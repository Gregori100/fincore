import 'package:fincore/screens/entry_form_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../helpers/widget_test_harness.dart';

void main() {
  group('EntryFormScreen — modo edit (RF-003, RF-004)', () {
    testWidgets(
        'Cancelar movimiento confirma + cierra el form sin gray screen',
        (tester) async {
      late String entryId;
      final harness = await pumpFincoreApp(
        tester,
        seed: (db, deps) async {
          final bolsa = (await deps.accountsDao.listAll())
              .firstWhere((a) => a.type == 'cash');
          entryId = await deps.entriesDao.registerExpense(
            accountOriginId: bolsa.id,
            amount: 150.0,
            occurredAt: DateTime.utc(2026, 6, 22, 12),
            description: 'Café',
          );
        },
      );

      // Push real desde el dashboard para que `maybePop` tenga a dónde
      // volver. Sin esto, `go_router.go` reemplaza el top y el pop queda
      // sin destino, ocultando la regresión del gray screen.
      final ctx = tester.element(find.byType(Scaffold));
      GoRouter.of(ctx).push('/entries/$entryId/edit');
      await tester.pumpAndSettle();

      expect(find.byType(EntryFormScreen), findsOneWidget,
          reason: 'EntryFormScreen no se montó tras el push a /edit');
      expect(find.text('Editar movimiento'), findsOneWidget);

      // Tap en el botón outline rojo "Eliminar movimiento". Antes del dialog
      // hay 1 match; tras el dialog habrá 2 (form + FilledButton del dialog).
      // El form es más alto que el viewport default (800x600); scroll first.
      final cancelButton = find.text('Eliminar movimiento');
      await tester.ensureVisible(cancelButton.first);
      await tester.pumpAndSettle();
      await tester.tap(cancelButton.first);
      await tester.pumpAndSettle();

      // Confirmar en el AlertDialog tocando el FilledButton destructivo.
      // Filtramos por descendiente del dialog para no tocar el del form.
      final confirmButton = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, 'Eliminar movimiento'),
      );
      expect(confirmButton, findsOneWidget);
      await tester.tap(confirmButton);
      await tester.pumpAndSettle();

      // Form cerrado, sin gray screen (que se manifestaba como ErrorWidget
      // o ausencia de AppBar). El dashboard debe estar visible de nuevo.
      expect(find.byType(EntryFormScreen), findsNothing,
          reason: 'El form sigue montado tras cancel; posible regresión gray screen');
      expect(find.text('Editar movimiento'), findsNothing);
      // Sanity: el dashboard volvió a estar visible.
      expect(find.text('BOLSA + DÉBITO'), findsOneWidget);

      await harness.dispose();
    });

    testWidgets(
        'Guardar cambios en edit modifica monto + cierra el form sin gray screen',
        (tester) async {
      late String entryId;
      final harness = await pumpFincoreApp(
        tester,
        seed: (db, deps) async {
          final bolsa = (await deps.accountsDao.listAll())
              .firstWhere((a) => a.type == 'cash');
          entryId = await deps.entriesDao.registerExpense(
            accountOriginId: bolsa.id,
            amount: 150.0,
            occurredAt: DateTime.utc(2026, 6, 22, 12),
            description: 'Café',
          );
        },
      );

      final ctx = tester.element(find.byType(Scaffold));
      GoRouter.of(ctx).push('/entries/$entryId/edit');
      await tester.pumpAndSettle();

      expect(find.byType(EntryFormScreen), findsOneWidget);

      // Sprint flutter-entry-form-redesign-v1: el amount hero no tiene label
      // "Monto" (es hero sin label). Se busca por ValueKey estable.
      final amountField = find.byKey(const ValueKey('amount_hero_field'));
      expect(amountField, findsOneWidget,
          reason: 'TextFormField del amount hero no encontrado');
      await tester.enterText(amountField, '200');
      await tester.pumpAndSettle();

      // Botón principal "Guardar cambios". El form es más alto que el
      // viewport default (800x600); scroll first.
      final saveButton = find.widgetWithText(FilledButton, 'Guardar cambios');
      expect(saveButton, findsOneWidget);
      await tester.ensureVisible(saveButton);
      await tester.pumpAndSettle();
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      expect(find.byType(EntryFormScreen), findsNothing,
          reason: 'El form sigue montado tras guardar; posible regresión gray screen');
      expect(find.text('Editar movimiento'), findsNothing);
      expect(find.text('BOLSA + DÉBITO'), findsOneWidget);

      // Verificación de persistencia: el monto en la BD ahora es 200.
      final entry = await harness.deps.entriesDao.findById(entryId);
      expect(entry?.entry.amount, 200.0,
          reason: 'El amount no se persistió tras Guardar cambios');

      await harness.dispose();
    });

    // Sprint UX de preservación de focus: el observer del lifecycle
    // recuerda cuál field tenía focus antes de `paused`/`inactive` y lo
    // restaura en `resumed`. Sin esto, salir a otra app (banco) y volver
    // pierde el focus y el teclado.
    testWidgets(
        'Focus del monto se preserva tras app pausada/resumed',
        (tester) async {
      late String entryId;
      final harness = await pumpFincoreApp(
        tester,
        seed: (db, deps) async {
          final bolsa = (await deps.accountsDao.listAll())
              .firstWhere((a) => a.type == 'cash');
          entryId = await deps.entriesDao.registerExpense(
            accountOriginId: bolsa.id,
            amount: 150.0,
            occurredAt: DateTime.utc(2026, 6, 22, 12),
            description: 'FocusTest',
          );
        },
      );
      final ctx = tester.element(find.byType(Scaffold));
      GoRouter.of(ctx).push('/entries/$entryId/edit');
      await tester.pumpAndSettle();

      // Dar focus al TextFormField del monto (buscado por Key estable
      // desde el refactor `flutter-entry-form-redesign-v1`).
      final amountField = find.byKey(const ValueKey('amount_hero_field'));
      expect(amountField, findsOneWidget);
      await tester.tap(amountField);
      await tester.pumpAndSettle();

      // Sanity: el field tiene focus.
      final amountState = tester.state<FormFieldState>(amountField);
      // ignore: invalid_use_of_protected_member
      expect(FocusScope.of(amountState.context).hasFocus, isTrue,
          reason: 'El monto no obtuvo focus tras el tap.');

      // Simular que la app pasa a background (usuario tabbea a otra app).
      // El framework de Flutter valida transiciones válidas: la secuencia
      // completa es resumed → inactive → hidden → paused (background) y
      // paused → hidden → inactive → resumed (foreground).
      tester.binding
          .handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding
          .handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding
          .handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pumpAndSettle();

      // Volver a foreground (usuario regresa desde el banco).
      tester.binding
          .handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding
          .handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding
          .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      // El focus debe volver al monto (post-frame callback ya corrió).
      // ignore: invalid_use_of_protected_member
      expect(FocusScope.of(amountState.context).hasFocus, isTrue,
          reason: 'El focus del monto no se restauró tras resumed.');

      await harness.dispose();
    });
  });
}
