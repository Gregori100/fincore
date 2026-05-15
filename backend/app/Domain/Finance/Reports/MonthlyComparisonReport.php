<?php

namespace App\Domain\Finance\Reports;

use Carbon\CarbonImmutable;

/**
 * Compara los buckets por categoría del mes actual contra el inmediato anterior.
 * Se monta sobre `CategoryBreakdownReport` para evitar duplicar la lógica de
 * agregación (JOIN withTrashed, bucket "Sin categorizar", scope per user,
 * exclusión de cancelados, kind=expense que incluye credit_expense, etc.).
 *
 * Para cada categoría que aparece en cualquiera de los dos meses, devuelve:
 *  - current: monto del mes actual (0 si no aparece)
 *  - previous: monto del mes anterior (0 si no aparece)
 *  - delta: current - previous
 *  - delta_pct: (delta / previous) * 100, o null si previous == 0 (matemáticamente
 *    indefinido — el frontend lo muestra como "nueva")
 *
 * Los buckets se ordenan por |delta| desc (cambio más grande primero).
 */
final class MonthlyComparisonReport
{
    public function __construct(private string $userId)
    {
    }

    /**
     * @param  string  $currentMonth  formato 'YYYY-MM'
     */
    public function generate(string $kind, ?string $accountId, string $currentMonth): array
    {
        $current = CarbonImmutable::createFromFormat('Y-m', $currentMonth)->startOfMonth();
        $previous = $current->subMonthNoOverflow();

        $currentFrom = $current->toDateString();
        $currentTo = $current->endOfMonth()->toDateString();
        $previousFrom = $previous->toDateString();
        $previousTo = $previous->endOfMonth()->toDateString();

        $service = new CategoryBreakdownReport($this->userId);
        $currentReport = $service->generate($kind, $accountId, $currentFrom, $currentTo);
        $previousReport = $service->generate($kind, $accountId, $previousFrom, $previousTo);

        // Indexar por una clave única que tolere category_id=null (sin categorizar).
        $keyOf = fn (array $b) => $b['category_id'] ?? '__uncategorized__';

        $byKey = [];
        foreach ($currentReport['buckets'] as $b) {
            $byKey[$keyOf($b)] = [
                'category_id' => $b['category_id'],
                'name' => $b['name'],
                'color_slug' => $b['color_slug'],
                'icon_slug' => $b['icon_slug'],
                'current' => (float) $b['total'],
                'previous' => 0.0,
            ];
        }
        foreach ($previousReport['buckets'] as $b) {
            $key = $keyOf($b);
            if (isset($byKey[$key])) {
                $byKey[$key]['previous'] = (float) $b['total'];
            } else {
                // La categoría tuvo actividad sólo en el mes anterior. Conservamos
                // los slugs del mes pasado para que el badge se pinte igual.
                $byKey[$key] = [
                    'category_id' => $b['category_id'],
                    'name' => $b['name'],
                    'color_slug' => $b['color_slug'],
                    'icon_slug' => $b['icon_slug'],
                    'current' => 0.0,
                    'previous' => (float) $b['total'],
                ];
            }
        }

        $buckets = array_map(function ($b) {
            $delta = $b['current'] - $b['previous'];
            $deltaPct = $b['previous'] > 0
                ? ($delta / $b['previous']) * 100.0
                : null;

            return [
                'category_id' => $b['category_id'],
                'name' => $b['name'],
                'color_slug' => $b['color_slug'],
                'icon_slug' => $b['icon_slug'],
                'current' => $b['current'],
                'previous' => $b['previous'],
                'delta' => $delta,
                'delta_pct' => $deltaPct,
            ];
        }, array_values($byKey));

        usort($buckets, fn ($a, $b) => abs($b['delta']) <=> abs($a['delta']));

        $currentTotal = (float) $currentReport['total'];
        $previousTotal = (float) $previousReport['total'];
        $totalDelta = $currentTotal - $previousTotal;
        $totalDeltaPct = $previousTotal > 0
            ? ($totalDelta / $previousTotal) * 100.0
            : null;

        return [
            'current_month' => $current->format('Y-m'),
            'previous_month' => $previous->format('Y-m'),
            'current_total' => $currentTotal,
            'previous_total' => $previousTotal,
            'delta' => $totalDelta,
            'delta_pct' => $totalDeltaPct,
            'buckets' => $buckets,
        ];
    }
}
