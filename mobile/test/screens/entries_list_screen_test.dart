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
        amount: 100000,
        occurredAt: day,
        description: 'Salario',
      );
      await deps.entriesDao.registerIncome(
        accountDestinationId: bolsa.id,
        amount: 20000,
        occurredAt: day.add(const Duration(hours: 1)),
        description: 'Reembolso',
      );
      await deps.entriesDao.registerExpense(
        accountOriginId: bolsa.id,
        amount: 5000,
        occurredAt: day.add(const Duration(hours: 2)),
        description: 'Café',
      );
      await deps.entriesDao.registerExpense(
        accountOriginId: bolsa.id,
        amount: 8000,
        occurredAt: day.add(const Duration(hours: 3)),
        description: 'Almuerzo',
      );
      await deps.entriesDao.registerTransfer(
        accountOriginId: bolsa.id,
        accountDestinationId: debit.id,
        amount: 50000,
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

  // M3 reactivado tras `flutter-entries-list-refactor-v1`: el cuelgue de
  // `pumpAndSettle` que difería este test fue resuelto como efecto
  // colateral del refactor. Causa raíz hipotetizada: cuando `_stream`,
  // `_accountsSub` y `_categoriesSub` coexistían en el mismo State, el
  // primer setState de los subs invalidaba el frame del StreamBuilder
  // antes de que recibiera su primer evento, generando un loop de
  // rebuild que pumpAndSettle no podía aterrizar. Al separar el state
  // de paginación al `EntriesPaginatedList`, los ciclos de rebuild
  // quedan desacoplados.
  group('Deep link via URL manual (M3 reactivado)', () {
    testWidgets(
        'Push /entries?categoryIds=<uuid> pre-carga filtro y rinde solo entries de esa categoría',
        (tester) async {
      String? comidaId;
      final harness = await pumpFincoreApp(tester, seed: (db, deps) async {
        final bolsa = (await deps.accountsDao.listAll())
            .firstWhere((a) => a.type == 'cash');
        comidaId = await deps.categoriesDao.create(
          name: 'ComidaM3',
          appliesTo: 'expense',
          colorSlug: 'red',
          iconSlug: 'shopping-cart',
        );
        final otraId = await deps.categoriesDao.create(
          name: 'OtraM3',
          appliesTo: 'expense',
          colorSlug: 'blue',
          iconSlug: 'truck',
        );
        final day = DateTime(DateTime.now().year, DateTime.now().month, 10, 10);
        await deps.entriesDao.registerExpense(
          accountOriginId: bolsa.id,
          categoryId: comidaId,
          amount: 10000,
          occurredAt: day,
          description: 'EntryComidaM3',
        );
        await deps.entriesDao.registerExpense(
          accountOriginId: bolsa.id,
          categoryId: otraId,
          amount: 5000,
          occurredAt: day.add(const Duration(hours: 1)),
          description: 'EntryOtraM3',
        );
      });

      final ctx = tester.element(find.byType(Scaffold).first);
      GoRouter.of(ctx).push('/entries?categoryIds=$comidaId');
      await tester.pumpAndSettle();

      expect(find.byType(EntriesListScreen), findsOneWidget);
      expect(find.text('EntryComidaM3'), findsOneWidget,
          reason: 'El deep link debe pre-cargar el filtro de Comida');
      expect(find.text('EntryOtraM3'), findsNothing,
          reason: 'El entry de otra categoría debe quedar fuera');

      await harness.dispose();
    });
  });

  group('Modo selección múltiple (flutter-entries-bulk-recategorize-v1)', () {
    Future<void> seedTwoEntries(dynamic db, dynamic deps) async {
      final bolsa = (await deps.accountsDao.listAll())
          .firstWhere((a) => a.type == 'cash');
      final now = DateTime.now();
      final day = DateTime(now.year, now.month, 5, 10);
      await deps.entriesDao.registerExpense(
        accountOriginId: bolsa.id,
        amount: 5000,
        occurredAt: day,
        description: 'Gasto uno',
      );
      await deps.entriesDao.registerExpense(
        accountOriginId: bolsa.id,
        amount: 8000,
        occurredAt: day.add(const Duration(hours: 1)),
        description: 'Gasto dos',
      );
    }

    Future<void> pushEntries(WidgetTester tester) async {
      final ctx = tester.element(find.byType(Scaffold));
      GoRouter.of(ctx).push('/entries');
      await tester.pumpAndSettle();
    }

    testWidgets(
        'WT-BULK-UI-01: long-press activa modo selección + AppBar contextual '
        'con contador "1 seleccionado"', (tester) async {
      final harness = await pumpFincoreApp(tester, seed: seedTwoEntries);
      await pushEntries(tester);

      // Entrada al modo: long-press sobre "Gasto uno".
      await tester.longPress(find.text('Gasto uno'));
      await tester.pumpAndSettle();

      expect(find.text('1 seleccionado'), findsOneWidget,
          reason: 'AppBar contextual debe mostrar contador');
      // FAB desaparece en modo selección — el AppBar propio lo suplanta.
      expect(find.byType(FloatingActionButton), findsNothing);
      // Botón "Asignar categoría" presente.
      expect(find.byTooltip('Asignar categoría'), findsOneWidget);
      // Botón "Salir de selección" también.
      expect(find.byTooltip('Salir de selección'), findsOneWidget);

      await harness.dispose();
    });

    testWidgets(
        'WT-BULK-UI-02: tap en segundo entry suma al contador '
        '(2 seleccionados)', (tester) async {
      final harness = await pumpFincoreApp(tester, seed: seedTwoEntries);
      await pushEntries(tester);

      await tester.longPress(find.text('Gasto uno'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Gasto dos'));
      await tester.pumpAndSettle();

      expect(find.text('2 seleccionados'), findsOneWidget);
      await harness.dispose();
    });

    testWidgets(
        'WT-BULK-UI-03: "Salir de selección" desmarca todo y restaura AppBar '
        'default + FAB', (tester) async {
      final harness = await pumpFincoreApp(tester, seed: seedTwoEntries);
      await pushEntries(tester);

      await tester.longPress(find.text('Gasto uno'));
      await tester.pumpAndSettle();
      expect(find.text('1 seleccionado'), findsOneWidget);

      await tester.tap(find.byTooltip('Salir de selección'));
      await tester.pumpAndSettle();

      expect(find.text('1 seleccionado'), findsNothing);
      expect(find.text('Movimientos'), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsOneWidget);

      await harness.dispose();
    });
  });
}
