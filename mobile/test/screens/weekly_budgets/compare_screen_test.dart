import 'package:fincore/screens/dashboard_screen.dart';
import 'package:fincore/widgets/amount_formatter.dart';
import 'package:fincore/widgets/base_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/widget_test_harness.dart';

/// Widget tests de `BudgetCompareScreen` (sprint `flutter-weekly-budgets-v1`):
/// comparación side-by-side de 2 presupuestos de la misma semana. Cubre
/// CP-01..CP-04 del encargo.
void main() {
  group('BudgetCompareScreen — CP', () {
    Future<void> pushCompare(
      WidgetTester tester,
      String idA,
      String idB,
    ) async {
      final ctx = tester.element(find.byType(Scaffold));
      GoRouter.of(ctx).push('/budgets/compare/$idA/$idB');
      await tester.pumpAndSettle();
    }

    Future<void> pushBudgets(WidgetTester tester) async {
      final ctx = tester.element(find.byType(Scaffold));
      GoRouter.of(ctx).push('/budgets');
      await tester.pumpAndSettle();
    }

    testWidgets(
        'CP-01: dos budgets con items diferentes → pantalla muestra ambos '
        'side-by-side', (tester) async {
      late String idA;
      late String idB;
      final weekStart = DateTime(2026, 7, 17);
      final harness = await pumpFincoreApp(
        tester,
        seed: (db, deps) async {
          idA = await deps.weeklyBudgetsDao.createBudget(
            weekStartDate: weekStart,
            label: 'Conservador',
          );
          idB = await deps.weeklyBudgetsDao.createBudget(
            weekStartDate: weekStart,
            label: 'Optimista',
          );
          await deps.weeklyBudgetsDao.addItem(
            budgetId: idA,
            name: 'Renta',
            amount: 500,
            kind: 'expense',
          );
          await deps.weeklyBudgetsDao.addItem(
            budgetId: idB,
            name: 'Freelance',
            amount: 800,
            kind: 'income',
          );
        },
      );
      await pushCompare(tester, idA, idB);

      expect(find.text('Comparar'), findsOneWidget);
      expect(find.text('Conservador'), findsOneWidget);
      expect(find.text('Optimista'), findsOneWidget);
      // Renta es exclusivo de A (gasto), Freelance exclusivo de B (ingreso).
      expect(find.text('Renta'), findsOneWidget);
      expect(find.text('Freelance'), findsOneWidget);
      // Ambos renglones exclusivos generan un "—" muted del lado opuesto.
      expect(find.text('—'), findsWidgets);

      await harness.dispose();
    });

    testWidgets(
        'CP-02: item con mismo nombre en ambos → aparece con delta',
        (tester) async {
      late String idA;
      late String idB;
      final weekStart = DateTime(2026, 7, 17);
      final harness = await pumpFincoreApp(
        tester,
        seed: (db, deps) async {
          idA = await deps.weeklyBudgetsDao.createBudget(
            weekStartDate: weekStart,
            label: 'Conservador',
          );
          idB = await deps.weeklyBudgetsDao.createBudget(
            weekStartDate: weekStart,
            label: 'Optimista',
          );
          await deps.weeklyBudgetsDao.addItem(
            budgetId: idA,
            name: 'Super',
            amount: 500,
            kind: 'expense',
          );
          await deps.weeklyBudgetsDao.addItem(
            budgetId: idB,
            name: 'Super',
            amount: 700,
            kind: 'expense',
          );
        },
      );
      await pushCompare(tester, idA, idB);

      // Mismo nombre en ambos → un solo renglón compartido, no dos.
      expect(find.text('Super'), findsNWidgets(2));
      // B (700) > A (500): delta +$200 se muestra junto al monto de B.
      expect(find.text('+${formatAmount(200)}'), findsOneWidget);

      await harness.dispose();
    });

    testWidgets(
        'CP-03: budgetIdA == budgetIdB → snackbar error + pop',
        (tester) async {
      late String id;
      final harness = await pumpFincoreApp(
        tester,
        seed: (db, deps) async {
          id = await deps.weeklyBudgetsDao.createBudget(
            weekStartDate: DateTime(2026, 7, 17),
            label: 'Único',
          );
        },
      );
      await pushCompare(tester, id, id);

      expect(
        find.text('No puedes comparar un presupuesto contigo mismo'),
        findsOneWidget,
      );
      // El pop vuelve al dashboard (el harness arranca ahí y el push del
      // helper apila sobre esa ruta).
      expect(find.byType(DashboardScreen), findsOneWidget);

      await harness.dispose();
    });

    testWidgets(
        'CP-04: entry desde list_screen — PopupMenu tiene "Comparar con..." '
        'solo si hay ≥1 otro budget misma semana', (tester) async {
      final weekStart = DateTime(2026, 7, 17);
      final harnessAlone = await pumpFincoreApp(
        tester,
        seed: (db, deps) async {
          await deps.weeklyBudgetsDao.createBudget(
            weekStartDate: weekStart,
            label: 'Solo',
          );
        },
      );
      await pushBudgets(tester);
      await tester.tap(find.byTooltip('Más acciones'));
      await tester.pumpAndSettle();
      expect(find.text('Comparar con...'), findsNothing);
      // Cierra el menú sin seleccionar nada.
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      await harnessAlone.dispose();

      late String idA;
      late String idB;
      final harnessWithSibling = await pumpFincoreApp(
        tester,
        seed: (db, deps) async {
          idA = await deps.weeklyBudgetsDao.createBudget(
            weekStartDate: weekStart,
            label: 'Card A',
          );
          idB = await deps.weeklyBudgetsDao.createBudget(
            weekStartDate: weekStart,
            label: 'Card B',
          );
        },
      );
      await pushBudgets(tester);

      final cardA = find.ancestor(
        of: find.text('Card A'),
        matching: find.byType(BaseCard),
      );
      final menuButtonA = find.descendant(
        of: cardA,
        matching: find.byTooltip('Más acciones'),
      );
      await tester.tap(menuButtonA);
      await tester.pumpAndSettle();
      expect(find.text('Comparar con...'), findsOneWidget);

      await tester.tap(find.text('Comparar con...'));
      await tester.pumpAndSettle();
      // Bottom sheet lista al hermano de la misma semana. `findsWidgets`
      // (no `findsOneWidget`): la card "Card B" del listado sigue montada
      // debajo del sheet, así que el texto aparece 2 veces en el árbol.
      expect(find.text('Card B'), findsWidgets);

      await tester.tap(find.text('Card B').last);
      await tester.pumpAndSettle();

      // Navegó a la pantalla de comparación. `/budgets` sigue apilada debajo
      // (push, no replace), así que "Card A"/"Card B" ahora aparecen 2 veces
      // cada uno (list_screen + compare_screen) — usamos el AppBar único
      // "Comparar" y el balance "$0" de ambas mini-headers (formato propio
      // de `BudgetCompareScreen`, distinto de "En equilibrio" del listado)
      // como señal inequívoca de que la pantalla nueva renderizó.
      expect(find.text('Comparar'), findsOneWidget);
      expect(find.text(r'$0'), findsNWidgets(2));

      await harnessWithSibling.dispose();
      // Silencia el warning de "unused" si el analyzer se queja de ids no
      // usados fuera del seed (no ocurre, pero documenta la intención).
      expect(idA, isNotEmpty);
      expect(idB, isNotEmpty);
    });
  });
}
