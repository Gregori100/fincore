<?php

namespace App\Domain\Finance\Actions;

use App\Domain\Finance\Exceptions\InsufficientFunds;
use App\Domain\Finance\Services\FinancialStateService;
use App\Models\Movement;
use Illuminate\Support\Facades\DB;

class RegisterExpense
{
    public static function execute(float $amount, ?string $description = null): void
    {
        $state = new FinancialStateService();
        $bo = $state->getBO();

        if ($amount > $bo) {
            throw new InsufficientFunds("Not enough BO");
        }

        DB::transaction(function () use ($amount, $description) {
            Movement::create([
                'type' => 'expense',
                'amount' => $amount,
                'description' => $description,
                'occurred_at' => now(),
            ]);
        });
    }
}
