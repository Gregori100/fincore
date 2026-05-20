<?php

namespace Tests\Feature\Finance;

use App\Domain\Finance\Actions\CreateCategory;
use App\Domain\Finance\Actions\RegisterExpense;
use App\Domain\Finance\Actions\RegisterIncome;
use App\Domain\Finance\Exceptions\InvalidCategoryAppliesTo;
use App\Domain\Finance\Services\FinancialStateService;
use App\Models\Account;
use App\Models\Category;
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

    public function test_spending_more_than_balance_is_allowed_and_goes_negative()
    {
        $user = $this->createUserWithBolsa();
        $bolsa = $user->accounts()->where('type', Account::TYPE_CASH)->firstOrFail();

        RegisterIncome::execute($user->id, $bolsa->id, 1000);
        RegisterExpense::execute($user->id, $bolsa->id, 2000);

        $state = new FinancialStateService($user->id);
        $this->assertEquals(-1000, $state->getAccountBalance($bolsa->id));
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

    public function test_income_with_income_category_persists_link()
    {
        $user = $this->createUserWithBolsa();
        $bolsa = $user->accounts()->where('type', Account::TYPE_CASH)->firstOrFail();
        $category = CreateCategory::execute($user->id, 'Salario X', Category::APPLIES_INCOME, 'green', 'briefcase');

        $entry = RegisterIncome::execute($user->id, $bolsa->id, 5000, 'Nómina', $category->id);

        $this->assertSame($category->id, $entry->category_id);
    }

    public function test_income_rejects_expense_only_category()
    {
        $user = $this->createUserWithBolsa();
        $bolsa = $user->accounts()->where('type', Account::TYPE_CASH)->firstOrFail();
        $category = CreateCategory::execute($user->id, 'Comida X', Category::APPLIES_EXPENSE, 'orange', 'cake');

        $this->expectException(InvalidCategoryAppliesTo::class);

        RegisterIncome::execute($user->id, $bolsa->id, 5000, null, $category->id);
    }

    public function test_income_accepts_both_category()
    {
        $user = $this->createUserWithBolsa();
        $bolsa = $user->accounts()->where('type', Account::TYPE_CASH)->firstOrFail();
        $category = CreateCategory::execute($user->id, 'Reembolso X', Category::APPLIES_BOTH, 'indigo', 'credit-card');

        $entry = RegisterIncome::execute($user->id, $bolsa->id, 300, null, $category->id);

        $this->assertSame($category->id, $entry->category_id);
    }
}
