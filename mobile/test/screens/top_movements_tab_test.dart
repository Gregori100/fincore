import 'package:fincore/screens/entry_form_screen.dart';
import 'package:fincore/screens/reports/top_movements_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../helpers/widget_test_harness.dart';

/// Widget tests del `TopMovementsTab`. Sprint
/// `flutter-reports-top-movements-v1`.
void main() {
  /// Helper: navega a `/reports` y tappea el tercer tab.
  Future<void> openTopMovementsTab(WidgetTester tester) async {
    final ctx = tester.element(find.byType(Scaffold).first);
    GoRouter.of(ctx).push('/reports');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Top movimientos'));
    await tester.pumpAndSettle();
  }

  group('TopMovementsTab', () {
    testWidgets('WT-01: render con datos: 3 entries → 3 rows visibles',
        (tester) async {
      final harness = await pumpFincoreApp(tester, seed: (db, deps) async {
        await deps.accountsDao.create(name: 'Banamex_T', type: 'debit');
        final debit = (await deps.accountsDao.listAll())
            .firstWhere((a) => a.name == 'Banamex_T');
        final now = DateTime.now();
        final day = DateTime(now.year, now.month, 10, 10);
        await deps.entriesDao.registerExpense(
          accountOriginId: debit.id,
          amount: 500,
          occurredAt: day,
          description: 'TopBig',
        );
        await deps.entriesDao.registerExpense(
          accountOriginId: debit.id,
          amount: 100,
          occurredAt: day.add(const Duration(hours: 1)),
          description: 'TopSmall',
        );
        await deps.entriesDao.registerExpense(
          accountOriginId: debit.id,
          amount: 300,
          occurredAt: day.add(const Duration(hours: 2)),
          description: 'TopMid',
        );
      });

      await openTopMovementsTab(tester);

      expect(find.byType(TopMovementsTab), findsOneWidget);
      // Los 3 entries son visibles.
      expect(find.text('TopBig'), findsOneWidget);
      expect(find.text('TopMid'), findsOneWidget);
      expect(find.text('TopSmall'), findsOneWidget);

      await harness.dispose();
    });

    testWidgets('WT-02: empty state cuando rango vacío', (tester) async {
      final harness = await pumpFincoreApp(tester);

      await openTopMovementsTab(tester);

      expect(find.text('No hay movimientos en este rango.'), findsOneWidget);

      await harness.dispose();
    });

    testWidgets('WT-03: empty state cuando sin kinds seleccionados',
        (tester) async {
      final harness = await pumpFincoreApp(tester);

      await openTopMovementsTab(tester);

      // Destildar los 5 chips de kinds (default: los 5 seleccionados).
      await tester.tap(find.text('Ingreso'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Gasto'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Gasto a tarjeta'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pago de tarjeta'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Transferencia'));
      await tester.pumpAndSettle();

      expect(
        find.text('Seleccioná al menos un tipo de movimiento.'),
        findsOneWidget,
      );

      await harness.dispose();
    });

    testWidgets('WT-04: tap en row navega a /entries/:id/edit',
        (tester) async {
      final harness = await pumpFincoreApp(tester, seed: (db, deps) async {
        await deps.accountsDao.create(name: 'Banamex_T', type: 'debit');
        final debit = (await deps.accountsDao.listAll())
            .firstWhere((a) => a.name == 'Banamex_T');
        final now = DateTime.now();
        await deps.entriesDao.registerExpense(
          accountOriginId: debit.id,
          amount: 500,
          occurredAt: DateTime(now.year, now.month, 10, 10),
          description: 'TapTarget',
        );
      });

      await openTopMovementsTab(tester);

      expect(find.text('TapTarget'), findsOneWidget);
      await tester.tap(find.text('TapTarget'));
      await tester.pumpAndSettle();

      // Tras tap, el form de edición de entry está montado.
      expect(find.byType(EntryFormScreen), findsOneWidget);

      await harness.dispose();
    });
  });
}
