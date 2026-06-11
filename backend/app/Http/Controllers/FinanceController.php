<?php

namespace App\Http\Controllers;

use App\Domain\Finance\Actions\ArchiveCategory;
use App\Domain\Finance\Actions\CancelJournalEntry;
use App\Domain\Finance\Actions\CreateAccount;
use App\Domain\Finance\Actions\CreateCategory;
use App\Domain\Finance\Actions\DeleteAccount;
use App\Domain\Finance\Actions\PayCreditAccount;
use App\Domain\Finance\Actions\RegisterCreditExpense;
use App\Domain\Finance\Actions\RegisterExpense;
use App\Domain\Finance\Actions\RegisterIncome;
use App\Domain\Finance\Actions\RegisterTransfer;
use App\Domain\Finance\Actions\UpdateAccount;
use App\Domain\Finance\Actions\UpdateCategory;
use App\Domain\Finance\Actions\UpdateJournalEntry;
use App\Domain\Finance\Reports\BudgetsReport;
use App\Domain\Finance\Reports\ByAccountReport;
use App\Domain\Finance\Reports\CashflowMonthlyReport;
use App\Domain\Finance\Reports\CategoryBreakdownReport;
use App\Domain\Finance\Reports\CreditCardsReport;
use App\Domain\Finance\Reports\MonthlyComparisonReport;
use App\Domain\Finance\Reports\SpendingForecastReport;
use App\Domain\Finance\Services\FinancialStateService;
use App\Models\JournalEntry;
use Illuminate\Http\Request;

class FinanceController extends Controller
{
    private function service(Request $request): FinancialStateService
    {
        return new FinancialStateService($request->user()->id);
    }

    public function state(Request $request)
    {
        $state = $this->service($request);

        return response()->json([
            'bo' => $state->getBO(),
            'de' => $state->getDE(),
            'cr' => $state->getCR(),
            'burn_rate' => $state->getMonthlyBurnRate(),
            'credit_usage_pct' => $state->getCreditUsagePercentage(),
            'accounts' => $state->getAccounts(),
            'recent_entries' => $state->getRecentEntries(),
            'categories' => $state->getCategories(),
        ]);
    }

    public function income(Request $request)
    {
        $data = $request->validate([
            'account_id' => 'required|uuid|exists:accounts,id',
            'amount' => 'required|numeric|min:0.01',
            'description' => 'nullable|string',
            'category_id' => 'sometimes|nullable|uuid|exists:categories,id',
            'occurred_at' => 'sometimes|nullable|date',
        ]);

        $entry = RegisterIncome::execute(
            $request->user()->id,
            $data['account_id'],
            (float) $data['amount'],
            $data['description'] ?? null,
            $data['category_id'] ?? null,
            $data['occurred_at'] ?? null,
        );

        return response()->json(['message' => 'Ingreso registrado', 'entry' => $entry], 201);
    }

    public function expense(Request $request)
    {
        $data = $request->validate([
            'account_id' => 'required|uuid|exists:accounts,id',
            'amount' => 'required|numeric|min:0.01',
            'description' => 'nullable|string',
            'category_id' => 'sometimes|nullable|uuid|exists:categories,id',
            'occurred_at' => 'sometimes|nullable|date',
        ]);

        $entry = RegisterExpense::execute(
            $request->user()->id,
            $data['account_id'],
            (float) $data['amount'],
            $data['description'] ?? null,
            $data['category_id'] ?? null,
            $data['occurred_at'] ?? null,
        );

        return response()->json(['message' => 'Gasto registrado', 'entry' => $entry], 201);
    }

    public function creditExpense(Request $request)
    {
        $data = $request->validate([
            'account_id' => 'required|uuid|exists:accounts,id',
            'amount' => 'required|numeric|min:0.01',
            'description' => 'nullable|string',
            'category_id' => 'sometimes|nullable|uuid|exists:categories,id',
            'occurred_at' => 'sometimes|nullable|date',
        ]);

        $entry = RegisterCreditExpense::execute(
            $request->user()->id,
            $data['account_id'],
            (float) $data['amount'],
            $data['description'] ?? null,
            $data['category_id'] ?? null,
            $data['occurred_at'] ?? null,
        );

        return response()->json(['message' => 'Cargo a crédito registrado', 'entry' => $entry], 201);
    }

