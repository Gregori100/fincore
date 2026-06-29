import 'package:fincore/screens/entry_form_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../helpers/widget_test_harness.dart';

/// Widget tests del flujo de **sugerencia automática de categoría**.
/// Sprint `flutter-entries-category-suggestion-v1`.
///
/// Cubre WT-S01..WT-S04 del test-plan:
/// - WT-S01: sugerencia visible al matchear descripción.
/// - WT-S02: manual override desactiva el chip y respeta la elección.
/// - WT-S03: editar entry NO dispara sugerencia.
/// - WT-S04: BD sin histórico no muestra el chip.
void main() {
  group('EntryFormScreen — sugerencia de categoría', () {
    /// Helper: avanza el clock virtual lo suficiente para que el debounce
    /// de 300ms del `_recalcSuggestion` complete + procesa los frames
    /// pendientes hasta que el setState con el resultado se aplique.
    Future<void> settleAfterDebounce(WidgetTester tester) async {
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
    }

    /// Navega desde /dashboard a /entries/new y deja el `KindPicker` listo
    /// para tappear.
    Future<void> openNewEntryForm(WidgetTester tester) async {
      final ctx = tester.element(find.byType(Scaffold).first);
      GoRouter.of(ctx).push('/entries/new');
      await tester.pumpAndSettle();
    }

    testWidgets(
        'WT-S01: sugerencia visible cuando la descripción matchea histórico',
        (tester) async {
      String catCafeId = '';
      final harness = await pumpFincoreApp(tester, seed: (db, deps) async {
        final bolsa = (await deps.accountsDao.listAll())
            .firstWhere((a) => a.type == 'cash');
        catCafeId = await deps.categoriesDao.create(
          name: 'Cafe_T',
          appliesTo: 'expense',
          colorSlug: 'orange',
          iconSlug: 'local-cafe',
        );
        await deps.entriesDao.registerExpense(
          accountOriginId: bolsa.id,
          amount: 50,
          occurredAt: DateTime.now().subtract(const Duration(days: 3)),
          description: 'Café',
          categoryId: catCafeId,
        );
      });

      await openNewEntryForm(tester);

      // Tappear "Gasto" en el KindPicker.
      await tester.tap(find.text('Gasto').first);
      await tester.pumpAndSettle();

      // Tipear descripción que matchea el histórico.
      await tester.enterText(
        find.widgetWithText(TextField, 'Descripción (opcional)'),
        'Café',
      );

      // Esperar el debounce + procesamiento del setState.
      await settleAfterDebounce(tester);

      // El chip "Sugerida" debe aparecer (RF-005).
      expect(find.text('Sugerida'), findsOneWidget,
          reason: 'la categoría matcheada por descripción debería '
              'pre-seleccionarse y mostrar el chip.');

      // Sanity: el ID de catCafeId se uso para esperar match — el catId
      // queda en _categoryId pero el widget solo expone el nombre. No
      // chequeamos el ID, solo la señal visual.
      expect(catCafeId, isNotEmpty);

      await harness.dispose();
    });

    testWidgets(
        'WT-S02: cambiar manualmente la categoría desactiva el chip y no se recalcula',
        (tester) async {
      String catCafeId = '';
      String catComidaId = '';
      final harness = await pumpFincoreApp(tester, seed: (db, deps) async {
        final bolsa = (await deps.accountsDao.listAll())
            .firstWhere((a) => a.type == 'cash');
        catCafeId = await deps.categoriesDao.create(
          name: 'Cafe_T',
          appliesTo: 'expense',
          colorSlug: 'orange',
          iconSlug: 'local-cafe',
        );
        catComidaId = await deps.categoriesDao.create(
          name: 'Comida_T',
          appliesTo: 'expense',
          colorSlug: 'red',
          iconSlug: 'restaurant',
        );
        await deps.entriesDao.registerExpense(
          accountOriginId: bolsa.id,
          amount: 50,
          occurredAt: DateTime.now().subtract(const Duration(days: 3)),
          description: 'Café',
          categoryId: catCafeId,
        );
      });

      await openNewEntryForm(tester);
      await tester.tap(find.text('Gasto').first);
      await tester.pumpAndSettle();

      // Disparar la sugerencia: tipear "Café".
      await tester.enterText(
        find.widgetWithText(TextField, 'Descripción (opcional)'),
        'Café',
      );
      await settleAfterDebounce(tester);

      // Chip visible.
      expect(find.text('Sugerida'), findsOneWidget);

      // Cambiar manualmente la categoría. El `CategoryPicker` usa
      // `DropdownMenu<String?>` (nullable), no `DropdownMenu<String>`,
      // por eso no se puede reusar `openDropdownByLabel` del harness
      // (que busca `DropdownMenu<String>`). Tappeamos el field
      // directamente con el filtro de tipo correcto.
      final categoryField = find.ancestor(
        of: find.text('Categoría (opcional)'),
        matching: find.byType(DropdownMenu<String?>),
      );
      expect(categoryField, findsOneWidget,
          reason: 'el CategoryPicker debería estar visible');
      await tester.ensureVisible(categoryField);
      await tester.pumpAndSettle();
      await tester.tap(categoryField);
      await tester.pumpAndSettle();
      // Tappear la entry "Comida_T" del menú.
      await tester.tap(find.text('Comida_T').last);
      await tester.pumpAndSettle();

      // El chip debería haber desaparecido (manual override).
      expect(find.text('Sugerida'), findsNothing,
          reason: 'tras cambio manual, el chip "Sugerida" debe desaparecer');

      // Cambiar más texto en descripción NO debería volver a sugerir.
      await tester.enterText(
        find.widgetWithText(TextField, 'Descripción (opcional)'),
        'Café especial',
      );
      await settleAfterDebounce(tester);
      expect(find.text('Sugerida'), findsNothing,
          reason: 'con _categoryTouched=true, el chip no debe reaparecer');

      // Sanity: el ID de catComidaId se uso para sembrar — la categoría
      // existe y aparece como opción del dropdown.
      expect(catComidaId, isNotEmpty);

      await harness.dispose();
    });

    testWidgets(
        'WT-S03: editar un entry existente NO dispara sugerencia',
        (tester) async {
      late String editingEntryId;
      final harness = await pumpFincoreApp(tester, seed: (db, deps) async {
        final bolsa = (await deps.accountsDao.listAll())
            .firstWhere((a) => a.type == 'cash');
        final catCafe = await deps.categoriesDao.create(
          name: 'Cafe_T',
          appliesTo: 'expense',
          colorSlug: 'orange',
          iconSlug: 'local-cafe',
        );
        // Entry histórico que daría match por descripción.
        await deps.entriesDao.registerExpense(
          accountOriginId: bolsa.id,
          amount: 50,
          occurredAt: DateTime.now().subtract(const Duration(days: 3)),
          description: 'Café',
          categoryId: catCafe,
        );
        // Entry que vamos a editar — SIN categoría, con descripción que
        // matchearía si la sugerencia se disparara.
        editingEntryId = await deps.entriesDao.registerExpense(
          accountOriginId: bolsa.id,
          amount: 70,
          occurredAt: DateTime.now().subtract(const Duration(days: 1)),
          description: 'Café',
          categoryId: null,
        );
      });

      final ctx = tester.element(find.byType(Scaffold).first);
      GoRouter.of(ctx).push('/entries/$editingEntryId/edit');
      await tester.pumpAndSettle();

      expect(find.byType(EntryFormScreen), findsOneWidget);
      expect(find.text('Editar movimiento'), findsOneWidget);

      // Modificar la descripción para forzar el listener (que en edit debe
      // ignorar el cálculo de sugerencia).
      await tester.enterText(
        find.widgetWithText(TextField, 'Descripción (opcional)'),
        'Café del día',
      );
      await settleAfterDebounce(tester);

      // El chip "Sugerida" NO debe aparecer aunque haya un histórico que
      // matchea (RN-S02 + RF-008).
      expect(find.text('Sugerida'), findsNothing,
          reason: 'en modo edit no se dispara sugerencia');

      await harness.dispose();
    });

    testWidgets(
        'WT-S04: BD sin histórico no muestra el chip',
        (tester) async {
      final harness = await pumpFincoreApp(tester, seed: (db, deps) async {
        // Sembrar categoría para que el picker tenga opciones pero SIN
        // entries históricos.
        await deps.categoriesDao.create(
          name: 'Cafe_T',
          appliesTo: 'expense',
          colorSlug: 'orange',
          iconSlug: 'local-cafe',
        );
      });

      await openNewEntryForm(tester);
      await tester.tap(find.text('Gasto').first);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'Descripción (opcional)'),
        'Café',
      );
      await settleAfterDebounce(tester);

      // Sin histórico no debe haber sugerencia ni chip.
      expect(find.text('Sugerida'), findsNothing);

      await harness.dispose();
    });
  });
}
