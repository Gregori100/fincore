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
    var sanitized = newValue.text.replaceAll(RegExp(r'[^\d.,]'), '');
    if (sanitized.isEmpty) return const TextEditingValue();

    // Interpretación de la coma (2026-07-15 hotfix):
    // Sin este bloque, al tipear el 5to dígito `12345` (que viene
    // formateado como `1,2345`), el formatter interpretaba la coma como
    // decimal con 4 chars y rechazaba el cambio → aparente límite de
    // 4 dígitos. Igual, al borrar decimales de `6,666.66` → `6,666.` →
    // `6,666`, la coma se re-leía como decimal con 3 chars → cursor
    // tirado sin poder seguir borrando.
    //
    // Heurística:
    // - Si `oldValue.text` ya tenía comas como separador de miles
    //   (matches `^\d{1,3}(,\d{3})+$` o tiene coma + punto), asumimos que
    //   TODAS las comas del newValue son miles → eliminar.
    // - En otro caso, si hay UNA coma con 1-2 dígitos después y sin
    //   puntos, la coma es decimal MX (`1,50` → 1.50) → normalizar a punto.
    // - En cualquier otro caso, coma de miles → eliminar.
    final commaCount = ','.allMatches(sanitized).length;
    final dotCount = '.'.allMatches(sanitized).length;
    final oldHasThousands = RegExp(r'^\d{1,3}(,\d{3})+(\.\d*)?$')
        .hasMatch(oldValue.text.trim());
    if (oldHasThousands || commaCount > 1 || dotCount > 0) {
      // Coma(s) son de miles → eliminar todas.
      sanitized = sanitized.replaceAll(',', '');
    } else if (commaCount == 1) {
      final commaIdx = sanitized.indexOf(',');
      final afterComma = sanitized.length - commaIdx - 1;
      if (afterComma >= 1 && afterComma <= 2) {
        // Coma decimal MX → normalizar a punto.
        sanitized = sanitized.replaceFirst(',', '.');
      } else {
        // Coma sin contexto decimal → miles.
        sanitized = sanitized.replaceAll(',', '');
      }
    }

    // Ahora el único separador posible es `.` (decimal).
    final lastDot = sanitized.lastIndexOf('.');
    String integerPart;
    String decimalPart;
    bool hasDecimalIndicator;

    if (lastDot >= 0) {
      // Puntos previos al último se ignoran (edge legacy `1.2.3` → `12.3`).
      integerPart = sanitized.substring(0, lastDot).replaceAll('.', '');
      decimalPart = sanitized.substring(lastDot + 1).replaceAll('.', '');
      hasDecimalIndicator = true;
    } else {
      integerPart = sanitized;
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