    public function payCredit(Request $request)
    {
        $data = $request->validate([
            'origin_id' => 'required|uuid|exists:accounts,id',
            'credit_account_id' => 'required|uuid|exists:accounts,id',
            'amount' => 'required|numeric|min:0.01',
            'description' => 'nullable|string',
            'occurred_at' => 'sometimes|nullable|date',
        ]);

        $entry = PayCreditAccount::execute(
            $request->user()->id,
            $data['origin_id'],
            $data['credit_account_id'],
            (float) $data['amount'],
            $data['description'] ?? null,
            $data['occurred_at'] ?? null,
        );

        return response()->json(['message' => 'Pago aplicado', 'entry' => $entry], 201);
    }

    public function transfer(Request $request)
    {
        $data = $request->validate([
            'origin_id' => 'required|uuid|exists:accounts,id',
            'destination_id' => 'required|uuid|exists:accounts,id',
            'amount' => 'required|numeric|min:0.01',
            'description' => 'nullable|string',
            'occurred_at' => 'sometimes|nullable|date',
        ]);

        $entry = RegisterTransfer::execute(
            $request->user()->id,
            $data['origin_id'],
            $data['destination_id'],
            (float) $data['amount'],
            $data['description'] ?? null,
            $data['occurred_at'] ?? null,
        );

        return response()->json(['message' => 'Transferencia registrada', 'entry' => $entry], 201);
    }

    public function listAccounts(Request $request)
    {
        $includeArchived = $request->boolean('include_archived');

        return response()->json([
            'accounts' => $this->service($request)->getAccounts($includeArchived),
        ]);
    }

    public function createAccount(Request $request)
    {
        $data = $request->validate([
            'name' => 'required|string',
            'description' => 'nullable|string|max:200',
            'type' => 'required|in:debit,credit',
            'credit_limit' => 'nullable|numeric|min:0',
            'closing_day' => 'nullable|integer|between:1,31',
            'payment_day' => 'nullable|integer|between:1,31',
            'interest_rate' => 'nullable|numeric|min:0|max:1',
            'minimum_payment_pct' => 'nullable|numeric|min:0|max:1',
        ]);

        $creditMeta = array_intersect_key($data, array_flip([
            'credit_limit', 'closing_day', 'payment_day', 'interest_rate', 'minimum_payment_pct',
        ]));

        $account = CreateAccount::execute(
            $request->user()->id,
            $data['name'],
            $data['type'],
            $creditMeta,
            $data['description'] ?? null,
        );

        return response()->json(['account' => $account], 201);
    }

    public function updateAccount(Request $request, string $id)
    {
        $data = $request->validate([
            'name' => 'sometimes|string',
            'description' => 'sometimes|nullable|string|max:200',
            'credit_limit' => 'sometimes|nullable|numeric|min:0',
            'closing_day' => 'sometimes|nullable|integer|between:1,31',
            'payment_day' => 'sometimes|nullable|integer|between:1,31',
            'interest_rate' => 'sometimes|nullable|numeric|min:0|max:1',
            'minimum_payment_pct' => 'sometimes|nullable|numeric|min:0|max:1',
        ]);

        $account = UpdateAccount::execute($request->user()->id, $id, $data);

        return response()->json(['account' => $account]);
    }

    public function deleteAccount(Request $request, string $id)
    {
        DeleteAccount::execute($request->user()->id, $id);

        return response()->json(['message' => 'Cuenta eliminada']);
    }

    public function listEntries(Request $request)
    {
        $userId = $request->user()->id;
        $filters = $request->validate([
            'account_id' => ['sometimes', 'uuid', 'exists:accounts,id,user_id,'.$userId],
            'category_id' => ['sometimes', 'uuid', 'exists:categories,id,user_id,'.$userId],
            'kind' => 'sometimes|in:income,expense,credit_expense,debt_payment,transfer,adjustment',
            'from' => 'sometimes|date',
            'to' => 'sometimes|date',
            'per_page' => 'sometimes|integer|min:1|max:200',
        ]);

        $query = JournalEntry::with(['origin', 'destination', 'category'])
            ->where('user_id', $request->user()->id)
            ->orderByDesc('occurred_at');

        self::applyEntryFilters($query, $filters);

        $perPage = (int) ($filters['per_page'] ?? 25);

        return response()->json($query->paginate($perPage));
    }

