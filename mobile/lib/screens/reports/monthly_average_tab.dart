import 'package:fincore/app_dependencies.dart';
import 'package:fincore/constants/category_catalog.dart';
import 'package:fincore/data/reports.dart';
import 'package:fincore/theme/fincore_colors.dart';
import 'package:fincore/widgets/amount_formatter.dart';
import 'package:fincore/widgets/base_card.dart';
import 'package:flutter/material.dart';

/// Tab "Promedio mensual" del reporte. Sprint
/// `flutter-reports-monthly-average-v1`.
///
/// Muestra el gasto promedio mensual prorrateado al día actual de los
/// últimos N meses cerrados (presets `[1, 3, 6, 12, 24]`, default 3) y lo
/// compara con el gasto del mes en curso hasta hoy. Debajo, desglose por
/// categoría ordenado por delta absoluto descendente.
///
/// Patrón de state idéntico a [CashflowTab]: `_monthsBack` + `_reportStream`
/// cacheado en `didChangeDependencies` para que `pumpAndSettle` asiente
/// limpio en widget tests.
///
/// Semáforo (RN-A10) compartido entre la card global y cada fila del
/// desglose: verde ≤95%, amarillo 95-110%, rojo >110%. Si
/// `historicalAverage == 0`, suprime el porcentaje y el semáforo.
class MonthlyAverageTab extends StatefulWidget {
  const MonthlyAverageTab({super.key});

  @override
  State<MonthlyAverageTab> createState() => _MonthlyAverageTabState();
}

class _MonthlyAverageTabState extends State<MonthlyAverageTab> {
  static const List<int> _presets = [1, 3, 6, 12, 24];
  int _monthsBack = 3;
  Stream<MonthlyAverageReport>? _reportStream;

  void _selectPreset(int n) {
    if (_monthsBack == n) return;
    setState(() {
      _monthsBack = n;
      _reportStream = _buildStream();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reportStream ??= _buildStream();
  }

  Stream<MonthlyAverageReport> _buildStream() {
    final deps = AppDependencies.of(context);
    return deps.reportsService.monthlyAverage(monthsBack: _monthsBack);
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final n in _presets)
              ChoiceChip(
                label: Text(_presetLabel(n)),
                selected: _monthsBack == n,
                onSelected: (_) => _selectPreset(n),
                showCheckmark: false,
                selectedColor: FincoreColors.accent.withValues(alpha: 0.18),
                backgroundColor: FincoreColors.surface,
                side: BorderSide(
                  color: _monthsBack == n
                      ? FincoreColors.accent
                      : FincoreColors.border,
                ),
                labelStyle: TextStyle(
                  color: _monthsBack == n
                      ? FincoreColors.accent
                      : FincoreColors.textPrimary,
                  fontWeight:
                      _monthsBack == n ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        StreamBuilder<MonthlyAverageReport>(
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
                _GlobalCard(report: report),
                const SizedBox(height: 8),
                _SubtitleLine(report: report),
                const SizedBox(height: 20),
                const _BreakdownHeader(),
                const SizedBox(height: 8),
                _CategoryBreakdown(report: report),
              ],
            );
          },
        ),
      ],
    );
  }

  String _presetLabel(int n) => n == 1 ? '1 mes' : '$n meses';
}

class _GlobalCard extends StatelessWidget {
  final MonthlyAverageReport report;
  const _GlobalCard({required this.report});

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColorForDelta(
      historical: report.historicalAverage,
      current: report.currentMonthSpent,
    );
    return BaseCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _HeaderMetric(
                label: 'Promedio',
                value: formatAmount(report.historicalAverage),
                color: FincoreColors.textPrimary,
              ),
              _HeaderMetric(
                label: 'Mes en curso',
                value: formatAmount(report.currentMonthSpent),
                color: FincoreColors.textPrimary,
              ),
              _HeaderMetric(
                label: 'Delta',
                value: _formatDelta(report.deltaAbsolute),
                color: statusColor,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: _StatusChip(
              historical: report.historicalAverage,
              current: report.currentMonthSpent,
              deltaPercent: report.deltaPercent,
            ),
          ),
        ],
      ),
    );
  }
}

class _SubtitleLine extends StatelessWidget {
  final MonthlyAverageReport report;
  const _SubtitleLine({required this.report});

