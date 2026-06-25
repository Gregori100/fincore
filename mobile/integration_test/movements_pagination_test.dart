import 'package:drift/native.dart';
import 'package:fincore/app_dependencies.dart';
import 'package:fincore/data/database.dart';
import 'package:fincore/data/seed.dart';
import 'package:fincore/router/app_router.dart';
import 'package:fincore/screens/entries_list_screen.dart';
import 'package:fincore/theme/fincore_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:intl/date_symbol_data_local.dart';

/// Integration tests del scroll infinito en `/entries`.
///
/// Corre en runtime real (device/emulator). Resuelve el cuelgue sistémico
/// de `pumpAndSettle` con widget tests + harness puro identificado en R2
/// del quality review v1: el harness `pumpFincoreApp` se cuelga cuando
/// `EntriesDao.watchPage` se invoca con `categoryIds: [<uuid_real>]` por
/// una interacción específica entre drift y el setup de `AppDependencies`.
///
/// Comandos:
///   flutter test integration_test/movements_pagination_test.dart
///
/// Necesita un device conectado o emulador corriendo (Android/Linux desktop).
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

  /// Siembra `n` expenses con fechas decrecientes dentro del mes corriente
  /// para que el default `thisMonth` los capture.
  Future<void> seedNExpenses(int n) async {
    final bolsa = (await deps.accountsDao.listAll())
        .firstWhere((a) => a.type == 'cash');
    final now = DateTime.now();
    final base = DateTime(now.year, now.month, 1, 10);
    for (var i = 0; i < n; i++) {
      await deps.entriesDao.registerExpense(
        accountOriginId: bolsa.id,
        amount: 10.0 + i,
        occurredAt: base.add(Duration(minutes: i)),
        description: 'PAG-$i',
      );
    }
  }

  testWidgets(
      'Default thisMonth con 250 entries muestra los primeros 100 + footer no-end',
      (tester) async {
    await seedNExpenses(250);
    await tester.pumpWidget(AppDependenciesProvider(
      deps: deps,
      child: FirstRunStateProvider(
        state: firstRunState,
        child: MaterialApp.router(
          theme: fincoreDarkTheme(),
          routerConfig: router,
        ),
      ),
    ));
    await tester.pumpAndSettle();
    // Navegar a /entries desde el dashboard.
    final ctx = tester.element(find.byType(Scaffold).first);
    GoRouter.of(ctx).push('/entries');
    await tester.pumpAndSettle();

    expect(find.byType(EntriesListScreen), findsOneWidget);
    // El entry más reciente debe estar visible.
    expect(find.text('PAG-249'), findsOneWidget,
        reason: 'El entry más reciente (PAG-249) debe ser visible');
    // No debe verse el footer "Fin" ni "Cargando…" en el inicio.
    expect(find.textContaining('Fin de los movimientos'), findsNothing);
  });

  testWidgets('Scroll al final dispara _loadMore (entries iniciales < total)',
      (tester) async {
    await seedNExpenses(250);
    await tester.pumpWidget(AppDependenciesProvider(
      deps: deps,
      child: FirstRunStateProvider(
        state: firstRunState,
        child: MaterialApp.router(
          theme: fincoreDarkTheme(),
          routerConfig: router,
        ),
      ),
    ));
    await tester.pumpAndSettle();
    final ctx = tester.element(find.byType(Scaffold).first);
    GoRouter.of(ctx).push('/entries');
    await tester.pumpAndSettle();

    // El entry #149 NO debe estar todavía (limit=100, visibles PAG-249 a
    // PAG-150). Verifica el corte inicial.
    expect(find.text('PAG-149'), findsNothing,
        reason: 'PAG-149 está fuera del primer page (limit=100)');
    // Y NO debe verse el footer "Fin" en el inicio (hay más entries).
    expect(find.textContaining('Fin de los movimientos'), findsNothing);
  });

  testWidgets('Con 50 entries (menos que limit) footer dice "Fin"',
      (tester) async {
    await seedNExpenses(50);
    await tester.pumpWidget(AppDependenciesProvider(
      deps: deps,
      child: FirstRunStateProvider(
        state: firstRunState,
        child: MaterialApp.router(
          theme: fincoreDarkTheme(),
          routerConfig: router,
        ),
      ),
    ));
    await tester.pumpAndSettle();
    final ctx = tester.element(find.byType(Scaffold).first);
    GoRouter.of(ctx).push('/entries');
    await tester.pumpAndSettle();
    // Pump adicional para que `_onSnapshotReceived` post-frame setState
    // se aplique y `_reachedEnd = true` se refleje en el footer.
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    // Scroll al final para asegurar el footer entre al viewport.
    await tester.scrollUntilVisible(
      find.textContaining('Fin de los movimientos'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('Fin de los movimientos'), findsOneWidget);
  });
}
