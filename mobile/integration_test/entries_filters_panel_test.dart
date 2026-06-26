import 'package:drift/native.dart';
import 'package:fincore/app_dependencies.dart';
import 'package:fincore/data/database.dart';
import 'package:fincore/data/seed.dart';
import 'package:fincore/router/app_router.dart';
import 'package:fincore/theme/fincore_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:intl/date_symbol_data_local.dart';

/// Integration tests del panel de filtros del `EntriesListScreen`.
///
/// Migración de M10 del quality review v1 (`flutter-local-mvp`) + DV-2/RF-021
/// del `flutter-local-hardening-v4`. Validan que el panel rinde con cuentas
/// y categorías sembradas, el multi-select funciona y aplicar refresca la
/// lista filtrada.
///
/// Cobertura:
/// - FP-01: panel rinde cuentas + categorías sembradas como chips.
/// - FP-02: tap chip cuenta + Aplicar filtra la lista (entry de otra cuenta
///   queda fuera).
///
/// Comandos:
///   flutter test integration_test/entries_filters_panel_test.dart -d linux
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late FincoreDatabase database;
  late AppDependencies deps;
  late FirstRunState firstRunState;
  late GoRouter router;

  setUp(() async {
    database = FincoreDatabase(NativeDatabase.memory());
    deps = AppDependencies.fromDatabase(database);
    await initializeDateFormatting('es_MX', null);
    await seedDefaults(
      db: database,
      accountsDao: deps.accountsDao,
      categoriesDao: deps.categoriesDao,
    );
    firstRunState = FirstRunState();
    firstRunState.value = true;
    router = buildAppRouter(deps: deps, firstRunState: firstRunState);
  });

  tearDown(() async {
    await database.close();
  });

  Widget buildApp() {
    return AppDependenciesProvider(
      deps: deps,
      child: FirstRunStateProvider(
        state: firstRunState,
        child: MaterialApp.router(
          theme: fincoreDarkTheme(),
          routerConfig: router,
        ),
      ),
    );
  }

  testWidgets('FP-01: panel rinde cuentas + categorías sembradas como chips',
      (tester) async {
    // Seed: Bolsa (del seedDefaults) + cuenta debit "BBVA" + categoría custom.
    await deps.accountsDao.create(name: 'BBVA', type: 'debit');
    await deps.categoriesDao.create(
      name: 'Suscripciones',
      appliesTo: 'expense',
      colorSlug: 'purple',
      iconSlug: 'film',
    );

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    final ctx = tester.element(find.byType(Scaffold).first);
    GoRouter.of(ctx).push('/entries');
    await tester.pumpAndSettle();

    // Tap el ícono `tune` del AppBar para abrir el panel.
    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();

    // El panel muestra el título "Filtros".
    expect(find.text('Filtros'), findsOneWidget);
    // Las 2 cuentas (Bolsa + BBVA) aparecen como chips multi-select.
    expect(find.text('Bolsa'), findsOneWidget);
    expect(find.text('BBVA'), findsOneWidget);
    // La categoría custom aparece como chip.
    expect(find.text('Suscripciones'), findsOneWidget);
    // El chip especial "Sin categoría" siempre está.
    expect(find.text('Sin categoría'), findsOneWidget);
  });

  testWidgets('FP-02: aplicar filtro por cuenta refresca la lista',
      (tester) async {
    // Seed: Bolsa + cuenta debit BBVA con 1 expense en cada cuenta.
    final bolsa = (await deps.accountsDao.listAll())
        .firstWhere((a) => a.type == 'cash');
    final bbvaId = await deps.accountsDao.create(name: 'BBVA', type: 'debit');
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day, 10);
    await deps.entriesDao.registerExpense(
      accountOriginId: bolsa.id,
      amount: 100.0,
      occurredAt: today,
      description: 'GastoBolsa',
    );
    await deps.entriesDao.registerExpense(
      accountOriginId: bbvaId,
      amount: 200.0,
      occurredAt: today.add(const Duration(hours: 1)),
      description: 'GastoBBVA',
    );

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    final ctx = tester.element(find.byType(Scaffold).first);
    GoRouter.of(ctx).push('/entries');
    await tester.pumpAndSettle();

    // Inicialmente ambos entries son visibles.
    expect(find.text('GastoBolsa'), findsOneWidget);
    expect(find.text('GastoBBVA'), findsOneWidget);

    // Abrir panel, tap chip "BBVA", aplicar.
    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();
    await tester.tap(find.text('BBVA'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aplicar'));
    await tester.pumpAndSettle();

    // GastoBBVA persiste; GastoBolsa queda fuera.
    expect(find.text('GastoBBVA'), findsOneWidget);
    expect(find.text('GastoBolsa'), findsNothing,
        reason: 'Filtrar por BBVA debe ocultar entries de la Bolsa');
  });
}
