<?php

namespace App\Http\Controllers;

use App\Domain\Finance\Reports\BudgetsReport;
use App\Domain\Finance\Reports\ByAccountReport;
use App\Domain\Finance\Reports\CashflowMonthlyReport;
use App\Domain\Finance\Reports\CategoryBreakdownReport;
use App\Domain\Finance\Reports\CreditCardsReport;
use App\Domain\Finance\Reports\Export\ReportExporter;
use App\Domain\Finance\Reports\MonthlyComparisonReport;
use App\Domain\Finance\Reports\SpendingForecastReport;
use App\Models\Account;
use Illuminate\Http\Request;

/**
 * 6 endpoints xlsx, uno por reporte. Cada acción valida los mismos params que
 * su contraparte JSON en FinanceController, invoca el Report Service y delega
 * en ReportExporter para construir el binario.
 *
 * Las acciones nunca duplican lógica de agregación: el Service es la fuente
 * de verdad. Aquí sólo se traducen los datos a tabla.
 */
class ReportExportController extends Controller
{
    private const ACCOUNT_TYPE_LABELS = [
        Account::TYPE_CASH => 'Efectivo',
        Account::TYPE_DEBIT => 'Débito',
        Account::TYPE_CREDIT => 'Crédito',
    ];

    public function byCategory(Request $request)
    {
        $userId = $request->user()->id;
        $data = $request->validate([
            'kind' => 'required|in:income,expense',
            'from' => 'required|date',
            'to' => 'required|date|after_or_equal:from',
            'account_id' => ['sometimes', 'nullable', 'uuid', 'exists:accounts,id,user_id,'.$userId],
        ]);

        $report = (new CategoryBreakdownReport($userId))->generate(
            $data['kind'],
            $data['account_id'] ?? null,
            $data['from'],
            $data['to'],
        );

        $kindLabel = $data['kind'] === 'income' ? 'Ingresos' : 'Gastos';
        $rangeLabel = "Rango: {$data['from']} a {$data['to']} · {$kindLabel}";

        $rows = array_map(
            fn (array $b) => [$b['name'], (int) $b['count'], (float) $b['total']],
            $report['buckets']
        );

        $exporter = (new ReportExporter)
            ->sheetTitle('Por categoría')
            ->header('Por categoría', $rangeLabel)
            ->table(
                ['Categoría', 'Movimientos', 'Total'],
                $rows,
                [ReportExporter::FORMAT_TEXT, ReportExporter::FORMAT_INT, ReportExporter::FORMAT_MONEY]
            )
            ->footer(['TOTAL', (int) $report['count'], (float) $report['total']]);

        $filename = sprintf('fincore-por-categoria-%s_%s.xlsx', $data['from'], $data['to']);

        return $exporter->download($filename);
    }

    public function cashflowMonthly(Request $request)
    {
        $userId = $request->user()->id;
        $data = $request->validate([
            'from' => 'required|date',
            'to' => 'required|date|after_or_equal:from',
            'account_id' => ['sometimes', 'nullable', 'uuid', 'exists:accounts,id,user_id,'.$userId],
        ]);

        $report = (new CashflowMonthlyReport($userId))->generate(
            $data['from'],
            $data['to'],
            $data['account_id'] ?? null,
        );

        $rangeLabel = "Rango: {$data['from']} a {$data['to']}";

        $rows = array_map(
            fn (array $m) => [$m['year_month'], (float) $m['income'], (float) $m['expense'], (float) $m['net']],
            $report['months']
        );

        $exporter = (new ReportExporter)
            ->sheetTitle('Cashflow mensual')
            ->header('Cashflow mensual', $rangeLabel)
            ->table(
                ['Año-Mes', 'Ingresos', 'Gastos', 'Neto'],
                $rows,
                [
                    ReportExporter::FORMAT_TEXT,
                    ReportExporter::FORMAT_MONEY,
                    ReportExporter::FORMAT_MONEY,
                    ReportExporter::FORMAT_MONEY,
                ]
            )
            ->footer([
                'TOTAL',
                (float) $report['total_income'],
                (float) $report['total_expense'],
                (float) $report['total_net'],
            ]);

        $filename = sprintf('fincore-cashflow-mensual-%s_%s.xlsx', $data['from'], $data['to']);

        return $exporter->download($filename);
    }

