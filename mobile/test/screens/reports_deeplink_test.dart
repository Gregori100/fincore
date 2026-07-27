import 'package:fincore/screens/entries_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../helpers/widget_test_harness.dart';

/// Widget tests del deep link desde el reporte hacia `/entries` (sprint
/// `flutter-movements-filters-v1`, RF-022).
///
/// Validan que tap en `_SpendingBucketRow` de `SpendingByCategoryTab`
/// navega a `/entries` con los query params equivalentes y la lista se
/// rinde filtrada.
void main() {
  group('Deep link reporte → /entries (RF-022)', () {
    testWidgets(
        'Tap en bucket "Comida" del reporte navega y muestra solo entries de Comida',
        (tester) async {
      final harness = await pumpFincoreApp(
        tester,
        seed: (db, deps) async {
          final bolsa = (await deps.accountsDao.listAll())
              .firstWhere((a) => a.type == 'cash');
          final catComida = await deps.categoriesDao.create(
            name: 'Comida_DL',
            appliesTo: 'expense',
            colorSlug: 'red',
            iconSlug: 'shopping-cart',
          );
          await deps.categoriesDao.create(
            name: 'Otra_DL',
            appliesTo: 'expense',
            colorSlug: 'blue',
            iconSlug: 'truck',
          );
          final now = DateTime.now();
          final day = DateTime(now.year, now.month, 10, 10);
          await deps.entriesDao.registerExpense(
            accountOriginId: bolsa.id,
            categoryId: catComida,
            amount: 20000,
            occurredAt: day,
            description: 'EsCom1',
          );
          await deps.entriesDao.registerExpense(
            accountOriginId: bolsa.id,
            amount: 5000,
            occurredAt: day.add(const Duration(hours: 1)),
            description: 'SinCatEntry',
          );
        },
      );

      // Push a /reports.
      final ctx = tester.element(find.byType(Scaffold));
      GoRouter.of(ctx).push('/reports');
      await tester.pumpAndSettle();

      // Tap en el bucket "Comida_DL". El widget rendea una BaseCard
      // tappeable con el texto del bucket.
      await tester.tap(find.text('Comida_DL'));
      await tester.pumpAndSettle();

      // Navegó a /entries.
      expect(find.byType(EntriesListScreen), findsOneWidget);
      // Solo el entry de Comida aparece.
      expect(find.text('EsCom1'), findsOneWidget);
      expect(find.text('SinCatEntry'), findsNothing);

      await harness.dispose();
    });

    testWidgets(
        'Tap en bucket "Sin categoría" navega con token __null__ y muestra entries sin cat',
        (tester) async {
      final harness = await pumpFincoreApp(
        tester,
        seed: (db, deps) async {
          final bolsa = (await deps.accountsDao.listAll())
              .firstWhere((a) => a.type == 'cash');
          final catActiva = await deps.categoriesDao.create(
            name: 'Activa_DL',
            appliesTo: 'expense',
            colorSlug: 'red',
            iconSlug: 'shopping-cart',
          );
          final now = DateTime.now();
          final day = DateTime(now.year, now.month, 10, 10);
          await deps.entriesDao.registerExpense(
            accountOriginId: bolsa.id,
            categoryId: catActiva,
            amount: 20000,
            occurredAt: day,
            description: 'EnCatActiva',
          );
          await deps.entriesDao.registerExpense(
            accountOriginId: bolsa.id,
            amount: 5000,
            occurredAt: day.add(const Duration(hours: 1)),
            description: 'SinCategoria',
          );
        },
      );

      final ctx = tester.element(find.byType(Scaffold));
      GoRouter.of(ctx).push('/reports');
      await tester.pumpAndSettle();

      // El bucket "Sin categoría" aparece como label literal.
      await tester.tap(find.text('Sin categoría'));
      await tester.pumpAndSettle();

      expect(find.byType(EntriesListScreen), findsOneWidget);
      expect(find.text('SinCategoria'), findsOneWidget);
      expect(find.text('EnCatActiva'), findsNothing);

      await harness.dispose();
    });
  });
}
