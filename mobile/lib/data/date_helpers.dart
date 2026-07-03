/// Helper de fechas usado por reportes que trabajan con días del mes
/// (día de corte, día de pago de tarjetas). Sprint
/// `flutter-reports-credit-cards-v1`.
library;

/// Retorna la próxima ocurrencia del [targetDay] a partir de [today]:
///
/// - Si `today.day < targetDay`, devuelve el mismo mes.
/// - Si `today.day == targetDay`, devuelve **hoy** (badge "Hoy" en la UI —
///   RN-CC04 / CB-04 del sprint).
/// - Si `today.day > targetDay`, devuelve el mes siguiente.
/// - Si el mes destino no tiene ese día (ej: `targetDay=31` en abril,
///   `targetDay=29` en febrero no bisiesto), se clampa al último día del
///   mes destino. Mismo patrón que dogear y el backend legacy.
///
/// Precondición: `1 <= targetDay <= 31`. Si se pasa fuera de rango, se
/// clampa a `[1, 31]` sin lanzar (mantener el helper resiliente).
DateTime nextOccurrenceOfDay(DateTime today, int targetDay) {
  final normalized = targetDay < 1 ? 1 : (targetDay > 31 ? 31 : targetDay);

  int year = today.year;
  int month = today.month;
  final daysInCurrentMonth = _daysInMonth(year, month);
  // Clampear el target al último día del mes actual (para el caso donde el
  // mes actual no tiene ese día — ej: target=31 en abril → 30 abril).
  final targetInCurrentMonth =
      normalized > daysInCurrentMonth ? daysInCurrentMonth : normalized;
  // Avanzar al mes siguiente solo si la ocurrencia clampada YA pasó respecto
  // a `today`. Antes había un bug: si el target no existía en el mes actual
  // (ej: `today=15 feb, target=31`) avanzábamos aunque el 29 de febrero
  // todavía fuera futuro. Ahora comparamos contra la fecha efectivamente
  // clampada dentro del mes.
  if (today.day > targetInCurrentMonth) {
    month += 1;
    if (month > 12) {
      month = 1;
      year += 1;
    }
    final daysInTargetMonth = _daysInMonth(year, month);
    final day =
        normalized > daysInTargetMonth ? daysInTargetMonth : normalized;
    return DateTime(year, month, day);
  }

  return DateTime(year, month, targetInCurrentMonth);
}

int _daysInMonth(int year, int month) {
  // Truco: día 0 del mes siguiente = último día del mes actual.
  return DateTime(year, month + 1, 0).day;
}

/// Retorna el rango del mes calendario local que contiene [anchor]:
/// `from` = día 1 a las 00:00:00, `to` = último día del mes a las
/// 23:59:59.999. Usado por el sprint `flutter-budgets-v1` para acotar
/// el `spent` del mes en curso en el reporte de presupuestos.
({DateTime from, DateTime to}) monthRange(DateTime anchor) {
  final from = DateTime(anchor.year, anchor.month, 1);
  final lastDay = _daysInMonth(anchor.year, anchor.month);
  final to = DateTime(
    anchor.year,
    anchor.month,
    lastDay,
    23,
    59,
    59,
    999,
  );
  return (from: from, to: to);
}
