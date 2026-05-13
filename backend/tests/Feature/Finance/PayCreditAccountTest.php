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

    private function bolsa(): Account
    {
        return Account::where('type', Account::TYPE_CASH)->firstOrFail();
    }

    public function test_paying_credit_reduces_bo_and_de()
    {
        $bolsa = $this->bolsa();
        $card = Account::factory()->credit()->create(['credit_limit' => 10000]);

        RegisterCreditExpense::execute($card->id, 3000);
        RegisterIncome::execute($bolsa->id, 5000);

        PayCreditAccount::execute($bolsa->id, $card->id, 2000);

        $state = new FinancialStateService();

        $this->assertEquals(3000, $state->getBO());
        $this->assertEquals(1000, $state->getAccountBalance($card->id));
        $this->assertEquals(1000, $state->getDE());
    }

    public function test_burn_rate_counts_expenses_and_credit_expenses()
    {
        $bolsa = $this->bolsa();
        $card = Account::factory()->credit()->create(['credit_limit' => 10000]);

        RegisterIncome::execute($bolsa->id, 5000);
        RegisterExpense::execute($bolsa->id, 1000);
        RegisterExpense::execute($bolsa->id, 500);
        RegisterCreditExpense::execute($card->id, 800);

        $state = new FinancialStateService();

        $this->assertEquals(2300, $state->getMonthlyBurnRate());
    }

    public function test_credit_usage_percentage()
    {
        $bbva = Account::factory()->credit()->create(['credit_limit' => 10000]);
        $nu = Account::factory()->credit()->create(['credit_limit' => 10000]);

        RegisterCreditExpense::execute($bbva->id, 2000);
        RegisterCreditExpense::execute($nu->id, 3000);

        $state = new FinancialStateService();

        $this->assertEquals(25, $state->getCreditUsagePercentage());
    }
}
