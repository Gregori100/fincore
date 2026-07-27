import 'package:fincore/app_dependencies.dart';
import 'package:fincore/constants/date_range_presets.dart';
import 'package:fincore/data/entries_filters.dart';
import 'package:fincore/data/reports.dart';
// Reusa el helper top-level `heatmapDayForMonthPosition` para no
// duplicar la conversión celda→DateTime (top-level públicos con el
// mismo nombre en 2 archivos daría conflicto de compilación).
import 'package:fincore/screens/reports/spending_heatmap_tab.dart'
    show heatmapDayForMonthPosition;
import 'package:fincore/theme/fincore_colors.dart';
import 'package:fincore/utils/money.dart';
import 'package:fincore/widgets/base_card.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// Tab "Heatmap ingresos" (11º) de /reports. Sprint
/// `flutter-reports-income-heatmap-v1`. Simétrico al 10º tab "Heatmap"
/// (gastos) pero para `kind='income'` y con paleta verde
/// (`FincoreColors.positive`).
///
/// Muestra un año completo de ingresos como **12 mini-heatmaps
/// mensuales** dispuestos en grilla 3×4. Cada mini es una cuadrícula
/// 7 columnas (Lun–Dom) × 6 filas (semanas del mes) con celdas
/// coloreadas según la intensidad de ingreso por día (RN-IHM06). Tap
/// en un mini abre el bottom sheet expandido; tap en un día del sheet
/// abre `/entries` con filtro custom (`from=to=día`, `kinds=['income']`,
/// RN-IHM09).
class IncomeHeatmapTab extends StatefulWidget {
  const IncomeHeatmapTab({super.key});

  @override
  State<IncomeHeatmapTab> createState() => _IncomeHeatmapTabState();
}

class _IncomeHeatmapTabState extends State<IncomeHeatmapTab> {
  late int _focusedYear;
  Stream<IncomeHeatmap>? _stream;

  @override
  void initState() {
    super.initState();
    _focusedYear = DateTime.now().year;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _stream ??= _buildStream();
  }

  Stream<IncomeHeatmap> _buildStream() {
    final deps = AppDependencies.of(context);
    return deps.reportsService.incomeHeatmap(year: _focusedYear);
  }

  void _onPrevYear() {
    setState(() {
      _focusedYear--;
      _stream = _buildStream();
    });
  }

  void _onNextYear() {
    setState(() {
      _focusedYear++;
      _stream = _buildStream();
    });
  }

  void _retryStream() {
    setState(() {
      _stream = _buildStream();
    });
  }

  void _onDayTap(DateTime day) {
    final from = DateTime(day.year, day.month, day.day);
    final to = DateTime(day.year, day.month, day.day, 23, 59, 59, 999);
    final filter = EntriesFilters(
      datePreset: DateRangePreset.custom,
      from: from,
      to: to,
      kinds: const ['income'],
    );
    context.push(filter.toDeepLink());
  }

  // Tap en un mini-heatmap del grid abre un bottom sheet con el mes
  // agrandado. Desde ahí el usuario puede tapear un día con precisión.
  // Post-smoke: los mini-heatmaps son útiles para ver el año de un
  // vistazo, pero las celdas de ~12 px son chicas para tap preciso —
  // el zoom por mes resuelve ese trade-off sin sacrificar la vista anual.
  void _onMonthTap(int month) {
    final heatmap = _lastHeatmap;
    if (heatmap == null) return;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: FincoreColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) => _MonthDetailSheet(
        year: _focusedYear,
        month: month,
        heatmap: heatmap,
        onDayTap: (day) {
          Navigator.of(sheetCtx).pop();
          _onDayTap(day);
        },
      ),
    );
  }

  // Cache del último IncomeHeatmap recibido, para pasarlo al sheet
  // sin depender del snapshot en el momento del tap.
  IncomeHeatmap? _lastHeatmap;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<IncomeHeatmap>(
      stream: _stream,
      builder: (context, snap) {
        if (snap.hasError) {
          return _ErrorState(onRetry: _retryStream);
        }
        if (!snap.hasData) {
          return const _LoadingState();
        }
        final heatmap = snap.data!;
        _lastHeatmap = heatmap;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _YearHeader(
                year: _focusedYear,
                onPrev: _onPrevYear,
                onNext: _onNextYear,
              ),
              const SizedBox(height: 12),
              _MonthsGrid(
                year: _focusedYear,
                heatmap: heatmap,
                onMonthTap: _onMonthTap,
              ),
              const SizedBox(height: 12),
              // Cuando el año está vacío, el empty banner ya comunica
              // "sin ingresos"; la leyenda de gradientes + subtexto
              // "Total: $0.00 · 0 días con ingreso" es ruido redundante.
              // Mostramos uno o el otro, no ambos.
              if (heatmap.daysWithIncome == 0)
                const _EmptyBanner()
              else
                _Legend(heatmap: heatmap),
            ],
          ),
        );
      },
    );
  }
}

