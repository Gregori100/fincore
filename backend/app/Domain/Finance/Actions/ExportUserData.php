<?php

namespace App\Domain\Finance\Actions;

use App\Models\Account;
use App\Models\Category;
use App\Models\JournalEntry;

class ExportUserData
{
    public const VERSION = 1;

    /**
     * Arma un snapshot serializable del dominio financiero activo del usuario:
     * cuentas, categorías y movimientos (sin soft-deleted, sin el plan). Los
     * `local_id` son los UUID originales y sólo sirven para resolver las
     * referencias dentro del archivo; al importar se descartan.
     *
     * @return array{version:int, exported_at:string, accounts:array, categories:array, entries:array}
     */
    public static function execute(string $userId): array
    {
        $accounts = Account::where('user_id', $userId)
            ->orderBy('created_at')
            ->get()
            ->map(fn (Account $a) => [
                'local_id' => $a->id,
                'name' => $a->name,
                'type' => $a->type,
                'is_protected' => (bool) $a->is_protected,
                'description' => $a->description,
                'credit_limit' => $a->credit_limit !== null ? (float) $a->credit_limit : null,
                'closing_day' => $a->closing_day,
                'payment_day' => $a->payment_day,
                'interest_rate' => $a->interest_rate !== null ? (float) $a->interest_rate : null,
                'minimum_payment_pct' => $a->minimum_payment_pct !== null ? (float) $a->minimum_payment_pct : null,
            ])
            ->values()
            ->all();

        $categories = Category::where('user_id', $userId)
            ->orderBy('created_at')
            ->get()
            ->map(fn (Category $c) => [
                'local_id' => $c->id,
                'name' => $c->name,
                'applies_to' => $c->applies_to,
                'color_slug' => $c->color_slug,
                'icon_slug' => $c->icon_slug,
                'monthly_limit' => $c->monthly_limit !== null ? (float) $c->monthly_limit : null,
            ])
            ->values()
            ->all();

        $entries = JournalEntry::where('user_id', $userId)
            ->orderBy('occurred_at')
            ->get()
            ->map(fn (JournalEntry $e) => [
                'kind' => $e->kind,
                'amount' => (float) $e->amount,
                'description' => $e->description,
                'occurred_at' => optional($e->occurred_at)->toIso8601String(),
                'account_origin_local' => $e->account_origin_id,
                'account_destination_local' => $e->account_destination_id,
                'category_local' => $e->category_id,
            ])
            ->values()
            ->all();

        return [
            'version' => self::VERSION,
            'exported_at' => now()->toIso8601String(),
            'accounts' => $accounts,
            'categories' => $categories,
            'entries' => $entries,
        ];
    }
}
