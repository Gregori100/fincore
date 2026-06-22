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

      // Tap en el botón outline rojo "Cancelar movimiento". Antes del dialog
      // hay 1 match; tras el dialog habrá 2 (form + FilledButton del dialog).
      // El form es más alto que el viewport default (800x600); scroll first.
      final cancelButton = find.text('Cancelar movimiento');
      await tester.ensureVisible(cancelButton);
      await tester.pumpAndSettle();
      await tester.tap(cancelButton);
      await tester.pumpAndSettle();

      // Confirmar en el AlertDialog tocando el FilledButton destructivo.
      // Filtramos por descendiente del dialog para no tocar el del form.
      final confirmButton = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, 'Cancelar movimiento'),
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
      expect(find.text('BO'), findsOneWidget);

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

      // El TextFormField del monto trae "150.0" como valor inicial.
      // Lo reemplazamos por 200.
      final amountField = find.widgetWithText(TextFormField, '150.0');
      expect(amountField, findsOneWidget,
          reason: 'Monto inicial 150.0 no encontrado en el form de edit');
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
      expect(find.text('BO'), findsOneWidget);

      // Verificación de persistencia: el monto en la BD ahora es 200.
      final entry = await harness.deps.entriesDao.findById(entryId);
      expect(entry?.entry.amount, 200.0,
          reason: 'El amount no se persistió tras Guardar cambios');

      await harness.dispose();
    });
  });
}
