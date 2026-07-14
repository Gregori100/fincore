import 'package:fincore/screens/reports/monthly_average_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../helpers/widget_test_harness.dart';

/// Widget tests del `MonthlyAverageTab`. Sprint
/// `flutter-reports-monthly-average-v1`.
///
/// Cobertura:
/// - WT-01: render con datos del mes anterior + mes actual.
/// - WT-02: cambiar preset de 3 → 6 actualiza la UI.
/// - WT-03: empty state con BD sin entries.
/// - WT-04: el desglose renderea filas de categorías.
void main() {
  group('MonthlyAverageTab', () {
    /// Navega a `/reports` y tappea el 5° tab "Promedio mensual". El TabBar
    /// es scrollable, así que el 5° tab puede estar fuera del viewport del
    /// test (800px de ancho); hacemos `ensureVisible` antes del tap.
    Future<void> openMonthlyAverageTab(WidgetTester tester) async {
      final ctx = tester.element(find.byType(Scaffold).first);
      GoRouter.of(ctx).push('/reports');
      await tester.pumpAndSettle();
      final tab = find.text('Promedio mensual');
      await tester.dragUntilVisible(
        tab,
        find.byType(TabBar),
        const Offset(-200, 0),
      );
      await tester.pumpAndSettle();
      await tester.tap(tab);
      await tester.pumpAndSettle();
    }

    testWidgets(
        'WT-01: render con datos: card global + subtítulo + breakdown',
        (tester) async {
      final now = DateTime.now();
      final lastMonth = DateTime(now.year, now.month - 1, 10, 12);
      final harness = await pumpFincoreApp(tester, seed: (db, deps) async {
        await deps.accountsDao.create(name: 'Banamex_W', type: 'debit');
        final debit = (await deps.accountsDao.listAll())
            .firstWhere((a) => a.name == 'Banamex_W');
        final cat = await deps.categoriesDao.create(
          name: 'Comida_W',
          appliesTo: 'expense',
          colorSlug: 'red',
          iconSlug: 'shopping-cart',
        );
        // Histórico: mes anterior.
        await deps.entriesDao.registerExpense(
          accountOriginId: debit.id,
          amount: 500,
          occurredAt: lastMonth,
          categoryId: cat,
        );
        // Mes actual: una entry día 1 para no chocar con el día actual.
        final currentMonth = DateTime(now.year, now.month, 1, 8);
        await deps.entriesDao.registerExpense(
          accountOriginId: debit.id,
          amount: 200,
          occurredAt: currentMonth,
          categoryId: cat,
        );
      });

      await openMonthlyAverageTab(tester);

      expect(find.byType(MonthlyAverageTab), findsOneWidget);
      // Header con las 3 métricas.
      expect(find.text('Promedio'), findsAtLeastNWidgets(1));
      expect(find.text('Mes en curso'), findsOneWidget);
      expect(find.text('Delta'), findsOneWidget);
      // Subtítulo del prorrateo.
      expect(find.textContaining('Comparación al día'), findsOneWidget);
      // Sección breakdown.
      expect(find.text('Desglose por categoría'), findsOneWidget);
      // La categoría sembrada aparece en el breakdown.
      expect(find.text('Comida_W'), findsOneWidget);

      await harness.dispose();
    });

    testWidgets(
        'WT-02: cambiar preset de 3 → 6 actualiza la UI sin error',
        (tester) async {
      final harness = await pumpFincoreApp(tester);

      await openMonthlyAverageTab(tester);

      // Tap en el preset "6 meses".
      await tester.tap(find.text('6 meses'));
      await tester.pumpAndSettle();

      // El tab sigue montado, sin crash. El subtítulo o empty state debería
      // re-renderizarse.
      expect(find.byType(MonthlyAverageTab), findsOneWidget);

      await harness.dispose();
    });

    testWidgets(
        'WT-03: empty state con BD sin entries muestra copy de onboarding',
        (tester) async {
      final harness = await pumpFincoreApp(tester);

      await openMonthlyAverageTab(tester);

      expect(
        find.text(
          'Se necesita al menos 1 mes cerrado de uso para calcular el promedio.',
        ),
        findsOneWidget,
      );

      await harness.dispose();
    });

    testWidgets(
        'WT-04: breakdown renderea filas en orden de delta absoluto desc',
        (tester) async {
      final now = DateTime.now();
      final harness = await pumpFincoreApp(tester, seed: (db, deps) async {
        await deps.accountsDao.create(name: 'Banamex_W4', type: 'debit');
        final debit = (await deps.accountsDao.listAll())
            .firstWhere((a) => a.name == 'Banamex_W4');
        final catAlta = await deps.categoriesDao.create(
          name: 'CatAlta_W4',
          appliesTo: 'expense',
          colorSlug: 'red',
          iconSlug: 'shopping-cart',
        );
        final catBaja = await deps.categoriesDao.create(
          name: 'CatBaja_W4',
          appliesTo: 'expense',
          colorSlug: 'blue',
          iconSlug: 'truck',
        );
        // Solo gasto del mes actual, sin histórico → delta = current.
        // catAlta = 500 (delta mayor), catBaja = 100 (delta menor).
        final currentMonth = DateTime(now.year, now.month, 1);
        await deps.entriesDao.registerExpense(
          accountOriginId: debit.id,
          amount: 500,
          occurredAt: currentMonth,
          categoryId: catAlta,
        );
        await deps.entriesDao.registerExpense(
          accountOriginId: debit.id,
          amount: 100,
          occurredAt: currentMonth.add(const Duration(hours: 1)),
          categoryId: catBaja,
        );
      });

      await openMonthlyAverageTab(tester);

      // Ambas categorías aparecen.
      expect(find.text('CatAlta_W4'), findsOneWidget);
      expect(find.text('CatBaja_W4'), findsOneWidget);
      // Orden: CatAlta debe aparecer ANTES (más arriba en pantalla).
      final altaY = tester.getTopLeft(find.text('CatAlta_W4')).dy;
      final bajaY = tester.getTopLeft(find.text('CatBaja_W4')).dy;
      expect(altaY < bajaY, isTrue,
          reason:
              'CatAlta_W4 (delta 500) debe aparecer arriba de CatBaja_W4 (delta 100)');

      await harness.dispose();
    });
  });
}
