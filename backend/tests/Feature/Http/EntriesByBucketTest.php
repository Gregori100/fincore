<?php

namespace Tests\Feature\Http;

use App\Domain\Finance\Actions\RegisterCreditExpense;
use App\Domain\Finance\Actions\RegisterExpense;
use App\Domain\Finance\Actions\RegisterIncome;
use App\Models\Account;
use App\Models\Category;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class EntriesByBucketTest extends TestCase
{
    use RefreshDatabase;

    private User $user;

    protected function setUp(): void
    {
        parent::setUp();
        $this->user = $this->createUserWithBolsa();
        $this->user->markEmailAsVerified();
        $this->actingAs($this->user, 'sanctum');
    }

    private function bolsa(): Account
    {
        return $this->user->accounts()->where('type', Account::TYPE_CASH)->firstOrFail();
    }

    public function test_returns_entries_for_account_and_kind(): void
    {
        $bolsa = $this->bolsa();
        RegisterIncome::execute($this->user->id, $bolsa->id, 1000);
        RegisterExpense::execute($this->user->id, $bolsa->id, 300);

        $this->getJson("/api/finance/reports/entries-by-bucket?account_id={$bolsa->id}&kind=expense")
            ->assertOk()
            ->assertJsonPath('total_count', 1)
            ->assertJsonPath('truncated', false)
            ->assertJsonCount(1, 'entries');
    }

    public function test_year_month_translates_to_from_to(): void
    {
        $bolsa = $this->bolsa();
        $e = RegisterIncome::execute($this->user->id, $bolsa->id, 1000);
        $e->occurred_at = now()->subMonth()->startOfMonth()->addDays(5);
        $e->save();

        $ym = now()->subMonth()->format('Y-m');
        $this->getJson("/api/finance/reports/entries-by-bucket?year_month={$ym}&kind=income")
            ->assertOk()
            ->assertJsonCount(1, 'entries');
    }

    public function test_year_month_overrides_from_to_if_both(): void
    {
        $bolsa = $this->bolsa();
        $e = RegisterIncome::execute($this->user->id, $bolsa->id, 500);
        $e->occurred_at = now()->subMonth()->startOfMonth()->addDay();
        $e->save();

        // from/to apuntan a hace 3 meses, year_month al mes pasado (donde está el entry).
        $ym = now()->subMonth()->format('Y-m');
        $from = now()->subMonths(3)->startOfMonth()->toDateString();
        $to = now()->subMonths(3)->endOfMonth()->toDateString();

        $this->getJson("/api/finance/reports/entries-by-bucket?from={$from}&to={$to}&year_month={$ym}&kind=income")
            ->assertOk()
            ->assertJsonCount(1, 'entries');
    }

    public function test_caps_at_100_with_truncated_flag(): void
    {
        $bolsa = $this->bolsa();
        for ($i = 0; $i < 105; $i++) {
            RegisterIncome::execute($this->user->id, $bolsa->id, 10);
        }

        $this->getJson("/api/finance/reports/entries-by-bucket?account_id={$bolsa->id}&kind=income")
            ->assertOk()
            ->assertJsonPath('total_count', 105)
            ->assertJsonPath('truncated', true)
            ->assertJsonCount(100, 'entries');
    }

    public function test_exactly_100_is_not_truncated(): void
    {
        $bolsa = $this->bolsa();
        for ($i = 0; $i < 100; $i++) {
            RegisterIncome::execute($this->user->id, $bolsa->id, 10);
        }

        $this->getJson("/api/finance/reports/entries-by-bucket?account_id={$bolsa->id}&kind=income")
            ->assertOk()
            ->assertJsonPath('total_count', 100)
            ->assertJsonPath('truncated', false);
    }

    public function test_zero_entries_returns_empty_array(): void
    {
        $bolsa = $this->bolsa();
        $this->getJson("/api/finance/reports/entries-by-bucket?account_id={$bolsa->id}&kind=expense")
            ->assertOk()
            ->assertJsonPath('total_count', 0)
            ->assertJsonPath('entries', []);
    }

    public function test_rejects_when_all_filters_empty(): void
    {
        $this->getJson('/api/finance/reports/entries-by-bucket')
            ->assertStatus(422)
            ->assertJsonPath('code', 'missing_filters');
    }

    public function test_rejects_malformed_year_month(): void
    {
        $this->getJson('/api/finance/reports/entries-by-bucket?year_month=2026-13')
            ->assertStatus(422);
    }

    public function test_scope_isolation(): void
    {
        $bolsa = $this->bolsa();
        $other = $this->createUserWithBolsa();
        $otherBolsa = $other->accounts()->where('type', Account::TYPE_CASH)->firstOrFail();
        RegisterIncome::execute($other->id, $otherBolsa->id, 7777);

        // El user actual no debería ver el entry del otro.
        $this->getJson("/api/finance/reports/entries-by-bucket?account_id={$bolsa->id}&kind=income")
            ->assertOk()
            ->assertJsonCount(0, 'entries');
    }

    public function test_eager_loads_relations_no_n_plus_1(): void
    {
        $bolsa = $this->bolsa();
        for ($i = 0; $i < 20; $i++) {
            RegisterIncome::execute($this->user->id, $bolsa->id, 100);
        }

        DB::enableQueryLog();
        $this->getJson("/api/finance/reports/entries-by-bucket?account_id={$bolsa->id}&kind=income")->assertOk();
        $count = count(DB::getQueryLog());
        DB::disableQueryLog();

        // Esperamos: count + entries select + eager loads (origin, destination, category) = ~5.
        // Sin eager loading, 20 entries × 3 relaciones ≈ 60+ queries.
        $this->assertLessThan(10, $count, "Posible N+1: {$count} queries");
    }

    public function test_includes_archived_account_entries_when_filtered_by_archived_account_id(): void
    {
        $bolsa = $this->bolsa();
        $banamex = Account::factory()->debit()->for($this->user)->create();
        RegisterIncome::execute($this->user->id, $banamex->id, 1234);
        $banamex->delete(); // archivar

        // Drill-down con su id debería seguir devolviendo el histórico.
        $this->getJson("/api/finance/reports/entries-by-bucket?account_id={$banamex->id}&kind=income")
            ->assertOk()
            ->assertJsonPath('total_count', 1);
    }

    private function makeCategory(string $appliesTo = 'expense'): Category
    {
        return Category::create([
            'user_id' => $this->user->id,
            'name' => 'Cat-'.bin2hex(random_bytes(4)),
            'applies_to' => $appliesTo,
            'color_slug' => 'orange',
            'icon_slug' => 'shopping-bag',
        ]);
    }

    public function test_kind_transfer_with_category_id_returns_empty(): void
    {
        // Los transfers no se categorizan; combinarlos con category_id debe
        // devolver vacío, sin error.
        $bolsa = $this->bolsa();
        $banamex = Account::factory()->debit()->for($this->user)->create();
        \App\Domain\Finance\Actions\RegisterTransfer::execute($this->user->id, $bolsa->id, $banamex->id, 500);
        $cat = $this->makeCategory();

        $this->getJson("/api/finance/reports/entries-by-bucket?kind=transfer&category_id={$cat->id}")
            ->assertOk()
            ->assertJsonPath('total_count', 0)
            ->assertJsonPath('entries', []);
    }

    public function test_combines_account_id_and_category_id_with_and(): void
    {
        // Dos entries: uno matchea ambos filtros, el otro solo uno.
        $bolsa = $this->bolsa();
        $cat = $this->makeCategory();
        RegisterExpense::execute($this->user->id, $bolsa->id, 100, 'matches', $cat->id);
        RegisterExpense::execute($this->user->id, $bolsa->id, 200, 'no category');

        $resp = $this->getJson("/api/finance/reports/entries-by-bucket?account_id={$bolsa->id}&category_id={$cat->id}")
            ->assertOk()
            ->assertJsonPath('total_count', 1);
        $this->assertSame('matches', $resp->json('entries.0.description'));
    }

    public function test_bucket_label_is_descriptive(): void
    {
        $bolsa = $this->bolsa();
        RegisterIncome::execute($this->user->id, $bolsa->id, 100);

        $resp = $this->getJson("/api/finance/reports/entries-by-bucket?account_id={$bolsa->id}&kind=income")
            ->assertOk();
        $label = $resp->json('bucket_label');
        $this->assertStringContainsString('Ingresos', $label);
        $this->assertStringContainsString('Bolsa', $label);
    }

    /* ---------------- Fixes entries-by-bucket-fixes ---------------- */

    public function test_category_id_null_filters_uncategorized_entries(): void
    {
        $bolsa = $this->bolsa();
        $cat = $this->makeCategory();
        // 1 con categoría, 1 sin categoría.
        RegisterExpense::execute($this->user->id, $bolsa->id, 100, 'con cat', $cat->id);
        RegisterExpense::execute($this->user->id, $bolsa->id, 200, 'sin cat');

        $resp = $this->getJson('/api/finance/reports/entries-by-bucket?category_id=&kind=expense')
            ->assertOk()
            ->assertJsonPath('total_count', 1);
        $this->assertSame('sin cat', $resp->json('entries.0.description'));
    }

    public function test_kind_expense_includes_credit_expense(): void
    {
        $bolsa = $this->bolsa();
        $credit = Account::factory()->credit()->for($this->user)->create(['credit_limit' => 10000]);
        RegisterExpense::execute($this->user->id, $bolsa->id, 100, 'gasto');
        RegisterCreditExpense::execute($this->user->id, $credit->id, 200, 'cargo');

        $this->getJson("/api/finance/reports/entries-by-bucket?account_id={$bolsa->id}&kind=expense")
            ->assertOk()
            // El account_id=bolsa solo encaja con el expense (el credit_expense salió de la tarjeta).
            ->assertJsonPath('total_count', 1);

        $this->getJson('/api/finance/reports/entries-by-bucket?kind=expense&from=2020-01-01&to=2030-12-31')
            ->assertOk()
            // Sin account_id, kind=expense trae los 2 (expense + credit_expense).
            ->assertJsonPath('total_count', 2);
    }

    public function test_kind_credit_expense_literal_does_not_mix_with_expense(): void
    {
        $bolsa = $this->bolsa();
        $credit = Account::factory()->credit()->for($this->user)->create(['credit_limit' => 10000]);
        RegisterExpense::execute($this->user->id, $bolsa->id, 100, 'gasto');
        RegisterCreditExpense::execute($this->user->id, $credit->id, 200, 'cargo');

        $resp = $this->getJson('/api/finance/reports/entries-by-bucket?kind=credit_expense&from=2020-01-01&to=2030-12-31')
            ->assertOk()
            ->assertJsonPath('total_count', 1);
        $this->assertSame('cargo', $resp->json('entries.0.description'));
    }

    public function test_kind_income_literal(): void
    {
        $bolsa = $this->bolsa();
        RegisterIncome::execute($this->user->id, $bolsa->id, 100, 'ingreso');
        RegisterExpense::execute($this->user->id, $bolsa->id, 50, 'gasto');

        $resp = $this->getJson('/api/finance/reports/entries-by-bucket?kind=income&from=2020-01-01&to=2030-12-31')
            ->assertOk()
            ->assertJsonPath('total_count', 1);
        $this->assertSame('ingreso', $resp->json('entries.0.description'));
    }

    public function test_kind_transfer_literal(): void
    {
        $bolsa = $this->bolsa();
        $banamex = Account::factory()->debit()->for($this->user)->create(['name' => 'Banamex']);
        \App\Domain\Finance\Actions\RegisterTransfer::execute($this->user->id, $bolsa->id, $banamex->id, 50);
        RegisterExpense::execute($this->user->id, $bolsa->id, 100, 'gasto');

        $resp = $this->getJson('/api/finance/reports/entries-by-bucket?kind=transfer&from=2020-01-01&to=2030-12-31')
            ->assertOk()
            ->assertJsonPath('total_count', 1);
    }

    public function test_category_id_null_combined_with_kind_expense_includes_credit_expense_sin_categoria(): void
    {
        $bolsa = $this->bolsa();
        $credit = Account::factory()->credit()->for($this->user)->create(['credit_limit' => 10000]);
        $cat = $this->makeCategory();
        // 1 expense con cat (no debe contar), 1 expense sin cat (sí cuenta),
        // 1 credit_expense sin cat (también cuenta porque kind=expense engloba).
        RegisterExpense::execute($this->user->id, $bolsa->id, 100, 'con cat', $cat->id);
        RegisterExpense::execute($this->user->id, $bolsa->id, 200, 'expense sin cat');
        RegisterCreditExpense::execute($this->user->id, $credit->id, 300, 'credit_expense sin cat');

        $this->getJson('/api/finance/reports/entries-by-bucket?category_id=&kind=expense&from=2020-01-01&to=2030-12-31')
            ->assertOk()
            ->assertJsonPath('total_count', 2);
    }

    public function test_bucket_label_includes_sin_categorizar_when_category_id_is_null(): void
    {
        $bolsa = $this->bolsa();
        RegisterExpense::execute($this->user->id, $bolsa->id, 100, 'sin cat');

        $resp = $this->getJson('/api/finance/reports/entries-by-bucket?category_id=&kind=expense')
            ->assertOk();
        $label = $resp->json('bucket_label');
        $this->assertStringContainsString('Gastos', $label);
        $this->assertStringContainsString('sin categorizar', $label);
    }

    public function test_bucket_label_with_category_id_uuid_unchanged(): void
    {
        $bolsa = $this->bolsa();
        $cat = $this->makeCategory();
        RegisterExpense::execute($this->user->id, $bolsa->id, 100, 'gasto', $cat->id);

        $resp = $this->getJson("/api/finance/reports/entries-by-bucket?category_id={$cat->id}&kind=expense")
            ->assertOk();
        $label = $resp->json('bucket_label');
        $this->assertStringContainsString('Gastos', $label);
        $this->assertStringContainsString('de '.$cat->name, $label);
    }
}
