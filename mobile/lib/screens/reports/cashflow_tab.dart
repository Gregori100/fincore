import 'package:fincore/app_dependencies.dart';
import 'package:fincore/constants/date_range_presets.dart';
import 'package:fincore/data/reports.dart';
import 'package:fincore/theme/fincore_colors.dart';
import 'package:fincore/widgets/amount_formatter.dart';
import 'package:fincore/widgets/base_card.dart';
import 'package:fincore/widgets/date_field_outlined.dart';
import 'package:fincore/widgets/error_snackbar.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Tab "Cashflow mensual" del reporte. Sprint `flutter-reports-cashflow-v1`.
///
/// Reusa el patrón de `SpendingByCategoryTab`: header con chips de presets de
/// fecha + state `_from/_to/_preset`, Stream cacheado en `_reportStream` para
/// que `pumpAndSettle` asiente en widget tests. El body reemplaza la lista de
/// buckets por:
/// - Header de 3 métricas (ingresos, gastos, neto del período).
/// - Bar chart pareado nativo (1 columna por mes, 2 barras verticales).
/// - Breakdown numérico fila a fila.
///
/// Default `thisMonth` por coherencia con el otro tab (decisión P-001).
class CashflowTab extends StatefulWidget {
  const CashflowTab({super.key});

  @override
  State<CashflowTab> createState() => _CashflowTabState();
}

class _CashflowTabState extends State<CashflowTab> {
  late DateTime _from;
  late DateTime _to;
  DateRangePreset _preset = DateRangePreset.thisMonth;
  Stream<CashflowReport>? _reportStream;

  @override
  void initState() {
    super.initState();
    final r = dateRangeForPreset(DateRangePreset.thisMonth, DateTime.now());
    _from = r.$1;
    _to = r.$2;
  }

