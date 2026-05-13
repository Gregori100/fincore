<?php

namespace Tests\Feature\Finance;

use App\Domain\Finance\Actions\RegisterExpense;
use App\Domain\Finance\Actions\RegisterIncome;
use App\Domain\Finance\Exceptions\InsufficientFunds;
use App\Domain\Finance\Services\FinancialStateService;
use App\Models\Account;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class IncomeTest extends TestCase
{
    use RefreshDatabase;

    private function bolsa(): Account
    {
        return Account::where('type', Account::TYPE_CASH)->firstOrFail();
    }

    public function test_income_increases_bo()
    {
        RegisterIncome::execute($this->bolsa()->id, 5000);

        $state = new FinancialStateService();

        $this->assertEquals(5000, $state->getBO());
    }

    public function test_expense_reduces_bo()
    {
        $bolsa = $this->bolsa();
        RegisterIncome::execute($bolsa->id, 5000);
        RegisterExpense::execute($bolsa->id, 2000);

        $state = new FinancialStateService();

        $this->assertEquals(3000, $state->getBO());
    }

    public function test_cannot_spend_more_than_balance()
    {
        $bolsa = $this->bolsa();
        RegisterIncome::execute($bolsa->id, 1000);

        $this->expectException(InsufficientFunds::class);

        RegisterExpense::execute($bolsa->id, 2000);
    }

    public function test_income_into_debit_account()
    {
        $debit = Account::factory()->debit()->create();

        RegisterIncome::execute($debit->id, 1500);

        $state = new FinancialStateService();
        $this->assertEquals(1500, $state->getAccountBalance($debit->id));
        $this->assertEquals(1500, $state->getBO());
    }
}
