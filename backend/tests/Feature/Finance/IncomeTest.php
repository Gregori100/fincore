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

    public function test_income_increases_bo()
    {
        $user = $this->createUserWithBolsa();
        $bolsa = $user->accounts()->where('type', Account::TYPE_CASH)->firstOrFail();

        RegisterIncome::execute($user->id, $bolsa->id, 5000);

        $state = new FinancialStateService($user->id);
        $this->assertEquals(5000, $state->getBO());
    }

    public function test_expense_reduces_bo()
    {
        $user = $this->createUserWithBolsa();
        $bolsa = $user->accounts()->where('type', Account::TYPE_CASH)->firstOrFail();

        RegisterIncome::execute($user->id, $bolsa->id, 5000);
        RegisterExpense::execute($user->id, $bolsa->id, 2000);

        $state = new FinancialStateService($user->id);
        $this->assertEquals(3000, $state->getBO());
    }

    public function test_cannot_spend_more_than_balance()
    {
        $user = $this->createUserWithBolsa();
        $bolsa = $user->accounts()->where('type', Account::TYPE_CASH)->firstOrFail();

        RegisterIncome::execute($user->id, $bolsa->id, 1000);

        $this->expectException(InsufficientFunds::class);

        RegisterExpense::execute($user->id, $bolsa->id, 2000);
    }

    public function test_income_into_debit_account()
    {
        $user = $this->createUserWithBolsa();
        $debit = Account::factory()->debit()->for($user)->create();

        RegisterIncome::execute($user->id, $debit->id, 1500);

        $state = new FinancialStateService($user->id);
        $this->assertEquals(1500, $state->getAccountBalance($debit->id));
        $this->assertEquals(1500, $state->getBO());
    }
}
