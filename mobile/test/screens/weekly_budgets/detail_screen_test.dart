import 'package:fincore/screens/dashboard_screen.dart';
import 'package:fincore/theme/fincore_colors.dart';
import 'package:fincore/widgets/amount_formatter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/widget_test_harness.dart';

/// Widget tests de `WeeklyBudgetScreen` (sprint `flutter-weekly-budgets-v1`,
/// T031). Cubre WT-DS01..WT-DS11 del test-plan
/// (`engineering/specs/flutter-weekly-budgets-v1/plan/test-plan.md`).
void main() {
  group('WeeklyBudgetScreen — WT-DS', () {
    // El harness monta en `/dashboard` por default. Empujamos el detalle
    // con un push real (mismo patrón que `entry_form_kinds_test.dart`)
    // porque el id del budget se genera recién dentro del `seed` callback y
    // no puede conocerse antes de montar la app.
    Future<void> pushBudgetDetail(WidgetTester tester, String id) async {
      final ctx = tester.element(find.byType(Scaffold));
      GoRouter.of(ctx).push('/budgets/$id');
      await tester.pumpAndSettle();
    }

    Future<void> settleAfterWrite(WidgetTester tester) async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();
    }

    // `_confirmDeleteBudget` (detail_screen.dart) hace
    // `await weeklyBudgetsDao.watchBudgetItems(id).first` antes de abrir el
    // `ConfirmDialog`. La primera emisión de un stream `.watch()` de drift
    // se agenda por un mecanismo real (no un `Timer` fake) que `pump()` con
    // duración simulada no logra destrabar — confirmado con debug directo:
    // un `await` liso sobre ese stream cuelga indefinidamente sin
    // `tester.runAsync`. `runAsync` puentea al event loop real para dejar
    // que esa resolución ocurra, y luego `pumpAndSettle` termina de asentar
    // el diálogo.
    // Un solo `runAsync` con delay fijo (no loop: llamar `runAsync`
    // repetidamente en bucle demostró colgar el test de forma reproducible).
    Future<void> settleAfterAsyncMenuAction(WidgetTester tester) async {
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 500));
      });
      await tester.pumpAndSettle();
    }

    testWidgets(
        'WT-DS01: AppBar con label + rango; secciones vacías; footer '
        '"En equilibrio"',
        (tester) async {
      late String budgetId;
      final harness = await pumpFincoreApp(
        tester,
        seed: (db, deps) async {
          budgetId = await deps.weeklyBudgetsDao.createBudget(
            weekStartDate: DateTime(2026, 7, 17),
            label: 'Sueldo 17',
          );
        },
      );
      await pushBudgetDetail(tester, budgetId);

      expect(find.text('Sueldo 17'), findsOneWidget);
      expect(find.text('INGRESOS ESPERADOS'), findsOneWidget);
      // Refactor `BalanceFooter` opción C: la barra de progreso también
      // rotula "GASTOS PLANEADOS" (mismo copy que el header de la sección de
      // la lista) — ahora hay 2 instancias del texto en pantalla. Ya no hay
      // label "Balance:"; el renglón grande de abajo dice
      // "Sobra"/"Faltan"/"En equilibrio" + monto.
      // Sprint flutter-weekly-budgets-polish-v1 (2026-07-14): reemplaza
      // "GASTOS PLANEADOS" por los 2 mini-amounts INGRESOS + GASTOS.
      // Buscamos ambos labels en uppercase; aparecen en el footer + en
      // el header de la sección de items (que reusa el mismo copy).
      expect(find.text('INGRESOS'), findsWidgets);
      expect(find.text('GASTOS'), findsWidgets);
      expect(find.text('Sin ingresos planeados'), findsOneWidget);
      expect(find.text('Sin gastos planeados'), findsOneWidget);
      expect(find.text('En equilibrio'), findsOneWidget);

      await harness.dispose();
    });

    testWidgets(
        'WT-DS02: tap "+ ingreso" abre form sheet; guardar "Sueldo" '
        r'$6500 agrega card + footer "Sobra $6,500"',
        (tester) async {
      late String budgetId;
      final harness = await pumpFincoreApp(
        tester,
        seed: (db, deps) async {
          budgetId = await deps.weeklyBudgetsDao.createBudget(
            weekStartDate: DateTime(2026, 7, 17),
            label: 'Sueldo 17',
          );
        },
      );
      await pushBudgetDetail(tester, budgetId);

      // QW3: el trailing del header de sección ahora es un `IconButton` sin
      // label (tooltip "Agregar ingreso"/"Agregar gasto"). Con ambas
      // secciones vacías, el primer "Agregar" que queda en el árbol es el
      // botón de la card vacía de "Ingresos esperados" (la sección de
      // income se renderea antes que la de expense en `_buildLoaded`),
      // mismo callback `onAddItem` que el trailing de antes.
      await tester.tap(find.text('Agregar').first);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(0), 'Sueldo');
      await tester.enterText(find.byType(TextField).at(1), '6500');
      await tester.tap(find.text('Guardar'));
      await settleAfterWrite(tester);

      expect(find.text('Sueldo'), findsOneWidget);
      // Refactor `BalanceFooter` opción C: el footer separa el label
      // ("Sobra") del monto ("$6,500.00") en 2 `Text` — el monto coincide
      // con el del renglón de la card (2 instancias en total).
      // Sprint flutter-weekly-budgets-polish-v1: el footer agrega los 2
      // mini-amounts INGRESOS + GASTOS, así que el monto aparece más veces.
      expect(find.text(formatAmount(6500)), findsWidgets);
      expect(find.text('Sobra'), findsOneWidget);

      await harness.dispose();
    });

    testWidgets(
        r'WT-DS03: agregar 1 expense $2000 sobre income $6500 → footer '
        r'"Sobra $4500"',
        (tester) async {
      late String budgetId;
      final harness = await pumpFincoreApp(
        tester,
        seed: (db, deps) async {
          budgetId = await deps.weeklyBudgetsDao.createBudget(
            weekStartDate: DateTime(2026, 7, 17),
            label: 'Sueldo 17',
          );
          await deps.weeklyBudgetsDao.addItem(
            budgetId: budgetId,
            name: 'Sueldo',
            amount: 6500,
            kind: 'income',
          );
        },
      );
      await pushBudgetDetail(tester, budgetId);

      // Con 1 renglón de income ($6500) el footer muestra "Sobra" +
      // "$6,500.00" — ese mismo monto también aparece en la card del
      // renglón, así que hay 2 instancias del texto exacto.
      expect(find.text('Sobra'), findsOneWidget);
      // Sprint flutter-weekly-budgets-polish-v1: el footer agrega los 2
      // mini-amounts INGRESOS + GASTOS, así que el monto aparece más veces.
      expect(find.text(formatAmount(6500)), findsWidgets);

      // QW3: income ya tiene 1 renglón → su sección no muestra ningún
      // "Agregar" (header ahora es ícono sin label, y al no estar vacía no
      // hay card con el botón secundario). La sección expense sigue vacía
      // y es la única que aporta un "Agregar" (el de su card vacía) → es
      // el primero (y único) del árbol.
      await tester.tap(find.text('Agregar').first);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(0), 'Renta');
      await tester.enterText(find.byType(TextField).at(1), '2000');
      await tester.tap(find.text('Guardar'));
      await settleAfterWrite(tester);

      expect(find.text('Renta'), findsOneWidget);
      // Sprint flutter-weekly-budgets-polish-v1: el mini-amount de GASTOS
      // en el footer duplica la aparición del monto.
      expect(find.text(formatAmount(2000)), findsWidgets);
      // "$4,500.00" es un monto único (no coincide con ningún renglón) →
      // findsOneWidget sigue siendo válido para el monto del footer.
      expect(find.text('Sobra'), findsOneWidget);
      expect(find.text(formatAmount(4500)), findsOneWidget);

      await harness.dispose();
    });

    testWidgets(
        r'WT-DS04: editar expense de $2000 a $8000 → footer "Faltan $1500" '
        'en rojo',
        (tester) async {
      late String budgetId;
      final harness = await pumpFincoreApp(
        tester,
        seed: (db, deps) async {
          budgetId = await deps.weeklyBudgetsDao.createBudget(
            weekStartDate: DateTime(2026, 7, 17),
            label: 'Sueldo 17',
          );
          await deps.weeklyBudgetsDao.addItem(
            budgetId: budgetId,
            name: 'Sueldo',
            amount: 6500,
            kind: 'income',
          );
          await deps.weeklyBudgetsDao.addItem(
            budgetId: budgetId,
            name: 'Renta',
            amount: 2000,
            kind: 'expense',
          );
        },
      );
      await pushBudgetDetail(tester, budgetId);

      expect(find.text('Sobra'), findsOneWidget);
      expect(find.text(formatAmount(4500)), findsOneWidget);

      // Tap en el nombre del renglón (fuera del handle) abre edición.
      await tester.tap(find.text('Renta'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(1), '8000');
      await tester.tap(find.text('Guardar'));
      await settleAfterWrite(tester);

      // Refactor `BalanceFooter` opción C: label ("Faltan") y monto
      // ("$1,500.00") son 2 `Text` separados — solo el monto lleva el color
      // semántico (`FincoreColors.negative`), el label siempre es
      // `textMuted`.
      expect(find.text('Faltan'), findsOneWidget);
      final amountFinder = find.text(formatAmount(1500));
      expect(amountFinder, findsOneWidget);
      final textWidget = tester.widget<Text>(amountFinder);
      expect(textWidget.style?.color, FincoreColors.negative);

      await harness.dispose();
    });

    testWidgets(
        'WT-DS05: swipe → confirmación → item desaparece + balance recalcula '
        '(sprint flutter-budgets-polish-v1: P1a swipe-to-delete)',
        (tester) async {
      late String budgetId;
      final harness = await pumpFincoreApp(
        tester,
        seed: (db, deps) async {
          budgetId = await deps.weeklyBudgetsDao.createBudget(
            weekStartDate: DateTime(2026, 7, 17),
            label: 'Sueldo 17',
          );
          await deps.weeklyBudgetsDao.addItem(
            budgetId: budgetId,
            name: 'Sueldo',
            amount: 6500,
            kind: 'income',
          );
        },
      );
      await pushBudgetDetail(tester, budgetId);

      expect(find.text('Sueldo'), findsOneWidget);
      expect(find.text('Sobra'), findsOneWidget);
      // Monto duplicado (renglón + footer) — ver nota de WT-DS02/03.
      // Sprint flutter-weekly-budgets-polish-v1: el footer agrega los 2
      // mini-amounts INGRESOS + GASTOS, así que el monto aparece más veces.
      expect(find.text(formatAmount(6500)), findsWidgets);

      // Swipe-to-delete: fling horizontal sobre el renglón activa el
      // Dismissible, que dispara `onDeleteItem` (el caller muestra el
      // ConfirmDialog). El `Dismissible` retorna `false` en `confirmDismiss`
      // para no remover optimistamente — el stream reactivo emite el
      // snapshot sin el ítem y la fila desaparece "sola".
      await tester.fling(find.text('Sueldo'), const Offset(-500, 0), 1500);
      await tester.pumpAndSettle();

      // `ConfirmDialog` — confirmamos con el botón "Eliminar".
      expect(find.text("¿Eliminar el renglón 'Sueldo'?"), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Eliminar'));
      await settleAfterWrite(tester);

      expect(find.text('Sueldo'), findsNothing);
      expect(find.text('En equilibrio'), findsOneWidget);

      await harness.dispose();
    });

    testWidgets(
        'WT-DS06: menú → "Eliminar presupuesto" muestra dialog con copy '
        'exacto',
        (tester) async {
      late String budgetId;
      final harness = await pumpFincoreApp(
        tester,
        seed: (db, deps) async {
          budgetId = await deps.weeklyBudgetsDao.createBudget(
            weekStartDate: DateTime(2026, 7, 17),
            label: 'Sueldo 17',
          );
          await deps.weeklyBudgetsDao.addItem(
            budgetId: budgetId,
            name: 'Sueldo',
            amount: 6500,
            kind: 'income',
          );
          await deps.weeklyBudgetsDao.addItem(
            budgetId: budgetId,
            name: 'Renta',
            amount: 2000,
            kind: 'expense',
          );
        },
      );
      await pushBudgetDetail(tester, budgetId);

      await tester.tap(find.byTooltip('Más acciones'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Eliminar presupuesto'));
      await settleAfterAsyncMenuAction(tester);

      expect(
        find.text(
          'Esto borrará el presupuesto y sus 2 renglones. Esta acción no '
          'se puede deshacer.',
        ),
        findsOneWidget,
      );

      // Confirmamos y validamos que vuelve al sitio anterior (dashboard).
      await tester.tap(find.widgetWithText(FilledButton, 'Eliminar'));
      await settleAfterWrite(tester);
      expect(find.byType(DashboardScreen), findsOneWidget);

      await harness.dispose();
    });

    testWidgets(
        'WT-DS07: menú → "Marcar como plantilla" → toggle sin dialog → '
        'snackbar success + badge visible',
        (tester) async {
      late String budgetId;
      final harness = await pumpFincoreApp(
        tester,
        seed: (db, deps) async {
          budgetId = await deps.weeklyBudgetsDao.createBudget(
            weekStartDate: DateTime(2026, 7, 17),
            label: 'Sueldo 17',
          );
        },
      );
      await pushBudgetDetail(tester, budgetId);

      expect(find.byIcon(Icons.bookmark), findsNothing);

      await tester.tap(find.byTooltip('Más acciones'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Marcar como plantilla'));
      await settleAfterWrite(tester);

      expect(find.text('Presupuesto marcado como plantilla.'), findsOneWidget);
      expect(find.byIcon(Icons.bookmark), findsOneWidget);

      final row = await harness.deps.weeklyBudgetsDao.findById(budgetId);
      expect(row!.isTemplate, isTrue);

      // El menú refleja el estado invertido tras el toggle.
      await tester.tap(find.byTooltip('Más acciones'));
      await tester.pumpAndSettle();
      expect(find.text('Quitar marca de plantilla'), findsOneWidget);

      await harness.dispose();
    });

    testWidgets(
        'WT-DS08: handle presente en cada renglón; tap en el row (no en '
        'el handle) abre edición en vez de reordenar',
        (tester) async {
      late String budgetId;
      final harness = await pumpFincoreApp(
        tester,
        seed: (db, deps) async {
          budgetId = await deps.weeklyBudgetsDao.createBudget(
            weekStartDate: DateTime(2026, 7, 17),
            label: 'Sueldo 17',
          );
          await deps.weeklyBudgetsDao.addItem(
            budgetId: budgetId,
            name: 'Sueldo',
            amount: 6500,
            kind: 'income',
          );
          await deps.weeklyBudgetsDao.addItem(
            budgetId: budgetId,
            name: 'Extra',
            amount: 500,
            kind: 'income',
          );
        },
      );
      await pushBudgetDetail(tester, budgetId);

      // RN-B20: un handle por renglón.
      expect(find.byIcon(Icons.drag_indicator), findsNWidgets(2));

      // Tap en el nombre (fuera del handle) abre el form de edición en
      // lugar de disparar un reorder — el orden de los renglones no
      // cambia (misma cuenta de handles, ambos labels siguen presentes).
      await tester.tap(find.text('Sueldo'));
      await tester.pumpAndSettle();

      expect(find.text('Editar renglón'), findsOneWidget);
      // El name field viene precargado con el valor existente.
      final nameField = tester.widget<TextField>(find.byType(TextField).at(0));
      expect(nameField.controller?.text, 'Sueldo');

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.drag_indicator), findsNWidgets(2));
      expect(find.text('Sueldo'), findsOneWidget);
      expect(find.text('Extra'), findsOneWidget);

      await harness.dispose();
    });

    testWidgets(
        'WT-DS09: tap label AppBar → dialog inline → guardar persiste',
        (tester) async {
      late String budgetId;
      final harness = await pumpFincoreApp(
        tester,
        seed: (db, deps) async {
          budgetId = await deps.weeklyBudgetsDao.createBudget(
            weekStartDate: DateTime(2026, 7, 17),
            label: 'Sueldo 17',
          );
        },
      );
      await pushBudgetDetail(tester, budgetId);

      await tester.tap(find.text('Sueldo 17'));
      await tester.pumpAndSettle();

      expect(find.text('Editar nombre'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Sueldo 17 v2');
      await tester.tap(find.text('Guardar'));
      await settleAfterWrite(tester);

      expect(find.text('Sueldo 17 v2'), findsOneWidget);
      expect(find.text('Sueldo 17'), findsNothing);

      await harness.dispose();
    });

    testWidgets(
        'WT-DS10: submit renglón con name vacío → validación local no '
        'permite submit',
        (tester) async {
      late String budgetId;
      final harness = await pumpFincoreApp(
        tester,
        seed: (db, deps) async {
          budgetId = await deps.weeklyBudgetsDao.createBudget(
            weekStartDate: DateTime(2026, 7, 17),
            label: 'Sueldo 17',
          );
        },
      );
      await pushBudgetDetail(tester, budgetId);

      await tester.tap(find.text('Agregar').first);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(1), '100');
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      expect(find.text('Ingresar un nombre.'), findsOneWidget);
      // El sheet sigue abierto y no se agregó ningún renglón: la sección de
      // ingresos, detrás del sheet, sigue mostrando el estado vacío.
      expect(find.text('Nuevo renglón'), findsOneWidget);
      expect(find.text('Sin ingresos planeados'), findsOneWidget);

      await harness.dispose();
    });

    testWidgets(
        'WT-DS11: submit con amount = 0 → validación no permite submit',
        (tester) async {
      late String budgetId;
      final harness = await pumpFincoreApp(
        tester,
        seed: (db, deps) async {
          budgetId = await deps.weeklyBudgetsDao.createBudget(
            weekStartDate: DateTime(2026, 7, 17),
            label: 'Sueldo 17',
          );
        },
      );
      await pushBudgetDetail(tester, budgetId);

      await tester.tap(find.text('Agregar').first);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(0), 'Sueldo');
      await tester.enterText(find.byType(TextField).at(1), '0');
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      expect(find.text('Debe ser mayor a 0.'), findsOneWidget);
      expect(find.text('Nuevo renglón'), findsOneWidget);

      await harness.dispose();
    });
  });
}
