<?php

namespace Tests\Feature\Finance;

use App\Domain\Finance\Actions\CreateDebt;
use App\Domain\Finance\Actions\PayDebt;
use App\Domain\Finance\Actions\RegisterCreditExpense;
use App\Domain\Finance\Actions\RegisterExpense;
use App\Domain\Finance\Actions\RegisterIncome;
use App\Domain\Finance\Services\FinancialStateService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class PayDebtTest extends TestCase
{
    use RefreshDatabase;

    public function test_paying_debt_reduces_bo_and_de()
    {
        $debt = CreateDebt::execute("BBVA", 10000);

        RegisterCreditExpense::execute($debt->id, 3000);
        RegisterIncome::execute(5000);

        PayDebt::execute($debt->id, 2000);

        $state = new FinancialStateService();

        $this->assertEquals(3000, $state->getBO());
        $this->assertEquals(1000, $debt->fresh()->current_amount);
    }

    public function test_burn_rate()
    {
        RegisterIncome::execute(5000);
        RegisterExpense::execute(1000);
        RegisterExpense::execute(500);

        $state = new FinancialStateService();

        $this->assertEquals(1500, $state->getMonthlyBurnRate());
    }

    public function test_credit_usage_percentage()
    {
        $bbva = CreateDebt::execute("BBVA", 10000);
        $nu   = CreateDebt::execute("NU", 10000);

        RegisterCreditExpense::execute($bbva->id, 2000);
        RegisterCreditExpense::execute($nu->id, 3000);

        $state = new FinancialStateService();

        $this->assertEquals(25, $state->getCreditUsagePercentage());
    }
}
