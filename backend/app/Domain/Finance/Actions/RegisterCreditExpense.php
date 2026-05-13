<?php

namespace App\Domain\Finance\Actions;

use App\Domain\Finance\Exceptions\CreditLimitExceeded;
use App\Domain\Finance\Exceptions\InvalidAccountType;
use App\Domain\Finance\Services\FinancialStateService;
use App\Models\Account;
use App\Models\JournalEntry;
use Illuminate\Support\Facades\DB;

class RegisterCreditExpense
{
    public static function execute(
        int $accountId,
        float $amount,
        ?string $description = null,
    ): JournalEntry {
        $account = Account::findOrFail($accountId);

        if (! $account->isCredit()) {
            throw new InvalidAccountType('Solo se puede cargar a una cuenta de tipo credit.');
        }

        $state = new FinancialStateService();
        $newBalance = $state->getAccountBalance($account->id) + $amount;
        $limit = (float) ($account->credit_limit ?? 0);

        if ($newBalance > $limit) {
            throw new CreditLimitExceeded();
        }

        return DB::transaction(fn () => JournalEntry::create([
            'user_id' => $account->user_id,
            'kind' => JournalEntry::KIND_CREDIT_EXPENSE,
            'amount' => $amount,
            'account_origin_id' => $account->id,
            'account_destination_id' => null,
            'description' => $description,
            'occurred_at' => now(),
        ]));
    }
}
