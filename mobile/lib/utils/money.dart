import 'package:intl/intl.dart';

/// Sprint flutter-integer-cents-v1: helpers de conversión y formateo de
/// montos monetarios expresados en centavos (`int`).
///
/// Convención del proyecto (RN-IC-01): todos los montos monetarios se
/// manejan como `int` en centavos. `double` queda reservado para ratios
/// 0-1 (interest_rate, minimum_payment_pct, minimum_capital_pct).
///
/// - `parseCents(String)`: parsea input del usuario a centavos. Acepta
///   ambos separadores decimales (`.` y `,`) y separadores de miles
///   (`,` y `.`) para tolerar hábitos de tipeo. Rechaza > 2 decimales.
/// - `formatCents(int)`: formatea centavos como string "MX$1,234.56".
///   Reemplaza al `formatAmount(num)` legacy con firma equivalente.
/// - `centsFromDouble(double)`: convierte un double legacy (backup
///   v1/v2, código pre-migración) a centavos con `round`. Nunca truncar.
/// - `centsToDouble(int)`: convierte centavos a double con 2 decimales.
///   Solo para compat con formatos externos que esperan double.

/// Parsea input del usuario a centavos. Acepta:
/// - "1500" → 150000
/// - "1500.50" → 150050
/// - "1500,50" → 150050
/// - "1,500.75" → 150075
/// - "1.500,75" → 150075 (formato europeo)
/// - "$1,500.75" → 150075 (símbolo $ tolerado)
/// - "  1500  " → 150000 (whitespace tolerado)
///
/// Rechaza:
/// - Más de 2 decimales ("1500.501" → throw)
/// - Negativos ("-100" → throw)
/// - Vacío o solo whitespace
/// - Caracteres no numéricos (letras, símbolos raros)
/// - NaN, Infinity
///
/// Throws [FormatException] con mensaje descriptivo en cualquier caso
/// inválido.
int parseCents(String input) {
  final cleaned = input.trim().replaceAll(r'$', '').replaceAll(' ', '');
  if (cleaned.isEmpty) {
    throw const FormatException('El monto no puede estar vacío.');
  }
  if (cleaned.startsWith('-')) {
    throw const FormatException('El monto no puede ser negativo.');
  }

  // Determinar separador decimal:
  // - Si hay tanto '.' como ',': el último es el decimal, el otro es
  //   separador de miles.
  // - Si solo hay uno: es decimal si tiene 1-2 dígitos después; si tiene
  //   3 exactos, es ambiguo pero por convención MX es decimal (excepción:
  //   "1,500" con 3 dígitos = mil quinientos con separador de miles).
  String normalized;
  final hasDot = cleaned.contains('.');
  final hasComma = cleaned.contains(',');

  if (hasDot && hasComma) {
    final lastDot = cleaned.lastIndexOf('.');
    final lastComma = cleaned.lastIndexOf(',');
    if (lastDot > lastComma) {
      // "1,500.75" — punto es decimal, coma es miles.
      normalized = cleaned.replaceAll(',', '');
    } else {
      // "1.500,75" — coma es decimal, punto es miles.
      normalized = cleaned.replaceAll('.', '').replaceAll(',', '.');
    }
  } else if (hasComma && !hasDot) {
    // Solo coma. Si los dígitos después de la última coma son 1-2, es
    // decimal. Si son 3 exactos, es separador de miles ("1,500").
    final parts = cleaned.split(',');
    if (parts.length == 2 && parts[1].length <= 2) {
      // "1500,50" o "150,5" — coma decimal.
      normalized = cleaned.replaceAll(',', '.');
    } else {
      // "1,500" o "1,234,567" — coma miles.
      normalized = cleaned.replaceAll(',', '');
    }
  } else {
    // Solo punto o ningún separador. Punto es decimal siempre.
    normalized = cleaned;
  }

  // Ahora `normalized` tiene solo dígitos y máx. un '.'.
  if (!RegExp(r'^[0-9]+(\.[0-9]+)?$').hasMatch(normalized)) {
    throw FormatException(
      'El monto tiene caracteres inválidos: "$input".',
    );
  }

  final dotIndex = normalized.indexOf('.');
  if (dotIndex == -1) {
    // Sin decimales — solo entero → cents = valor * 100.
    final int units;
    try {
      units = int.parse(normalized);
    } on FormatException {
      throw FormatException('El monto es demasiado grande: "$input".');
    }
    return units * 100;
  }

  final wholePart = normalized.substring(0, dotIndex);
  final decimalPart = normalized.substring(dotIndex + 1);
  if (decimalPart.length > 2) {
    throw FormatException(
      'El monto no puede tener más de 2 decimales: "$input".',
    );
  }
  // Padding a exactamente 2 decimales: "5" → "50", "50" → "50".
  final paddedDecimal = decimalPart.padRight(2, '0');
  final int wholeCents;
  final int decimalCents;
  try {
    wholeCents = int.parse(wholePart) * 100;
    decimalCents = int.parse(paddedDecimal);
  } on FormatException {
    throw FormatException('El monto es demasiado grande: "$input".');
  }
  return wholeCents + decimalCents;
}

/// Formatea centavos como string monetario en locale es_MX.
///
/// - `showSign: true` antepone `+` cuando el valor es positivo.
/// - Negativos siempre vienen con `-` por convención.
/// - `omitZeroDecimals: true` omite los decimales cuando son ".00".
String formatCents(int cents, {bool showSign = false, bool omitZeroDecimals = false}) {
  final absValue = cents.abs();
  final wholePart = absValue ~/ 100;
  final decimalPart = absValue % 100;
  final formatter = NumberFormat.decimalPattern('es_MX');
  final wholeStr = formatter.format(wholePart);
  final String body;
  if (omitZeroDecimals && decimalPart == 0) {
    body = '\$$wholeStr';
  } else {
    final decStr = decimalPart.toString().padLeft(2, '0');
    body = '\$$wholeStr.$decStr';
  }
  if (cents < 0) return '-$body';
  if (showSign && cents > 0) return '+$body';
  return body;
}

/// Versión compacta para columnas estrechas: `$1.2K`, `$3.4M`.
/// Devuelve string sin decimales fijos.
String formatCentsCompact(int cents) {
  final dollars = cents / 100.0;
  final formatter = NumberFormat.compactCurrency(locale: 'es_MX', symbol: r'$');
  return formatter.format(dollars);
}

/// Convierte double legacy (backup v1/v2, código pre-migración) a
/// centavos. Usa `round`, nunca `toInt` (que truncaría).
///
/// Ejemplos:
/// - `centsFromDouble(173.77)` → `17377`
/// - `centsFromDouble(173.7699999)` → `17377` (residuo IEEE 754 corregido)
/// - `centsFromDouble(0.005)` → `1` (redondeo bancario estándar; 0.004 → 0)
/// - `centsFromDouble(-100.50)` → `-10050`
int centsFromDouble(double dollars) {
  if (dollars.isNaN || dollars.isInfinite) {
    throw ArgumentError('centsFromDouble: valor no finito: $dollars');
  }
  return (dollars * 100).round();
}

/// Convierte centavos a double con 2 decimales. Solo para compat con
/// formatos externos que esperan double (ej. export a formatos legacy).
///
/// No usar en código de dominio — el dominio se mantiene en `int` cents.
double centsToDouble(int cents) => cents / 100.0;
