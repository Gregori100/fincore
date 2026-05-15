<?php

namespace Tests\Feature\Finance;

use App\Domain\Finance\Catalog\CategoryDefaults;
use App\Models\Category;
use App\Models\User;
use Illuminate\Auth\Events\Registered;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class CategoryDefaultsTest extends TestCase
{
    use RefreshDatabase;

    public function test_registered_event_creates_default_categories(): void
    {
        $user = User::factory()->create();

        event(new Registered($user));

        $categories = Category::where('user_id', $user->id)->get();
        $this->assertCount(count(CategoryDefaults::DEFAULTS), $categories);

        foreach (CategoryDefaults::DEFAULTS as $expected) {
            $this->assertTrue(
                $categories->contains(fn (Category $c) => $c->name === $expected['name']
                    && $c->applies_to === $expected['applies_to']
                    && $c->color_slug === $expected['color_slug']
                    && $c->icon_slug === $expected['icon_slug']),
                "Falta categoría default: {$expected['name']}",
            );
        }
    }

    public function test_each_default_has_valid_color_and_icon(): void
    {
        foreach (CategoryDefaults::DEFAULTS as $default) {
            $this->assertTrue(
                CategoryDefaults::isValidColor($default['color_slug']),
                "color_slug inválido en default '{$default['name']}': {$default['color_slug']}",
            );
            $this->assertTrue(
                CategoryDefaults::isValidIcon($default['icon_slug']),
                "icon_slug inválido en default '{$default['name']}': {$default['icon_slug']}",
            );
        }
    }
}