  void _selectPreset(DateRangePreset preset) {
    final r = dateRangeForPreset(
      preset,
      DateTime.now(),
      currentFrom: _from,
      currentTo: _to,
    );
    setState(() {
      _preset = preset;
      _from = r.$1;
      _to = r.$2;
      _reportStream = _buildStream();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reportStream ??= _buildStream();
  }

  Stream<CashflowReport> _buildStream() {
    final deps = AppDependencies.of(context);
    return deps.reportsService.cashflowByMonth(from: _from, to: _to);
  }

  void _updateRange({DateTime? from, DateTime? to}) {
    setState(() {
      if (from != null) _from = from;
      if (to != null) _to = to;
      _reportStream = _buildStream();
    });
  }

  Future<void> _pickFrom(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _from,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(2100, 12, 31),
      helpText: 'Desde',
    );
    if (picked == null) return;
    if (!context.mounted) return;
    final newFrom = DateTime(picked.year, picked.month, picked.day);
    if (newFrom.isAfter(_to)) {
      showWarningSnackbar(
        context,
        'El rango no es válido. Revisá las fechas.',
      );
      return;
    }
    _updateRange(from: newFrom);
  }

  Future<void> _pickTo(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _to,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(2100, 12, 31),
      helpText: 'Hasta',
    );
    if (picked == null) return;
    if (!context.mounted) return;
    final newTo =
        DateTime(picked.year, picked.month, picked.day, 23, 59, 59, 999);
    if (newTo.isBefore(_from)) {
      showWarningSnackbar(
        context,
        'El rango no es válido. Revisá las fechas.',
      );
      return;
    }
    _updateRange(to: newTo);
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('d MMM y', 'es_MX');
    final isCustom = _preset == DateRangePreset.custom;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final p in DateRangePreset.values)
              ChoiceChip(
                label: Text(p.label),
                selected: _preset == p,
                onSelected: (_) => _selectPreset(p),
                showCheckmark: false,
                selectedColor: FincoreColors.accent.withValues(alpha: 0.18),
                backgroundColor: FincoreColors.surface,
                side: BorderSide(
                  color: _preset == p
                      ? FincoreColors.accent
                      : FincoreColors.border,
                ),
                labelStyle: TextStyle(
                  color: _preset == p
                      ? FincoreColors.accent
                      : FincoreColors.textPrimary,
                  fontWeight: _preset == p ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (!isCustom)
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 6),
            child: Text(
              '${dateFormat.format(_from)} — ${dateFormat.format(_to)}',
              style: const TextStyle(
                color: FincoreColors.textSubtle,
                fontSize: 12,
              ),
            ),
          ),
        if (isCustom) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: DateFieldOutlined(
                  label: 'Desde',
                  value: _from,
                  format: dateFormat,
                  onTap: () => _pickFrom(context),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DateFieldOutlined(
                  label: 'Hasta',
                  value: _to,
                  format: dateFormat,
                  onTap: () => _pickTo(context),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        StreamBuilder<CashflowReport>(
          stream: _reportStream,
          builder: (context, snap) {
            if (snap.hasError) {
              return _ErrorState(
                error: snap.error,
                onRetry: () => setState(() {
                  _reportStream = _buildStream();
                }),
              );
            }
            if (!snap.hasData) {
              return const _LoadingState();
            }
            final report = snap.data!;
            if (report.isEmpty) {
              return const _EmptyState();
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _CashflowHeader(report: report),
                const SizedBox(height: 16),
                _CashflowChart(report: report),
                const SizedBox(height: 16),
                _CashflowBreakdown(report: report),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _CashflowHeader extends StatelessWidget {
  final CashflowReport report;
  const _CashflowHeader({required this.report});

  @override
  Widget build(BuildContext context) {
    final netColor = report.net >= 0
        ? FincoreColors.positive
        : FincoreColors.negative;
    return BaseCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _HeaderMetric(
            label: 'Ingresos',
            value: formatAmount(report.totalIncome),
            color: FincoreColors.positive,
          ),
          _HeaderMetric(
            label: 'Gastos',
            value: formatAmount(report.totalExpense),
            color: FincoreColors.negative,
          ),
          _HeaderMetric(
            label: 'Neto',
            value: report.net >= 0
                ? formatAmount(report.net)
                : '-${formatAmount(report.net.abs())}',
            color: netColor,
          ),
        ],
      ),
    );
  }
}

class _HeaderMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _HeaderMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: FincoreColors.textSubtle,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

/// Ancho mínimo por columna del chart. Con menos pixeles las dos barras
/// pareadas se ven aplastadas. Con 6 columnas a 48px = 288px caben en cels
/// de 360dp+; con más columnas, scroll horizontal.
const double _kColumnWidth = 48.0;

/// Alto del área de barras (sin labels del eje X). Suficiente para que se
/// note la diferencia de altura entre meses sin ocupar media pantalla.
const double _kChartHeight = 140.0;

class _CashflowChart extends StatelessWidget {
  final CashflowReport report;
  const _CashflowChart({required this.report});

  @override
  Widget build(BuildContext context) {
    final maxValue = report.months.fold<double>(0, (acc, m) {
      final localMax = m.income > m.expense ? m.income : m.expense;
      return localMax > acc ? localMax : acc;
    });
    return BaseCard(
      padding: const EdgeInsets.fromLTRB(8, 16, 8, 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: _kChartHeight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final m in report.months)
                    _ChartColumn(
                      month: m,
                      maxValue: maxValue,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                for (final m in report.months)
                  SizedBox(
                    width: _kColumnWidth,
                    child: Text(
                      DateFormat('MMM', 'es_MX').format(m.firstDay),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: FincoreColors.textSubtle,
                        fontSize: 11,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ChartColumn extends StatelessWidget {
  final MonthCashflow month;
  final double maxValue;

  const _ChartColumn({required this.month, required this.maxValue});

  @override
  Widget build(BuildContext context) {
    final incomeFactor =
        maxValue > 0 ? (month.income / maxValue).clamp(0.0, 1.0) : 0.0;
    final expenseFactor =
        maxValue > 0 ? (month.expense / maxValue).clamp(0.0, 1.0) : 0.0;
    return SizedBox(
      width: _kColumnWidth,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _Bar(factor: incomeFactor, color: FincoreColors.positive),
          const SizedBox(width: 4),
          _Bar(factor: expenseFactor, color: FincoreColors.negative),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  final double factor;
  final Color color;
  const _Bar({required this.factor, required this.color});

  @override
  Widget build(BuildContext context) {
    // Alto mínimo de 2px para que un valor de 0 deje un sliver visible y
    // mantenga la alineación visual con los meses pareados. Sin esto, un mes
    // con income=0 mostraría solo una barra (rojo) descentrada.
    final height = (factor * _kChartHeight).clamp(2.0, _kChartHeight);
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: Container(
        width: 14,
        height: height,
        color: color,
      ),
    );
  }
}

class _CashflowBreakdown extends StatelessWidget {
  final CashflowReport report;
  const _CashflowBreakdown({required this.report});

  @override
  Widget build(BuildContext context) {
    return BaseCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Column(
        children: [
          for (var i = 0; i < report.months.length; i++) ...[
            if (i > 0)
              const Divider(height: 1, color: FincoreColors.border),
            _BreakdownRow(month: report.months[i]),
          ],
        ],
      ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  final MonthCashflow month;
  const _BreakdownRow({required this.month});

  @override
  Widget build(BuildContext context) {
    final netColor = month.net >= 0
        ? FincoreColors.positive
        : FincoreColors.negative;
    final monthLabel = DateFormat('MMM y', 'es_MX').format(month.firstDay);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            child: Text(
              monthLabel,
              style: const TextStyle(
                color: FincoreColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              formatAmount(month.income),
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: FincoreColors.positive,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              formatAmount(month.expense),
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: FincoreColors.negative,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              month.net >= 0
                  ? formatAmount(month.net)
                  : '-${formatAmount(month.net.abs())}',
              textAlign: TextAlign.right,
              style: TextStyle(
                color: netColor,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const BaseCard(
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            Icons.trending_up,
            size: 56,
            color: FincoreColors.textMuted,
          ),
          SizedBox(height: 12),
          Text(
            'No hay movimientos en este rango.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: FincoreColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Ajustá las fechas o registrá un movimiento.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: FincoreColors.textSubtle,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const BaseCard(
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      child: Center(
        child: Text(
          'Cargando…',
          style: TextStyle(
            color: FincoreColors.textSubtle,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final Object? error;
  final VoidCallback onRetry;

  const _ErrorState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return BaseCard(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            size: 48,
            color: FincoreColors.warning,
          ),
          const SizedBox(height: 12),
          const Text(
            'No pude armar el reporte.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: FincoreColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            error?.toString() ?? 'Error desconocido',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: FincoreColors.textSubtle,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Reintentar'),
            style: OutlinedButton.styleFrom(
              foregroundColor: FincoreColors.accent,
            ),
          ),
        ],
      ),
    );
  }
}
