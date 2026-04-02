<?php

namespace App\Domain\Finance\Actions;

use App\Domain\Finance\Exceptions\InsufficientFunds;
use App\Domain\Finance\Exceptions\OverpayDebt;
use App\Domain\Finance\Services\FinancialStateService;
use App\Models\Debt;
use App\Models\Movement;
use Illuminate\Support\Facades\DB;

class PayDebt
{
    public static function execute(
        int $debtId,
        float $amount,
        ?string $description = null
    ): Movement {
        $debt = Debt::findOrFail($debtId);

        $state = new FinancialStateService();
        $bo = $state->getBO();

        if ($amount > $bo) {
            throw new InsufficientFunds();
        }

        if ($amount > $debt->current_amount) {
            throw new OverpayDebt();
        }

        return DB::transaction(function () use ($debt, $amount, $description) {
            $debt->update([
                'current_amount' => $debt->current_amount - $amount
            ]);

            return Movement::create([
                'type' => 'debt_payment',
                'amount' => $amount,
                'description' => $description,
                'debt_id' => $debt->id,
                'occurred_at' => now(),
            ]);
        });
    }
}
