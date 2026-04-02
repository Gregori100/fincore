<?php

namespace Database\Factories;

use App\Models\Debt;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<Debt>
 */
class DebtFactory extends Factory
{
    protected $model = Debt::class;

    public function definition(): array
    {
        return [
            'name'           => fake()->company(),
            'initial_amount' => 0,
            'current_amount' => 0,
            'credit_limit'   => fake()->randomFloat(2, 1000, 50000),
        ];
    }
}
