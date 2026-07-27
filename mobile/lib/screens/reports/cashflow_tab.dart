import 'package:fincore/app_dependencies.dart';
import 'package:fincore/constants/category_catalog.dart';
import 'package:fincore/constants/date_range_presets.dart';
import 'package:fincore/data/entries_filters.dart';
import 'package:fincore/data/reports.dart';
import 'package:fincore/widgets/delta_chip.dart';
import 'package:fincore/theme/fincore_colors.dart';
import 'package:fincore/utils/money.dart';
import 'package:fincore/widgets/base_card.dart';
import 'package:fincore/widgets/date_field_outlined.dart';
import 'package:fincore/widgets/error_snackbar.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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
        'El rango no es válido. Verificar las fechas.',
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
        'El rango no es válido. Verificar las fechas.',
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
            value: formatCents(report.totalIncome),
            color: FincoreColors.positive,
          ),
          _HeaderMetric(
            label: 'Gastos',
            value: formatCents(report.totalExpense),
            color: FincoreColors.negative,
          ),
          _HeaderMetric(
            label: 'Neto',
            value: report.net >= 0
                ? formatCents(report.net)
                : '-${formatCents(report.net.abs())}',
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
    final maxValue = report.months.fold<int>(0, (acc, m) {
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
  final int maxValue;

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

  void _openBreakdownSheet(BuildContext context) {
    // Sprint flutter-cashflow-monthly-breakdown-v1: tap en la fila del
    // mes abre el desglose por categoría del mes. Cachea el `monthAnchor`
    // en el sheet — cambiar el rango del tab con el sheet abierto NO
    // reactiva el sheet (CB-17 aceptado).
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: FincoreColors.surface,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _MonthBreakdownSheet(monthAnchor: month.firstDay),
    );
  }

  @override
  Widget build(BuildContext context) {
    final netColor = month.net >= 0
        ? FincoreColors.positive
        : FincoreColors.negative;
    final monthLabel = DateFormat('MMM y', 'es_MX').format(month.firstDay);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openBreakdownSheet(context),
        borderRadius: BorderRadius.circular(4),
        child: Padding(
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
                  formatCents(month.income),
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
                  formatCents(month.expense),
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
                      ? formatCents(month.net)
                      : '-${formatCents(month.net.abs())}',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: netColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              const Icon(
                // `expand_more` señala "abre desglose" (bottom sheet), no
                // "navega a otra pantalla" — reservamos `chevron_right`
                // para pushes de ruta (convención del proyecto).
                Icons.expand_more,
                size: 16,
                color: FincoreColors.textSubtle,
              ),
            ],
          ),
        ),
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
            'Ajustar las fechas o registrar un movimiento.',
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

// ---------------------------------------------------------------------------
// Bottom sheet del sprint flutter-cashflow-monthly-breakdown-v1
// ---------------------------------------------------------------------------

/// Sheet modal con el desglose por categoría del mes anclado en
/// `monthAnchor`. Sprint `flutter-cashflow-monthly-breakdown-v1`.
///
/// Cachea el Stream una sola vez para que `pumpAndSettle` no cuelgue en
/// widget tests (patrón cashflow tab). El sheet permanece abierto hasta
/// que el usuario lo cierra — cambiar el rango del tab base con el sheet
/// abierto NO reactiva el sheet (CB-17 aceptado).
class _MonthBreakdownSheet extends StatefulWidget {
  final DateTime monthAnchor;

  const _MonthBreakdownSheet({required this.monthAnchor});

  @override
  State<_MonthBreakdownSheet> createState() => _MonthBreakdownSheetState();
}

class _MonthBreakdownSheetState extends State<_MonthBreakdownSheet> {
  Stream<MonthBreakdown>? _stream;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _stream ??= AppDependencies.of(context)
        .reportsService
        .cashflowMonthBreakdown(monthAnchor: widget.monthAnchor);
  }

  Future<void> _drillDown() async {
    // Capturar handlers antes del await por si el context se desmonta
    // durante el pop del sheet (R3 del plan).
    //
    // `EntriesListScreen` NO lee `state.extra` — solo parsea query params
    // vía `EntriesFilters.parse(uri.queryParameters)`. Por eso el drill-down
    // usa `.toDeepLink()` para serializar el filtro como query string
    // (patrón oficial del proyecto: ver calendar / heatmap tabs).
    final navigator = Navigator.of(context);
    final router = GoRouter.of(context);
    final target = EntriesFilters.forMonth(firstDay: widget.monthAnchor)
        .toDeepLink();
    await navigator.maybePop();
    if (!mounted) return;
    router.push(target);
  }

  @override
  Widget build(BuildContext context) {
    final rawMonthName =
        DateFormat('MMMM y', 'es_MX').format(widget.monthAnchor);
    final monthTitle =
        '${rawMonthName[0].toUpperCase()}${rawMonthName.substring(1)}';

    return SafeArea(
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    monthTitle,
                    style: const TextStyle(
                      color: FincoreColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 18,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(
                    Icons.close,
                    color: FincoreColors.textSubtle,
                  ),
                  tooltip: 'Cerrar',
                ),
              ],
            ),
            const SizedBox(height: 12),
            StreamBuilder<MonthBreakdown>(
              stream: _stream,
              builder: (context, snap) {
                if (snap.hasError) {
                  return _MonthBreakdownError(error: snap.error);
                }
                if (!snap.hasData) {
                  return const _MonthBreakdownLoading();
                }
                final data = snap.data!;
                final hasIncome = data.incomeBuckets.isNotEmpty;
                final hasExpense = data.expenseBuckets.isNotEmpty;
                if (!hasIncome && !hasExpense) {
                  return const _MonthBreakdownEmpty();
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _BreakdownSummary(breakdown: data),
                    const SizedBox(height: 16),
                    if (hasIncome) ...[
                      const _SectionHeader(label: 'Ingresos por categoría'),
                      const SizedBox(height: 8),
                      for (final b in data.incomeBuckets)
                        _CategoryFlowRow(flow: b, isExpenseSide: false),
                    ],
                    if (hasIncome && hasExpense) const SizedBox(height: 16),
                    if (hasExpense) ...[
                      const _SectionHeader(label: 'Gastos por categoría'),
                      const SizedBox(height: 8),
                      for (final b in data.expenseBuckets)
                        _CategoryFlowRow(flow: b, isExpenseSide: true),
                    ],
                    const SizedBox(height: 16),
                    TextButton.icon(
                      onPressed: _drillDown,
                      icon: const Icon(Icons.arrow_forward, size: 18),
                      label: const Text('Ver movimientos'),
                      style: TextButton.styleFrom(
                        foregroundColor: FincoreColors.accent,
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _BreakdownSummary extends StatelessWidget {
  final MonthBreakdown breakdown;
  const _BreakdownSummary({required this.breakdown});

  @override
  Widget build(BuildContext context) {
    final netColor = breakdown.net >= 0
        ? FincoreColors.positive
        : FincoreColors.negative;
    final netLabel = breakdown.net >= 0
        ? formatCents(breakdown.net)
        : '-${formatCents(breakdown.net.abs())}';
    return BaseCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ingresos',
                  style: TextStyle(
                    color: FincoreColors.textMuted,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  formatCents(breakdown.totalIncome),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: FincoreColors.positive,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                DeltaChip(
                  delta: breakdown.deltaIncome,
                  isExpenseSide: false,
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Gastos',
                  style: TextStyle(
                    color: FincoreColors.textMuted,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  formatCents(breakdown.totalExpense),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: FincoreColors.negative,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                DeltaChip(
                  delta: breakdown.deltaExpense,
                  isExpenseSide: true,
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Neto',
                  style: TextStyle(
                    color: FincoreColors.textMuted,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  netLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: netColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                DeltaChip(
                  // Neto sube = mejor (más plata queda) → coincide con
                  // el lado ingresos (isExpenseSide=false).
                  delta: breakdown.deltaNet,
                  isExpenseSide: false,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: FincoreColors.textMuted,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.3,
      ),
    );
  }
}

/// Fila de una categoría dentro de una sección del sheet. Usa
/// `colorBySlug`/`iconBySlug` directamente para evitar construir un
/// objeto `Category` sintético (R8 del plan). Sin categoría → chip
/// gris con `Icons.label_off_outlined` (fallback estándar del proyecto).
class _CategoryFlowRow extends StatelessWidget {
  final CategoryFlow flow;
  final bool isExpenseSide;
  const _CategoryFlowRow({required this.flow, required this.isExpenseSide});

  @override
  Widget build(BuildContext context) {
    final color = flow.colorSlug != null
        ? colorBySlug(flow.colorSlug)
        : FincoreColors.textSubtle;
    final icon = flow.iconSlug != null
        ? iconBySlug(flow.iconSlug)
        : Icons.label_off_outlined;
    // Sprint polish 0.18.2+92: reemplazar el porcentaje gris del share
    // por una barra de progreso fina debajo del row. Elimina la
    // ambigüedad de "dos números lado a lado" (share del mes vs delta
    // vs mes previo), aprovecha que el ojo lee proporciones más rápido
    // que dígitos, y deja el chip de delta como único número numérico
    // de la fila.
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: color.withValues(alpha: 0.4),
                    width: 1,
                  ),
                ),
                child: Icon(icon, size: 15, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  flow.label,
                  style: const TextStyle(
                    color: FincoreColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                formatCents(flow.amount),
                style: const TextStyle(
                  color: FincoreColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 6),
              SizedBox(
                width: 66,
                child: DeltaChip(
                  delta: flow.delta,
                  isExpenseSide: isExpenseSide,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Barra de progreso alineada con el label (28 chip + 10 gap
          // = 38 px de padding izquierdo).
          Padding(
            padding: const EdgeInsets.only(left: 38, right: 4),
            child: _ShareBar(percent: flow.percent, color: color),
          ),
        ],
      ),
    );
  }
}

/// Barra horizontal fina que representa el share del bucket dentro del
/// mes. Reemplaza el porcentaje gris textual (sprint polish 0.18.2+92)
/// para eliminar la ambigüedad visual con el chip de delta.
class _ShareBar extends StatelessWidget {
  final double percent;
  final Color color;
  const _ShareBar({required this.percent, required this.color});

  @override
  Widget build(BuildContext context) {
    final clamped = (percent / 100).clamp(0.0, 1.0);
    return Container(
      height: 3,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: clamped,
          child: Container(
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),
    );
  }
}

// _DeltaChip + helpers extraídos a `mobile/lib/widgets/delta_chip.dart`
// en el sprint `flutter-reports-shared-widgets-v1` (2026-07-14) para
// consumo compartido desde futuros reports y drill-downs.

class _MonthBreakdownLoading extends StatelessWidget {
  const _MonthBreakdownLoading();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: FincoreColors.accent,
        ),
      ),
    );
  }
}

class _MonthBreakdownEmpty extends StatelessWidget {
  const _MonthBreakdownEmpty();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Icon(
            Icons.event_busy,
            color: FincoreColors.textSubtle,
            size: 32,
          ),
          SizedBox(height: 8),
          Text(
            'Sin movimientos en este mes.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: FincoreColors.textMuted,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthBreakdownError extends StatelessWidget {
  final Object? error;
  const _MonthBreakdownError({required this.error});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          const Icon(
            Icons.error_outline,
            color: FincoreColors.negative,
            size: 28,
          ),
          const SizedBox(height: 8),
          const Text(
            'No se pudo cargar el desglose.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: FincoreColors.negative,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: 4),
            Text(
              error.toString(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: FincoreColors.textSubtle,
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
