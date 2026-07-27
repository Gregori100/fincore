import 'package:fincore/app_dependencies.dart';
import 'package:fincore/data/daos/weekly_budgets_dao.dart';
import 'package:fincore/data/database.dart';
import 'package:fincore/theme/fincore_colors.dart';
import 'package:fincore/utils/money.dart';
import 'package:fincore/widgets/base_card.dart';
import 'package:fincore/widgets/error_snackbar.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

/// Vista calendario del módulo de presupuestos semanales (sprint
/// `flutter-weekly-budgets-v1`).
///
/// Muestra un mes completo con un punto debajo del día donde arranca un
/// presupuesto (`week_start_date`). Si hay 2 o más presupuestos con la
/// misma fecha de arranque (multi-plan), se muestran 2 puntos. Reusa
/// `table_calendar` (ya pineado en `pubspec.yaml` para el reporte
/// "Calendario" de movimientos) en vez de armar un grid manual, siguiendo
/// el mismo patrón que `lib/screens/reports/movements_calendar_tab.dart`.
///
/// A diferencia del tab de reportes, aquí no hace falta re-consultar por
/// mes: `weeklyBudgetsDao.watchAll()` trae todos los presupuestos (son
/// pocos por diseño — un usuario single-user no acumula miles) y se
/// agrupan en memoria por día normalizado.
class BudgetCalendarScreen extends StatefulWidget {
  const BudgetCalendarScreen({super.key});

  @override
  State<BudgetCalendarScreen> createState() => _BudgetCalendarScreenState();
}

