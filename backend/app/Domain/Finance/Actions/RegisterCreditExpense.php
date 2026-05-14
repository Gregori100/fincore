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
        string $userId,
        string $accountId,
        float $amount,
        ?string $description = null,
    ): JournalEntry {
        return DB::transaction(function () use ($userId, $accountId, $amount, $description) {
            // lockForUpdate previene que dos cargos simultáneos sumen y excedan
            // el límite de crédito por race condition.
            $account = Account::where('id', $accountId)
                ->where('user_id', $userId)
                ->lockForUpdate()
                ->firstOrFail();

            if (! $account->isCredit()) {
                throw new InvalidAccountType('Solo se puede cargar a una cuenta de tipo credit.');
            }

            $state = new FinancialStateService($userId);
            $newBalance = $state->getAccountBalance($account->id) + $amount;
            $limit = (float) ($account->credit_limit ?? 0);

            if ($newBalance > $limit) {
                throw new CreditLimitExceeded();
            }

            return JournalEntry::create([
                'user_id' => $userId,
                'kind' => JournalEntry::KIND_CREDIT_EXPENSE,
                'amount' => $amount,
                'account_origin_id' => $account->id,
                'account_destination_id' => null,
                'description' => $description,
                'occurred_at' => now(),
            ]);
        });
    }
}
