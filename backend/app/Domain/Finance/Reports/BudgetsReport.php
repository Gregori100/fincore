<?php

namespace App\Domain\Finance\Reports;

use App\Models\Category;
use App\Models\JournalEntry;
use Carbon\CarbonImmutable;

/**
 * Estado de presupuestos del mes en curso. Sólo considera categorías:
 *  - activas (no archivadas)
 *  - con `monthly_limit` configurado (no null)
 *  - con `applies_to ∈ {expense, both}` — los income no se incluyen aún
 *    (el campo se persiste pero no se usa en reportes).
 *
 * El "gasto" es la suma de `expense + credit_expense` con esa `category_id`
 * cuyo `occurred_at` cae entre el día 1 del mes en curso y hoy. Entries
 * cancelados quedan fuera automáticamente por el scope global de SoftDeletes.
 */
final class BudgetsReport
{
    public function __construct(private string $userId)
    {
    }

    /**
     * @return array{
     *   month: string,
     *   total_limit: float, total_spent: float, total_pct: ?float,
     *   buckets: list<array{
     *     category_id: string, name: string,
     *     color_slug: string, icon_slug: string,
     *     monthly_limit: float, spent: float,
     *     remaining: float, pct_consumed: float,
     *   }>,
     * }
     */
    public function generate(): array
    {
        $today = CarbonImmutable::today();
        $from = $today->startOfMonth();
        $month = $today->format('Y-m');

        $categories = Category::query()
            ->where('user_id', $this->userId)
            ->whereNotNull('monthly_limit')
            ->whereIn('applies_to', [Category::APPLIES_EXPENSE, Category::APPLIES_BOTH])
            ->whereNull('deleted_at')
            ->orderBy('name')
            ->get();

        $buckets = $categories->map(function (Category $category) use ($from, $today) {
            $spent = (float) JournalEntry::query()
                ->where('user_id', $this->userId)
                ->where('category_id', $category->id)
                ->whereIn('kind', [
                    JournalEntry::KIND_EXPENSE,
                    JournalEntry::KIND_CREDIT_EXPENSE,
                ])
                ->whereBetween('occurred_at', [
                    $from->toDateString().' 00:00:00',
                    $today->toDateString().' 23:59:59',
                ])
                ->sum('amount');

            $limit = (float) $category->monthly_limit;
            $remaining = $limit - $spent;

            $pct = $this->pctConsumed($limit, $spent);

            return [
                'category_id' => $category->id,
                'name' => $category->name,
                'color_slug' => $category->color_slug,
                'icon_slug' => $category->icon_slug,
                'monthly_limit' => $limit,
                'spent' => $spent,
                'remaining' => $remaining,
                'pct_consumed' => $pct,
            ];
        })->all();

        // Orden por % consumido descendente: las categorías al borde arriba.
        usort($buckets, fn ($a, $b) => $b['pct_consumed'] <=> $a['pct_consumed']);

        $totalLimit = (float) array_sum(array_column($buckets, 'monthly_limit'));
        $totalSpent = (float) array_sum(array_column($buckets, 'spent'));
        $totalPct = $totalLimit > 0 ? ($totalSpent / $totalLimit) * 100.0 : null;

        return [
            'month' => $month,
            'total_limit' => $totalLimit,
            'total_spent' => $totalSpent,
            'total_pct' => $totalPct,
            'buckets' => $buckets,
        ];
    }

    /**
     * % consumido del presupuesto. Si el límite es 0 y se gastó, devolvemos 999
     * para forzar color rojo en la UI; sin límite efectivo cualquier gasto está
     * "fuera" — el remaining negativo es la fuente de verdad del monto.
     */
    private function pctConsumed(float $limit, float $spent): float
    {
        if ($limit > 0) {
            return ($spent / $limit) * 100.0;
        }
        return $spent > 0 ? 999.0 : 0.0;
    }
}
