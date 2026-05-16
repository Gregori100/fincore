<?php

namespace Tests\Feature\Finance;

use App\Domain\Finance\Actions\CreateCategory;
use App\Domain\Finance\Actions\UpdateCategory;
use App\Domain\Finance\Exceptions\DuplicateCategoryName;
use App\Domain\Finance\Exceptions\InvalidCategoryAppliesTo;
use App\Domain\Finance\Exceptions\InvalidColorSlug;
use App\Domain\Finance\Exceptions\InvalidIconSlug;
use App\Models\Category;
use Illuminate\Database\Eloquent\ModelNotFoundException;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class UpdateCategoryTest extends TestCase
{
    use RefreshDatabase;

    public function test_updates_name_applies_to_color_and_icon(): void
    {
        $user = $this->createUserWithBolsa();
        $category = CreateCategory::execute($user->id, 'Original', Category::APPLIES_EXPENSE, 'orange', 'cake');

        $updated = UpdateCategory::execute($user->id, $category->id, [
            'name' => 'Editada',
            'applies_to' => Category::APPLIES_BOTH,
            'color_slug' => 'purple',
            'icon_slug' => 'star',
        ]);

        $this->assertSame('Editada', $updated->name);
        $this->assertSame('both', $updated->applies_to);
        $this->assertSame('purple', $updated->color_slug);
        $this->assertSame('star', $updated->icon_slug);
    }

    public function test_trims_name_and_rejects_empty(): void
    {
        $user = $this->createUserWithBolsa();
        $category = CreateCategory::execute($user->id, 'Antes', Category::APPLIES_EXPENSE, 'orange', 'cake');

        $updated = UpdateCategory::execute($user->id, $category->id, ['name' => '  Después  ']);
        $this->assertSame('Después', $updated->name);

        $this->expectException(InvalidCategoryAppliesTo::class);
        UpdateCategory::execute($user->id, $category->id, ['name' => '   ']);
    }

    public function test_rejects_duplicate_name(): void
    {
        $user = $this->createUserWithBolsa();
        CreateCategory::execute($user->id, 'Comida', Category::APPLIES_EXPENSE, 'orange', 'cake');
        $other = CreateCategory::execute($user->id, 'Bebidas', Category::APPLIES_EXPENSE, 'blue', 'shopping-bag');

        $this->expectException(DuplicateCategoryName::class);

        UpdateCategory::execute($user->id, $other->id, ['name' => 'comida']);
    }

    public function test_allows_keeping_same_name(): void
    {
        $user = $this->createUserWithBolsa();
        $category = CreateCategory::execute($user->id, 'Comida', Category::APPLIES_EXPENSE, 'orange', 'cake');

        $updated = UpdateCategory::execute($user->id, $category->id, ['name' => 'Comida', 'color_slug' => 'red']);

        $this->assertSame('Comida', $updated->name);
        $this->assertSame('red', $updated->color_slug);
    }

    public function test_rejects_invalid_color_or_icon(): void
    {
        $user = $this->createUserWithBolsa();
        $category = CreateCategory::execute($user->id, 'X', Category::APPLIES_EXPENSE, 'orange', 'cake');

        try {
            UpdateCategory::execute($user->id, $category->id, ['color_slug' => 'magenta']);
            $this->fail('Esperaba InvalidColorSlug.');
        } catch (InvalidColorSlug) {
            $this->assertTrue(true);
        }

        try {
            UpdateCategory::execute($user->id, $category->id, ['icon_slug' => 'rocket']);
            $this->fail('Esperaba InvalidIconSlug.');
        } catch (InvalidIconSlug) {
            $this->assertTrue(true);
        }
    }

    public function test_cannot_update_other_users_category(): void
    {
        $userA = $this->createUserWithBolsa();
        $userB = $this->createUserWithBolsa();
        $catA = CreateCategory::execute($userA->id, 'A', Category::APPLIES_EXPENSE, 'orange', 'cake');

        $this->expectException(ModelNotFoundException::class);

        UpdateCategory::execute($userB->id, $catA->id, ['name' => 'hackeado']);
    }

    public function test_unknown_fields_are_ignored(): void
    {
        $user = $this->createUserWithBolsa();
        $category = CreateCategory::execute($user->id, 'Original', Category::APPLIES_EXPENSE, 'orange', 'cake');

        $updated = UpdateCategory::execute($user->id, $category->id, [
            'name' => 'Editada',
            'user_id' => 'otro-user',
            'id' => 'otro-id',
        ]);

        $this->assertSame('Editada', $updated->name);
        $this->assertSame($user->id, $updated->user_id);
    }

    public function test_updates_monthly_limit(): void
    {
        $user = $this->createUserWithBolsa();
        $category = CreateCategory::execute($user->id, 'Comida X', Category::APPLIES_EXPENSE, 'orange', 'cake');

        $updated = UpdateCategory::execute($user->id, $category->id, ['monthly_limit' => 2000]);

        $this->assertEquals(2000, (float) $updated->monthly_limit);
    }

    public function test_can_clear_monthly_limit_with_null(): void
    {
        $user = $this->createUserWithBolsa();
        $category = CreateCategory::execute(
            $user->id, 'Comida X', Category::APPLIES_EXPENSE, 'orange', 'cake', 1500
        );

        $updated = UpdateCategory::execute($user->id, $category->id, ['monthly_limit' => null]);

        $this->assertNull($updated->monthly_limit);
    }

    public function test_rejects_negative_monthly_limit_on_update(): void
    {
        $user = $this->createUserWithBolsa();
        $category = CreateCategory::execute($user->id, 'X', Category::APPLIES_EXPENSE, 'orange', 'cake');

        $this->expectException(InvalidCategoryAppliesTo::class);

        UpdateCategory::execute($user->id, $category->id, ['monthly_limit' => -50]);
    }
}
