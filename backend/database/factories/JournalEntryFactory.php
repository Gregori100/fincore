<?php

namespace Database\Factories;

use App\Models\JournalEntry;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<JournalEntry>
 */
class JournalEntryFactory extends Factory
{
    protected $model = JournalEntry::class;

    public function definition(): array
    {
        return [
            'user_id' => User::factory(),
            'kind' => JournalEntry::KIND_INCOME,
            'amount' => fake()->randomFloat(2, 10, 5000),
            'account_origin_id' => null,
            'account_destination_id' => null,
            'description' => fake()->sentence(3),
            'occurred_at' => now(),
        ];
    }
}
