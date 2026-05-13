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
        $user = $this->createUserWithBolsa();

        CreateAccount::execute($user->id, 'Banamex Débito', Account::TYPE_DEBIT);

        $this->assertDatabaseHas('accounts', [
            'user_id' => $user->id,
            'name' => 'Banamex Débito',
            'type' => 'debit',
            'is_protected' => false,
        ]);
    }

    public function test_create_credit_account_with_full_metadata()
    {
        $user = $this->createUserWithBolsa();

        CreateAccount::execute(
            $user->id,
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
            'user_id' => $user->id,
            'name' => 'Costco Visa',
            'type' => 'credit',
            'credit_limit' => 25000,
            'closing_day' => 15,
            'payment_day' => 5,
        ]);
    }

    public function test_credit_account_requires_credit_limit()
    {
        $user = $this->createUserWithBolsa();

        $this->expectException(InvalidAccountType::class);

        CreateAccount::execute($user->id, 'Sin Límite', Account::TYPE_CREDIT, []);
    }

    public function test_cannot_create_extra_cash_account()
    {
        $user = $this->createUserWithBolsa();

        $this->expectException(InvalidAccountType::class);

        CreateAccount::execute($user->id, 'Bolsa 2', Account::TYPE_CASH);
    }

    public function test_unknown_type_is_rejected()
    {
        $user = $this->createUserWithBolsa();

        $this->expectException(InvalidAccountType::class);

        CreateAccount::execute($user->id, 'Raro', 'savings');
    }
}
