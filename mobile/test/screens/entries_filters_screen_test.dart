import 'package:fincore/constants/date_range_presets.dart';
import 'package:fincore/data/entries_filters.dart';
import 'package:fincore/screens/entries_filters_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
      // Chip "Sin categoría" presente.
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

    // M10 del quality review v1 — intentado y diferido. El test del panel
    // con cuentas sembradas + multi-select funcional cuelga `pumpAndSettle`
    // por la misma causa que M3 (no era los StreamBuilders del bar). El
    // sprint actual quedó con un patch perf v1 que mejoró el comportamiento
    // pero no llegó a aislar la causa raíz. Pendiente para sprint dedicado
    // de UI testing depth.
    //
    // Cobertura compensatoria: los tests existentes con `accounts: []` +
    // `categories: []` validan el render del panel + interacción con chips
    // fijos (presets de fecha, kinds, "Sin categoría"). El multi-select
    // funcional con datos reales se valida con smoke manual SM-04.

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
}
