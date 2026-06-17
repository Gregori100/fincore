import 'package:intl/intl.dart';

/// Formatea un monto como moneda en es_MX. Usado en saldos, totales y badges.
///
/// - `showSign: true` antepone `+` cuando el valor es positivo (útil para
///   diferenciar ingresos de gastos en listas).
/// - Negativos siempre vienen con `-` por convención.
String formatAmount(num value, {bool showSign = false}) {
  final formatter = NumberFormat.currency(locale: 'es_MX', symbol: r'$');
  final formatted = formatter.format(value.abs());
  if (value < 0) return '-$formatted';
  if (showSign && value > 0) return '+$formatted';
  return formatted;
}

/// Versión compacta para columnas estrechas: `$1.2K`, `$3.4M`. Sin decimales.
String formatAmountCompact(num value) {
  final formatter = NumberFormat.compactCurrency(locale: 'es_MX', symbol: r'$');
  return formatter.format(value);
}
