<?php

namespace Tests\Feature\Http;

use App\Domain\Finance\Actions\RegisterExpense;
use App\Domain\Finance\Actions\RegisterIncome;
use App\Domain\Finance\Reports\Export\ReportExporter;
use App\Models\Account;
use App\Models\Category;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class ReportExportTest extends TestCase
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

    private function makeCategory(string $appliesTo = 'expense', ?float $monthlyLimit = null): Category
    {
        return Category::create([
            'user_id' => $this->user->id,
            'name' => 'Cat-'.bin2hex(random_bytes(4)),
            'applies_to' => $appliesTo,
            'color_slug' => 'orange',
            'icon_slug' => 'shopping-bag',
            'monthly_limit' => $monthlyLimit,
        ]);
    }

    private function getBinary(string $url): string
    {
        $response = $this->get($url);
        $response->assertOk();

        return (string) $response->streamedContent();
    }

    private function assertXlsxHeaders($response, string $filenameContains): void
    {
        $response->assertOk();
        $response->assertHeader(
            'Content-Type',
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
        );
        $disposition = $response->headers->get('Content-Disposition');
        $this->assertNotNull($disposition);
        $this->assertStringContainsString('attachment', $disposition);
        $this->assertStringContainsString($filenameContains, $disposition);
    }

    /* ---------------- by-category ---------------- */

    public function test_by_category_returns_xlsx_with_correct_headers(): void
    {
        RegisterExpense::execute($this->user->id, $this->bolsa()->id, 100, 'gasto');

        $url = '/api/finance/reports/by-category/export.xlsx?kind=expense&from=2026-01-01&to=2026-12-31';
        $response = $this->get($url);

        $this->assertXlsxHeaders($response, 'fincore-por-categoria-2026-01-01_2026-12-31.xlsx');

        $bin = (string) $response->streamedContent();
        $this->assertSame("PK\x03\x04", substr($bin, 0, 4));
    }

    public function test_by_category_xlsx_matches_json_endpoint(): void
    {
        $cat = $this->makeCategory();
        RegisterExpense::execute($this->user->id, $this->bolsa()->id, 250.50, 'cena', $cat->id);
        RegisterExpense::execute($this->user->id, $this->bolsa()->id, 100, 'café'); // sin categoría

        $params = 'kind=expense&from=2020-01-01&to=2030-12-31';
        $json = $this->getJson('/api/finance/reports/by-category?'.$params)->json();
        $bin = $this->getBinary('/api/finance/reports/by-category/export.xlsx?'.$params);
        $sheet = ReportExporter::loadFromBinary($bin)->getActiveSheet();

        $totalCells = [];
        for ($row = 5; $row <= 50; $row++) {
            $name = $sheet->getCell('A'.$row)->getValue();
            if ($name === null || $name === 'TOTAL') {
                break;
            }
            $totalCells[$name] = (float) $sheet->getCell('C'.$row)->getValue();
        }

        foreach ($json['buckets'] as $b) {
            $this->assertArrayHasKey($b['name'], $totalCells);
            $this->assertEquals((float) $b['total'], $totalCells[$b['name']]);
        }
    }

    public function test_by_category_empty_returns_xlsx_with_zero_total(): void
    {
        $url = '/api/finance/reports/by-category/export.xlsx?kind=expense&from=2020-01-01&to=2020-12-31';
        $bin = $this->getBinary($url);
        $sheet = ReportExporter::loadFromBinary($bin)->getActiveSheet();

        // headers en fila 4, sin filas de data, footer TOTAL en fila 5.
        $this->assertSame('Categoría', $sheet->getCell('A4')->getValue());
        $this->assertSame('TOTAL', $sheet->getCell('A5')->getValue());
        $this->assertEquals(0, $sheet->getCell('C5')->getValue());
    }

    public function test_by_category_validates_query_params(): void
    {
        $this->getJson('/api/finance/reports/by-category/export.xlsx?kind=invalid&from=x&to=y')
            ->assertStatus(422);
    }

    /* ---------------- cashflow-monthly ---------------- */

    public function test_cashflow_monthly_returns_xlsx(): void
    {
        RegisterIncome::execute($this->user->id, $this->bolsa()->id, 1000);
        $url = '/api/finance/reports/cashflow-monthly/export.xlsx?from=2026-01-01&to=2026-12-31';
        $response = $this->get($url);
        $this->assertXlsxHeaders($response, 'fincore-cashflow-mensual-2026-01-01_2026-12-31.xlsx');
    }

    public function test_cashflow_monthly_xlsx_matches_json(): void
    {
        RegisterIncome::execute($this->user->id, $this->bolsa()->id, 1000);
        RegisterExpense::execute($this->user->id, $this->bolsa()->id, 300);

        $params = 'from=2020-01-01&to=2030-12-31';
        $json = $this->getJson('/api/finance/reports/cashflow-monthly?'.$params)->json();
        $bin = $this->getBinary('/api/finance/reports/cashflow-monthly/export.xlsx?'.$params);
        $sheet = ReportExporter::loadFromBinary($bin)->getActiveSheet();

        $cellsByMonth = [];
        for ($row = 5; $row <= 50; $row++) {
            $ym = $sheet->getCell('A'.$row)->getValue();
            if ($ym === null || $ym === 'TOTAL') {
                break;
            }
            $cellsByMonth[$ym] = [
                'income' => (float) $sheet->getCell('B'.$row)->getValue(),
                'expense' => (float) $sheet->getCell('C'.$row)->getValue(),
                'net' => (float) $sheet->getCell('D'.$row)->getValue(),
            ];
        }

        foreach ($json['months'] as $m) {
            $this->assertArrayHasKey($m['year_month'], $cellsByMonth);
            $this->assertEquals((float) $m['income'], $cellsByMonth[$m['year_month']]['income']);
            $this->assertEquals((float) $m['expense'], $cellsByMonth[$m['year_month']]['expense']);
            $this->assertEquals((float) $m['net'], $cellsByMonth[$m['year_month']]['net']);
        }
    }

    /* ---------------- month-comparison ---------------- */

    public function test_month_comparison_returns_xlsx_with_month_filename(): void
    {
        $url = '/api/finance/reports/month-comparison/export.xlsx?kind=expense&month=2026-06';
        $response = $this->get($url);
        $this->assertXlsxHeaders($response, 'fincore-comparativo-mes-2026-06.xlsx');
    }

    public function test_month_comparison_validates_month_format(): void
    {
        $this->getJson('/api/finance/reports/month-comparison/export.xlsx?kind=expense&month=2026-13')
            ->assertStatus(422);
    }

    /* ---------------- credit-cards ---------------- */

    public function test_credit_cards_returns_xlsx_without_range(): void
    {
        $card = Account::factory()->credit()->for($this->user)->create([
            'name' => 'Visa',
            'credit_limit' => 10000,
        ]);

        $response = $this->get('/api/finance/reports/credit-cards/export.xlsx');
        $this->assertXlsxHeaders($response, 'fincore-tarjetas-credito.xlsx');
    }

    public function test_credit_cards_no_footer_row(): void
    {
        Account::factory()->credit()->for($this->user)->create([
            'name' => 'Visa',
            'credit_limit' => 10000,
            'closing_day' => null,
            'payment_day' => null,
        ]);

        $bin = $this->getBinary('/api/finance/reports/credit-cards/export.xlsx');
        $sheet = ReportExporter::loadFromBinary($bin)->getActiveSheet();

        // header fila 4, una tarjeta fila 5; no debe haber "TOTAL" en A6.
        $this->assertSame('Visa', $sheet->getCell('A5')->getValue());
        $this->assertNotSame('TOTAL', $sheet->getCell('A6')->getValue());
    }

    public function test_credit_cards_empty_metadata_renders_blank_cells(): void
    {
        Account::factory()->credit()->for($this->user)->create([
            'name' => 'SinConfig',
            'credit_limit' => 5000,
            'closing_day' => null,
            'payment_day' => null,
            'minimum_payment_pct' => null,
        ]);

        $bin = $this->getBinary('/api/finance/reports/credit-cards/export.xlsx');
        $sheet = ReportExporter::loadFromBinary($bin)->getActiveSheet();

        // Día corte (col F=index 5) y Día pago (col G=6) deben ser ''/null, no 0.
        $closingDay = $sheet->getCell('F5')->getValue();
        $paymentDay = $sheet->getCell('G5')->getValue();
        $minimum = $sheet->getCell('H5')->getValue();
        $this->assertTrue($closingDay === '' || $closingDay === null);
        $this->assertTrue($paymentDay === '' || $paymentDay === null);
        $this->assertTrue($minimum === '' || $minimum === null);
    }

    /* ---------------- budgets ---------------- */

    public function test_budgets_returns_xlsx(): void
    {
        $this->makeCategory('expense', 1000.0);
        $response = $this->get('/api/finance/reports/budgets/export.xlsx');
        $this->assertXlsxHeaders($response, 'fincore-presupuestos.xlsx');
    }

    public function test_budgets_xlsx_includes_pct_format(): void
    {
        $cat = $this->makeCategory('expense', 1000.0);
        RegisterExpense::execute($this->user->id, $this->bolsa()->id, 250, 'gasto', $cat->id);

        $bin = $this->getBinary('/api/finance/reports/budgets/export.xlsx');
        $sheet = ReportExporter::loadFromBinary($bin)->getActiveSheet();

        // Columna E es "Consumido %"; debe tener formato porcentaje.
        $this->assertSame(
            ReportExporter::PCT_FORMAT_CODE,
            $sheet->getStyle('E5')->getNumberFormat()->getFormatCode()
        );
    }

    /* ---------------- by-account ---------------- */

    public function test_by_account_returns_xlsx(): void
    {
        $response = $this->get('/api/finance/reports/by-account/export.xlsx?from=2026-01-01&to=2026-12-31');
        $this->assertXlsxHeaders($response, 'fincore-por-cuenta-2026-01-01_2026-12-31.xlsx');
    }

    public function test_by_account_excludes_archived_accounts(): void
    {
        $banamex = Account::factory()->debit()->for($this->user)->create(['name' => 'Banamex']);
        $banamex->delete(); // archivar

        $bin = $this->getBinary('/api/finance/reports/by-account/export.xlsx?from=2020-01-01&to=2030-12-31');
        $sheet = ReportExporter::loadFromBinary($bin)->getActiveSheet();

        // Recorrer filas de data; Banamex no debe aparecer.
        for ($row = 5; $row <= 30; $row++) {
            $name = $sheet->getCell('A'.$row)->getValue();
            if ($name === null || $name === 'TOTAL') {
                break;
            }
            $this->assertNotSame('Banamex', $name);
        }
    }

    public function test_by_account_xlsx_matches_json(): void
    {
        Account::factory()->debit()->for($this->user)->create(['name' => 'Banamex']);
        RegisterIncome::execute($this->user->id, $this->bolsa()->id, 500);

        $params = 'from=2020-01-01&to=2030-12-31';
        $json = $this->getJson('/api/finance/reports/by-account?'.$params)->json();
        $bin = $this->getBinary('/api/finance/reports/by-account/export.xlsx?'.$params);
        $sheet = ReportExporter::loadFromBinary($bin)->getActiveSheet();

        $rows = [];
        for ($r = 5; $r <= 30; $r++) {
            $n = $sheet->getCell('A'.$r)->getValue();
            if ($n === null || $n === 'TOTAL') {
                break;
            }
            $rows[$n] = [
                'income' => (float) $sheet->getCell('C'.$r)->getValue(),
                'expense' => (float) $sheet->getCell('D'.$r)->getValue(),
                'net' => (float) $sheet->getCell('E'.$r)->getValue(),
            ];
        }

        foreach ($json['accounts'] as $a) {
            $this->assertArrayHasKey($a['name'], $rows);
            $this->assertEquals((float) $a['income'], $rows[$a['name']]['income']);
            $this->assertEquals((float) $a['expense'], $rows[$a['name']]['expense']);
            $this->assertEquals((float) $a['net'], $rows[$a['name']]['net']);
        }
    }

    /* ---------------- permisos y aislamiento ---------------- */

    public function test_unauthenticated_returns_401(): void
    {
        // re-instanciar un cliente sin auth.
        $this->app['auth']->forgetGuards();
        $this->refreshApplication();

        $response = $this->getJson('/api/finance/reports/by-category/export.xlsx?kind=expense&from=2026-01-01&to=2026-12-31');
        $this->assertContains($response->getStatusCode(), [401, 403]);
    }

    public function test_unverified_email_returns_403(): void
    {
        // UserFactory marca email_verified_at por default; usar el estado unverified.
        $u = User::factory()->unverified()->create();
        Account::factory()->cash()->for($u)->create();
        $this->actingAs($u, 'sanctum');

        $this->getJson('/api/finance/reports/by-category/export.xlsx?kind=expense&from=2026-01-01&to=2026-12-31')
            ->assertStatus(403);
    }

    public function test_user_a_cannot_see_user_b_data_in_by_category(): void
    {
        $userB = $this->createUserWithBolsa();
        $userB->markEmailAsVerified();
        $bolsaB = $userB->accounts()->where('type', Account::TYPE_CASH)->firstOrFail();
        RegisterExpense::execute($userB->id, $bolsaB->id, 9999, 'gasto de B');

        // Sigo autenticado como user A (this->user).
        $bin = $this->getBinary('/api/finance/reports/by-category/export.xlsx?kind=expense&from=2020-01-01&to=2030-12-31');
        $sheet = ReportExporter::loadFromBinary($bin)->getActiveSheet();

        for ($row = 5; $row <= 30; $row++) {
            $total = $sheet->getCell('C'.$row)->getValue();
            $name = $sheet->getCell('A'.$row)->getValue();
            if ($name === null || $name === 'TOTAL') {
                if ($name === 'TOTAL') {
                    $this->assertEquals(0, (float) $total);
                }
                break;
            }
            $this->assertNotEquals(9999, (float) $total);
        }
    }

    public function test_user_a_cannot_use_account_id_from_user_b(): void
    {
        $userB = $this->createUserWithBolsa();
        $bolsaB = $userB->accounts()->where('type', Account::TYPE_CASH)->firstOrFail();

        $this->getJson('/api/finance/reports/by-category/export.xlsx?kind=expense&from=2026-01-01&to=2026-12-31&account_id='.$bolsaB->id)
            ->assertStatus(422);
    }

    /* ---------------- soft delete histórico ---------------- */

    public function test_archived_category_keeps_historical_name_in_by_category(): void
    {
        $cat = $this->makeCategory();
        $catName = $cat->name;
        RegisterExpense::execute($this->user->id, $this->bolsa()->id, 100, 'gasto', $cat->id);
        $cat->delete();

        $bin = $this->getBinary('/api/finance/reports/by-category/export.xlsx?kind=expense&from=2020-01-01&to=2030-12-31');
        $sheet = ReportExporter::loadFromBinary($bin)->getActiveSheet();

        $found = false;
        for ($row = 5; $row <= 30; $row++) {
            $name = $sheet->getCell('A'.$row)->getValue();
            if ($name === null || $name === 'TOTAL') {
                break;
            }
            if ($name === $catName) {
                $found = true;
                break;
            }
        }
        $this->assertTrue($found, 'La categoría archivada debe conservar su nombre histórico en el xlsx');
    }

    public function test_cancelled_entries_are_excluded(): void
    {
        $entry = RegisterExpense::execute($this->user->id, $this->bolsa()->id, 100, 'gasto');
        $entry->delete(); // soft delete

        $bin = $this->getBinary('/api/finance/reports/by-category/export.xlsx?kind=expense&from=2020-01-01&to=2030-12-31');
        $sheet = ReportExporter::loadFromBinary($bin)->getActiveSheet();

        // El TOTAL debe ser 0 porque el único entry fue cancelado.
        for ($row = 5; $row <= 10; $row++) {
            if ($sheet->getCell('A'.$row)->getValue() === 'TOTAL') {
                $this->assertEquals(0, (float) $sheet->getCell('C'.$row)->getValue());

                return;
            }
        }
        $this->fail('No se encontró fila TOTAL');
    }
}
