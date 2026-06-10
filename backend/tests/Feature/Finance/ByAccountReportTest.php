<?php

namespace Tests\Feature\Finance;

use App\Domain\Finance\Actions\CancelJournalEntry;
use App\Domain\Finance\Actions\PayCreditAccount;
use App\Domain\Finance\Actions\RegisterCreditExpense;
use App\Domain\Finance\Actions\RegisterExpense;
use App\Domain\Finance\Actions\RegisterIncome;
use App\Domain\Finance\Actions\RegisterTransfer;
use App\Domain\Finance\Reports\ByAccountReport;
use App\Models\Account;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class ByAccountReportTest extends TestCase
{
    use RefreshDatabase;

    private function rangeAll(): array
    {
        return [now()->subYears(1)->toDateString(), now()->addYears(1)->toDateString()];
    }

    public function test_no_movements_returns_zero_for_each_account(): void
    {
        $user = $this->createUserWithBolsa();
        Account::factory()->debit()->for($user)->create(['name' => 'Banamex']);

        [$from, $to] = $this->rangeAll();
        $report = (new ByAccountReport($user->id))->generate($from, $to);

        $this->assertCount(2, $report['accounts']);
        foreach ($report['accounts'] as $row) {
            $this->assertSame(0.0, $row['income']);
            $this->assertSame(0.0, $row['expense']);
            $this->assertSame(0.0, $row['net']);
        }
    }

    public function test_income_only_aggregates_in_destination(): void
    {
        $user = $this->createUserWithBolsa();
        $bolsa = $user->accounts()->where('type', Account::TYPE_CASH)->firstOrFail();
        RegisterIncome::execute($user->id, $bolsa->id, 5000);

        [$from, $to] = $this->rangeAll();
        $report = (new ByAccountReport($user->id))->generate($from, $to);

        $row = collect($report['accounts'])->firstWhere('account_id', $bolsa->id);
        $this->assertEquals(5000.0, $row['income']);
        $this->assertEquals(0.0, $row['expense']);
        $this->assertEquals(5000.0, $row['net']);
    }

    public function test_expense_only_aggregates_in_origin(): void
    {
        $user = $this->createUserWithBolsa();
        $bolsa = $user->accounts()->where('type', Account::TYPE_CASH)->firstOrFail();
        RegisterIncome::execute($user->id, $bolsa->id, 1000);
        RegisterExpense::execute($user->id, $bolsa->id, 300);

        [$from, $to] = $this->rangeAll();
        $report = (new ByAccountReport($user->id))->generate($from, $to);

        $row = collect($report['accounts'])->firstWhere('account_id', $bolsa->id);
        $this->assertEquals(1000.0, $row['income']);
        $this->assertEquals(300.0, $row['expense']);
        $this->assertEquals(700.0, $row['net']);
    }

    public function test_transfer_aggregates_on_both_sides(): void
    {
        $user = $this->createUserWithBolsa();
        $bolsa = $user->accounts()->where('type', Account::TYPE_CASH)->firstOrFail();
        $banamex = Account::factory()->debit()->for($user)->create(['name' => 'Banamex']);
        RegisterIncome::execute($user->id, $bolsa->id, 5000);
        RegisterTransfer::execute($user->id, $bolsa->id, $banamex->id, 2000);

        [$from, $to] = $this->rangeAll();
        $report = (new ByAccountReport($user->id))->generate($from, $to);

        $rowBolsa = collect($report['accounts'])->firstWhere('account_id', $bolsa->id);
        $rowBanamex = collect($report['accounts'])->firstWhere('account_id', $banamex->id);

        $this->assertEquals(5000.0, $rowBolsa['income']);
        $this->assertEquals(2000.0, $rowBolsa['expense']);
        $this->assertEquals(2000.0, $rowBanamex['income']);
        $this->assertEquals(0.0, $rowBanamex['expense']);

        // Sum total de netos = entradas reales al user (5k) sin doble contar el transfer.
        $sumNet = array_sum(array_column($report['accounts'], 'net'));
        $this->assertEquals(5000.0, $sumNet);
    }

    public function test_debt_payment_aggregates_correctly(): void
    {
        $user = $this->createUserWithBolsa();
        $bolsa = $user->accounts()->where('type', Account::TYPE_CASH)->firstOrFail();
        $card = Account::factory()->credit()->for($user)->create(['name' => 'Visa', 'credit_limit' => 10000]);
        RegisterIncome::execute($user->id, $bolsa->id, 5000);
        RegisterCreditExpense::execute($user->id, $card->id, 1500);
        PayCreditAccount::execute($user->id, $bolsa->id, $card->id, 1000);

        [$from, $to] = $this->rangeAll();
        $report = (new ByAccountReport($user->id))->generate($from, $to);

        $rowBolsa = collect($report['accounts'])->firstWhere('account_id', $bolsa->id);
        $rowCard = collect($report['accounts'])->firstWhere('account_id', $card->id);

        $this->assertEquals(1000.0, $rowBolsa['expense']);   // pago salió de Bolsa
        $this->assertEquals(1000.0, $rowCard['income']);     // tarjeta recibió pago (deuda baja)
        $this->assertEquals(1500.0, $rowCard['expense']);    // cargo (deuda sube)
    }

    public function test_credit_expense_aggregates_in_credit_account_expense(): void
    {
        $user = $this->createUserWithBolsa();
        $card = Account::factory()->credit()->for($user)->create(['name' => 'Visa', 'credit_limit' => 10000]);
        RegisterCreditExpense::execute($user->id, $card->id, 500);

        [$from, $to] = $this->rangeAll();
        $report = (new ByAccountReport($user->id))->generate($from, $to);

        $row = collect($report['accounts'])->firstWhere('account_id', $card->id);
        $this->assertEquals(0.0, $row['income']);
        $this->assertEquals(500.0, $row['expense']);
    }

    public function test_excludes_archived_accounts(): void
    {
        $user = $this->createUserWithBolsa();
        $banamex = Account::factory()->debit()->for($user)->create(['name' => 'Banamex']);
        $banamex->delete(); // soft

        [$from, $to] = $this->rangeAll();
        $report = (new ByAccountReport($user->id))->generate($from, $to);

        $ids = collect($report['accounts'])->pluck('account_id')->all();
        $this->assertNotContains($banamex->id, $ids);
    }

    public function test_excludes_soft_deleted_entries(): void
    {
        $user = $this->createUserWithBolsa();
        $bolsa = $user->accounts()->where('type', Account::TYPE_CASH)->firstOrFail();
        $entry = RegisterIncome::execute($user->id, $bolsa->id, 9999);
        CancelJournalEntry::execute($user->id, $entry->id);

        [$from, $to] = $this->rangeAll();
        $report = (new ByAccountReport($user->id))->generate($from, $to);

        $row = collect($report['accounts'])->firstWhere('account_id', $bolsa->id);
        $this->assertEquals(0.0, $row['income']);
    }

    public function test_respects_user_scope(): void
    {
        $userA = $this->createUserWithBolsa();
        $userB = $this->createUserWithBolsa();
        $bolsaB = $userB->accounts()->where('type', Account::TYPE_CASH)->firstOrFail();
        RegisterIncome::execute($userB->id, $bolsaB->id, 9999);

        [$from, $to] = $this->rangeAll();
        $report = (new ByAccountReport($userA->id))->generate($from, $to);

        $rowA = $report['accounts'][0];
        $this->assertEquals(0.0, $rowA['income']);
    }

    public function test_respects_date_range(): void
    {
        $user = $this->createUserWithBolsa();
        $bolsa = $user->accounts()->where('type', Account::TYPE_CASH)->firstOrFail();
        $entry = RegisterIncome::execute($user->id, $bolsa->id, 1000);
        $entry->occurred_at = now()->subMonths(3);
        $entry->save();

        $from = now()->subMonth()->toDateString();
        $to = now()->toDateString();
        $report = (new ByAccountReport($user->id))->generate($from, $to);

        $row = collect($report['accounts'])->firstWhere('account_id', $bolsa->id);
        $this->assertEquals(0.0, $row['income']);
    }
}
