<?php

namespace App\Listeners;

use App\Domain\Finance\Catalog\CategoryDefaults;
use App\Models\Category;
use Illuminate\Auth\Events\Registered;

class CreateUserDefaultCategories
{
    /**
     * Crea las categorías default para un usuario recién registrado. El listener
     * se autodescubre por convención (Laravel 11+) por su firma handle(Registered).
     *
     * Las categorías son copias por user — el usuario puede renombrarlas,
     * cambiar color/icono, archivarlas o borrarlas individualmente.
     */
    public function handle(Registered $event): void
    {
        foreach (CategoryDefaults::DEFAULTS as $row) {
            Category::create([
                'user_id' => $event->user->id,
                'name' => $row['name'],
                'applies_to' => $row['applies_to'],
                'color_slug' => $row['color_slug'],
                'icon_slug' => $row['icon_slug'],
            ]);
        }
    }
}
