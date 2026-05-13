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
        $bolsa = Account::where('type', Account::TYPE_CASH)->firstOrFail();

        $this->expectException(ProtectedAccount::class);

        UpdateAccount::execute($bolsa->id, ['name' => 'Otro nombre']);
    }

    public function test_bolsa_cannot_be_deleted()
    {
        $bolsa = Account::where('type', Account::TYPE_CASH)->firstOrFail();

        $this->expectException(ProtectedAccount::class);

        DeleteAccount::execute($bolsa->id);
    }

    public function test_account_with_entries_cannot_be_deleted()
    {
        $debit = Account::factory()->debit()->create();
        RegisterIncome::execute($debit->id, 100);

        $this->expectException(ProtectedAccount::class);

        DeleteAccount::execute($debit->id);
    }

    public function test_empty_account_can_be_deleted()
    {
        $debit = Account::factory()->debit()->create();

        DeleteAccount::execute($debit->id);

        $this->assertDatabaseMissing('accounts', ['id' => $debit->id]);
    }

    public function test_updating_a_credit_account_metadata()
    {
        $card = Account::factory()->credit()->create([
            'credit_limit' => 10000,
            'closing_day' => 10,
        ]);

        $updated = UpdateAccount::execute($card->id, [
            'credit_limit' => 15000,
            'closing_day' => 20,
        ]);

        $this->assertEquals(15000, $updated->credit_limit);
        $this->assertEquals(20, $updated->closing_day);
    }
}
