<?php

namespace Tests\Feature\Finance;

use App\Domain\Finance\Actions\ArchiveCategory;
use App\Domain\Finance\Actions\CancelJournalEntry;
use App\Domain\Finance\Actions\CreateCategory;
use App\Domain\Finance\Actions\RegisterCreditExpense;
use App\Domain\Finance\Actions\RegisterExpense;
use App\Domain\Finance\Actions\RegisterIncome;
use App\Domain\Finance\Reports\CategoryBreakdownReport;
use App\Models\Account;
use App\Models\Category;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class CategoryBreakdownReportTest extends TestCase
{
    use RefreshDatabase;

    /** Helper: registra income + expense con categoría dada. */
    private function spendInCategory($user, $bolsaId, Category $category, float $amount): void
    {
        RegisterExpense::execute($user->id, $bolsaId, $amount, null, $category->id);
    }

    private function fund($user, $bolsaId, float $amount): void
    {
        RegisterIncome::execute($user->id, $bolsaId, $amount);
    }

    public function test_groups_expense_entries_by_category(): void
    {
        $user = $this->createUserWithBolsa();
        $bolsa = $user->accounts()->where('type', Account::TYPE_CASH)->firstOrFail();
        $comida = CreateCategory::execute($user->id, 'Comida X', Category::APPLIES_EXPENSE, 'orange', 'cake');
        $transporte = CreateCategory::execute($user->id, 'Transporte X', Category::APPLIES_EXPENSE, 'blue', 'truck');

        $this->fund($user, $bolsa->id, 10000);
        $this->spendInCategory($user, $bolsa->id, $comida, 800);
        $this->spendInCategory($user, $bolsa->id, $comida, 200);
        $this->spendInCategory($user, $bolsa->id, $transporte, 500);

        $report = (new CategoryBreakdownReport($user->id))->generate(
            'expense', null, '2000-01-01', '2099-12-31'
        );

        $this->assertEquals(1500, $report['total']);
        $this->assertEquals(3, $report['count']);
        $this->assertCount(2, $report['buckets']);

        $first = $report['buckets'][0];
        $this->assertSame('Comida X', $first['name']);
        $this->assertEquals(1000, $first['total']);
        $this->assertEquals(2, $first['count']);

        $second = $report['buckets'][1];
        $this->assertSame('Transporte X', $second['name']);
        $this->assertEquals(500, $second['total']);
    }

    public function test_includes_credit_expense_when_kind_is_expense(): void
    {
        $user = $this->createUserWithBolsa();
        $card = Account::factory()->credit()->for($user)->create(['credit_limit' => 10000]);
        $compras = CreateCategory::execute($user->id, 'Compras X', Category::APPLIES_EXPENSE, 'purple', 'shopping-bag');

        RegisterCreditExpense::execute($user->id, $card->id, 1200, 'Costco', $compras->id);

        $report = (new CategoryBreakdownReport($user->id))->generate(
            'expense', null, '2000-01-01', '2099-12-31'
        );

        $this->assertEquals(1200, $report['total']);
        $this->assertSame('Compras X', $report['buckets'][0]['name']);
    }

    public function test_excludes_credit_expense_when_kind_is_income(): void
    {
        $user = $this->createUserWithBolsa();
        $card = Account::factory()->credit()->for($user)->create(['credit_limit' => 10000]);
        $compras = CreateCategory::execute($user->id, 'Compras X', Category::APPLIES_EXPENSE, 'purple', 'shopping-bag');
        RegisterCreditExpense::execute($user->id, $card->id, 1200, null, $compras->id);

        $report = (new CategoryBreakdownReport($user->id))->generate(
            'income', null, '2000-01-01', '2099-12-31'
        );

        $this->assertEquals(0, $report['total']);
        $this->assertCount(0, $report['buckets']);
    }

    public function test_entries_without_category_appear_as_sin_categorizar(): void
    {
        $user = $this->createUserWithBolsa();
        $bolsa = $user->accounts()->where('type', Account::TYPE_CASH)->firstOrFail();
        $this->fund($user, $bolsa->id, 5000);

        RegisterExpense::execute($user->id, $bolsa->id, 350); // sin categoría

        $report = (new CategoryBreakdownReport($user->id))->generate(
            'expense', null, '2000-01-01', '2099-12-31'
        );

        $this->assertCount(1, $report['buckets']);
        $this->assertNull($report['buckets'][0]['category_id']);
        $this->assertSame('Sin categorizar', $report['buckets'][0]['name']);
        $this->assertEquals(350, $report['buckets'][0]['total']);
    }

    public function test_archived_category_preserves_name_in_report(): void
    {
        $user = $this->createUserWithBolsa();
        $bolsa = $user->accounts()->where('type', Account::TYPE_CASH)->firstOrFail();
        $temp = CreateCategory::execute($user->id, 'Temporal X', Category::APPLIES_EXPENSE, 'pink', 'sparkles');
        $this->fund($user, $bolsa->id, 5000);
        $this->spendInCategory($user, $bolsa->id, $temp, 200);

        ArchiveCategory::execute($user->id, $temp->id);

        $report = (new CategoryBreakdownReport($user->id))->generate(
            'expense', null, '2000-01-01', '2099-12-31'
        );

        // El bucket sigue mostrando el nombre y los slugs originales.
        $this->assertSame('Temporal X', $report['buckets'][0]['name']);
        $this->assertSame('pink', $report['buckets'][0]['color_slug']);
        $this->assertSame('sparkles', $report['buckets'][0]['icon_slug']);
    }

    public function test_filters_by_account_for_expense(): void
    {
        $user = $this->createUserWithBolsa();
        $bolsa = $user->accounts()->where('type', Account::TYPE_CASH)->firstOrFail();
        $debit = Account::factory()->debit()->for($user)->create();
        $comida = CreateCategory::execute($user->id, 'Comida X', Category::APPLIES_EXPENSE, 'orange', 'cake');
        $this->fund($user, $bolsa->id, 5000);
        $this->fund($user, $debit->id, 5000);
        $this->spendInCategory($user, $bolsa->id, $comida, 400);
        $this->spendInCategory($user, $debit->id, $comida, 100);

        $reportBolsa = (new CategoryBreakdownReport($user->id))->generate(
            'expense', $bolsa->id, '2000-01-01', '2099-12-31'
        );

        $this->assertEquals(400, $reportBolsa['total']);
        $this->assertEquals(1, $reportBolsa['count']);
    }

    public function test_filters_by_date_range(): void
    {
        $user = $this->createUserWithBolsa();
        $bolsa = $user->accounts()->where('type', Account::TYPE_CASH)->firstOrFail();
        $comida = CreateCategory::execute($user->id, 'Comida X', Category::APPLIES_EXPENSE, 'orange', 'cake');
        $this->fund($user, $bolsa->id, 5000);

        $this->spendInCategory($user, $bolsa->id, $comida, 200);
        // Movimiento "antiguo" - lo creamos y luego forzamos occurred_at.
        $oldEntry = RegisterExpense::execute($user->id, $bolsa->id, 999, null, $comida->id);
        $oldEntry->forceFill(['occurred_at' => '2020-01-15 10:00:00'])->save();

        $today = now()->toDateString();
        $report = (new CategoryBreakdownReport($user->id))->generate(
            'expense', null, $today, $today
        );

        $this->assertEquals(200, $report['total']);
    }

    public function test_cancelled_entries_are_excluded(): void
    {
        $user = $this->createUserWithBolsa();
        $bolsa = $user->accounts()->where('type', Account::TYPE_CASH)->firstOrFail();
        $comida = CreateCategory::execute($user->id, 'Comida X', Category::APPLIES_EXPENSE, 'orange', 'cake');
        $this->fund($user, $bolsa->id, 5000);

        $keep = RegisterExpense::execute($user->id, $bolsa->id, 300, null, $comida->id);
        $cancel = RegisterExpense::execute($user->id, $bolsa->id, 200, null, $comida->id);
        CancelJournalEntry::execute($user->id, $cancel->id);

        $report = (new CategoryBreakdownReport($user->id))->generate(
            'expense', null, '2000-01-01', '2099-12-31'
        );

        $this->assertEquals(300, $report['total']);
        $this->assertEquals(1, $report['count']);
    }

    public function test_scope_is_per_user(): void
    {
        $userA = $this->createUserWithBolsa();
        $userB = $this->createUserWithBolsa();
        $bolsaA = $userA->accounts()->where('type', Account::TYPE_CASH)->firstOrFail();
        $bolsaB = $userB->accounts()->where('type', Account::TYPE_CASH)->firstOrFail();
        RegisterIncome::execute($userA->id, $bolsaA->id, 5000);
        RegisterIncome::execute($userB->id, $bolsaB->id, 5000);
        RegisterExpense::execute($userA->id, $bolsaA->id, 100);
        RegisterExpense::execute($userB->id, $bolsaB->id, 999);

        $reportA = (new CategoryBreakdownReport($userA->id))->generate(
            'expense', null, '2000-01-01', '2099-12-31'
        );

        $this->assertEquals(100, $reportA['total']);
    }
}
