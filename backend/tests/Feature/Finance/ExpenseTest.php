<?php

namespace Tests\Feature\Finance;

use App\Domain\Finance\Actions\CreateCategory;
use App\Domain\Finance\Actions\PayCreditAccount;
use App\Domain\Finance\Actions\RegisterCreditExpense;
use App\Domain\Finance\Actions\RegisterExpense;
use App\Domain\Finance\Actions\RegisterIncome;
use App\Domain\Finance\Exceptions\InvalidCategoryAppliesTo;
use App\Domain\Finance\Exceptions\OverpayDebt;
use App\Domain\Finance\Services\FinancialStateService;
use App\Models\Account;
use App\Models\Category;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class ExpenseTest extends TestCase
{
    use RefreshDatabase;

    public function test_spending_more_than_balance_leaves_negative()
    {
        // Libreta libre: el gasto se acepta y la cuenta queda con saldo negativo.
        $user = $this->createUserWithBolsa();
        $bolsa = $user->accounts()->where('type', Account::TYPE_CASH)->firstOrFail();

        RegisterIncome::execute($user->id, $bolsa->id, 1000);
        RegisterExpense::execute($user->id, $bolsa->id, 1500);

        $state = new FinancialStateService($user->id);
        $this->assertEquals(-500, $state->getAccountBalance($bolsa->id));
        $this->assertEquals(-500, $state->getBO());
    }

    public function test_cannot_overpay_credit_card()
    {
        // Sí queda bloqueado: pagar más que la deuda dejaría saldo a favor en
        // la tarjeta, lo cual no tiene sentido contable para la libreta personal.
        $user = $this->createUserWithBolsa();
        $bolsa = $user->accounts()->where('type', Account::TYPE_CASH)->firstOrFail();
        $card = Account::factory()->credit()->for($user)->create(['credit_limit' => 10000]);

        RegisterIncome::execute($user->id, $bolsa->id, 5000);
        RegisterCreditExpense::execute($user->id, $card->id, 1000);

        $this->expectException(OverpayDebt::class);

        PayCreditAccount::execute($user->id, $bolsa->id, $card->id, 2000);
    }

    public function test_paying_credit_without_funds_leaves_origin_negative()
    {
        $user = $this->createUserWithBolsa();
        $bolsa = $user->accounts()->where('type', Account::TYPE_CASH)->firstOrFail();
        $card = Account::factory()->credit()->for($user)->create(['credit_limit' => 10000]);

        RegisterCreditExpense::execute($user->id, $card->id, 1000);
        PayCreditAccount::execute($user->id, $bolsa->id, $card->id, 500);

        $state = new FinancialStateService($user->id);
        $this->assertEquals(-500, $state->getAccountBalance($bolsa->id));
        $this->assertEquals(500, $state->getAccountBalance($card->id));
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

    public function test_expense_with_expense_category_persists_link()
    {
        $user = $this->createUserWithBolsa();
        $bolsa = $user->accounts()->where('type', Account::TYPE_CASH)->firstOrFail();
        RegisterIncome::execute($user->id, $bolsa->id, 1000);
        $category = CreateCategory::execute($user->id, 'Comida X', Category::APPLIES_EXPENSE, 'orange', 'cake');

        $entry = RegisterExpense::execute($user->id, $bolsa->id, 200, 'comida', $category->id);

        $this->assertSame($category->id, $entry->category_id);
    }

    public function test_expense_rejects_income_only_category()
    {
        $user = $this->createUserWithBolsa();
        $bolsa = $user->accounts()->where('type', Account::TYPE_CASH)->firstOrFail();
        RegisterIncome::execute($user->id, $bolsa->id, 1000);
        $category = CreateCategory::execute($user->id, 'Salario X', Category::APPLIES_INCOME, 'green', 'briefcase');

        $this->expectException(InvalidCategoryAppliesTo::class);

        RegisterExpense::execute($user->id, $bolsa->id, 200, null, $category->id);
    }
}