    public function monthComparison(Request $request)
    {
        $userId = $request->user()->id;
        $data = $request->validate([
            'kind' => 'required|in:income,expense',
            'month' => ['required', 'regex:/^\d{4}-(0[1-9]|1[0-2])$/'],
            'account_id' => ['sometimes', 'nullable', 'uuid', 'exists:accounts,id,user_id,'.$userId],
        ]);

        $report = (new MonthlyComparisonReport($userId))->generate(
            $data['kind'],
            $data['account_id'] ?? null,
            $data['month'],
        );

        $kindLabel = $data['kind'] === 'income' ? 'Ingresos' : 'Gastos';
        $rangeLabel = "Mes: {$report['current_month']} vs {$report['previous_month']} · {$kindLabel}";

        // delta_pct viene en porcentaje 0-100; convertir a fracción para que el
        // formato 0.0% de Excel lo pinte como X.X% sin doble multiplicación.
        $rows = array_map(
            fn (array $b) => [
                $b['name'],
                (float) $b['previous'],
                (float) $b['current'],
                (float) $b['delta'],
                $b['delta_pct'] === null ? '' : ((float) $b['delta_pct']) / 100,
            ],
            $report['buckets']
        );

        $totalDeltaPct = $report['delta_pct'] === null ? '' : ((float) $report['delta_pct']) / 100;

        $exporter = (new ReportExporter)
            ->sheetTitle('Comparativo mes vs mes')
            ->header('Comparativo mes vs mes', $rangeLabel)
            ->table(
                ['Categoría', 'Mes anterior', 'Mes actual', 'Δ', 'Δ %'],
                $rows,
                [
                    ReportExporter::FORMAT_TEXT,
                    ReportExporter::FORMAT_MONEY,
                    ReportExporter::FORMAT_MONEY,
                    ReportExporter::FORMAT_MONEY,
                    ReportExporter::FORMAT_PCT,
                ]
            )
            ->footer([
                'TOTAL',
                (float) $report['previous_total'],
                (float) $report['current_total'],
                (float) $report['delta'],
                $totalDeltaPct,
            ]);

        $filename = sprintf('fincore-comparativo-mes-%s.xlsx', $data['month']);

        return $exporter->download($filename);
    }

    public function creditCards(Request $request)
    {
        $report = (new CreditCardsReport($request->user()->id))->generate();

        $rows = array_map(
            fn (array $c) => [
                $c['name'],
                (float) $c['balance'],
                (float) $c['credit_limit'],
                (float) $c['available'],
                ((float) $c['utilization_pct']) / 100, // 0-100 → fracción para fmt 0.0%
                $c['closing_day'] !== null ? (int) $c['closing_day'] : '',
                $c['payment_day'] !== null ? (int) $c['payment_day'] : '',
                $c['minimum_payment_estimated'] !== null ? (float) $c['minimum_payment_estimated'] : '',
            ],
            $report['cards']
        );

        $exporter = (new ReportExporter)
            ->sheetTitle('Tarjetas de crédito')
            ->header('Tarjetas de crédito', 'Estado actual')
            ->table(
                [
                    'Tarjeta',
                    'Deuda',
                    'Límite',
                    'Disponible',
                    'Utilización %',
                    'Día corte',
                    'Día pago',
                    'Pago mín. estimado',
                ],
                $rows,
                [
                    ReportExporter::FORMAT_TEXT,
                    ReportExporter::FORMAT_MONEY,
                    ReportExporter::FORMAT_MONEY,
                    ReportExporter::FORMAT_MONEY,
                    ReportExporter::FORMAT_PCT,
                    ReportExporter::FORMAT_INT,
                    ReportExporter::FORMAT_INT,
                    ReportExporter::FORMAT_MONEY,
                ]
            )
            ->footer([]); // tarjetas no llevan footer

        return $exporter->download('fincore-tarjetas-credito.xlsx');
    }

