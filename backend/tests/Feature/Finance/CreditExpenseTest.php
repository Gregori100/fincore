<?php

namespace Tests\Feature\Finance;

use App\Domain\Finance\Actions\CreateDebt;
use App\Domain\Finance\Actions\RegisterCreditExpense;
use App\Domain\Finance\Exceptions\CreditLimitExceeded;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class CreditExpenseTest extends TestCase
{
    use RefreshDatabase;

    public function test_credit_expense_increases_debt()
    {
        $debt = CreateDebt::execute("BBVA", 10000);

        RegisterCreditExpense::execute($debt->id, 2000);

        $this->assertEquals(2000, $debt->fresh()->current_amount);
    }

    public function test_cannot_exceed_credit_limit()
    {
        $debt = CreateDebt::execute("BBVA", 1000);

        $this->expectException(CreditLimitExceeded::class);

        RegisterCreditExpense::execute($debt->id, 2000);
    }
}
