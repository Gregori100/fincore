<?php

namespace Tests\Feature\Finance;

use App\Domain\Finance\Actions\CreateCategory;
use App\Domain\Finance\Actions\RegisterCreditExpense;
use App\Domain\Finance\Exceptions\CreditLimitExceeded;
use App\Domain\Finance\Exceptions\InvalidAccountType;
use App\Domain\Finance\Exceptions\InvalidCategoryAppliesTo;
use App\Domain\Finance\Services\FinancialStateService;
use App\Models\Account;
use App\Models\Category;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class CreditExpenseTest extends TestCase
{
    use RefreshDatabase;

    public function test_credit_expense_increases_debt()
    {
        $user = $this->createUserWithBolsa();
        $card = Account::factory()->credit()->for($user)->create(['credit_limit' => 10000]);

        RegisterCreditExpense::execute($user->id, $card->id, 2000);

        $state = new FinancialStateService($user->id);
        $this->assertEquals(2000, $state->getAccountBalance($card->id));
        $this->assertEquals(2000, $state->getDE());
    }

    public function test_cannot_exceed_credit_limit()
    {
        $user = $this->createUserWithBolsa();
        $card = Account::factory()->credit()->for($user)->create(['credit_limit' => 1000]);

        $this->expectException(CreditLimitExceeded::class);

        RegisterCreditExpense::execute($user->id, $card->id, 2000);
    }

    public function test_cannot_credit_expense_on_cash_or_debit_account()
    {
        $user = $this->createUserWithBolsa();
        $bolsa = $user->accounts()->where('type', Account::TYPE_CASH)->firstOrFail();

        $this->expectException(InvalidAccountType::class);

        RegisterCreditExpense::execute($user->id, $bolsa->id, 100);
    }

    public function test_credit_expense_with_expense_category_persists_link()
    {
        $user = $this->createUserWithBolsa();
        $card = Account::factory()->credit()->for($user)->create(['credit_limit' => 10000]);
        $category = CreateCategory::execute($user->id, 'Compras X', Category::APPLIES_EXPENSE, 'purple', 'shopping-bag');

        $entry = RegisterCreditExpense::execute($user->id, $card->id, 800, 'Costco', $category->id);

        $this->assertSame($category->id, $entry->category_id);
    }

    public function test_credit_expense_rejects_income_only_category()
    {
        $user = $this->createUserWithBolsa();
        $card = Account::factory()->credit()->for($user)->create(['credit_limit' => 10000]);
        $category = CreateCategory::execute($user->id, 'Salario X', Category::APPLIES_INCOME, 'green', 'briefcase');

        $this->expectException(InvalidCategoryAppliesTo::class);

        RegisterCreditExpense::execute($user->id, $card->id, 800, null, $category->id);
    }
}
