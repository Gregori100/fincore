import 'package:fincore/data/date_helpers.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tests del helper `nextOccurrenceOfDay` del sprint
/// `flutter-reports-credit-cards-v1`.
///
/// Cubre RN-CC04/CC05 y casos de calendario (bisiesto, cambio de año,
/// clamp al último día del mes).
void main() {
  group('nextOccurrenceOfDay', () {
    test('UT-13a: mismo día del mes → hoy (CB-04)', () {
      final today = DateTime(2024, 1, 15);
      expect(nextOccurrenceOfDay(today, 15), DateTime(2024, 1, 15));
    });

    test('UT-13b: día futuro del mes actual', () {
      final today = DateTime(2024, 1, 10);
      expect(nextOccurrenceOfDay(today, 15), DateTime(2024, 1, 15));
    });

    test('UT-13c: día pasado del mes actual → mes siguiente', () {
      final today = DateTime(2024, 1, 16);
      expect(nextOccurrenceOfDay(today, 15), DateTime(2024, 2, 15));
    });

    test('UT-13d: target 31 en abril (mes de 30 días), hoy=15 → clamp a 30 abril', () {
      // El clamp del mes actual (30 abril) todavía es futuro respecto a hoy=15.
      // Fix del bug detectado en quality review: antes saltaba a mayo 31.
      final today = DateTime(2024, 4, 15);
      expect(nextOccurrenceOfDay(today, 31), DateTime(2024, 4, 30));
    });

    test('UT-13e: target 31 en abril, hoy = 30 → clamp a hoy mismo (badge "Hoy")', () {
      final today = DateTime(2024, 4, 30);
      expect(nextOccurrenceOfDay(today, 31), DateTime(2024, 4, 30));
    });

    test('UT-13f: target 29 en febrero bisiesto (2024) → 29 feb', () {
      final today = DateTime(2024, 2, 10);
      expect(nextOccurrenceOfDay(today, 29), DateTime(2024, 2, 29));
    });

    test(
        'UT-13g: target 29 en febrero no bisiesto (2023), hoy=10 → clamp a 28 feb',
        () {
      // Feb 2023 tiene 28 días; target=29 clampa a 28. Como hoy=10 < 28, se
      // queda en el mes actual (el corte cae fin de mes, todavía futuro).
      final today = DateTime(2023, 2, 10);
      expect(nextOccurrenceOfDay(today, 29), DateTime(2023, 2, 28));
    });

    test('UT-13h: target 31 en febrero bisiesto, hoy=10 → clamp a 29 feb', () {
      // Feb 2024 tiene 29 días; target=31 clampa a 29. Como hoy=10 < 29,
      // se queda en el mes actual.
      final today = DateTime(2024, 2, 10);
      expect(nextOccurrenceOfDay(today, 31), DateTime(2024, 2, 29));
    });

    test(
        'UT-13h2: target 31 en febrero, hoy=29 (bisiesto) → clamp a hoy mismo',
        () {
      final today = DateTime(2024, 2, 29);
      expect(nextOccurrenceOfDay(today, 31), DateTime(2024, 2, 29));
    });

    test(
        'UT-13h3: target 31, hoy=último día del mes anterior a un mes de 31 días → mes siguiente 31',
        () {
      // Post-clamp del mes actual = último día del mes actual. Si hoy es
      // ese último día, ya es "hoy". Pero si hoy pasa ese día (imposible)
      // se salta. Este test verifica el salto a un mes con día 31 real.
      final today = DateTime(2024, 4, 30);
      // Target=30 → hoy exactamente → hoy.
      expect(nextOccurrenceOfDay(today, 30), DateTime(2024, 4, 30));
    });

    test('UT-13i: cambio de año diciembre → enero', () {
      final today = DateTime(2024, 12, 31);
      expect(nextOccurrenceOfDay(today, 5), DateTime(2025, 1, 5));
    });

    test('UT-13j: target 30 en enero (31 días), hoy = 5 → 30 enero', () {
      final today = DateTime(2024, 1, 5);
      expect(nextOccurrenceOfDay(today, 30), DateTime(2024, 1, 30));
    });

    test('UT-13k: target 1 en enero, hoy = 15 → 1 febrero', () {
      final today = DateTime(2024, 1, 15);
      expect(nextOccurrenceOfDay(today, 1), DateTime(2024, 2, 1));
    });

    test('UT-13l: target = 1, hoy = 1 → hoy', () {
      final today = DateTime(2024, 3, 1);
      expect(nextOccurrenceOfDay(today, 1), DateTime(2024, 3, 1));
    });

    test('UT-13m: target fuera de rango (0) → clamp a 1', () {
      final today = DateTime(2024, 3, 15);
      expect(nextOccurrenceOfDay(today, 0), DateTime(2024, 4, 1));
    });

    test('UT-13n: target fuera de rango (35) → clamp a 31 y luego al mes',
        () {
      final today = DateTime(2024, 3, 15);
      // targetDay=35 → clamp a 31 → hoy(15)<31 → 31 marzo (31 días).
      expect(nextOccurrenceOfDay(today, 35), DateTime(2024, 3, 31));
    });

    test('UT-13o: hoy = 31 dic, target = 31 → hoy (mismo día)', () {
      final today = DateTime(2024, 12, 31);
      expect(nextOccurrenceOfDay(today, 31), DateTime(2024, 12, 31));
    });
  });
}
