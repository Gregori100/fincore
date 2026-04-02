<?php

namespace App\Domain\Finance\Services;

use App\Models\Debt;
use App\Models\Movement;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;

class FinancialStateService
{
    public function getBO(): float
    {
        $income = Movement::where('type', 'income')->sum('amount');
        $expense = Movement::where('type', 'expense')->sum('amount');
        $payments = Movement::where('type', 'debt_payment')->sum('amount');

        return (float) ($income - $expense - $payments);
    }

    public function getDE(): float
    {
        return (float) Debt::sum('current_amount');
    }

    public function getCR(): float
    {
        return Debt::sum(DB::raw('credit_limit - current_amount'));
    }

    public function getDebts(): Collection
    {
        return Debt::all();
    }

    public function getMovements(): Collection
    {
        return Movement::latest()->get();
    }

    public function getDebtsSummary(): array
    {
        return Debt::all()
            ->map(fn($debt) => [
                'name' => $debt->name,
                'current_amount' => (float) $debt->current_amount,
            ])
            ->toArray();
    }

    public function getMonthlyBurnRate(): float
    {
        return Movement::where('type', 'expense')
            ->where('occurred_at', '>=', now()->subMonth())
            ->sum('amount');
    }

    public function getCreditUsagePercentage(): float
    {
        $totalLimit = Debt::sum('credit_limit');
        $used = Debt::sum('current_amount');

        if ($totalLimit == 0) return 0;

        return round(($used / $totalLimit) * 100, 2);
    }
}
