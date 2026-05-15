<?php

namespace App\Domain\Finance\Actions;

use App\Models\Category;

class ArchiveCategory
{
    /**
     * Archiva (soft delete) una categoría del usuario. A diferencia de
     * `DeleteAccount`, no requiere que esté "vacía": los `JournalEntry` que la
     * referencian conservan `category_id`, pero el badge desaparece en la UI
     * porque la relación no usa withTrashed().
     */
    public static function execute(string $userId, string $categoryId): void
    {
        $category = Category::where('id', $categoryId)
            ->where('user_id', $userId)
            ->firstOrFail();

        $category->delete();
    }
}