    public function budgets(Request $request)
    {
        $report = (new BudgetsReport($request->user()->id))->generate();

        $rows = array_map(
            fn (array $b) => [
                $b['name'],
                (float) $b['monthly_limit'],
                (float) $b['spent'],
                (float) $b['remaining'],
                ((float) $b['pct_consumed']) / 100,
            ],
            $report['buckets']
        );

        $totalPct = $report['total_pct'] === null ? '' : ((float) $report['total_pct']) / 100;

        $exporter = (new ReportExporter)
            ->sheetTitle('Presupuestos')
            ->header('Presupuestos', 'Mes en curso: '.$report['month'])
            ->table(
                ['Categoría', 'Límite mensual', 'Gastado', 'Restante', 'Consumido %'],
                $rows,
                [
                    ReportExporter::FORMAT_TEXT,
                    ReportExporter::FORMAT_MONEY,
                    ReportExporter::FORMAT_MONEY,
                    ReportExporter::FORMAT_MONEY,
                    ReportExporter::FORMAT_PCT,
                ]
            )
            ->footer([
                'TOTAL',
                (float) $report['total_limit'],
                (float) $report['total_spent'],
                (float) ($report['total_limit'] - $report['total_spent']),
                $totalPct,
            ]);

        return $exporter->download('fincore-presupuestos.xlsx');
    }

    public function byAccount(Request $request)
    {
        $data = $request->validate([
            'from' => 'sometimes|date',
            'to' => 'sometimes|date|after_or_equal:from',
        ]);

        $from = $data['from'] ?? now()->startOfMonth()->toDateString();
        $to = $data['to'] ?? now()->toDateString();

        $report = (new ByAccountReport($request->user()->id))->generate($from, $to);

        $rows = array_map(
            fn (array $a) => [
                $a['name'],
                self::ACCOUNT_TYPE_LABELS[$a['type']] ?? $a['type'],
                (float) $a['income'],
                (float) $a['expense'],
                (float) $a['net'],
            ],
            $report['accounts']
        );

        $totalIncome = array_sum(array_column($report['accounts'], 'income'));
        $totalExpense = array_sum(array_column($report['accounts'], 'expense'));
        $totalNet = $totalIncome - $totalExpense;

        $exporter = (new ReportExporter)
            ->sheetTitle('Por cuenta')
            ->header('Por cuenta', "Rango: {$from} a {$to}")
            ->table(
                ['Cuenta', 'Tipo', 'Ingresos', 'Gastos', 'Neto'],
                $rows,
                [
                    ReportExporter::FORMAT_TEXT,
                    ReportExporter::FORMAT_TEXT,
                    ReportExporter::FORMAT_MONEY,
                    ReportExporter::FORMAT_MONEY,
                    ReportExporter::FORMAT_MONEY,
                ]
            )
            ->footer([
                'TOTAL',
                '',
                (float) $totalIncome,
                (float) $totalExpense,
                (float) $totalNet,
            ]);

        $filename = sprintf('fincore-por-cuenta-%s_%s.xlsx', $from, $to);

        return $exporter->download($filename);
    }

    public function forecast(Request $request)
    {
        $report = (new SpendingForecastReport($request->user()->id))->generate();

        // delta_pct viene en porcentaje 0-100; convertir a fracción para que el
        // formato 0.0% de Excel lo pinte como X.X% sin doble multiplicación.
        $rows = array_map(
            fn (array $b) => [
                $b['name'],
                (float) $b['current_spent'],
                (float) $b['historical_average'],
                (float) $b['projection'],
                $b['delta_pct'] === null ? '' : ((float) $b['delta_pct']) / 100,
            ],
            $report['categories']
        );

        $totalDeltaPct = $report['totals']['delta_pct'] === null
            ? ''
            : ((float) $report['totals']['delta_pct']) / 100;

        $exporter = (new ReportExporter)
            ->sheetTitle('Proyección de gasto')
            ->header('Proyección de gasto', 'Mes en curso: '.$report['month'])
            ->table(
                ['Categoría', 'Gastado este mes', 'Promedio histórico', 'Proyección fin de mes', 'Δ %'],
                $rows,
                [
                    ReportExporter::FORMAT_TEXT,
                    ReportExporter::FORMAT_MONEY,
                    ReportExporter::FORMAT_MONEY,
                    ReportExporter::FORMAT_MONEY,
                    ReportExporter::FORMAT_PCT,
                ]
            )
            ->footer([
                'TOTAL',
                (float) $report['totals']['current_spent'],
                (float) $report['totals']['historical_average'],
                (float) $report['totals']['projection'],
                $totalDeltaPct,
            ]);

        $filename = sprintf('fincore-proyeccion-gasto-%s.xlsx', $report['month']);

        return $exporter->download($filename);
    }
}
