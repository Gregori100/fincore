<?php

namespace App\Domain\Finance\Reports;

use App\Models\JournalEntry;
use Illuminate\Support\Facades\DB;

/**
 * Agrupa entries del usuario por categoría dentro de un rango de fechas.
 *
 * - `kind=expense` incluye `expense` + `credit_expense` (semánticamente egresos).
 * - `kind=income` incluye sólo `income`.
 *
 * Los entries sin categoría aparecen como un bucket especial con
 * `category_id=null` y `name="Sin categorizar"`. Las categorías archivadas
 * conservan su nombre/color/icono en el reporte (JOIN con withTrashed).
 *
 * Los entries cancelados (`deleted_at != null` en journal_entries) se excluyen
 * automáticamente por el scope global de SoftDeletes — todas las queries
 * pasan por Eloquent.
 */
final class CategoryBreakdownReport
{
    public const UNCATEGORIZED_LABEL = 'Sin categorizar';

    public function __construct(private string $userId)
    {
    }

    /**
     * @return array{
     *   total: float,
     *   count: int,
     *   buckets: list<array{category_id: ?string, name: string, color_slug: ?string, icon_slug: ?string, total: float, count: int}>
     * }
     */
    public function generate(string $kind, ?string $accountId, string $from, string $to): array
    {
        $kinds = match ($kind) {
            'income' => [JournalEntry::KIND_INCOME],
            'expense' => [JournalEntry::KIND_EXPENSE, JournalEntry::KIND_CREDIT_EXPENSE],
            default => [],
        };

        // Para expense: origin es la cuenta donde sale el dinero (Bolsa/débito/crédito).
        // Para income: destination es la cuenta donde llega el dinero.
        // El filtro `account_id` aplica al lado relevante según el kind.
        $accountColumn = $kind === 'income' ? 'account_destination_id' : 'account_origin_id';

        $base = JournalEntry::query()
            ->where('journal_entries.user_id', $this->userId)
            ->whereIn('journal_entries.kind', $kinds)
            ->where('journal_entries.occurred_at', '>=', $from)
            ->where('journal_entries.occurred_at', '<=', $to.' 23:59:59');

        if ($accountId !== null) {
            $base->where("journal_entries.{$accountColumn}", $accountId);
        }

        $rows = (clone $base)
            ->leftJoin('categories', 'categories.id', '=', 'journal_entries.category_id')
            ->groupBy('journal_entries.category_id', 'categories.name', 'categories.color_slug', 'categories.icon_slug')
            ->orderByDesc(DB::raw('SUM(journal_entries.amount)'))
            ->get([
                'journal_entries.category_id',
                'categories.name',
                'categories.color_slug',
                'categories.icon_slug',
                DB::raw('SUM(journal_entries.amount) AS total'),
                DB::raw('COUNT(*) AS entries_count'),
            ]);

        $buckets = $rows->map(function ($row) {
            $hasCategory = $row->category_id !== null;
            return [
                'category_id' => $row->category_id,
                'name' => $hasCategory ? $row->name : self::UNCATEGORIZED_LABEL,
                'color_slug' => $hasCategory ? $row->color_slug : null,
                'icon_slug' => $hasCategory ? $row->icon_slug : null,
                'total' => (float) $row->total,
                'count' => (int) $row->entries_count,
            ];
        })->all();

        $total = array_sum(array_column($buckets, 'total'));
        $count = array_sum(array_column($buckets, 'count'));

        return [
            'total' => (float) $total,
            'count' => (int) $count,
            'buckets' => $buckets,
        ];
    }
}