  @override
  Widget build(BuildContext context) {
    final monthsLabel =
        report.monthsAvailable == 1 ? '1 mes cerrado' : '${report.monthsAvailable} meses cerrados';
    final base = 'Comparación al día ${report.currentDayOfMonth} del mes';
    final extra = ' (basado en $monthsLabel)';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        '$base$extra',
        style: const TextStyle(
          color: FincoreColors.textSubtle,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _BreakdownHeader extends StatelessWidget {
  const _BreakdownHeader();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        'Desglose por categoría',
        style: TextStyle(
          color: FincoreColors.textMuted,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _CategoryBreakdown extends StatelessWidget {
  final MonthlyAverageReport report;
  const _CategoryBreakdown({required this.report});

  @override
  Widget build(BuildContext context) {
    if (report.categoryBreakdown.isEmpty) {
      return const BaseCard(
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        child: Text(
          'Aún no hay categorías con movimientos en este período.',
          style: TextStyle(
            color: FincoreColors.textSubtle,
            fontSize: 12,
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final row in report.categoryBreakdown) ...[
          _CategoryRow(delta: row),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _CategoryRow extends StatelessWidget {
  final CategoryAverageDelta delta;
  const _CategoryRow({required this.delta});

  @override
  Widget build(BuildContext context) {
    final color = colorBySlug(delta.colorSlug);
    final icon = iconBySlug(delta.iconSlug);
    final statusColor = _statusColorForDelta(
      historical: delta.historicalAverage,
      current: delta.currentMonthSpent,
    );
    final deltaText = _formatDelta(delta.deltaAbsolute);
    final percentText = delta.deltaPercent == null
        ? '—'
        : '${delta.deltaPercent! >= 0 ? '+' : ''}${delta.deltaPercent!.toStringAsFixed(1)}%';

    return BaseCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  delta.name,
                  style: const TextStyle(
                    color: FincoreColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'Promedio ${formatAmount(delta.historicalAverage)} · Actual ${formatAmount(delta.currentMonthSpent)}',
                  style: const TextStyle(
                    color: FincoreColors.textSubtle,
                    fontSize: 11,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                deltaText,
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                percentText,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final double historical;
  final double current;
  final double? deltaPercent;
  const _StatusChip({
    required this.historical,
    required this.current,
    required this.deltaPercent,
  });

  @override
  Widget build(BuildContext context) {
    if (deltaPercent == null || historical == 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: FincoreColors.surfaceElevated,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: FincoreColors.border),
        ),
        child: const Text(
          'Sin histórico',
          style: TextStyle(
            color: FincoreColors.textSubtle,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }
    final color = _statusColorForDelta(historical: historical, current: current);
    final label = _statusLabel(historical: historical, current: current);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
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
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
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
            Icons.show_chart,
            size: 56,
            color: FincoreColors.textMuted,
          ),
          SizedBox(height: 12),
          Text(
            'Necesitás al menos 1 mes cerrado de uso para calcular promedio.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: FincoreColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Registrar los gastos a diario para que este reporte gane valor mes a mes.',
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

/// RN-A10: semáforo según porcentaje del actual sobre el promedio.
/// - Verde (positive) si actual ≤ 95% del promedio.
/// - Amarillo (warning) si 95% < actual ≤ 110%.
/// - Rojo (negative) si actual > 110%.
/// Cuando `historical == 0`, fallback gris (textMuted) — la UI igualmente
/// suprime el chip vía `_StatusChip`.
Color _statusColorForDelta({
  required double historical,
  required double current,
}) {
  if (historical == 0) return FincoreColors.textMuted;
  final ratio = current / historical;
  if (ratio <= 0.95) return FincoreColors.positive;
  if (ratio <= 1.10) return FincoreColors.warning;
  return FincoreColors.negative;
}

String _statusLabel({
  required double historical,
  required double current,
}) {
  if (historical == 0) return 'Sin histórico';
  final ratio = current / historical;
  if (ratio <= 0.95) return 'Por debajo';
  if (ratio <= 1.10) return 'En línea';
  return 'Por encima';
}

String _formatDelta(double value) {
  if (value == 0) return formatAmount(0);
  if (value > 0) return '+${formatAmount(value)}';
  return '-${formatAmount(value.abs())}';
}
