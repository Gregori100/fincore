<?php

namespace Tests\Feature\Finance;

use App\Domain\Finance\Actions\RegisterCreditExpense;
use App\Domain\Finance\Exceptions\CreditLimitExceeded;
use App\Domain\Finance\Exceptions\InvalidAccountType;
use App\Domain\Finance\Services\FinancialStateService;
use App\Models\Account;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class CreditExpenseTest extends TestCase
{
    use RefreshDatabase;

    public function test_credit_expense_increases_debt()
    {
        $card = Account::factory()->credit()->create(['credit_limit' => 10000]);

        RegisterCreditExpense::execute($card->id, 2000);

        $state = new FinancialStateService();
        $this->assertEquals(2000, $state->getAccountBalance($card->id));
        $this->assertEquals(2000, $state->getDE());
    }

    public function test_cannot_exceed_credit_limit()
    {
        $card = Account::factory()->credit()->create(['credit_limit' => 1000]);

        $this->expectException(CreditLimitExceeded::class);

        RegisterCreditExpense::execute($card->id, 2000);
    }

    public function test_cannot_credit_expense_on_cash_or_debit_account()
    {
        $bolsa = Account::where('type', Account::TYPE_CASH)->firstOrFail();

        $this->expectException(InvalidAccountType::class);

        RegisterCreditExpense::execute($bolsa->id, 100);
    }
}
