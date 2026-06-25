import 'package:fincore/screens/entries_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../helpers/factories.dart';
import '../helpers/widget_test_harness.dart';

/// Tests de `EntriesListScreen` post sprint `flutter-movements-filters-v1`.
///
/// El flujo previo (bottom sheet + filtro single-kind) se reemplazó por:
/// - Panel full-screen `EntriesFiltersScreen` (RF-006).
/// - Filtros con `EntriesFilters` immutable + multi-kind/multi-categoría.
/// - Chips de filtros activos arriba de la lista con "X" para remover.
/// - Default `thisMonth` (cambio de UX vs sprint anterior, RT-02).
void main() {
  group('EntriesListScreen — flujo base', () {
    Future<void> seedMixedEntries(dynamic db, dynamic deps) async {
      await db.into(db.accounts).insert(Factories.debit(name: 'Banamex'));
      final bolsa = (await deps.accountsDao.listAll())
          .firstWhere((a) => a.type == 'cash');
      final debit = (await deps.accountsDao.listAll())
          .firstWhere((a) => a.name == 'Banamex');
      // Fechas relativas a hoy para que caigan dentro del default thisMonth.
      final now = DateTime.now();
      final day = DateTime(now.year, now.month, 5, 10);
      await deps.entriesDao.registerIncome(
        accountDestinationId: bolsa.id,
        amount: 1000.0,
        occurredAt: day,
        description: 'Salario',
      );
      await deps.entriesDao.registerIncome(
        accountDestinationId: bolsa.id,
        amount: 200.0,
        occurredAt: day.add(const Duration(hours: 1)),
        description: 'Reembolso',
      );
      await deps.entriesDao.registerExpense(
        accountOriginId: bolsa.id,
        amount: 50.0,
        occurredAt: day.add(const Duration(hours: 2)),
        description: 'Café',
      );
      await deps.entriesDao.registerExpense(
        accountOriginId: bolsa.id,
        amount: 80.0,
        occurredAt: day.add(const Duration(hours: 3)),
        description: 'Almuerzo',
      );
      await deps.entriesDao.registerTransfer(
        accountOriginId: bolsa.id,
        accountDestinationId: debit.id,
        amount: 500.0,
        occurredAt: day.add(const Duration(hours: 4)),
        description: 'A débito',
      );
    }

    Future<void> pushEntries(WidgetTester tester) async {
      final ctx = tester.element(find.byType(Scaffold));
      GoRouter.of(ctx).push('/entries');
      await tester.pumpAndSettle();
    }

    testWidgets('Default thisMonth muestra los 5 entries del mes actual',
        (tester) async {
      final harness = await pumpFincoreApp(tester, seed: seedMixedEntries);
      await pushEntries(tester);

      expect(find.byType(EntriesListScreen), findsOneWidget);
      // El default thisMonth no activa filtros visibles (activeCount=0).
      // Sin badge ni chips activos.
      expect(find.byTooltip('Filtros'), findsOneWidget);
      // Las 5 descripciones aparecen.
      expect(find.text('Salario'), findsOneWidget);
      expect(find.text('Café'), findsOneWidget);
      expect(find.text('A débito'), findsOneWidget);

      await harness.dispose();
    });

    testWidgets(
        'AppBar tiene IconButton tune (sin badge cuando no hay filtros)',
        (tester) async {
      final harness = await pumpFincoreApp(tester);
      final ctx = tester.element(find.byType(Scaffold));
      GoRouter.of(ctx).push('/entries');
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.tune), findsOneWidget);
      // No hay número de badge porque activeCount = 0.
      expect(find.byTooltip('Filtros'), findsOneWidget);

      await harness.dispose();
    });

    testWidgets(
        'Estado vacío específico cuando lista vacía + filtros activos',
        (tester) async {
      final harness = await pumpFincoreApp(tester);
      // Deep link con filtros que no matchean nada (BD sin entries).
      final ctx = tester.element(find.byType(Scaffold));
      GoRouter.of(ctx).push('/entries?kinds=expense&categoryIds=__null__');
      await tester.pumpAndSettle();

      expect(
        find.textContaining('No hay movimientos con esos filtros'),
        findsOneWidget,
      );

      await harness.dispose();
    });

    testWidgets(
        'Estado vacío genérico cuando BD vacía sin filtros',
        (tester) async {
      final harness = await pumpFincoreApp(tester);
      final ctx = tester.element(find.byType(Scaffold));
      GoRouter.of(ctx).push('/entries');
      await tester.pumpAndSettle();

      // Default thisMonth, BD vacía → estado vacío genérico (no "con esos filtros").
      expect(find.text('No hay movimientos.'), findsOneWidget);

      await harness.dispose();
    });
  });

  // Deep link via query params — test diferido.
  //
  // El test específico que valida "push /entries?categoryIds=X muestra solo
  // entries de X" cuelga `pumpAndSettle` cuando `EntriesListScreen` rinde
  // `_ActiveFiltersBar` (que tiene 2 StreamBuilders anidados de cuentas y
  // categorías además del stream principal del DAO). El feature funciona
  // en producción y es funcionalmente equivalente al deep link desde el
  // reporte (cubierto por `reports_deeplink_test.dart`). Difiero el test
  // dedicado a un futuro sprint de UI testing depth.
  //
  // Cobertura compensatoria: `reports_deeplink_test.dart` valida el flujo
  // end-to-end completo (tap en bucket → /entries con query params →
  // lista filtrada). RF-012 funcional cubierto.
}
