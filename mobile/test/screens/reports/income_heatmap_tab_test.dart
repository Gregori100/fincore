import 'package:fincore/screens/reports/income_heatmap_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/widget_test_harness.dart';

/// Widget tests del `IncomeHeatmapTab`. Sprint
/// `flutter-reports-income-heatmap-v1` (RF-014).
void main() {
  Future<void> openIncomeHeatmapTab(WidgetTester tester) async {
    final ctx = tester.element(find.byType(Scaffold).first);
    GoRouter.of(ctx).push('/reports');
    await tester.pumpAndSettle();
    // El tab es el 11º y último; el TabBar es scrollable.
    await tester.dragUntilVisible(
      find.widgetWithText(Tab, 'Heatmap ingresos'),
      find.byType(TabBar),
      const Offset(-100, 0),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(Tab, 'Heatmap ingresos'));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'WT-IHM01: BD vacía → tab monta con banner "Sin ingresos registrados"',
      (tester) async {
    final harness = await pumpFincoreApp(tester);
    await openIncomeHeatmapTab(tester);

    expect(find.byType(IncomeHeatmapTab), findsOneWidget);
    expect(find.text('${DateTime.now().year}'), findsOneWidget);
    // Consolidación en año vacío: banner presente, leyenda oculta.
    expect(
      find.textContaining('Sin ingresos registrados en este año'),
      findsOneWidget,
    );

    await harness.dispose();
  });

  testWidgets(
      'WT-IHM02: seed con 1 income → subtexto "1 día con ingreso" + leyenda',
      (tester) async {
    final now = DateTime.now();
    final harness = await pumpFincoreApp(
      tester,
      seed: (db, deps) async {
        final catSueldo = await deps.categoriesDao.create(
          name: 'SueldoIHM_WT',
          appliesTo: 'income',
          colorSlug: 'green',
          iconSlug: 'briefcase',
        );
        final bolsa = (await deps.accountsDao.listAll())
            .firstWhere((a) => a.type == 'cash');
        await deps.entriesDao.registerIncome(
          accountDestinationId: bolsa.id,
          amount: 5000,
          categoryId: catSueldo,
          occurredAt: DateTime(now.year, now.month, 10, 12),
          description: 'IncomeHeatmapWT',
        );
      },
    );
    await openIncomeHeatmapTab(tester);

    expect(find.textContaining('1 día con ingreso'), findsOneWidget);
    // Con al menos 1 ingreso, la leyenda sí se muestra.
    expect(find.text('Menos'), findsOneWidget);
    expect(find.text('Más'), findsOneWidget);

    await harness.dispose();
  });

  testWidgets(
      'WT-IHM03: tap en la flecha izquierda cambia el año',
      (tester) async {
    final currentYear = DateTime.now().year;
    final prevYear = currentYear - 1;
    final harness = await pumpFincoreApp(tester);
    await openIncomeHeatmapTab(tester);

    expect(find.text('$currentYear'), findsOneWidget);
    await tester.tap(find.byTooltip('Año anterior'));
    await tester.pumpAndSettle();
    expect(find.text('$prevYear'), findsOneWidget);
    expect(find.text('$currentYear'), findsNothing);

    await harness.dispose();
  });

  // T3 del quality review del gastos aplicado acá: verificar que el
  // drill-down filtra por kinds=['income'] y NO incluye expenses del
  // mismo día.
  testWidgets(
      'WT-IHM04: tap en mini abre sheet + tap en día → drill-down solo ingresos',
      (tester) async {
    final now = DateTime.now();
    final targetDay = DateTime(now.year, now.month, 15);
    final harness = await pumpFincoreApp(
      tester,
      seed: (db, deps) async {
        final catSueldo = await deps.categoriesDao.create(
          name: 'SueldoIHM_DrillDown',
          appliesTo: 'income',
          colorSlug: 'green',
          iconSlug: 'briefcase',
        );
        final catComida = await deps.categoriesDao.create(
          name: 'ComidaIHM_DrillDown',
          appliesTo: 'expense',
          colorSlug: 'red',
          iconSlug: 'shopping-cart',
        );
        final bolsa = (await deps.accountsDao.listAll())
            .firstWhere((a) => a.type == 'cash');
        // 1 income que SÍ debe aparecer.
        await deps.entriesDao.registerIncome(
          accountDestinationId: bolsa.id,
          amount: 3000,
          categoryId: catSueldo,
          occurredAt: DateTime(
            targetDay.year,
            targetDay.month,
            targetDay.day,
            10,
          ),
          description: 'IncomeHeatmapDrillDownIncome',
        );
        // 1 expense el MISMO día que NO debe aparecer.
        await deps.entriesDao.registerExpense(
          accountOriginId: bolsa.id,
          amount: 200,
          categoryId: catComida,
          occurredAt: DateTime(
            targetDay.year,
            targetDay.month,
            targetDay.day,
            15,
          ),
          description: 'IncomeHeatmapDrillDownExpense',
        );
      },
    );
    await openIncomeHeatmapTab(tester);

    // Tap en el mini del mes actual.
    const monthLabels = [
      'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
      'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'
    ];
    final label = monthLabels[targetDay.month - 1];
    await tester.dragUntilVisible(
      find.text(label),
      find.byType(IncomeHeatmapTab),
      const Offset(0, -100),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();

    // Tap en el día 15 dentro del sheet.
    final dayLabel = find.text('${targetDay.day}');
    expect(dayLabel, findsWidgets);
    await tester.tap(dayLabel.first);
    await tester.pumpAndSettle();

    // Drill-down: la lista muestra el income y NO el expense del mismo día.
    expect(
      find.text('IncomeHeatmapDrillDownIncome'),
      findsOneWidget,
      reason: 'El income debe aparecer en el drill-down.',
    );
    expect(
      find.text('IncomeHeatmapDrillDownExpense'),
      findsNothing,
      reason: 'El expense NO debe aparecer (kinds filtra a income).',
    );

    await harness.dispose();
  });
}
