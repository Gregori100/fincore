import 'package:fincore/screens/account_form_screen.dart';
import 'package:fincore/screens/category_form_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../helpers/factories.dart';
import '../helpers/widget_test_harness.dart';

void main() {
  group('AccountsListScreen — T045a / RF-007', () {
    testWidgets('Renderiza las cuentas activas sembradas', (tester) async {
      final harness = await pumpFincoreApp(
        tester,
        seed: (db, deps) async {
          await db.into(db.accounts).insert(Factories.debit(name: 'Banamex'));
          await db.into(db.accounts).insert(Factories.credit(name: 'Visa'));
        },
      );

      final ctx = tester.element(find.byType(Scaffold));
      GoRouter.of(ctx).push('/accounts');
      await tester.pumpAndSettle();

      // "Bolsa" aparece 2x: como nombre + como _typeLabel('cash'). Las demás
      // cuentas tienen labels distintos ('Débito', 'Crédito'), así que sus
      // nombres aparecen 1x.
      expect(find.text('Bolsa'), findsNWidgets(2));
      expect(find.text('Banamex'), findsOneWidget);
      expect(find.text('Visa'), findsOneWidget);

      await harness.dispose();
    });

    testWidgets('Tap en una cuenta navega al form de edición',
        (tester) async {
      final harness = await pumpFincoreApp(
        tester,
        seed: (db, deps) async {
          await db.into(db.accounts).insert(Factories.debit(name: 'Banamex'));
        },
      );

      final ctx = tester.element(find.byType(Scaffold));
      GoRouter.of(ctx).push('/accounts');
      await tester.pumpAndSettle();

      // Bolsa está protegida y NO es tappeable; Banamex sí.
      await tester.tap(find.text('Banamex'));
      await tester.pumpAndSettle();

      expect(find.byType(AccountFormScreen), findsOneWidget,
          reason: 'Tap en cuenta debit no navegó al form de edición');

      await harness.dispose();
    });
  });

  group('CategoriesListScreen — T045b / RF-007', () {
    testWidgets('Renderiza las 10 categorías default sembradas',
        (tester) async {
      final harness = await pumpFincoreApp(tester);

      final ctx = tester.element(find.byType(Scaffold));
      GoRouter.of(ctx).push('/categories');
      await tester.pumpAndSettle();

      // El DAO ordena por nombre asc; el ListView lazy-renderiza, así que
      // solo las primeras categorías alfabéticas garantizan estar montadas
      // sin scroll. Sueldo/Transporte quedan más abajo y requerirían scroll.
      expect(find.text('Comida'), findsOneWidget);
      expect(find.text('Entretenimiento'), findsOneWidget);
      expect(find.text('Hogar'), findsOneWidget);

      await harness.dispose();
    });

    testWidgets('Tap en una categoría navega al form de edición',
        (tester) async {
      final harness = await pumpFincoreApp(tester);

      final ctx = tester.element(find.byType(Scaffold));
      GoRouter.of(ctx).push('/categories');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Comida'));
      await tester.pumpAndSettle();

      expect(find.byType(CategoryFormScreen), findsOneWidget,
          reason: 'Tap en categoría no navegó al form de edición');

      await harness.dispose();
    });
  });
}
