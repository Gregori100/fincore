<?php

namespace App\Domain\Finance\Services;

use App\Models\Account;
use App\Models\JournalEntry;
use Illuminate\Support\Collection;

class FinancialStateService
{
    public function __construct(private int $userId)
    {
    }

    public function getAccountBalance(int $accountId): float
    {
        // withTrashed() porque DeleteAccount soft-deletea: las cuentas archivadas
        // siguen siendo referenciadas por journal_entries históricas y debemos
        // poder leer su balance (siempre 0 si fue archivada con la regla actual,
        // pero también necesario para resolver el `type` cash/credit en
        // operaciones que cargan la entry sin filtrar por archivada).
        $account = Account::withTrashed()
            ->where('id', $accountId)
            ->where('user_id', $this->userId)
            ->firstOrFail();

        $incoming = (float) JournalEntry::where('user_id', $this->userId)
            ->where('account_destination_id', $accountId)
            ->sum('amount');

        $outgoing = (float) JournalEntry::where('user_id', $this->userId)
            ->where('account_origin_id', $accountId)
            ->sum('amount');

        return $account->isCredit()
            ? $outgoing - $incoming
            : $incoming - $outgoing;
    }

    public function getAccounts(): Collection
    {
        return Account::where('user_id', $this->userId)
            ->get()
            ->map(function (Account $account) {
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
        return Account::where('user_id', $this->userId)
            ->whereIn('type', [Account::TYPE_CASH, Account::TYPE_DEBIT])
            ->get()
            ->sum(fn (Account $a) => $this->getAccountBalance($a->id));
    }

    public function getDE(): float
    {
        return Account::where('user_id', $this->userId)
            ->where('type', Account::TYPE_CREDIT)
            ->get()
            ->sum(fn (Account $a) => $this->getAccountBalance($a->id));
    }

    public function getCR(): float
    {
        return Account::where('user_id', $this->userId)
            ->where('type', Account::TYPE_CREDIT)
            ->get()
            ->sum(function (Account $a) {
                $limit = (float) ($a->credit_limit ?? 0);
                return $limit - $this->getAccountBalance($a->id);
            });
    }

    public function getRecentEntries(int $limit = 10): Collection
    {
        return JournalEntry::where('user_id', $this->userId)
            ->with(['origin', 'destination'])
            ->orderByDesc('occurred_at')
            ->limit($limit)
            ->get();
    }

    public function getMonthlyBurnRate(): float
    {
        return (float) JournalEntry::where('user_id', $this->userId)
            ->whereIn('kind', [
                JournalEntry::KIND_EXPENSE,
                JournalEntry::KIND_CREDIT_EXPENSE,
            ])
            ->where('occurred_at', '>=', now()->subMonth())
            ->sum('amount');
    }

    public function getCreditUsagePercentage(): float
    {
        $totalLimit = (float) Account::where('user_id', $this->userId)
            ->where('type', Account::TYPE_CREDIT)
            ->sum('credit_limit');

        if ($totalLimit == 0) {
            return 0;
        }

        $used = $this->getDE();

        return round(($used / $totalLimit) * 100, 2);
    }
}
