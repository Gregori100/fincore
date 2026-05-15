<?php

namespace Tests\Feature\Finance;

use App\Domain\Finance\Actions\CreateCategory;
use App\Domain\Finance\Exceptions\DuplicateCategoryName;
use App\Domain\Finance\Exceptions\InvalidCategoryAppliesTo;
use App\Domain\Finance\Exceptions\InvalidColorSlug;
use App\Domain\Finance\Exceptions\InvalidIconSlug;
use App\Models\Category;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Str;
use Tests\TestCase;

class CreateCategoryTest extends TestCase
{
    use RefreshDatabase;

    public function test_creates_a_category(): void
    {
        $user = $this->createUserWithBolsa();

        $category = CreateCategory::execute($user->id, 'Café', Category::APPLIES_EXPENSE, 'orange', 'cake');

        $this->assertDatabaseHas('categories', [
            'id' => $category->id,
            'user_id' => $user->id,
            'name' => 'Café',
            'applies_to' => 'expense',
            'color_slug' => 'orange',
            'icon_slug' => 'cake',
        ]);
        $this->assertTrue(Str::isUuid($category->id));
    }

    public function test_trims_whitespace_around_name(): void
    {
        $user = $this->createUserWithBolsa();

        $category = CreateCategory::execute($user->id, '  Café  ', Category::APPLIES_EXPENSE, 'orange', 'cake');

        $this->assertSame('Café', $category->name);
    }

    public function test_rejects_empty_name(): void
    {
        $user = $this->createUserWithBolsa();

        $this->expectException(InvalidCategoryAppliesTo::class);

        CreateCategory::execute($user->id, '   ', Category::APPLIES_EXPENSE, 'orange', 'cake');
    }

    public function test_rejects_name_over_80_chars(): void
    {
        $user = $this->createUserWithBolsa();

        $this->expectException(InvalidCategoryAppliesTo::class);

        CreateCategory::execute($user->id, str_repeat('x', 81), Category::APPLIES_EXPENSE, 'orange', 'cake');
    }

    public function test_rejects_duplicate_name_case_insensitive(): void
    {
        $user = $this->createUserWithBolsa();
        CreateCategory::execute($user->id, 'Comida fuera', Category::APPLIES_EXPENSE, 'orange', 'cake');

        $this->expectException(DuplicateCategoryName::class);

        CreateCategory::execute($user->id, 'comida FUERA', Category::APPLIES_EXPENSE, 'red', 'shopping-bag');
    }

    public function test_allows_same_name_for_different_users(): void
    {
        $userA = $this->createUserWithBolsa();
        $userB = $this->createUserWithBolsa();

        CreateCategory::execute($userA->id, 'Café', Category::APPLIES_EXPENSE, 'orange', 'cake');
        CreateCategory::execute($userB->id, 'Café', Category::APPLIES_EXPENSE, 'orange', 'cake');

        $this->assertEquals(2, Category::where('name', 'Café')->count());
    }

    public function test_rejects_invalid_applies_to(): void
    {
        $user = $this->createUserWithBolsa();

        $this->expectException(InvalidCategoryAppliesTo::class);

        CreateCategory::execute($user->id, 'X', 'savings', 'orange', 'cake');
    }

    public function test_rejects_invalid_color_slug(): void
    {
        $user = $this->createUserWithBolsa();

        $this->expectException(InvalidColorSlug::class);

        CreateCategory::execute($user->id, 'X', Category::APPLIES_EXPENSE, 'magenta', 'cake');
    }

    public function test_rejects_invalid_icon_slug(): void
    {
        $user = $this->createUserWithBolsa();

        $this->expectException(InvalidIconSlug::class);

        CreateCategory::execute($user->id, 'X', Category::APPLIES_EXPENSE, 'orange', 'rocket-ship');
    }
}
