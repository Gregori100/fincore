<?php

namespace Database\Factories;

use App\Models\Account;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<Account>
 */
class AccountFactory extends Factory
{
    protected $model = Account::class;

    public function definition(): array
    {
        return [
            'user_id' => null,
            'name' => fake()->company(),
            'type' => Account::TYPE_DEBIT,
            'is_protected' => false,
            'credit_limit' => null,
            'closing_day' => null,
            'payment_day' => null,
            'interest_rate' => null,
            'minimum_payment_pct' => null,
        ];
    }

    public function cash(): static
    {
        return $this->state(fn () => [
            'name' => Account::PROTECTED_CASH_NAME,
            'type' => Account::TYPE_CASH,
            'is_protected' => true,
        ]);
    }

    public function debit(): static
    {
        return $this->state(fn () => [
            'type' => Account::TYPE_DEBIT,
        ]);
    }

    public function credit(): static
    {
        return $this->state(fn () => [
            'type' => Account::TYPE_CREDIT,
            'credit_limit' => fake()->randomFloat(2, 5000, 50000),
            'closing_day' => fake()->numberBetween(1, 28),
            'payment_day' => fake()->numberBetween(1, 28),
            'interest_rate' => fake()->randomFloat(4, 0.0100, 0.0500),
            'minimum_payment_pct' => 0.05,
        ]);
    }
}