    /**
     * Aplica filtros estandarizados a una query de JournalEntry. Compartido por
     * `listEntries` (paginado para /entries) y `entriesByBucket` (sin paginar
     * para drill-down). Centralizar evita que la semántica de filtros diverja.
     *
     * `account_id` matchea cuentas en origin OR destination (la entry "toca" la cuenta).
     */
    private static function applyEntryFilters(\Illuminate\Database\Eloquent\Builder $query, array $filters): void
    {
        if (isset($filters['account_id'])) {
            $id = $filters['account_id'];
            $query->where(function ($q) use ($id) {
                $q->where('account_origin_id', $id)
                    ->orWhere('account_destination_id', $id);
            });
        }

        // `array_key_exists` en lugar de `isset` porque la key puede estar
        // presente con valor `null` para filtrar entries sin categoría (bucket
        // "Sin categorizar" de los reportes que agrupan por categoría).
        if (array_key_exists('category_id', $filters)) {
            if ($filters['category_id'] === null) {
                $query->whereNull('category_id');
            } else {
                $query->where('category_id', $filters['category_id']);
            }
        }

        if (isset($filters['kind'])) {
            // `kind=expense` engloba expense + credit_expense para alinear el
            // drill-down con la semántica que ya usan los Report Services
            // agregados (CategoryBreakdownReport, BudgetsReport, SpendingForecastReport).
            // Otros kinds mantienen comportamiento literal.
            if ($filters['kind'] === JournalEntry::KIND_EXPENSE) {
                $query->whereIn('kind', [
                    JournalEntry::KIND_EXPENSE,
                    JournalEntry::KIND_CREDIT_EXPENSE,
                ]);
            } else {
                $query->where('kind', $filters['kind']);
            }
        }

        if (isset($filters['from'])) {
            // El `from` es una fecha (YYYY-MM-DD) que el cliente interpreta
            // como inicio del día. Usar `>= $from` (sin hora) ya cubre todo
            // el día porque Postgres compara timestamps con la cadena tratada
            // como medianoche local.
            $query->where('occurred_at', '>=', $filters['from']);
        }

        if (isset($filters['to'])) {
            // El `to` es una fecha (YYYY-MM-DD); sin hora, se trata como
            // 00:00:00 del día y excluiría todo lo que ocurra después en
            // ese mismo día. Patrón consistente con los Report Services que
            // sí agregan ' 23:59:59' (CategoryBreakdownReport, etc.).
            $query->where('occurred_at', '<=', $filters['to'].' 23:59:59');
        }
    }

    public function updateEntry(Request $request, string $id)
    {
        $data = $request->validate([
            'category_id' => 'sometimes|nullable|uuid|exists:categories,id',
            'description' => 'sometimes|nullable|string|max:200',
            'occurred_at' => 'sometimes|date',
            // No verificamos exists: aquí porque la Action resuelve la cuenta
            // dentro del scope del usuario y lanza un mensaje de dominio más claro.
            'account_origin_id' => 'sometimes|nullable|uuid',
            'account_destination_id' => 'sometimes|nullable|uuid',
            'amount' => 'sometimes|numeric|gt:0',
        ]);

        $entry = UpdateJournalEntry::execute($request->user()->id, $id, $data);

        return response()->json(['entry' => $entry]);
    }

    public function cancelEntry(Request $request, string $id)
    {
        CancelJournalEntry::execute($request->user()->id, $id);

        return response()->json(['message' => 'Movimiento cancelado']);
    }

    public function listCategories(Request $request)
    {
        $includeArchived = $request->boolean('include_archived');
        $appliesTo = $request->query('applies_to');

        $categories = $this->service($request)->getCategories($includeArchived);

        if ($appliesTo && in_array($appliesTo, ['income', 'expense'], true)) {
            $categories = $categories->filter(
                fn ($c) => $c->applies_to === $appliesTo || $c->applies_to === 'both',
            )->values();
        }

        return response()->json(['categories' => $categories]);
    }

