<?php

namespace Tests\Feature\Finance;

use App\Domain\Finance\Actions\DeleteAccount;
use App\Domain\Finance\Actions\RegisterIncome;
use App\Domain\Finance\Actions\UpdateAccount;
use App\Domain\Finance\Exceptions\ProtectedAccount;
use App\Models\Account;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class ProtectedAccountTest extends TestCase
{
    use RefreshDatabase;

    public function test_bolsa_cannot_be_updated()
    {
        $user = $this->createUserWithBolsa();
        $bolsa = $user->accounts()->where('type', Account::TYPE_CASH)->firstOrFail();

        $this->expectException(ProtectedAccount::class);

        UpdateAccount::execute($user->id, $bolsa->id, ['name' => 'Otro nombre']);
    }

    public function test_bolsa_cannot_be_deleted()
    {
        $user = $this->createUserWithBolsa();
        $bolsa = $user->accounts()->where('type', Account::TYPE_CASH)->firstOrFail();

        $this->expectException(ProtectedAccount::class);

        DeleteAccount::execute($user->id, $bolsa->id);
    }

    public function test_account_with_balance_cannot_be_deleted()
    {
        $user = $this->createUserWithBolsa();
        $debit = Account::factory()->debit()->for($user)->create();
        RegisterIncome::execute($user->id, $debit->id, 100);

        $this->expectException(\App\Domain\Finance\Exceptions\AccountNotEmpty::class);

        DeleteAccount::execute($user->id, $debit->id);
    }

    public function test_account_with_entries_but_zero_balance_can_be_archived()
    {
        $user = $this->createUserWithBolsa();
        $debit = Account::factory()->debit()->for($user)->create();
        // Genera entries pero deja balance en 0.
        RegisterIncome::execute($user->id, $debit->id, 100);
        \App\Domain\Finance\Actions\RegisterExpense::execute($user->id, $debit->id, 100);

        DeleteAccount::execute($user->id, $debit->id);

        // Soft-deletea, no hard delete.
        $this->assertSoftDeleted('accounts', ['id' => $debit->id]);
    }

    public function test_empty_account_can_be_archived()
    {
        $user = $this->createUserWithBolsa();
        $debit = Account::factory()->debit()->for($user)->create();

        DeleteAccount::execute($user->id, $debit->id);

        // Soft delete: la fila sigue en BD pero con deleted_at != null.
        $this->assertSoftDeleted('accounts', ['id' => $debit->id]);
    }

    public function test_credit_with_pending_debt_cannot_be_archived()
    {
        $user = $this->createUserWithBolsa();
        $card = Account::factory()->credit()->for($user)->create(['credit_limit' => 10000]);
        \App\Domain\Finance\Actions\RegisterCreditExpense::execute($user->id, $card->id, 500);

        $this->expectException(\App\Domain\Finance\Exceptions\AccountNotEmpty::class);

        DeleteAccount::execute($user->id, $card->id);
    }

    public function test_archived_account_does_not_appear_in_listing()
    {
        $user = $this->createUserWithBolsa();
        $debit = Account::factory()->debit()->for($user)->create();
        DeleteAccount::execute($user->id, $debit->id);

        $state = new \App\Domain\Finance\Services\FinancialStateService($user->id);
        $accountIds = $state->getAccounts()->pluck('id')->all();

        $this->assertNotContains($debit->id, $accountIds);
    }

    public function test_journal_entries_still_load_archived_account_via_relation()
    {
        $user = $this->createUserWithBolsa();
        $debit = Account::factory()->debit()->for($user)->create(['name' => 'Banamex Archived']);
        RegisterIncome::execute($user->id, $debit->id, 100);
        \App\Domain\Finance\Actions\RegisterExpense::execute($user->id, $debit->id, 100);

        DeleteAccount::execute($user->id, $debit->id);

        $entry = \App\Models\JournalEntry::with(['origin', 'destination'])
            ->where('user_id', $user->id)
            ->where('account_origin_id', $debit->id)
            ->first();

        $this->assertNotNull($entry);
        $this->assertNotNull($entry->origin);
        $this->assertEquals('Banamex Archived', $entry->origin->name);
        $this->assertNotNull($entry->origin->deleted_at);
    }

    public function test_update_rejects_setting_credit_limit_to_null()
    {
        $user = $this->createUserWithBolsa();
        $card = Account::factory()->credit()->for($user)->create(['credit_limit' => 10000]);

        $this->expectException(\App\Domain\Finance\Exceptions\InvalidCreditLimit::class);

        UpdateAccount::execute($user->id, $card->id, ['credit_limit' => null]);
    }

    public function test_update_rejects_duplicate_name_case_insensitive()
    {
        $user = $this->createUserWithBolsa();
        Account::factory()->debit()->for($user)->create(['name' => 'BBVA']);
        $other = Account::factory()->debit()->for($user)->create(['name' => 'Banamex']);

        $this->expectException(\App\Domain\Finance\Exceptions\DuplicateAccountName::class);

        UpdateAccount::execute($user->id, $other->id, ['name' => 'bbva']);
    }

    public function test_update_allows_keeping_same_name()
    {
        $user = $this->createUserWithBolsa();
        $debit = Account::factory()->debit()->for($user)->create(['name' => 'Banamex']);

        $updated = UpdateAccount::execute($user->id, $debit->id, [
            'name' => 'Banamex',
        ]);

        $this->assertEquals('Banamex', $updated->name);
    }

    public function test_update_rejects_closing_day_equal_to_payment_day()
    {
        $user = $this->createUserWithBolsa();
        $card = Account::factory()->credit()->for($user)->create([
            'credit_limit' => 10000,
            'closing_day' => 15,
            'payment_day' => 5,
        ]);

        $this->expectException(\App\Domain\Finance\Exceptions\InvalidCreditMetadata::class);

        UpdateAccount::execute($user->id, $card->id, ['payment_day' => 15]);
    }

    public function test_updating_a_credit_account_metadata()
    {
        $user = $this->createUserWithBolsa();
        $card = Account::factory()->credit()->for($user)->create([
            'credit_limit' => 10000,
            'closing_day' => 10,
        ]);

        $updated = UpdateAccount::execute($user->id, $card->id, [
            'credit_limit' => 15000,
            'closing_day' => 20,
        ]);

        $this->assertEquals(15000, $updated->credit_limit);
        $this->assertEquals(20, $updated->closing_day);
    }

    public function test_cannot_lower_credit_limit_below_current_debt()
    {
        $user = $this->createUserWithBolsa();
        $card = Account::factory()->credit()->for($user)->create([
            'credit_limit' => 10000,
        ]);

        // Genera deuda de 5000 con un cargo a la tarjeta.
        \App\Domain\Finance\Actions\RegisterCreditExpense::execute($user->id, $card->id, 5000);

        $this->expectException(\App\Domain\Finance\Exceptions\InvalidCreditLimit::class);

        UpdateAccount::execute($user->id, $card->id, ['credit_limit' => 4000]);
    }

    public function test_can_lower_credit_limit_above_current_debt()
    {
        $user = $this->createUserWithBolsa();
        $card = Account::factory()->credit()->for($user)->create([
            'credit_limit' => 10000,
        ]);

        \App\Domain\Finance\Actions\RegisterCreditExpense::execute($user->id, $card->id, 3000);

        // 6000 > 3000 de deuda, así que es válido.
        $updated = UpdateAccount::execute($user->id, $card->id, ['credit_limit' => 6000]);

        $this->assertEquals(6000, $updated->credit_limit);
    }

    public function test_update_persists_description_and_trims()
    {
        $user = $this->createUserWithBolsa();
        $debit = Account::factory()->debit()->for($user)->create();

        $updated = UpdateAccount::execute($user->id, $debit->id, [
            'description' => '   Mi cuenta principal   ',
        ]);

        $this->assertSame('Mi cuenta principal', $updated->description);
    }

    public function test_update_can_clear_description_with_null()
    {
        $user = $this->createUserWithBolsa();
        $debit = Account::factory()->debit()->for($user)->create([
            'description' => 'algo anterior',
        ]);

        $updated = UpdateAccount::execute($user->id, $debit->id, [
            'description' => null,
        ]);

        $this->assertNull($updated->description);
    }

    public function test_update_rejects_description_over_200_chars()
    {
        $user = $this->createUserWithBolsa();
        $debit = Account::factory()->debit()->for($user)->create();

        $this->expectException(\App\Domain\Finance\Exceptions\InvalidAccountType::class);

        UpdateAccount::execute($user->id, $debit->id, [
            'description' => str_repeat('a', 201),
        ]);
    }
}
