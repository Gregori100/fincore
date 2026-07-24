import 'package:fincore/utils/money.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

/// Sprint flutter-integer-cents-v1: tests unitarios de los helpers de
/// conversión y formateo monetarios.
void main() {
  setUpAll(() async {
    await initializeDateFormatting('es_MX', null);
  });

  group('parseCents', () {
    test('UT-IC-01: enteros sin decimales', () {
      expect(parseCents('1500'), 150000);
      expect(parseCents('0'), 0);
      expect(parseCents('1'), 100);
      expect(parseCents('999999'), 99999900);
    });

    test('UT-IC-02: con punto decimal', () {
      expect(parseCents('173.77'), 17377);
      expect(parseCents('100.5'), 10050);
      expect(parseCents('0.99'), 99);
      expect(parseCents('0.5'), 50);
      expect(parseCents('0.01'), 1);
    });

    test('UT-IC-03: con coma decimal', () {
      expect(parseCents('173,77'), 17377);
      expect(parseCents('100,5'), 10050);
      expect(parseCents('0,01'), 1);
    });

    test('UT-IC-04: con separador de miles y decimal', () {
      expect(parseCents('1,500.75'), 150075);
      expect(parseCents('1,500,000.50'), 150000050);
      // Formato europeo:
      expect(parseCents('1.500,75'), 150075);
      expect(parseCents('1.500.000,50'), 150000050);
    });

    test('UT-IC-05: coma sola con 3 dígitos → miles', () {
      expect(parseCents('1,500'), 150000);
      expect(parseCents('12,345'), 1234500);
    });

    test('UT-IC-06: coma sola con 1-2 dígitos → decimal', () {
      expect(parseCents('1,5'), 150);
      expect(parseCents('1,50'), 150);
    });

    test('UT-IC-07: símbolo \$ tolerado', () {
      expect(parseCents(r'$1,500.75'), 150075);
      expect(parseCents(r'$100'), 10000);
    });

    test('UT-IC-08: whitespace tolerado', () {
      expect(parseCents('  1500  '), 150000);
      expect(parseCents(' 100.50 '), 10050);
    });

    test('UT-IC-09: rechaza más de 2 decimales', () {
      expect(() => parseCents('100.501'), throwsFormatException);
      expect(() => parseCents('100.999'), throwsFormatException);
    });

    test('UT-IC-10: rechaza negativos', () {
      expect(() => parseCents('-100'), throwsFormatException);
      expect(() => parseCents('-100.50'), throwsFormatException);
    });

    test('UT-IC-11: rechaza vacío o solo whitespace', () {
      expect(() => parseCents(''), throwsFormatException);
      expect(() => parseCents('   '), throwsFormatException);
    });

    test('UT-IC-12: rechaza caracteres inválidos', () {
      expect(() => parseCents('abc'), throwsFormatException);
      expect(() => parseCents('100abc'), throwsFormatException);
      expect(() => parseCents('1e10'), throwsFormatException);
    });
  });

  group('formatCents', () {
    test('UT-IC-13: enteros y decimales básicos', () {
      expect(formatCents(0), r'$0.00');
      expect(formatCents(100), r'$1.00');
      expect(formatCents(17377), r'$173.77');
      expect(formatCents(150000), r'$1,500.00');
      expect(formatCents(150075), r'$1,500.75');
    });

    test('UT-IC-14: negativos con signo antes de \$', () {
      expect(formatCents(-100), r'-$1.00');
      expect(formatCents(-17377), r'-$173.77');
    });

    test('UT-IC-15: showSign antepone +', () {
      expect(formatCents(100, showSign: true), r'+$1.00');
      expect(formatCents(0, showSign: true), r'$0.00',
          reason: 'Cero no lleva signo');
      expect(formatCents(-100, showSign: true), r'-$1.00');
    });

    test('UT-IC-16: omitZeroDecimals oculta ".00"', () {
      expect(formatCents(100, omitZeroDecimals: true), r'$1');
      expect(formatCents(150000, omitZeroDecimals: true), r'$1,500');
      expect(formatCents(17377, omitZeroDecimals: true), r'$173.77');
    });

    test('UT-IC-17: montos grandes con separador de miles', () {
      expect(formatCents(100000000), r'$1,000,000.00');
      expect(formatCents(20791625), r'$207,916.25',
          reason: 'Suma agregada del backup real de Diego');
    });
  });

  group('centsFromDouble', () {
    test('UT-IC-18: round-trip básico', () {
      expect(centsFromDouble(173.77), 17377);
      expect(centsFromDouble(0.0), 0);
      expect(centsFromDouble(1.0), 100);
      expect(centsFromDouble(-100.50), -10050);
    });

    test('UT-IC-19: residuo IEEE 754 se corrige por round', () {
      // 0.1 + 0.2 = 0.30000000000000004 en IEEE 754
      final residuo = 0.1 + 0.2;
      expect(centsFromDouble(residuo), 30);
      // 173.77 puede almacenarse como 173.7699999... o 173.77000001
      expect(centsFromDouble(173.76999999999998), 17377);
      expect(centsFromDouble(173.77000000000001), 17377);
    });

    test('UT-IC-20: redondeo bancario en punto medio', () {
      expect(centsFromDouble(0.005), 1,
          reason: '0.5 centavos redondea a 1 (banker\'s round)');
      expect(centsFromDouble(0.004), 0,
          reason: '0.4 centavos redondea a 0');
    });

    test('UT-IC-21: NaN e Infinity → error', () {
      expect(() => centsFromDouble(double.nan), throwsArgumentError);
      expect(() => centsFromDouble(double.infinity), throwsArgumentError);
      expect(() => centsFromDouble(double.negativeInfinity), throwsArgumentError);
    });
  });

  group('centsToDouble', () {
    test('UT-IC-22: round-trip perfecto para valores comunes', () {
      for (final cents in [0, 1, 100, 17377, 150000, -10050]) {
        expect(centsFromDouble(centsToDouble(cents)), cents);
      }
    });

    test('UT-IC-23: round-trip contra la suma del backup real', () {
      const totalCents = 20791625;
      final asDouble = centsToDouble(totalCents);
      expect(asDouble, 207916.25);
      expect(centsFromDouble(asDouble), totalCents);
    });
  });
}
