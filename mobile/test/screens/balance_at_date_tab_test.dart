import 'package:fincore/screens/reports/balance_at_date_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../helpers/widget_test_harness.dart';

/// Widget tests del `BalanceAtDateTab`. Sprint
/// `flutter-reports-balance-at-date-v1`.
void main() {
  /// Helper: navega a `/reports` y tappea el cuarto tab.
  ///
  /// El TabBar tiene `isScrollable: true` desde el sprint del 3er tab. Con
  /// 4 tabs el cuarto puede quedar fuera del viewport inicial, así que
  /// `ensureVisible` lo trae antes del tap.
  Future<void> openBalanceAtDateTab(WidgetTester tester) async {
    final ctx = tester.element(find.byType(Scaffold).first);
    GoRouter.of(ctx).push('/reports');
    await tester.pumpAndSettle();
    final tabFinder = find.text('Saldo a fecha');
    await tester.ensureVisible(tabFinder);
    await tester.pumpAndSettle();
    await tester.tap(tabFinder);
    await tester.pumpAndSettle();
  }

  group('BalanceAtDateTab', () {
    testWidgets(
        'WT-01: render con datos: 3 cards BO/DE/CR + lista de cuentas',
        (tester) async {
      final harness = await pumpFincoreApp(tester, seed: (db, deps) async {
        await deps.accountsDao.create(name: 'BBVA_B', type: 'debit');
        final bolsa = (await deps.accountsDao.listAll())
            .firstWhere((a) => a.type == 'cash');
        final now = DateTime.now();
        await deps.entriesDao.registerIncome(
          accountDestinationId: bolsa.id,
          amount: 150000,
          occurredAt: DateTime(now.year, now.month - 1, 15),
        );
      });

      await openBalanceAtDateTab(tester);

      expect(find.byType(BalanceAtDateTab), findsOneWidget);
      // 3 cards de totales.
      expect(find.text('BO'), findsOneWidget);
      expect(find.text('DE'), findsOneWidget);
      expect(find.text('CR'), findsOneWidget);
      // Bolsa en la lista (cuenta del seed).
      expect(find.text('Bolsa'), findsOneWidget);
      expect(find.text('Efectivo'), findsOneWidget);

      await harness.dispose();
    });

    testWidgets('WT-02: empty state cuando BD sin cuentas activas',
        (tester) async {
      // seedBolsa: false → BD sin ninguna cuenta. El router redirige a
      // /first-run; navegamos manualmente a /reports.
      final harness = await pumpFincoreApp(tester, seedBolsa: false);
      // Forzar firstRunState = true para que el push a /reports no
      // redirija al first-run.
      harness.firstRunState.value = true;
      await tester.pumpAndSettle();

      // Navegar al dashboard primero (que es el root tras firstRun=true).
      final ctx = tester.element(find.byType(Scaffold).first);
      GoRouter.of(ctx).push('/reports');
      await tester.pumpAndSettle();
      final tabFinder = find.text('Saldo a fecha');
      await tester.ensureVisible(tabFinder);
      await tester.pumpAndSettle();
      await tester.tap(tabFinder);
      await tester.pumpAndSettle();

      expect(find.text('No hay cuentas activas.'), findsOneWidget);

      await harness.dispose();
    });

    testWidgets('WT-03: tap en field de fecha abre date picker',
        (tester) async {
      final harness = await pumpFincoreApp(tester);

      await openBalanceAtDateTab(tester);

      // El field "Saldo al" debe estar visible.
      expect(find.text('Saldo al'), findsAtLeastNWidgets(1));
      // Tap en el field abre el date picker.
      await tester.tap(find.text('Saldo al').last);
      await tester.pumpAndSettle();

      expect(find.byType(DatePickerDialog), findsOneWidget);

      await harness.dispose();
    });
  });
}
