import 'package:fincore/screens/weekly_budgets/calendar_screen.dart';
import 'package:fincore/theme/fincore_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../helpers/widget_test_harness.dart';

/// Widget tests de `BudgetCalendarScreen` (sprint `flutter-weekly-budgets-v1`
/// — vista calendario del módulo de presupuestos semanales).
///
/// Convención documentada en otros tests de `/budgets`: el harness arranca
/// en `/dashboard` y cada test pushea `/budgets/calendar` con
/// `context.push(...)` en vez de pasar `initialRoute` (que reemplaza el
/// stack y cuelga `pumpAndSettle`).
void main() {
  Future<void> pushCalendar(WidgetTester tester) async {
    final ctx = tester.element(find.byType(Scaffold));
    GoRouter.of(ctx).push('/budgets/calendar');
    await tester.pumpAndSettle();
  }

  /// Predicado del dot pintado por `_dot()`: `Container` 4x4 con
  /// `BoxDecoration.color == FincoreColors.accent` (opacidad 1). El
  /// `todayDecoration` del calendario también usa `accent` pero con alpha
  /// 0.25, así que el chequeo de color exacto no da falsos positivos.
  Finder dotFinder() {
    return find.byWidgetPredicate((w) {
      if (w is! Container) return false;
      final decoration = w.decoration;
      if (decoration is! BoxDecoration) return false;
      return decoration.color == FincoreColors.accent &&
          decoration.shape == BoxShape.circle;
    });
  }

  testWidgets('CS-01: sin presupuestos, monta el grid del mes actual sin dots',
      (tester) async {
    final harness = await pumpFincoreApp(tester);
    await pushCalendar(tester);

    expect(find.byType(BudgetCalendarScreen), findsOneWidget);
    expect(find.byWidgetPredicate((w) => w is TableCalendar), findsOneWidget);
    expect(dotFinder(), findsNothing);

    await harness.dispose();
  });

  testWidgets(
      'CS-02: con 1 presupuesto en el mes, aparece un dot en el día '
      'correspondiente', (tester) async {
    final now = DateTime.now();
    // Día 10: lejos de los bordes del mes, evita ambigüedad con "outside
    // days" de mes previo/siguiente que table_calendar renderiza de relleno.
    final targetDay = DateTime(now.year, now.month, 10);
    final harness = await pumpFincoreApp(
      tester,
      seed: (db, deps) async {
        await deps.weeklyBudgetsDao.createBudget(
          weekStartDate: targetDay,
          label: 'PresuCalendario',
        );
      },
    );
    await pushCalendar(tester);

    expect(dotFinder(), findsOneWidget);

    await harness.dispose();
  });

  testWidgets(
      'CS-03: tap en un día con 1 presupuesto navega a su detalle',
      (tester) async {
    final now = DateTime.now();
    final targetDay = DateTime(now.year, now.month, 10);
    final harness = await pumpFincoreApp(
      tester,
      seed: (db, deps) async {
        await deps.weeklyBudgetsDao.createBudget(
          weekStartDate: targetDay,
          label: 'PresuCalendario',
        );
      },
    );
    await pushCalendar(tester);

    final dayCell = find.text('10');
    final dayInCalendar = find.descendant(
      of: find.byWidgetPredicate((w) => w is TableCalendar),
      matching: dayCell,
    );
    expect(dayInCalendar, findsWidgets,
        reason: 'El día 10 debería aparecer en el calendario.');
    await tester.tap(dayInCalendar.first);
    await tester.pumpAndSettle();

    expect(find.text('PresuCalendario'), findsOneWidget,
        reason: 'El tap debe navegar al detalle del presupuesto sembrado.');

    await harness.dispose();
  });
}
