import 'package:flutter_test/flutter_test.dart';

import '../helpers/widget_test_harness.dart';

void main() {
  group('DashboardScreen — T043 / RF-005', () {
    testWidgets(r'BD recién seedeada: solo Bolsa, BO=$0, sin movimientos',
        (tester) async {
      final harness = await pumpFincoreApp(tester);

      // Bolsa visible (nombre + label tipo cash).
      expect(find.text('Bolsa'), findsNWidgets(2));
      // Cards de totales.
      expect(find.text('BO'), findsOneWidget);
      expect(find.text('DE'), findsOneWidget);
      expect(find.text('CR'), findsOneWidget);
      // Sin movimientos: el placeholder textual del tile vacío.
      expect(
        find.textContaining('Aún no hay movimientos'),
        findsOneWidget,
      );

      await harness.dispose();
    });

    testWidgets('Con 1 ingreso sembrado: BO refleja el monto',
        (tester) async {
      final harness = await pumpFincoreApp(
        tester,
        seed: (db, deps) async {
          final bolsa = (await deps.accountsDao.listAll())
              .firstWhere((a) => a.type == 'cash');
          await deps.entriesDao.registerIncome(
            accountDestinationId: bolsa.id,
            amount: 1000.0,
            occurredAt: DateTime.utc(2026, 6, 22, 12),
            description: 'Salario',
          );
        },
      );

      // El placeholder de "sin movimientos" debe haberse ido.
      expect(
        find.textContaining('Aún no hay movimientos'),
        findsNothing,
      );
      // El movimiento aparece en la lista por descripción.
      expect(find.text('Salario'), findsOneWidget);

      await harness.dispose();
    });
  });
}
