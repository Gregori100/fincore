<?php

namespace App\Domain\Finance\Actions;

use App\Domain\Finance\Exceptions\InvalidAccountType;
use App\Domain\Finance\Exceptions\InvalidCategoryAppliesTo;
use App\Models\Account;
use App\Models\Category;
use App\Models\JournalEntry;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;

class RegisterExpense
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
            // lockForUpdate serializa mutaciones concurrentes sobre la misma
            // cuenta. Mantenemos el lock aunque ya no validamos fondos (libreta
            // libre: saldos negativos son legales): evita ordenamiento raro de
            // dos gastos simultáneos.
            $account = Account::where('id', $accountId)
                ->where('user_id', $userId)
                ->lockForUpdate()
                ->firstOrFail();

            if (! $account->isCashLike()) {
                throw new InvalidAccountType('Un gasto en efectivo/débito solo puede salir de una cuenta cash o debit. Usa credit_expense para tarjetas de crédito.');
            }

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
                'kind' => JournalEntry::KIND_EXPENSE,
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
