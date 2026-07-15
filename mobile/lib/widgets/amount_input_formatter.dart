import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// TextInputFormatter para inputs de monto que:
///
/// - Acepta solo dígitos, `.` y `,`.
/// - Interpreta el ÚLTIMO separador `.` o `,` como decimal (tolerante con
///   locale mexicano que a veces usa coma decimal).
/// - Ignora los separadores anteriores al último (miles).
/// - Formatea la parte entera con separadores de miles (`1000` → `1,000`).
/// - Máximo 2 decimales. Estados con más decimales se rechazan.
/// - Estados intermedios válidos permitidos: `1.`, `0.5`, `1,` (aceptando
///   que el usuario está tipeando el decimal).
///
/// El cursor queda al final del texto formateado (compromiso vs cálculo
/// exacto de posición equivalente en el nuevo string).
///
/// Sprint `flutter-entry-form-redesign-v1` (RF-002).
class AmountInputFormatter extends TextInputFormatter {
  static final NumberFormat _thousandsFormat = NumberFormat('#,##0', 'en_US');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue;

    // Sanitizar: solo dígitos, `.` y `,`.
    final sanitized = newValue.text.replaceAll(RegExp(r'[^\d.,]'), '');
    if (sanitized.isEmpty) return const TextEditingValue();

    // Detectar el separador decimal: el ÚLTIMO `.` o `,` que aparezca.
    final lastComma = sanitized.lastIndexOf(',');
    final lastDot = sanitized.lastIndexOf('.');
    String integerPart;
    String decimalPart;
    bool hasDecimalIndicator;

    if (lastComma > lastDot) {
      // Coma es decimal.
      integerPart = sanitized.substring(0, lastComma).replaceAll(RegExp(r'[,.]'), '');
      decimalPart = sanitized.substring(lastComma + 1).replaceAll(RegExp(r'[,.]'), '');
      hasDecimalIndicator = true;
    } else if (lastDot > lastComma) {
      // Punto es decimal.
      integerPart = sanitized.substring(0, lastDot).replaceAll(RegExp(r'[,.]'), '');
      decimalPart = sanitized.substring(lastDot + 1).replaceAll(RegExp(r'[,.]'), '');
      hasDecimalIndicator = true;
    } else {
      // Sin separador — entero puro.
      integerPart = sanitized.replaceAll(RegExp(r'[,.]'), '');
      decimalPart = '';
      hasDecimalIndicator = false;
    }

    // Rechazar más de 2 decimales.
    if (decimalPart.length > 2) return oldValue;

    // Construir el output formateado.
    String formatted;
    if (integerPart.isEmpty && !hasDecimalIndicator) {
      formatted = '';
    } else if (integerPart.isEmpty && hasDecimalIndicator) {
      // Ej: usuario tipeó ".5" — preservar como "0.5" para no romper el intento.
      formatted = '0.$decimalPart';
    } else {
      final intValue = int.tryParse(integerPart);
      if (intValue == null) return oldValue;
      formatted = _thousandsFormat.format(intValue);
      if (hasDecimalIndicator) {
        formatted += '.$decimalPart';
      }
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

/// Convierte un string formateado (`"1,234.56"`) a `double` para persistir.
/// Retorna `null` si el string no es parseable.
///
/// Se usa en `entry_form_screen._submit()` al leer el `_amountCtrl.text`.
double? parseFormattedAmount(String formatted) {
  final normalized = formatted.replaceAll(',', '').trim();
  if (normalized.isEmpty) return null;
  return double.tryParse(normalized);
}

/// Formatea un `double` para hidratar el TextField en modo edit.
/// Ejemplos: `1000` → `"1,000"`, `1500.5` → `"1,500.50"`.
///
/// Se usa en `entry_form_screen._bootstrap()` cuando se carga un entry existente.
String formatAmountForInput(double amount) {
  final rounded = (amount * 100).round() / 100;
  final intPart = rounded.truncate();
  final decimals = ((rounded - intPart) * 100).round().abs();
  final intFormatted = AmountInputFormatter._thousandsFormat.format(intPart);
  if (decimals == 0) return intFormatted;
  return '$intFormatted.${decimals.toString().padLeft(2, '0')}';
}
