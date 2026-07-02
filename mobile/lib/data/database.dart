import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:fincore/data/daos/accounts_dao.dart';
import 'package:fincore/data/daos/app_preferences_dao.dart';
import 'package:fincore/data/daos/categories_dao.dart';
import 'package:fincore/data/daos/entries_dao.dart';
import 'package:fincore/data/daos/saved_views_dao.dart';

part 'database.g.dart';

// =============================================================================
// Tabla: accounts
// =============================================================================
// Almacena las cuentas del usuario (Bolsa singleton, débitos, créditos).
// La Bolsa se crea automáticamente al arrancar limpio (seed.dart) con
// type='cash', is_protected=true. Solo puede haber UNA cuenta con type='cash'
// activa por instalación.
class Accounts extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get type => text()(); // 'cash' | 'debit' | 'credit'
  TextColumn get description => text().nullable()();
  BoolColumn get isProtected => boolean().withDefault(const Constant(false))();
  // Metadata de tarjeta. `credit_limit` es NOT NULL con default 0 desde el
  // sprint flutter-reports-credit-cards-v1 (schemaVersion 5): una tarjeta
  // conceptualmente siempre tiene límite (aunque sea 0). El DAO valida que
  // `type='credit'` reciba explícitamente el valor. Para cuentas cash/debit
  // el campo se materializa como 0 sin efecto funcional (nunca se lee).
  // Los otros campos siguen nullable — son opcionales aún cuando la cuenta
  // es credit (permiten cargar tarjetas sin saber corte/pago/mínimo).
  RealColumn get creditLimit => real().withDefault(const Constant(0))();
  IntColumn get closingDay => integer().nullable()();
  IntColumn get paymentDay => integer().nullable()();
  RealColumn get interestRate => real().nullable()();
  RealColumn get minimumPaymentPct => real().nullable()();
  // Timestamps + soft delete.
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// =============================================================================
// Tabla: categories
// =============================================================================
// Categorías de movimientos. applies_to ∈ {income, expense, both}.
// color_slug e icon_slug deben existir en el catálogo curado
// (lib/constants/category_catalog.dart).
class Categories extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get appliesTo => text()(); // 'income' | 'expense' | 'both'
  TextColumn get colorSlug => text()();
  TextColumn get iconSlug => text()();
  // monthly_limit se acepta por compatibilidad con el formato JSON v1 del backend
  // (sprint respaldos). La UI del MVP local no lo expone, pero el schema lo
  // preserva para no perder dato al importar/exportar.
  RealColumn get monthlyLimit => real().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// =============================================================================
