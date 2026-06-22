import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../helpers/factories.dart';
import '../helpers/widget_test_harness.dart';

/// Para cada kind, validar que tras seleccionarlo en el KindPicker el form
/// muestra los labels de origin/destination según RN-011.
///
/// Labels esperados:
/// - income → solo `Cuenta destino` (cash/debit)
/// - expense → solo `Cuenta origen` (cash/debit)
/// - credit_expense → solo `Tarjeta` (credit)
/// - debt_payment → `Pagás desde` + `Tarjeta a pagar`
/// - transfer → `Cuenta origen` + `Cuenta destino`
void main() {
  group('EntryFormScreen — 5 kinds (T044 / RF-006)', () {
    Future<void> pushNewEntry(WidgetTester tester) async {
      // Push real desde el dashboard para mantener el stack y permitir el back.
      final ctx = tester.element(find.byType(Scaffold));
      GoRouter.of(ctx).push('/entries/new');
      await tester.pumpAndSettle();
    }

    Future<void> selectKind(WidgetTester tester, String label) async {
      // Cada card del KindPicker es un InkWell con un Text de la label.
      // Tocamos el InkWell para que dispare `onChanged(k)`.
      final card = find.ancestor(
        of: find.text(label),
        matching: find.byType(InkWell),
      );
      expect(card, findsWidgets,
          reason: 'KindPicker card "$label" no encontrada');
      await tester.tap(card.first);
      await tester.pumpAndSettle();
    }

    Future<void> seedAccounts(dynamic db, dynamic deps) async {
      // La Bolsa ya está por seedDefaults; agregamos un debit y un credit.
      await db.into(db.accounts).insert(Factories.debit(name: 'Banamex'));
      await db.into(db.accounts).insert(Factories.credit(name: 'Visa'));
    }

    testWidgets('Ingreso muestra solo "Cuenta destino"', (tester) async {
      final harness = await pumpFincoreApp(tester, seed: seedAccounts);
      await pushNewEntry(tester);
      await selectKind(tester, 'Ingreso');

      // El AccountPicker dest tiene `label: Text('Cuenta destino')`.
      expect(find.text('Cuenta destino'), findsOneWidget);
      // No debería haber `Cuenta origen` ni `Tarjeta` ni `Pagás desde`.
      expect(find.text('Cuenta origen'), findsNothing);
      expect(find.text('Tarjeta'), findsNothing);
      expect(find.text('Pagás desde'), findsNothing);

      await harness.dispose();
    });

    testWidgets('Gasto muestra solo "Cuenta origen"', (tester) async {
      final harness = await pumpFincoreApp(tester, seed: seedAccounts);
      await pushNewEntry(tester);
      await selectKind(tester, 'Gasto');

      expect(find.text('Cuenta origen'), findsOneWidget);
      expect(find.text('Cuenta destino'), findsNothing);
      expect(find.text('Tarjeta'), findsNothing);

      await harness.dispose();
    });

    testWidgets('Gasto a tarjeta muestra "Tarjeta" como origen',
        (tester) async {
      final harness = await pumpFincoreApp(tester, seed: seedAccounts);
      await pushNewEntry(tester);
      await selectKind(tester, 'Gasto a tarjeta');

      expect(find.text('Tarjeta'), findsOneWidget);
      expect(find.text('Cuenta destino'), findsNothing);
      expect(find.text('Pagás desde'), findsNothing);

      await harness.dispose();
    });

    testWidgets('Pago de tarjeta muestra "Pagás desde" + "Tarjeta a pagar"',
        (tester) async {
      final harness = await pumpFincoreApp(tester, seed: seedAccounts);
      await pushNewEntry(tester);
      await selectKind(tester, 'Pago de tarjeta');

      expect(find.text('Pagás desde'), findsOneWidget);
      expect(find.text('Tarjeta a pagar'), findsOneWidget);
      expect(find.text('Cuenta destino'), findsNothing);

      await harness.dispose();
    });

    testWidgets('Transferencia muestra "Cuenta origen" + "Cuenta destino"',
        (tester) async {
      final harness = await pumpFincoreApp(tester, seed: seedAccounts);
      await pushNewEntry(tester);
      await selectKind(tester, 'Transferencia');

      expect(find.text('Cuenta origen'), findsOneWidget);
      expect(find.text('Cuenta destino'), findsOneWidget);
      expect(find.text('Tarjeta'), findsNothing);

      await harness.dispose();
    });
  });
}
