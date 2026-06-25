/// Presets de rango temporal compartidos por reportes y filtros de movimientos.
///
/// Extraído de `lib/screens/reports/range_presets.dart` (sprint
/// `flutter-movements-filters-v1`, RF-018) al promover los presets a
/// reutilización fuera del feature de reportes: ahora también los consume el
/// panel de filtros de `/entries` y futuros reportes con filtro temporal
/// (cashflow mensual, saldo a fecha).
///
/// - `thisMonth`: día 1 al último día del mes calendario corriente (default).
/// - `lastMonth`: día 1 al último día del mes anterior.
/// - `thisYear`: 1 enero al 31 diciembre del año corriente.
/// - `custom`: rango libre editable por el usuario via DatePicker. Cuando se
///   pide computar el rango para `custom`, los parámetros `currentFrom` y
///   `currentTo` actúan como valores actuales.
enum DateRangePreset { thisMonth, lastMonth, thisYear, custom }

extension DateRangePresetLabel on DateRangePreset {
  String get label => switch (this) {
        DateRangePreset.thisMonth => 'Este mes',
        DateRangePreset.lastMonth => 'Mes pasado',
        DateRangePreset.thisYear => 'Año',
        DateRangePreset.custom => 'Custom',
      };

  /// Slug estable para serializar a query params del router. Independiente
  /// del label visual (que puede cambiar por traducción).
  String get slug => switch (this) {
        DateRangePreset.thisMonth => 'this_month',
        DateRangePreset.lastMonth => 'last_month',
        DateRangePreset.thisYear => 'this_year',
        DateRangePreset.custom => 'custom',
      };
}

/// Parsea un slug del query param a un `DateRangePreset`. Retorna null si
/// el slug no matchea ninguno conocido (caller decide el fallback).
DateRangePreset? dateRangePresetFromSlug(String? slug) {
  switch (slug) {
    case 'this_month':
      return DateRangePreset.thisMonth;
    case 'last_month':
      return DateRangePreset.lastMonth;
    case 'this_year':
      return DateRangePreset.thisYear;
    case 'custom':
      return DateRangePreset.custom;
    default:
      return null;
  }
}

/// Calcula el par `(from, to)` para un preset dado tomando como referencia
/// `ref` (típicamente `DateTime.now()`).
///
/// El `to` siempre cierra al final del día (23:59:59.999) para que el rango
/// inclusivo capture entries hasta el último milisegundo del día final
/// (consistente con RN-R05 del sprint `flutter-reports-v1` y RN-M04 del
/// sprint `flutter-movements-filters-v1`).
///
/// Para `DateRangePreset.custom`, requiere `currentFrom` y `currentTo`
/// porque el rango se mantiene tal cual estaba (el usuario edita
/// manualmente vía DatePicker).
///
/// Casos manejados correctamente por el constructor `DateTime` de Dart:
/// - Enero + `lastMonth` → `DateTime(year, 0, 1)` se interpreta como
///   diciembre del año anterior.
/// - `DateTime(year, month + 1, 0)` se interpreta como último día del mes
///   `month` (truco del día 0 que rebobina al mes anterior).
(DateTime, DateTime) dateRangeForPreset(
  DateRangePreset preset,
  DateTime ref, {
  DateTime? currentFrom,
  DateTime? currentTo,
}) {
  switch (preset) {
    case DateRangePreset.thisMonth:
      final from = DateTime(ref.year, ref.month, 1);
      final to = DateTime(ref.year, ref.month + 1, 0, 23, 59, 59, 999);
      return (from, to);
    case DateRangePreset.lastMonth:
      final from = DateTime(ref.year, ref.month - 1, 1);
      final to = DateTime(ref.year, ref.month, 0, 23, 59, 59, 999);
      return (from, to);
    case DateRangePreset.thisYear:
      return (
        DateTime(ref.year, 1, 1),
        DateTime(ref.year, 12, 31, 23, 59, 59, 999),
      );
    case DateRangePreset.custom:
      assert(
        currentFrom != null && currentTo != null,
        'DateRangePreset.custom requiere currentFrom y currentTo',
      );
      return (currentFrom!, currentTo!);
  }
}
