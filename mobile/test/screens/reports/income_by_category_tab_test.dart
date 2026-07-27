import 'package:fincore/screens/reports/income_by_category_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/widget_test_harness.dart';

/// Widget tests del `IncomeByCategoryTab`. Sprint
/// `flutter-reports-income-by-category-v1` (RF-005..011).
void main() {
  Future<void> openIncomeTab(WidgetTester tester) async {
    final ctx = tester.element(find.byType(Scaffold).first);
    GoRouter.of(ctx).push('/reports');
    await tester.pumpAndSettle();
    // El tab es el 8vo y último; el TabBar es scrollable.
    await tester.dragUntilVisible(
      find.widgetWithText(Tab, 'Ingreso por categoría'),
      find.byType(TabBar),
      const Offset(-100, 0),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(Tab, 'Ingreso por categoría'));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'WT-I01: sin incomes en el rango → empty state con texto contextual',
      (tester) async {
    final harness = await pumpFincoreApp(tester);
    await openIncomeTab(tester);

    expect(find.byType(IncomeByCategoryTab), findsOneWidget);
    expect(
      find.text('No se registraron ingresos en el período'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.trending_up), findsWidgets);

    await harness.dispose();
  });

  testWidgets(
      'WT-I02: con 2 incomes en categorías distintas → 2 buckets con "Total del período"',
      (tester) async {
    final harness = await pumpFincoreApp(
      tester,
      seed: (db, deps) async {
        final catSueldo = await deps.categoriesDao.create(
          name: 'SueldoWT',
          appliesTo: 'income',
          colorSlug: 'green',
          iconSlug: 'briefcase',
        );
        final catFreelance = await deps.categoriesDao.create(
          name: 'FreelanceWT',
          appliesTo: 'income',
          colorSlug: 'blue',
          iconSlug: 'briefcase',
        );
        final bolsa = (await deps.accountsDao.listAll())
            .firstWhere((a) => a.type == 'cash')
            .id;
        final now = DateTime.now();
        // Ambos incomes dentro del mes actual (default: thisMonth).
        await deps.entriesDao.registerIncome(
          accountDestinationId: bolsa,
          amount: 3000000,
          categoryId: catSueldo,
          occurredAt: DateTime(now.year, now.month, 5),
        );
        await deps.entriesDao.registerIncome(
          accountDestinationId: bolsa,
          amount: 500000,
          categoryId: catFreelance,
          occurredAt: DateTime(now.year, now.month, 10),
        );
      },
    );
    await openIncomeTab(tester);

    // Total card + buckets visibles.
    expect(find.text('Total del período'), findsOneWidget);
    expect(find.text('SueldoWT'), findsOneWidget);
    expect(find.text('FreelanceWT'), findsOneWidget);
    expect(find.text('2 movimientos'), findsOneWidget);

    await harness.dispose();
  });

  testWidgets(
      'WT-I03: income con category_id=null → aparece como "Sin categoría"',
      (tester) async {
    final harness = await pumpFincoreApp(
      tester,
      seed: (db, deps) async {
        final bolsa = (await deps.accountsDao.listAll())
            .firstWhere((a) => a.type == 'cash')
            .id;
        final now = DateTime.now();
        await deps.entriesDao.registerIncome(
          accountDestinationId: bolsa,
          amount: 50000,
          occurredAt: DateTime(now.year, now.month, 15),
        );
      },
    );
    await openIncomeTab(tester);

    expect(find.text('Sin categoría'), findsOneWidget);

    await harness.dispose();
  });
}
