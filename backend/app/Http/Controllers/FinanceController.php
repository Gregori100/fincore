<?php

namespace App\Http\Controllers;

use App\Domain\Finance\Actions\PayDebt;
use App\Domain\Finance\Actions\RegisterExpense;
use App\Domain\Finance\Actions\RegisterIncome;
use App\Domain\Finance\Services\FinancialStateService;
use App\Models\Debt;
use Illuminate\Http\Request;

class FinanceController extends Controller
{
    public function state()
    {
        $state = new FinancialStateService();

        return response()->json([
            'bo' => $state->getBO(),
            'de' => $state->getDE(),
            'debts' => $state->getDebtsSummary(),
        ]);
    }

    public function income(Request $request)
    {
        $data = $request->validate([
            'amount' => 'required|numeric|min:0.01',
            'description' => 'nullable|string',
        ]);

        RegisterIncome::execute(
            $data['amount'],
            $data['description'] ?? null
        );

        return response()->json(['message' => 'Ingreso registrado']);
    }

    public function expense(Request $request)
    {
        $data = $request->validate([
            'amount' => 'required|numeric|min:0.01',
            'description' => 'nullable|string',
        ]);

        RegisterExpense::execute(
            $data['amount'],
            $data['description'] ?? null
        );

        return response()->json(['message' => 'Gasto registrado']);
    }

    public function payDebt(Request $request)
    {
        $data = $request->validate([
            'debt_id' => 'required|exists:debts,id',
            'amount' => 'required|numeric|min:0.01',
        ]);

        $debt = Debt::findOrFail($data['debt_id']);

        PayDebt::execute($debt->id, $data['amount']);

        return response()->json(['message' => 'Deuda pagada']);
    }
}
