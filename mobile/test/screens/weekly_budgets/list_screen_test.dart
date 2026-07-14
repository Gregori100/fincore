import 'package:fincore/data/weekly_budgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/widget_test_harness.dart';

/// Widget tests de `WeeklyBudgetsListScreen` (sprint
/// `flutter-weekly-budgets-v1`, T030 + refactor 2026-07-14). Cubre
/// WT-LS01..WT-LS06 del test-plan
/// (`engineering/specs/flutter-weekly-budgets-v1/plan/test-plan.md`).
///
/// Convención documentada en `reports_screen_test.dart`: el harness arranca
/// en `/dashboard` y cada test pushea `/budgets` con `context.push(...)`.
/// Pasar `initialRoute: '/budgets'` al harness cuelga `pumpAndSettle`
/// indefinidamente (el `router.go(...)` interno reemplaza el stack y la
/// transición nunca asienta), mientras que `push` apila y asienta normal.
void main() {
  group('WeeklyBudgetsListScreen — WT-LS', () {
    Future<void> pushBudgets(WidgetTester tester) async {
      final ctx = tester.element(find.byType(Scaffold));
      GoRouter.of(ctx).push('/budgets');
      await tester.pumpAndSettle();
    }

    Future<void> settleAfterWrite(WidgetTester tester) async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();
    }

    // Mismo mecanismo documentado en `detail_screen_test.dart`:
    // `_deleteAllBudgets` hace `await _budgetsStream.first` antes de abrir el
    // `ConfirmDialog` — esa primera emisión de un stream `.watch()` de drift
    // no se resuelve con `pump()` simulado, necesita el event loop real vía
    // `runAsync`.
    Future<void> settleAfterAsyncMenuAction(WidgetTester tester) async {
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 500));
      });
      await tester.pumpAndSettle();
    }

    testWidgets('WT-LS01: BD vacía muestra empty state en /budgets',
        (tester) async {
      final harness = await pumpFincoreApp(tester);
      await pushBudgets(tester);

      expect(
        find.text('No hay presupuestos todavía.'),
        findsOneWidget,
      );
      expect(find.text('Crear primer presupuesto'), findsOneWidget);
      // Fix UX/UI: con la lista vacía, el FAB del Scaffold se oculta — el
      // único CTA es el del empty state.
      expect(find.byTooltip('Nuevo presupuesto'), findsNothing);

      await harness.dispose();
    });

    testWidgets(
        'WT-LS02: con 3 budgets (esta semana/próximos/pasados) muestra '
        'las 3 secciones + card por budget con label + balance',
        (tester) async {
      // El AppPreferencesDao no tiene `week_start_dow` seteado en una BD
      // fresca de test → default ISO 5 (viernes), igual que el que la
      // pantalla usará internamente. Anclamos las 3 fechas a ese mismo
      // cálculo para no depender de qué día corre la suite.
      final currentWeekStart = suggestedWeekStartDate(
        now: DateTime.now(),
        weekStartDow: 5,
      );
      final upcomingWeekStart = currentWeekStart.add(const Duration(days: 7));
      final pastWeekStart = currentWeekStart.subtract(const Duration(days: 7));

      final harness = await pumpFincoreApp(
        tester,
        seed: (db, deps) async {
          await deps.weeklyBudgetsDao.createBudget(
            weekStartDate: currentWeekStart,
            label: 'Sueldo actual',
          );
          await deps.weeklyBudgetsDao.createBudget(
            weekStartDate: upcomingWeekStart,
            label: 'Sueldo próximo',
          );
          await deps.weeklyBudgetsDao.createBudget(
            weekStartDate: pastWeekStart,
            label: 'Sueldo pasado',
          );
        },
      );
      await pushBudgets(tester);

      // `SectionTitle` renderiza el texto en mayúsculas.
      expect(find.text('ESTA SEMANA'), findsOneWidget);
      expect(find.text('PRÓXIMAS'), findsOneWidget);
      expect(find.text('PASADAS'), findsOneWidget);

      expect(find.text('Sueldo actual'), findsOneWidget);
      expect(find.text('Sueldo próximo'), findsOneWidget);
      expect(find.text('Sueldo pasado'), findsOneWidget);

      // Ninguno de los 3 tiene renglones → balance 0 → "En equilibrio" x3.
      expect(find.text('En equilibrio'), findsNWidgets(3));

      await harness.dispose();
    });

    // Fix UX/UI: con la lista vacía el FAB se oculta (Fix 2), así que estos
    // tests siembran un budget existente para mantener el FAB visible y
    // seguir cubriendo ese flujo de entrada específico.
    testWidgets('WT-LS03: tap FAB abre bottom sheet con 2 opciones',
        (tester) async {
      final harness = await pumpFincoreApp(
        tester,
        seed: (db, deps) async {
          await deps.weeklyBudgetsDao.createBudget(
            weekStartDate: DateTime.now(),
            label: 'Existente',
          );
        },
      );
      await pushBudgets(tester);

      await tester.tap(find.byTooltip('Nuevo presupuesto'));
      await tester.pumpAndSettle();

      expect(find.text('En blanco'), findsOneWidget);
      expect(find.text('Desde plantilla'), findsOneWidget);

      await harness.dispose();
    });

    testWidgets(
        'WT-LS04: "En blanco" → picker → auto-label (sin dialog) → navega '
        'a detalle',
        (tester) async {
      final harness = await pumpFincoreApp(
        tester,
        seed: (db, deps) async {
          await deps.weeklyBudgetsDao.createBudget(
            weekStartDate: DateTime.now(),
            label: 'Existente',
          );
        },
      );
      await pushBudgets(tester);

      await tester.tap(find.byTooltip('Nuevo presupuesto'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('En blanco'));
      await tester.pumpAndSettle();

      // `showDatePicker` abre con la fecha sugerida ya seleccionada; basta
      // confirmar con el botón OK localizado ("ACEPTAR" en es_MX) sin tocar
      // el calendario.
      expect(find.byType(DatePickerDialog), findsOneWidget);
      await tester.tap(find.text('ACEPTAR'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();

      // Refactor: sin dialog de nombre — el label se genera automático
      // ("Semana del D mmm") y navega directo al detalle.
      expect(find.text('Nombre del presupuesto'), findsNothing);
      expect(find.textContaining('Semana del'), findsOneWidget);

      await harness.dispose();
    });

    testWidgets(
        'WT-LS05: "Desde plantilla" deshabilitada sin plantillas; '
        'habilitada si hay al menos un budget marcado (is_template=true)',
        (tester) async {
      final harnessNoTemplates = await pumpFincoreApp(
        tester,
        seed: (db, deps) async {
          await deps.weeklyBudgetsDao.createBudget(
            weekStartDate: DateTime.now(),
            label: 'Existente',
          );
        },
      );
      await pushBudgets(tester);
      await tester.tap(find.byTooltip('Nuevo presupuesto'));
      await tester.pumpAndSettle();

      final disabledTile = tester.widget<ListTile>(
        find.widgetWithText(ListTile, 'Desde plantilla'),
      );
      expect(disabledTile.enabled, isFalse);

      await harnessNoTemplates.dispose();

      final harnessWithTemplate = await pumpFincoreApp(
        tester,
        seed: (db, deps) async {
          await deps.weeklyBudgetsDao.createBudget(
            weekStartDate: DateTime.now(),
            label: 'Existente',
          );
          final templateId = await deps.weeklyBudgetsDao.createBudget(
            weekStartDate: DateTime.now(),
            label: 'Plantilla T',
          );
          await deps.weeklyBudgetsDao.toggleTemplateFlag(templateId);
        },
      );
      await pushBudgets(tester);
      await tester.tap(find.byTooltip('Nuevo presupuesto'));
      await tester.pumpAndSettle();

      final enabledTile = tester.widget<ListTile>(
        find.widgetWithText(ListTile, 'Desde plantilla'),
      );
      expect(enabledTile.enabled, isTrue);

      await harnessWithTemplate.dispose();
    });

    testWidgets(
        'WT-LS06: tap "Marcar como plantilla" en PopupMenu → toggle '
        'persiste + badge visible',
        (tester) async {
      late String budgetId;
      final harness = await pumpFincoreApp(
        tester,
        seed: (db, deps) async {
          budgetId = await deps.weeklyBudgetsDao.createBudget(
            weekStartDate: DateTime.now(),
            label: 'Sueldo semanal',
          );
        },
      );
      await pushBudgets(tester);

      expect(find.byIcon(Icons.bookmark), findsNothing);

      await tester.tap(find.byTooltip('Más acciones'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Marcar como plantilla'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();

      expect(find.text('Presupuesto marcado como plantilla.'), findsOneWidget);
      expect(find.byIcon(Icons.bookmark), findsOneWidget);

      final row = await harness.deps.weeklyBudgetsDao.findById(budgetId);
      expect(row!.isTemplate, isTrue);

      // Toggle inverso: el label del menú cambia.
      await tester.tap(find.byTooltip('Más acciones'));
      await tester.pumpAndSettle();
      expect(find.text('Quitar de plantillas'), findsOneWidget);

      await harness.dispose();
    });

    testWidgets(
        'WT-LS07: long-press en un card entra en modo selección con '
        '"1 seleccionado" + delete',
        (tester) async {
      final harness = await pumpFincoreApp(
        tester,
        seed: (db, deps) async {
          await deps.weeklyBudgetsDao.createBudget(
            weekStartDate: DateTime.now(),
            label: 'Presupuesto A',
          );
        },
      );
      await pushBudgets(tester);

      await tester.longPress(find.text('Presupuesto A'));
      await tester.pumpAndSettle();

      expect(find.text('1 seleccionado'), findsOneWidget);
      expect(find.byTooltip('Eliminar seleccionados'), findsOneWidget);
      expect(find.byTooltip('Salir de selección'), findsOneWidget);

      await harness.dispose();
    });

    testWidgets(
        'WT-LS08: en modo selección, tap otro card sube el contador a '
        '"2 seleccionados"',
        (tester) async {
      final harness = await pumpFincoreApp(
        tester,
        seed: (db, deps) async {
          await deps.weeklyBudgetsDao.createBudget(
            weekStartDate: DateTime.now(),
            label: 'Presupuesto A',
          );
          await deps.weeklyBudgetsDao.createBudget(
            weekStartDate: DateTime.now(),
            label: 'Presupuesto B',
          );
        },
      );
      await pushBudgets(tester);

      await tester.longPress(find.text('Presupuesto A'));
      await tester.pumpAndSettle();
      expect(find.text('1 seleccionado'), findsOneWidget);

      await tester.tap(find.text('Presupuesto B'));
      await tester.pumpAndSettle();

      expect(find.text('2 seleccionados'), findsOneWidget);

      await harness.dispose();
    });

    testWidgets(
        'WT-LS09: tap IconButton close del AppBar bulk sale del modo '
        'selección',
        (tester) async {
      final harness = await pumpFincoreApp(
        tester,
        seed: (db, deps) async {
          await deps.weeklyBudgetsDao.createBudget(
            weekStartDate: DateTime.now(),
            label: 'Presupuesto A',
          );
        },
      );
      await pushBudgets(tester);

      await tester.longPress(find.text('Presupuesto A'));
      await tester.pumpAndSettle();
      expect(find.text('1 seleccionado'), findsOneWidget);

      await tester.tap(find.byTooltip('Salir de selección'));
      await tester.pumpAndSettle();

      expect(find.text('Presupuestos semanales'), findsOneWidget);
      expect(find.text('1 seleccionado'), findsNothing);
      // La card sigue existiendo — solo se salió del modo, no se borró nada.
      expect(find.text('Presupuesto A'), findsOneWidget);

      await harness.dispose();
    });

    testWidgets(
        'WT-LS10: bulk delete con 2 seleccionados los borra de la BD + '
        'snackbar',
        (tester) async {
      late String idA;
      late String idB;
      final harness = await pumpFincoreApp(
        tester,
        seed: (db, deps) async {
          idA = await deps.weeklyBudgetsDao.createBudget(
            weekStartDate: DateTime.now(),
            label: 'Presupuesto A',
          );
          idB = await deps.weeklyBudgetsDao.createBudget(
            weekStartDate: DateTime.now(),
            label: 'Presupuesto B',
          );
          await deps.weeklyBudgetsDao.createBudget(
            weekStartDate: DateTime.now(),
            label: 'Presupuesto C',
          );
        },
      );
      await pushBudgets(tester);

      await tester.longPress(find.text('Presupuesto A'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Presupuesto B'));
      await tester.pumpAndSettle();
      expect(find.text('2 seleccionados'), findsOneWidget);

      await tester.tap(find.byTooltip('Eliminar seleccionados'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Eliminar 2 presupuestos y todos sus renglones? Esta acción no '
          'se puede deshacer.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Eliminar'));
      await settleAfterWrite(tester);

      expect(find.text('2 presupuestos eliminados.'), findsOneWidget);
      expect(find.text('Presupuesto A'), findsNothing);
      expect(find.text('Presupuesto B'), findsNothing);
      expect(find.text('Presupuesto C'), findsOneWidget);
      // Vuelve al AppBar normal tras el bulk delete.
      expect(find.text('Presupuestos semanales'), findsOneWidget);

      expect(await harness.deps.weeklyBudgetsDao.findById(idA), isNull);
      expect(await harness.deps.weeklyBudgetsDao.findById(idB), isNull);

      await harness.dispose();
    });

    testWidgets(
        'WT-LS11: menú AppBar "Eliminar todos" con 3 budgets los borra '
        'todos + snackbar',
        (tester) async {
      final harness = await pumpFincoreApp(
        tester,
        seed: (db, deps) async {
          await deps.weeklyBudgetsDao.createBudget(
            weekStartDate: DateTime.now(),
            label: 'Presupuesto A',
          );
          await deps.weeklyBudgetsDao.createBudget(
            weekStartDate: DateTime.now(),
            label: 'Presupuesto B',
          );
          await deps.weeklyBudgetsDao.createBudget(
            weekStartDate: DateTime.now(),
            label: 'Presupuesto C',
          );
        },
      );
      await pushBudgets(tester);

      await tester.tap(find.byTooltip('Más opciones'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Eliminar todos'));
      await settleAfterAsyncMenuAction(tester);

      expect(
        find.text(
          'Eliminar los 3 presupuestos y todos sus renglones? Esta acción '
          'no se puede deshacer.',
        ),
        findsOneWidget,
      );

      await tester.tap(find.widgetWithText(FilledButton, 'Eliminar'));
      await settleAfterWrite(tester);

      expect(find.text('3 presupuestos eliminados.'), findsOneWidget);
      expect(find.text('No hay presupuestos todavía.'), findsOneWidget);

      await harness.dispose();
    });

    testWidgets(
        'WT-LS12: back nativo en modo selección sale del modo sin cerrar '
        'la pantalla',
        (tester) async {
      final harness = await pumpFincoreApp(
        tester,
        seed: (db, deps) async {
          await deps.weeklyBudgetsDao.createBudget(
            weekStartDate: DateTime.now(),
            label: 'Presupuesto A',
          );
        },
      );
      await pushBudgets(tester);

      await tester.longPress(find.text('Presupuesto A'));
      await tester.pumpAndSettle();
      expect(find.text('1 seleccionado'), findsOneWidget);

      // Simula el back nativo invocando directamente el callback del
      // `PopScope` que envuelve la pantalla — evita depender de APIs de
      // simulación de back de Android que cambian entre versiones de
      // Flutter. `dynamic` esquiva el type-check del parámetro genérico
      // `PopScope<T>` (T se infiere `dynamic` porque el callback no anota
      // sus parámetros).
      final popScopeWidget = tester.widgetList(
        find.byWidgetPredicate((w) => w is PopScope),
      ).single;
      (popScopeWidget as dynamic).onPopInvokedWithResult(false, null);
      await tester.pumpAndSettle();

      expect(find.text('Presupuestos semanales'), findsOneWidget);
      expect(find.text('1 seleccionado'), findsNothing);
      expect(find.text('Presupuesto A'), findsOneWidget);

      await harness.dispose();
    });
  });
}
