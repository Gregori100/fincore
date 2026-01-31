<?php

namespace App\Domain\Finance\Actions;

use App\Models\Debt;
use App\Models\Movement;
use Exception;

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
            throw new Exception('Credit limit exceeded');
        }

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
    }
}
