import 'package:fincore/constants/date_range_presets.dart';
import 'package:fincore/data/entries_filters.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tests del modelo `EntriesFilters` (sprint flutter-movements-filters-v1,
/// RF-006 apoyo). Cubre factory thisMonth + round-trip serialize/parse +
/// validación defensiva de URL malformada + deduplicación.
void main() {
  group('EntriesFilters — defaults', () {
    test('factory thisMonth con ref fijo', () {
      final f = EntriesFilters.thisMonth(DateTime(2026, 6, 15));
      expect(f.datePreset, DateRangePreset.thisMonth);
      expect(f.from, DateTime(2026, 6, 1));
      expect(f.to, DateTime(2026, 6, 30, 23, 59, 59, 999));
      expect(f.kinds, isEmpty);
      expect(f.accountIds, isEmpty);
      expect(f.categoryIds, isEmpty);
    });

    test('activeCount = 0 en default thisMonth', () {
      final f = EntriesFilters.thisMonth(DateTime(2026, 6, 15));
      expect(f.activeCount, 0);
    });

    test('activeCount cuenta dimensiones, no items', () {
      final base = EntriesFilters.thisMonth(DateTime(2026, 6, 15));
      final f = base.copyWith(
        kinds: ['expense', 'credit_expense'],
        accountIds: ['a1', 'a2'],
        categoryIds: ['c1', 'c2', 'c3'],
      );
      // kinds (1) + accountIds (1) + categoryIds (1) = 3 dimensiones.
      expect(f.activeCount, 3);
    });

    test('activeCount cuenta datePreset != thisMonth como activo', () {
      final f = EntriesFilters.thisMonth(DateTime(2026, 6, 15))
          .withPreset(DateRangePreset.lastMonth, DateTime(2026, 6, 15));
      expect(f.activeCount, 1);
    });
  });

  group('EntriesFilters — withPreset', () {
    test('cambio a lastMonth recalcula rango', () {
      final base = EntriesFilters.thisMonth(DateTime(2026, 6, 15));
      final f = base.withPreset(DateRangePreset.lastMonth, DateTime(2026, 6, 15));
      expect(f.from, DateTime(2026, 5, 1));
      expect(f.to, DateTime(2026, 5, 31, 23, 59, 59, 999));
    });

    test('cambio a custom preserva rango previo', () {
      final base = EntriesFilters.thisMonth(DateTime(2026, 6, 15));
      final f = base.withPreset(DateRangePreset.custom, DateTime(2026, 6, 15));
      expect(f.from, DateTime(2026, 6, 1));
      expect(f.to, DateTime(2026, 6, 30, 23, 59, 59, 999));
      expect(f.datePreset, DateRangePreset.custom);
    });
  });

  group('EntriesFilters — serialize / parse round-trip', () {
    test('default thisMonth → URL vacío', () {
      final f = EntriesFilters.thisMonth(DateTime(2026, 6, 15));
      expect(f.serialize(), isEmpty);
    });

    test('lastMonth + kinds → URL serializa preset + kinds', () {
      final f = EntriesFilters.thisMonth(DateTime(2026, 6, 15))
          .withPreset(DateRangePreset.lastMonth, DateTime(2026, 6, 15))
          .copyWith(kinds: ['expense', 'credit_expense']);
      final s = f.serialize();
      expect(s['datePreset'], 'last_month');
      expect(s['kinds'], 'expense,credit_expense');
      expect(s.containsKey('from'), isFalse,
          reason: 'preset no-custom no serializa fechas');
    });

    test('custom serializa from + to ISO 8601', () {
      final f = EntriesFilters(
        datePreset: DateRangePreset.custom,
        from: DateTime(2026, 3, 5),
        to: DateTime(2026, 4, 10, 23, 59, 59, 999),
      );
      final s = f.serialize();
      expect(s['datePreset'], 'custom');
      expect(s['from'], DateTime(2026, 3, 5).toIso8601String());
      expect(s['to'], DateTime(2026, 4, 10, 23, 59, 59, 999).toIso8601String());
    });

    test('round-trip: serialize → parse devuelve filtros equivalentes', () {
      final ref = DateTime(2026, 6, 15);
      final original = EntriesFilters.thisMonth(ref)
          .withPreset(DateRangePreset.lastMonth, ref)
          .copyWith(
            kinds: ['expense', 'credit_expense'],
            accountIds: ['acc-1', 'acc-2'],
            categoryIds: ['cat-1', 'cat-2'],
          );
      final s = original.serialize();
      final parsed = EntriesFilters.parse(s, ref);
      expect(parsed.datePreset, original.datePreset);
      expect(parsed.from, original.from);
      expect(parsed.to, original.to);
      expect(parsed.kinds, original.kinds);
      expect(parsed.accountIds, original.accountIds);
      expect(parsed.categoryIds, original.categoryIds);
    });
  });

  group('EntriesFilters — parse defensivo', () {
    test('URL vacío → thisMonth default', () {
      final ref = DateTime(2026, 6, 15);
      final f = EntriesFilters.parse({}, ref);
      expect(f.datePreset, DateRangePreset.thisMonth);
    });

    test('preset desconocido → fallback thisMonth', () {
      final ref = DateTime(2026, 6, 15);
      final f = EntriesFilters.parse({'datePreset': 'invalido'}, ref);
      expect(f.datePreset, DateRangePreset.thisMonth);
    });

    test('custom con fechas inválidas → fallback thisMonth', () {
      final ref = DateTime(2026, 6, 15);
      final f = EntriesFilters.parse({
        'datePreset': 'custom',
        'from': 'no-es-fecha',
        'to': 'tampoco',
      }, ref);
      expect(f.from, DateTime(2026, 6, 1));
      expect(f.to, DateTime(2026, 6, 30, 23, 59, 59, 999));
    });

    test('custom con from > to → fallback thisMonth', () {
      final ref = DateTime(2026, 6, 15);
      final f = EntriesFilters.parse({
        'datePreset': 'custom',
        'from': DateTime(2026, 6, 20).toIso8601String(),
        'to': DateTime(2026, 6, 10).toIso8601String(),
      }, ref);
      expect(f.from, DateTime(2026, 6, 1));
      expect(f.to, DateTime(2026, 6, 30, 23, 59, 59, 999));
    });

    test('kinds con duplicados se deduplica', () {
      final f = EntriesFilters.parse({
        'kinds': 'expense,expense,credit_expense',
      });
      expect(f.kinds.length, 2);
      expect(f.kinds.toSet(), {'expense', 'credit_expense'});
    });

    test('kinds inválidos se filtran', () {
      final f = EntriesFilters.parse({
        'kinds': 'expense,bogus,credit_expense',
      });
      expect(f.kinds.toSet(), {'expense', 'credit_expense'});
    });

    test('categoryIds con duplicados se deduplica', () {
      final f = EntriesFilters.parse({
        'categoryIds': 'cat-1,cat-1,cat-2,__null__',
      });
      expect(f.categoryIds.toSet(), {'cat-1', 'cat-2', '__null__'});
    });
  });

  // ===========================================================================
  // amount — sprint `flutter-movements-amount-filter-v1`
  // ===========================================================================
  group('EntriesFilters — amount (RF-001..RF-007)', () {
    final base = EntriesFilters.thisMonth(DateTime(2026, 6, 15));

    test('UT-07: copyWith setea, clearMinAmount/clearMaxAmount limpia', () {
      final withMin = base.copyWith(minAmount: 100);
      expect(withMin.minAmount, 100);
      expect(withMin.maxAmount, isNull);

      // No cambiar.
      final noOp = withMin.copyWith();
      expect(noOp.minAmount, 100);

      // Limpiar explícitamente.
      final cleared = withMin.copyWith(clearMinAmount: true);
      expect(cleared.minAmount, isNull);

      // Setear max + limpiar min en la misma copia.
      final mixed = withMin.copyWith(
        maxAmount: 500,
        clearMinAmount: true,
      );
      expect(mixed.minAmount, isNull);
      expect(mixed.maxAmount, 500);
    });

    test('UT-08: clearDimension(amount) limpia ambos campos', () {
      final f = base.copyWith(minAmount: 100, maxAmount: 500);
      final cleared = f.clearDimension(FilterDimension.amount);
      expect(cleared.minAmount, isNull);
      expect(cleared.maxAmount, isNull);
    });

    test('UT-09: activeCount cuenta amount como 1 dimensión (no 2)', () {
      expect(base.activeCount, 0);
      expect(base.copyWith(minAmount: 100).activeCount, 1);
      expect(base.copyWith(maxAmount: 500).activeCount, 1);
      expect(base.copyWith(minAmount: 100, maxAmount: 500).activeCount, 1);
    });

    test('UT-10: parse({"minAmount": "500", "maxAmount": "1500"}) ok', () {
      final f = EntriesFilters.parse({
        'minAmount': '500',
        'maxAmount': '1500',
      });
      expect(f.minAmount, 500.0);
      expect(f.maxAmount, 1500.0);
    });

    test('UT-11: parse con no-numérico → null', () {
      final f = EntriesFilters.parse({'minAmount': 'abc'});
      expect(f.minAmount, isNull);
    });

    test('UT-12: parse con negativos → null (RN-A07)', () {
      final f = EntriesFilters.parse({
        'minAmount': '-500',
        'maxAmount': '-100',
      });
      expect(f.minAmount, isNull);
      expect(f.maxAmount, isNull);
    });

    test('UT-13: toDeepLink agrega minAmount/maxAmount como query params',
        () {
      final f = base.copyWith(minAmount: 500, maxAmount: 1500);
      final link = f.toDeepLink();
      expect(link, contains('minAmount=500'));
      expect(link, contains('maxAmount=1500'));
    });
  });

  // Sprint flutter-reports-income-by-category-v1 (RF-004).
  group('forIncomeBucket', () {
    final from = DateTime(2026, 6, 1);
    final to = DateTime(2026, 6, 30, 23, 59, 59, 999);

    test(
        'UT-I11: con categoryId → kinds=[income], datePreset=custom, categoryIds contiene el id',
        () {
      final f = EntriesFilters.forIncomeBucket(
        categoryId: '01a2b3c4-5678-7abc-9def-000000000042',
        from: from,
        to: to,
      );
      expect(f.kinds, ['income']);
      expect(f.datePreset, DateRangePreset.custom);
      expect(f.from, from);
      expect(f.to, to);
      expect(f.categoryIds, ['01a2b3c4-5678-7abc-9def-000000000042']);
    });

    test(
        'UT-I12: con categoryId=null → categoryIds contiene el token "sin categoría"',
        () {
      final f = EntriesFilters.forIncomeBucket(
        categoryId: null,
        from: from,
        to: to,
      );
      expect(f.kinds, ['income']);
      // El token de "sin categoría" es privado — verificamos que hay
      // exactamente 1 elemento y NO es un UUID vacío.
      expect(f.categoryIds, hasLength(1));
      expect(f.categoryIds.first, isNotEmpty);
    });
  });

  // Sprint flutter-reports-movements-calendar-v1 (RF-006).
  group('forDay (sprint movements-calendar)', () {
    test(
        'UT-CAL13: forDay arma rango custom de 1 día sin restricciones extra',
        () {
      final f = EntriesFilters.forDay(day: DateTime(2026, 6, 15));
      expect(f.datePreset, DateRangePreset.custom);
      expect(f.from, DateTime(2026, 6, 15, 0, 0, 0));
      expect(f.to, DateTime(2026, 6, 15, 23, 59, 59, 999));
      expect(f.kinds, isEmpty,
          reason: 'Sin filtro de kind: muestra todos los movimientos del día.');
      expect(f.accountIds, isEmpty);
      expect(f.categoryIds, isEmpty);
      expect(f.minAmount, isNull);
      expect(f.maxAmount, isNull);
    });

    test(
        'UT-CAL14: forDay → toDeepLink → parse roundtrip preserva el rango',
        () {
      final f = EntriesFilters.forDay(day: DateTime(2026, 3, 8));
      final link = f.toDeepLink();
      // El deep link es /entries?datePreset=custom&from=...&to=...
      // Parseamos con EntriesFilters.parse (mismo path que usa el router).
      final uri = Uri.parse(link);
      final parsed = EntriesFilters.parse(uri.queryParameters);
      expect(parsed.datePreset, DateRangePreset.custom);
      expect(parsed.from, DateTime(2026, 3, 8, 0, 0, 0));
      expect(parsed.to, DateTime(2026, 3, 8, 23, 59, 59, 999));
      expect(parsed.kinds, isEmpty);
      expect(parsed.categoryIds, isEmpty);
    });
  });

  group('forMonth (sprint cashflow-monthly-breakdown-v1)', () {
    test('UT-CB14: junio 2026 → rango 2026-06-01 00:00 a 2026-06-30 23:59:59.999',
        () {
      final f = EntriesFilters.forMonth(firstDay: DateTime(2026, 6, 15));
      expect(f.datePreset, DateRangePreset.custom);
      expect(f.from, DateTime(2026, 6, 1));
      expect(f.to, DateTime(2026, 6, 30, 23, 59, 59, 999));
    });

    test('UT-CB15: febrero 2024 (bisiesto) → 29/2 último día', () {
      final f = EntriesFilters.forMonth(firstDay: DateTime(2024, 2, 1));
      expect(f.from, DateTime(2024, 2, 1));
      expect(f.to, DateTime(2024, 2, 29, 23, 59, 59, 999));
    });
  });
}
