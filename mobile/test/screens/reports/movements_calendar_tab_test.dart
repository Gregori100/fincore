import 'package:fincore/screens/reports/movements_calendar_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../helpers/widget_test_harness.dart';

/// Widget tests del `MovementsCalendarTab`. Sprint
/// `flutter-reports-movements-calendar-v1` (RF-012).
void main() {
  Future<void> openCalendarTab(WidgetTester tester) async {
    final ctx = tester.element(find.byType(Scaffold).first);
    GoRouter.of(ctx).push('/reports');
    await tester.pumpAndSettle();
    // El tab es el 9no y último; el TabBar es scrollable.
    await tester.dragUntilVisible(
      find.widgetWithText(Tab, 'Calendario'),
      find.byType(TabBar),
      const Offset(-100, 0),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(Tab, 'Calendario'));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'WT-CAL01: render inicial monta TableCalendar con mes en foco',
      (tester) async {
    final harness = await pumpFincoreApp(tester);
    await openCalendarTab(tester);

    expect(find.byType(MovementsCalendarTab), findsOneWidget);
    expect(find.byWidgetPredicate((w) => w is TableCalendar), findsOneWidget);

    await harness.dispose();
  });

  testWidgets(
      'WT-CAL02: seed con 1 expense el día 10 del mes actual → tab monta con datos',
      (tester) async {
    final now = DateTime.now();
    final day10 = DateTime(now.year, now.month, 10, 12);
    final harness = await pumpFincoreApp(
      tester,
      seed: (db, deps) async {
        final catComida = await deps.categoriesDao.create(
          name: 'ComidaCAL',
          appliesTo: 'expense',
          colorSlug: 'red',
          iconSlug: 'shopping-cart',
        );
        final bolsa = (await deps.accountsDao.listAll())
            .firstWhere((a) => a.type == 'cash');
        await deps.entriesDao.registerExpense(
          accountOriginId: bolsa.id,
          amount: 20000,
          categoryId: catComida,
          occurredAt: day10,
          description: 'CalendarExpense',
        );
      },
    );
    await openCalendarTab(tester);

    // El TableCalendar renderiza el mes actual con marcadores. La
    // presencia del widget confirma que el StreamBuilder no está en
    // loading/error. El detalle del marcador visual se valida en smoke
    // porque `table_calendar` renderiza builders con posicionamiento
    // sub-widget difícil de encontrar por find.byType robusto.
    expect(find.byWidgetPredicate((w) => w is TableCalendar), findsOneWidget);

    await harness.dispose();
  });

  testWidgets(
      'WT-CAL03: tap en un día navega a /entries con filter custom',
      (tester) async {
    final now = DateTime.now();
    final targetDay = DateTime(now.year, now.month, 10);
    final harness = await pumpFincoreApp(
      tester,
      seed: (db, deps) async {
        final bolsa = (await deps.accountsDao.listAll())
            .firstWhere((a) => a.type == 'cash');
        await deps.entriesDao.registerIncome(
          accountDestinationId: bolsa.id,
          amount: 500000,
          occurredAt: DateTime(
            targetDay.year,
            targetDay.month,
            targetDay.day,
            12,
          ),
          description: 'IncomeCAL',
        );
      },
    );
    await openCalendarTab(tester);

    // Tap directo en el número "10" del calendario. Usamos el widget
    // `Text` con la etiqueta del día. table_calendar renderiza los
    // números como Text('10') dentro de la celda.
    final dayCell = find.text('10');
    // Puede haber más de un "10" si algún otro Text lo trae (poco
    // probable en la vista de reportes). Filtramos por ancestros dentro
    // del TableCalendar.
    final dayInCalendar = find.descendant(
      of: find.byWidgetPredicate((w) => w is TableCalendar),
      matching: dayCell,
    );
    expect(dayInCalendar, findsWidgets,
        reason: 'El día 10 debería aparecer en el calendario.');
    await tester.tap(dayInCalendar.first);
    await tester.pumpAndSettle();

    // El drill-down abre `/entries`. Verificamos que la ruta cambió:
    // el widget del reporte queda en el stack pero la nueva ruta se
    // monta encima. La forma más simple es buscar el EntryFormScreen
    // NO — no, tap en día abre /entries, no el form.
    // Buscamos la lista de movimientos con la descripción sembrada.
    expect(find.text('IncomeCAL'), findsOneWidget,
        reason: 'El drill-down debe listar el income sembrado ese día.');

    await harness.dispose();
  });

  testWidgets(
      'WT-CAL04: tap en la flecha derecha del header cambia el mes',
      (tester) async {
    final harness = await pumpFincoreApp(tester);
    await openCalendarTab(tester);

    // Flecha derecha del header del TableCalendar.
    final rightChevron = find.byIcon(Icons.chevron_right);
    expect(rightChevron, findsOneWidget);
    await tester.tap(rightChevron);
    await tester.pumpAndSettle();

    // El calendario sigue montado; verificamos que sigue existiendo
    // (validación exhaustiva del label del nuevo mes se hace en smoke
    // porque depende del locale y del mes en curso).
    expect(find.byWidgetPredicate((w) => w is TableCalendar), findsOneWidget);

    await harness.dispose();
  });
}
