import 'package:fincore/constants/date_range_presets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tests unitarios del helper `dateRangeForPreset` (M4 quality review v1 +
/// RF-018 del sprint flutter-movements-filters-v1 que extrajo el helper a
/// `lib/constants/date_range_presets.dart`).
///
/// El cálculo de "Mes pasado" cruzando enero/diciembre y la construcción de
/// "último día del mes" via `DateTime(year, month + 1, 0)` son las áreas más
/// frágiles. Estos tests blindan contra refactor ingenuo (ej. guardar
/// `month - 1` con clamp en 1 rompería el cruce de año).
void main() {
  group('dateRangeForPreset — thisMonth', () {
    test('mes de 30 días (junio): from = 1, to = 30', () {
      final ref = DateTime(2026, 6, 15);
      final (from, to) = dateRangeForPreset(DateRangePreset.thisMonth, ref);
      expect(from, DateTime(2026, 6, 1));
      expect(to, DateTime(2026, 6, 30, 23, 59, 59, 999));
    });

    test('mes de 31 días (julio): from = 1, to = 31', () {
      final ref = DateTime(2026, 7, 10);
      final (from, to) = dateRangeForPreset(DateRangePreset.thisMonth, ref);
      expect(from, DateTime(2026, 7, 1));
      expect(to, DateTime(2026, 7, 31, 23, 59, 59, 999));
    });

    test('febrero año bisiesto: from = 1, to = 29', () {
      final ref = DateTime(2024, 2, 15);
      final (from, to) = dateRangeForPreset(DateRangePreset.thisMonth, ref);
      expect(from, DateTime(2024, 2, 1));
      expect(to, DateTime(2024, 2, 29, 23, 59, 59, 999));
    });

    test('febrero año NO bisiesto: from = 1, to = 28', () {
      final ref = DateTime(2026, 2, 10);
      final (from, to) = dateRangeForPreset(DateRangePreset.thisMonth, ref);
      expect(from, DateTime(2026, 2, 1));
      expect(to, DateTime(2026, 2, 28, 23, 59, 59, 999));
    });

    test('último día del mes como referencia rinde igual', () {
      final ref = DateTime(2026, 6, 30, 23, 59);
      final (from, to) = dateRangeForPreset(DateRangePreset.thisMonth, ref);
      expect(from, DateTime(2026, 6, 1));
      expect(to, DateTime(2026, 6, 30, 23, 59, 59, 999));
    });
  });

  group('dateRangeForPreset — lastMonth', () {
    test('mes corriente junio → mes pasado mayo (31 días)', () {
      final ref = DateTime(2026, 6, 15);
      final (from, to) = dateRangeForPreset(DateRangePreset.lastMonth, ref);
      expect(from, DateTime(2026, 5, 1));
      expect(to, DateTime(2026, 5, 31, 23, 59, 59, 999));
    });

    test('enero cruza a diciembre del año anterior', () {
      final ref = DateTime(2026, 1, 10);
      final (from, to) = dateRangeForPreset(DateRangePreset.lastMonth, ref);
      expect(from, DateTime(2025, 12, 1),
          reason: 'enero - 1 mes debe ser diciembre del año anterior');
      expect(to, DateTime(2025, 12, 31, 23, 59, 59, 999),
          reason: 'fin de diciembre = día 31');
    });

    test('marzo año bisiesto → mes pasado febrero (29 días)', () {
      final ref = DateTime(2024, 3, 10);
      final (from, to) = dateRangeForPreset(DateRangePreset.lastMonth, ref);
      expect(from, DateTime(2024, 2, 1));
      expect(to, DateTime(2024, 2, 29, 23, 59, 59, 999),
          reason: 'febrero 2024 es bisiesto: día 29');
    });

    test('marzo año NO bisiesto → mes pasado febrero (28 días)', () {
      final ref = DateTime(2026, 3, 15);
      final (from, to) = dateRangeForPreset(DateRangePreset.lastMonth, ref);
      expect(from, DateTime(2026, 2, 1));
      expect(to, DateTime(2026, 2, 28, 23, 59, 59, 999));
    });
  });

  group('dateRangeForPreset — thisYear', () {
    test('mitad de año: from = 1 ene, to = 31 dic', () {
      final ref = DateTime(2026, 6, 15);
      final (from, to) = dateRangeForPreset(DateRangePreset.thisYear, ref);
      expect(from, DateTime(2026, 1, 1));
      expect(to, DateTime(2026, 12, 31, 23, 59, 59, 999));
    });

    test('primer día del año rinde igual', () {
      final ref = DateTime(2026, 1, 1);
      final (from, to) = dateRangeForPreset(DateRangePreset.thisYear, ref);
      expect(from, DateTime(2026, 1, 1));
      expect(to, DateTime(2026, 12, 31, 23, 59, 59, 999));
    });

    test('último día del año rinde igual', () {
      final ref = DateTime(2026, 12, 31, 22);
      final (from, to) = dateRangeForPreset(DateRangePreset.thisYear, ref);
      expect(from, DateTime(2026, 1, 1));
      expect(to, DateTime(2026, 12, 31, 23, 59, 59, 999));
    });
  });

  group('dateRangeForPreset — custom', () {
    test('preserva currentFrom y currentTo tal cual', () {
      final ref = DateTime(2026, 6, 15);
      final cf = DateTime(2026, 3, 10);
      final ct = DateTime(2026, 4, 20, 23, 59, 59, 999);
      final (from, to) = dateRangeForPreset(
        DateRangePreset.custom,
        ref,
        currentFrom: cf,
        currentTo: ct,
      );
      expect(from, cf);
      expect(to, ct);
    });
  });

  group('extension label + slug', () {
    test('Cada preset tiene un label en español', () {
      expect(DateRangePreset.thisMonth.label, 'Este mes');
      expect(DateRangePreset.lastMonth.label, 'Mes pasado');
      expect(DateRangePreset.thisYear.label, 'Año');
      expect(DateRangePreset.custom.label, 'Custom');
    });

    test('Slugs estables para serializar a query params', () {
      expect(DateRangePreset.thisMonth.slug, 'this_month');
      expect(DateRangePreset.lastMonth.slug, 'last_month');
      expect(DateRangePreset.thisYear.slug, 'this_year');
      expect(DateRangePreset.custom.slug, 'custom');
    });

    test('dateRangePresetFromSlug parse correcto + null en desconocido', () {
      expect(dateRangePresetFromSlug('this_month'), DateRangePreset.thisMonth);
      expect(dateRangePresetFromSlug('last_month'), DateRangePreset.lastMonth);
      expect(dateRangePresetFromSlug('this_year'), DateRangePreset.thisYear);
      expect(dateRangePresetFromSlug('custom'), DateRangePreset.custom);
      expect(dateRangePresetFromSlug('blabla'), isNull);
      expect(dateRangePresetFromSlug(null), isNull);
      expect(dateRangePresetFromSlug(''), isNull);
    });
  });
}
