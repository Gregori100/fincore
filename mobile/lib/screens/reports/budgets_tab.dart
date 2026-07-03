import 'package:fincore/app_dependencies.dart';
import 'package:fincore/constants/category_catalog.dart';
import 'package:fincore/data/reports.dart';
import 'package:fincore/theme/fincore_colors.dart';
import 'package:fincore/widgets/amount_formatter.dart';
import 'package:fincore/widgets/base_card.dart';
import 'package:fincore/widgets/skeleton.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// Tab "Presupuestos" del reporte. Sprint `flutter-budgets-v1`.
///
/// Muestra el progreso por categoría con `monthly_limit` definido:
/// gastado vs límite, % usado, disponible, badges de estado
/// (OK/Warning/Excedido/Sin gasto). Reactivo: cambios de presupuesto o
/// registro de gastos actualizan el reporte sin refresh.
///
/// Selector de mes (sprint `flutter-budgets-month-picker-v1`): permite
/// ver el progreso de meses pasados. Como no se guarda historial del
/// `monthly_limit`, el límite mostrado siempre es el vigente hoy
/// (documentado en el aviso de la UI cuando no es el mes en curso).
class BudgetsTab extends StatefulWidget {
  const BudgetsTab({super.key});

  @override
  State<BudgetsTab> createState() => _BudgetsTabState();
}

