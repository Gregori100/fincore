import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:fincore/app_dependencies.dart';
import 'package:fincore/data/database.dart';
import 'package:fincore/data/seed.dart';
import 'package:fincore/router/app_router.dart';
import 'package:fincore/theme/fincore_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'sqlite_override.dart';

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
  } else if (initialRoute == '/first-run' && seedBolsa) {
    // Inconsistencia: pediste /first-run pero seedBolsa=true. El redirect te
    // mandará a /dashboard. Lo fuerzo igual para evitar sorpresas mudas.
    router.go(initialRoute);
    await tester.pumpAndSettle();
  }

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
  final dynamic router; // GoRouter, pero evitamos importar go_router acá.
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
