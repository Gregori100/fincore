<?php

namespace Tests\Feature\Http;

use App\Domain\Finance\Actions\RegisterCreditExpense;
use App\Domain\Finance\Actions\RegisterIncome;
use App\Models\Account;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class FinanceApiTest extends TestCase
{
    use RefreshDatabase;

    private function bolsa(): Account
    {
        return Account::where('type', Account::TYPE_CASH)->firstOrFail();
    }

    public function test_state_endpoint_returns_full_shape()
    {
        $this->getJson('/api/finance/state')
            ->assertOk()
            ->assertJsonStructure([
                'bo',
                'de',
                'cr',
                'burn_rate',
                'credit_usage_pct',
                'accounts',
                'recent_entries',
            ]);
    }

    public function test_list_accounts_includes_bolsa()
    {
        $this->getJson('/api/finance/accounts')
            ->assertOk()
            ->assertJsonFragment(['name' => Account::PROTECTED_CASH_NAME]);
    }

    public function test_create_debit_account_via_api()
    {
        $this->postJson('/api/finance/accounts', [
            'name' => 'Banamex',
            'type' => 'debit',
        ])
            ->assertCreated()
            ->assertJsonPath('account.name', 'Banamex')
            ->assertJsonPath('account.type', 'debit');
    }

    public function test_create_credit_account_via_api()
    {
        $this->postJson('/api/finance/accounts', [
            'name' => 'Costco Visa',
            'type' => 'credit',
            'credit_limit' => 25000,
            'closing_day' => 15,
            'payment_day' => 5,
            'interest_rate' => 0.0367,
            'minimum_payment_pct' => 0.05,
        ])
            ->assertCreated()
            ->assertJsonPath('account.type', 'credit')
            ->assertJsonPath('account.credit_limit', '25000.00');
    }

    public function test_cannot_create_cash_account_via_api()
    {
        $this->postJson('/api/finance/accounts', [
            'name' => 'Otra Bolsa',
            'type' => 'cash',
        ])->assertStatus(422);
    }

    public function test_update_account_rejects_protected_bolsa()
    {
        $this->patchJson('/api/finance/accounts/' . $this->bolsa()->id, [
            'name' => 'Hackeada',
        ])
            ->assertStatus(409)
            ->assertJsonPath('code', 'protected_account');
    }

    public function test_delete_account_rejects_protected_bolsa()
    {
        $this->deleteJson('/api/finance/accounts/' . $this->bolsa()->id)
            ->assertStatus(409)
            ->assertJsonPath('code', 'protected_account');
    }

    public function test_income_endpoint_creates_entry()
    {
        $this->postJson('/api/finance/income', [
            'account_id' => $this->bolsa()->id,
            'amount' => 5000,
            'description' => 'sueldo',
        ])
            ->assertCreated()
            ->assertJsonPath('entry.kind', 'income')
            ->assertJsonPath('entry.amount', '5000.00');
    }

    public function test_income_validation_requires_account_id()
    {
        $this->postJson('/api/finance/income', ['amount' => 100])
            ->assertStatus(422)
            ->assertJsonValidationErrors(['account_id']);
    }

    public function test_expense_returns_422_insufficient_funds()
    {
        $this->postJson('/api/finance/expense', [
            'account_id' => $this->bolsa()->id,
            'amount' => 100,
        ])
            ->assertStatus(422)
            ->assertJsonPath('code', 'insufficient_funds');
    }

    public function test_credit_expense_returns_422_when_limit_exceeded()
    {
        $card = Account::factory()->credit()->create(['credit_limit' => 1000]);

        $this->postJson('/api/finance/credit-expense', [
            'account_id' => $card->id,
            'amount' => 2000,
        ])
            ->assertStatus(422)
            ->assertJsonPath('code', 'credit_limit_exceeded');
    }

    public function test_pay_credit_happy_path()
    {
        $bolsa = $this->bolsa();
        $card = Account::factory()->credit()->create(['credit_limit' => 10000]);

        RegisterIncome::execute($bolsa->id, 5000);
        RegisterCreditExpense::execute($card->id, 2000);

        $this->postJson('/api/finance/pay-credit', [
            'origin_id' => $bolsa->id,
            'credit_account_id' => $card->id,
            'amount' => 1500,
        ])
            ->assertCreated()
            ->assertJsonPath('entry.kind', 'debt_payment');
    }

    public function test_pay_credit_returns_422_overpay()
    {
        $bolsa = $this->bolsa();
        $card = Account::factory()->credit()->create(['credit_limit' => 10000]);

        RegisterIncome::execute($bolsa->id, 5000);
        RegisterCreditExpense::execute($card->id, 1000);

        $this->postJson('/api/finance/pay-credit', [
            'origin_id' => $bolsa->id,
            'credit_account_id' => $card->id,
            'amount' => 2000,
        ])
            ->assertStatus(422)
            ->assertJsonPath('code', 'overpay_debt');
    }

    public function test_transfer_between_cash_accounts()
    {
        $bolsa = $this->bolsa();
        $banamex = Account::factory()->debit()->create();
        RegisterIncome::execute($bolsa->id, 1000);

        $this->postJson('/api/finance/transfer', [
            'origin_id' => $bolsa->id,
            'destination_id' => $banamex->id,
            'amount' => 400,
        ])
            ->assertCreated()
            ->assertJsonPath('entry.kind', 'transfer');
    }

    public function test_transfer_to_credit_account_is_422()
    {
        $bolsa = $this->bolsa();
        $card = Account::factory()->credit()->create(['credit_limit' => 10000]);
        RegisterIncome::execute($bolsa->id, 1000);

        $this->postJson('/api/finance/transfer', [
            'origin_id' => $bolsa->id,
            'destination_id' => $card->id,
            'amount' => 100,
        ])
            ->assertStatus(422)
            ->assertJsonPath('code', 'invalid_account_type');
    }

    public function test_entries_endpoint_paginates_and_filters()
    {
        $bolsa = $this->bolsa();
        RegisterIncome::execute($bolsa->id, 1000, 'a');
        RegisterIncome::execute($bolsa->id, 2000, 'b');

        $this->getJson('/api/finance/entries?per_page=10')
            ->assertOk()
            ->assertJsonStructure(['data', 'current_page', 'last_page', 'total']);

        $this->getJson('/api/finance/entries?kind=income')
            ->assertOk()
            ->assertJsonPath('total', 2);

        $this->getJson('/api/finance/entries?kind=expense')
            ->assertOk()
            ->assertJsonPath('total', 0);

        $this->getJson('/api/finance/entries?account_id=' . $bolsa->id)
            ->assertOk()
            ->assertJsonPath('total', 2);
    }
}