class _BudgetsTabState extends State<BudgetsTab> {
  Stream<List<BudgetProgress>>? _stream;
  late DateTime _monthAnchor;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _monthAnchor = DateTime(now.year, now.month, 1);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _stream ??= _buildStream();
  }

  Stream<List<BudgetProgress>> _buildStream() {
    return AppDependencies.of(context)
        .reportsService
        .watchBudgetsProgress(monthAnchor: _monthAnchor);
  }

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _monthAnchor.year == now.year && _monthAnchor.month == now.month;
  }

  bool get _isFutureMonth {
    final now = DateTime.now();
    if (_monthAnchor.year > now.year) return true;
    if (_monthAnchor.year == now.year && _monthAnchor.month > now.month) {
      return true;
    }
    return false;
  }

  void _shiftMonth(int delta) {
    setState(() {
      _monthAnchor =
          DateTime(_monthAnchor.year, _monthAnchor.month + delta, 1);
      _stream = _buildStream();
    });
  }

  Future<void> _pickMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _monthAnchor,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(DateTime.now().year + 5, 12, 31),
      helpText: 'Seleccionar mes',
      initialDatePickerMode: DatePickerMode.year,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _monthAnchor = DateTime(picked.year, picked.month, 1);
      _stream = _buildStream();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _MonthSelector(
          anchor: _monthAnchor,
          isCurrentMonth: _isCurrentMonth,
          canGoForward: !_isFutureMonth,
          onPrev: () => _shiftMonth(-1),
          onNext: () => _shiftMonth(1),
          onTap: _pickMonth,
        ),
        if (!_isCurrentMonth) const _HistoricalLimitNotice(),
        Expanded(
          child: StreamBuilder<List<BudgetProgress>>(
            stream: _stream,
            builder: (context, snap) {
              if (snap.hasError) {
                return _ErrorState(error: snap.error);
              }
              if (!snap.hasData) {
                return const _LoadingState();
              }
              final items = snap.data!;
              if (items.isEmpty) {
                return const _EmptyState();
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, i) => _BudgetTile(progress: items[i]),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _MonthSelector extends StatelessWidget {
  final DateTime anchor;
  final bool isCurrentMonth;
  final bool canGoForward;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onTap;

  const _MonthSelector({
    required this.anchor,
    required this.isCurrentMonth,
    required this.canGoForward,
    required this.onPrev,
    required this.onNext,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final label = DateFormat('MMMM yyyy', 'es_MX').format(anchor);
    // Capitalizar la primera letra del nombre del mes (español pone en
    // minúscula por default).
    final display = label.isEmpty
        ? label
        : '${label[0].toUpperCase()}${label.substring(1)}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: onPrev,
            tooltip: 'Mes anterior',
            color: FincoreColors.textSubtle,
          ),
          Expanded(
            child: Center(
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.calendar_month_outlined,
                        size: 18,
                        color: FincoreColors.accent,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        display,
                        style: const TextStyle(
                          color: FincoreColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (isCurrentMonth) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: FincoreColors.accent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            'Hoy',
                            style: TextStyle(
                              color: FincoreColors.accent,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: canGoForward ? onNext : null,
            tooltip: 'Mes siguiente',
            color: FincoreColors.textSubtle,
            disabledColor:
                FincoreColors.textSubtle.withValues(alpha: 0.3),
          ),
        ],
      ),
    );
  }
}

class _HistoricalLimitNotice extends StatelessWidget {
  const _HistoricalLimitNotice();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: FincoreColors.warning.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: FincoreColors.warning.withValues(alpha: 0.3),
          ),
        ),
        child: const Row(
          children: [
            Icon(
              Icons.info_outline,
              size: 16,
              color: FincoreColors.warning,
            ),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'El límite mostrado es el actual, no el que estaba vigente '
                'ese mes. El gasto sí corresponde al mes seleccionado.',
                style: TextStyle(
                  color: FincoreColors.warning,
                  fontSize: 11,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: const [
        SkeletonCard(),
        SizedBox(height: 12),
        SkeletonCard(),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.savings_outlined,
              size: 64,
              color: FincoreColors.textMuted,
            ),
            const SizedBox(height: 16),
            const Text(
              'No definiste presupuestos aún',
              style: TextStyle(
                color: FincoreColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Editar una categoría de gasto y definir el monto '
              'mensual. El progreso aparece aquí.',
              style: TextStyle(
                color: FincoreColors.textSubtle,
                fontSize: 13,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => context.push('/categories'),
              icon: const Icon(Icons.category_outlined),
              label: const Text('Ir a Categorías'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final Object? error;
  const _ErrorState({required this.error});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline,
                size: 48, color: FincoreColors.negative),
            const SizedBox(height: 16),
            Text(
              'No se pudieron cargar los presupuestos.\n${error ?? ''}',
              style: const TextStyle(color: FincoreColors.textMuted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _BudgetTile extends StatelessWidget {
  final BudgetProgress progress;
  const _BudgetTile({required this.progress});

  @override
  Widget build(BuildContext context) {
    final ringColor = _ringColorFor(progress);
    return BaseCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Chip inline con color+ícono del catálogo (evita depender del
              // widget CategoryBadge que requiere un modelo Category).
              _CategoryIconChip(
                colorSlug: progress.colorSlug,
                iconSlug: progress.iconSlug,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  progress.categoryName,
                  style: const TextStyle(
                    color: FincoreColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (progress.isNoSpend) const _NoSpendBadge(),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _UsedRing(
                usedPct: progress.usedPct,
                color: ringColor,
                // Meta $0 + gasto > 0 (usedPct null pero excedida): llenar
                // el ring en rojo para comunicar la gravedad.
                forceFilled: progress.isOverBudget,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _MoneyRow(
                      label: 'Gastado',
                      amount: progress.spent,
                      amountColor: progress.isOverBudget
                          ? FincoreColors.negative
                          : FincoreColors.textPrimary,
                    ),
                    const SizedBox(height: 4),
                    _MoneyRow(
                      label: 'Límite',
                      amount: progress.monthlyLimit,
                      amountColor: FincoreColors.textSubtle,
                    ),
                    const SizedBox(height: 4),
                    _MoneyRow(
                      label: 'Disponible',
                      amount: progress.available,
                      // Color por estado: positive solo cuando hay disponible
                      // saludable; muted cuando la categoría está excedida
                      // (disponible=0, mostrar "$ 0" en verde brillante era
                      // contradictorio con el badge rojo).
                      amountColor: progress.isOverBudget
                          ? FincoreColors.textSubtle
                          : progress.isWarning
                              ? FincoreColors.warning
                              : FincoreColors.positive,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (progress.isOverBudget && progress.overBy != null) ...[
            const SizedBox(height: 12),
            _OverBadge(overBy: progress.overBy!),
          ],
        ],
      ),
    );
  }

  Color _ringColorFor(BudgetProgress p) {
    if (p.isOverBudget) return FincoreColors.negative;
    if (p.isWarning) return FincoreColors.warning;
    // OK con gasto o sin gasto: usar el color del catálogo de la categoría
    // como acento visual — refuerza identidad de la categoría.
    return colorBySlug(p.colorSlug);
  }
}

class _CategoryIconChip extends StatelessWidget {
  final String colorSlug;
  final String iconSlug;
  const _CategoryIconChip({required this.colorSlug, required this.iconSlug});

  @override
  Widget build(BuildContext context) {
    final color = colorBySlug(colorSlug);
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      alignment: Alignment.center,
      child: Icon(iconBySlug(iconSlug), size: 18, color: color),
    );
  }
}

class _UsedRing extends StatelessWidget {
  final double? usedPct;
  final Color color;
  /// Cuando el estado es "excedido con límite 0" (usedPct=null pero
  /// gastó plata sobre presupuesto = 0), forzamos el ring lleno en
  /// negativo para no mostrar un círculo vacío que parezca "sin datos".
  final bool forceFilled;
  const _UsedRing({
    required this.usedPct,
    required this.color,
    this.forceFilled = false,
  });

  @override
  Widget build(BuildContext context) {
    final double ringValue;
    if (usedPct != null) {
      ringValue = (usedPct! / 100).clamp(0.0, 1.0);
    } else {
      ringValue = forceFilled ? 1.0 : 0.0;
    }
    return SizedBox(
      width: 72,
      height: 72,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.expand(
            child: CircularProgressIndicator(
              value: ringValue,
              strokeWidth: 6,
              backgroundColor: FincoreColors.border,
              color: color,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                usedPct == null ? '—' : '${usedPct!.toStringAsFixed(0)}%',
                style: TextStyle(
                  color: color,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Text(
                'usado',
                style: TextStyle(
                  color: FincoreColors.textSubtle,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MoneyRow extends StatelessWidget {
  final String label;
  final double amount;
  final Color amountColor;
  const _MoneyRow({
    required this.label,
    required this.amount,
    required this.amountColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: FincoreColors.textMuted,
            fontSize: 13,
          ),
        ),
        Text(
          formatAmount(amount),
          style: TextStyle(
            color: amountColor,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _NoSpendBadge extends StatelessWidget {
  const _NoSpendBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: FincoreColors.positive.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Text(
        'Sin gasto',
        style: TextStyle(
          color: FincoreColors.positive,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _OverBadge extends StatelessWidget {
  final double overBy;
  const _OverBadge({required this.overBy});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: FincoreColors.negative.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: FincoreColors.negative.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: FincoreColors.negative, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Excedido por ${formatAmount(overBy)}',
              style: const TextStyle(
                color: FincoreColors.negative,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
