<?php

namespace Tests\Feature\Finance;

use App\Domain\Finance\Actions\PayCreditAccount;
use App\Domain\Finance\Actions\RegisterCreditExpense;
use App\Domain\Finance\Actions\RegisterExpense;
use App\Domain\Finance\Actions\RegisterIncome;
use App\Domain\Finance\Services\FinancialStateService;
use App\Models\Account;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class PayCreditAccountTest extends TestCase
{
    use RefreshDatabase;

    public function test_paying_credit_reduces_bo_and_de()
    {
        $user = $this->createUserWithBolsa();
        $bolsa = $user->accounts()->where('type', Account::TYPE_CASH)->firstOrFail();
        $card = Account::factory()->credit()->for($user)->create(['credit_limit' => 10000]);

        RegisterCreditExpense::execute($user->id, $card->id, 3000);
        RegisterIncome::execute($user->id, $bolsa->id, 5000);

        PayCreditAccount::execute($user->id, $bolsa->id, $card->id, 2000);

        $state = new FinancialStateService($user->id);

        $this->assertEquals(3000, $state->getBO());
        $this->assertEquals(1000, $state->getAccountBalance($card->id));
        $this->assertEquals(1000, $state->getDE());
    }

    public function test_burn_rate_counts_expenses_and_credit_expenses()
    {
        $user = $this->createUserWithBolsa();
        $bolsa = $user->accounts()->where('type', Account::TYPE_CASH)->firstOrFail();
        $card = Account::factory()->credit()->for($user)->create(['credit_limit' => 10000]);

        RegisterIncome::execute($user->id, $bolsa->id, 5000);
        RegisterExpense::execute($user->id, $bolsa->id, 1000);
        RegisterExpense::execute($user->id, $bolsa->id, 500);
        RegisterCreditExpense::execute($user->id, $card->id, 800);

        $state = new FinancialStateService($user->id);

        $this->assertEquals(2300, $state->getMonthlyBurnRate());
    }

    public function test_credit_usage_percentage()
    {
        $user = $this->createUserWithBolsa();
        $bbva = Account::factory()->credit()->for($user)->create(['credit_limit' => 10000]);
        $nu = Account::factory()->credit()->for($user)->create(['credit_limit' => 10000]);

        RegisterCreditExpense::execute($user->id, $bbva->id, 2000);
        RegisterCreditExpense::execute($user->id, $nu->id, 3000);

        $state = new FinancialStateService($user->id);

        $this->assertEquals(25, $state->getCreditUsagePercentage());
    }
}
