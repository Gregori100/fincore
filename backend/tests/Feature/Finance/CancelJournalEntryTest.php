<?php

namespace Tests\Feature\Finance;

use App\Domain\Finance\Actions\CancelJournalEntry;
use App\Domain\Finance\Actions\RegisterCreditExpense;
use App\Domain\Finance\Actions\RegisterExpense;
use App\Domain\Finance\Actions\RegisterIncome;
use App\Domain\Finance\Actions\RegisterTransfer;
use App\Domain\Finance\Actions\UpdateJournalEntry;
use App\Domain\Finance\Services\FinancialStateService;
use App\Models\Account;
use App\Models\JournalEntry;
use Illuminate\Database\Eloquent\ModelNotFoundException;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class CancelJournalEntryTest extends TestCase
{
    use RefreshDatabase;

    public function test_cancels_an_entry(): void
    {
        $user = $this->createUserWithBolsa();
        $bolsa = $user->accounts()->where('type', Account::TYPE_CASH)->firstOrFail();
        $entry = RegisterIncome::execute($user->id, $bolsa->id, 500);

        CancelJournalEntry::execute($user->id, $entry->id);

        $this->assertSoftDeleted('journal_entries', ['id' => $entry->id]);
    }

    public function test_balance_recalculates_after_cancel_expense(): void
    {
        $user = $this->createUserWithBolsa();
        $bolsa = $user->accounts()->where('type', Account::TYPE_CASH)->firstOrFail();
        RegisterIncome::execute($user->id, $bolsa->id, 5000);
        $expense = RegisterExpense::execute($user->id, $bolsa->id, 1200);

        $state = new FinancialStateService($user->id);
        $this->assertEquals(3800, $state->getBO());

        CancelJournalEntry::execute($user->id, $expense->id);

        $this->assertEquals(5000, $state->getBO());
    }

    public function test_cancel_credit_expense_reduces_debt(): void
    {
        $user = $this->createUserWithBolsa();
        $card = Account::factory()->credit()->for($user)->create(['credit_limit' => 10000]);
        $charge = RegisterCreditExpense::execute($user->id, $card->id, 1500);

        $state = new FinancialStateService($user->id);
        $this->assertEquals(1500, $state->getDE());

        CancelJournalEntry::execute($user->id, $charge->id);

        $this->assertEquals(0, $state->getDE());
    }

    public function test_cancel_transfer_restores_both_sides(): void
    {
        $user = $this->createUserWithBolsa();
        $bolsa = $user->accounts()->where('type', Account::TYPE_CASH)->firstOrFail();
        $debit = Account::factory()->debit()->for($user)->create();
        RegisterIncome::execute($user->id, $bolsa->id, 5000);
        $transfer = RegisterTransfer::execute($user->id, $bolsa->id, $debit->id, 2000);

        $state = new FinancialStateService($user->id);
        $this->assertEquals(3000, $state->getAccountBalance($bolsa->id));
        $this->assertEquals(2000, $state->getAccountBalance($debit->id));

        CancelJournalEntry::execute($user->id, $transfer->id);

        $this->assertEquals(5000, $state->getAccountBalance($bolsa->id));
        $this->assertEquals(0, $state->getAccountBalance($debit->id));
    }

    public function test_cancel_allows_leaving_account_negative(): void
    {
        $user = $this->createUserWithBolsa();
        $bolsa = $user->accounts()->where('type', Account::TYPE_CASH)->firstOrFail();
        $income = RegisterIncome::execute($user->id, $bolsa->id, 1000);
        RegisterExpense::execute($user->id, $bolsa->id, 500);

        // Cancelar el ingreso deja la cuenta en -500. No debe lanzar excepción.
        CancelJournalEntry::execute($user->id, $income->id);

        $state = new FinancialStateService($user->id);
        $this->assertEquals(-500, $state->getBO());
    }

    public function test_cannot_cancel_other_users_entry(): void
    {
        $userA = $this->createUserWithBolsa();
        $userB = $this->createUserWithBolsa();
        $bolsaA = $userA->accounts()->where('type', Account::TYPE_CASH)->firstOrFail();
        $entry = RegisterIncome::execute($userA->id, $bolsaA->id, 1000);

        $this->expectException(ModelNotFoundException::class);

        CancelJournalEntry::execute($userB->id, $entry->id);
    }

    public function test_cannot_cancel_already_cancelled_entry(): void
    {
        $user = $this->createUserWithBolsa();
        $bolsa = $user->accounts()->where('type', Account::TYPE_CASH)->firstOrFail();
        $entry = RegisterIncome::execute($user->id, $bolsa->id, 1000);

        CancelJournalEntry::execute($user->id, $entry->id);

        // El scope global de SoftDeletes oculta los cancelados → not found.
        $this->expectException(ModelNotFoundException::class);

        CancelJournalEntry::execute($user->id, $entry->id);
    }

    public function test_cancelled_entry_no_longer_appears_in_listings(): void
    {
        $user = $this->createUserWithBolsa();
        $bolsa = $user->accounts()->where('type', Account::TYPE_CASH)->firstOrFail();
        RegisterIncome::execute($user->id, $bolsa->id, 1000);
        $expense = RegisterExpense::execute($user->id, $bolsa->id, 200);

        CancelJournalEntry::execute($user->id, $expense->id);

        $state = new FinancialStateService($user->id);
        $recent = $state->getRecentEntries();

        $this->assertEquals(1, $recent->count());
        $this->assertNotEquals($expense->id, $recent->first()->id);

        // Pero sigue existiendo en BD con withTrashed.
        $this->assertNotNull(JournalEntry::withTrashed()->find($expense->id));
    }

    public function test_cancelled_entry_blocks_update(): void
    {
        $user = $this->createUserWithBolsa();
        $bolsa = $user->accounts()->where('type', Account::TYPE_CASH)->firstOrFail();
        RegisterIncome::execute($user->id, $bolsa->id, 1000);
        $entry = RegisterExpense::execute($user->id, $bolsa->id, 200, 'antes');

        CancelJournalEntry::execute($user->id, $entry->id);

        $this->expectException(ModelNotFoundException::class);

        UpdateJournalEntry::execute($user->id, $entry->id, ['description' => 'después']);
    }
}
