<?php

namespace App\Domain\Finance\Services;

use App\Models\Account;
use App\Models\JournalEntry;
use Illuminate\Support\Collection;

class FinancialStateService
{
    public function getAccountBalance(int $accountId): float
    {
        $account = Account::findOrFail($accountId);

        $incoming = (float) JournalEntry::where('account_destination_id', $accountId)->sum('amount');
        $outgoing = (float) JournalEntry::where('account_origin_id', $accountId)->sum('amount');

        // En cuentas de crédito, el balance representa deuda actual:
        // los cargos (origin) la suben, los pagos (destination) la bajan.
        return $account->isCredit()
            ? $outgoing - $incoming
            : $incoming - $outgoing;
    }

    public function getAccounts(): Collection
    {
        return Account::all()->map(function (Account $account) {
            $balance = $this->getAccountBalance($account->id);
            $account->balance = $balance;
            if ($account->isCredit() && $account->credit_limit !== null) {
                $account->available_credit = (float) $account->credit_limit - $balance;
            }
            return $account;
        });
    }

    public function getBO(): float
    {
        return Account::whereIn('type', [Account::TYPE_CASH, Account::TYPE_DEBIT])
            ->get()
            ->sum(fn (Account $a) => $this->getAccountBalance($a->id));
    }

    public function getDE(): float
    {
        return Account::where('type', Account::TYPE_CREDIT)
            ->get()
            ->sum(fn (Account $a) => $this->getAccountBalance($a->id));
    }

    public function getCR(): float
    {
        return Account::where('type', Account::TYPE_CREDIT)
            ->get()
            ->sum(function (Account $a) {
                $limit = (float) ($a->credit_limit ?? 0);
                return $limit - $this->getAccountBalance($a->id);
            });
    }

    public function getRecentEntries(int $limit = 10): Collection
    {
        return JournalEntry::with(['origin', 'destination'])
            ->orderByDesc('occurred_at')
            ->limit($limit)
            ->get();
    }

    public function getMonthlyBurnRate(): float
    {
        return (float) JournalEntry::whereIn('kind', [
            JournalEntry::KIND_EXPENSE,
            JournalEntry::KIND_CREDIT_EXPENSE,
        ])
            ->where('occurred_at', '>=', now()->subMonth())
            ->sum('amount');
    }

    public function getCreditUsagePercentage(): float
    {
        $totalLimit = (float) Account::where('type', Account::TYPE_CREDIT)->sum('credit_limit');

        if ($totalLimit == 0) {
            return 0;
        }

        $used = $this->getDE();

        return round(($used / $totalLimit) * 100, 2);
    }
}
