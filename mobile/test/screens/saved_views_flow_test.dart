import 'package:fincore/data/entries_filters.dart';
import 'package:fincore/screens/entries_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../helpers/widget_test_harness.dart';

/// Widget tests del flow de vistas guardadas. Sprint
/// `flutter-entries-saved-views-v1` (CM-03).
void main() {
  group('Saved views flow', () {
    testWidgets(
        'WT-01: guardar vista desde el panel persiste en BD',
        (tester) async {
      final harness = await pumpFincoreApp(tester);

      // Push a /entries.
      final ctx = tester.element(find.byType(Scaffold).first);
      GoRouter.of(ctx).push('/entries');
      await tester.pumpAndSettle();

      // Abrir panel de filtros.
      await tester.tap(find.byTooltip('Filtros'));
      await tester.pumpAndSettle();

      // Scroll para llegar al botón "Guardar como vista" (al final del
      // panel).
      await tester.scrollUntilVisible(
        find.text('Guardar como vista'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Guardar como vista'));
      await tester.pumpAndSettle();

      // Sheet visible: ingresar nombre y guardar. Tras el patch UX v2,
      // el dialog es un modal bottom sheet con TextField (no
      // TextFormField). Usamos `.last` porque el panel también tiene
      // TextFields para los montos.
      expect(find.text('Guardar vista'), findsOneWidget);
      await tester.enterText(find.byType(TextField).last, 'Mi vista');
      await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
      await tester.pumpAndSettle();

      // Verificar en BD.
      final views = await harness.deps.savedViewsDao.listAll();
      expect(views, hasLength(1));
      expect(views.first.name, 'Mi vista');

      await harness.dispose();
    });

    testWidgets(
        'WT-02: aplicar vista desde AppBar setea los filtros',
        (tester) async {
      final harness = await pumpFincoreApp(tester, seed: (db, deps) async {
        // Sembrar 1 vista con kinds=[expense].
        await deps.savedViewsDao.create(
          name: 'Solo gastos',
          filters: EntriesFilters.thisMonth().copyWith(
            kinds: const ['expense'],
          ),
        );
      });

      final ctx = tester.element(find.byType(Scaffold).first);
      GoRouter.of(ctx).push('/entries');
      await tester.pumpAndSettle();

      // Tap en el icono de bookmarks.
      await tester.tap(find.byTooltip('Mis vistas'));
      await tester.pumpAndSettle();

      // Sheet visible con la vista.
      expect(find.text('Solo gastos'), findsOneWidget);

      // Tap en la vista (en el ListTile, no en el menú).
      await tester.tap(find.text('Solo gastos'));
      await tester.pumpAndSettle();

      // El sheet se cerró. El screen sigue montado.
      expect(find.byType(EntriesListScreen), findsOneWidget);
      // El chip del filtro activo debe aparecer.
      expect(find.text('Gasto'), findsOneWidget);

      await harness.dispose();
    });

    testWidgets(
        'WT-03: empty state cuando no hay vistas guardadas',
        (tester) async {
      final harness = await pumpFincoreApp(tester);

      final ctx = tester.element(find.byType(Scaffold).first);
      GoRouter.of(ctx).push('/entries');
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Mis vistas'));
      await tester.pumpAndSettle();

      expect(find.byType(SavedViewPickerSheetMarker), findsNothing,
          reason: 'marker no existe, sólo el contenido del sheet');
      expect(
        find.text('No tenés vistas guardadas todavía.'),
        findsOneWidget,
      );

      await harness.dispose();
    });
  });
}

/// Marker para validación (no se usa realmente, sólo para mostrar
/// que el find esperado del empty state es por texto, no por widget
/// dedicado).
class SavedViewPickerSheetMarker extends Widget {
  const SavedViewPickerSheetMarker({super.key});
  @override
  Element createElement() => throw UnimplementedError();
}
