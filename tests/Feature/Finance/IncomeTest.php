<?php

namespace Tests\Feature\Finance;

use App\Domain\Finance\Actions\RegisterExpense;
use App\Domain\Finance\Actions\RegisterIncome;
use App\Domain\Finance\Exceptions\InsufficientFunds;
use App\Domain\Finance\Services\FinancialStateService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class IncomeTest extends TestCase
{
    use RefreshDatabase;

    public function test_income_increases_bo()
    {
        RegisterIncome::execute(5000);

        $state = new FinancialStateService();

        $this->assertEquals(5000, $state->getBO());
    }

    public function test_expense_reduces_bo()
    {
        RegisterIncome::execute(5000);
        RegisterExpense::execute(2000);

        $state = new FinancialStateService();

        $this->assertEquals(3000, $state->getBO());
    }

    public function test_cannot_spend_more_than_bo()
    {
        RegisterIncome::execute(1000);

        $this->expectException(InsufficientFunds::class);

        RegisterExpense::execute(2000);
    }
}
