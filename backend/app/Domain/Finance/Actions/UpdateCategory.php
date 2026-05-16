<?php

namespace App\Domain\Finance\Actions;

use App\Domain\Finance\Catalog\CategoryDefaults;
use App\Domain\Finance\Exceptions\DuplicateCategoryName;
use App\Domain\Finance\Exceptions\InvalidCategoryAppliesTo;
use App\Domain\Finance\Exceptions\InvalidColorSlug;
use App\Domain\Finance\Exceptions\InvalidIconSlug;
use App\Models\Category;

class UpdateCategory
{
    private const EDITABLE_FIELDS = ['name', 'applies_to', 'color_slug', 'icon_slug', 'monthly_limit'];

    private const MAX_NAME_LENGTH = 80;

    public static function execute(string $userId, string $categoryId, array $changes): Category
    {
        $category = Category::where('id', $categoryId)
            ->where('user_id', $userId)
            ->firstOrFail();

        $update = array_intersect_key($changes, array_flip(self::EDITABLE_FIELDS));

        if (array_key_exists('name', $update)) {
            $update['name'] = trim((string) $update['name']);
            if ($update['name'] === '') {
                throw new InvalidCategoryAppliesTo('El nombre es obligatorio.');
            }
            if (mb_strlen($update['name']) > self::MAX_NAME_LENGTH) {
                throw new InvalidCategoryAppliesTo('El nombre no puede exceder '.self::MAX_NAME_LENGTH.' caracteres.');
            }

            $duplicated = Category::withTrashed()
                ->where('user_id', $userId)
                ->where('id', '!=', $categoryId)
                ->whereRaw('LOWER(name) = ?', [mb_strtolower($update['name'])])
                ->exists();
            if ($duplicated) {
                throw new DuplicateCategoryName();
            }
        }

        if (array_key_exists('applies_to', $update)
            && ! in_array($update['applies_to'], [
                Category::APPLIES_INCOME,
                Category::APPLIES_EXPENSE,
                Category::APPLIES_BOTH,
            ], true)) {
            throw new InvalidCategoryAppliesTo("Valor inválido para applies_to: {$update['applies_to']}");
        }

        if (array_key_exists('color_slug', $update)
            && ! CategoryDefaults::isValidColor($update['color_slug'])) {
            throw new InvalidColorSlug();
        }
        if (array_key_exists('icon_slug', $update)
            && ! CategoryDefaults::isValidIcon($update['icon_slug'])) {
            throw new InvalidIconSlug();
        }

        if (array_key_exists('monthly_limit', $update)
            && $update['monthly_limit'] !== null
            && (float) $update['monthly_limit'] < 0) {
            throw new InvalidCategoryAppliesTo('El límite mensual debe ser cero o positivo.');
        }

        $category->update($update);

        return $category->fresh();
    }
}
