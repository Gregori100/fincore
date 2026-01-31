<?php

namespace App\Domain\Finance\Actions;

use App\Models\Movement;
use Illuminate\Support\Facades\DB;

class RegisterIncome
{
    public static function execute(float $amount, ?string $description = null): void
    {
        DB::transaction(function () use ($amount, $description) {
            Movement::create([
                'type' => 'income',
                'amount' => $amount,
                'description' => $description,
                'occurred_at' => now(),
            ]);
        });
    }
}
