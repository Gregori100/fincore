<?php

namespace Tests\Feature\Finance;

use App\Domain\Finance\Actions\CreateAccount;
use App\Domain\Finance\Exceptions\InvalidAccountType;
use App\Models\Account;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class CreateAccountTest extends TestCase
{
    use RefreshDatabase;

    public function test_create_debit_account()
    {
        CreateAccount::execute('Banamex Débito', Account::TYPE_DEBIT);

        $this->assertDatabaseHas('accounts', [
            'name' => 'Banamex Débito',
            'type' => 'debit',
            'is_protected' => false,
        ]);
    }

    public function test_create_credit_account_with_full_metadata()
    {
        CreateAccount::execute(
            'Costco Visa',
            Account::TYPE_CREDIT,
            [
                'credit_limit' => 25000,
                'closing_day' => 15,
                'payment_day' => 5,
                'interest_rate' => 0.0367,
                'minimum_payment_pct' => 0.05,
            ],
        );

        $this->assertDatabaseHas('accounts', [
            'name' => 'Costco Visa',
            'type' => 'credit',
            'credit_limit' => 25000,
            'closing_day' => 15,
            'payment_day' => 5,
        ]);
    }

    public function test_credit_account_requires_credit_limit()
    {
        $this->expectException(InvalidAccountType::class);

        CreateAccount::execute('Sin Límite', Account::TYPE_CREDIT, []);
    }

    public function test_cannot_create_extra_cash_account()
    {
        $this->expectException(InvalidAccountType::class);

        CreateAccount::execute('Bolsa 2', Account::TYPE_CASH);
    }

    public function test_unknown_type_is_rejected()
    {
        $this->expectException(InvalidAccountType::class);

        CreateAccount::execute('Raro', 'savings');
    }
}
