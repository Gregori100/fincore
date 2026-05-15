<?php

namespace App\Domain\Finance\Catalog;

use App\Models\Category;

/**
 * Source of truth para el catálogo de categorías:
 *
 *  - COLORS: paleta cerrada de slugs (mapean a CSS vars en el frontend).
 *  - ICONS: catálogo cerrado de slugs (mapean a heroicons en el frontend).
 *  - DEFAULTS: 10 categorías que se crean automáticamente al registrar un user
 *    (ver `App\Listeners\CreateUserDefaultCategories`).
 *
 * Los slugs son contratos compartidos con el frontend; cambiar uno aquí implica
 * actualizar también `frontend/src/constants/categoryCatalog.js`.
 */
final class CategoryDefaults
{
    /** Paleta de colores curada (oklch en el tema dark del frontend). */
    public const COLORS = [
        'blue',
        'green',
        'red',
        'orange',
        'purple',
        'pink',
        'teal',
        'yellow',
        'indigo',
        'gray',
    ];

    /** Catálogo de iconos heroicons (24/outline) disponibles. */
    public const ICONS = [
        'shopping-bag',
        'shopping-cart',
        'truck',
        'home',
        'bolt',
        'light-bulb',
        'film',
        'musical-note',
        'heart',
        'academic-cap',
        'book-open',
        'globe-alt',
        'map',
        'gift',
        'cake',
        'device-phone-mobile',
        'computer-desktop',
        'fire',
        'paint-brush',
        'sparkles',
        'briefcase',
        'arrow-trending-up',
        'credit-card',
        'banknotes',
        'currency-dollar',
        'trophy',
        'star',
        'wrench',
        'wrench-screwdriver',
        'tag',
    ];

    /**
     * Categorías creadas automáticamente para cada usuario nuevo.
     * El user puede renombrarlas, cambiar color/icono, archivarlas o borrarlas.
     *
     * @return array<int, array{name: string, applies_to: string, color_slug: string, icon_slug: string}>
     */
    public const DEFAULTS = [
        // Expense (7)
        ['name' => 'Comida', 'applies_to' => Category::APPLIES_EXPENSE, 'color_slug' => 'orange', 'icon_slug' => 'shopping-bag'],
        ['name' => 'Transporte', 'applies_to' => Category::APPLIES_EXPENSE, 'color_slug' => 'blue', 'icon_slug' => 'truck'],
        ['name' => 'Vivienda', 'applies_to' => Category::APPLIES_EXPENSE, 'color_slug' => 'gray', 'icon_slug' => 'home'],
        ['name' => 'Servicios', 'applies_to' => Category::APPLIES_EXPENSE, 'color_slug' => 'yellow', 'icon_slug' => 'bolt'],
        ['name' => 'Salud', 'applies_to' => Category::APPLIES_EXPENSE, 'color_slug' => 'red', 'icon_slug' => 'heart'],
        ['name' => 'Entretenimiento', 'applies_to' => Category::APPLIES_EXPENSE, 'color_slug' => 'purple', 'icon_slug' => 'film'],
        ['name' => 'Otros gastos', 'applies_to' => Category::APPLIES_EXPENSE, 'color_slug' => 'gray', 'icon_slug' => 'tag'],

        // Income (2)
        ['name' => 'Salario', 'applies_to' => Category::APPLIES_INCOME, 'color_slug' => 'green', 'icon_slug' => 'briefcase'],
        ['name' => 'Inversiones', 'applies_to' => Category::APPLIES_INCOME, 'color_slug' => 'teal', 'icon_slug' => 'arrow-trending-up'],

        // Both (1)
        ['name' => 'Reembolsos', 'applies_to' => Category::APPLIES_BOTH, 'color_slug' => 'indigo', 'icon_slug' => 'credit-card'],
    ];

    public static function isValidColor(string $slug): bool
    {
        return in_array($slug, self::COLORS, true);
    }

    public static function isValidIcon(string $slug): bool
    {
        return in_array($slug, self::ICONS, true);
    }
}
