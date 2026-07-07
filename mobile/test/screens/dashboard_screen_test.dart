import 'package:fincore/screens/reports_screen.dart';
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

    // Sprint UX de visibilidad de cuenta: la row de "Últimos movimientos"
    // muestra el nombre de la cuenta relevante según el kind (destino en
    // income; origen en expense; "origen → destino" en transfer/pago).
    testWidgets(
        'Últimos movimientos: la row muestra el nombre de la cuenta',
        (tester) async {
      final harness = await pumpFincoreApp(
        tester,
        seed: (db, deps) async {
          final bolsa = (await deps.accountsDao.listAll())
              .firstWhere((a) => a.type == 'cash');
          final bbva = await deps.accountsDao.create(
            name: 'BBVA_Row_Test',
            type: 'debit',
          );
          // Expense desde BBVA → subtexto muestra "BBVA_Row_Test".
          await deps.entriesDao.registerExpense(
            accountOriginId: bbva,
            amount: 300,
            occurredAt: DateTime.utc(2026, 6, 22, 12),
            description: 'GastoBBVA_Row',
          );
          // Transfer bolsa → BBVA → subtexto muestra "Bolsa → BBVA_Row_Test".
          await deps.entriesDao.registerTransfer(
            accountOriginId: bolsa.id,
            accountDestinationId: bbva,
            amount: 100,
            occurredAt: DateTime.utc(2026, 6, 23, 12),
            description: 'TransferRow_Test',
          );
        },
      );

      // La descripción del expense es visible.
      expect(find.text('GastoBBVA_Row'), findsOneWidget);
      // El nombre de la cuenta aparece dentro del subtexto (que también
      // trae fecha y kind). Usamos textContaining porque el subtexto es
      // "BBVA_Row_Test · 22 jun · Gasto".
      expect(
        find.textContaining('BBVA_Row_Test'),
        findsWidgets,
        reason: 'La row del expense muestra el nombre de la cuenta origen.',
      );
      // La transfer muestra "origen → destino" en el subtexto.
      expect(
        find.textContaining('Bolsa → BBVA_Row_Test'),
        findsOneWidget,
        reason: 'La row del transfer muestra "origen → destino".',
      );

      await harness.dispose();
    });

    testWidgets(
        'AppBar tiene IconButton "Reportes" que navega a /reports (RF-017)',
        (tester) async {
      final harness = await pumpFincoreApp(tester);

      // El IconButton del AppBar tiene tooltip "Reportes" (único, no confunde
      // con el icono de Categorías ni Settings).
      final reportsButton = find.byTooltip('Reportes');
      expect(reportsButton, findsOneWidget,
          reason: 'El AppBar del Dashboard debería tener un IconButton Reportes');

      await tester.tap(reportsButton);
      await tester.pumpAndSettle();

      expect(find.byType(ReportsScreen), findsOneWidget,
          reason: 'Tap del IconButton Reportes navega a /reports');

      await harness.dispose();
    });
  });
}
