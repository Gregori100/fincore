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

    testWidgets(
        'Alta sin nombre queda bloqueada por validator + sin cuenta creada (RF-203 v2)',
        (tester) async {
      final harness = await pumpFincoreApp(tester);

      final ctx = tester.element(find.byType(Scaffold));
      GoRouter.of(ctx).push('/accounts/new');
      await tester.pumpAndSettle();

      // NO completar nombre. Scroll y tap submit directo.
      await tester.scrollUntilVisible(
        find.text('Crear cuenta'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Crear cuenta'));
      await tester.pumpAndSettle();

      // Form sigue montado (no cerró por validator bloqueado).
      expect(find.byType(AccountFormScreen), findsOneWidget,
          reason: 'El form se cerró aunque el nombre era vacío');
      // No se creó cuenta extra (solo Bolsa de seedDefaults).
      final all = await harness.deps.accountsDao.listAll();
      expect(all.length, 1,
          reason: 'Solo debería existir la Bolsa, sin la cuenta vacía');

      await harness.dispose();
    });

    testWidgets(
        'Alta con duplicate_account_name muestra snackbar de error (RF-203 v2)',
        (tester) async {
      final harness = await pumpFincoreApp(
        tester,
        seed: (db, deps) async {
          await deps.accountsDao.create(name: 'Banamex', type: 'debit');
        },
      );

      final ctx = tester.element(find.byType(Scaffold));
      GoRouter.of(ctx).push('/accounts/new');
      await tester.pumpAndSettle();

      // Intentar crear OTRA cuenta con el mismo nombre.
      final nameField = find.ancestor(
        of: find.text('Nombre'),
        matching: find.byType(TextFormField),
      ).first;
      await tester.enterText(nameField, 'Banamex');
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Crear cuenta'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Crear cuenta'));
      await tester.pumpAndSettle();

      // Snackbar de error con mensaje amigable mapeado de `duplicate_account_name`.
      expect(find.byType(SnackBar), findsOneWidget,
          reason: 'Debería aparecer un snackbar de error');
      // El error_snackbar mapea duplicate_account_name a "Ya existe una cuenta..."
      expect(
        find.textContaining('Ya tenés una cuenta'),
        findsOneWidget,
        reason: 'El snackbar debería contener el mensaje de duplicate_account_name',
      );

      // Solo hay 1 cuenta debit (Banamex) + Bolsa = 2. No se creó la duplicada.
      final all = await harness.deps.accountsDao.listAll();
      expect(all.length, 2, reason: 'Cuenta duplicada no debería crearse');

      await harness.dispose();
    });

    testWidgets(
        'Edición de Bolsa (protected) NO muestra botón "Guardar cambios" (RF-203 v2)',
        (tester) async {
      final harness = await pumpFincoreApp(tester);

      // Bolsa es la cuenta protected creada por seedDefaults.
      final bolsa = (await harness.deps.accountsDao.listAll())
          .firstWhere((a) => a.type == 'cash');

      final ctx = tester.element(find.byType(Scaffold));
      GoRouter.of(ctx).push('/accounts/${bolsa.id}/edit');
      await tester.pumpAndSettle();

      expect(find.byType(AccountFormScreen), findsOneWidget);
      // Bolsa protected usa `_ProtectedView` (widget custom, no ListView del
      // form normal). NO debería mostrar "Guardar cambios" ni "Archivar
      // cuenta" en ningún lado del árbol.
      expect(find.text('Guardar cambios'), findsNothing,
          reason: 'Bolsa protected no debería mostrar "Guardar cambios"');
      expect(find.text('Archivar cuenta'), findsNothing,
          reason: 'Bolsa protected no debería mostrar "Archivar cuenta"');

      await harness.dispose();
    });
  });
}
