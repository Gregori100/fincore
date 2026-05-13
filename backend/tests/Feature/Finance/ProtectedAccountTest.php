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

    public function test_account_with_entries_cannot_be_deleted()
    {
        $user = $this->createUserWithBolsa();
        $debit = Account::factory()->debit()->for($user)->create();
        RegisterIncome::execute($user->id, $debit->id, 100);

        $this->expectException(ProtectedAccount::class);

        DeleteAccount::execute($user->id, $debit->id);
    }

    public function test_empty_account_can_be_deleted()
    {
        $user = $this->createUserWithBolsa();
        $debit = Account::factory()->debit()->for($user)->create();

        DeleteAccount::execute($user->id, $debit->id);

        $this->assertDatabaseMissing('accounts', ['id' => $debit->id]);
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
}
