<?php

namespace Tests\Feature\Finance;

use App\Domain\Finance\Actions\ArchiveCategory;
use App\Domain\Finance\Actions\CancelJournalEntry;
use App\Domain\Finance\Actions\CreateCategory;
use App\Domain\Finance\Actions\RegisterCreditExpense;
use App\Domain\Finance\Actions\RegisterExpense;
use App\Domain\Finance\Actions\RegisterIncome;
use App\Domain\Finance\Reports\BudgetsReport;
use App\Models\Account;
use App\Models\Category;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class BudgetsReportTest extends TestCase
{
    use RefreshDatabase;

    private function bolsaOf($user): Account
    {
        return $user->accounts()->where('type', Account::TYPE_CASH)->firstOrFail();
    }

    private function findBucket(array $buckets, string $name): ?array
    {
        foreach ($buckets as $b) {
            if ($b['name'] === $name) {
                return $b;
            }
        }
        return null;
    }

    public function test_returns_empty_buckets_when_no_categories_have_monthly_limit(): void
    {
        $user = $this->createUserWithBolsa();
        CreateCategory::execute($user->id, 'Sin límite', Category::APPLIES_EXPENSE, 'orange', 'cake');

        $report = (new BudgetsReport($user->id))->generate();

        $this->assertSame([], $report['buckets']);
        $this->assertEquals(0, $report['total_limit']);
    }

    public function test_returns_only_categories_with_monthly_limit_set(): void
    {
        $user = $this->createUserWithBolsa();
        CreateCategory::execute($user->id, 'Sin límite', Category::APPLIES_EXPENSE, 'orange', 'cake');
        CreateCategory::execute($user->id, 'Con límite', Category::APPLIES_EXPENSE, 'blue', 'truck', 1500);

        $report = (new BudgetsReport($user->id))->generate();

        $this->assertCount(1, $report['buckets']);
        $this->assertSame('Con límite', $report['buckets'][0]['name']);
        $this->assertEquals(1500, $report['buckets'][0]['monthly_limit']);
    }

    public function test_excludes_categories_with_applies_to_income(): void
    {
        $user = $this->createUserWithBolsa();
        CreateCategory::execute($user->id, 'Salario X', Category::APPLIES_INCOME, 'green', 'briefcase', 5000);
        CreateCategory::execute($user->id, 'Comida X', Category::APPLIES_EXPENSE, 'orange', 'cake', 2000);

        $report = (new BudgetsReport($user->id))->generate();

        $this->assertCount(1, $report['buckets']);
        $this->assertSame('Comida X', $report['buckets'][0]['name']);
    }

    public function test_includes_categories_with_applies_to_both(): void
    {
        $user = $this->createUserWithBolsa();
        CreateCategory::execute($user->id, 'Reembolsos X', Category::APPLIES_BOTH, 'indigo', 'credit-card', 1000);

        $report = (new BudgetsReport($user->id))->generate();

        $this->assertCount(1, $report['buckets']);
        $this->assertSame('Reembolsos X', $report['buckets'][0]['name']);
    }

    public function test_spent_sums_expense_and_credit_expense_of_current_month(): void
    {
        $user = $this->createUserWithBolsa();
        $bolsa = $this->bolsaOf($user);
        $card = Account::factory()->credit()->for($user)->create(['credit_limit' => 10000]);
        $comida = CreateCategory::execute($user->id, 'Comida X', Category::APPLIES_EXPENSE, 'orange', 'cake', 2000);

        RegisterIncome::execute($user->id, $bolsa->id, 10000);
        RegisterExpense::execute($user->id, $bolsa->id, 500, null, $comida->id);
        RegisterCreditExpense::execute($user->id, $card->id, 300, null, $comida->id);

        $report = (new BudgetsReport($user->id))->generate();

        $bucket = $this->findBucket($report['buckets'], 'Comida X');
        $this->assertEquals(800, $bucket['spent']);
        $this->assertEquals(1200, $bucket['remaining']);
        $this->assertEqualsWithDelta(40.0, $bucket['pct_consumed'], 0.01);
    }

    public function test_spent_excludes_cancelled_entries(): void
    {
        $user = $this->createUserWithBolsa();
        $bolsa = $this->bolsaOf($user);
        $comida = CreateCategory::execute($user->id, 'Comida X', Category::APPLIES_EXPENSE, 'orange', 'cake', 2000);
        RegisterIncome::execute($user->id, $bolsa->id, 10000);

        $kept = RegisterExpense::execute($user->id, $bolsa->id, 200, null, $comida->id);
        $cancel = RegisterExpense::execute($user->id, $bolsa->id, 999, null, $comida->id);
        CancelJournalEntry::execute($user->id, $cancel->id);

        $report = (new BudgetsReport($user->id))->generate();

        $this->assertEquals(200, $report['buckets'][0]['spent']);
    }

    public function test_spent_excludes_entries_from_previous_months(): void
    {
        $user = $this->createUserWithBolsa();
        $bolsa = $this->bolsaOf($user);
        $comida = CreateCategory::execute($user->id, 'Comida X', Category::APPLIES_EXPENSE, 'orange', 'cake', 2000);
        RegisterIncome::execute($user->id, $bolsa->id, 10000);

        $current = RegisterExpense::execute($user->id, $bolsa->id, 300, null, $comida->id);
        $old = RegisterExpense::execute($user->id, $bolsa->id, 800, null, $comida->id);
        $old->forceFill(['occurred_at' => now()->subMonths(2)->startOfMonth()])->save();

        $report = (new BudgetsReport($user->id))->generate();

        $this->assertEquals(300, $report['buckets'][0]['spent']);
    }

    public function test_excludes_archived_categories(): void
    {
        $user = $this->createUserWithBolsa();
        $comida = CreateCategory::execute($user->id, 'Comida X', Category::APPLIES_EXPENSE, 'orange', 'cake', 1500);
        ArchiveCategory::execute($user->id, $comida->id);

        $report = (new BudgetsReport($user->id))->generate();

        $this->assertSame([], $report['buckets']);
    }

    public function test_orders_buckets_by_pct_consumed_desc(): void
    {
        $user = $this->createUserWithBolsa();
        $bolsa = $this->bolsaOf($user);
        $a = CreateCategory::execute($user->id, 'A poco usada', Category::APPLIES_EXPENSE, 'orange', 'cake', 1000);
        $b = CreateCategory::execute($user->id, 'B casi al tope', Category::APPLIES_EXPENSE, 'blue', 'truck', 500);
        $c = CreateCategory::execute($user->id, 'C media', Category::APPLIES_EXPENSE, 'red', 'heart', 1000);
        RegisterIncome::execute($user->id, $bolsa->id, 10000);

        RegisterExpense::execute($user->id, $bolsa->id, 100, null, $a->id); // 10%
        RegisterExpense::execute($user->id, $bolsa->id, 450, null, $b->id); // 90%
        RegisterExpense::execute($user->id, $bolsa->id, 500, null, $c->id); // 50%

        $report = (new BudgetsReport($user->id))->generate();

        $names = array_column($report['buckets'], 'name');
        $this->assertSame(['B casi al tope', 'C media', 'A poco usada'], $names);
    }

    public function test_scope_is_per_user(): void
    {
        $userA = $this->createUserWithBolsa();
        $userB = $this->createUserWithBolsa();
        CreateCategory::execute($userA->id, 'Comida A', Category::APPLIES_EXPENSE, 'orange', 'cake', 1000);
        CreateCategory::execute($userB->id, 'Comida B', Category::APPLIES_EXPENSE, 'orange', 'cake', 1000);

        $report = (new BudgetsReport($userA->id))->generate();

        $this->assertCount(1, $report['buckets']);
        $this->assertSame('Comida A', $report['buckets'][0]['name']);
    }
}
