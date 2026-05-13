<?php

namespace App\Domain\Finance\Actions;

use App\Domain\Finance\Exceptions\InvalidAccountType;
use App\Models\Account;
use App\Models\JournalEntry;
use Illuminate\Support\Facades\DB;

class RegisterIncome
{
    public static function execute(
        int $userId,
        int $accountId,
        float $amount,
        ?string $description = null,
    ): JournalEntry {
        $account = Account::where('id', $accountId)
            ->where('user_id', $userId)
            ->firstOrFail();

        if (! $account->isCashLike()) {
            throw new InvalidAccountType('Un ingreso solo puede recibirse en una cuenta de efectivo o débito.');
        }

        return DB::transaction(fn () => JournalEntry::create([
            'user_id' => $userId,
            'kind' => JournalEntry::KIND_INCOME,
            'amount' => $amount,
            'account_origin_id' => null,
            'account_destination_id' => $account->id,
            'description' => $description,
            'occurred_at' => now(),
        ]));
    }
}
