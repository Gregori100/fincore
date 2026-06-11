<?php

namespace App\Domain\Finance\Reports;

use App\Models\JournalEntry;
use Carbon\CarbonImmutable;

/**
 * Proyecta el gasto del mes en curso por categoría usando el método lineal
 * por ritmo:
 *
 *   proyeccion = gastado_actual × (dias_totales_del_mes / dias_transcurridos)
 *
 * Compara la proyección contra el promedio de los 3 meses calendario
 * inmediatamente anteriores al mes en curso. El promedio se divide siempre
 * entre 3 (no entre meses con actividad) — refleja categorías esporádicas
 * con promedios reducidos en lugar de inflarlos.
 *
 * Cobertura: una categoría aparece si y sólo si tiene al menos 1 entry de
 * gasto (kind ∈ {expense, credit_expense}) en la ventana histórica. La regla
 * se aplica en SQL via HAVING para no traer ruido a PHP.
 *
 * Las categorías archivadas con histórico mantienen su nombre/color/icono
 * (leftJoin sobre `categories` que no respeta el global scope de SoftDeletes
 * — patrón idéntico al de CategoryBreakdownReport).
 *
 * Entries cancelados (`journal_entries.deleted_at != null`) se excluyen
 * automáticamente por el scope global de SoftDeletes en JournalEntry.
 */
final class SpendingForecastReport
{
    public const UNCATEGORIZED_LABEL = 'Sin categorizar';

    public function __construct(private string $userId) {}

    /**
     * @return array{
     *   month: string,
     *   today: string,
     *   days_in_month: int,
     *   days_elapsed: int,
     *   window_from: string,
     *   window_to: string,
     *   categories: list<array{
     *     category_id: ?string, name: string, color_slug: ?string, icon_slug: ?string,
     *     current_spent: float, historical_average: float, projection: float, delta_pct: ?float,
     *   }>,
     *   totals: array{
     *     current_spent: float, historical_average: float, projection: float, delta_pct: ?float,
     *   },
     * }
     */
    public function generate(): array
    {
        $today = CarbonImmutable::now();
        $month = $today->format('Y-m');
        $daysInMonth = $today->daysInMonth;
        // Clamp defensivo: now()->day nunca devuelve 0 hoy, pero evita división
        // por cero si un bug futuro de Carbon lo hiciera.
        $daysElapsed = max(1, $today->day);

        $currentFrom = $today->startOfMonth()->toDateString();
        $currentToEndOfDay = $today->endOfDay()->toDateTimeString();

        // Ventana histórica: 3 meses calendario inmediatamente anteriores.
        // Si hoy es 10 jun, ventana = 1 mar → 31 may.
        $windowToDate = $today->startOfMonth()->subDay(); // último día del mes pasado
        $windowFromDate = $windowToDate->startOfMonth()->subMonthsNoOverflow(2);
        $windowFrom = $windowFromDate->toDateString();
        $windowTo = $windowToDate->toDateString();
        $windowToEndOfDay = $windowToDate->endOfDay()->toDateTimeString();

        // 1 sola query con SUMs condicionales por category_id. El rango global
        // cubre ventana + mes actual; cada SUM filtra el segmento que aplica.
        // selectRaw con bindings posicionales es idiomático Laravel y mantiene
        // la query parametrizada (sin riesgo de inyección, portable PG/SQLite).
        $rows = JournalEntry::query()
            ->select([
                'journal_entries.category_id',
                'categories.name',
                'categories.color_slug',
                'categories.icon_slug',
            ])
            ->selectRaw(
                'SUM(CASE WHEN journal_entries.occurred_at >= ? THEN journal_entries.amount ELSE 0 END) AS current_spent',
                [$currentFrom]
            )
            ->selectRaw(
                'SUM(CASE WHEN journal_entries.occurred_at >= ? AND journal_entries.occurred_at <= ? THEN journal_entries.amount ELSE 0 END) AS historical_total',
                [$windowFrom, $windowToEndOfDay]
            )
            ->where('journal_entries.user_id', $this->userId)
            ->whereIn('journal_entries.kind', [
                JournalEntry::KIND_EXPENSE,
                JournalEntry::KIND_CREDIT_EXPENSE,
            ])
            ->where('journal_entries.occurred_at', '>=', $windowFrom)
            ->where('journal_entries.occurred_at', '<=', $currentToEndOfDay)
            ->leftJoin('categories', 'categories.id', '=', 'journal_entries.category_id')
            ->groupBy('journal_entries.category_id', 'categories.name', 'categories.color_slug', 'categories.icon_slug')
            ->havingRaw(
                'SUM(CASE WHEN journal_entries.occurred_at >= ? AND journal_entries.occurred_at <= ? THEN journal_entries.amount ELSE 0 END) > 0',
                [$windowFrom, $windowToEndOfDay]
            )
            ->get();

        $buckets = $rows->map(function ($row) use ($daysInMonth, $daysElapsed) {
            $hasCategory = $row->category_id !== null;
            $currentSpent = (float) $row->current_spent;
            $historicalAverage = (float) $row->historical_total / 3.0;
            $projection = $currentSpent * ($daysInMonth / $daysElapsed);
            $deltaPct = $this->computeDeltaPct($projection, $historicalAverage);

            return [
                'category_id' => $row->category_id,
                'name' => $hasCategory ? $row->name : self::UNCATEGORIZED_LABEL,
                'color_slug' => $hasCategory ? $row->color_slug : null,
                'icon_slug' => $hasCategory ? $row->icon_slug : null,
                'current_spent' => $currentSpent,
                'historical_average' => $historicalAverage,
                'projection' => $projection,
                'delta_pct' => $deltaPct,
            ];
        })->all();

        usort($buckets, function (array $a, array $b) {
            // null al final.
            if ($a['delta_pct'] === null && $b['delta_pct'] === null) {
                return strcmp($a['name'], $b['name']);
            }
            if ($a['delta_pct'] === null) {
                return 1;
            }
            if ($b['delta_pct'] === null) {
                return -1;
            }
            // delta_pct desc; desempate alfabético.
            $cmp = $b['delta_pct'] <=> $a['delta_pct'];

            return $cmp !== 0 ? $cmp : strcmp($a['name'], $b['name']);
        });

        $totalCurrent = (float) array_sum(array_column($buckets, 'current_spent'));
        $totalAverage = (float) array_sum(array_column($buckets, 'historical_average'));
        $totalProjection = (float) array_sum(array_column($buckets, 'projection'));
        $totalDeltaPct = $this->computeDeltaPct($totalProjection, $totalAverage);

        return [
            'month' => $month,
            'today' => $today->toDateString(),
            'days_in_month' => $daysInMonth,
            'days_elapsed' => $daysElapsed,
            'window_from' => $windowFrom,
            'window_to' => $windowTo,
            'categories' => $buckets,
            'totals' => [
                'current_spent' => $totalCurrent,
                'historical_average' => $totalAverage,
                'projection' => $totalProjection,
                'delta_pct' => $totalDeltaPct,
            ],
        ];
    }

    /**
     * (proyeccion - promedio) / promedio × 100, redondeado a 1 decimal.
     * Devuelve null cuando el promedio es 0 (sin base de comparación).
     */
    private function computeDeltaPct(float $projection, float $average): ?float
    {
        if ($average === 0.0) {
            return null;
        }

        return round((($projection - $average) / $average) * 100.0, 1);
    }
}
