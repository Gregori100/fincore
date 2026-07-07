import 'package:fincore/screens/reports/credit_cards_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/widget_test_harness.dart';

/// Widget tests del `CreditCardsTab`. Sprint
/// `flutter-reports-credit-cards-v1`.
///
/// Cubre: empty state con CTA, data completa, badges, reactividad básica.
void main() {
  testWidgets('WT-01: sin tarjetas activas → empty state con CTA',
      (tester) async {
    final harness = await pumpFincoreApp(tester);
    // Navegar al reporte y seleccionar el tab "Tarjetas".
    final ctx = tester.element(find.byType(Scaffold).first);
    GoRouter.of(ctx).push('/reports');
    await tester.pumpAndSettle();

    // El seed default no crea tarjetas credit; solo Bolsa. Encontrar el tab
    // "Tarjetas" y tapearlo.
    // El TabBar es scrollable; asegurarse de que "Tarjetas" esté visible
    // antes del tap (está al final de los 6 tabs).
    await tester.dragUntilVisible(
      find.widgetWithText(Tab, 'Tarjetas'),
      find.byType(TabBar),
      const Offset(-100, 0),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(Tab, 'Tarjetas'));
    await tester.pumpAndSettle();

    expect(find.byType(CreditCardsTab), findsOneWidget);
    expect(find.text('No hay tarjetas de crédito todavía'), findsOneWidget);
    expect(find.text('Agregar tarjeta'), findsOneWidget);

    await harness.dispose();
  });

  testWidgets('WT-02: con tarjetas activas → renderea cards con datos',
      (tester) async {
    final harness = await pumpFincoreApp(
      tester,
      seed: (db, deps) async {
        await deps.accountsDao.create(
          name: 'AmexOro',
          type: 'credit',
          creditLimit: 20000,
          closingDay: 15,
          paymentDay: 5,
          minimumPaymentPct: 0.05,
        );
      },
    );
    final ctx = tester.element(find.byType(Scaffold).first);
    GoRouter.of(ctx).push('/reports');
    await tester.pumpAndSettle();

    // El TabBar es scrollable; asegurarse de que "Tarjetas" esté visible
    // antes del tap (está al final de los 6 tabs).
    await tester.dragUntilVisible(
      find.widgetWithText(Tab, 'Tarjetas'),
      find.byType(TabBar),
      const Offset(-100, 0),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(Tab, 'Tarjetas'));
    await tester.pumpAndSettle();

    expect(find.byType(CreditCardsTab), findsOneWidget);
    expect(find.text('AmexOro'), findsOneWidget);
    expect(find.text('Deuda'), findsOneWidget);
    expect(find.text('Límite'), findsOneWidget);
    expect(find.text('Disponible'), findsOneWidget);
    expect(find.text('Próximo corte'), findsOneWidget);
    expect(find.text('Próximo pago'), findsOneWidget);

    await harness.dispose();
  });

  testWidgets(
      'WT-03: tarjeta sin minimumPaymentPct → NO muestra línea "Pago mínimo"',
      (tester) async {
    final harness = await pumpFincoreApp(
      tester,
      seed: (db, deps) async {
        await deps.accountsDao.create(
          name: 'BasicaCard',
          type: 'credit',
          creditLimit: 10000,
          closingDay: 15,
          paymentDay: 5,
          // sin minimumPaymentPct
        );
      },
    );
    final ctx = tester.element(find.byType(Scaffold).first);
    GoRouter.of(ctx).push('/reports');
    await tester.pumpAndSettle();
    // El TabBar es scrollable; asegurarse de que "Tarjetas" esté visible
    // antes del tap (está al final de los 6 tabs).
    await tester.dragUntilVisible(
      find.widgetWithText(Tab, 'Tarjetas'),
      find.byType(TabBar),
      const Offset(-100, 0),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(Tab, 'Tarjetas'));
    await tester.pumpAndSettle();

    expect(find.text('BasicaCard'), findsOneWidget);
    expect(find.text('Pago mínimo estimado'), findsNothing);

    await harness.dispose();
  });

  testWidgets(
      'WT-04: tarjeta sin closingDay → "—" en próximo corte, sin badge',
      (tester) async {
    final harness = await pumpFincoreApp(
      tester,
      seed: (db, deps) async {
        await deps.accountsDao.create(
          name: 'SinCorte',
          type: 'credit',
          creditLimit: 5000,
          // sin closingDay ni paymentDay
        );
      },
    );
    final ctx = tester.element(find.byType(Scaffold).first);
    GoRouter.of(ctx).push('/reports');
    await tester.pumpAndSettle();
    // El TabBar es scrollable; asegurarse de que "Tarjetas" esté visible
    // antes del tap (está al final de los 6 tabs).
    await tester.dragUntilVisible(
      find.widgetWithText(Tab, 'Tarjetas'),
      find.byType(TabBar),
      const Offset(-100, 0),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(Tab, 'Tarjetas'));
    await tester.pumpAndSettle();

    expect(find.text('SinCorte'), findsOneWidget);
    // Debe mostrar guiones en próximo corte/pago (2 "—").
    expect(find.text('—'), findsWidgets);

    await harness.dispose();
  });

  testWidgets(
      'WT-06: tarjeta excedida → badge "Excedido por \$X" visible',
      (tester) async {
    final harness = await pumpFincoreApp(
      tester,
      seed: (db, deps) async {
        final id = await deps.accountsDao.create(
          name: 'ExcedidaCard',
          type: 'credit',
          creditLimit: 1000,
          closingDay: 15,
          paymentDay: 5,
        );
        // Registrar cargo que excede el límite (1500 > 1000).
        await deps.entriesDao.registerCreditExpense(
          accountOriginId: id,
          amount: 1500,
          occurredAt: DateTime.now(),
        );
      },
    );
    final ctx = tester.element(find.byType(Scaffold).first);
    GoRouter.of(ctx).push('/reports');
    await tester.pumpAndSettle();
    await tester.dragUntilVisible(
      find.widgetWithText(Tab, 'Tarjetas'),
      find.byType(TabBar),
      const Offset(-100, 0),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(Tab, 'Tarjetas'));
    await tester.pumpAndSettle();

    expect(find.text('ExcedidaCard'), findsOneWidget);
    // Badge "Excedido por $X" con formato de monto.
    expect(find.textContaining('Excedido por'), findsOneWidget);

    await harness.dispose();
  });

  testWidgets(
      'WT-15: ReportsScreen renderea 6 tabs (incluye "Tarjetas")',
      (tester) async {
    final harness = await pumpFincoreApp(tester);
    final ctx = tester.element(find.byType(Scaffold).first);
    GoRouter.of(ctx).push('/reports');
    await tester.pumpAndSettle();

    expect(find.byType(Tab), findsNWidgets(9));
    expect(find.widgetWithText(Tab, 'Gasto por categoría'), findsOneWidget);
    expect(find.widgetWithText(Tab, 'Tarjetas'), findsOneWidget);

    await harness.dispose();
  });

  testWidgets(
      'WT-05: tarjeta con debt=0 → badge "Sin deuda", sin pago mínimo',
      (tester) async {
    final harness = await pumpFincoreApp(
      tester,
      seed: (db, deps) async {
        await deps.accountsDao.create(
          name: 'ClearCard',
          type: 'credit',
          creditLimit: 10000,
          closingDay: 15,
          paymentDay: 5,
          minimumPaymentPct: 0.05,
        );
      },
    );
    final ctx = tester.element(find.byType(Scaffold).first);
    GoRouter.of(ctx).push('/reports');
    await tester.pumpAndSettle();
    // El TabBar es scrollable; asegurarse de que "Tarjetas" esté visible
    // antes del tap (está al final de los 6 tabs).
    await tester.dragUntilVisible(
      find.widgetWithText(Tab, 'Tarjetas'),
      find.byType(TabBar),
      const Offset(-100, 0),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(Tab, 'Tarjetas'));
    await tester.pumpAndSettle();

    expect(find.text('ClearCard'), findsOneWidget);
    expect(find.text('Sin deuda'), findsOneWidget);
    // Sin línea de pago mínimo porque debt=0.
    expect(find.text('Pago mínimo estimado'), findsNothing);

    await harness.dispose();
  });
}
