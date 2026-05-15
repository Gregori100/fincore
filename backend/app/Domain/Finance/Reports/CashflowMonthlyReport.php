<?php

namespace App\Domain\Finance\Reports;

use App\Models\JournalEntry;

/**
 * Agrupa los movimientos del usuario por mes y separa ingresos vs egresos.
 *
 * - `income` = entries kind=income (dinero entra al sistema).
 * - `expense` = entries kind ∈ {expense, credit_expense} (dinero sale del sistema).
 * - `transfer` y `debt_payment` se excluyen: son flujos internos entre cuentas
 *   propias, no afectan el patrimonio neto.
 * - Entries cancelados (`deleted_at != null`) se excluyen por el scope global
 *   de SoftDeletes en JournalEntry.
 *
 * El método devuelve sólo los meses con actividad; el frontend completa con
 * ceros los meses faltantes para tener una serie continua de 12 elementos.
 */
final class CashflowMonthlyReport
{
    public function __construct(private string $userId)
    {
    }

    /**
     * @return array{
     *   months: list<array{year_month: string, income: float, expense: float, net: float}>,
     *   total_income: float,
     *   total_expense: float,
     *   total_net: float,
     * }
     */
    public function generate(string $from, string $to, ?string $accountId): array
    {
        $query = JournalEntry::query()
            ->where('user_id', $this->userId)
            ->whereIn('kind', [
                JournalEntry::KIND_INCOME,
                JournalEntry::KIND_EXPENSE,
                JournalEntry::KIND_CREDIT_EXPENSE,
            ])
            ->where('occurred_at', '>=', $from)
            ->where('occurred_at', '<=', $to.' 23:59:59');

        // Si se filtra por cuenta, el entry cuenta si esa cuenta es origen
        // (egresos) o destino (ingresos). Un OR cubre ambos lados sin duplicar
        // el entry (no hay un entry que tenga la misma cuenta en ambos lados).
        if ($accountId !== null) {
            $query->where(function ($q) use ($accountId) {
                $q->where('account_origin_id', $accountId)
                    ->orWhere('account_destination_id', $accountId);
            });
        }

        // Agrupamos en PHP en lugar de SQL para mantener portabilidad entre
        // Postgres (prod) y SQLite (tests). El volumen por user es chico
        // (cientos de entries/mes), el costo es ínfimo.
        $entries = $query->get(['occurred_at', 'kind', 'amount']);

        $months = $entries
            ->groupBy(fn ($e) => $e->occurred_at->format('Y-m'))
            ->map(function ($group, $yearMonth) {
                $income = (float) $group->where('kind', JournalEntry::KIND_INCOME)->sum('amount');
                $expense = (float) $group->whereIn('kind', [
                    JournalEntry::KIND_EXPENSE,
                    JournalEntry::KIND_CREDIT_EXPENSE,
                ])->sum('amount');

                return [
                    'year_month' => $yearMonth,
                    'income' => $income,
                    'expense' => $expense,
                    'net' => $income - $expense,
                ];
            })
            ->sortBy('year_month')
            ->values()
            ->all();

        $totalIncome = array_sum(array_column($months, 'income'));
        $totalExpense = array_sum(array_column($months, 'expense'));

        return [
            'months' => $months,
            'total_income' => (float) $totalIncome,
            'total_expense' => (float) $totalExpense,
            'total_net' => (float) ($totalIncome - $totalExpense),
        ];
    }
}
