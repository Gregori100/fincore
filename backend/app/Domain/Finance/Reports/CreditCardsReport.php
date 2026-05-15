<?php

namespace App\Domain\Finance\Reports;

use App\Domain\Finance\Services\FinancialStateService;
use App\Models\Account;
use App\Models\JournalEntry;
use Carbon\CarbonImmutable;

/**
 * Devuelve el estado actual de cada tarjeta de crédito activa del usuario:
 * deuda, utilización, fechas próximas de corte/pago y totales del ciclo en
 * curso y del último ciclo cerrado.
 *
 * Si una tarjeta no tiene `closing_day`/`payment_day`/`minimum_payment_pct`
 * configurado, los campos dependientes vienen como `null` para que el frontend
 * muestre "no configurado" con CTA a editar.
 *
 * No incluye motor real de intereses: el pago mínimo estimado es una
 * aproximación basada únicamente en los cargos del último ciclo cerrado.
 */
final class CreditCardsReport
{
    public function __construct(private string $userId)
    {
    }

    public function generate(): array
    {
        $service = new FinancialStateService($this->userId);

        $cards = Account::query()
            ->where('user_id', $this->userId)
            ->where('type', Account::TYPE_CREDIT)
            ->whereNull('deleted_at')
            ->orderBy('name')
            ->get();

        $today = CarbonImmutable::today();

        $result = [];
        foreach ($cards as $card) {
            $balance = $service->getAccountBalance($card->id);
            $limit = (float) ($card->credit_limit ?? 0);
            $available = max(0.0, $limit - $balance);
            $utilizationPct = $limit > 0 ? ($balance / $limit) * 100 : 0;

            $closingCycle = $card->closing_day
                ? $this->cycleFor((int) $card->closing_day, $today)
                : null;

            $nextPayment = $card->payment_day
                ? $this->nextDayOccurrence((int) $card->payment_day, $today)
                : null;

            $currentCycle = null;
            $lastCycle = null;
            $minimumPaymentEstimated = null;

            if ($closingCycle !== null) {
                [$lastClosing, $nextClosing] = $closingCycle;

                $currentFrom = $lastClosing->copy()->addDay();
                $currentTo = $today;
                $lastFrom = $lastClosing->copy()->subMonthNoOverflow()->addDay();
                $lastTo = $lastClosing;

                $currentCycle = $this->cycleSummary($card->id, $currentFrom, $currentTo);
                $lastCycle = $this->cycleSummary($card->id, $lastFrom, $lastTo);

                if ($card->minimum_payment_pct !== null) {
                    $minimumPaymentEstimated = $lastCycle['charges_total']
                        * (float) $card->minimum_payment_pct;
                }
            }

            $result[] = [
                'id' => $card->id,
                'name' => $card->name,
                'balance' => $balance,
                'credit_limit' => $limit,
                'available' => $available,
                'utilization_pct' => round($utilizationPct, 2),
                'closing_day' => $card->closing_day !== null ? (int) $card->closing_day : null,
                'payment_day' => $card->payment_day !== null ? (int) $card->payment_day : null,
                'interest_rate' => $card->interest_rate !== null ? (float) $card->interest_rate : null,
                'minimum_payment_pct' => $card->minimum_payment_pct !== null ? (float) $card->minimum_payment_pct : null,
                'next_closing_date' => $closingCycle !== null ? $closingCycle[1]->toDateString() : null,
                'days_to_closing' => $closingCycle !== null ? $today->diffInDays($closingCycle[1], false) : null,
                'next_payment_date' => $nextPayment !== null ? $nextPayment->toDateString() : null,
                'days_to_payment' => $nextPayment !== null ? $today->diffInDays($nextPayment, false) : null,
                'current_cycle' => $currentCycle,
                'last_cycle' => $lastCycle,
                'minimum_payment_estimated' => $minimumPaymentEstimated,
            ];
        }

        // Orden por % de utilización descendente; las más comprometidas arriba.
        usort($result, function ($a, $b) {
            $cmp = $b['utilization_pct'] <=> $a['utilization_pct'];
            return $cmp !== 0 ? $cmp : strcmp($a['name'], $b['name']);
        });

        return ['cards' => $result];
    }

    /**
     * Devuelve [$lastClosing, $nextClosing] para un closing_day dado.
     * Si hoy ya pasó el día de corte de este mes, "este mes" es el último corte;
     * si aún no llega, el corte anterior fue el del mes pasado.
     *
     * @return array{0: CarbonImmutable, 1: CarbonImmutable}
     */
    private function cycleFor(int $closingDay, CarbonImmutable $today): array
    {
        $thisMonthClosing = $today->copy()->setDay(min($closingDay, $today->daysInMonth));

        if ($today->greaterThanOrEqualTo($thisMonthClosing)) {
            $lastClosing = $thisMonthClosing;
            $nextClosing = $lastClosing->addMonthNoOverflow();
            // Re-ajustar el día por si el siguiente mes tiene menos días que closingDay.
            $nextClosing = $nextClosing->setDay(min($closingDay, $nextClosing->daysInMonth));
        } else {
            $nextClosing = $thisMonthClosing;
            $lastClosing = $thisMonthClosing->subMonthNoOverflow();
            $lastClosing = $lastClosing->setDay(min($closingDay, $lastClosing->daysInMonth));
        }

        return [$lastClosing, $nextClosing];
    }

    /**
     * Devuelve la próxima ocurrencia del día N del mes (>= hoy). Si hoy es el día N
     * o anterior dentro del mes, devuelve este mes; si ya pasó, el del mes siguiente.
     */
    private function nextDayOccurrence(int $dayOfMonth, CarbonImmutable $today): CarbonImmutable
    {
        $thisMonth = $today->copy()->setDay(min($dayOfMonth, $today->daysInMonth));
        if ($today->lessThanOrEqualTo($thisMonth)) {
            return $thisMonth;
        }
        $nextMonth = $thisMonth->addMonthNoOverflow();
        return $nextMonth->setDay(min($dayOfMonth, $nextMonth->daysInMonth));
    }

    /**
     * @return array{from: string, to: string, charges_total: float, charges_count: int}
     */
    private function cycleSummary(string $cardId, CarbonImmutable $from, CarbonImmutable $to): array
    {
        $row = JournalEntry::query()
            ->where('user_id', $this->userId)
            ->where('kind', JournalEntry::KIND_CREDIT_EXPENSE)
            ->where('account_origin_id', $cardId)
            ->whereBetween('occurred_at', [
                $from->toDateString().' 00:00:00',
                $to->toDateString().' 23:59:59',
            ])
            ->selectRaw('COALESCE(SUM(amount), 0) AS total, COUNT(*) AS cnt')
            ->first();

        return [
            'from' => $from->toDateString(),
            'to' => $to->toDateString(),
            'charges_total' => (float) $row->total,
            'charges_count' => (int) $row->cnt,
        ];
    }
}
