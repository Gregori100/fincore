import 'package:fincore/data/database.dart';
import 'package:fincore/data/weekly_budgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tests de los helpers puros de presupuestos semanales. Sprint
/// `flutter-weekly-budgets-v1` (T026).
///
/// Puros: no requieren BD ni override de sqlite — construyen los rows de
/// drift directamente vía sus constructores generados.
void main() {
  DateTime ts(int day) => DateTime(2026, 1, day);

  WeeklyBudgetRow budget({
    required String id,
    required DateTime weekStartDate,
    String label = 'Presupuesto',
  }) {
    return WeeklyBudgetRow(
      id: id,
      weekStartDate: weekStartDate,
      label: label,
      isTemplate: false,
      createdAt: ts(1),
      updatedAt: ts(1),
    );
  }

  WeeklyBudgetItemRow item({
    required String id,
    required String budgetId,
    required int amount,
    required String kind,
    String name = 'Item',
    int sortOrder = 0,
  }) {
    return WeeklyBudgetItemRow(
      id: id,
      budgetId: budgetId,
      name: name,
      categoryId: null,
      amount: amount,
      kind: kind,
      sortOrder: sortOrder,
      isDone: false,
      createdAt: ts(1),
      updatedAt: ts(1),
    );
  }

  group('suggestedWeekStartDate', () {
    test(
        'UT-H01: now un martes, weekStartDow=5 (viernes) → viernes previo',
        () {
      // 2026-07-14 es martes.
      final result = suggestedWeekStartDate(
        now: DateTime(2026, 7, 14, 12, 30),
        weekStartDow: 5,
      );
      expect(result, DateTime(2026, 7, 10));
    });

    test('UT-H02: now cae exactamente en weekStartDow → mismo día medianoche',
        () {
      // 2026-07-10 es viernes (weekday == 5).
      final now = DateTime(2026, 7, 10, 18, 45);
      final result = suggestedWeekStartDate(now: now, weekStartDow: 5);
      expect(result, DateTime(2026, 7, 10));
    });

    test(
        'UT-H03: weekStartDow=1 (lunes), now domingo → lunes previo (6 días atrás)',
        () {
      // 2026-07-12 es domingo (weekday == 7).
      final now = DateTime(2026, 7, 12, 9, 0);
      final result = suggestedWeekStartDate(now: now, weekStartDow: 1);
      expect(result, DateTime(2026, 7, 6));
    });
  });

  group('groupBudgetsByRange', () {
    test('UT-H04: separa correctamente en las 3 secciones según week_start_date',
        () {
      final now = DateTime(2026, 7, 14); // martes
      const weekStartDow = 5; // viernes
      // Semana actual arranca 2026-07-10.
      final current = budget(id: 'b-current', weekStartDate: DateTime(2026, 7, 10));
      final future = budget(id: 'b-future', weekStartDate: DateTime(2026, 7, 17));
      final pastBudget = budget(id: 'b-past', weekStartDate: DateTime(2026, 7, 3));

      final grouped = groupBudgetsByRange(
        budgets: [current, future, pastBudget],
        now: now,
        weekStartDow: weekStartDow,
      );

      expect(grouped[BudgetSection.thisWeek]!.map((b) => b.id), ['b-current']);
      expect(grouped[BudgetSection.upcoming]!.map((b) => b.id), ['b-future']);
      expect(grouped[BudgetSection.past]!.map((b) => b.id), ['b-past']);
    });

    test('UT-H05: multi-plan con la misma fecha caen bajo la misma sección',
        () {
      final now = DateTime(2026, 7, 14);
      const weekStartDow = 5;
      final a = budget(id: 'a', weekStartDate: DateTime(2026, 7, 10));
      final b = budget(id: 'b', weekStartDate: DateTime(2026, 7, 10));

      final grouped = groupBudgetsByRange(
        budgets: [a, b],
        now: now,
        weekStartDow: weekStartDow,
      );

      expect(grouped[BudgetSection.thisWeek]!.length, 2);
      expect(
        grouped[BudgetSection.thisWeek]!.map((r) => r.id).toSet(),
        {'a', 'b'},
      );
      expect(grouped[BudgetSection.upcoming], isEmpty);
      expect(grouped[BudgetSection.past], isEmpty);
    });
  });

  group('calculateBalance', () {
    test('UT-H06: lista vacía retorna 0', () {
      expect(calculateBalance([]), 0);
    });

    test('UT-H07: solo income retorna +Σ', () {
      final items = [
        item(id: '1', budgetId: 'x', amount: 10000, kind: 'income'),
        item(id: '2', budgetId: 'x', amount: 5000, kind: 'income'),
      ];
      expect(calculateBalance(items), 15000);
    });

    test('UT-H08: solo expense retorna −Σ', () {
      final items = [
        item(id: '1', budgetId: 'x', amount: 3000, kind: 'expense'),
        item(id: '2', budgetId: 'x', amount: 2000, kind: 'expense'),
      ];
      expect(calculateBalance(items), -5000);
    });

    test('UT-H09: mixto retorna Σincome − Σexpense', () {
      final items = [
        item(id: '1', budgetId: 'x', amount: 20000, kind: 'income'),
        item(id: '2', budgetId: 'x', amount: 8000, kind: 'expense'),
        item(id: '3', budgetId: 'x', amount: 2000, kind: 'expense'),
      ];
      expect(calculateBalance(items), 10000);
    });
  });
}