    public function createCategory(Request $request)
    {
        $data = $request->validate([
            'name' => 'required|string|max:80',
            'applies_to' => 'required|in:income,expense,both',
            'color_slug' => 'required|string|max:30',
            'icon_slug' => 'required|string|max:40',
            'monthly_limit' => 'sometimes|nullable|numeric|min:0',
        ]);

        $category = CreateCategory::execute(
            $request->user()->id,
            $data['name'],
            $data['applies_to'],
            $data['color_slug'],
            $data['icon_slug'],
            isset($data['monthly_limit']) ? (float) $data['monthly_limit'] : null,
        );

        return response()->json(['category' => $category], 201);
    }

    public function updateCategory(Request $request, string $id)
    {
        $data = $request->validate([
            'name' => 'sometimes|string|max:80',
            'applies_to' => 'sometimes|in:income,expense,both',
            'color_slug' => 'sometimes|string|max:30',
            'icon_slug' => 'sometimes|string|max:40',
            'monthly_limit' => 'sometimes|nullable|numeric|min:0',
        ]);

        $category = UpdateCategory::execute($request->user()->id, $id, $data);

        return response()->json(['category' => $category]);
    }

    public function archiveCategory(Request $request, string $id)
    {
        ArchiveCategory::execute($request->user()->id, $id);

        return response()->json(['message' => 'Categoría archivada']);
    }

    public function reportByCategory(Request $request)
    {
        $data = $request->validate([
            'kind' => 'required|in:income,expense',
            'from' => 'required|date',
            'to' => 'required|date|after_or_equal:from',
            'account_id' => 'sometimes|nullable|uuid|exists:accounts,id',
        ]);

        $report = (new CategoryBreakdownReport($request->user()->id))->generate(
            $data['kind'],
            $data['account_id'] ?? null,
            $data['from'],
            $data['to'],
        );

        return response()->json($report);
    }

    public function reportCashflowMonthly(Request $request)
    {
        $data = $request->validate([
            'from' => 'required|date',
            'to' => 'required|date|after_or_equal:from',
            'account_id' => 'sometimes|nullable|uuid|exists:accounts,id',
        ]);

        $report = (new CashflowMonthlyReport($request->user()->id))->generate(
            $data['from'],
            $data['to'],
            $data['account_id'] ?? null,
        );

        return response()->json($report);
    }

    public function reportMonthComparison(Request $request)
    {
        $data = $request->validate([
            'kind' => 'required|in:income,expense',
            'month' => ['required', 'regex:/^\d{4}-\d{2}$/'],
            'account_id' => 'sometimes|nullable|uuid|exists:accounts,id',
        ]);

        $report = (new MonthlyComparisonReport($request->user()->id))->generate(
            $data['kind'],
            $data['account_id'] ?? null,
            $data['month'],
        );

        return response()->json($report);
    }

    public function reportCreditCards(Request $request)
    {
        $report = (new CreditCardsReport($request->user()->id))->generate();

        return response()->json($report);
    }

    public function reportBudgets(Request $request)
    {
        $report = (new BudgetsReport($request->user()->id))->generate();

        return response()->json($report);
    }

    public function reportForecast(Request $request)
    {
        $report = (new SpendingForecastReport($request->user()->id))->generate();

        return response()->json($report);
    }

    public function reportByAccount(Request $request)
    {
        $data = $request->validate([
            'from' => 'sometimes|date',
            'to' => 'sometimes|date|after_or_equal:from',
        ]);

        // Default: mes en curso (primer día → hoy), consistente con /entries.
        $from = $data['from'] ?? now()->startOfMonth()->toDateString();
        $to = $data['to'] ?? now()->toDateString();

        $report = (new ByAccountReport($request->user()->id))->generate($from, $to);

        return response()->json($report);
    }