class _YearHeader extends StatelessWidget {
  final int year;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  const _YearHeader({
    required this.year,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          onPressed: onPrev,
          icon: const Icon(Icons.chevron_left, color: FincoreColors.accent),
          tooltip: 'Año anterior',
        ),
        Text(
          '$year',
          style: const TextStyle(
            color: FincoreColors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        IconButton(
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right, color: FincoreColors.accent),
          tooltip: 'Año siguiente',
        ),
      ],
    );
  }
}

/// Grilla 3 columnas × 4 filas con los 12 mini-heatmaps mensuales del año.
class _MonthsGrid extends StatelessWidget {
  final int year;
  final IncomeHeatmap heatmap;
  final void Function(int month) onMonthTap;

  const _MonthsGrid({
    required this.year,
    required this.heatmap,
    required this.onMonthTap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 3 columnas + 2 gaps entre columnas de 12 px cada uno.
        const columns = 3;
        const gap = 12.0;
        final availableWidth = constraints.maxWidth;
        final monthWidth =
            (availableWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: List.generate(12, (i) {
            final month = i + 1;
            return SizedBox(
              width: monthWidth,
              child: _MonthMini(
                year: year,
                month: month,
                heatmap: heatmap,
                onTap: () => onMonthTap(month),
              ),
            );
          }),
        );
      },
    );
  }
}

/// Mini-heatmap de un mes (vista compacta del grid anual). 7 columnas
/// (Lun–Dom) × 6 filas. Tap en cualquier parte del mini abre el sheet
/// con el mes agrandado (los 12 mini-heatmaps son solo "resumen del
/// año"; el drill-down por día requiere el zoom del sheet).
class _MonthMini extends StatelessWidget {
  final int year;
  final int month;
  final IncomeHeatmap heatmap;
  final VoidCallback onTap;

  const _MonthMini({
    required this.year,
    required this.month,
    required this.heatmap,
    required this.onTap,
  });

