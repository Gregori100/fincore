<?php

namespace App\Domain\Finance\Actions;

use App\Domain\Finance\Exceptions\InsufficientFunds;
use App\Domain\Finance\Exceptions\InvalidAccountType;
use App\Domain\Finance\Services\FinancialStateService;
use App\Models\Account;
use App\Models\JournalEntry;
use Illuminate\Support\Facades\DB;

class RegisterExpense
{
    public static function execute(
        int $accountId,
        float $amount,
        ?string $description = null,
    ): JournalEntry {
        $account = Account::findOrFail($accountId);

        if (! $account->isCashLike()) {
            throw new InvalidAccountType('Un gasto en efectivo/débito solo puede salir de una cuenta cash o debit. Usa credit_expense para tarjetas de crédito.');
        }

        $state = new FinancialStateService();
        if ($amount > $state->getAccountBalance($account->id)) {
            throw new InsufficientFunds();
        }

        return DB::transaction(fn () => JournalEntry::create([
            'user_id' => $account->user_id,
            'kind' => JournalEntry::KIND_EXPENSE,
            'amount' => $amount,
            'account_origin_id' => $account->id,
            'account_destination_id' => null,
            'description' => $description,
            'occurred_at' => now(),
        ]));
    }
}
