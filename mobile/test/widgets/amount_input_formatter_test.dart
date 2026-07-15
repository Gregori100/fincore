import 'package:fincore/widgets/amount_input_formatter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tests del `AmountInputFormatter` (sprint `flutter-entry-form-redesign-v1`).

TextEditingValue _apply(String oldText, String newText) {
  final oldValue = TextEditingValue(
    text: oldText,
    selection: TextSelection.collapsed(offset: oldText.length),
  );
  final newValue = TextEditingValue(
    text: newText,
    selection: TextSelection.collapsed(offset: newText.length),
  );
  return AmountInputFormatter().formatEditUpdate(oldValue, newValue);
}

void main() {
  group('AmountInputFormatter — casos básicos', () {
    test('string vacío devuelve vacío', () {
      expect(_apply('', '').text, '');
    });

    test('un dígito se muestra tal cual', () {
      expect(_apply('', '1').text, '1');
    });

    test('999 sin miles', () {
      expect(_apply('99', '999').text, '999');
    });

    test('1000 se formatea a "1,000"', () {
      expect(_apply('999', '1000').text, '1,000');
    });

    test('12345 se formatea a "12,345"', () {
      expect(_apply('1234', '12345').text, '12,345');
    });

    test('1000000 se formatea a "1,000,000"', () {
      expect(_apply('100000', '1000000').text, '1,000,000');
    });
  });

  group('AmountInputFormatter — decimales', () {
    test('acepta "1." como estado intermedio', () {
      expect(_apply('1', '1.').text, '1.');
    });

    test('"1.5" se preserva', () {
      expect(_apply('1.', '1.5').text, '1.5');
    });

    test('"1.50" se preserva', () {
      expect(_apply('1.5', '1.50').text, '1.50');
    });

    test('"1.505" es rechazado (más de 2 decimales)', () {
      final result = _apply('1.50', '1.505');
      expect(result.text, '1.50');
    });

    test('decimal con coma "1,50" se normaliza a "1.50"', () {
      expect(_apply('', '1,50').text, '1.50');
    });

    test('"0.5" se preserva', () {
      expect(_apply('0', '0.5').text, '0.5');
    });

    test('".5" se convierte en "0.5"', () {
      expect(_apply('', '.5').text, '0.5');
    });

    test('miles + decimales "1000.50" → "1,000.50"', () {
      expect(_apply('1000.5', '1000.50').text, '1,000.50');
    });
  });

  group('AmountInputFormatter — rechazos y sanitización', () {
    test('"1.2.3" (dos puntos) — el último punto es decimal, primero se ignora', () {
      // Comportamiento: "1.2" es el entero (con separador ignorado) y ".3" es decimal
      // Result: "12.3"
      expect(_apply('1.2', '1.2.3').text, '12.3');
    });

    test('paste sucio "\$1,234.56 pesos" queda "1,234.56"', () {
      expect(_apply('', r'$1,234.56 pesos').text, '1,234.56');
    });

    test('caracteres no numéricos sueltos se filtran', () {
      expect(_apply('', 'abc123').text, '123');
    });
  });

  group('parseFormattedAmount', () {
    test('"1,234.56" → 1234.56', () {
      expect(parseFormattedAmount('1,234.56'), 1234.56);
    });

    test('"1000" → 1000.0', () {
      expect(parseFormattedAmount('1000'), 1000.0);
    });

    test('vacío → null', () {
      expect(parseFormattedAmount(''), isNull);
    });

    test('inválido → null', () {
      expect(parseFormattedAmount('abc'), isNull);
    });
  });

  group('formatAmountForInput (hydration edit)', () {
    test('1000.0 → "1,000"', () {
      expect(formatAmountForInput(1000), '1,000');
    });

    test('1500.5 → "1,500.50"', () {
      expect(formatAmountForInput(1500.5), '1,500.50');
    });

    test('1234.56 → "1,234.56"', () {
      expect(formatAmountForInput(1234.56), '1,234.56');
    });

    test('0.99 → "0.99"', () {
      expect(formatAmountForInput(0.99), '0.99');
    });

    test('0.0 → "0"', () {
      expect(formatAmountForInput(0), '0');
    });
  });
}
