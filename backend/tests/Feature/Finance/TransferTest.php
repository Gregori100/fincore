<?php

namespace Tests\Feature\Finance;

use App\Domain\Finance\Actions\RegisterIncome;
use App\Domain\Finance\Actions\RegisterTransfer;
use App\Domain\Finance\Exceptions\InsufficientFunds;
use App\Domain\Finance\Exceptions\InvalidAccountType;
use App\Domain\Finance\Services\FinancialStateService;
use App\Models\Account;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class TransferTest extends TestCase
{
    use RefreshDatabase;

    public function test_transfer_moves_balance_between_cash_like_accounts()
    {
        $bolsa = Account::where('type', Account::TYPE_CASH)->firstOrFail();
        $banamex = Account::factory()->debit()->create();

        RegisterIncome::execute($bolsa->id, 5000);
        RegisterTransfer::execute($bolsa->id, $banamex->id, 2000, 'depósito');

        $state = new FinancialStateService();

        $this->assertEquals(3000, $state->getAccountBalance($bolsa->id));
        $this->assertEquals(2000, $state->getAccountBalance($banamex->id));
        $this->assertEquals(5000, $state->getBO());
    }

    public function test_transfer_to_self_is_invalid()
    {
        $bolsa = Account::where('type', Account::TYPE_CASH)->firstOrFail();
        RegisterIncome::execute($bolsa->id, 1000);

        $this->expectException(InvalidAccountType::class);

        RegisterTransfer::execute($bolsa->id, $bolsa->id, 500);
    }

    public function test_transfer_to_credit_account_is_invalid()
    {
        $bolsa = Account::where('type', Account::TYPE_CASH)->firstOrFail();
        $card = Account::factory()->credit()->create(['credit_limit' => 10000]);
        RegisterIncome::execute($bolsa->id, 1000);

        $this->expectException(InvalidAccountType::class);

        RegisterTransfer::execute($bolsa->id, $card->id, 500);
    }

    public function test_transfer_requires_sufficient_funds()
    {
        $bolsa = Account::where('type', Account::TYPE_CASH)->firstOrFail();
        $banamex = Account::factory()->debit()->create();

        $this->expectException(InsufficientFunds::class);

        RegisterTransfer::execute($bolsa->id, $banamex->id, 500);
    }
}
