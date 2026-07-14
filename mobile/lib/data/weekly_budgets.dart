// =============================================================================
// Helpers puros de dominio — presupuestos semanales (sprint flutter-weekly-budgets-v1)
// =============================================================================
// Funciones sin BD ni side effects: cálculo de semana sugerida, rango de una
// semana, agrupación de presupuestos por sección (esta semana/próximas/pasadas)
// y balance de un presupuesto. Testeables aisladamente (T026).
//
// Deliberadamente NO importa `package:flutter/material.dart`: este archivo
// vive en `lib/data/` y debe mantenerse desacoplado de Flutter (usa
// `WeekRange` propia en lugar de `DateTimeRange`).

import 'package:fincore/data/database.dart';

/// Rango de fechas [start, endExclusive) que cubre una semana de presupuesto.
///
/// `endExclusive` es exclusivo: el rango cubre exactamente 7 días desde
/// `start` (medianoche local) hasta `start + 7 días` (sin incluir ese día).
class WeekRange {
  final DateTime start;
  final DateTime endExclusive;

  const WeekRange({required this.start, required this.endExclusive});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WeekRange &&
          start == other.start &&
          endExclusive == other.endExclusive);

  @override
  int get hashCode => Object.hash(start, endExclusive);

  @override
  String toString() => 'WeekRange(start: $start, endExclusive: $endExclusive)';
}

/// Secciones en las que se agrupan los presupuestos semanales en la lista.
enum BudgetSection { thisWeek, upcoming, past }

/// Calcula la medianoche local del día de arranque de semana más reciente
/// (o igual a `now`) cuyo `.weekday == weekStartDow`.
///
/// `weekStartDow` usa la convención ISO 8601 de `DateTime.weekday`:
/// 1 = lunes, 2 = martes, ..., 7 = domingo.
///
/// Retrocede desde `now` día por día (máximo 6 días) hasta encontrar el día
/// buscado. Si `now.weekday == weekStartDow`, retorna medianoche del mismo
/// día de `now`.
DateTime suggestedWeekStartDate({
  required DateTime now,
  required int weekStartDow,
}) {
  assert(
    weekStartDow >= 1 && weekStartDow <= 7,
    'weekStartDow debe estar en [1, 7] (ISO 8601), recibido: $weekStartDow',
  );

  final today = DateTime(now.year, now.month, now.day);
  final diff = (today.weekday - weekStartDow) % 7;
  // `%` en Dart puede retornar 0..6 para operandos positivos (weekday y
  // weekStartDow están en [1,7]), así que `diff` ya queda no negativo.
  return today.subtract(Duration(days: diff));
}

/// Retorna el rango [start, start + 7 días) cubierto por una semana de
/// presupuesto que arranca en `weekStartDate`.
WeekRange weekRangeOf(DateTime weekStartDate) {
  return WeekRange(
    start: weekStartDate,
    endExclusive: weekStartDate.add(const Duration(days: 7)),
  );
}

/// Agrupa `budgets` en `thisWeek` / `upcoming` / `past` respecto al arranque
/// de la semana actual (calculado con [suggestedWeekStartDate]).
///
/// - `thisWeek`: `weekStartDate == currentWeekStart`, ordenados ASC.
/// - `upcoming`: `weekStartDate > currentWeekStart`, ordenados ASC.
/// - `past`: `weekStartDate < currentWeekStart`, ordenados DESC (más
///   recientes primero).
///
/// Las 3 keys siempre están presentes en el map retornado, aunque la lista
/// correspondiente esté vacía.
Map<BudgetSection, List<WeeklyBudgetRow>> groupBudgetsByRange({
  required List<WeeklyBudgetRow> budgets,
  required DateTime now,
  required int weekStartDow,
}) {
  final currentWeekStart = suggestedWeekStartDate(
    now: now,
    weekStartDow: weekStartDow,
  );

  final thisWeek = <WeeklyBudgetRow>[];
  final upcoming = <WeeklyBudgetRow>[];
  final past = <WeeklyBudgetRow>[];

  for (final budget in budgets) {
    if (budget.weekStartDate.isAtSameMomentAs(currentWeekStart)) {
      thisWeek.add(budget);
    } else if (budget.weekStartDate.isAfter(currentWeekStart)) {
      upcoming.add(budget);
    } else {
      past.add(budget);
    }
  }

  thisWeek.sort((a, b) => a.weekStartDate.compareTo(b.weekStartDate));
  upcoming.sort((a, b) => a.weekStartDate.compareTo(b.weekStartDate));
  past.sort((a, b) => b.weekStartDate.compareTo(a.weekStartDate));

  return {
    BudgetSection.thisWeek: thisWeek,
    BudgetSection.upcoming: upcoming,
    BudgetSection.past: past,
  };
}

/// Balance de un presupuesto: Σ ingresos − Σ gastos.
///
/// Ignora defensivamente cualquier item con `kind` distinto de
/// `'income'`/`'expense'` (no debería ocurrir dado que el DAO valida el
/// kind al crear/editar, pero este helper no depende de esa garantía).
double calculateBalance(List<WeeklyBudgetItemRow> items) {
  var balance = 0.0;
  for (final item in items) {
    if (item.kind == 'income') {
      balance += item.amount;
    } else if (item.kind == 'expense') {
      balance -= item.amount;
    }
  }
  return balance;
}
