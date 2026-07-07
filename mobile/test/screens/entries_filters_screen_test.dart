import 'package:fincore/constants/date_range_presets.dart';
import 'package:fincore/data/entries_filters.dart';
import 'package:fincore/screens/entries_filters_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../helpers/widget_test_harness.dart';

/// Widget tests del nuevo panel `EntriesFiltersScreen` (sprint
/// `flutter-movements-filters-v1`, RF-021).
///
/// El panel se monta vía `Navigator.push` desde `EntriesListScreen`; los
/// tests acá lo montan directo con `MaterialApp` + `AppDependenciesProvider`
/// del harness para aislarlo del flujo del list screen.
void main() {
  /// Helper para abrir el panel desde el dashboard hidratado por el harness.
  /// Toma el contexto del Scaffold del Dashboard (vive dentro del
  /// `AppDependenciesProvider`) y hace `Navigator.of(ctx).push(...)` desde
  /// ahí. No usar `find.byType(Navigator).first` porque go_router monta su
  /// propio Navigator y el push iría a un contexto sin AppDependencies.
  ///
  /// Tras el sprint patch (perf v1) el panel recibe `accounts` y
  /// `categories` resueltos por el padre, no streams. Para tests aislados
  /// pasamos listas vacías por default (suficiente para validar el render
  /// del panel y los chips fijos).
  Future<EntriesFilters?> openPanel(
    WidgetTester tester, {
    required EntriesFilters initial,
  }) {
    final ctx = tester.element(find.byType(Scaffold).first);
    final future = Navigator.of(ctx).push<EntriesFilters>(
      MaterialPageRoute(
        builder: (_) => EntriesFiltersScreen(
          initial: initial,
          accounts: const [],
          categories: const [],
        ),
        fullscreenDialog: true,
      ),
    );
    return future;
  }

  group('EntriesFiltersScreen — render base', () {
    testWidgets('Monta con header, 4 secciones y footer', (tester) async {
      final harness = await pumpFincoreApp(tester);
      final initial = EntriesFilters.thisMonth();
      // ignore: unused_local_variable
      final future = openPanel(tester, initial: initial);
      await tester.pumpAndSettle();

      expect(find.byType(EntriesFiltersScreen), findsOneWidget);
      expect(find.text('Filtros'), findsOneWidget);
      expect(find.text('Fecha'), findsOneWidget);
      expect(find.text('Tipo'), findsOneWidget);
      expect(find.text('Cuenta'), findsOneWidget);
      expect(find.text('Categorías'), findsOneWidget);
      expect(find.text('Limpiar todo'), findsOneWidget);
      expect(find.text('Aplicar'), findsOneWidget);

      await harness.dispose();
    });

    testWidgets('Default thisMonth está seleccionado al abrir', (tester) async {
      final harness = await pumpFincoreApp(tester);
      openPanel(tester, initial: EntriesFilters.thisMonth());
      await tester.pumpAndSettle();

      // Chip "Este mes" presente.
      expect(find.text('Este mes'), findsOneWidget);
      // Los 5 kinds individuales como chips.
      expect(find.text('Ingreso'), findsOneWidget);
      expect(find.text('Gasto'), findsOneWidget);
      expect(find.text('Gasto a tarjeta'), findsOneWidget);
      expect(find.text('Pago de tarjeta'), findsOneWidget);
      expect(find.text('Transferencia'), findsOneWidget);
      // Chip "Sin categoría" presente (tras `flutter-movements-amount-filter-v1`
      // la sección "Monto" empuja "Categorías" fuera del viewport inicial,
      // así que scrolleamos antes del expect).
      await tester.scrollUntilVisible(
        find.text('Sin categoría'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Sin categoría'), findsOneWidget);

      await harness.dispose();
    });
  });

  group('EntriesFiltersScreen — interacción', () {
    testWidgets('Tap en "Gasto" y "Gasto a tarjeta" marca ambos chips',
        (tester) async {
      final harness = await pumpFincoreApp(tester);
      final future = openPanel(tester, initial: EntriesFilters.thisMonth());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Gasto'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Gasto a tarjeta'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Aplicar'));
      await tester.pumpAndSettle();

      final result = await future;
      expect(result, isNotNull);
      expect(result!.kinds.toSet(), {'expense', 'credit_expense'});

      await harness.dispose();
    });

    testWidgets('Tap en "Limpiar todo" resetea al default visualmente',
        (tester) async {
      final harness = await pumpFincoreApp(tester);
      // Iniciar con kinds activos para que Limpiar todo tenga efecto.
      final initial = EntriesFilters.thisMonth().copyWith(
        kinds: const ['income'],
      );
      openPanel(tester, initial: initial);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Limpiar todo'));
      await tester.pumpAndSettle();

      // El panel sigue montado (no hace pop).
      expect(find.byType(EntriesFiltersScreen), findsOneWidget);

      await harness.dispose();
    });

    testWidgets('Tap en X del header descarta cambios (pop sin resultado)',
        (tester) async {
      final harness = await pumpFincoreApp(tester);
      final future = openPanel(tester, initial: EntriesFilters.thisMonth());
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Cerrar'));
      await tester.pumpAndSettle();

      // Panel desmontado.
      expect(find.byType(EntriesFiltersScreen), findsNothing);
      // El future del push resuelve a null.
      final result = await future;
      expect(result, isNull);

      await harness.dispose();
    });

    testWidgets('Tap en "Aplicar" propaga EntriesFilters al caller',
        (tester) async {
      final harness = await pumpFincoreApp(tester);
      final initial = EntriesFilters.thisMonth();
      final future = openPanel(tester, initial: initial);
      await tester.pumpAndSettle();

      // Tap en chip de tipo "Gasto a tarjeta".
      await tester.tap(find.text('Gasto a tarjeta'));
      await tester.pumpAndSettle();
      // Cambiar fecha a Mes pasado.
      await tester.tap(find.text('Mes pasado'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Aplicar'));
      await tester.pumpAndSettle();

      final result = await future;
      expect(result, isNotNull);
      expect(result!.datePreset, DateRangePreset.lastMonth);
      expect(result.kinds, ['credit_expense']);

      await harness.dispose();
    });

    // M10 reactivado tras `flutter-entries-list-refactor-v1`: ver nota en
    // `entries_list_screen_test.dart` sobre por qué el refactor lo fix.
    // Este test usa el flujo end-to-end con el panel abierto desde el
    // `EntriesListScreen` real (no via `openPanel` helper) para validar
    // el multi-select sobre datos sembrados.
    testWidgets(
        'M10: tap chip cuenta + Aplicar filtra entries (flujo desde /entries)',
        (tester) async {
      String? bbvaId;
      final harness = await pumpFincoreApp(tester, seed: (db, deps) async {
        bbvaId = await deps.accountsDao.create(name: 'BBVA-M10', type: 'debit');
        final bolsa = (await deps.accountsDao.listAll())
            .firstWhere((a) => a.type == 'cash');
        final today = DateTime.now();
        await deps.entriesDao.registerExpense(
          accountOriginId: bolsa.id,
          amount: 100,
          occurredAt: today,
          description: 'GastoBolsaM10',
        );
        await deps.entriesDao.registerExpense(
          accountOriginId: bbvaId!,
          amount: 200,
          occurredAt: today.add(const Duration(hours: 1)),
          description: 'GastoBBVAM10',
        );
      });

      final ctx = tester.element(find.byType(Scaffold).first);
      GoRouter.of(ctx).push('/entries');
      await tester.pumpAndSettle();

      expect(find.text('GastoBolsaM10'), findsOneWidget);
      expect(find.text('GastoBBVAM10'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.tune));
      await tester.pumpAndSettle();
      await tester.tap(find.text('BBVA-M10'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aplicar'));
      await tester.pumpAndSettle();

      expect(find.text('GastoBBVAM10'), findsOneWidget);
      expect(find.text('GastoBolsaM10'), findsNothing,
          reason: 'Filtrar por BBVA debe ocultar entries de la Bolsa');

      await harness.dispose();
    });

    testWidgets('Tap en "Custom" muestra los dos input fields de fecha',
        (tester) async {
      final harness = await pumpFincoreApp(tester);
      openPanel(tester, initial: EntriesFilters.thisMonth());
      await tester.pumpAndSettle();

      // Antes de Custom: no hay icon calendar.
      expect(find.byIcon(Icons.calendar_today), findsNothing);

      await tester.tap(find.text('Custom'));
      await tester.pumpAndSettle();

      // Tras Custom: aparecen 2 icons + labels Desde / Hasta.
      expect(find.byIcon(Icons.calendar_today), findsNWidgets(2));
      expect(find.text('Desde'), findsOneWidget);
      expect(find.text('Hasta'), findsOneWidget);

      await harness.dispose();
    });
  });

  // ==========================================================================
  // amount — sprint `flutter-movements-amount-filter-v1`
  // ==========================================================================
  group('EntriesFiltersScreen — sección Monto', () {
    Future<EntriesFilters?> openPanelWith(
      WidgetTester tester, {
      required EntriesFilters initial,
    }) {
      final ctx = tester.element(find.byType(Scaffold).first);
      return Navigator.of(ctx).push<EntriesFilters>(
        MaterialPageRoute(
          builder: (_) => EntriesFiltersScreen(
            initial: initial,
            accounts: const [],
            categories: const [],
          ),
          fullscreenDialog: true,
        ),
      );
    }

    testWidgets('WT-01: sección "Monto" renderea con 2 fields',
        (tester) async {
      final harness = await pumpFincoreApp(tester);
      // ignore: unused_local_variable
      final future = openPanelWith(tester, initial: EntriesFilters.thisMonth());
      await tester.pumpAndSettle();

      expect(find.text('Monto'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Mínimo'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Máximo'), findsOneWidget);

      await harness.dispose();
    });

    testWidgets(
        'WT-02: ingresar min=100 + Aplicar retorna EntriesFilters con minAmount=100',
        (tester) async {
      final harness = await pumpFincoreApp(tester);
      final future = openPanelWith(tester, initial: EntriesFilters.thisMonth());
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Mínimo'),
        '100',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aplicar'));
      await tester.pumpAndSettle();

      final result = await future;
      expect(result, isNotNull);
      expect(result!.minAmount, 100.0);
      expect(result.maxAmount, isNull);

      await harness.dispose();
    });

    testWidgets(
        'WT-03: min > max + Aplicar muestra snackbar warning y NO emite',
        (tester) async {
      final harness = await pumpFincoreApp(tester);
      // ignore: unused_local_variable
      final future = openPanelWith(tester, initial: EntriesFilters.thisMonth());
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Mínimo'),
        '1000',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Máximo'),
        '100',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aplicar'));
      await tester.pumpAndSettle();

      // Snackbar visible con el mensaje del warning.
      expect(
        find.textContaining('rango de monto no es válido'),
        findsOneWidget,
      );
      // Panel sigue montado (no pop).
      expect(find.byType(EntriesFiltersScreen), findsOneWidget);

      await harness.dispose();
    });
  });

  // ==========================================================================
  // Hint "Sin categoría" — sprint `flutter-reports-drilldown-parity-v1`
  // ==========================================================================
  group('EntriesFiltersScreen — hint Sin categoría', () {
    Future<EntriesFilters?> openPanelWith(
      WidgetTester tester, {
      required EntriesFilters initial,
    }) {
      final ctx = tester.element(find.byType(Scaffold).first);
      return Navigator.of(ctx).push<EntriesFilters>(
        MaterialPageRoute(
          builder: (_) => EntriesFiltersScreen(
            initial: initial,
            accounts: const [],
            categories: const [],
          ),
          fullscreenDialog: true,
        ),
      );
    }

    const hintFragment = 'categorías cuyo tipo fue editado a otro flujo';

    // El screen usa `ListView` (lazy loading), así que el hint queda fuera
    // del tree hasta que scrolleamos la sección "Categorías" al viewport.
    // Usamos el chip "Sin categoría" como ancla (siempre visible en la
    // sección) y hacemos un drag adicional hacia arriba para forzar el
    // renderizado del hint que vive justo debajo del Wrap.
    Future<void> scrollToCategoriesSection(WidgetTester tester) async {
      await tester.scrollUntilVisible(
        find.text('Sin categoría'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.drag(
        find.byType(Scrollable).first,
        const Offset(0, -200),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('WT-DPH01: token + kinds=[income] → hint visible',
        (tester) async {
      final harness = await pumpFincoreApp(tester);
      final initial = EntriesFilters.thisMonth().copyWith(
        kinds: const ['income'],
        categoryIds: const ['__null__'],
      );
      // ignore: unused_local_variable
      final future = openPanelWith(tester, initial: initial);
      await tester.pumpAndSettle();
      await scrollToCategoriesSection(tester);

      expect(find.textContaining(hintFragment), findsOneWidget);
      await harness.dispose();
    });

    testWidgets(
        'WT-DPH02: token + kinds=[expense, credit_expense] → hint visible',
        (tester) async {
      final harness = await pumpFincoreApp(tester);
      final initial = EntriesFilters.thisMonth().copyWith(
        kinds: const ['expense', 'credit_expense'],
        categoryIds: const ['__null__'],
      );
      // ignore: unused_local_variable
      final future = openPanelWith(tester, initial: initial);
      await tester.pumpAndSettle();
      await scrollToCategoriesSection(tester);

      expect(find.textContaining(hintFragment), findsOneWidget);
      await harness.dispose();
    });

    testWidgets(
        'WT-DPH03: token + kinds mixto (income+expense) → hint NO visible (RN-P03)',
        (tester) async {
      final harness = await pumpFincoreApp(tester);
      final initial = EntriesFilters.thisMonth().copyWith(
        kinds: const ['income', 'expense'],
        categoryIds: const ['__null__'],
      );
      // ignore: unused_local_variable
      final future = openPanelWith(tester, initial: initial);
      await tester.pumpAndSettle();
      await scrollToCategoriesSection(tester);

      expect(find.textContaining(hintFragment), findsNothing);
      await harness.dispose();
    });

    testWidgets('WT-DPH04: sin token → hint NO visible', (tester) async {
      final harness = await pumpFincoreApp(tester);
      final initial = EntriesFilters.thisMonth().copyWith(
        kinds: const ['income'],
        categoryIds: const [],
      );
      // ignore: unused_local_variable
      final future = openPanelWith(tester, initial: initial);
      await tester.pumpAndSettle();
      await scrollToCategoriesSection(tester);

      expect(find.textContaining(hintFragment), findsNothing);
      await harness.dispose();
    });
  });
}
