import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:fincore/app_dependencies.dart';
import 'package:fincore/data/database.dart';
import 'package:fincore/data/seed.dart';
import 'package:fincore/router/app_router.dart';
import 'package:fincore/theme/fincore_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart' show GoRouter;
import 'package:intl/date_symbol_data_local.dart';

import 'sqlite_override.dart';

/// L1-H1 quality review v3: bandera simple. El scheduler actual de flutter
/// test es serial dentro del mismo isolate, así que la condición de carrera
/// teórica (dos tests inicializando el locale al mismo tiempo) no aplica.
/// Si en el futuro se habilita scheduler paralelo en el mismo isolate,
/// reevaluar con un `Completer<void>` que serialice la carga.
bool _localeInitialized = false;

/// Resultado del harness — expone las piezas para que los tests las inspeccionen.
class FincoreTestHarness {
  final FincoreDatabase database;
  final AppDependencies deps;
  final FirstRunState firstRunState;

  /// Sprint flutter-loans-flexible-payments-v1: expuesto para poder navegar a
  /// rutas cuyo path depende de un id generado DENTRO del `seed` (ej.
  /// `/loans/:id`), que no se puede pasar por `initialRoute` porque todavía
  /// no existe cuando se llama al harness.
  final GoRouter router;

  FincoreTestHarness({
    required this.database,
    required this.deps,
    required this.firstRunState,
    required this.router,
  });

  Future<void> dispose() async {
    await database.close();
  }
}

/// Monta la app FinCore con BD in-memory dentro de un widget test.
///
/// Patrón de uso:
///
/// ```dart
/// testWidgets('Dashboard muestra Bolsa con BD recién seedeada', (tester) async {
///   final harness = await pumpFincoreApp(tester);
///   expect(find.text('Bolsa'), findsOneWidget);
///   await harness.dispose();
/// });
/// ```
///
/// - `initialRoute`: ruta a navegar tras el pump inicial. Default `/dashboard`.
///   El router siempre arranca en `/splash` y redirige según `firstRunState`;
///   si el caller pide otra ruta, el harness hace `router.go(initialRoute)`
///   tras el primer `pumpAndSettle`.
/// - `seed`: callback opcional para sembrar datos extra (cuentas, categorías,
///   movimientos) ANTES del primer build. La Bolsa singleton ya está sembrada
///   por default vía `seedDefaults` salvo que se pase `seedBolsa: false`.
/// - `seedBolsa`: si `false`, NO se ejecuta `seedDefaults`. Útil para tests del
///   first-run que validan el splash → /first-run.
/// - `onboardingSeen`: por default `true` para que los tests existentes (que
///   asumían el flujo previo a este sprint) no rompan. Tests específicos del
///   onboarding deben pasar `false` para forzar el redirect a `/onboarding`.
Future<FincoreTestHarness> pumpFincoreApp(
  WidgetTester tester, {
  String initialRoute = '/dashboard',
  Future<void> Function(FincoreDatabase db, AppDependencies deps)? seed,
  bool seedBolsa = true,
  bool onboardingSeen = true,
}) async {
  // RF-011 v4 (L1-H2 quality review v3): combinación ambigua. Si Diego pide
  // `/first-run` con la Bolsa ya sembrada, el router redirigirá inmediatamente
  // a `/dashboard` y el test queda en una pantalla distinta a la pedida sin
  // pista clara. Hacerlo bloqueante deja el contrato explícito.
  assert(
    !(seedBolsa && initialRoute == '/first-run'),
    "pumpFincoreApp: combinación ambigua seedBolsa=true + initialRoute='/first-run'. "
    "Si quieres probar el first-run, pasar seedBolsa: false.",
  );
  initSqliteOverride();
  // Cada widget test arma su propio FincoreDatabase in-memory. Drift loguea un
  // WARNING cuando detecta múltiples instancias en el mismo isolate aunque el
  // executor sea distinto. En tests es intencional, así que lo silenciamos.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  // Las pantallas que formatean fechas (entry_form, dashboard) crashean con
  // LocaleDataException si `initializeDateFormatting('es_MX')` nunca corrió.
  // El `main.dart` real lo hace antes de runApp; en tests lo hacemos aquí
  // una sola vez por isolate.
  if (!_localeInitialized) {
    await initializeDateFormatting('es_MX', null);
    _localeInitialized = true;
  }

  final database = FincoreDatabase(NativeDatabase.memory());
  final deps = AppDependencies.fromDatabase(database);

  if (seedBolsa) {
    await seedDefaults(
      db: database,
      accountsDao: deps.accountsDao,
      categoriesDao: deps.categoriesDao,
    );
  }

  if (seed != null) {
    await seed(database, deps);
  }

  final firstRunState = FirstRunState();
  // Sin esto, el redirect del router queda colgado en /splash esperando que
  // alguien complete el chequeo async de hasBolsa. En tests resolvemos sync
  // para no depender de timers de pumpAndSettle.
  // Sprint `flutter-onboarding-for-testers-v1`: el router ahora también
  // observa `onboardingSeen`. Default true para no romper tests previos.
  firstRunState.setInitial(
    hasBolsa: seedBolsa,
    onboardingSeen: onboardingSeen,
  );

  final router = buildAppRouter(deps: deps, firstRunState: firstRunState);

  await tester.pumpWidget(FincoreApp(
    deps: deps,
    router: router,
    firstRunState: firstRunState,
  ));
  await tester.pumpAndSettle();

  if (initialRoute != '/dashboard' && initialRoute != '/first-run') {
    router.go(initialRoute);
    await tester.pumpAndSettle();
  }
  // RF-011 v4: la rama `initialRoute == '/first-run' && seedBolsa` ahora es
  // imposible por el assert al inicio; el redirect del router resuelve el
  // caso `seedBolsa=false` solo.

  return FincoreTestHarness(
    database: database,
    deps: deps,
    firstRunState: firstRunState,
    router: router,
  );
}

