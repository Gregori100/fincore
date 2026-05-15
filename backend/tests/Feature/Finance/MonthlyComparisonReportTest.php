<?php

namespace Tests\Feature\Finance;

use App\Domain\Finance\Actions\CancelJournalEntry;
use App\Domain\Finance\Actions\CreateCategory;
use App\Domain\Finance\Actions\RegisterCreditExpense;
use App\Domain\Finance\Actions\RegisterExpense;
use App\Domain\Finance\Actions\RegisterIncome;
use App\Domain\Finance\Reports\MonthlyComparisonReport;
use App\Models\Account;
use App\Models\Category;
use Carbon\CarbonImmutable;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class MonthlyComparisonReportTest extends TestCase
{
    use RefreshDatabase;

    /** Registra un expense forzando occurred_at en un mes específico. */
    private function expenseAtMonth(string $userId, string $accountId, float $amount, string $yearMonth, ?string $categoryId = null): void
    {
        $entry = RegisterExpense::execute($userId, $accountId, $amount, null, $categoryId);
        $date = CarbonImmutable::createFromFormat('Y-m', $yearMonth)->startOfMonth()->addDays(5);
        $entry->forceFill(['occurred_at' => $date])->save();
    }

    private function incomeAtMonth(string $userId, string $accountId, float $amount, string $yearMonth, ?string $categoryId = null): void
    {
        $entry = RegisterIncome::execute($userId, $accountId, $amount, null, $categoryId);
        $date = CarbonImmutable::createFromFormat('Y-m', $yearMonth)->startOfMonth()->addDays(5);
        $entry->forceFill(['occurred_at' => $date])->save();
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

    public function test_compares_totals_between_current_and_previous_month(): void
    {
        $user = $this->createUserWithBolsa();
        $bolsa = $user->accounts()->where('type', Account::TYPE_CASH)->firstOrFail();
        $comida = CreateCategory::execute($user->id, 'Comida X', Category::APPLIES_EXPENSE, 'orange', 'cake');

        // Fondear para que los gastos pasen la validación de saldo.
        RegisterIncome::execute($user->id, $bolsa->id, 100000);

        $this->expenseAtMonth($user->id, $bolsa->id, 1200, '2026-05', $comida->id);
        $this->expenseAtMonth($user->id, $bolsa->id, 1000, '2026-04', $comida->id);

        $report = (new MonthlyComparisonReport($user->id))->generate('expense', null, '2026-05');

        $this->assertSame('2026-05', $report['current_month']);
        $this->assertSame('2026-04', $report['previous_month']);
        $this->assertEqualsWithDelta(1200, $report['current_total'], 0.01);
        $this->assertEqualsWithDelta(1000, $report['previous_total'], 0.01);
        $this->assertEqualsWithDelta(200, $report['delta'], 0.01);
        $this->assertEqualsWithDelta(20, $report['delta_pct'], 0.01);

        $b = $this->findBucket($report['buckets'], 'Comida X');
        $this->assertNotNull($b);
        $this->assertEqualsWithDelta(1200, $b['current'], 0.01);
        $this->assertEqualsWithDelta(1000, $b['previous'], 0.01);
        $this->assertEqualsWithDelta(200, $b['delta'], 0.01);
        $this->assertEqualsWithDelta(20, $b['delta_pct'], 0.01);
    }

    public function test_category_with_activity_only_in_current_month_has_null_delta_pct(): void
    {
        $user = $this->createUserWithBolsa();
        $bolsa = $user->accounts()->where('type', Account::TYPE_CASH)->firstOrFail();
        $nueva = CreateCategory::execute($user->id, 'Entretenimiento X', Category::APPLIES_EXPENSE, 'purple', 'film');
        RegisterIncome::execute($user->id, $bolsa->id, 10000);

        $this->expenseAtMonth($user->id, $bolsa->id, 500, '2026-05', $nueva->id);

        $report = (new MonthlyComparisonReport($user->id))->generate('expense', null, '2026-05');

        $b = $this->findBucket($report['buckets'], 'Entretenimiento X');
        $this->assertNotNull($b);
        $this->assertEqualsWithDelta(500, $b['current'], 0.01);
        $this->assertEqualsWithDelta(0, $b['previous'], 0.01);
        $this->assertEqualsWithDelta(500, $b['delta'], 0.01);
        $this->assertNull($b['delta_pct']);
    }

    public function test_category_with_activity_only_in_previous_month_appears_with_zero_current(): void
    {
        $user = $this->createUserWithBolsa();
        $bolsa = $user->accounts()->where('type', Account::TYPE_CASH)->firstOrFail();
        $salud = CreateCategory::execute($user->id, 'Salud X', Category::APPLIES_EXPENSE, 'red', 'heart');
        RegisterIncome::execute($user->id, $bolsa->id, 10000);

        $this->expenseAtMonth($user->id, $bolsa->id, 300, '2026-04', $salud->id);

        $report = (new MonthlyComparisonReport($user->id))->generate('expense', null, '2026-05');

        $b = $this->findBucket($report['buckets'], 'Salud X');
        $this->assertNotNull($b);
        $this->assertEqualsWithDelta(0, $b['current'], 0.01);
        $this->assertEqualsWithDelta(300, $b['previous'], 0.01);
        $this->assertEqualsWithDelta(-300, $b['delta'], 0.01);
        $this->assertEqualsWithDelta(-100, $b['delta_pct'], 0.01);
    }

    public function test_total_delta_pct_is_null_when_previous_total_is_zero(): void
    {
        $user = $this->createUserWithBolsa();
        $bolsa = $user->accounts()->where('type', Account::TYPE_CASH)->firstOrFail();
        RegisterIncome::execute($user->id, $bolsa->id, 10000);
        $this->expenseAtMonth($user->id, $bolsa->id, 500, '2026-05');

        $report = (new MonthlyComparisonReport($user->id))->generate('expense', null, '2026-05');

        $this->assertEqualsWithDelta(500, $report['current_total'], 0.01);
        $this->assertEqualsWithDelta(0, $report['previous_total'], 0.01);
        $this->assertNull($report['delta_pct']);
    }

    public function test_credit_expense_counts_when_kind_is_expense(): void
    {
        $user = $this->createUserWithBolsa();
        $card = Account::factory()->credit()->for($user)->create(['credit_limit' => 10000]);
        $compras = CreateCategory::execute($user->id, 'Compras X', Category::APPLIES_EXPENSE, 'purple', 'shopping-bag');

        $entry = RegisterCreditExpense::execute($user->id, $card->id, 800, null, $compras->id);
        $entry->forceFill(['occurred_at' => CarbonImmutable::createFromFormat('Y-m', '2026-05')->startOfMonth()->addDays(3)])->save();

        $report = (new MonthlyComparisonReport($user->id))->generate('expense', null, '2026-05');

        $this->assertEqualsWithDelta(800, $report['current_total'], 0.01);
    }

    public function test_filters_by_account(): void
    {
        $user = $this->createUserWithBolsa();
        $bolsa = $user->accounts()->where('type', Account::TYPE_CASH)->firstOrFail();
        $debit = Account::factory()->debit()->for($user)->create();
        RegisterIncome::execute($user->id, $bolsa->id, 10000);
        RegisterIncome::execute($user->id, $debit->id, 10000);

        $this->expenseAtMonth($user->id, $bolsa->id, 300, '2026-05');
        $this->expenseAtMonth($user->id, $debit->id, 700, '2026-05');

        $report = (new MonthlyComparisonReport($user->id))->generate('expense', $bolsa->id, '2026-05');

        $this->assertEqualsWithDelta(300, $report['current_total'], 0.01);
    }

    public function test_cancelled_entries_are_excluded(): void
    {
        $user = $this->createUserWithBolsa();
        $bolsa = $user->accounts()->where('type', Account::TYPE_CASH)->firstOrFail();
        RegisterIncome::execute($user->id, $bolsa->id, 10000);

        $kept = RegisterExpense::execute($user->id, $bolsa->id, 200);
        $kept->forceFill(['occurred_at' => CarbonImmutable::createFromFormat('Y-m', '2026-05')->startOfMonth()->addDay()])->save();
        $cancel = RegisterExpense::execute($user->id, $bolsa->id, 1000);
        $cancel->forceFill(['occurred_at' => CarbonImmutable::createFromFormat('Y-m', '2026-05')->startOfMonth()->addDay()])->save();
        CancelJournalEntry::execute($user->id, $cancel->id);

        $report = (new MonthlyComparisonReport($user->id))->generate('expense', null, '2026-05');

        $this->assertEqualsWithDelta(200, $report['current_total'], 0.01);
    }

    public function test_scope_is_per_user(): void
    {
        $userA = $this->createUserWithBolsa();
        $userB = $this->createUserWithBolsa();
        $bolsaA = $userA->accounts()->where('type', Account::TYPE_CASH)->firstOrFail();
        $bolsaB = $userB->accounts()->where('type', Account::TYPE_CASH)->firstOrFail();
        RegisterIncome::execute($userA->id, $bolsaA->id, 10000);
        RegisterIncome::execute($userB->id, $bolsaB->id, 10000);

        $this->expenseAtMonth($userA->id, $bolsaA->id, 100, '2026-05');
        $this->expenseAtMonth($userB->id, $bolsaB->id, 999, '2026-05');

        $report = (new MonthlyComparisonReport($userA->id))->generate('expense', null, '2026-05');

        $this->assertEqualsWithDelta(100, $report['current_total'], 0.01);
    }
}
