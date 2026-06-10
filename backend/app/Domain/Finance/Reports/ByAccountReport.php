<?php

namespace App\Domain\Finance\Reports;

use App\Models\Account;
use App\Models\JournalEntry;

/**
 * Para cada cuenta activa del usuario, agrega ingresos, egresos y neto en un
 * rango cerrado [from, to].
 *
 * - `income`  = suma de `journal_entries.amount` donde `account_destination_id = cuenta.id`.
 * - `expense` = suma de `journal_entries.amount` donde `account_origin_id = cuenta.id`.
 * - `net`     = income − expense (positivo: la cuenta recibió más de lo que salió).
 *
 * Semántica por tipo de cuenta:
 * - cash/debit: `income` = ingresos recibidos + transfers entrantes;
 *               `expense` = gastos + transfers salientes + pagos a tarjeta.
 * - credit:     `income` = pagos recibidos (debt_payment como destination, la deuda baja);
 *               `expense` = cargos (credit_expense como origin, la deuda sube).
 *
 * Cuentas archivadas se excluyen por el scope SoftDeletes de `Account`.
 * Entries cancelados se excluyen por el scope SoftDeletes de `JournalEntry`.
 */
final class ByAccountReport
{
    public function __construct(private string $userId) {}

    /**
     * @return array{
     *   from: string,
     *   to: string,
     *   accounts: list<array{account_id: string, name: string, type: string, income: float, expense: float, net: float}>,
     * }
     */
    public function generate(string $from, string $to): array
    {
        $accounts = Account::query()
            ->where('user_id', $this->userId)
            ->orderBy('created_at')
            ->get(['id', 'name', 'type']);

        // Una sola query trae todos los entries del rango; agrupamos en PHP por
        // cuenta. Patrón consistente con CashflowMonthlyReport: evita N+1 (antes
        // 2N queries con sum() por cuenta) y se mantiene portable PG/SQLite.
        $endOfTo = \Carbon\Carbon::parse($to)->endOfDay();
        $entries = JournalEntry::query()
            ->where('user_id', $this->userId)
            ->where('occurred_at', '>=', $from)
            ->where('occurred_at', '<=', $endOfTo)
            ->get(['account_origin_id', 'account_destination_id', 'amount']);

        $incomeByAccount = $entries
            ->whereNotNull('account_destination_id')
            ->groupBy('account_destination_id')
            ->map(fn ($g) => (float) $g->sum('amount'));

        $expenseByAccount = $entries
            ->whereNotNull('account_origin_id')
            ->groupBy('account_origin_id')
            ->map(fn ($g) => (float) $g->sum('amount'));

        $rows = $accounts->map(function (Account $a) use ($incomeByAccount, $expenseByAccount) {
            $income = (float) ($incomeByAccount[$a->id] ?? 0);
            $expense = (float) ($expenseByAccount[$a->id] ?? 0);

            return [
                'account_id' => $a->id,
                'name' => $a->name,
                'type' => $a->type,
                'income' => $income,
                'expense' => $expense,
                'net' => $income - $expense,
            ];
        })->values()->all();

        return [
            'from' => $from,
            'to' => $to,
            'accounts' => $rows,
        ];
    }
}
