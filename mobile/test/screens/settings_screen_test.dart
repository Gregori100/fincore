import 'package:fincore/screens/categories_list_screen.dart';
import 'package:fincore/screens/first_run_screen.dart';
import 'package:fincore/screens/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../helpers/widget_test_harness.dart';

/// Tests de Settings — confirmaciones destructivas y navegación.
/// RF-023 v1 del sprint flutter-ui-test-coverage-v1.
void main() {
  group('SettingsScreen — confirmaciones (RF-023 v1)', () {
    testWidgets(
        'Reiniciar sin exportar: confirmación destructiva + redirect a /first-run',
        (tester) async {
      final harness = await pumpFincoreApp(tester);

      final ctx = tester.element(find.byType(Scaffold));
      GoRouter.of(ctx).push('/settings');
      // `pumpAndSettle` cuelga porque `PackageInfo.fromPlatform()` del
      // FutureBuilder de "Acerca de" nunca resuelve en tests (MethodChannel
      // sin mock). `pump` con frame manual basta para montar SettingsScreen.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(SettingsScreen), findsOneWidget);

      // Scroll al botón destructivo en "Zona peligrosa". `OutlinedButton.icon`
      // genera widgets internos donde el Text es descendant del button; usamos
      // `find.text` y subimos al OutlinedButton ancestor.
      final resetText = find.text('Reiniciar sin exportar');
      await tester.ensureVisible(resetText);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(resetText);
      // `pumpAndSettle` se cuelga mientras Settings está montado por el
      // FutureBuilder de PackageInfo. Usamos pump() con duration.
      await tester.pump(const Duration(milliseconds: 300));

      // AlertDialog: confirmar con el FilledButton destructivo "Borrar todo igual".
      final confirmButton = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, 'Borrar todo igual'),
      );
      expect(confirmButton, findsOneWidget);
      await tester.tap(confirmButton);
      // Igual: pump() en lugar de pumpAndSettle() porque navegamos a
      // /first-run pero Settings puede seguir colgando microtasks.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Redirige a /first-run y la BD queda wipe (sin Bolsa).
      expect(find.byType(FirstRunScreen), findsOneWidget,
          reason: 'Tras reset destructivo debería estar en /first-run');
      final accounts = await harness.deps.accountsDao.listAll();
      expect(accounts, isEmpty,
          reason: 'wipeAll() debería haber borrado todas las cuentas');

      await harness.dispose();
    });

    testWidgets('Tap card "Categorías" navega a /categories', (tester) async {
      final harness = await pumpFincoreApp(tester);

      final ctx = tester.element(find.byType(Scaffold));
      GoRouter.of(ctx).push('/settings');
      // `pumpAndSettle` cuelga porque `PackageInfo.fromPlatform()` del
      // FutureBuilder de "Acerca de" nunca resuelve en tests (MethodChannel
      // sin mock). `pump` con frame manual basta para montar SettingsScreen.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // El BaseCard de Organización tiene un Text("Categorías") como label.
      await tester.tap(find.text('Categorías'));
      await tester.pumpAndSettle();

      expect(find.byType(CategoriesListScreen), findsOneWidget,
          reason: 'Tap en card Categorías debería navegar a /categories');

      await harness.dispose();
    });
  });
}
