<?php

namespace Database\Factories;

use App\Models\Category;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<Category>
 */
class CategoryFactory extends Factory
{
    protected $model = Category::class;

    public function definition(): array
    {
        return [
            'user_id' => User::factory(),
            'name' => fake()->unique()->word(),
            'applies_to' => Category::APPLIES_EXPENSE,
            'color_slug' => 'blue',
            'icon_slug' => 'shopping-bag',
        ];
    }

    public function income(): static
    {
        return $this->state(fn () => ['applies_to' => Category::APPLIES_INCOME]);
    }

    public function expense(): static
    {
        return $this->state(fn () => ['applies_to' => Category::APPLIES_EXPENSE]);
    }

    public function both(): static
    {
        return $this->state(fn () => ['applies_to' => Category::APPLIES_BOTH]);
    }
}
