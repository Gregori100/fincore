<?php

namespace Tests\Feature\Finance;

use App\Domain\Finance\Actions\CancelJournalEntry;
use App\Domain\Finance\Actions\PayCreditAccount;
use App\Domain\Finance\Actions\RegisterCreditExpense;
use App\Domain\Finance\Actions\RegisterExpense;
use App\Domain\Finance\Actions\RegisterIncome;
use App\Domain\Finance\Actions\RegisterTransfer;
use App\Domain\Finance\Reports\CashflowMonthlyReport;
use App\Models\Account;
use App\Models\JournalEntry;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class CashflowMonthlyReportTest extends TestCase
{
    use RefreshDatabase;

    private function thisMonthKey(): string
    {
        return now()->format('Y-m');
    }

    public function test_aggregates_income_and_expense_per_month(): void
    {
        $user = $this->createUserWithBolsa();
        $bolsa = $user->accounts()->where('type', Account::TYPE_CASH)->firstOrFail();

        RegisterIncome::execute($user->id, $bolsa->id, 5000);
        RegisterExpense::execute($user->id, $bolsa->id, 1200);
        RegisterExpense::execute($user->id, $bolsa->id, 300);

        $report = (new CashflowMonthlyReport($user->id))->generate(
            '2000-01-01', '2099-12-31', null
        );

        $this->assertCount(1, $report['months']);
        $this->assertSame($this->thisMonthKey(), $report['months'][0]['year_month']);
        $this->assertEquals(5000, $report['months'][0]['income']);
        $this->assertEquals(1500, $report['months'][0]['expense']);
        $this->assertEquals(3500, $report['months'][0]['net']);

        $this->assertEquals(5000, $report['total_income']);
        $this->assertEquals(1500, $report['total_expense']);
        $this->assertEquals(3500, $report['total_net']);
    }

    public function test_credit_expense_counts_as_expense(): void
    {
        $user = $this->createUserWithBolsa();
        $card = Account::factory()->credit()->for($user)->create(['credit_limit' => 10000]);

        RegisterCreditExpense::execute($user->id, $card->id, 1500);

        $report = (new CashflowMonthlyReport($user->id))->generate(
            '2000-01-01', '2099-12-31', null
        );

        $this->assertEquals(1500, $report['total_expense']);
        $this->assertEquals(0, $report['total_income']);
    }

    public function test_transfer_is_excluded_from_cashflow(): void
    {
        $user = $this->createUserWithBolsa();
        $bolsa = $user->accounts()->where('type', Account::TYPE_CASH)->firstOrFail();
        $debit = Account::factory()->debit()->for($user)->create();

        RegisterIncome::execute($user->id, $bolsa->id, 5000);
        RegisterTransfer::execute($user->id, $bolsa->id, $debit->id, 2000);

        $report = (new CashflowMonthlyReport($user->id))->generate(
            '2000-01-01', '2099-12-31', null
        );

        // La transferencia no debe alterar el cashflow neto del periodo.
        $this->assertEquals(5000, $report['total_income']);
        $this->assertEquals(0, $report['total_expense']);
    }

    public function test_debt_payment_is_excluded_from_cashflow(): void
    {
        $user = $this->createUserWithBolsa();
        $bolsa = $user->accounts()->where('type', Account::TYPE_CASH)->firstOrFail();
        $card = Account::factory()->credit()->for($user)->create(['credit_limit' => 10000]);

        RegisterIncome::execute($user->id, $bolsa->id, 5000);
        RegisterCreditExpense::execute($user->id, $card->id, 1000);
        PayCreditAccount::execute($user->id, $bolsa->id, $card->id, 500);

        $report = (new CashflowMonthlyReport($user->id))->generate(
            '2000-01-01', '2099-12-31', null
        );

        // Income=5000, Expense=1000 (cargo crédito); el pago a tarjeta NO suma.
        $this->assertEquals(5000, $report['total_income']);
        $this->assertEquals(1000, $report['total_expense']);
    }

    public function test_filters_by_account(): void
    {
        $user = $this->createUserWithBolsa();
        $bolsa = $user->accounts()->where('type', Account::TYPE_CASH)->firstOrFail();
        $debit = Account::factory()->debit()->for($user)->create();

        RegisterIncome::execute($user->id, $bolsa->id, 2000);
        RegisterIncome::execute($user->id, $debit->id, 3000);
        RegisterExpense::execute($user->id, $bolsa->id, 500);
        RegisterExpense::execute($user->id, $debit->id, 800);

        $report = (new CashflowMonthlyReport($user->id))->generate(
            '2000-01-01', '2099-12-31', $bolsa->id
        );

        $this->assertEquals(2000, $report['total_income']);
        $this->assertEquals(500, $report['total_expense']);
    }

    public function test_cancelled_entries_are_excluded(): void
    {
        $user = $this->createUserWithBolsa();
        $bolsa = $user->accounts()->where('type', Account::TYPE_CASH)->firstOrFail();

        RegisterIncome::execute($user->id, $bolsa->id, 5000);
        $expense = RegisterExpense::execute($user->id, $bolsa->id, 1200);
        CancelJournalEntry::execute($user->id, $expense->id);

        $report = (new CashflowMonthlyReport($user->id))->generate(
            '2000-01-01', '2099-12-31', null
        );

        $this->assertEquals(5000, $report['total_income']);
        $this->assertEquals(0, $report['total_expense']);
    }

    public function test_only_months_with_activity_are_returned(): void
    {
        $user = $this->createUserWithBolsa();
        $bolsa = $user->accounts()->where('type', Account::TYPE_CASH)->firstOrFail();

        RegisterIncome::execute($user->id, $bolsa->id, 1000);

        // Forzamos un entry en un mes distinto (manualmente).
        $entry = RegisterExpense::execute($user->id, $bolsa->id, 200);
        $entry->forceFill(['occurred_at' => '2025-01-15 10:00:00'])->save();

        $report = (new CashflowMonthlyReport($user->id))->generate(
            '2000-01-01', '2099-12-31', null
        );

        // Solo deben aparecer los meses con actividad (sin ceros intermedios).
        $this->assertCount(2, $report['months']);

        $keys = array_column($report['months'], 'year_month');
        $this->assertContains('2025-01', $keys);
        $this->assertContains($this->thisMonthKey(), $keys);
    }

    public function test_scope_is_per_user(): void
    {
        $userA = $this->createUserWithBolsa();
        $userB = $this->createUserWithBolsa();
        $bolsaA = $userA->accounts()->where('type', Account::TYPE_CASH)->firstOrFail();
        $bolsaB = $userB->accounts()->where('type', Account::TYPE_CASH)->firstOrFail();

        RegisterIncome::execute($userA->id, $bolsaA->id, 100);
        RegisterIncome::execute($userB->id, $bolsaB->id, 999);

        $reportA = (new CashflowMonthlyReport($userA->id))->generate(
            '2000-01-01', '2099-12-31', null
        );

        $this->assertEquals(100, $reportA['total_income']);
    }
}
