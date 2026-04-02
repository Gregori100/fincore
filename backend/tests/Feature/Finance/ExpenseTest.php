<?php

namespace Tests\Feature\Finance;

use App\Domain\Finance\Actions\CreateDebt;
use App\Domain\Finance\Actions\PayDebt;
use App\Domain\Finance\Actions\RegisterExpense;
use App\Domain\Finance\Actions\RegisterIncome;
use App\Domain\Finance\Exceptions\InsufficientFunds;
use App\Domain\Finance\Exceptions\OverpayDebt;
use App\Domain\Finance\Services\FinancialStateService;
use App\Models\Debt;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class ExpenseTest extends TestCase
{
    use RefreshDatabase;

    public function test_cannot_spend_more_than_bo()
    {
        RegisterIncome::execute(1000);

        $this->expectException(InsufficientFunds::class);

        RegisterExpense::execute(1500);
    }

    public function test_cannot_overpay_debt()
    {
        RegisterIncome::execute(5000);
        $debt = Debt::factory()->create(['current_amount' => 1000]);

        $this->expectException(OverpayDebt::class);

        PayDebt::execute($debt->id, 2000);
    }

    public function test_cannot_pay_debt_without_funds()
    {
        $debt = Debt::factory()->create(['current_amount' => 1000]);

        $this->expectException(InsufficientFunds::class);

        PayDebt::execute($debt->id, 500);
    }

    public function test_bo_is_never_negative()
    {
        RegisterIncome::execute(1000);
        RegisterExpense::execute(1000);

        $state = new FinancialStateService();

        $this->assertEquals(0, $state->getBO());
    }
}