class _BudgetCalendarScreenState extends State<BudgetCalendarScreen> {
  late DateTime _focusedMonth;
  Stream<List<WeeklyBudgetRow>>? _stream;
  // Rango amplio ±10 años fijado una sola vez al montar, mismo criterio que
  // `MovementsCalendarTab`: si dependiera de `_focusedMonth` el rango se
  // desplazaría con la navegación en vez de quedar fijo.
  late final DateTime _firstDay;
  late final DateTime _lastDay;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _focusedMonth = DateTime(now.year, now.month, 1);
    _firstDay = DateTime(now.year - 10, 1, 1);
    _lastDay = DateTime(now.year + 10, 12, 31);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Cache del stream: sin esto, cada build recrea el stream y
    // `pumpAndSettle` de los widget tests no asienta.
    _stream ??= AppDependencies.of(context).weeklyBudgetsDao.watchAll();
  }

  Map<DateTime, List<WeeklyBudgetRow>> _groupByDay(
    List<WeeklyBudgetRow> budgets,
  ) {
    final map = <DateTime, List<WeeklyBudgetRow>>{};
    for (final budget in budgets) {
      final key = DateTime(
        budget.weekStartDate.year,
        budget.weekStartDate.month,
        budget.weekStartDate.day,
      );
      map.putIfAbsent(key, () => []).add(budget);
    }
    return map;
  }

  void _onDaySelected(
    DateTime selectedDay,
    Map<DateTime, List<WeeklyBudgetRow>> byDay,
  ) {
    final key = DateTime(selectedDay.year, selectedDay.month, selectedDay.day);
    final budgets = byDay[key] ?? const <WeeklyBudgetRow>[];
    if (budgets.isEmpty) {
      _openCreateForDaySheet(key);
    } else if (budgets.length == 1) {
      context.push('/budgets/${budgets.first.id}');
    } else {
      _openMultiPickerSheet(budgets);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Calendario')),
      body: StreamBuilder<List<WeeklyBudgetRow>>(
        stream: _stream,
        builder: (context, snap) {
          if (snap.hasError) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) showErrorSnackbar(context, snap.error!);
            });
          }
          if (!snap.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: FincoreColors.accent),
            );
          }
          final byDay = _groupByDay(snap.data!);
          return Padding(
            padding: const EdgeInsets.all(16),
            child: BaseCard(
              padding: const EdgeInsets.all(8),
              child: TableCalendar<WeeklyBudgetRow>(
                locale: 'es_MX',
                firstDay: _firstDay,
                lastDay: _lastDay,
                focusedDay: _focusedMonth,
                availableCalendarFormats: const {
                  CalendarFormat.month: 'Mes',
                },
                headerStyle: const HeaderStyle(
                  formatButtonVisible: false,
                  titleCentered: true,
                  titleTextStyle: TextStyle(
                    color: FincoreColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                  leftChevronIcon: Icon(
                    Icons.chevron_left,
                    color: FincoreColors.accent,
                  ),
                  rightChevronIcon: Icon(
                    Icons.chevron_right,
                    color: FincoreColors.accent,
                  ),
                ),
                daysOfWeekStyle: const DaysOfWeekStyle(
                  weekdayStyle: TextStyle(
                    color: FincoreColors.textSubtle,
                    fontWeight: FontWeight.w500,
                  ),
                  weekendStyle: TextStyle(
                    color: FincoreColors.textSubtle,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                calendarStyle: CalendarStyle(
                  outsideDaysVisible: true,
                  defaultTextStyle: const TextStyle(
                    color: FincoreColors.textPrimary,
                  ),
                  weekendTextStyle: const TextStyle(
                    color: FincoreColors.textPrimary,
                  ),
                  outsideTextStyle: TextStyle(
                    color: FincoreColors.textSubtle.withValues(alpha: 0.6),
                  ),
                  todayDecoration: BoxDecoration(
                    color: FincoreColors.accent.withValues(alpha: 0.25),
                    shape: BoxShape.circle,
                  ),
                  todayTextStyle: const TextStyle(
                    color: FincoreColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                  markersMaxCount: 2,
                  markersAlignment: Alignment.bottomCenter,
                ),
                calendarBuilders: CalendarBuilders(
                  markerBuilder: (context, day, events) {
                    final key = DateTime(day.year, day.month, day.day);
                    final budgets = byDay[key];
                    if (budgets == null || budgets.isEmpty) return null;
                    final dotCount = budgets.length >= 2 ? 2 : 1;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(dotCount, (_) => _dot()),
                      ),
                    );
                  },
                ),
                onPageChanged: (focusedDay) {
                  setState(() {
                    _focusedMonth =
                        DateTime(focusedDay.year, focusedDay.month, 1);
                  });
                },
                onDaySelected: (selectedDay, focusedDay) =>
                    _onDaySelected(selectedDay, byDay),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _dot() {
    return Container(
      width: 4,
      height: 4,
      margin: const EdgeInsets.symmetric(horizontal: 1),
      decoration: const BoxDecoration(
        color: FincoreColors.accent,
        shape: BoxShape.circle,
      ),
    );
  }

  // ===========================================================================
  // Bottom sheets — multi-plan y creación desde día vacío
  // ===========================================================================

  Future<void> _openMultiPickerSheet(List<WeeklyBudgetRow> budgets) async {
    final deps = AppDependencies.of(context);
    final chosen = await showModalBottomSheet<WeeklyBudgetRow>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      backgroundColor: FincoreColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Elige un presupuesto',
                  style: TextStyle(
                    color: FincoreColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                for (final budget in budgets)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      budget.label,
                      style: const TextStyle(color: FincoreColors.textPrimary),
                    ),
                    subtitle: StreamBuilder<int>(
                      stream: deps.weeklyBudgetsDao
                          .watchBudgetBalance(budget.id),
                      builder: (context, snap) {
                        if (!snap.hasData) {
                          return const Text(
                            'Cargando…',
                            style: TextStyle(color: FincoreColors.textSubtle),
                          );
                        }
                        final balance = snap.data!;
                        final String label;
                        final Color color;
                        if (balance > 0) {
                          label = 'Sobra ${formatCents(balance)}';
                          color = FincoreColors.positive;
                        } else if (balance < 0) {
                          label = 'Faltan ${formatCents(balance.abs())}';
                          color = FincoreColors.negative;
                        } else {
                          label = 'En equilibrio';
                          color = FincoreColors.textMuted;
                        }
                        return Text(
                          label,
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w600,
                          ),
                        );
                      },
                    ),
                    onTap: () => Navigator.of(sheetContext).pop(budget),
                  ),
              ],
            ),
          ),
        );
      },
    );
    if (chosen == null || !mounted) return;
    context.push('/budgets/${chosen.id}');
  }

  Future<void> _openCreateForDaySheet(DateTime day) async {
    final fmt = DateFormat('EEEE d MMMM', 'es_MX');
    final dayLabel = _capitalize(fmt.format(day));
    final shouldCreate = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      backgroundColor: FincoreColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Sin presupuestos el $dayLabel',
                  style: const TextStyle(
                    color: FincoreColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => Navigator.of(sheetContext).pop(true),
                  icon: const Icon(Icons.add),
                  label: const Text('Crear presupuesto para esta fecha'),
                  style: FilledButton.styleFrom(
                    backgroundColor: FincoreColors.accent,
                    foregroundColor: FincoreColors.canvas,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (shouldCreate != true || !mounted) return;

    final deps = AppDependencies.of(context);
    final label = await deps.weeklyBudgetsDao.generateAutoLabel(day);
    if (!mounted) return;

    try {
      final id = await deps.weeklyBudgetsDao.createBudget(
        weekStartDate: day,
        label: label,
      );
      if (mounted) context.push('/budgets/$id');
    } on WeeklyBudgetsDaoError catch (e) {
      if (mounted) showWarningSnackbar(context, e.message);
    } catch (e) {
      if (mounted) showErrorSnackbar(context, e);
    }
  }

}

/// Capitaliza la primera letra de un string formateado por `DateFormat`
/// (`intl` en español devuelve minúsculas: "viernes 17 julio").
String _capitalize(String s) =>
    s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
