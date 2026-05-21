<?php

namespace App\Domain\Finance\Plan\Services;

use App\Domain\Finance\Services\FinancialStateService;
use App\Models\Account;
use App\Models\JournalEntry;
use App\Models\PlannedEvent;
use Illuminate\Support\Carbon;
use Illuminate\Support\Collection;

class PlanProjectionService
{
    public function __construct(
        private string $userId,
        private int $horizonMonths = 6,
    ) {}

    /**
     * Calcula la proyección de saldos por cuenta a `horizonMonths` meses desde hoy.
     *
     * @return array{
     *     horizon: array{from:string, to:string},
     *     accounts: list<array{id:string, name:string, type:string, initial_balance:float, final_balance:float}>,
     *     series: array<string, list<array{date:string, balance:float}>>,
     *     events: list<array{date:string, kind:string, amount:float, account_origin_id:?string, account_destination_id:?string, planned_event_id:string, override_id:?string, source:string, warnings:list<string>, skipped:bool}>
     * }
     */
    public function project(): array
    {
        $from = Carbon::today();
        $to = $from->copy()->addMonths($this->horizonMonths);

        $state = new FinancialStateService($this->userId);
        $accounts = $state->getAccounts(includeArchived: false);

        $balances = [];
        $accountTypes = [];
        $accountSummaries = [];

        foreach ($accounts as $account) {
            $balances[$account->id] = (float) $account->balance;
            $accountTypes[$account->id] = $account->type;
            $accountSummaries[] = [
                'id' => $account->id,
                'name' => $account->name,
                'type' => $account->type,
                'initial_balance' => (float) $account->balance,
                'final_balance' => (float) $account->balance,
            ];
        }

        $series = [];
        foreach ($accounts as $account) {
            $series[$account->id] = [[
                'date' => $from->toDateString(),
                'balance' => (float) $account->balance,
            ]];
        }

        $occurrences = $this->collectOccurrences($from, $to);
        $events = [];

        foreach ($occurrences as $occurrence) {
            /** @var PlannedEvent $event */
            $event = $occurrence['event'];
            $date = $occurrence['date'];
            $amount = (float) $occurrence['amount'];
            $overrideId = $occurrence['override_id'];
            $source = $occurrence['source'];
            $skipped = $occurrence['skipped'];
            $warnings = [];

            $originId = $event->account_origin_id;
            $destinationId = $event->account_destination_id;

            $originActive = $originId !== null && array_key_exists($originId, $balances);
            $destinationActive = $destinationId !== null && array_key_exists($destinationId, $balances);

            if (! $skipped) {
                if (($originId !== null && ! $originActive) || ($destinationId !== null && ! $destinationActive)) {
                    $skipped = true;
                    $warnings[] = 'archived_account';
                }
            }

            // Auto-ajuste de debt_payment: nunca dejar la tarjeta en negativo.
            // Si la deuda ya está en 0, se salta la ocurrencia. Si el monto
            // excede la deuda actual, se recorta al monto exacto adeudado.
            if (! $skipped && $event->kind === JournalEntry::KIND_DEBT_PAYMENT && $destinationId !== null) {
                $currentDebt = $balances[$destinationId];
                if ($currentDebt <= 0) {
                    $skipped = true;
                    $warnings[] = 'debt_already_zero';
                    $amount = 0.0;
                } elseif ($amount > $currentDebt) {
                    $amount = $currentDebt;
                    $warnings[] = 'auto_adjusted';
                }
            }

            if (! $skipped) {
                $this->applyToBalances($event, $amount, $balances, $accountTypes);
                $this->snapshotBalances($series, $balances, $date);
            }

            // No emitir las ocurrencias auto-saltadas por "tarjeta ya en cero":
            // son ruido (no aportan información al usuario, solo serían "0 → 0").
            // Las saltadas por archived_account o por override manual sí se emiten
            // (son señales que el usuario debe ver).
            if ($skipped && in_array('debt_already_zero', $warnings, true)) {
                continue;
            }

            $events[] = [
                'date' => $date->toDateString(),
                'kind' => $event->kind,
                'amount' => $amount,
                'account_origin_id' => $originId,
                'account_destination_id' => $destinationId,
                'planned_event_id' => $event->id,
                'override_id' => $overrideId,
                'source' => $source,
                'warnings' => $warnings,
                'skipped' => $skipped,
            ];
        }

        // Asegurar que cada serie llegue hasta el final del horizonte con el último balance.
        foreach ($series as $accountId => $points) {
            $last = end($points);
            if ($last['date'] !== $to->toDateString()) {
                $series[$accountId][] = [
                    'date' => $to->toDateString(),
                    'balance' => $balances[$accountId],
                ];
            }
        }

        foreach ($accountSummaries as &$summary) {
            $summary['final_balance'] = $balances[$summary['id']];
        }
        unset($summary);

        return [
            'horizon' => [
                'from' => $from->toDateString(),
                'to' => $to->toDateString(),
            ],
            'accounts' => $accountSummaries,
            'series' => $series,
            'events' => $events,
        ];
    }

    /**
     * Recolecta todas las ocurrencias efectivas (regla + overrides) en orden
     * cronológico estable. Cada elemento contiene {event, date, amount,
     * override_id, source, skipped}.
     */
    private function collectOccurrences(Carbon $from, Carbon $to): Collection
    {
        $events = PlannedEvent::where('user_id', $this->userId)
            ->with(['overrides'])
            ->get();

        $result = collect();

        foreach ($events as $event) {
            $overridesByDate = $event->overrides->keyBy(
                fn ($o) => $o->occurrence_date->toDateString(),
            );

            foreach ($event->occurrencesBetween($from, $to) as $date) {
                $key = $date->toDateString();
                $override = $overridesByDate->get($key);

                if ($override !== null) {
                    $skipped = (bool) $override->is_skipped;
                    $amount = $skipped ? 0.0 : (float) $override->amount;
                    $result->push([
                        'event' => $event,
                        'date' => $date,
                        'amount' => $amount,
                        'override_id' => $override->id,
                        'source' => 'override',
                        'skipped' => $skipped,
                    ]);
                } else {
                    $result->push([
                        'event' => $event,
                        'date' => $date,
                        'amount' => (float) $event->amount,
                        'override_id' => null,
                        'source' => 'rule',
                        'skipped' => false,
                    ]);
                }
            }
        }

        return $result->sortBy([
            ['date', 'asc'],
            fn ($a, $b) => $a['event']->created_at <=> $b['event']->created_at,
        ])->values();
    }

    private function applyToBalances(PlannedEvent $event, float $amount, array &$balances, array $accountTypes): void
    {
        $originId = $event->account_origin_id;
        $destinationId = $event->account_destination_id;

        // Replica la semántica de FinancialStateService::getAccountBalance:
        //   cash/debit: incoming - outgoing
        //   credit:     outgoing - incoming  (la deuda sube con outgoing)
        if ($originId !== null) {
            $balances[$originId] += ($accountTypes[$originId] === Account::TYPE_CREDIT)
                ? $amount
                : -$amount;
        }
        if ($destinationId !== null) {
            $balances[$destinationId] += ($accountTypes[$destinationId] === Account::TYPE_CREDIT)
                ? -$amount
                : $amount;
        }
    }

    private function snapshotBalances(array &$series, array $balances, Carbon $date): void
    {
        foreach ($series as $accountId => &$points) {
            $points[] = [
                'date' => $date->toDateString(),
                'balance' => round($balances[$accountId], 2),
            ];
        }
        unset($points);
    }
}