/// RF-101 v1: abre el `DropdownMenu<String>` cuyo field tiene el label dado.
///
/// Patrón identificado tras el cuelgue del RF-019 del v4: `tester.tap(find.text(label))`
/// no logra hit-test sobre el field porque el `Text(label)` vive dentro del
/// `InputDecorator` y el offset derivado del Text no toca el área tappeable.
///
/// El fix es tappear el `DropdownMenu<String>` directamente. Material 3 abre
/// el menú con cualquier tap en el field. El `find.ancestor` filtra por field
/// específico cuando hay múltiples DropdownMenu en pantalla (`pago_de_tarjeta`
/// y `transfer` tienen 2 fields cada uno).
Future<void> openDropdownByLabel(
  WidgetTester tester,
  String fieldLabel,
) async {
  final field = find.ancestor(
    of: find.text(fieldLabel),
    matching: find.byType(DropdownMenu<String>),
  );
  expect(field, findsOneWidget,
      reason: 'No encontré exactamente un DropdownMenu<String> con label "$fieldLabel"');
  // Sin `ensureVisible`, cuando el form tiene scroll (kinds con 2 dropdowns)
  // el segundo field puede quedar fuera del viewport tras cerrar el primero
  // y el `tap` deriva un offset que no hit-testea.
  await tester.ensureVisible(field);
  await tester.pumpAndSettle();
  await tester.tap(field);
  await tester.pumpAndSettle();
}

/// RF-102 v1: valida items visibles del DropdownMenu actualmente abierto.
///
/// `shouldShow`: cada string debe aparecer como sub-string en al menos un Text
/// dentro del menú overlay (usamos `find.textContaining` porque las entries
/// del `AccountPicker` formatean `'$name  ·  $typeLabel'`).
/// `shouldNotShow`: el opuesto, ninguno debe aparecer.
///
/// Después de validar, cierra el dropdown con ESC. El tap fuera del overlay
/// es frágil porque el overlay puede tapar al AppBar y otros tap targets.
Future<void> verifyDropdownItems(
  WidgetTester tester, {
  required List<String> shouldShow,
  required List<String> shouldNotShow,
}) async {
  for (final name in shouldShow) {
    expect(
      find.textContaining(name),
      findsAtLeastNWidgets(1),
      reason: '"$name" debería aparecer en el dropdown abierto',
    );
  }
  for (final name in shouldNotShow) {
    expect(
      find.textContaining(name),
      findsNothing,
      reason: '"$name" NO debería aparecer en el dropdown abierto',
    );
  }
}

/// Versión reducida del `FincoreApp` real, sin acoplarse a `runApp` ni a
/// `SystemChrome`. Reusa el `MaterialApp.router` con el theme oscuro.
class FincoreApp extends StatelessWidget {
  final AppDependencies deps;
  // RF-013 v4 (L1-H5 quality review v3): tipado fuerte. Antes `dynamic` para
  // evitar importar go_router; ahora se importa con `show GoRouter` para
  // mantener el surface mínimo y blindar a cambios de signature.
  final GoRouter router;
  final FirstRunState firstRunState;

  const FincoreApp({
    super.key,
    required this.deps,
    required this.router,
    required this.firstRunState,
  });

  @override
  Widget build(BuildContext context) {
    return AppDependenciesProvider(
      deps: deps,
      child: FirstRunStateProvider(
        state: firstRunState,
        child: MaterialApp.router(
          title: 'FinCore (test)',
          debugShowCheckedModeBanner: false,
          theme: fincoreDarkTheme(),
          routerConfig: router,
          // Espejar la config de localizations del main.dart para que
          // los widget tests reproduzcan el mismo entorno de A11Y.
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('es', 'MX'),
            Locale('en', 'US'),
          ],
          locale: const Locale('es', 'MX'),
        ),
      ),
    );
  }
}
