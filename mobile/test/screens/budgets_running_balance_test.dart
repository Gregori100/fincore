import 'package:fincore/screens/weekly_budgets/widgets/items_section.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tests puros del cascade `withCumulativeCascade` del sprint
/// `flutter-budgets-running-balance-v1`. Verifica que la suma acumulada
/// por renglón coincide con lo pedido por Diego:
///
///   Ingreso1 1500     → = 1500
///   Ingreso2 700      → = 2200
///   Ingreso3 300      → = 2500
///   Egreso1  500      → = 2000
///   Egreso2  1800     → = 200
///   Egreso3  300      → = -100
///
/// Sin harness de widget: la función es pura para justamente permitir
/// este blindaje mínimo.
void main() {
  BudgetItemDisplay item(String id, int amount, {bool isDone = false}) {
    return BudgetItemDisplay(
      id: id,
      name: id,
      amount: amount,
      isDone: isDone,
    );
  }

  group('withCumulativeCascade', () {
    test(
        'UT-RB01: 3 ingresos acumulan 1500 → 2200 → 2500 (ejemplo canónico '
        'de Diego)', () {
      final out = withCumulativeCascade(
        income: [item('i1', 1500), item('i2', 700), item('i3', 300)],
        expense: const [],
      );
      expect(out.income.map((i) => i.cumulativeAfter).toList(),
          [1500, 2200, 2500]);
      expect(out.expense, isEmpty);
    });

    test(
        'UT-RB02: cruce ingresos → gastos "arrastra" el subtotal; último '
        'gasto queda en -100', () {
      final out = withCumulativeCascade(
        income: [item('i1', 1500), item('i2', 700), item('i3', 300)],
        expense: [item('e1', 500), item('e2', 1800), item('e3', 300)],
      );
      expect(out.income.map((i) => i.cumulativeAfter).toList(),
          [1500, 2200, 2500]);
      expect(out.expense.map((e) => e.cumulativeAfter).toList(),
          [2000, 200, -100]);
    });

    test('UT-RB03: sólo gastos → running negativo desde el primero', () {
      final out = withCumulativeCascade(
        income: const [],
        expense: [item('e1', 500), item('e2', 300)],
      );
      expect(out.income, isEmpty);
      expect(out.expense.map((e) => e.cumulativeAfter).toList(),
          [-500, -800]);
    });

    test('UT-RB04: lista vacía en ambos lados → devuelve dos listas vacías',
        () {
      final out = withCumulativeCascade(income: const [], expense: const []);
      expect(out.income, isEmpty);
      expect(out.expense, isEmpty);
    });

    test('UT-RB05: isDone no altera la cascada (el saldo sigue el plan)', () {
      // Mismo dataset que UT-RB02 pero con todos marcados como done: los
      // valores acumulados deben ser idénticos.
      final out = withCumulativeCascade(
        income: [
          item('i1', 1500, isDone: true),
          item('i2', 700, isDone: true),
          item('i3', 300, isDone: true),
        ],
        expense: [
          item('e1', 500, isDone: true),
          item('e2', 1800, isDone: true),
          item('e3', 300, isDone: true),
        ],
      );
      expect(out.income.map((i) => i.cumulativeAfter).toList(),
          [1500, 2200, 2500]);
      expect(out.expense.map((e) => e.cumulativeAfter).toList(),
          [2000, 200, -100]);
    });

    test('UT-RB06: preserva el resto de los campos del BudgetItemDisplay',
        () {
      const input = BudgetItemDisplay(
        id: 'i1',
        name: 'Sueldo',
        categoryId: 'cat-1',
        amount: 150000,
        isDone: true,
      );
      final out = withCumulativeCascade(income: [input], expense: const []);
      final result = out.income.single;
      expect(result.id, 'i1');
      expect(result.name, 'Sueldo');
      expect(result.categoryId, 'cat-1');
      expect(result.amount, 150000);
      expect(result.isDone, isTrue);
      expect(result.cumulativeAfter, 150000);
    });
  });
}
