<?php

namespace App\Domain\Finance\Actions;

use App\Models\Debt;

class CreateDebt
{
    public static function execute(string $name, float $limit): Debt
    {
        return Debt::create([
            'name' => $name,
            'initial_amount' => 0,
            'current_amount' => 0,
            'credit_limit' => $limit,
        ]);
    }
}
