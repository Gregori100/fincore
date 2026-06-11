<?php

namespace Tests\Feature\Http;

use App\Domain\Finance\Actions\RegisterExpense;
use App\Domain\Finance\Reports\Export\ReportExporter;
use App\Models\Account;
use App\Models\Category;
use App\Models\User;
use Carbon\Carbon;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class ForecastReportTest extends TestCase
{
    use RefreshDatabase;

    private const REF_TODAY = '2026-06-10 12:00:00';

    private User $user;

    protected function setUp(): void
    {
        parent::setUp();
        Carbon::setTestNow(self::REF_TODAY);
        $this->user = $this->createUserWithBolsa();
        $this->user->markEmailAsVerified();
        $this->actingAs($this->user, 'sanctum');
    }

    protected function tearDown(): void
    {
        Carbon::setTestNow();
        parent::tearDown();
    }

    private function bolsa(): Account
    {
        return $this->user->accounts()->where('type', Account::TYPE_CASH)->firstOrFail();
    }

    private function makeCategory(string $name = 'Comida'): Category
    {
        return Category::create([
            'user_id' => $this->user->id,
            'name' => $name,
            'applies_to' => 'expense',
            'color_slug' => 'orange',
            'icon_slug' => 'shopping-bag',
        ]);
    }

    private function expenseOn(string $date, float $amount, ?string $categoryId = null): void
    {
        $entry = RegisterExpense::execute($this->user->id, $this->bolsa()->id, $amount, 'gasto', $categoryId);
        $entry->occurred_at = $date.' 12:00:00';
        $entry->save();
    }

    /* ---------- JSON endpoint ---------- */

    public function test_endpoint_returns_200_with_full_shape(): void
    {
        $cat = $this->makeCategory();
        $this->expenseOn('2026-04-15', 6000, $cat->id);
        $this->expenseOn('2026-06-05', 2500, $cat->id);

        $response = $this->getJson('/api/finance/reports/forecast')
            ->assertOk();

        $payload = $response->json();
        $this->assertSame('2026-06', $payload['month']);
        $this->assertSame('2026-06-10', $payload['today']);
        $this->assertSame(30, $payload['days_in_month']);
        $this->assertSame(10, $payload['days_elapsed']);
        $this->assertSame('2026-03-01', $payload['window_from']);
        $this->assertSame('2026-05-31', $payload['window_to']);
        $this->assertCount(1, $payload['categories']);
        $this->assertSame('Comida', $payload['categories'][0]['name']);
        $this->assertEquals(2500, $payload['categories'][0]['current_spent']);
        $this->assertEquals(2000, $payload['categories'][0]['historical_average']);
        $this->assertEquals(7500, $payload['categories'][0]['projection']);
        $this->assertEquals(275.0, $payload['categories'][0]['delta_pct']);
        $this->assertArrayHasKey('totals', $payload);
    }

    public function test_endpoint_unauthenticated_returns_401(): void
    {
        $this->app['auth']->forgetGuards();
        $this->refreshApplication();

        $response = $this->getJson('/api/finance/reports/forecast');
        $this->assertContains($response->getStatusCode(), [401, 403]);
    }

    public function test_endpoint_unverified_email_returns_403(): void
    {
        $u = User::factory()->unverified()->create();
        Account::factory()->cash()->for($u)->create();
        $this->actingAs($u, 'sanctum');

        $this->getJson('/api/finance/reports/forecast')->assertStatus(403);
    }

    public function test_endpoint_ignores_extra_query_params(): void
    {
        $cat = $this->makeCategory();
        $this->expenseOn('2026-04-15', 3000, $cat->id);

        $a = $this->getJson('/api/finance/reports/forecast')->assertOk()->json();
        $b = $this->getJson('/api/finance/reports/forecast?foo=bar&baz=qux')->assertOk()->json();

        $this->assertSame($a, $b);
    }

    public function test_endpoint_empty_user_returns_empty_categories_and_zero_totals(): void
    {
        $payload = $this->getJson('/api/finance/reports/forecast')->assertOk()->json();

        $this->assertSame([], $payload['categories']);
        $this->assertEquals(0, $payload['totals']['current_spent']);
        $this->assertEquals(0, $payload['totals']['historical_average']);
        $this->assertEquals(0, $payload['totals']['projection']);
        $this->assertNull($payload['totals']['delta_pct']);
    }

    public function test_endpoint_user_a_does_not_see_user_b_data(): void
    {
        $other = $this->createUserWithBolsa();
        $other->markEmailAsVerified();
        $otherBolsa = $other->accounts()->where('type', Account::TYPE_CASH)->firstOrFail();
        $otherCat = Category::create([
            'user_id' => $other->id, 'name' => 'OtherCat', 'applies_to' => 'expense',
            'color_slug' => 'blue', 'icon_slug' => 'cake',
        ]);
        $otherEntry = RegisterExpense::execute($other->id, $otherBolsa->id, 9999, 'gasto B', $otherCat->id);
        $otherEntry->occurred_at = '2026-04-15 12:00:00';
        $otherEntry->save();

        // Sigo autenticado como $this->user.
        $payload = $this->getJson('/api/finance/reports/forecast')->assertOk()->json();
        $this->assertSame([], $payload['categories']);
    }

    /* ---------- XLSX export ---------- */

    public function test_export_xlsx_returns_correct_headers(): void
    {
        $cat = $this->makeCategory();
        $this->expenseOn('2026-04-15', 6000, $cat->id);

        $response = $this->get('/api/finance/reports/forecast/export.xlsx')->assertOk();

        $response->assertHeader(
            'Content-Type',
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
        );
        $disposition = (string) $response->headers->get('Content-Disposition');
        $this->assertStringContainsString('attachment', $disposition);
        $this->assertStringContainsString('fincore-proyeccion-gasto-2026-06.xlsx', $disposition);
    }

    public function test_export_xlsx_content_matches_json(): void
    {
        $cat = $this->makeCategory();
        $this->expenseOn('2026-04-15', 6000, $cat->id);
        $this->expenseOn('2026-06-05', 2500, $cat->id);

        $json = $this->getJson('/api/finance/reports/forecast')->assertOk()->json();
        $response = $this->get('/api/finance/reports/forecast/export.xlsx')->assertOk();
        $bin = (string) $response->streamedContent();
        $this->assertSame("PK\x03\x04", substr($bin, 0, 4));

        $sheet = ReportExporter::loadFromBinary($bin)->getActiveSheet();

        // Header tabla en fila 4; data en fila 5.
        $this->assertSame('Categoría', $sheet->getCell('A4')->getValue());
        $this->assertSame('Comida', $sheet->getCell('A5')->getValue());
        $this->assertEquals((float) $json['categories'][0]['current_spent'], (float) $sheet->getCell('B5')->getValue());
        $this->assertEquals((float) $json['categories'][0]['historical_average'], (float) $sheet->getCell('C5')->getValue());
        $this->assertEquals((float) $json['categories'][0]['projection'], (float) $sheet->getCell('D5')->getValue());

        // Footer TOTAL en fila 6.
        $this->assertSame('TOTAL', $sheet->getCell('A6')->getValue());
    }

    public function test_export_xlsx_with_empty_categories_still_renders(): void
    {
        $response = $this->get('/api/finance/reports/forecast/export.xlsx')->assertOk();
        $bin = (string) $response->streamedContent();
        $sheet = ReportExporter::loadFromBinary($bin)->getActiveSheet();

        // Header en fila 4; sin data rows; footer TOTAL en fila 5.
        $this->assertSame('Categoría', $sheet->getCell('A4')->getValue());
        $this->assertSame('TOTAL', $sheet->getCell('A5')->getValue());
        $this->assertEquals(0, $sheet->getCell('B5')->getValue());
    }

    public function test_export_xlsx_unauthenticated_returns_401(): void
    {
        $this->app['auth']->forgetGuards();
        $this->refreshApplication();

        $response = $this->getJson('/api/finance/reports/forecast/export.xlsx');
        $this->assertContains($response->getStatusCode(), [401, 403]);
    }
}