  static const double _cellGap = 2;
  static const int _columns = 7;
  static const int _maxRows = 6;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final availableWidth = constraints.maxWidth;
            final cellSize =
                (availableWidth - _cellGap * (_columns - 1)) / _columns;
            final gridHeight =
                cellSize * _maxRows + _cellGap * (_maxRows - 1);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _MonthLabel(year: year, month: month),
                const SizedBox(height: 6),
                SizedBox(
                  height: gridHeight,
                  child: CustomPaint(
                    size: Size(availableWidth, gridHeight),
                    painter: _MonthMiniPainter(
                      year: year,
                      month: month,
                      heatmap: heatmap,
                      cellSize: cellSize,
                      gap: _cellGap,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Sheet modal con el mes agrandado. Cada celda es un `InkWell` para
/// que el tap sea preciso y con feedback visual. Muestra header con
/// nombre del mes + botón cerrar, encabezado con los días de la
/// semana (L M X J V S D), grid con celdas grandes, y un pie con el
/// total del mes.
class _MonthDetailSheet extends StatelessWidget {
  final int year;
  final int month;
  final IncomeHeatmap heatmap;
  final void Function(DateTime day) onDayTap;

  const _MonthDetailSheet({
    required this.year,
    required this.month,
    required this.heatmap,
    required this.onDayTap,
  });

  static const int _columns = 7;

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(year, month, 1);
    final firstWeekday = firstDay.weekday;
    final daysInMonth = DateTime(year, month + 1, 0).day;
    // Filas necesarias para acomodar el mes según en qué día de la
    // semana empieza (min 5, max 6).
    final totalCells = (firstWeekday - 1) + daysInMonth;
    final rows = (totalCells / _columns).ceil();

    var monthTotal = 0;
    for (var d = 1; d <= daysInMonth; d++) {
      monthTotal += heatmap.dayIncome[DateTime(year, month, d)] ?? 0;
    }

    final monthName = DateFormat('MMMM', 'es_MX').format(firstDay);
    final monthTitle =
        '${monthName[0].toUpperCase()}${monthName.substring(1)} $year';

    // A1 del quality review: envolvemos el contenido en un
    // `SingleChildScrollView` para blindar contra overflow en landscape
    // o pantallas cortas. En rotación horizontal el grid puede pasar de
    // ~640 px vs 400 px útiles disponibles → sin scroll wrapper dispara
    // RenderFlex overflow. El `ClampingScrollPhysics` evita el bounce
    // Android que se ve extraño dentro de un sheet modal.
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
            const _WeekdayHeader(),
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, constraints) {
                const gap = 6.0;
                final cellSize =
                    (constraints.maxWidth - gap * (_columns - 1)) / _columns;
                return Column(
                  children: List.generate(rows, (row) {
                    return Padding(
                      padding: EdgeInsets.only(top: row == 0 ? 0 : gap),
                      child: Row(
                        children: List.generate(_columns, (col) {
                          final day = heatmapDayForMonthPosition(year, month, col, row);
                          return Padding(
                            padding: EdgeInsets.only(
                              left: col == 0 ? 0 : gap,
                            ),
                            child: SizedBox(
                              width: cellSize,
                              height: cellSize,
                              child: day == null
                                  ? const SizedBox.shrink()
                                  : _DayCell(
                                      day: day,
                                      heatmap: heatmap,
                                      onTap: () => onDayTap(day),
                                    ),
                            ),
                          );
                        }),
                      ),
                    );
                  }),
                );
              },
            ),
            const SizedBox(height: 16),
            Text(
              'Ingreso del mes: ${formatCents(monthTotal)}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: FincoreColors.textSubtle,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class _WeekdayHeader extends StatelessWidget {
  const _WeekdayHeader();

  @override
  Widget build(BuildContext context) {
    const labels = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
    return Row(
      children: labels
          .map(
            (l) => Expanded(
              child: Text(
                l,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: FincoreColors.textSubtle,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _DayCell extends StatelessWidget {
  final DateTime day;
  final IncomeHeatmap heatmap;
  final VoidCallback onTap;

  const _DayCell({
    required this.day,
    required this.heatmap,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final level = heatmap.intensityFor(day);
    final color = _colorForIntensity(level);
    // Contraste del número: fondo oscuro (veryHigh) usa texto blanco;
    // el resto usa el color primario.
    final textColor = level == IntensityLevel.veryHigh
        ? Colors.white
        : FincoreColors.textPrimary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(6),
        ),
        alignment: Alignment.center,
        child: Text(
          '${day.day}',
          style: TextStyle(
            color: textColor,
            fontSize: 13,
            fontWeight: level == IntensityLevel.none
                ? FontWeight.w500
                : FontWeight.w600,
          ),
        ),
      ),
    );
  }

}

class _MonthLabel extends StatelessWidget {
  final int year;
  final int month;
  const _MonthLabel({required this.year, required this.month});

  @override
  Widget build(BuildContext context) {
    final label = DateFormat('MMM', 'es_MX').format(DateTime(year, month, 1));
    // Capitalizar (DateFormat viene en minúsculas para es_MX: "ene", "feb").
    final capitalized = label[0].toUpperCase() + label.substring(1);
    // Ícono `open_in_full` sutil al lado del nombre del mes: afordance
    // visual de que el mini es tapeable y abre el detalle expandido.
    // Discretion vs discoverability: 10 px con textSubtle es lo bastante
    // suave para no ensuciar la vista año, pero suficiente para que el
    // usuario primerizo entienda que el mini se puede ampliar.
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          capitalized,
          style: const TextStyle(
            color: FincoreColors.textSubtle,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 3),
        const Icon(
          Icons.open_in_full,
          size: 10,
          color: FincoreColors.textSubtle,
        ),
      ],
    );
  }
}

/// Mapea un [IntensityLevel] a su color en la paleta del heatmap.
/// Extraído a top-level (A4 del quality review) para evitar drift entre
/// `_DayCell`, `_MonthMiniPainter` y `_Legend` — antes tenían 3 copias
/// idénticas del switch y cambiar la paleta requería tocar 3 lugares.
Color _colorForIntensity(IntensityLevel level) {
  switch (level) {
    case IntensityLevel.none:
      return FincoreColors.surfaceElevated;
    case IntensityLevel.low:
      return FincoreColors.positive.withValues(alpha: 0.25);
    case IntensityLevel.medium:
      return FincoreColors.positive.withValues(alpha: 0.45);
    case IntensityLevel.high:
      return FincoreColors.positive.withValues(alpha: 0.7);
    case IntensityLevel.veryHigh:
      return FincoreColors.positive;
  }
}

class _MonthMiniPainter extends CustomPainter {
  final int year;
  final int month;
  final IncomeHeatmap heatmap;
  final double cellSize;
  final double gap;

  _MonthMiniPainter({
    required this.year,
    required this.month,
    required this.heatmap,
    required this.cellSize,
    required this.gap,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final firstDay = DateTime(year, month, 1);
    final firstWeekday = firstDay.weekday; // 1=Mon..7=Sun
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final paint = Paint();

    for (var day = 1; day <= daysInMonth; day++) {
      final dayIndex = (firstWeekday - 1) + (day - 1);
      final column = dayIndex % 7;
      final row = dayIndex ~/ 7;
      final x = column * (cellSize + gap);
      final y = row * (cellSize + gap);
      final date = DateTime(year, month, day);
      paint.color = _colorForIntensity(heatmap.intensityFor(date));
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, cellSize, cellSize),
          const Radius.circular(2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_MonthMiniPainter oldDelegate) {
    return oldDelegate.year != year ||
        oldDelegate.month != month ||
        oldDelegate.heatmap != heatmap ||
        oldDelegate.cellSize != cellSize;
  }
}

class _Legend extends StatelessWidget {
  final IncomeHeatmap heatmap;
  const _Legend({required this.heatmap});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Menos',
              style: TextStyle(
                color: FincoreColors.textSubtle,
                fontSize: 11,
              ),
            ),
            const SizedBox(width: 8),
            _swatch(_colorForIntensity(IntensityLevel.none)),
            _swatch(_colorForIntensity(IntensityLevel.low)),
            _swatch(_colorForIntensity(IntensityLevel.medium)),
            _swatch(_colorForIntensity(IntensityLevel.high)),
            _swatch(_colorForIntensity(IntensityLevel.veryHigh)),
            const SizedBox(width: 8),
            const Text(
              'Más',
              style: TextStyle(
                color: FincoreColors.textSubtle,
                fontSize: 11,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Total: ${formatCents(heatmap.total)}'
          ' · ${heatmap.daysWithIncome} '
          '${heatmap.daysWithIncome == 1 ? 'día' : 'días'} con ingreso',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: FincoreColors.textSubtle,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _swatch(Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

class _EmptyBanner extends StatelessWidget {
  const _EmptyBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: FincoreColors.accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: FincoreColors.accent.withValues(alpha: 0.3),
        ),
      ),
      child: const Row(
        children: [
          Icon(
            Icons.info_outline,
            size: 16,
            color: FincoreColors.accent,
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Sin ingresos registrados en este año.',
              style: TextStyle(
                color: FincoreColors.accent,
                fontSize: 12,
              ),
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
    return const Padding(
      padding: EdgeInsets.all(16),
      child: BaseCard(
        padding: EdgeInsets.all(24),
        child: Center(
          child: Text(
            'Cargando…',
            style: TextStyle(color: FincoreColors.textSubtle),
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: BaseCard(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(
              Icons.error_outline,
              color: FincoreColors.negative,
              size: 32,
            ),
            const SizedBox(height: 8),
            const Text(
              'Error al cargar el heatmap de ingresos.',
              style: TextStyle(color: FincoreColors.textPrimary),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: onRetry,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}

