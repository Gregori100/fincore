<?php

namespace App\Domain\Finance\Actions;

use App\Domain\Finance\Exceptions\CreditLimitExceeded;
use App\Models\Debt;
use App\Models\Movement;
use Illuminate\Support\Facades\DB;

class RegisterCreditExpense
{
    public static function execute(
        int $debtId,
        float $amount,
        ?string $description = null
    ): Movement {
        $debt = Debt::findOrFail($debtId);

        $newAmount = $debt->current_amount + $amount;

        if ($newAmount > $debt->credit_limit) {
            throw new CreditLimitExceeded();
        }

        return DB::transaction(function () use ($debt, $newAmount, $amount, $description) {
            $debt->update([
                'current_amount' => $newAmount,
            ]);

            return Movement::create([
                'type' => 'credit_expense',
                'amount' => $amount,
                'description' => $description,
                'debt_id' => $debt->id,
                'occurred_at' => now(),
            ]);
        });
    }
}
