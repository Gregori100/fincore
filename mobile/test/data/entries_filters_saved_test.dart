import 'package:fincore/constants/date_range_presets.dart';
import 'package:fincore/data/entries_filters.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tests del serializer `toSavedJson`/`fromSavedJson` de
/// `EntriesFilters`. Sprint `flutter-entries-saved-views-v1` (CM-02).
void main() {
  group('EntriesFilters — toSavedJson/fromSavedJson', () {
    test('UT-11: round-trip preserva todos los campos (custom)', () {
      final original = EntriesFilters(
        datePreset: DateRangePreset.custom,
        from: DateTime(2026, 5, 1),
        to: DateTime(2026, 5, 31, 23, 59, 59),
        kinds: const ['expense', 'credit_expense'],
        accountIds: const ['acc-1', 'acc-2'],
        categoryIds: const ['cat-1'],
        minAmount: 100.0,
        maxAmount: 500.0,
      );
      final json = original.toSavedJson();
      final restored = EntriesFilters.fromSavedJson(json);
      expect(restored.datePreset, original.datePreset);
      expect(restored.from, original.from);
      expect(restored.to, original.to);
      expect(restored.kinds, original.kinds);
      expect(restored.accountIds, original.accountIds);
      expect(restored.categoryIds, original.categoryIds);
      expect(restored.minAmount, original.minAmount);
      expect(restored.maxAmount, original.maxAmount);
    });

    test(
        'UT-12: preset thisMonth se aplica rolling (recalcula al deserializar)',
        () {
      // Guardar en junio 2026.
      final saved = EntriesFilters.thisMonth(DateTime(2026, 6, 15));
      expect(saved.from, DateTime(2026, 6, 1));
      final json = saved.toSavedJson();
      // El JSON NO debe contener from/to para preset semántico.
      expect(json.containsKey('from'), isFalse);
      expect(json.containsKey('to'), isFalse);
      // Al deserializar en julio, recalcula.
      final restored =
          EntriesFilters.fromSavedJson(json, DateTime(2026, 7, 15));
      expect(restored.from, DateTime(2026, 7, 1));
      expect(restored.to.month, 7);
    });

    test('UT-13: preset custom se guarda con from/to ISO8601 exactos',
        () {
      final saved = EntriesFilters(
        datePreset: DateRangePreset.custom,
        from: DateTime(2026, 5, 1),
        to: DateTime(2026, 5, 31, 23, 59, 59),
      );
      final json = saved.toSavedJson();
      expect(json['from'], isA<String>());
      expect(json['to'], isA<String>());
      // Al deserializar en cualquier mes, mantiene fechas exactas.
      final restored = EntriesFilters.fromSavedJson(
          json, DateTime(2026, 12, 15));
      expect(restored.from, DateTime(2026, 5, 1));
      expect(restored.to, DateTime(2026, 5, 31, 23, 59, 59));
    });

    test('UT-14: fromSavedJson({}) → fallback a thisMonth', () {
      final restored =
          EntriesFilters.fromSavedJson({}, DateTime(2026, 6, 15));
      expect(restored.datePreset, DateRangePreset.thisMonth);
      expect(restored.from, DateTime(2026, 6, 1));
    });

    test('UT-15: campos extra en JSON se ignoran sin error', () {
      final saved = EntriesFilters.thisMonth();
      final json = saved.toSavedJson();
      json['extra_field'] = 'algo';
      json['otra_cosa'] = 42;
      // No debería lanzar.
      final restored = EntriesFilters.fromSavedJson(json);
      expect(restored.datePreset, saved.datePreset);
    });

    test('UT-16: fromSavedJson con kinds como lista parsea correcto',
        () {
      final json = <String, dynamic>{
        'datePreset': 'this_month',
        'kinds': ['expense', 'income'],
        'accountIds': ['acc-1'],
        'categoryIds': ['cat-1', 'cat-2'],
        'minAmount': 100,
        'maxAmount': 500.5,
      };
      final restored = EntriesFilters.fromSavedJson(json);
      expect(restored.kinds.toSet(), {'expense', 'income'});
      expect(restored.accountIds, ['acc-1']);
      expect(restored.categoryIds.toSet(), {'cat-1', 'cat-2'});
      expect(restored.minAmount, 100);
      expect(restored.maxAmount, 500.5);
    });
  });
}
