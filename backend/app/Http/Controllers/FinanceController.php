<?php

namespace App\Http\Controllers;

use App\Domain\Finance\Actions\CreateAccount;
use App\Domain\Finance\Actions\DeleteAccount;
use App\Domain\Finance\Actions\PayCreditAccount;
use App\Domain\Finance\Actions\RegisterCreditExpense;
use App\Domain\Finance\Actions\RegisterExpense;
use App\Domain\Finance\Actions\RegisterIncome;
use App\Domain\Finance\Actions\RegisterTransfer;
use App\Domain\Finance\Actions\UpdateAccount;
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
        ]);
    }

    public function income(Request $request)
    {
        $data = $request->validate([
            'account_id' => 'required|uuid|exists:accounts,id',
            'amount' => 'required|numeric|min:0.01',
            'description' => 'nullable|string',
        ]);

        $entry = RegisterIncome::execute(
            $request->user()->id,
            $data['account_id'],
            (float) $data['amount'],
            $data['description'] ?? null,
        );

        return response()->json(['message' => 'Ingreso registrado', 'entry' => $entry], 201);
    }

    public function expense(Request $request)
    {
        $data = $request->validate([
            'account_id' => 'required|uuid|exists:accounts,id',
            'amount' => 'required|numeric|min:0.01',
            'description' => 'nullable|string',
        ]);

        $entry = RegisterExpense::execute(
            $request->user()->id,
            $data['account_id'],
            (float) $data['amount'],
            $data['description'] ?? null,
        );

        return response()->json(['message' => 'Gasto registrado', 'entry' => $entry], 201);
    }

    public function creditExpense(Request $request)
    {
        $data = $request->validate([
            'account_id' => 'required|uuid|exists:accounts,id',
            'amount' => 'required|numeric|min:0.01',
            'description' => 'nullable|string',
        ]);

        $entry = RegisterCreditExpense::execute(
            $request->user()->id,
            $data['account_id'],
            (float) $data['amount'],
            $data['description'] ?? null,
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
            'kind' => 'sometimes|in:income,expense,credit_expense,debt_payment,transfer,adjustment',
            'from' => 'sometimes|date',
            'to' => 'sometimes|date',
            'per_page' => 'sometimes|integer|min:1|max:200',
        ]);

        $query = JournalEntry::with(['origin', 'destination'])
            ->where('user_id', $request->user()->id)
            ->orderByDesc('occurred_at');

        if (isset($filters['account_id'])) {
            $id = $filters['account_id'];
            $query->where(function ($q) use ($id) {
                $q->where('account_origin_id', $id)
                    ->orWhere('account_destination_id', $id);
            });
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
}
