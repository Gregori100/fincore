import 'package:fincore/screens/account_form_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../helpers/widget_test_harness.dart';

/// Tests del account_form_screen — alta + edición.
/// RF-020 v1 del sprint flutter-ui-test-coverage-v1.
void main() {
  group('AccountFormScreen — CRUD (RF-020 v1)', () {
    testWidgets('Alta nueva: monta el form con campos visibles',
        (tester) async {
      final harness = await pumpFincoreApp(tester);

      final ctx = tester.element(find.byType(Scaffold));
      GoRouter.of(ctx).push('/accounts/new');
      await tester.pumpAndSettle();

      expect(find.byType(AccountFormScreen), findsOneWidget);
      expect(find.text('Tipo de cuenta'), findsOneWidget);
      expect(find.text('Nombre'), findsOneWidget);

      await harness.dispose();
    });

    testWidgets(
        'Alta de debit nuevo persiste en BD',
        (tester) async {
      final harness = await pumpFincoreApp(tester);

      final ctx = tester.element(find.byType(Scaffold));
      GoRouter.of(ctx).push('/accounts/new');
      await tester.pumpAndSettle();

      // Llenar nombre (debit es el default).
      final nameField = find.ancestor(
        of: find.text('Nombre'),
        matching: find.byType(TextFormField),
      ).first;
      await tester.enterText(nameField, 'Banamex');
      await tester.pumpAndSettle();

      // Scroll al botón submit + tap (mismo patrón que category form).
      await tester.scrollUntilVisible(
        find.text('Crear cuenta'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Crear cuenta'));
      await tester.pumpAndSettle();

      // Verificar persistencia.
      final all = await harness.deps.accountsDao.listAll();
      expect(
        all.any((a) => a.name == 'Banamex' && a.type == 'debit'),
        isTrue,
        reason: 'La cuenta "Banamex" tipo debit debería persistir',
      );

      await harness.dispose();
    });

    testWidgets(
        'Edición de debit existente persiste el cambio de nombre',
        (tester) async {
      late String banamexId;
      final harness = await pumpFincoreApp(
        tester,
        seed: (db, deps) async {
          banamexId = await deps.accountsDao.create(
            name: 'Banamex',
            type: 'debit',
          );
        },
      );

      final ctx = tester.element(find.byType(Scaffold));
      GoRouter.of(ctx).push('/accounts/$banamexId/edit');
      await tester.pumpAndSettle();

      // En edit, modificar el nombre del field "Nombre".
      final nameField = find.ancestor(
        of: find.text('Nombre'),
        matching: find.byType(TextFormField),
      ).first;
      await tester.enterText(nameField, 'Banamex Oro');
      await tester.pumpAndSettle();

      // Scroll y submit con "Guardar cambios".
      await tester.scrollUntilVisible(
        find.text('Guardar cambios'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar cambios'));
      await tester.pumpAndSettle();

      final updated = await harness.deps.accountsDao.findById(banamexId);
      expect(updated?.name, 'Banamex Oro');

      await harness.dispose();
    });
  });
}
