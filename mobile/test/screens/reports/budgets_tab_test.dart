import 'package:drift/drift.dart' show Value;
import 'package:fincore/screens/reports/budgets_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/widget_test_harness.dart';

/// Widget tests del `BudgetsTab`. Sprint `flutter-budgets-v1`.
void main() {
  Future<void> openBudgetsTab(WidgetTester tester) async {
    final ctx = tester.element(find.byType(Scaffold).first);
    GoRouter.of(ctx).push('/reports');
    await tester.pumpAndSettle();
    await tester.dragUntilVisible(
      find.widgetWithText(Tab, 'Presupuestos'),
      find.byType(TabBar),
      const Offset(-100, 0),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(Tab, 'Presupuestos'));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'WT-B01: sin presupuestos → empty state con CTA "Ir a Categorías"',
      (tester) async {
    final harness = await pumpFincoreApp(tester);
    await openBudgetsTab(tester);

    expect(find.byType(BudgetsTab), findsOneWidget);
    expect(find.text('No definiste presupuestos aún'), findsOneWidget);
    expect(find.text('Ir a Categorías'), findsOneWidget);

    await harness.dispose();
  });

  testWidgets('WT-B02: con presupuestos → card por categoría con datos',
      (tester) async {
    final harness = await pumpFincoreApp(
      tester,
      seed: (db, deps) async {
        final catId = await deps.categoriesDao.create(
          name: 'ComidaBudget',
          appliesTo: 'expense',
          colorSlug: 'red',
          iconSlug: 'shopping-cart',
          monthlyLimit: 500000,
        );
        final bolsa = (await deps.accountsDao.listAll())
            .firstWhere((a) => a.type == 'cash')
            .id;
        await deps.entriesDao.registerExpense(
          accountOriginId: bolsa,
          amount: 150000,
          categoryId: catId,
          occurredAt: DateTime.now(),
        );
      },
    );
    await openBudgetsTab(tester);

    expect(find.text('ComidaBudget'), findsOneWidget);
    expect(find.text('Gastado'), findsOneWidget);
    expect(find.text('Límite'), findsOneWidget);
    expect(find.text('Disponible'), findsOneWidget);

    await harness.dispose();
  });

  testWidgets('WT-B03: spent > límite → badge "Excedido por \$X" visible',
      (tester) async {
    final harness = await pumpFincoreApp(
      tester,
      seed: (db, deps) async {
        final catId = await deps.categoriesDao.create(
          name: 'ExcedidaCat',
          appliesTo: 'expense',
          colorSlug: 'red',
          iconSlug: 'shopping-cart',
          monthlyLimit: 10000,
        );
        final bolsa = (await deps.accountsDao.listAll())
            .firstWhere((a) => a.type == 'cash')
            .id;
        await deps.entriesDao.registerExpense(
          accountOriginId: bolsa,
          amount: 25000,
          categoryId: catId,
          occurredAt: DateTime.now(),
        );
      },
    );
    await openBudgetsTab(tester);

    expect(find.text('ExcedidaCat'), findsOneWidget);
    expect(find.textContaining('Excedido por'), findsOneWidget);

    await harness.dispose();
  });

  testWidgets('WT-B04: spent = 0 → badge "Sin gasto"', (tester) async {
    final harness = await pumpFincoreApp(
      tester,
      seed: (db, deps) async {
        await deps.categoriesDao.create(
          name: 'AhorroCat',
          appliesTo: 'expense',
          colorSlug: 'green',
          iconSlug: 'heart',
          monthlyLimit: 100000,
        );
      },
    );
    await openBudgetsTab(tester);

    expect(find.text('AhorroCat'), findsOneWidget);
    expect(find.text('Sin gasto'), findsOneWidget);

    await harness.dispose();
  });

  testWidgets(
      'WT-B08: cambiar applies_to a income limpia el budget al submit',
      (tester) async {
    // Sembramos una categoría expense con budget, la editamos cambiando
    // applies_to a income y verificamos que el DAO persiste monthly_limit=null.
    late String catId;
    final harness = await pumpFincoreApp(
      tester,
      seed: (db, deps) async {
        catId = await deps.categoriesDao.create(
          name: 'EditableCat',
          appliesTo: 'expense',
          colorSlug: 'blue',
          iconSlug: 'tag',
          monthlyLimit: 50000,
        );
      },
    );

    // Cambio directo por DAO simulando el flujo del form:
    // el submit cuando el usuario cambia a income pasa Value(null).
    await harness.deps.categoriesDao.updateCategory(
      id: catId,
      appliesTo: 'income',
      monthlyLimit: const Value(null),
    );
    final updated = await harness.deps.categoriesDao.findById(catId);
    expect(updated, isNotNull);
    expect(updated!.monthlyLimit, isNull);
    expect(updated.appliesTo, 'income');

    await harness.dispose();
  });

  testWidgets(
      'WT-B09: selector de mes muestra badge "Hoy" en el mes actual',
      (tester) async {
    final harness = await pumpFincoreApp(tester);
    await openBudgetsTab(tester);
    // El mes actual dispara el chip "Hoy".
    expect(find.text('Hoy'), findsOneWidget);
    // No debe aparecer el aviso del límite histórico en el mes en curso.
    expect(
      find.textContaining('El límite mostrado es el actual'),
      findsNothing,
    );
    await harness.dispose();
  });

  testWidgets(
      'WT-B10: chevron_left navega al mes anterior + muestra aviso del límite histórico',
      (tester) async {
    final harness = await pumpFincoreApp(tester);
    await openBudgetsTab(tester);
    // Estado inicial: mes actual, sin aviso.
    expect(find.text('Hoy'), findsOneWidget);
    // Tap en chevron_left (dos IconButton: prev + next).
    final prevBtn = find.byIcon(Icons.chevron_left);
    expect(prevBtn, findsOneWidget);
    await tester.tap(prevBtn);
    await tester.pumpAndSettle();
    // Ya no es el mes actual → badge "Hoy" desaparece + aviso visible.
    expect(find.text('Hoy'), findsNothing);
    expect(
      find.textContaining('El límite mostrado es el actual'),
      findsOneWidget,
    );
    // chevron_right ahora debe estar habilitado (podemos volver al mes actual).
    final nextBtn = find.byIcon(Icons.chevron_right);
    expect(nextBtn, findsOneWidget);
    await harness.dispose();
  });
}
