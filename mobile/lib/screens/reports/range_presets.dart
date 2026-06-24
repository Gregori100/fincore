/// Presets de rango temporal disponibles para los reportes.
///
/// El extract de `spending_by_category_tab.dart` se hizo para permitir tests
/// unitarios del cálculo de rangos (M4 del quality review v1) y para
/// preparar reutilización cuando se sumen más reportes con filtros
/// temporales (cashflow mensual, saldo a fecha, etc.).
///
/// - `thisMonth`: día 1 al último día del mes calendario corriente (default).
/// - `lastMonth`: día 1 al último día del mes anterior.
/// - `thisYear`: 1 enero al 31 diciembre del año corriente.
/// - `custom`: rango libre editable por el usuario via DatePicker. Cuando se
///   pide computar el rango para `custom`, los parámetros `currentFrom` y
///   `currentTo` actúan como valores actuales.
enum ReportRangePreset { thisMonth, lastMonth, thisYear, custom }

extension ReportRangePresetLabel on ReportRangePreset {
  String get label => switch (this) {
        ReportRangePreset.thisMonth => 'Este mes',
        ReportRangePreset.lastMonth => 'Mes pasado',
        ReportRangePreset.thisYear => 'Año',
        ReportRangePreset.custom => 'Custom',
      };
}

/// Calcula el par `(from, to)` para un preset dado tomando como referencia
/// `ref` (típicamente `DateTime.now()`).
///
/// El `to` siempre cierra al final del día (23:59:59.999) para que el rango
/// inclusivo (RN-R05) capture entries hasta el último milisegundo del día
/// final.
///
/// Para `ReportRangePreset.custom`, requiere `currentFrom` y `currentTo`
/// porque el rango se mantiene tal cual estaba (el usuario edita
/// manualmente vía DatePicker).
///
/// Casos manejados correctamente por el constructor `DateTime` de Dart:
/// - Enero + `lastMonth` → `DateTime(year, 0, 1)` se interpreta como
///   diciembre del año anterior.
/// - `DateTime(year, month + 1, 0)` se interpreta como último día del mes
///   `month` (truco del día 0 que rebobina al mes anterior).
(DateTime, DateTime) reportRangeForPreset(
  ReportRangePreset preset,
  DateTime ref, {
  DateTime? currentFrom,
  DateTime? currentTo,
}) {
  switch (preset) {
    case ReportRangePreset.thisMonth:
      final from = DateTime(ref.year, ref.month, 1);
      final to = DateTime(ref.year, ref.month + 1, 0, 23, 59, 59, 999);
      return (from, to);
    case ReportRangePreset.lastMonth:
      final from = DateTime(ref.year, ref.month - 1, 1);
      final to = DateTime(ref.year, ref.month, 0, 23, 59, 59, 999);
      return (from, to);
    case ReportRangePreset.thisYear:
      return (
        DateTime(ref.year, 1, 1),
        DateTime(ref.year, 12, 31, 23, 59, 59, 999),
      );
    case ReportRangePreset.custom:
      assert(
        currentFrom != null && currentTo != null,
        'ReportRangePreset.custom requiere currentFrom y currentTo',
      );
      return (currentFrom!, currentTo!);
  }
}