    /**
     * Endpoint genérico de drill-down: dado un set de filtros estandarizados
     * (kind, account_id, category_id, from, to, year_month), devuelve hasta 100
     * journal_entries que matchean, con eager loading de relaciones. Sirve a
     * todos los reportes para no duplicar lógica por bucket.
     */
    public function entriesByBucket(Request $request)
    {
        $userId = $request->user()->id;
        // El drill-down permite auditar histórico de cuentas/categorías archivadas,
        // por eso `exists:` no filtra por `deleted_at` (la regla no respeta scopes
        // de soft delete). El scope por `user_id` sí es defensa explícita.
        $data = $request->validate([
            'kind' => 'sometimes|in:income,expense,credit_expense,debt_payment,transfer,adjustment',
            'account_id' => ['sometimes', 'uuid', 'exists:accounts,id,user_id,'.$userId],
            'category_id' => ['sometimes', 'nullable', 'uuid', 'exists:categories,id,user_id,'.$userId],
            'from' => 'sometimes|date',
            'to' => 'sometimes|date',
            'year_month' => ['sometimes', 'regex:/^\d{4}-(0[1-9]|1[0-2])$/'],
        ]);

        // Exige al menos un filtro para evitar dump de toda la cuenta.
        if (empty($data)) {
            return response()->json([
                'error' => 'Drill-down requiere al menos un filtro.',
                'code' => 'missing_filters',
            ], 422);
        }

        // year_month es atajo: traduce a from/to (primer y último día del mes).
        // Si vienen ambos, year_month prevalece.
        if (isset($data['year_month'])) {
            [$y, $m] = explode('-', $data['year_month']);
            $start = \Carbon\Carbon::create((int) $y, (int) $m, 1)->startOfDay();
            $data['from'] = $start->toDateString();
            $data['to'] = $start->copy()->endOfMonth()->toDateString();
            unset($data['year_month']);
        }

        $filters = $data;

        $query = JournalEntry::with(['origin', 'destination', 'category'])
            ->where('user_id', $request->user()->id)
            ->orderByDesc('occurred_at');

        self::applyEntryFilters($query, $filters);

        $totalCount = (clone $query)->count();
        $cap = 100;
        $entries = $query->limit($cap)->get();

        return response()->json([
            'entries' => $entries,
            'truncated' => $totalCount > $cap,
            'total_count' => $totalCount,
            'bucket_label' => self::buildBucketLabel($filters, $request->user()->id),
        ]);
    }

    /**
     * Arma un label humano del bucket basándose en los filtros. Lazily resuelve
     * nombres (cuenta, categoría) sólo cuando los ids están presentes.
     */
    private static function buildBucketLabel(array $filters, string $userId): string
    {
        $parts = [];

        $kindLabel = [
            JournalEntry::KIND_INCOME => 'Ingresos',
            JournalEntry::KIND_EXPENSE => 'Gastos',
            JournalEntry::KIND_CREDIT_EXPENSE => 'Cargos a tarjeta',
            JournalEntry::KIND_DEBT_PAYMENT => 'Pagos a tarjeta',
            JournalEntry::KIND_TRANSFER => 'Transferencias',
        ];
        $parts[] = $kindLabel[$filters['kind'] ?? ''] ?? 'Movimientos';

        // `array_key_exists` para captar el caso `category_id=null` (bucket
        // "Sin categorizar"), que `isset` no detectaría.
        if (array_key_exists('category_id', $filters)) {
            if ($filters['category_id'] === null) {
                $parts[] = 'sin categorizar';
            } else {
                $cat = \App\Models\Category::withTrashed()
                    ->where('user_id', $userId)
                    ->find($filters['category_id']);
                if ($cat) {
                    $parts[] = 'de '.$cat->name;
                }
            }
        }

        if (isset($filters['account_id'])) {
            $acc = \App\Models\Account::withTrashed()
                ->where('user_id', $userId)
                ->find($filters['account_id']);
            if ($acc) {
                $parts[] = 'en '.$acc->name;
            }
        }

        if (isset($filters['from']) && isset($filters['to'])) {
            $parts[] = 'del '.$filters['from'].' al '.$filters['to'];
        } elseif (isset($filters['from'])) {
            $parts[] = 'desde '.$filters['from'];
        } elseif (isset($filters['to'])) {
            $parts[] = 'hasta '.$filters['to'];
        }

        return implode(' ', $parts);
    }
}
