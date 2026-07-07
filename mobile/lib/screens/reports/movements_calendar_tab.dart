import 'package:fincore/app_dependencies.dart';
import 'package:fincore/data/entries_filters.dart';
import 'package:fincore/data/reports.dart';
import 'package:fincore/theme/fincore_colors.dart';
import 'package:fincore/widgets/base_card.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:table_calendar/table_calendar.dart';

/// Tab "Calendario" del reporte. Sprint
/// `flutter-reports-movements-calendar-v1`.
///
/// Muestra un calendario mensual con hasta 3 marcadores por día según los
/// tipos de movimiento que hubo (verde ingreso, rojo gasto, azul movimiento
/// interno; RN-CAL01). Tap en un día abre `/entries` con filtro custom
/// `from = to = ese día` (RN-CAL05). Navegación mes anterior/siguiente
/// con el header nativo de `TableCalendar`.
class MovementsCalendarTab extends StatefulWidget {
  const MovementsCalendarTab({super.key});

  @override
  State<MovementsCalendarTab> createState() => _MovementsCalendarTabState();
}

class _MovementsCalendarTabState extends State<MovementsCalendarTab> {
  late DateTime _focusedMonth;
  DateTime? _selectedDay;
  Stream<Map<DateTime, DayActivity>>? _stream;
  // A2 del quality review: `firstDay`/`lastDay` se fijan una vez al montar
  // a partir de `DateTime.now()`. Si dependieran de `_focusedMonth`, la
  // ventana ±10 años se desplazaría con la navegación y el rango sería
  // efectivamente infinito (contradicción con el comentario declarado).
  late final DateTime _firstDay;
  late final DateTime _lastDay;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _focusedMonth = DateTime(now.year, now.month, 1);
    // RN-CAL06: al abrir la tab, selectedDay = hoy (siempre en el mes en
    // foco al init, porque _focusedMonth se acaba de setear a este mes).
    _selectedDay = DateTime(now.year, now.month, now.day);
    _firstDay = DateTime(now.year - 10, 1, 1);
    _lastDay = DateTime(now.year + 10, 12, 31);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Cache del stream: el `customSelect` de drift construye un stream nuevo
    // en cada llamada; sin cache, el build recreaba el stream en cada frame
    // y los widget tests con pumpAndSettle no asentaban. Mismo patrón que
    // los otros tabs por categoría del reporte.
    _stream ??= _buildStream();
  }

  Stream<Map<DateTime, DayActivity>> _buildStream() {
    final deps = AppDependencies.of(context);
    return deps.reportsService.movementsByDay(monthAnchor: _focusedMonth);
  }

  // A1 del quality review: callback público para el botón "Reintentar" del
  // `_ErrorState`. Fuerza la recreación del stream para volver a intentar
  // la query si el error fue transitorio.
  void _retryStream() {
    setState(() {
      _stream = _buildStream();
    });
  }

  void _onPageChanged(DateTime newFocusedMonth) {
    final normalized = DateTime(
      newFocusedMonth.year,
      newFocusedMonth.month,
      1,
    );
    setState(() {
      _focusedMonth = normalized;
      // Al cambiar de mes, deseleccionar el día previo (queda fuera de foco).
      _selectedDay = null;
      _stream = _buildStream();
    });
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    final normalizedDay = DateTime(
      selectedDay.year,
      selectedDay.month,
      selectedDay.day,
    );
    // A3 del quality review: si el usuario tapea un "outside day"
    // (día visible del mes previo/siguiente que renderiza table_calendar
    // por relleno), sincronizamos `_focusedMonth` para evitar la
    // divergencia entre header (mes anterior) y día seleccionado (mes
    // vecino) al volver a la tab. Mismo tipo de asimetría que R9 pero en
    // la callback opuesta.
    final crossedMonth = normalizedDay.year != _focusedMonth.year ||
        normalizedDay.month != _focusedMonth.month;
    setState(() {
      _selectedDay = normalizedDay;
      if (crossedMonth) {
        _focusedMonth = DateTime(normalizedDay.year, normalizedDay.month, 1);
        _stream = _buildStream();
      }
    });
    // Drill-down: navega a /entries con filtro custom del día.
    // RN-CAL05 + RF-006. El deep link reusa el mismo mecanismo que los
    // otros tabs (forCategoryBucket, forIncomeBucket).
    final filter = EntriesFilters.forDay(day: normalizedDay);
    context.push(filter.toDeepLink());
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<DateTime, DayActivity>>(
      stream: _stream,
      builder: (context, snap) {
        if (snap.hasError) {
          return _ErrorState(onRetry: _retryStream);
        }
        if (!snap.hasData) {
          return const _LoadingState();
        }
        final activity = snap.data!;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BaseCard(
                padding: const EdgeInsets.all(8),
                child: TableCalendar<DayActivity>(
                  locale: 'es_MX',
                  // Rango amplio ±10 años del mes de apertura del tab.
                  // Cacheado en initState (A2 del quality review); no
                  // se desplaza con la navegación mensual.
                  firstDay: _firstDay,
                  lastDay: _lastDay,
                  focusedDay: _focusedMonth,
                  selectedDayPredicate: (day) {
                    final s = _selectedDay;
                    if (s == null) return false;
                    return day.year == s.year &&
                        day.month == s.month &&
                        day.day == s.day;
                  },
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
                    selectedDecoration: const BoxDecoration(
                      color: FincoreColors.accent,
                      shape: BoxShape.circle,
                    ),
                    selectedTextStyle: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                    markersMaxCount: 3,
                    markersAlignment: Alignment.bottomCenter,
                  ),
                  calendarBuilders: CalendarBuilders(
                    markerBuilder: (context, day, events) {
                      // RN-CAL01: hasta 3 puntos según kinds presentes.
                      // events viene vacío porque no usamos eventLoader —
                      // resolvemos por el Map cacheado por closure.
                      final normalized = DateTime(day.year, day.month, day.day);
                      final data = activity[normalized];
                      if (data == null || !data.hasAny) return null;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (data.hasIncome) _dot(FincoreColors.positive),
                            if (data.hasSpending) _dot(FincoreColors.negative),
                            if (data.hasInternal) _dot(FincoreColors.accent),
                          ],
                        ),
                      );
                    },
                  ),
                  onPageChanged: _onPageChanged,
                  onDaySelected: _onDaySelected,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _dot(Color color) {
    return Container(
      width: 5,
      height: 5,
      margin: const EdgeInsets.symmetric(horizontal: 1),
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
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
              'Error al cargar el calendario.',
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
