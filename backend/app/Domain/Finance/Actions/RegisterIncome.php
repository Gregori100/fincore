<?php

namespace App\Domain\Finance\Actions;

use App\Domain\Finance\Exceptions\InvalidAccountType;
use App\Models\Account;
use App\Models\JournalEntry;
use Illuminate\Support\Facades\DB;

class RegisterIncome
{
    public static function execute(
        string $userId,
        string $accountId,
        float $amount,
        ?string $description = null,
    ): JournalEntry {
        return DB::transaction(function () use ($userId, $accountId, $amount, $description) {
            // lockForUpdate serializa mutaciones concurrentes sobre la misma cuenta.
            // Aunque income no valida balance, mantenemos el patrón uniforme con
            // las demás Actions para que dos requests sobre la misma cuenta no se
            // intercalen y dejen estado raro.
            $account = Account::where('id', $accountId)
                ->where('user_id', $userId)
                ->lockForUpdate()
                ->firstOrFail();

            if (! $account->isCashLike()) {
                throw new InvalidAccountType('Un ingreso solo puede recibirse en una cuenta de efectivo o débito.');
            }

            return JournalEntry::create([
                'user_id' => $userId,
                'kind' => JournalEntry::KIND_INCOME,
                'amount' => $amount,
                'account_origin_id' => null,
                'account_destination_id' => $account->id,
                'description' => $description,
                'occurred_at' => now(),
            ]);
        });
    }
}
