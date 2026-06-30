import 'package:fincore/data/app_preferences_keys.dart';
import 'package:fincore/screens/first_run_screen.dart';
import 'package:fincore/screens/onboarding_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/widget_test_harness.dart';

/// Widget tests del flujo de onboarding. Sprint
/// `flutter-onboarding-for-testers-v1`.
///
/// Cobertura:
/// - WT-O01: render del slide 1 + presencia de "Saltar" + botón "Siguiente".
/// - WT-O02: tap "Siguiente" navega al slide 2.
/// - WT-O03: tap "Siguiente" dos veces llega al slide 3 con botón "Empezar".
/// - WT-O04: "Empezar" persiste el flag + navega a /first-run.
/// - WT-O05: "Saltar" desde slide 1 persiste flag + navega a /first-run.
/// - WT-O06: tap en dot navega directo a otro slide.
void main() {
  group('OnboardingScreen', () {
    testWidgets(
        'WT-O01: render slide 1 con wordmark + Saltar + Siguiente',
        (tester) async {
      final harness = await pumpFincoreApp(
        tester,
        seedBolsa: false,
        onboardingSeen: false,
      );
      expect(find.byType(OnboardingScreen), findsOneWidget);
      expect(find.text('Saltar'), findsOneWidget);
      expect(find.text('Siguiente'), findsOneWidget);
      expect(find.textContaining('libreta digital'), findsAtLeastNWidgets(1));
      await harness.dispose();
    });

    testWidgets('WT-O02: tap "Siguiente" navega al slide 2', (tester) async {
      final harness = await pumpFincoreApp(
        tester,
        seedBolsa: false,
        onboardingSeen: false,
      );
      await tester.tap(find.text('Siguiente'));
      await tester.pumpAndSettle();
      expect(find.text('Registrá cada movimiento'), findsOneWidget);
      await harness.dispose();
    });

    testWidgets(
        'WT-O03: dos taps "Siguiente" llegan al slide 3 con "Empezar"',
        (tester) async {
      final harness = await pumpFincoreApp(
        tester,
        seedBolsa: false,
        onboardingSeen: false,
      );
      await tester.tap(find.text('Siguiente'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Siguiente'));
      await tester.pumpAndSettle();
      expect(find.text('Mirá tus reportes y patrones'), findsOneWidget);
      expect(find.text('Empezar'), findsOneWidget);
      expect(find.text('Siguiente'), findsNothing);
      await harness.dispose();
    });

    testWidgets(
        'WT-O04: "Empezar" persiste flag + navega a /first-run',
        (tester) async {
      final harness = await pumpFincoreApp(
        tester,
        seedBolsa: false,
        onboardingSeen: false,
      );
      await tester.tap(find.text('Siguiente'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Siguiente'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Empezar'));
      await tester.pumpAndSettle();

      // Persistió el flag.
      final seen =
          await harness.deps.appPreferencesDao.get(kPrefOnboardingSeen);
      expect(seen, 'true');
      // T2 quality review v1: validar también que llegamos al destino
      // esperado (FirstRunScreen). Sin esto, un crash + ErrorWidget
      // haría pasar el test por la razón equivocada.
      expect(find.byType(OnboardingScreen), findsNothing);
      expect(find.byType(FirstRunScreen), findsOneWidget);
      await harness.dispose();
    });

    testWidgets(
        'WT-O05: "Saltar" desde slide 1 persiste flag + navega a /first-run',
        (tester) async {
      final harness = await pumpFincoreApp(
        tester,
        seedBolsa: false,
        onboardingSeen: false,
      );
      await tester.tap(find.text('Saltar'));
      await tester.pumpAndSettle();
      final seen =
          await harness.deps.appPreferencesDao.get(kPrefOnboardingSeen);
      expect(seen, 'true');
      expect(find.byType(OnboardingScreen), findsNothing);
      await harness.dispose();
    });

    testWidgets(
        'WT-O06: tap en dot del slide 3 navega directo',
        (tester) async {
      final harness = await pumpFincoreApp(
        tester,
        seedBolsa: false,
        onboardingSeen: false,
      );
      // 3 dots (Containers chicos). Tappeamos el último.
      final dots = find.byWidgetPredicate((w) {
        return w is GestureDetector && w.onTap != null;
      });
      // Hay 1 GestureDetector por dot (3 en total). Tappeamos el último.
      await tester.tap(dots.at(2));
      await tester.pumpAndSettle();
      expect(find.text('Mirá tus reportes y patrones'), findsOneWidget);
      expect(find.text('Empezar'), findsOneWidget);
      await harness.dispose();
    });
  });
}
