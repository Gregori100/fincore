<?php

namespace App\Domain\Finance\Actions;

use App\Domain\Finance\Catalog\CategoryDefaults;
use App\Domain\Finance\Exceptions\DuplicateCategoryName;
use App\Domain\Finance\Exceptions\InvalidCategoryAppliesTo;
use App\Domain\Finance\Exceptions\InvalidColorSlug;
use App\Domain\Finance\Exceptions\InvalidIconSlug;
use App\Models\Category;

class CreateCategory
{
    private const MAX_NAME_LENGTH = 80;

    public static function execute(
        string $userId,
        string $name,
        string $appliesTo,
        string $colorSlug,
        string $iconSlug,
        ?float $monthlyLimit = null,
    ): Category {
        $name = trim($name);

        if ($name === '') {
            throw new InvalidCategoryAppliesTo('El nombre es obligatorio.');
        }
        if (mb_strlen($name) > self::MAX_NAME_LENGTH) {
            throw new InvalidCategoryAppliesTo('El nombre no puede exceder '.self::MAX_NAME_LENGTH.' caracteres.');
        }

        if (! in_array($appliesTo, [
            Category::APPLIES_INCOME,
            Category::APPLIES_EXPENSE,
            Category::APPLIES_BOTH,
        ], true)) {
            throw new InvalidCategoryAppliesTo("Valor inválido para applies_to: {$appliesTo}");
        }

        if (! CategoryDefaults::isValidColor($colorSlug)) {
            throw new InvalidColorSlug();
        }
        if (! CategoryDefaults::isValidIcon($iconSlug)) {
            throw new InvalidIconSlug();
        }

        if ($monthlyLimit !== null && $monthlyLimit < 0) {
            throw new InvalidCategoryAppliesTo('El límite mensual debe ser cero o positivo.');
        }

        // Unicidad case-insensitive del nombre, igual que en Account.
        // withTrashed() para que una archivada no permita un duplicado nuevo
        // — el user puede "reactivar" cambiando primero el nombre del archivado
        // (aunque hoy no hay reactivación, sí evita reciclaje accidental).
        $exists = Category::withTrashed()
            ->where('user_id', $userId)
            ->whereRaw('LOWER(name) = ?', [mb_strtolower($name)])
            ->exists();
        if ($exists) {
            throw new DuplicateCategoryName();
        }

        return Category::create([
            'user_id' => $userId,
            'name' => $name,
            'applies_to' => $appliesTo,
            'color_slug' => $colorSlug,
            'icon_slug' => $iconSlug,
            'monthly_limit' => $monthlyLimit,
        ]);
    }
}
