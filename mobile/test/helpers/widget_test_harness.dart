import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:fincore/app_dependencies.dart';
import 'package:fincore/data/database.dart';
import 'package:fincore/data/seed.dart';
import 'package:fincore/router/app_router.dart';
import 'package:fincore/theme/fincore_theme.dart';
import 'package:flutter/material.dart';
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

  FincoreTestHarness({
    required this.database,
    required this.deps,
    required this.firstRunState,
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
Future<FincoreTestHarness> pumpFincoreApp(
  WidgetTester tester, {
  String initialRoute = '/dashboard',
  Future<void> Function(FincoreDatabase db, AppDependencies deps)? seed,
  bool seedBolsa = true,
}) async {
  // RF-011 v4 (L1-H2 quality review v3): combinación ambigua. Si Diego pide
  // `/first-run` con la Bolsa ya sembrada, el router redirigirá inmediatamente
  // a `/dashboard` y el test queda en una pantalla distinta a la pedida sin
  // pista clara. Hacerlo bloqueante deja el contrato explícito.
  assert(
    !(seedBolsa && initialRoute == '/first-run'),
    "pumpFincoreApp: combinación ambigua seedBolsa=true + initialRoute='/first-run'. "
    "Si querés testear el first-run, pasá seedBolsa: false.",
  );
  initSqliteOverride();
  // Cada widget test arma su propio FincoreDatabase in-memory. Drift loguea un
  // WARNING cuando detecta múltiples instancias en el mismo isolate aunque el
  // executor sea distinto. En tests es intencional, así que lo silenciamos.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  // Las pantallas que formatean fechas (entry_form, dashboard) crashean con
  // LocaleDataException si `initializeDateFormatting('es_MX')` nunca corrió.
  // El `main.dart` real lo hace antes de runApp; en tests lo hacemos acá
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
  firstRunState.value = seedBolsa;

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
  );
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
        ),
      ),
    );
  }
}
