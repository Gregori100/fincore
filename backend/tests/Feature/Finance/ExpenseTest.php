<?php

namespace Tests\Feature\Finance;

use App\Domain\Finance\Actions\PayCreditAccount;
use App\Domain\Finance\Actions\RegisterCreditExpense;
use App\Domain\Finance\Actions\RegisterExpense;
use App\Domain\Finance\Actions\RegisterIncome;
use App\Domain\Finance\Exceptions\InsufficientFunds;
use App\Domain\Finance\Exceptions\OverpayDebt;
use App\Domain\Finance\Services\FinancialStateService;
use App\Models\Account;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class ExpenseTest extends TestCase
{
    use RefreshDatabase;

    public function test_cannot_spend_more_than_account_balance()
    {
        $user = $this->createUserWithBolsa();
        $bolsa = $user->accounts()->where('type', Account::TYPE_CASH)->firstOrFail();

        RegisterIncome::execute($user->id, $bolsa->id, 1000);

        $this->expectException(InsufficientFunds::class);

        RegisterExpense::execute($user->id, $bolsa->id, 1500);
    }

    public function test_cannot_overpay_credit_account()
    {
        $user = $this->createUserWithBolsa();
        $bolsa = $user->accounts()->where('type', Account::TYPE_CASH)->firstOrFail();
        $card = Account::factory()->credit()->for($user)->create(['credit_limit' => 10000]);

        RegisterIncome::execute($user->id, $bolsa->id, 5000);
        RegisterCreditExpense::execute($user->id, $card->id, 1000);

        $this->expectException(OverpayDebt::class);

        PayCreditAccount::execute($user->id, $bolsa->id, $card->id, 2000);
    }

    public function test_cannot_pay_credit_account_without_funds()
    {
        $user = $this->createUserWithBolsa();
        $bolsa = $user->accounts()->where('type', Account::TYPE_CASH)->firstOrFail();
        $card = Account::factory()->credit()->for($user)->create(['credit_limit' => 10000]);

        RegisterCreditExpense::execute($user->id, $card->id, 1000);

        $this->expectException(InsufficientFunds::class);

        PayCreditAccount::execute($user->id, $bolsa->id, $card->id, 500);
    }

    public function test_account_balance_reaches_zero()
    {
        $user = $this->createUserWithBolsa();
        $bolsa = $user->accounts()->where('type', Account::TYPE_CASH)->firstOrFail();

        RegisterIncome::execute($user->id, $bolsa->id, 1000);
        RegisterExpense::execute($user->id, $bolsa->id, 1000);

        $state = new FinancialStateService($user->id);

        $this->assertEquals(0, $state->getBO());
        $this->assertEquals(0, $state->getAccountBalance($bolsa->id));
    }
}
