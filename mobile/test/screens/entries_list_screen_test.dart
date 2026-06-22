import 'package:fincore/screens/entries_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../helpers/factories.dart';
import '../helpers/widget_test_harness.dart';

/// Tests de entries_list — render + bottom sheet de filtros.
/// RF-021 v1 del sprint flutter-ui-test-coverage-v1.
void main() {
  group('EntriesListScreen — bottom sheet de filtros (RF-021 v1)', () {
    Future<void> seedMixedEntries(dynamic db, dynamic deps) async {
      await db.into(db.accounts).insert(Factories.debit(name: 'Banamex'));
      final bolsa = (await deps.accountsDao.listAll())
          .firstWhere((a) => a.type == 'cash');
      final debit = (await deps.accountsDao.listAll())
          .firstWhere((a) => a.name == 'Banamex');
      // 2 income + 2 expense + 1 transfer = 5 entries.
      await deps.entriesDao.registerIncome(
        accountDestinationId: bolsa.id,
        amount: 1000.0,
        occurredAt: DateTime.utc(2026, 6, 22, 10),
        description: 'Salario',
      );
      await deps.entriesDao.registerIncome(
        accountDestinationId: bolsa.id,
        amount: 200.0,
        occurredAt: DateTime.utc(2026, 6, 22, 11),
        description: 'Reembolso',
      );
      await deps.entriesDao.registerExpense(
        accountOriginId: bolsa.id,
        amount: 50.0,
        occurredAt: DateTime.utc(2026, 6, 22, 12),
        description: 'Café',
      );
      await deps.entriesDao.registerExpense(
        accountOriginId: bolsa.id,
        amount: 80.0,
        occurredAt: DateTime.utc(2026, 6, 22, 13),
        description: 'Almuerzo',
      );
      await deps.entriesDao.registerTransfer(
        accountOriginId: bolsa.id,
        accountDestinationId: debit.id,
        amount: 500.0,
        occurredAt: DateTime.utc(2026, 6, 22, 14),
        description: 'A débito',
      );
    }

    Future<void> pushEntries(WidgetTester tester) async {
      final ctx = tester.element(find.byType(Scaffold));
      GoRouter.of(ctx).push('/entries');
      await tester.pumpAndSettle();
    }

    testWidgets('Sembrado de 5 entries de distintos kinds rendea los 5',
        (tester) async {
      final harness = await pumpFincoreApp(tester, seed: seedMixedEntries);
      await pushEntries(tester);

      expect(find.byType(EntriesListScreen), findsOneWidget);
      // Descripciones unique de los 5 entries.
      expect(find.text('Salario'), findsOneWidget);
      expect(find.text('Reembolso'), findsOneWidget);
      expect(find.text('Café'), findsOneWidget);
      expect(find.text('Almuerzo'), findsOneWidget);
      expect(find.text('A débito'), findsOneWidget);

      await harness.dispose();
    });

    testWidgets(
        'Filtrar por kind=income deja solo los 2 ingresos visibles',
        (tester) async {
      final harness = await pumpFincoreApp(tester, seed: seedMixedEntries);
      await pushEntries(tester);

      // Abrir el bottom sheet tocando el icon filter en el AppBar.
      await tester.tap(find.byTooltip('Filtros'));
      await tester.pumpAndSettle();

      // En el bottom sheet aparecen los chips de kind. Tap "Ingreso".
      expect(find.text('Tipo'), findsOneWidget);
      await tester.tap(find.text('Ingreso'));
      await tester.pumpAndSettle();

      // Aplicar.
      await tester.tap(find.text('Aplicar'));
      await tester.pumpAndSettle();

      // Solo los 2 income.
      expect(find.text('Salario'), findsOneWidget);
      expect(find.text('Reembolso'), findsOneWidget);
      expect(find.text('Café'), findsNothing);
      expect(find.text('Almuerzo'), findsNothing);
      expect(find.text('A débito'), findsNothing);

      await harness.dispose();
    });

    testWidgets(
        'Limpiar filtro restaura los 5 entries',
        (tester) async {
      final harness = await pumpFincoreApp(tester, seed: seedMixedEntries);
      await pushEntries(tester);

      // Aplicar filtro de Ingreso primero.
      await tester.tap(find.byTooltip('Filtros'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ingreso'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aplicar'));
      await tester.pumpAndSettle();
      expect(find.text('Café'), findsNothing);

      // Re-abrir filtros y tocar "Todos".
      await tester.tap(find.byTooltip('Filtros (activos)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Todos'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aplicar'));
      await tester.pumpAndSettle();

      // Los 5 vuelven.
      expect(find.text('Salario'), findsOneWidget);
      expect(find.text('Café'), findsOneWidget);
      expect(find.text('A débito'), findsOneWidget);

      await harness.dispose();
    });
  });
}
