<?php

namespace App\Domain\Finance\Actions;

use App\Domain\Finance\Exceptions\InvalidAccountType;
use App\Domain\Finance\Exceptions\InvalidCategoryAppliesTo;
use App\Models\Account;
use App\Models\Category;
use App\Models\JournalEntry;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;

class RegisterCreditExpense
{
    public static function execute(
        string $userId,
        string $accountId,
        float $amount,
        ?string $description = null,
        ?string $categoryId = null,
        ?string $occurredAt = null,
    ): JournalEntry {
        return DB::transaction(function () use ($userId, $accountId, $amount, $description, $categoryId, $occurredAt) {
            // lockForUpdate serializa cargos simultáneos sobre la misma tarjeta.
            // Ya no validamos contra credit_limit: la app permite exceder el
            // límite y la UI lo marca visualmente (libreta libre).
            $account = Account::where('id', $accountId)
                ->where('user_id', $userId)
                ->lockForUpdate()
                ->firstOrFail();

            if (! $account->isCredit()) {
                throw new InvalidAccountType('Solo se puede cargar a una cuenta de tipo credit.');
            }

            // credit_expense semánticamente es un "gasto" — usa categorías de
            // expense o both. Income no aplica.
            if ($categoryId !== null) {
                $category = Category::where('id', $categoryId)
                    ->where('user_id', $userId)
                    ->first();
                if (! $category) {
                    throw new InvalidCategoryAppliesTo('La categoría no existe o no te pertenece.');
                }
                if (! $category->appliesToKind(JournalEntry::KIND_EXPENSE)) {
                    throw new InvalidCategoryAppliesTo();
                }
            }

            return JournalEntry::create([
                'user_id' => $userId,
                'kind' => JournalEntry::KIND_CREDIT_EXPENSE,
                'amount' => $amount,
                'account_origin_id' => $account->id,
                'account_destination_id' => null,
                'description' => $description,
                'category_id' => $categoryId,
                'occurred_at' => $occurredAt !== null ? Carbon::parse($occurredAt) : now(),
            ]);
        });
    }
}
