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
use App\Domain\Finance\Reports\CategoryBreakdownReport;
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
        ]);

        $entry = RegisterIncome::execute(
            $request->user()->id,
            $data['account_id'],
            (float) $data['amount'],
            $data['description'] ?? null,
            $data['category_id'] ?? null,
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
        ]);

        $entry = RegisterExpense::execute(
            $request->user()->id,
            $data['account_id'],
            (float) $data['amount'],
            $data['description'] ?? null,
            $data['category_id'] ?? null,
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
        ]);

        $entry = RegisterCreditExpense::execute(
            $request->user()->id,
            $data['account_id'],
            (float) $data['amount'],
            $data['description'] ?? null,
            $data['category_id'] ?? null,
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
        ]);

        $entry = PayCreditAccount::execute(
            $request->user()->id,
            $data['origin_id'],
            $data['credit_account_id'],
            (float) $data['amount'],
            $data['description'] ?? null,
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
        ]);

        $entry = RegisterTransfer::execute(
            $request->user()->id,
            $data['origin_id'],
            $data['destination_id'],
            (float) $data['amount'],
            $data['description'] ?? null,
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
        $filters = $request->validate([
            'account_id' => 'sometimes|uuid|exists:accounts,id',
            'category_id' => 'sometimes|uuid|exists:categories,id',
            'kind' => 'sometimes|in:income,expense,credit_expense,debt_payment,transfer,adjustment',
            'from' => 'sometimes|date',
            'to' => 'sometimes|date',
            'per_page' => 'sometimes|integer|min:1|max:200',
        ]);

        $query = JournalEntry::with(['origin', 'destination', 'category'])
            ->where('user_id', $request->user()->id)
            ->orderByDesc('occurred_at');

        if (isset($filters['account_id'])) {
            $id = $filters['account_id'];
            $query->where(function ($q) use ($id) {
                $q->where('account_origin_id', $id)
                    ->orWhere('account_destination_id', $id);
            });
        }

        if (isset($filters['category_id'])) {
            $query->where('category_id', $filters['category_id']);
        }

        if (isset($filters['kind'])) {
            $query->where('kind', $filters['kind']);
        }

        if (isset($filters['from'])) {
            $query->where('occurred_at', '>=', $filters['from']);
        }

        if (isset($filters['to'])) {
            $query->where('occurred_at', '<=', $filters['to']);
        }

        $perPage = (int) ($filters['per_page'] ?? 25);

        return response()->json($query->paginate($perPage));
    }

    public function updateEntry(Request $request, string $id)
    {
        $data = $request->validate([
            'category_id' => 'sometimes|nullable|uuid|exists:categories,id',
            'description' => 'sometimes|nullable|string|max:200',
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
        ]);

        $category = CreateCategory::execute(
            $request->user()->id,
            $data['name'],
            $data['applies_to'],
            $data['color_slug'],
            $data['icon_slug'],
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
}
