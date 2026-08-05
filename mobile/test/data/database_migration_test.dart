import 'package:drift/native.dart';
import 'package:fincore/data/database.dart';
import 'package:fincore/data/financial_state.dart';
import 'package:fincore/data/entries_filters.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/sqlite_override.dart';

/// Test de migración 2 → 3 del sprint
/// `flutter-entries-saved-views-v1` (CM-06).
///
/// Estrategia: tomar una BD en estado v3 (todas las tablas creadas por
/// `onCreate`), simular el estado pre-migración dropeando `saved_views`,
/// ejecutar el SQL equivalente al de `m.createTable(savedViews)` y
/// verificar que la tabla queda lista para uso real.
///
/// NO valida el flujo completo "abrir BD v2 → onUpgrade dispara" porque
/// drift en memoria no permite persistir el `user_version` entre dos
/// aperturas. Esa validación queda cubierta por smoke manual SM-01
/// (instalar el APK sobre la versión anterior con datos existentes).
void main() {
  setUpAll(initSqliteOverride);

  test(
      'UT-17: CREATE TABLE saved_views deja la tabla lista para CRUD '
      '(equivalente al `m.createTable` de la migración 2 → 3)',
      () async {
    final db = FincoreDatabase(NativeDatabase.memory());
    // Forzar onCreate completo.
    await db.accountsDao.listAll();

    // Sembrar datos del usuario para validar que NO se pierden al
    // dropear/recrear `saved_views`.
    final accountId =
        await db.accountsDao.create(name: 'Banamex', type: 'debit');
    final categoryId = await db.categoriesDao.create(
      name: 'Comida',
      appliesTo: 'expense',
      colorSlug: 'red',
      iconSlug: 'shopping-cart',
    );

    // Simular estado pre-migración: dropear `saved_views`.
    await db.customStatement('DROP TABLE saved_views');
    final preRows = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='saved_views'",
          readsFrom: const {},
        )
        .get();
    expect(preRows, isEmpty,
        reason: 'saved_views debería estar dropeada antes de migrar');

    // Ejecutar el SQL equivalente al de `m.createTable(savedViews)`.
    // `created_at` es TEXT (no INTEGER) porque `build.yaml` setea
    // `store_date_time_values_as_text: true` para preservar subsegundos
    // — same DateTime mapping que el codegen emite.
    await db.customStatement('''
      CREATE TABLE saved_views (
        id TEXT NOT NULL PRIMARY KEY,
        name TEXT NOT NULL,
        filters_json TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    // Verificar que la tabla existe.
    final postRows = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='saved_views'",
          readsFrom: const {},
        )
        .get();
    expect(postRows, hasLength(1));

    // Verificar que el DAO funciona end-to-end con la tabla recién
    // creada.
    final viewId = await db.savedViewsDao.create(
      name: 'TestView',
      filters: EntriesFilters.thisMonth(),
    );
    final list = await db.savedViewsDao.listAll();
    expect(list, hasLength(1));
    expect(list.first.id, viewId);
    expect(list.first.name, 'TestView');

    // Verificar que los datos del usuario sembrados antes de la migración
    // siguen ahí (validación crítica para RN-V01).
    final accountsAfter = await db.accountsDao.listAll();
    expect(accountsAfter.any((a) => a.id == accountId), isTrue,
        reason: 'cuenta sembrada antes de la migración debe persistir');
    final categoriesAfter = await db.categoriesDao.listAll();
    expect(categoriesAfter.any((c) => c.id == categoryId), isTrue,
        reason: 'categoría sembrada antes de la migración debe persistir');

    await db.close();
  });

  // Sprint flutter-saved-views-polish-v1 / H14 quality review: blindar
  // las ramas defensiva 1→3 y el guardrail UnimplementedError, que son el
  // primer schema bump del MVP. Sienta precedente para los próximos.

  test(
      'UT-18: rama defensiva 1→3 crea el índice + tabla saved_views '
      '(instalación que se saltó schemaVersion 2)',
      () async {
    final db = FincoreDatabase(NativeDatabase.memory());
    await db.accountsDao.listAll(); // fuerza onCreate.

    // Simular estado pre-1→3: dropear ambas estructuras.
    await db.customStatement('DROP TABLE saved_views');
    await db.customStatement('DROP INDEX idx_entries_occurred_active');

    // Llamar a onUpgrade vía `Migrator` directo, escenario from=1 to=3.
    final migrator = db.createMigrator();
    await db.migration.onUpgrade(migrator, 1, 3);

    // Verificar índice parcial creado.
    final idxRows = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type='index' "
          "AND name='idx_entries_occurred_active'",
          readsFrom: const {},
        )
        .get();
    expect(idxRows, hasLength(1),
        reason: 'rama 1→3 debe recrear idx_entries_occurred_active');

    // Verificar tabla saved_views creada y usable.
    final viewId = await db.savedViewsDao.create(
      name: 'Defensiva',
      filters: EntriesFilters.thisMonth(),
    );
    expect(viewId, isNotEmpty);

    await db.close();
  });

  test(
      'UT-19: guardrail UnimplementedError dispara para upgrade no '
      'implementado (RN-H02)',
      () async {
    final db = FincoreDatabase(NativeDatabase.memory());
    await db.accountsDao.listAll();
    final migrator = db.createMigrator();

    // Cualquier from/to que no esté entre las ramas explícitas debe
    // disparar el throw del guardrail.
    expect(
      () => db.migration.onUpgrade(migrator, 4, 99),
      throwsA(isA<UnimplementedError>()),
    );

    await db.close();
  });

  // ===========================================================================
  // Sprint flutter-onboarding-for-testers-v1: schema bump v3 → v4
  // ===========================================================================

  test(
      'MT-01: migración 3 → 4 crea tabla app_preferences sin tocar '
      'datos del usuario',
      () async {
    final db = FincoreDatabase(NativeDatabase.memory());
    // Forzar onCreate completo (queda en v4).
    final accountId = await db.accountsDao.create(name: 'Banamex_MT', type: 'debit');
    final categoryId = await db.categoriesDao.create(
      name: 'Comida_MT',
      appliesTo: 'expense',
      colorSlug: 'red',
      iconSlug: 'shopping-cart',
    );

    // Simular estado pre-3→4: dropear app_preferences.
    await db.customStatement('DROP TABLE app_preferences');
    final preRows = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='app_preferences'",
          readsFrom: const {},
        )
        .get();
    expect(preRows, isEmpty);

    // Ejecutar onUpgrade(3, 4) vía Migrator directo.
    final migrator = db.createMigrator();
    await db.migration.onUpgrade(migrator, 3, 4);

    // Verificar tabla creada y usable.
    await db.appPreferencesDao.set('test_key', 'test_value');
    final value = await db.appPreferencesDao.get('test_key');
    expect(value, 'test_value');

    // Verificar que los datos del usuario sembrados antes de la migración
    // siguen ahí.
    final accountsAfter = await db.accountsDao.listAll();
    expect(accountsAfter.any((a) => a.id == accountId), isTrue);
    final categoriesAfter = await db.categoriesDao.listAll();
    expect(categoriesAfter.any((c) => c.id == categoryId), isTrue);

    await db.close();
  });

  test(
      'MT-02: rama defensiva 2 → 4 crea saved_views Y app_preferences',
      () async {
    final db = FincoreDatabase(NativeDatabase.memory());
    await db.accountsDao.listAll(); // fuerza onCreate

    // Simular estado v2: dropear tanto saved_views como app_preferences.
    await db.customStatement('DROP TABLE saved_views');
    await db.customStatement('DROP TABLE app_preferences');

    final migrator = db.createMigrator();
    await db.migration.onUpgrade(migrator, 2, 4);

    // Verificar ambas tablas creadas y usables.
    final viewId = await db.savedViewsDao.create(
      name: 'V2to4',
      filters: EntriesFilters.thisMonth(),
    );
    expect(viewId, isNotEmpty);
    await db.appPreferencesDao.set('mt02_key', 'mt02_value');
    expect(await db.appPreferencesDao.get('mt02_key'), 'mt02_value');

    await db.close();
  });

  test(
      'MT-03: rama defensiva 1 → 4 crea índice + saved_views + app_preferences',
      () async {
    final db = FincoreDatabase(NativeDatabase.memory());
    await db.accountsDao.listAll();

    // Simular estado v1: sin índice parcial ni saved_views ni app_preferences.
    await db.customStatement('DROP TABLE saved_views');
    await db.customStatement('DROP TABLE app_preferences');
    await db.customStatement('DROP INDEX idx_entries_occurred_active');

    final migrator = db.createMigrator();
    await db.migration.onUpgrade(migrator, 1, 4);

    // Verificar índice creado.
    final idxRows = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type='index' "
          "AND name='idx_entries_occurred_active'",
          readsFrom: const {},
        )
        .get();
    expect(idxRows, hasLength(1));

    // Verificar saved_views usable.
    final viewId = await db.savedViewsDao.create(
      name: 'V1to4',
      filters: EntriesFilters.thisMonth(),
    );
    expect(viewId, isNotEmpty);

    // Verificar app_preferences usable.
    await db.appPreferencesDao.set('mt03_key', 'mt03_value');
    expect(await db.appPreferencesDao.get('mt03_key'), 'mt03_value');

    await db.close();
  });

  // ===========================================================================
  // Sprint flutter-weekly-budgets-v1: schema bump v6 → v7
  // ===========================================================================
  // MG-01..MG-04 del test-plan. Mismo patrón que MT-01..03: la BD in-memory
  // abre siempre en schemaVersion actual (7) vía onCreate; para simular una
  // instalación existente en v6 dropeamos las 2 tablas del planeador semanal
  // + sus índices y llamamos a `onUpgrade` vía `Migrator` directo con
  // `from=6, to=7`.
  //
  // Refactor 2026-07-14: las tablas `budget_templates`/`budget_template_items`
  // fueron eliminadas — el rol de plantilla ahora vive como `is_template` en
  // `weekly_budgets`. MG-01..04 quedan con 2 tablas y 3 índices (sin
  // `idx_bt_items_template_sort`, reemplazado por `idx_weekly_budgets_template`).

  test(
      'MG-01: BD virgen con schemaVersion=7 (onCreate) → las 2 tablas del '
      'planeador semanal existen y son usables', () async {
    final db = FincoreDatabase(NativeDatabase.memory());
    await db.accountsDao.listAll(); // fuerza onCreate.

    for (final table in [
      'weekly_budgets',
      'weekly_budget_items',
    ]) {
      final rows = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type='table' AND name='$table'",
            readsFrom: const {},
          )
          .get();
      expect(rows, hasLength(1), reason: 'tabla $table debería existir tras onCreate');
    }

    // Usable end-to-end vía el DAO, incluyendo el flag de plantilla.
    final budgetId = await db.weeklyBudgetsDao.createBudget(
      weekStartDate: DateTime(2026, 7, 17),
      label: 'MG-01',
    );
    expect(budgetId, isNotEmpty);
    await db.weeklyBudgetsDao.toggleTemplateFlag(budgetId);
    final row = await db.weeklyBudgetsDao.findById(budgetId);
    expect(row!.isTemplate, isTrue);

    await db.close();
  });

  test(
      'MG-02: BD "existente v6" (sin las 2 tablas nuevas) → onUpgrade(6, 7) '
      'las crea sin perder datos pre-existentes', () async {
    final db = FincoreDatabase(NativeDatabase.memory());
    await db.accountsDao.listAll(); // fuerza onCreate en v7.

    // Datos del usuario sembrados ANTES de simular la migración.
    final accountId =
        await db.accountsDao.create(name: 'Banamex_MG02', type: 'debit');
    final categoryId = await db.categoriesDao.create(
      name: 'Comida_MG02',
      appliesTo: 'expense',
      colorSlug: 'red',
      iconSlug: 'shopping-cart',
    );

    // Simular estado pre-6→7: dropear las 2 tablas nuevas + sus índices.
    await db.customStatement('DROP TABLE weekly_budget_items');
    await db.customStatement('DROP TABLE weekly_budgets');
    final preRows = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type='table' "
          "AND name IN ('weekly_budgets', 'weekly_budget_items')",
          readsFrom: const {},
        )
        .get();
    expect(preRows, isEmpty,
        reason: 'las 2 tablas deberían estar dropeadas antes de migrar');

    // Ejecutar onUpgrade(6, 7) vía Migrator directo.
    final migrator = db.createMigrator();
    await db.migration.onUpgrade(migrator, 6, 7);

    // Verificar las 2 tablas creadas y usables end-to-end.
    final budgetId = await db.weeklyBudgetsDao.createBudget(
      weekStartDate: DateTime(2026, 7, 17),
      label: 'MG-02',
    );
    await db.weeklyBudgetsDao.addItem(
      budgetId: budgetId,
      name: 'Renglón MG-02',
      amount: 10000,
      kind: 'expense',
    );
    expect(await db.weeklyBudgetsDao.watchAll().first, hasLength(1));
    await db.weeklyBudgetsDao.toggleTemplateFlag(budgetId);
    expect(await db.weeklyBudgetsDao.watchTemplates().first, hasLength(1));

    // Verificar que los datos pre-existentes NO se perdieron.
    final accountsAfter = await db.accountsDao.listAll();
    expect(accountsAfter.any((a) => a.id == accountId), isTrue,
        reason: 'cuenta sembrada antes de la migración debe persistir');
    final categoriesAfter = await db.categoriesDao.listAll();
    expect(categoriesAfter.any((c) => c.id == categoryId), isTrue,
        reason: 'categoría sembrada antes de la migración debe persistir');

    await db.close();
  });

  test(
      'MG-03: migración 6 → 7 es aditiva pura — crea los 3 índices nuevos '
      'sin migración de datos', () async {
    final db = FincoreDatabase(NativeDatabase.memory());
    await db.accountsDao.listAll();

    // Simular estado pre-6→7: dropear tablas + índices.
    await db.customStatement('DROP INDEX idx_weekly_budgets_start');
    await db.customStatement('DROP INDEX idx_wb_items_budget_sort');
    await db.customStatement('DROP INDEX idx_weekly_budgets_template');
    await db.customStatement('DROP TABLE weekly_budget_items');
    await db.customStatement('DROP TABLE weekly_budgets');

    final migrator = db.createMigrator();
    await db.migration.onUpgrade(migrator, 6, 7);

    for (final index in [
      'idx_weekly_budgets_start',
      'idx_wb_items_budget_sort',
      'idx_weekly_budgets_template',
    ]) {
      final rows = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type='index' AND name='$index'",
            readsFrom: const {},
          )
          .get();
      expect(rows, hasLength(1), reason: 'índice $index debe recrearse en 6→7');
    }

    await db.close();
  });

  test(
      'MG-QR-M4: 5→11, 6→11 y 7→11 crean loans + columnas + índice '
      '(hotfix quality-review — ramas defensivas)', () async {
    for (final from in [5, 6, 7]) {
      final db = FincoreDatabase(NativeDatabase.memory());
      await db.accountsDao.listAll(); // fuerza open y schema real (v11).
      final migrator = db.createMigrator();
      // No debe crashear con UnimplementedError.
      await db.migration.onUpgrade(migrator, from, 11);
      // La tabla `loans` existe.
      final loansTable = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type='table' AND name='loans'",
            readsFrom: const {},
          )
          .get();
      expect(loansTable, hasLength(1),
          reason: 'ruta $from→11 debe crear la tabla loans');
      // La columna `is_monthly_payment` existe en journal_entries.
      final colProbe = await db
          .customSelect(
            "SELECT COUNT(*) AS c FROM pragma_table_info('journal_entries') "
            "WHERE name = 'is_monthly_payment'",
            readsFrom: const {},
          )
          .getSingle();
      expect(colProbe.read<int>('c'), 1,
          reason: 'ruta $from→11 debe agregar is_monthly_payment');
      // Índice parcial de loans en entries.
      final idxProbe = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type='index' "
            "AND name='idx_entries_loan'",
            readsFrom: const {},
          )
          .get();
      expect(idxProbe, hasLength(1),
          reason: 'ruta $from→11 debe crear idx_entries_loan');
      await db.close();
    }
  });

  test(
      'MG-BIC-01: 12→13 agrega columna is_done a weekly_budget_items '
      '(sprint flutter-budgets-item-completion-v1)', () async {
    final db = FincoreDatabase(NativeDatabase.memory());
    await db.accountsDao.listAll();
    final migrator = db.createMigrator();

    // Idempotente vía probe: correr 12→13 sobre una BD que ya está en v13
    // no debe fallar.
    await db.migration.onUpgrade(migrator, 12, 13);

    final colProbe = await db
        .customSelect(
          "SELECT COUNT(*) AS c FROM pragma_table_info('weekly_budget_items') "
          "WHERE name = 'is_done'",
          readsFrom: const {},
        )
        .getSingle();
    expect(colProbe.read<int>('c'), 1,
        reason: '12→13 debe garantizar la columna is_done');

    await db.close();
  });

  test(
      'MG-BIC-02: 5→13, 8→13, 11→13 y 12→13 dejan la columna is_done '
      'presente (cadenas defensivas)', () async {
    for (final from in [5, 8, 11, 12]) {
      final db = FincoreDatabase(NativeDatabase.memory());
      await db.accountsDao.listAll(); // fuerza schema real (v13).
      final migrator = db.createMigrator();
      await db.migration.onUpgrade(migrator, from, 13);

      final colProbe = await db
          .customSelect(
            "SELECT COUNT(*) AS c FROM pragma_table_info('weekly_budget_items') "
            "WHERE name = 'is_done'",
            readsFrom: const {},
          )
          .getSingle();
      expect(colProbe.read<int>('c'), 1,
          reason: 'ruta $from→13 debe dejar is_done en la tabla');
      await db.close();
    }
  });

  test(
      'MG-04: guardrail UnimplementedError sigue activo para un upgrade no '
      'implementado (from=99, to=100)', () async {
    final db = FincoreDatabase(NativeDatabase.memory());
    await db.accountsDao.listAll();
    final migrator = db.createMigrator();

    expect(
      () => db.migration.onUpgrade(migrator, 99, 100),
      throwsA(isA<UnimplementedError>()),
    );

    await db.close();
  });

  // ===========================================================================
  // Sprint flutter-integer-cents-v1: schema bump v13 → v14
  // ===========================================================================
  //
  // La conversión REAL → INTEGER no se puede simular re-declarando las tablas
  // (el schema Dart ya está en v14), así que los tests atacan las dos
  // propiedades verificables: idempotencia del helper y que las 9 columnas
  // monetarias queden declaradas INTEGER tras cualquier ruta de migración.

  /// Tipo declarado de una columna según `pragma_table_info`.
  Future<String> declaredType(
      FincoreDatabase db, String table, String column) async {
    final row = await db
        .customSelect(
          "SELECT type FROM pragma_table_info('$table') WHERE name = '$column'",
          readsFrom: const {},
        )
        .getSingle();
    return row.read<String>('type').toUpperCase();
  }

  const moneyColumns = <(String, String)>[
    ('journal_entries', 'amount'),
    ('journal_entries', 'principal_amount'),
    ('journal_entries', 'interest_amount'),
    ('accounts', 'credit_limit'),
    ('accounts', 'minimum_floor'),
    ('loans', 'principal_amount'),
    ('loans', 'monthly_payment'),
    ('weekly_budget_items', 'amount'),
    ('categories', 'monthly_limit'),
  ];

  test(
      'MG-IC-01: las 9 columnas monetarias quedan declaradas INTEGER y los '
      '3 ratios siguen REAL (schema v14)', () async {
    final db = FincoreDatabase(NativeDatabase.memory());
    await db.accountsDao.listAll(); // fuerza onCreate en v14.

    for (final (table, column) in moneyColumns) {
      expect(await declaredType(db, table, column), 'INTEGER',
          reason: '$table.$column debe ser INTEGER (centavos, RN-IC-01)');
    }
    // Los ratios 0-1 NO son montos y quedan como REAL (RN-IC-02, P-003).
    for (final column in [
      'interest_rate',
      'minimum_payment_pct',
      'minimum_capital_pct',
    ]) {
      expect(await declaredType(db, 'accounts', column), 'REAL',
          reason: 'accounts.$column es un ratio 0-1, no un monto');
    }

    await db.close();
  });

  test(
      'MG-IC-02: la conversión 13→14 es idempotente — correrla sobre una BD '
      'ya migrada no altera los montos', () async {
    final db = FincoreDatabase(NativeDatabase.memory());
    final bolsa = await db.accountsDao.createBolsa();
    await db.entriesDao.registerIncome(
      accountDestinationId: bolsa,
      amount: 17377, // $173.77 — el monto del bug que disparó el sprint.
      occurredAt: DateTime(2026, 7, 24),
    );
    await db.entriesDao.registerExpense(
      accountOriginId: bolsa,
      amount: 5099,
      occurredAt: DateTime(2026, 7, 24),
    );
    final before = await FinancialStateService(db).accountBalanceNow(bolsa);
    expect(before, 17377 - 5099);

    // Re-ejecutar la migración: el probe de `pragma_table_info` detecta que
    // `amount` ya es INTEGER y hace no-op. Sin el probe, los montos se
    // multiplicarían por 100 otra vez.
    final migrator = db.createMigrator();
    await db.migration.onUpgrade(migrator, 13, 14);

    final after = await FinancialStateService(db).accountBalanceNow(bolsa);
    expect(after, before,
        reason: 'la migración debe ser idempotente ante reintento post-crash');

    await db.close();
  });

  test(
      'MG-IC-03: las rutas defensivas X→14 dejan las 9 columnas monetarias '
      'en INTEGER sin lanzar', () async {
    for (final from in [5, 8, 11, 12, 13]) {
      final db = FincoreDatabase(NativeDatabase.memory());
      await db.accountsDao.listAll();
      final migrator = db.createMigrator();

      await db.migration.onUpgrade(migrator, from, 14);

      for (final (table, column) in moneyColumns) {
        expect(await declaredType(db, table, column), 'INTEGER',
            reason: 'ruta $from→14 debe dejar $table.$column en INTEGER');
      }
      await db.close();
    }
  });

  test(
      'MG-IC-04: tras la migración los balances derivados son exactos — '
      'pagar el saldo completo de una tarjeta no dispara overpay_debt '
      '(regresión del bug 2026-07-24)', () async {
    final db = FincoreDatabase(NativeDatabase.memory());
    final bolsa = await db.accountsDao.createBolsa();
    final tarjeta = await db.accountsDao.create(
      name: 'Visa',
      type: 'credit',
      creditLimit: 5000000,
    );
    await db.entriesDao.registerIncome(
      accountDestinationId: bolsa,
      amount: 100000,
      occurredAt: DateTime(2026, 7, 24),
    );
    // Cargos que en `double` acumulaban residuo IEE 754 (0.1 + 0.2 ...).
    for (var i = 0; i < 10; i++) {
      await db.entriesDao.registerCreditExpense(
        accountOriginId: tarjeta,
        amount: i.isEven ? 10 : 20,
        occurredAt: DateTime(2026, 7, 24),
      );
    }
    final deuda = await FinancialStateService(db).accountBalanceNow(tarjeta);
    expect(deuda, 150, reason: '5 × 10 + 5 × 20 centavos');

    // Pagar exactamente la deuda: con centavos enteros la comparación
    // `amount > deuda` es exacta y NO hace falta la tolerancia `+ 0.005`.
    final id = await db.entriesDao.registerDebtPayment(
      accountOriginId: bolsa,
      accountDestinationId: tarjeta,
      amount: deuda,
      occurredAt: DateTime(2026, 7, 24),
    );
    expect(id, isNotEmpty);
    expect(await FinancialStateService(db).accountBalanceNow(tarjeta), 0,
        reason: 'la tarjeta queda exactamente en cero, sin residuo');

    await db.close();
  });

  // ==========================================================================
  // Sprint flutter-loans-flexible-payments-v1 — schemaVersion 15
  // ==========================================================================

  Future<bool> tableExists(FincoreDatabase db, String table) async {
    final row = await db
        .customSelect(
          "SELECT COUNT(*) AS c FROM sqlite_master "
          "WHERE type = 'table' AND name = '$table'",
          readsFrom: const {},
        )
        .getSingle();
    return row.read<int>('c') > 0;
  }

  /// Simula una BD en v14 dropeando la tabla que introduce la v15.
  ///
  /// `seed` corre ANTES del drop: los DAOs de préstamo referencian
  /// `loan_adjustments` en su SQL de saldo, así que sin la tabla no se puede
  /// sembrar nada.
  Future<FincoreDatabase> openAtV14({
    Future<void> Function(FincoreDatabase db)? seed,
  }) async {
    final db = FincoreDatabase(NativeDatabase.memory());
    await db.accountsDao.listAll(); // fuerza onCreate
    if (seed != null) await seed(db);
    await db.customStatement('DROP INDEX IF EXISTS idx_loan_adjustments_loan');
    await db.customStatement('DROP TABLE IF EXISTS loan_adjustments');
    return db;
  }

  test(
      'MG-LF-01: la migración 14 → 15 crea loan_adjustments con los tipos '
      'correctos', () async {
    final db = await openAtV14();
    expect(await tableExists(db, 'loan_adjustments'), isFalse,
        reason: 'precondición: la tabla no existe en v14');

    await db.migration.onUpgrade(db.createMigrator(), 14, 15);

    // `amount` es INTEGER porque son centavos con signo (RN-IC-01).
    expect(await declaredType(db, 'loan_adjustments', 'amount'), 'INTEGER');
    expect(await declaredType(db, 'loan_adjustments', 'id'), 'TEXT');
    expect(await declaredType(db, 'loan_adjustments', 'loan_id'), 'TEXT');
    expect(await declaredType(db, 'loan_adjustments', 'reason'), 'TEXT');
    // `store_date_time_values_as_text: true` en build.yaml.
    expect(await declaredType(db, 'loan_adjustments', 'occurred_at'), 'TEXT');
    expect(await declaredType(db, 'loan_adjustments', 'deleted_at'), 'TEXT');
    await db.close();
  });

  test('MG-LF-02: la migración crea el índice parcial por loan_id', () async {
    final db = await openAtV14();
    await db.migration.onUpgrade(db.createMigrator(), 14, 15);

    final rows = await db
        .customSelect("SELECT name FROM sqlite_master WHERE type = 'index' "
            "AND tbl_name = 'loan_adjustments'")
        .get();
    expect(rows.map((r) => r.read<String>('name')),
        contains('idx_loan_adjustments_loan'));
    await db.close();
  });

  test(
      'MG-LF-03: la migración 14 → 15 es idempotente (CB-12)', () async {
    final db = await openAtV14();
    await db.migration.onUpgrade(db.createMigrator(), 14, 15);
    // Segunda pasada: el probe de `pragma_table_info` debe evitar el
    // "table already exists" de `m.createTable`.
    await db.migration.onUpgrade(db.createMigrator(), 14, 15);

    final tables = await db
        .customSelect("SELECT COUNT(*) AS c FROM sqlite_master "
            "WHERE type = 'table' AND name = 'loan_adjustments'")
        .getSingle();
    expect(tables.read<int>('c'), 1);
    await db.close();
  });

  test(
      'MG-LF-04: las rutas defensivas X→15 crean la tabla sin lanzar (CB-13)',
      () async {
    for (final from in [5, 8, 11, 13, 14]) {
      final db = await openAtV14();

      await db.migration.onUpgrade(db.createMigrator(), from, 15);

      expect(await declaredType(db, 'loan_adjustments', 'amount'), 'INTEGER',
          reason: 'ruta $from→15 debe dejar la tabla creada');
      // Y la cadena previa sigue aterrizando en centavos.
      expect(await declaredType(db, 'journal_entries', 'amount'), 'INTEGER',
          reason: 'ruta $from→15 debe conservar el paso a centavos de v14');
      await db.close();
    }
  });

  test(
      'MG-LF-05: un préstamo con pagos conserva exactamente su saldo tras '
      'migrar a v15 (CB-11)', () async {
    late String loanId;
    final db = await openAtV14(seed: (db) async {
      final bolsa = await db.accountsDao.createBolsa();
      loanId = await db.loansDao.create(
        name: 'BBVA',
        principalAmount: 3700000,
        monthlyPayment: 250000,
        initialDurationMonths: 24,
        paymentDay: 5,
        contractDate: DateTime.utc(2026, 5, 1),
        destinationAccountId: bolsa,
      );
      await db.entriesDao.registerLoanPayment(
        loanId: loanId,
        accountOriginId: bolsa,
        amount: 250000,
        principalAmount: 210000,
        interestAmount: 40000,
        occurredAt: DateTime.utc(2026, 6, 5),
        isMonthlyPayment: true,
      );
    });
    // Saldo que el usuario tenía en v14, con la fórmula de dos términos.
    const saldoEsperado = 3700000 - 210000;

    await db.migration.onUpgrade(db.createMigrator(), 14, 15);

    expect(await db.loansDao.balanceOf(loanId), saldoEsperado,
        reason: 'sin ajustes, la fórmula de tres términos da lo mismo');
    await db.close();
  });

  test(
      'MG-LF-06: el guardrail sigue lanzando para un destino no implementado',
      () async {
    final db = FincoreDatabase(NativeDatabase.memory());
    await db.accountsDao.listAll();
    expect(
      () => db.migration.onUpgrade(db.createMigrator(), 14, 99),
      throwsA(isA<UnimplementedError>()),
    );
    await db.close();
  });
}
