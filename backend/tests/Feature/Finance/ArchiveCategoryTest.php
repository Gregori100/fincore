<?php

namespace Tests\Feature\Finance;

use App\Domain\Finance\Actions\ArchiveCategory;
use App\Domain\Finance\Actions\CreateCategory;
use App\Domain\Finance\Actions\RegisterExpense;
use App\Models\Account;
use App\Models\Category;
use App\Models\JournalEntry;
use Illuminate\Database\Eloquent\ModelNotFoundException;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class ArchiveCategoryTest extends TestCase
{
    use RefreshDatabase;

    public function test_archives_a_category_with_soft_delete(): void
    {
        $user = $this->createUserWithBolsa();
        $category = CreateCategory::execute($user->id, 'Café', Category::APPLIES_EXPENSE, 'orange', 'cake');

        ArchiveCategory::execute($user->id, $category->id);

        $this->assertSoftDeleted('categories', ['id' => $category->id]);
        $this->assertNull(Category::find($category->id));
        $this->assertNotNull(Category::withTrashed()->find($category->id));
    }

    public function test_archived_category_keeps_fk_on_existing_entries(): void
    {
        $user = $this->createUserWithBolsa();
        $bolsa = $user->accounts()->where('type', Account::TYPE_CASH)->firstOrFail();
        $category = CreateCategory::execute($user->id, 'Café', Category::APPLIES_EXPENSE, 'orange', 'cake');

        // Necesitamos fondos para gastar.
        \App\Domain\Finance\Actions\RegisterIncome::execute($user->id, $bolsa->id, 1000);
        $entry = RegisterExpense::execute($user->id, $bolsa->id, 80, 'cappuccino', $category->id);

        ArchiveCategory::execute($user->id, $category->id);

        // El entry conserva el category_id en BD; la relación 'category' devuelve null
        // porque NO usa withTrashed (los badges desaparecen en la UI).
        $fresh = JournalEntry::find($entry->id);
        $this->assertSame($category->id, $fresh->category_id);
        $this->assertNull($fresh->category);
    }

    public function test_cannot_archive_other_users_category(): void
    {
        $userA = $this->createUserWithBolsa();
        $userB = $this->createUserWithBolsa();
        $cat = CreateCategory::execute($userA->id, 'A', Category::APPLIES_EXPENSE, 'orange', 'cake');

        $this->expectException(ModelNotFoundException::class);

        ArchiveCategory::execute($userB->id, $cat->id);
    }
}
