<?php

namespace Tests\Feature\Finance;

use App\Domain\Finance\Actions\CreateCategory;
use App\Domain\Finance\Actions\PayCreditAccount;
use App\Domain\Finance\Actions\RegisterCreditExpense;
use App\Domain\Finance\Actions\RegisterExpense;
use App\Domain\Finance\Actions\RegisterIncome;
use App\Domain\Finance\Actions\RegisterTransfer;
use App\Domain\Finance\Actions\UpdateJournalEntry;
use App\Domain\Finance\Exceptions\ImmutableJournalField;
use App\Domain\Finance\Exceptions\InvalidAccountType;
use App\Domain\Finance\Exceptions\InvalidCategoryAppliesTo;
use App\Models\Account;
use App\Models\Category;
use Illuminate\Database\Eloquent\ModelNotFoundException;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class UpdateJournalEntryTest extends TestCase
{
    use RefreshDatabase;

    public function test_updates_category_id_on_existing_entry(): void
    {
        $user = $this->createUserWithBolsa();
        $bolsa = $user->accounts()->where('type', Account::TYPE_CASH)->firstOrFail();
        RegisterIncome::execute($user->id, $bolsa->id, 1000);
        $entry = RegisterExpense::execute($user->id, $bolsa->id, 80);

        $category = CreateCategory::execute($user->id, 'Café', Category::APPLIES_EXPENSE, 'orange', 'cake');

        $updated = UpdateJournalEntry::execute($user->id, $entry->id, ['category_id' => $category->id]);

        $this->assertSame($category->id, $updated->category_id);
    }

    public function test_updates_description(): void
    {
        $user = $this->createUserWithBolsa();
        $bolsa = $user->accounts()->where('type', Account::TYPE_CASH)->firstOrFail();
        RegisterIncome::execute($user->id, $bolsa->id, 1000);
        $entry = RegisterExpense::execute($user->id, $bolsa->id, 80, 'original');

        $updated = UpdateJournalEntry::execute($user->id, $entry->id, ['description' => '  cappuccino  ']);

        $this->assertSame('cappuccino', $updated->description);
    }

    public function test_clearing_description_with_null(): void
    {
        $user = $this->createUserWithBolsa();
        $bolsa = $user->accounts()->where('type', Account::TYPE_CASH)->firstOrFail();
        RegisterIncome::execute($user->id, $bolsa->id, 1000);
        $entry = RegisterExpense::execute($user->id, $bolsa->id, 80, 'algo');

        $updated = UpdateJournalEntry::execute($user->id, $entry->id, ['description' => null]);

        $this->assertNull($updated->description);
    }

    public function test_clearing_category_with_null(): void
    {
        $user = $this->createUserWithBolsa();
        $bolsa = $user->accounts()->where('type', Account::TYPE_CASH)->firstOrFail();
        RegisterIncome::execute($user->id, $bolsa->id, 1000);
        $category = CreateCategory::execute($user->id, 'Café', Category::APPLIES_EXPENSE, 'orange', 'cake');
        $entry = RegisterExpense::execute($user->id, $bolsa->id, 80, null, $category->id);

        $updated = UpdateJournalEntry::execute($user->id, $entry->id, ['category_id' => null]);

        $this->assertNull($updated->category_id);
    }

    public function test_rejects_immutable_fields(): void
    {
        $user = $this->createUserWithBolsa();
        $bolsa = $user->accounts()->where('type', Account::TYPE_CASH)->firstOrFail();
        RegisterIncome::execute($user->id, $bolsa->id, 1000);
        $entry = RegisterExpense::execute($user->id, $bolsa->id, 80);

        foreach (['kind'] as $field) {
            try {
                UpdateJournalEntry::execute($user->id, $entry->id, [$field => 'cualquier-cosa']);
                $this->fail("Esperaba ImmutableJournalField al editar {$field}");
            } catch (ImmutableJournalField) {
                $this->assertTrue(true);
            }
        }
    }

    public function test_rejects_category_with_wrong_applies_to(): void
    {
        $user = $this->createUserWithBolsa();
        $bolsa = $user->accounts()->where('type', Account::TYPE_CASH)->firstOrFail();
        RegisterIncome::execute($user->id, $bolsa->id, 1000);
        $entry = RegisterExpense::execute($user->id, $bolsa->id, 80);

        // Categoría sólo de ingreso → no aplica al expense.
        $incomeCategory = CreateCategory::execute($user->id, 'Salario X', Category::APPLIES_INCOME, 'green', 'briefcase');

        $this->expectException(InvalidCategoryAppliesTo::class);

        UpdateJournalEntry::execute($user->id, $entry->id, ['category_id' => $incomeCategory->id]);
    }

    public function test_accepts_both_category_on_expense(): void
    {
        $user = $this->createUserWithBolsa();
        $bolsa = $user->accounts()->where('type', Account::TYPE_CASH)->firstOrFail();
        RegisterIncome::execute($user->id, $bolsa->id, 1000);
        $entry = RegisterExpense::execute($user->id, $bolsa->id, 80);

        $bothCategory = CreateCategory::execute($user->id, 'Reembolso X', Category::APPLIES_BOTH, 'indigo', 'credit-card');

        $updated = UpdateJournalEntry::execute($user->id, $entry->id, ['category_id' => $bothCategory->id]);

        $this->assertSame($bothCategory->id, $updated->category_id);
    }

    public function test_can_move_occurred_at_to_the_past(): void
    {
        $user = $this->createUserWithBolsa();
        $bolsa = $user->accounts()->where('type', Account::TYPE_CASH)->firstOrFail();
        RegisterIncome::execute($user->id, $bolsa->id, 1000);
        $entry = RegisterExpense::execute($user->id, $bolsa->id, 80);

        $updated = UpdateJournalEntry::execute($user->id, $entry->id, ['occurred_at' => '2024-01-15']);

        $this->assertSame('2024-01-15', $updated->occurred_at->format('Y-m-d'));
    }

    public function test_can_move_occurred_at_to_the_future(): void
    {
        $user = $this->createUserWithBolsa();
        $bolsa = $user->accounts()->where('type', Account::TYPE_CASH)->firstOrFail();
        RegisterIncome::execute($user->id, $bolsa->id, 1000);
        $entry = RegisterExpense::execute($user->id, $bolsa->id, 80);

        // Libreta libre: futuro permitido (sirve, p.ej., para movimientos programados).
        $updated = UpdateJournalEntry::execute($user->id, $entry->id, ['occurred_at' => '2099-12-31']);

        $this->assertSame('2099-12-31', $updated->occurred_at->format('Y-m-d'));
    }

    public function test_rejects_invalid_occurred_at(): void
    {
        $user = $this->createUserWithBolsa();
        $bolsa = $user->accounts()->where('type', Account::TYPE_CASH)->firstOrFail();
        RegisterIncome::execute($user->id, $bolsa->id, 1000);
        $entry = RegisterExpense::execute($user->id, $bolsa->id, 80);

        $this->expectException(ImmutableJournalField::class);

        UpdateJournalEntry::execute($user->id, $entry->id, ['occurred_at' => 'no-es-fecha']);
    }

    public function test_rejects_null_occurred_at(): void
    {
        $user = $this->createUserWithBolsa();
        $bolsa = $user->accounts()->where('type', Account::TYPE_CASH)->firstOrFail();
        RegisterIncome::execute($user->id, $bolsa->id, 1000);
        $entry = RegisterExpense::execute($user->id, $bolsa->id, 80);

        $this->expectException(ImmutableJournalField::class);

        UpdateJournalEntry::execute($user->id, $entry->id, ['occurred_at' => null]);
    }

    public function test_can_recategorize_credit_expense(): void
    {
        // Regresión: el método appliesToKind() compara contra income/expense/both,
        // pero el kind del entry es 'credit_expense'. Sin mapeo, editar un cargo a
        // tarjeta tirando una categoría de gasto válida disparaba InvalidCategoryAppliesTo.
        $user = $this->createUserWithBolsa();
        $card = Account::factory()->credit()->for($user)->create([
            'credit_limit' => 10000,
            'closing_day' => 10,
            'payment_day' => 25,
        ]);
        $entry = RegisterCreditExpense::execute($user->id, $card->id, 500);

        $category = CreateCategory::execute($user->id, 'Supermercado', Category::APPLIES_EXPENSE, 'orange', 'cake');

        $updated = UpdateJournalEntry::execute($user->id, $entry->id, ['category_id' => $category->id]);

        $this->assertSame($category->id, $updated->category_id);
    }

    public function test_credit_expense_rejects_income_only_category(): void
    {
        $user = $this->createUserWithBolsa();
        $card = Account::factory()->credit()->for($user)->create([
            'credit_limit' => 10000,
            'closing_day' => 10,
            'payment_day' => 25,
        ]);
        $entry = RegisterCreditExpense::execute($user->id, $card->id, 500);

        $incomeOnly = CreateCategory::execute($user->id, 'Nómina', Category::APPLIES_INCOME, 'green', 'briefcase');

        $this->expectException(InvalidCategoryAppliesTo::class);

        UpdateJournalEntry::execute($user->id, $entry->id, ['category_id' => $incomeOnly->id]);
    }

    public function test_transfer_cannot_be_categorized(): void
    {
        $user = $this->createUserWithBolsa();
        $bolsa = $user->accounts()->where('type', Account::TYPE_CASH)->firstOrFail();
        $debit = Account::factory()->debit()->for($user)->create();
        RegisterIncome::execute($user->id, $bolsa->id, 1000);
        $entry = RegisterTransfer::execute($user->id, $bolsa->id, $debit->id, 200);

        $category = CreateCategory::execute($user->id, 'Cualquiera', Category::APPLIES_BOTH, 'indigo', 'credit-card');

        $this->expectException(InvalidCategoryAppliesTo::class);

        UpdateJournalEntry::execute($user->id, $entry->id, ['category_id' => $category->id]);
    }

    public function test_debt_payment_cannot_be_categorized(): void
    {
        $user = $this->createUserWithBolsa();
        $bolsa = $user->accounts()->where('type', Account::TYPE_CASH)->firstOrFail();
        $card = Account::factory()->credit()->for($user)->create([
            'credit_limit' => 10000,
            'closing_day' => 10,
            'payment_day' => 25,
        ]);
        RegisterIncome::execute($user->id, $bolsa->id, 1000);
        RegisterCreditExpense::execute($user->id, $card->id, 500);
        $entry = PayCreditAccount::execute($user->id, $bolsa->id, $card->id, 200);

        $category = CreateCategory::execute($user->id, 'Cualquiera', Category::APPLIES_BOTH, 'indigo', 'credit-card');

        $this->expectException(InvalidCategoryAppliesTo::class);

        UpdateJournalEntry::execute($user->id, $entry->id, ['category_id' => $category->id]);
    }

    public function test_can_move_expense_origin_to_another_cash_account(): void
    {
        $user = $this->createUserWithBolsa();
        $bolsa = $user->accounts()->where('type', Account::TYPE_CASH)->firstOrFail();
        $debit = Account::factory()->debit()->for($user)->create();
        RegisterIncome::execute($user->id, $bolsa->id, 1000);
        RegisterIncome::execute($user->id, $debit->id, 1000);
        $entry = RegisterExpense::execute($user->id, $bolsa->id, 80, 'compra mal asignada');

        $updated = UpdateJournalEntry::execute($user->id, $entry->id, [
            'account_origin_id' => $debit->id,
        ]);

        $this->assertSame($debit->id, $updated->account_origin_id);
        $this->assertNull($updated->account_destination_id);
    }

    public function test_can_move_credit_expense_to_another_credit_card(): void
    {
        $user = $this->createUserWithBolsa();
        $visa = Account::factory()->credit()->for($user)->create([
            'credit_limit' => 10000,
            'closing_day' => 5,
            'payment_day' => 20,
        ]);
        $master = Account::factory()->credit()->for($user)->create([
            'credit_limit' => 10000,
            'closing_day' => 10,
            'payment_day' => 25,
        ]);
        $entry = RegisterCreditExpense::execute($user->id, $visa->id, 500);

        $updated = UpdateJournalEntry::execute($user->id, $entry->id, [
            'account_origin_id' => $master->id,
        ]);

        $this->assertSame($master->id, $updated->account_origin_id);
    }

    public function test_can_swap_both_sides_of_a_transfer(): void
    {
        $user = $this->createUserWithBolsa();
        $bolsa = $user->accounts()->where('type', Account::TYPE_CASH)->firstOrFail();
        $banamex = Account::factory()->debit()->for($user)->create();
        $santander = Account::factory()->debit()->for($user)->create();
        RegisterIncome::execute($user->id, $bolsa->id, 1000);
        $entry = RegisterTransfer::execute($user->id, $bolsa->id, $banamex->id, 200);

        $updated = UpdateJournalEntry::execute($user->id, $entry->id, [
            'account_origin_id' => $banamex->id,
            'account_destination_id' => $santander->id,
        ]);

        $this->assertSame($banamex->id, $updated->account_origin_id);
        $this->assertSame($santander->id, $updated->account_destination_id);
    }

    public function test_rejects_expense_pointing_to_credit_account(): void
    {
        $user = $this->createUserWithBolsa();
        $bolsa = $user->accounts()->where('type', Account::TYPE_CASH)->firstOrFail();
        $card = Account::factory()->credit()->for($user)->create([
            'credit_limit' => 10000,
            'closing_day' => 5,
            'payment_day' => 20,
        ]);
        RegisterIncome::execute($user->id, $bolsa->id, 1000);
        $entry = RegisterExpense::execute($user->id, $bolsa->id, 80);

        $this->expectException(InvalidAccountType::class);

        UpdateJournalEntry::execute($user->id, $entry->id, [
            'account_origin_id' => $card->id,
        ]);
    }

    public function test_rejects_transfer_to_same_account(): void
    {
        $user = $this->createUserWithBolsa();
        $bolsa = $user->accounts()->where('type', Account::TYPE_CASH)->firstOrFail();
        $debit = Account::factory()->debit()->for($user)->create();
        RegisterIncome::execute($user->id, $bolsa->id, 1000);
        $entry = RegisterTransfer::execute($user->id, $bolsa->id, $debit->id, 200);

        $this->expectException(InvalidAccountType::class);

        UpdateJournalEntry::execute($user->id, $entry->id, [
            'account_destination_id' => $bolsa->id,
        ]);
    }

    public function test_rejects_assignment_to_account_of_other_user(): void
    {
        $userA = $this->createUserWithBolsa();
        $userB = $this->createUserWithBolsa();
        $bolsaA = $userA->accounts()->where('type', Account::TYPE_CASH)->firstOrFail();
        $debitB = Account::factory()->debit()->for($userB)->create();
        RegisterIncome::execute($userA->id, $bolsaA->id, 1000);
        $entry = RegisterExpense::execute($userA->id, $bolsaA->id, 80);

        $this->expectException(InvalidAccountType::class);

        UpdateJournalEntry::execute($userA->id, $entry->id, [
            'account_origin_id' => $debitB->id,
        ]);
    }

    public function test_can_edit_amount(): void
    {
        $user = $this->createUserWithBolsa();
        $bolsa = $user->accounts()->where('type', Account::TYPE_CASH)->firstOrFail();
        RegisterIncome::execute($user->id, $bolsa->id, 1000);
        $entry = RegisterExpense::execute($user->id, $bolsa->id, 80);

        $updated = UpdateJournalEntry::execute($user->id, $entry->id, ['amount' => 120.50]);

        $this->assertEquals(120.50, $updated->amount);
    }

    public function test_rejects_zero_amount(): void
    {
        $user = $this->createUserWithBolsa();
        $bolsa = $user->accounts()->where('type', Account::TYPE_CASH)->firstOrFail();
        RegisterIncome::execute($user->id, $bolsa->id, 1000);
        $entry = RegisterExpense::execute($user->id, $bolsa->id, 80);

        $this->expectException(ImmutableJournalField::class);

        UpdateJournalEntry::execute($user->id, $entry->id, ['amount' => 0]);
    }

    public function test_rejects_negative_amount(): void
    {
        $user = $this->createUserWithBolsa();
        $bolsa = $user->accounts()->where('type', Account::TYPE_CASH)->firstOrFail();
        RegisterIncome::execute($user->id, $bolsa->id, 1000);
        $entry = RegisterExpense::execute($user->id, $bolsa->id, 80);

        $this->expectException(ImmutableJournalField::class);

        UpdateJournalEntry::execute($user->id, $entry->id, ['amount' => -50]);
    }

    public function test_cannot_update_other_users_entry(): void
    {
        $userA = $this->createUserWithBolsa();
        $userB = $this->createUserWithBolsa();
        $bolsaA = $userA->accounts()->where('type', Account::TYPE_CASH)->firstOrFail();
        RegisterIncome::execute($userA->id, $bolsaA->id, 1000);
        $entry = RegisterExpense::execute($userA->id, $bolsaA->id, 80);

        $this->expectException(ModelNotFoundException::class);

        UpdateJournalEntry::execute($userB->id, $entry->id, ['description' => 'hackeado']);
    }
}
