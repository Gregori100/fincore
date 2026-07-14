import 'package:fincore/data/app_preferences_keys.dart';
import 'package:fincore/screens/categories_list_screen.dart';
import 'package:fincore/screens/help_screen.dart';
import 'package:fincore/screens/onboarding_screen.dart';
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
        'Reiniciar sin exportar: confirmación destructiva + redirect a /onboarding',
        (tester) async {
      final harness = await pumpFincoreApp(tester);

      final ctx = tester.element(find.byType(Scaffold));
      GoRouter.of(ctx).push('/settings');
      // `pumpAndSettle` cuelga porque `PackageInfo.fromPlatform()` del
      // FutureBuilder de "Acerca de" nunca resuelve en tests (MethodChannel
      // sin mock). `pump` con frame manual basta para montar SettingsScreen.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      // Sprint flutter-weekly-budgets-v1: sección Preferencias con
      // `didChangeDependencies` async que dispara setState al resolverse.
      // Pump extra para dejar que se estabilice.
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(SettingsScreen), findsOneWidget);

      // Scroll al botón destructivo en "Zona peligrosa". `OutlinedButton.icon`
      // genera widgets internos donde el Text es descendant del button; usamos
      // `find.text` y subimos al OutlinedButton ancestor.
      final resetText = find.text('Reiniciar sin exportar', skipOffstage: false);
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

      // S1 quality review v1: tras `wipeAll`, el state también resetea
      // `onboarding_seen` → router redirige a `/onboarding` (no a
      // `/first-run`). Antes del fix, el state quedaba `onboardingSeen=true`
      // en memoria y el router iba a `/first-run`, contradiciendo el
      // comentario de `backup.dart` ("el usuario lo verá de nuevo").
      expect(find.byType(OnboardingScreen), findsOneWidget,
          reason: 'Tras reset destructivo el usuario vuelve a ver onboarding');
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

  // Sprint `flutter-onboarding-for-testers-v1`: tests del indicador de
  // último respaldo + tap en "Ayuda".
  group('SettingsScreen — sprint onboarding-for-testers-v1', () {
    Future<void> openSettings(WidgetTester tester) async {
      final ctx = tester.element(find.byType(Scaffold).first);
      GoRouter.of(ctx).push('/settings');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      // Sprint flutter-weekly-budgets-v1: sección Preferencias agrega un
      // `didChangeDependencies` async que dispara setState al resolverse.
      // Un pump extra deja que se estabilicen ese setState + el
      // FutureBuilder de `_LastExportInfo` (que se rebuildea con el
      // setState del padre).
      await tester.pump(const Duration(milliseconds: 200));
    }

    testWidgets(
        'WT-S-LX01: last_export_at no existe → renderea "Aún no exportaste"',
        (tester) async {
      final harness = await pumpFincoreApp(tester);
      await openSettings(tester);
      expect(find.byType(SettingsScreen), findsOneWidget);
      // Sprint flutter-weekly-budgets-v1: la sección Preferencias empujó
      // el "Respaldo" fuera del viewport inicial en algunos runs.
      // `skipOffstage: false` para tolerar el layout más largo.
      expect(
        find.text('Aún no exportaste un respaldo.', skipOffstage: false),
        findsOneWidget,
      );
      await harness.dispose();
    });

    testWidgets(
        'WT-S-LX02: last_export_at hace 5 días → texto neutro sin warning',
        (tester) async {
      final harness = await pumpFincoreApp(tester, seed: (db, deps) async {
        final fiveDaysAgo =
            DateTime.now().subtract(const Duration(days: 5));
        await deps.appPreferencesDao
            .set(kPrefLastExportAt, fiveDaysAgo.toIso8601String());
      });
      await openSettings(tester);
      expect(
        find.text('Último respaldo: hace 5 días.', skipOffstage: false),
        findsOneWidget,
      );
      expect(
        find.byIcon(Icons.warning_amber_rounded, skipOffstage: false),
        findsNothing,
      );
      await harness.dispose();
    });

    testWidgets(
        'WT-S-LX03: last_export_at hace 20 días → warning badge',
        (tester) async {
      final harness = await pumpFincoreApp(tester, seed: (db, deps) async {
        final twentyDaysAgo =
            DateTime.now().subtract(const Duration(days: 20));
        await deps.appPreferencesDao
            .set(kPrefLastExportAt, twentyDaysAgo.toIso8601String());
      });
      await openSettings(tester);
      expect(
        find.textContaining('te recomendamos exportar pronto',
            skipOffstage: false),
        findsOneWidget,
      );
      expect(
        find.byIcon(Icons.warning_amber_rounded, skipOffstage: false),
        findsOneWidget,
      );
      await harness.dispose();
    });

    testWidgets(
        'WT-S-LX04: last_export_at corrupto → "Aún no exportaste"',
        (tester) async {
      final harness = await pumpFincoreApp(tester, seed: (db, deps) async {
        await deps.appPreferencesDao.set(kPrefLastExportAt, 'not-a-date');
      });
      await openSettings(tester);
      expect(
        find.text('Aún no exportaste un respaldo.', skipOffstage: false),
        findsOneWidget,
      );
      await harness.dispose();
    });

    testWidgets(
        'WT-S-LX05: tap en BaseCard "Ayuda" navega a /help',
        (tester) async {
      final harness = await pumpFincoreApp(tester);
      await openSettings(tester);
      // Sprint flutter-weekly-budgets-v1: la sección Preferencias empujó
      // "Ayuda" más abajo del cacheExtent del ListView, así que
      // `find.text` (con o sin skipOffstage) no encuentra el widget
      // porque nunca se construyó. Scrolleamos con `dragUntilVisible`
      // hasta que se materialice.
      final helpFinder = find.text('FAQ sobre tipos de movimientos, reportes, presupuestos y respaldo.');
      await tester.dragUntilVisible(
        helpFinder,
        find.byType(Scrollable).first,
        const Offset(0, -100),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(helpFinder);
      await tester.pumpAndSettle();
      expect(find.byType(HelpScreen), findsOneWidget);
      await harness.dispose();
    });
  });
}