// Tabla: journal_entries
// =============================================================================
// Cada movimiento del libro. Los 5 kinds: income, expense, credit_expense,
// debt_payment, transfer. account_origin_id y account_destination_id pueden
// ser NULL según el kind (ver RN-011 de spec).
class JournalEntries extends Table {
  TextColumn get id => text()();
  TextColumn get kind => text()();
  TextColumn get accountOriginId =>
      text().nullable().references(Accounts, #id)();
  TextColumn get accountDestinationId =>
      text().nullable().references(Accounts, #id)();
  // amount > 0 se valida en el DAO. SQLite CHECK declarativo causa
  // recursive_getter warning; preferimos validación explícita en cada Action.
  RealColumn get amount => real()();
  TextColumn get description => text().nullable()();
  DateTimeColumn get occurredAt => dateTime()();
  TextColumn get categoryId =>
      text().nullable().references(Categories, #id)();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// =============================================================================
// Tabla: saved_views (sprint flutter-entries-saved-views-v1)
// =============================================================================
// Vistas guardadas del panel de filtros de `/entries`. Diego guarda combos de
// filtros (fecha + tipo + cuenta + categoría + monto) con nombre custom para
// reaplicarlos con un tap.
//
// Borrado físico (sin `deleted_at`): las vistas son preferencias de UI, no
// datos críticos. Si Diego elimina una vista, se va.
//
// Sin índices: esperamos <100 filas (single-user). `name` se valida case-
// insensitive en el DAO con `LOWER(name) = LOWER(?)` para impedir duplicados.
@DataClassName('SavedViewRow')
class SavedViews extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get filtersJson => text()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

// =============================================================================
// Tabla: app_preferences (sprint flutter-onboarding-for-testers-v1)
// =============================================================================
// Estado simple key/value para preferencias de UI que deben sobrevivir
// reinicios de la app pero NO forman parte de los datos del usuario.
//
// Casos de uso v1:
// - `onboarding_seen`: flag para no volver a mostrar el onboarding.
// - `last_export_at`: timestamp ISO8601 del último export exitoso.
//
// NO se incluye en el backup JSON v1 (misma decisión que `saved_views`).
// `BackupService.wipeAll()` la limpia para que un reseteo deje al usuario
// como recién instalado.
//
// Sin timestamps, sin soft delete, sin FK. Tabla intencionalmente trivial.
@DataClassName('AppPreferenceRow')
class AppPreferences extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

// =============================================================================
// FincoreDatabase
// =============================================================================
// Los 3 DAOs se registran en `daos:` desde el sprint flutter-local-hardening-v4
// (RF-004): EntriesDao quedó accesible vía codegen tras extraer
// `accountBalanceAtomic` como función pura en `financial_state.dart` (RF-001).
// Antes del v4, `EntriesDao` requería `FinancialStateService` y se instanciaba
// manualmente en `AppDependencies`; ahora `attachedDatabase.entriesDao` es la
// fuente única.
//
// schemaVersion 3 (sprint flutter-entries-saved-views-v1): tabla `saved_views`
// nueva. Migración aditiva en `onUpgrade`.
//
// schemaVersion 4 (sprint flutter-onboarding-for-testers-v1): tabla
// `app_preferences` key/value para estado de UI (onboarding visto,
// último export). Migración aditiva, no toca datos del usuario.
//
// schemaVersion 5 (sprint flutter-reports-credit-cards-v1): `credit_limit`
// deja de ser nullable y pasa a NOT NULL DEFAULT 0. La migración recrea
// la tabla `accounts` con el nuevo constraint, backfilleando NULLs a 0
// previo al recreate. Los índices no declarados en el schema Dart se
// re-crean explícitamente después de alterTable.
@DriftDatabase(
  tables: [Accounts, Categories, JournalEntries, SavedViews, AppPreferences],
  daos: [
    AccountsDao,
    CategoriesDao,
    EntriesDao,
    SavedViewsDao,
    AppPreferencesDao,
  ],
)
class FincoreDatabase extends _$FincoreDatabase {
  FincoreDatabase([QueryExecutor? executor])
      : super(executor ?? driftDatabase(name: 'fincore'));

  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          // Índices para saldos derivados rápidos (RF-004 + P-005).
          // Sin estos, las queries agregadas de FinancialStateService
          // pueden superar el budget de 10 ms con muchos entries.
          await customStatement(
            'CREATE INDEX idx_entries_origin ON journal_entries(account_origin_id)',
          );
          await customStatement(
            'CREATE INDEX idx_entries_dest ON journal_entries(account_destination_id)',
          );
          await customStatement(
            'CREATE INDEX idx_entries_deleted ON journal_entries(deleted_at)',
          );
          // Índices auxiliares para filtros típicos.
          await customStatement(
            'CREATE INDEX idx_accounts_deleted ON accounts(deleted_at)',
          );
          await customStatement(
            'CREATE INDEX idx_categories_deleted ON categories(deleted_at)',
          );
          await customStatement(
            'CREATE INDEX idx_entries_kind ON journal_entries(kind)',
          );
          // Nota futura (M7 del quality review v1 del sprint
          // flutter-reports-v1): si `ReportsService.spendingByCategory`
          // degrada con journal grande (>10k entries), considerar agregar
          // un índice compuesto parcial:
          //   CREATE INDEX idx_entries_kind_occurred_active
          //   ON journal_entries(kind, occurred_at)
          //   WHERE deleted_at IS NULL;
          // Hoy `idx_entries_kind` + filtro de rango es suficiente para el
          // tamaño del journal típico de single-user. Bumpear schemaVersion
          // y agregar rama en `onUpgrade` si se decide aplicar.
          // schemaVersion 2 (RF-011 del sprint flutter-local-hardening):
          // índice parcial para `watchPage` que ordena por occurred_at DESC y
          // filtra deleted_at IS NULL. Sin esto la lista de movimientos
          // degrada con 50k+ entries.
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_entries_occurred_active '
            'ON journal_entries(occurred_at DESC) '
            'WHERE deleted_at IS NULL',
          );
        },
        onUpgrade: (m, from, to) async {
          // Migración 1 → 2 (RF-011 + RN-H02): agrega el índice parcial nuevo
          // a instalaciones existentes sin tocar datos del usuario.
          if (from == 1 && to == 2) {
            await customStatement(
              'CREATE INDEX idx_entries_occurred_active '
              'ON journal_entries(occurred_at DESC) '
              'WHERE deleted_at IS NULL',
            );
            return;
          }
          // Migración 2 → 3 (sprint flutter-entries-saved-views-v1): crea
          // tabla nueva `saved_views`. Aditiva, no destructiva — no toca
          // datos existentes.
          if (from == 2 && to == 3) {
            await m.createTable(savedViews);
            return;
          }
          // Migración 1 → 3 (instalación que se saltó la 2): combina ambas.
          if (from == 1 && to == 3) {
            await customStatement(
              'CREATE INDEX idx_entries_occurred_active '
              'ON journal_entries(occurred_at DESC) '
              'WHERE deleted_at IS NULL',
            );
            await m.createTable(savedViews);
            return;
          }
          // Migración 3 → 4 (sprint flutter-onboarding-for-testers-v1):
          // crea tabla `app_preferences`. Aditiva, no destructiva.
          if (from == 3 && to == 4) {
            await m.createTable(appPreferences);
            return;
          }
          // Migración 2 → 4 (saltea 3): combina 2→3 + 3→4.
          if (from == 2 && to == 4) {
            await m.createTable(savedViews);
            await m.createTable(appPreferences);
            return;
          }
          // Migración 1 → 4 (saltea 2 y 3): combina las tres.
          if (from == 1 && to == 4) {
            await customStatement(
              'CREATE INDEX idx_entries_occurred_active '
              'ON journal_entries(occurred_at DESC) '
              'WHERE deleted_at IS NULL',
            );
            await m.createTable(savedViews);
            await m.createTable(appPreferences);
            return;
          }
          // Migración 4 → 5 (sprint flutter-reports-credit-cards-v1):
          // `credit_limit` pasa de nullable a NOT NULL DEFAULT 0. Requiere
          // (1) backfill de NULLs a 0 y (2) recreación de la tabla `accounts`
          // porque SQLite no soporta ALTER COLUMN.
          //
          // NOTA: onUpgrade NO corre en transacción usuario (limitación de
          // `PRAGMA foreign_keys`, que drift togglea internamente durante
          // `alterTable`). La migración es idempotente por diseño: si crashea
          // antes de que drift persista schemaVersion=5, el siguiente open
          // re-ejecuta 4→5 sin efectos secundarios (UPDATE ... WHERE IS NULL
          // es no-op tras el primer paso; alterTable reconstruye a la forma
          // vigente; CREATE INDEX IF NOT EXISTS es idempotente).
          if (from == 4 && to == 5) {
            await customStatement(
              'UPDATE accounts SET credit_limit = 0 WHERE credit_limit IS NULL',
            );
            await m.alterTable(TableMigration(accounts));
            // drift.alterTable pierde los índices no declarados en el schema
            // Dart (idx_accounts_deleted es customStatement en onCreate).
            // Re-crear explícitamente.
            await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_accounts_deleted '
              'ON accounts(deleted_at)',
            );
            return;
          }
          // Migración 3 → 5 (defensiva): combina 3→4 + 4→5.
          if (from == 3 && to == 5) {
            await m.createTable(appPreferences);
            await customStatement(
              'UPDATE accounts SET credit_limit = 0 WHERE credit_limit IS NULL',
            );
            await m.alterTable(TableMigration(accounts));
            await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_accounts_deleted '
              'ON accounts(deleted_at)',
            );
            return;
          }
          // Migración 2 → 5 (defensiva): combina 2→3 + 3→4 + 4→5.
          if (from == 2 && to == 5) {
            await m.createTable(savedViews);
            await m.createTable(appPreferences);
            await customStatement(
              'UPDATE accounts SET credit_limit = 0 WHERE credit_limit IS NULL',
            );
            await m.alterTable(TableMigration(accounts));
            await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_accounts_deleted '
              'ON accounts(deleted_at)',
            );
            return;
          }
          // Migración 1 → 5 (defensiva): combina las cuatro migraciones.
          if (from == 1 && to == 5) {
            await customStatement(
              'CREATE INDEX idx_entries_occurred_active '
              'ON journal_entries(occurred_at DESC) '
              'WHERE deleted_at IS NULL',
            );
            await m.createTable(savedViews);
            await m.createTable(appPreferences);
            await customStatement(
              'UPDATE accounts SET credit_limit = 0 WHERE credit_limit IS NULL',
            );
            await m.alterTable(TableMigration(accounts));
            await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_accounts_deleted '
              'ON accounts(deleted_at)',
            );
            return;
          }
          // Guardrail (RN-H02 + RF-009): cualquier futura migración debe
          // implementarse explícitamente como rama `if (from == X && to == Y)`
          // ANTES de este throw. Sin esto, un bump accidental de
          // `schemaVersion` corrompería datos del usuario silenciosamente.
          throw UnimplementedError(
            'Schema upgrade $from → $to no implementado en database.dart. '
            'Agregá la rama correspondiente en MigrationStrategy.onUpgrade '
            'antes de bumpear schemaVersion.',
          );
        },
        beforeOpen: (details) async {
          // SQLite trae FKs deshabilitadas por default; sin esto las references
          // declaradas arriba no se enforzan. Crítico para integridad.
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}
