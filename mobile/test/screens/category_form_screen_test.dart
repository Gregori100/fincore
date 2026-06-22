import 'package:fincore/screens/category_form_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../helpers/widget_test_harness.dart';

/// Tests del category_form_screen — alta + preview live + edición.
/// RF-022 v1 del sprint flutter-ui-test-coverage-v1.
void main() {
  group('CategoryFormScreen — alta + preview (RF-022 v1)', () {
    testWidgets('Alta nueva: preview muestra "Vista previa" sin nombre',
        (tester) async {
      final harness = await pumpFincoreApp(tester);

      final ctx = tester.element(find.byType(Scaffold));
      GoRouter.of(ctx).push('/categories/new');
      await tester.pumpAndSettle();

      expect(find.byType(CategoryFormScreen), findsOneWidget);

      // El preview inicial muestra el placeholder "Vista previa".
      expect(find.text('Vista previa'), findsOneWidget,
          reason: 'Preview inicial debería mostrar "Vista previa" sin nombre');

      await harness.dispose();
    });

    testWidgets(
        'Escribir nombre actualiza el preview live',
        (tester) async {
      final harness = await pumpFincoreApp(tester);

      final ctx = tester.element(find.byType(Scaffold));
      GoRouter.of(ctx).push('/categories/new');
      await tester.pumpAndSettle();

      // Encontrar el TextFormField del nombre por su label.
      final nameField = find.ancestor(
        of: find.text('Nombre'),
        matching: find.byType(TextFormField),
      ).first;
      await tester.enterText(nameField, 'Suscripciones');
      await tester.pumpAndSettle();

      // El preview ahora muestra el nombre.
      expect(find.text('Suscripciones'), findsAtLeastNWidgets(1),
          reason: 'Preview debería mostrar el nombre tras enterText');
      expect(find.text('Vista previa'), findsNothing,
          reason: 'Placeholder "Vista previa" debería desaparecer');

      await harness.dispose();
    });

    testWidgets(
        'Alta con nombre + submit persiste en la BD',
        (tester) async {
      final harness = await pumpFincoreApp(tester);

      final ctx = tester.element(find.byType(Scaffold));
      GoRouter.of(ctx).push('/categories/new');
      await tester.pumpAndSettle();

      final nameField = find.ancestor(
        of: find.text('Nombre'),
        matching: find.byType(TextFormField),
      ).first;
      await tester.enterText(nameField, 'Suscripciones');
      await tester.pumpAndSettle();

      // El botón submit está al fondo del ListView fuera del viewport 800x600.
      // `scrollUntilVisible` lazy-renderea los items hasta encontrarlo.
      await tester.scrollUntilVisible(
        find.text('Crear categoría'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Crear categoría'));
      await tester.pumpAndSettle();

      // Verificar persistencia.
      final all = await harness.deps.categoriesDao.listAll();
      expect(
        all.any((c) => c.name == 'Suscripciones'),
        isTrue,
        reason: 'La categoría "Suscripciones" debería persistir tras submit',
      );

      await harness.dispose();
    });
  });
}
