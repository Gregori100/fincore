import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:fincore/data/daos/accounts_dao.dart';
import 'package:fincore/data/daos/app_preferences_dao.dart';
import 'package:fincore/data/daos/categories_dao.dart';
import 'package:fincore/data/daos/entries_dao.dart';
import 'package:fincore/data/daos/loans_dao.dart';
import 'package:fincore/data/daos/saved_views_dao.dart';
import 'package:fincore/data/daos/weekly_budgets_dao.dart';

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
  // Sprint flutter-integer-cents-v1 (schemaVersion 14): monto en centavos
  // (int) para eliminar la clase de bugs de precisión IEEE 754 (RN-IC-01).
  IntColumn get creditLimit => integer().withDefault(const Constant(0))();
  IntColumn get closingDay => integer().nullable()();
  IntColumn get paymentDay => integer().nullable()();
  // `interest_rate`, `minimum_payment_pct` y `minimum_capital_pct` son
  // ratios 0-1, NO montos: quedan como REAL (RN-IC-02, decidido en P-003).
  RealColumn get interestRate => real().nullable()();
  RealColumn get minimumPaymentPct => real().nullable()();
  // Sprint flutter-schema-v6-forward-compat-v1: columnas "dead" preservadas
  // en schema por compatibilidad. Fueron agregadas en schemaVersion 6 del
  // sprint `flutter-credit-cards-minimum-payment-formula-v1` para la
  // fórmula compuesta del pago mínimo, que después fue completamente
  // retirada del reporte y del form. Los testers (Diego) instalaron esa
  // versión y su BD quedó en v6 con estas columnas. Al no dropearlas del
  // schema evitamos el downgrade v6→v5 que trababa la app al abrir
  // (guardrail RN-H02). Ni el DAO, ni el form, ni los reports las leen;
  // el backup las preserva silenciosamente (mismo patrón que
  // `minimumPaymentPct`).
  RealColumn get minimumCapitalPct =>
      real().withDefault(const Constant(0.015))();
  // Sprint flutter-integer-cents-v1: monto en centavos. El default preserva
  // el equivalente de $150 (era `150.0` REAL, ahora `15000` centavos).
  IntColumn get minimumFloor => integer().withDefault(const Constant(15000))();
  // Timestamps + soft delete.
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  // Sprint flutter-accounts-archive-v1 (schemaVersion 9): archived_at separa
  // "archivada" (reversible, preserva histórico y reportes) de deleted_at
  // (destructivo, cascada de journal_entries). Una cuenta con
  // archived_at != null desaparece de pickers de alta pero sigue apareciendo
  // en /entries, reportes y KPIs.
  DateTimeColumn get archivedAt => dateTime().nullable()();

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
  // Sprint flutter-integer-cents-v1: monto en centavos (int).
  IntColumn get monthlyLimit => integer().nullable()();
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
  // Sprint flutter-integer-cents-v1: monto en centavos (int).
  IntColumn get amount => integer()();
  TextColumn get description => text().nullable()();
  DateTimeColumn get occurredAt => dateTime()();
  TextColumn get categoryId =>
      text().nullable().references(Categories, #id)();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  // Sprint flutter-loans-v1 (schemaVersion 10): campos para el kind
  // `loan_payment` y para trazabilidad del `income` inicial ligado a un
  // préstamo. `loan_id` no-null implica que este entry pertenece a un préstamo
  // y no es editable desde entry_form_screen (se administra desde /loans).
  // `principal_amount` + `interest_amount` sólo poblados cuando
  // `kind == 'loan_payment'` (split declarado por el usuario que suma amount).
  TextColumn get loanId =>
      text().nullable().references(Loans, #id)();
  // Sprint flutter-integer-cents-v1: montos en centavos (int).
  IntColumn get principalAmount => integer().nullable()();
  IntColumn get interestAmount => integer().nullable()();
  // Hotfix smoke Diego v2: distingue "Pago del mes" (monthly obligatorio,
  // único por mes calendario) de "Abono a capital" (extra, múltiples
  // permitidos tras el monthly). El proxy anterior `interest_amount > 0`
  // fallaba en el edge case legítimo de pago del mes sin intereses
  // (mes de gracia). Se persiste el flag explícito seteado por la UI:
  // `LoanMonthlyPaymentForm` → true, `LoanCapitalPaymentForm` → false.
  // Sólo relevante para `kind == 'loan_payment'`; en otros kinds el
  // valor es irrelevante (default false).
  BoolColumn get isMonthlyPayment =>
      boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

// =============================================================================
// Tabla: loans (sprint flutter-loans-v1)
// =============================================================================
// Préstamos personales que Diego recibe (bancarios, hipoteca, auto, amigos).
// Entidad autónoma — NO es una Account virtual. El saldo pendiente se deriva
// on-the-fly de `journal_entries` con `kind='loan_payment' AND loan_id=X`:
//   saldo = principal_amount − Σ(loan_payment.principal_amount).
//
// Cada Loan tiene un `income` inicial ligado por `loan_id` (creado
// atómicamente en `LoansDao.create`) que representa el desembolso en
// `destination_account_id`.
//
// Estados:
//   - Activo:            deleted_at IS NULL AND closed_at IS NULL
//   - Cerrado (paid):    closed_at != NULL AND close_reason='paid'    (auto)
//   - Cerrado (manual):  closed_at != NULL AND close_reason='manual'  (UI)
//   - Eliminado:         deleted_at != NULL  (cascada income + pagos)
//
// Los `paid` no se reabren por acción manual (sólo por eliminar un pago con
// capital > 0 que devuelve saldo>0). Los `manual` sí se reabren via reopen.
//
// `principal_amount` y `destination_account_id` son INMUTABLES post-create
// (RN-L01, RN-L02) porque están atados al `income` inicial. `monthly_payment`,
// `current_duration_months`, `payment_day`, `contract_date`, `name` sí son
// editables.
class Loans extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  // Sprint flutter-integer-cents-v1: montos en centavos (int).
  IntColumn get principalAmount => integer()();
  IntColumn get monthlyPayment => integer()();
  IntColumn get initialDurationMonths => integer()();
  IntColumn get currentDurationMonths => integer()();
  IntColumn get paymentDay => integer()(); // 1-28
  DateTimeColumn get contractDate => dateTime()();
  TextColumn get destinationAccountId =>
      text().references(Accounts, #id)();
  DateTimeColumn get closedAt => dateTime().nullable()();
  TextColumn get closeReason => text().nullable()(); // 'paid' | 'manual'
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
// Tablas: weekly_budgets + weekly_budget_items (sprint flutter-weekly-budgets-v1)
// =============================================================================
// Planeador semanal anticipado. Independiente del ledger — ni EntriesDao ni
// FinancialStateService leen estas tablas. Hard delete (sin `deleted_at`):
// borrar un presupuesto lo elimina físicamente + cascade a sus items.
//
// La cascade se gestiona en aplicación dentro de WeeklyBudgetsDao.deleteBudget
// (transacción `delete items` + `delete budget`) para portabilidad y para no
// depender del comportamiento de drift/SQLite con onDelete. Ver RN-B05.
//
// `week_start_date` guarda medianoche local del día de arranque (normalizado
// en el DAO). El rango cubierto es [week_start_date, week_start_date + 7 días).
// Immutable post-create (RN-B09) para preservar el rango de los renglones ya
// agregados.
//
// Multi-plan por semana permitido: sin UNIQUE por week_start_date; se
// diferencian por `label`.
//
// **Refactor 2026-07-14**: la columna `is_template` unifica el concepto de
// "plantilla" con el de "presupuesto". Un budget marcado como plantilla
// aparece en el listado normal con un badge y, además, se ofrece como
// origen al crear un presupuesto nuevo desde el flujo "Desde plantilla".
// Al crear desde plantilla se copia snapshot de los items (nuevos ids) —
// editar el origen no afecta a los derivados y viceversa. Este refactor
// eliminó las tablas `budget_templates` y `budget_template_items` (que
// duplicaban el shape) y su DAO.
//
// NO se incluyen en el backup JSON v1. `BackupService.wipeAll()` sí las
// borra para dejar la BD como recién instalada.
@DataClassName('WeeklyBudgetRow')
class WeeklyBudgets extends Table {
  TextColumn get id => text()();
  DateTimeColumn get weekStartDate => dateTime()();
  TextColumn get label => text()();
  BoolColumn get isTemplate => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

// Renglones de un presupuesto semanal. `amount > 0` y `name` no vacío se
// validan en el DAO. `category_id` opcional — si la categoría se archiva
// después, el badge desaparece en el render pero el renglón no se rompe.
// `kind ∈ {income, expense}`. `sort_order` para reorder manual (drag & drop
// con handle).
//
// Sprint flutter-budgets-item-completion-v1: `is_done` marca manual del
// usuario para "ya pasó / ya cumplí este renglón". Sin vínculo automático
// a entries del journal — es una check-list operativa. Se resetea a false
// al duplicar un presupuesto (los items del clon no heredan el estado).
@DataClassName('WeeklyBudgetItemRow')
class WeeklyBudgetItems extends Table {
  TextColumn get id => text()();
  TextColumn get budgetId => text().references(WeeklyBudgets, #id)();
  TextColumn get name => text()();
  TextColumn get categoryId =>
      text().nullable().references(Categories, #id)();
  // Sprint flutter-integer-cents-v1: monto en centavos (int).
  IntColumn get amount => integer()();
  TextColumn get kind => text()(); // 'income' | 'expense'
  IntColumn get sortOrder => integer()();
  BoolColumn get isDone => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

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
  tables: [
    Accounts,
    Categories,
    JournalEntries,
    Loans,
    SavedViews,
    AppPreferences,
    WeeklyBudgets,
    WeeklyBudgetItems,
  ],
  daos: [
    AccountsDao,
    CategoriesDao,
    EntriesDao,
    LoansDao,
    SavedViewsDao,
    AppPreferencesDao,
    WeeklyBudgetsDao,
  ],
)
class FincoreDatabase extends _$FincoreDatabase {
  FincoreDatabase([QueryExecutor? executor])
      : super(executor ?? driftDatabase(name: 'fincore'));

  @override
  int get schemaVersion => 14;

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
          // Sprint flutter-weekly-budgets-v1: índices para el planeador
          // semanal. `idx_weekly_budgets_start` para agrupar por rango
          // en el listado; `idx_wb_items_budget_sort` para leer items
          // ordenados por sort_order dentro de un budget sin sort
          // adicional. `idx_weekly_budgets_template` acelera el filtro
          // del selector "Desde plantilla" (is_template = 1).
          await customStatement(
            'CREATE INDEX idx_weekly_budgets_start '
            'ON weekly_budgets(week_start_date)',
          );
          await customStatement(
            'CREATE INDEX idx_wb_items_budget_sort '
            'ON weekly_budget_items(budget_id, sort_order)',
          );
          await customStatement(
            'CREATE INDEX idx_weekly_budgets_template '
            'ON weekly_budgets(is_template) WHERE is_template = 1',
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
          // Sprint flutter-loans-v1: índice parcial para agregación rápida
          // del saldo de préstamos y de la cascada de deleteLoan.
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_entries_loan '
            'ON journal_entries(loan_id) WHERE loan_id IS NOT NULL',
          );
          // Hotfix quality-review B20 (schemaVersion 12): índices parciales
          // en la tabla `loans` para consistencia con el resto del schema
          // (todas las FKs y todos los deleted_at ya estaban indexados).
          // Impacto real bajo en single-user (<100 préstamos) pero cierra
          // deuda de patrón.
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_loans_deleted '
            'ON loans(deleted_at)',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_loans_dest_account '
            'ON loans(destination_account_id) WHERE deleted_at IS NULL',
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
          // Migración 5 → 6 (sprint flutter-schema-v6-forward-compat-v1):
          // agrega las columnas `minimum_capital_pct` y `minimum_floor` que
          // vivían en un sprint retirado. Se re-introducen en el schema
          // solo por forward-compat: usuarios que instalaron ese sprint
          // tienen BD v6 y sin esta rama al abrir la app con schemaVersion
          // 5 disparaban `UnimplementedError` (guardrail RN-H02). Las
          // columnas quedan "dead" — ni el DAO, ni el form, ni los
          // reports las leen. Aditiva, sin pérdida de datos.
          //
          // Nota SQLite: `ALTER TABLE ADD COLUMN` con `NOT NULL DEFAULT`
          // aplica el default a las filas existentes.
          if (from == 5 && to == 6) {
            await customStatement(
              'ALTER TABLE accounts ADD COLUMN minimum_capital_pct REAL NOT NULL DEFAULT 0.015',
            );
            await customStatement(
              'ALTER TABLE accounts ADD COLUMN minimum_floor REAL NOT NULL DEFAULT 150',
            );
            return;
          }
          // Migración 6 → 7 (sprint flutter-weekly-budgets-v1): crea las 4
          // tablas del planeador semanal + sus índices. Aditiva, no
          // destructiva, no toca datos del usuario.
          //
          // Fix A1 (branch-quality-review flutter-weekly-budgets-v1):
          // `m.createTable(...)` no acepta `IF NOT EXISTS`. Si la app crashea
          // a mitad de esta migración (batería, kill de OS), el siguiente
          // `open()` re-ejecuta `onUpgrade(6,7)` desde cero y explotaba con
          // "table already exists". DDL manual con `CREATE TABLE/INDEX IF NOT
          // EXISTS` (mismo patrón que 4→5 con `idx_accounts_deleted`) para
          // que la migración sea idempotente ante reintentos. El DDL replica
          // exactamente lo que generaba `m.createTable` (columnas + FKs +
          // PK), verificado contra el schema real emitido por drift.
          if (from == 6 && to == 7) {
            // Refactor 2026-07-14: tablas `budget_templates` y
            // `budget_template_items` eliminadas del schema; el rol de
            // plantilla ahora vive como `is_template` en weekly_budgets.
            await customStatement(
              'CREATE TABLE IF NOT EXISTS weekly_budgets ('
              'id TEXT NOT NULL, '
              'week_start_date TEXT NOT NULL, '
              'label TEXT NOT NULL, '
              'is_template INTEGER NOT NULL DEFAULT 0 CHECK (is_template IN (0, 1)), '
              'created_at TEXT NOT NULL, '
              'updated_at TEXT NOT NULL, '
              'PRIMARY KEY (id))',
            );
            await customStatement(
              'CREATE TABLE IF NOT EXISTS weekly_budget_items ('
              'id TEXT NOT NULL, '
              'budget_id TEXT NOT NULL REFERENCES weekly_budgets (id), '
              'name TEXT NOT NULL, '
              'category_id TEXT NULL REFERENCES categories (id), '
              'amount REAL NOT NULL, '
              'kind TEXT NOT NULL, '
              'sort_order INTEGER NOT NULL, '
              'created_at TEXT NOT NULL, '
              'updated_at TEXT NOT NULL, '
              'PRIMARY KEY (id))',
            );
            await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_weekly_budgets_start '
              'ON weekly_budgets(week_start_date)',
            );
            await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_wb_items_budget_sort '
              'ON weekly_budget_items(budget_id, sort_order)',
            );
            await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_weekly_budgets_template '
              'ON weekly_budgets(is_template) WHERE is_template = 1',
            );
            return;
          }
          // Migración 7 → 8 (hotfix del refactor de plantillas 2026-07-14):
          // instalaciones que corrieron el sprint pre-refactor tienen
          // `weekly_budgets` sin la columna `is_template` + las tablas
          // `budget_templates` y `budget_template_items` con datos huérfanos.
          // Alinea el schema in-place para no forzar reinstall:
          //   1) agrega columna `is_template` NOT NULL DEFAULT 0.
          //   2) dropea las 2 tablas obsoletas (pierden las plantillas viejas
          //      — Diego marca las nuevas desde el detalle del presupuesto).
          //   3) crea el índice parcial nuevo del selector de plantillas.
          //   4) borra el índice viejo si existía.
          // Los presupuestos y sus renglones se preservan intactos.
          if (from == 7 && to == 8) {
            await customStatement(
              'ALTER TABLE weekly_budgets ADD COLUMN is_template '
              'INTEGER NOT NULL DEFAULT 0 '
              'CHECK (is_template IN (0, 1))',
            );
            await customStatement(
              'DROP TABLE IF EXISTS budget_template_items',
            );
            await customStatement('DROP TABLE IF EXISTS budget_templates');
            await customStatement(
              'DROP INDEX IF EXISTS idx_bt_items_template_sort',
            );
            await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_weekly_budgets_template '
              'ON weekly_budgets(is_template) WHERE is_template = 1',
            );
            return;
          }
          // Migración 6 → 8 (defensiva): instalación que se saltó la 7 —
          // vino directamente de v6. Aplica la migración 6→7 (versión ya
          // refactoreada del schema, sin las 2 tablas de templates) y no
          // necesita nada de la rama 7→8 porque el schema queda igual.
          if (from == 6 && to == 8) {
            await customStatement(
              'CREATE TABLE IF NOT EXISTS weekly_budgets ('
              'id TEXT NOT NULL, '
              'week_start_date TEXT NOT NULL, '
              'label TEXT NOT NULL, '
              'is_template INTEGER NOT NULL DEFAULT 0 CHECK (is_template IN (0, 1)), '
              'created_at TEXT NOT NULL, '
              'updated_at TEXT NOT NULL, '
              'PRIMARY KEY (id))',
            );
            await customStatement(
              'CREATE TABLE IF NOT EXISTS weekly_budget_items ('
              'id TEXT NOT NULL, '
              'budget_id TEXT NOT NULL REFERENCES weekly_budgets (id), '
              'name TEXT NOT NULL, '
              'category_id TEXT NULL REFERENCES categories (id), '
              'amount REAL NOT NULL, '
              'kind TEXT NOT NULL, '
              'sort_order INTEGER NOT NULL, '
              'created_at TEXT NOT NULL, '
              'updated_at TEXT NOT NULL, '
              'PRIMARY KEY (id))',
            );
            await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_weekly_budgets_start '
              'ON weekly_budgets(week_start_date)',
            );
            await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_wb_items_budget_sort '
              'ON weekly_budget_items(budget_id, sort_order)',
            );
            await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_weekly_budgets_template '
              'ON weekly_budgets(is_template) WHERE is_template = 1',
            );
            return;
          }
          // Migración 8 → 9 (sprint flutter-accounts-archive-v1): agrega
          // columna `archived_at` a `accounts` para separar archivado
          // reversible del soft-delete cascada. Aditiva, no destructiva.
          if (from == 8 && to == 9) {
            await customStatement(
              'ALTER TABLE accounts ADD COLUMN archived_at TEXT',
            );
            return;
          }
          // Migración 7 → 9 (defensiva): combina 7→8 + 8→9.
          if (from == 7 && to == 9) {
            await customStatement(
              'ALTER TABLE weekly_budgets ADD COLUMN is_template '
              'INTEGER NOT NULL DEFAULT 0 '
              'CHECK (is_template IN (0, 1))',
            );
            await customStatement(
              'DROP TABLE IF EXISTS budget_template_items',
            );
            await customStatement('DROP TABLE IF EXISTS budget_templates');
            await customStatement(
              'DROP INDEX IF EXISTS idx_bt_items_template_sort',
            );
            await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_weekly_budgets_template '
              'ON weekly_budgets(is_template) WHERE is_template = 1',
            );
            await customStatement(
              'ALTER TABLE accounts ADD COLUMN archived_at TEXT',
            );
            return;
          }
          // Migración 6 → 9 (defensiva): combina 6→8 + 8→9.
          if (from == 6 && to == 9) {
            await customStatement(
              'CREATE TABLE IF NOT EXISTS weekly_budgets ('
              'id TEXT NOT NULL, '
              'week_start_date TEXT NOT NULL, '
              'label TEXT NOT NULL, '
              'is_template INTEGER NOT NULL DEFAULT 0 CHECK (is_template IN (0, 1)), '
              'created_at TEXT NOT NULL, '
              'updated_at TEXT NOT NULL, '
              'PRIMARY KEY (id))',
            );
            await customStatement(
              'CREATE TABLE IF NOT EXISTS weekly_budget_items ('
              'id TEXT NOT NULL, '
              'budget_id TEXT NOT NULL REFERENCES weekly_budgets (id), '
              'name TEXT NOT NULL, '
              'category_id TEXT NULL REFERENCES categories (id), '
              'amount REAL NOT NULL, '
              'kind TEXT NOT NULL, '
              'sort_order INTEGER NOT NULL, '
              'created_at TEXT NOT NULL, '
              'updated_at TEXT NOT NULL, '
              'PRIMARY KEY (id))',
            );
            await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_weekly_budgets_start '
              'ON weekly_budgets(week_start_date)',
            );
            await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_wb_items_budget_sort '
              'ON weekly_budget_items(budget_id, sort_order)',
            );
            await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_weekly_budgets_template '
              'ON weekly_budgets(is_template) WHERE is_template = 1',
            );
            await customStatement(
              'ALTER TABLE accounts ADD COLUMN archived_at TEXT',
            );
            return;
          }
          // Migración 9 → 10 (sprint flutter-loans-v1): crea tabla `loans` +
          // agrega 4 columnas nullable a `journal_entries` para el kind nuevo
          // `loan_payment` (loan_id FK + principal_amount + interest_amount +
          // is_monthly_payment) + índice parcial para acelerar `balanceOf`.
          // Aditiva, no destructiva, no toca datos del usuario.
          if (from == 9 && to == 10) {
            await customStatement(
              'CREATE TABLE IF NOT EXISTS loans ('
              'id TEXT NOT NULL, '
              'name TEXT NOT NULL, '
              'principal_amount REAL NOT NULL, '
              'monthly_payment REAL NOT NULL, '
              'initial_duration_months INTEGER NOT NULL, '
              'current_duration_months INTEGER NOT NULL, '
              'payment_day INTEGER NOT NULL, '
              'contract_date TEXT NOT NULL, '
              'destination_account_id TEXT NOT NULL REFERENCES accounts (id), '
              'closed_at TEXT NULL, '
              'close_reason TEXT NULL, '
              'created_at TEXT NOT NULL, '
              'updated_at TEXT NOT NULL, '
              'deleted_at TEXT NULL, '
              'PRIMARY KEY (id))',
            );
            await customStatement(
              'ALTER TABLE journal_entries ADD COLUMN loan_id TEXT '
              'REFERENCES loans (id)',
            );
            await customStatement(
              'ALTER TABLE journal_entries ADD COLUMN principal_amount REAL',
            );
            await customStatement(
              'ALTER TABLE journal_entries ADD COLUMN interest_amount REAL',
            );
            await customStatement(
              'ALTER TABLE journal_entries ADD COLUMN is_monthly_payment '
              'INTEGER NOT NULL DEFAULT 0 '
              'CHECK (is_monthly_payment IN (0, 1))',
            );
            await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_entries_loan '
              'ON journal_entries(loan_id) WHERE loan_id IS NOT NULL',
            );
            return;
          }
          // Migración 8 → 10 (defensiva): combina 8→9 (archived_at) + 9→10.
          if (from == 8 && to == 10) {
            await customStatement(
              'ALTER TABLE accounts ADD COLUMN archived_at TEXT',
            );
            await customStatement(
              'CREATE TABLE IF NOT EXISTS loans ('
              'id TEXT NOT NULL, '
              'name TEXT NOT NULL, '
              'principal_amount REAL NOT NULL, '
              'monthly_payment REAL NOT NULL, '
              'initial_duration_months INTEGER NOT NULL, '
              'current_duration_months INTEGER NOT NULL, '
              'payment_day INTEGER NOT NULL, '
              'contract_date TEXT NOT NULL, '
              'destination_account_id TEXT NOT NULL REFERENCES accounts (id), '
              'closed_at TEXT NULL, '
              'close_reason TEXT NULL, '
              'created_at TEXT NOT NULL, '
              'updated_at TEXT NOT NULL, '
              'deleted_at TEXT NULL, '
              'PRIMARY KEY (id))',
            );
            await customStatement(
              'ALTER TABLE journal_entries ADD COLUMN loan_id TEXT '
              'REFERENCES loans (id)',
            );
            await customStatement(
              'ALTER TABLE journal_entries ADD COLUMN principal_amount REAL',
            );
            await customStatement(
              'ALTER TABLE journal_entries ADD COLUMN interest_amount REAL',
            );
            await customStatement(
              'ALTER TABLE journal_entries ADD COLUMN is_monthly_payment '
              'INTEGER NOT NULL DEFAULT 0 '
              'CHECK (is_monthly_payment IN (0, 1))',
            );
            await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_entries_loan '
              'ON journal_entries(loan_id) WHERE loan_id IS NOT NULL',
            );
            return;
          }
          // Migración 10 → 11 (hotfix smoke Diego v2): agrega
          // `is_monthly_payment` a `journal_entries` para distinguir
          // "Pago del mes" de "Abono a capital" sin depender del proxy
          // `interest_amount > 0`. Idempotente vía probe de pragma_table_info
          // porque algunas instalaciones tempranas del sprint corrieron una
          // versión iterativa de la rama 9→10 que ya incluía la columna
          // (bump inline sin cambio de schemaVersion), y otras no.
          if (from == 10 && to == 11) {
            final probe = await customSelect(
              "SELECT COUNT(*) AS c FROM pragma_table_info('journal_entries') "
              "WHERE name = 'is_monthly_payment'",
            ).getSingle();
            if (probe.read<int>('c') == 0) {
              await customStatement(
                'ALTER TABLE journal_entries ADD COLUMN is_monthly_payment '
                'INTEGER NOT NULL DEFAULT 0 '
                'CHECK (is_monthly_payment IN (0, 1))',
              );
            }
            return;
          }
          // Migración 9 → 11 (defensiva): combina 9→10 (loans + 4 columnas
          // en journal_entries + índice) + 10→11 no-op (la columna ya la
          // pusimos en la rama 9→10 aquí).
          if (from == 9 && to == 11) {
            await customStatement(
              'CREATE TABLE IF NOT EXISTS loans ('
              'id TEXT NOT NULL, '
              'name TEXT NOT NULL, '
              'principal_amount REAL NOT NULL, '
              'monthly_payment REAL NOT NULL, '
              'initial_duration_months INTEGER NOT NULL, '
              'current_duration_months INTEGER NOT NULL, '
              'payment_day INTEGER NOT NULL, '
              'contract_date TEXT NOT NULL, '
              'destination_account_id TEXT NOT NULL REFERENCES accounts (id), '
              'closed_at TEXT NULL, '
              'close_reason TEXT NULL, '
              'created_at TEXT NOT NULL, '
              'updated_at TEXT NOT NULL, '
              'deleted_at TEXT NULL, '
              'PRIMARY KEY (id))',
            );
            await customStatement(
              'ALTER TABLE journal_entries ADD COLUMN loan_id TEXT '
              'REFERENCES loans (id)',
            );
            await customStatement(
              'ALTER TABLE journal_entries ADD COLUMN principal_amount REAL',
            );
            await customStatement(
              'ALTER TABLE journal_entries ADD COLUMN interest_amount REAL',
            );
            await customStatement(
              'ALTER TABLE journal_entries ADD COLUMN is_monthly_payment '
              'INTEGER NOT NULL DEFAULT 0 '
              'CHECK (is_monthly_payment IN (0, 1))',
            );
            await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_entries_loan '
              'ON journal_entries(loan_id) WHERE loan_id IS NOT NULL',
            );
            return;
          }
          // Hotfix quality-review M4: ramas defensivas 5→11, 6→11, 7→11.
          // Antes crasheaban con `UnimplementedError` (guardrail RN-H02).
          // Componen las transiciones intermedias con customStatement en
          // lugar de recursión para preservar la política aditiva.
          if (from == 5 && to == 11) {
            // 5→6: minimum_capital_pct + minimum_floor (idempotente).
            await _maybeAddColumn('accounts', 'minimum_capital_pct',
                'REAL NOT NULL DEFAULT 0.015');
            await _maybeAddColumn(
                'accounts', 'minimum_floor', 'REAL NOT NULL DEFAULT 150');
            // 6→9 (skip 7→8 porque nunca hubo templates en v5).
            await _createWeeklyBudgetTablesRefactored();
            await _maybeAddColumn('accounts', 'archived_at', 'TEXT');
            // 9→11: loans schema (ya idempotente).
            await _createLoansSchema();
            return;
          }
          if (from == 6 && to == 11) {
            await _createWeeklyBudgetTablesRefactored();
            await _maybeAddColumn('accounts', 'archived_at', 'TEXT');
            await _createLoansSchema();
            return;
          }
          if (from == 7 && to == 11) {
            // 7→8: is_template + drop templates + índice (idempotente).
            await _maybeAddColumn('weekly_budgets', 'is_template',
                'INTEGER NOT NULL DEFAULT 0 CHECK (is_template IN (0, 1))');
            await customStatement(
              'DROP TABLE IF EXISTS budget_template_items',
            );
            await customStatement('DROP TABLE IF EXISTS budget_templates');
            await customStatement(
              'DROP INDEX IF EXISTS idx_bt_items_template_sort',
            );
            await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_weekly_budgets_template '
              'ON weekly_budgets(is_template) WHERE is_template = 1',
            );
            await _maybeAddColumn('accounts', 'archived_at', 'TEXT');
            await _createLoansSchema();
            return;
          }
          // Migración 12 → 13 (sprint flutter-budgets-item-completion-v1):
          // agrega columna `is_done` a `weekly_budget_items` para marcar
          // renglones "ya pasó / ya cumplí" desde la lista del presupuesto.
          // Aditiva, DEFAULT 0 backfillea existentes a "no hecho". Idempotente
          // vía probe de pragma_table_info.
          if (from == 12 && to == 13) {
            await _addIsDoneColumn();
            return;
          }
          // Ramas defensivas X→13: cadena de todo lo que aterriza en v12 +
          // `_addIsDoneColumn`. Mismo patrón que las X→12 (M4 del quality
          // review v1 de flutter-loans-v1). Todos los helpers son idempotentes
          // por probe / IF NOT EXISTS.
          if (from == 11 && to == 13) {
            await _createLoansIndexes();
            await _addIsDoneColumn();
            return;
          }
          if (from == 10 && to == 13) {
            await _maybeAddColumn(
                'journal_entries',
                'is_monthly_payment',
                'INTEGER NOT NULL DEFAULT 0 CHECK (is_monthly_payment IN (0, 1))');
            await _createLoansIndexes();
            await _addIsDoneColumn();
            return;
          }
          if (from == 9 && to == 13) {
            await _createLoansSchema();
            await _createLoansIndexes();
            await _addIsDoneColumn();
            return;
          }
          if (from == 8 && to == 13) {
            await _maybeAddColumn('accounts', 'archived_at', 'TEXT');
            await _createLoansSchema();
            await _createLoansIndexes();
            await _addIsDoneColumn();
            return;
          }
          if (from == 7 && to == 13) {
            await _maybeAddColumn('weekly_budgets', 'is_template',
                'INTEGER NOT NULL DEFAULT 0 CHECK (is_template IN (0, 1))');
            await customStatement(
                'DROP TABLE IF EXISTS budget_template_items');
            await customStatement('DROP TABLE IF EXISTS budget_templates');
            await customStatement(
                'DROP INDEX IF EXISTS idx_bt_items_template_sort');
            await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_weekly_budgets_template '
              'ON weekly_budgets(is_template) WHERE is_template = 1',
            );
            await _maybeAddColumn('accounts', 'archived_at', 'TEXT');
            await _createLoansSchema();
            await _createLoansIndexes();
            await _addIsDoneColumn();
            return;
          }
          if (from == 6 && to == 13) {
            await _createWeeklyBudgetTablesRefactored();
            await _maybeAddColumn('accounts', 'archived_at', 'TEXT');
            await _createLoansSchema();
            await _createLoansIndexes();
            await _addIsDoneColumn();
            return;
          }
          if (from == 5 && to == 13) {
            await _maybeAddColumn('accounts', 'minimum_capital_pct',
                'REAL NOT NULL DEFAULT 0.015');
            await _maybeAddColumn(
                'accounts', 'minimum_floor', 'REAL NOT NULL DEFAULT 150');
            await _createWeeklyBudgetTablesRefactored();
            await _maybeAddColumn('accounts', 'archived_at', 'TEXT');
            await _createLoansSchema();
            await _createLoansIndexes();
            await _addIsDoneColumn();
            return;
          }
          // Hotfix quality-review B20: migración 11→12 agrega índices en la
          // tabla `loans` (deleted_at, destination_account_id). Aditiva.
          if (from == 11 && to == 12) {
            await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_loans_deleted '
              'ON loans(deleted_at)',
            );
            await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_loans_dest_account '
              'ON loans(destination_account_id) WHERE deleted_at IS NULL',
            );
            return;
          }
          // Ramas defensivas 8→12, 9→12, 10→12: componer las de 8/9/10→11 +
          // los índices nuevos de 11→12.
          if (from == 10 && to == 12) {
            await _maybeAddColumn(
                'journal_entries',
                'is_monthly_payment',
                'INTEGER NOT NULL DEFAULT 0 CHECK (is_monthly_payment IN (0, 1))');
            await _createLoansIndexes();
            return;
          }
          if (from == 9 && to == 12) {
            await _createLoansSchema();
            await _createLoansIndexes();
            return;
          }
          if (from == 8 && to == 12) {
            await _maybeAddColumn('accounts', 'archived_at', 'TEXT');
            await _createLoansSchema();
            await _createLoansIndexes();
            return;
          }
          if (from == 7 && to == 12) {
            await _maybeAddColumn('weekly_budgets', 'is_template',
                'INTEGER NOT NULL DEFAULT 0 CHECK (is_template IN (0, 1))');
            await customStatement(
                'DROP TABLE IF EXISTS budget_template_items');
            await customStatement('DROP TABLE IF EXISTS budget_templates');
            await customStatement(
                'DROP INDEX IF EXISTS idx_bt_items_template_sort');
            await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_weekly_budgets_template '
              'ON weekly_budgets(is_template) WHERE is_template = 1',
            );
            await _maybeAddColumn('accounts', 'archived_at', 'TEXT');
            await _createLoansSchema();
            await _createLoansIndexes();
            return;
          }
          if (from == 6 && to == 12) {
            await _createWeeklyBudgetTablesRefactored();
            await _maybeAddColumn('accounts', 'archived_at', 'TEXT');
            await _createLoansSchema();
            await _createLoansIndexes();
            return;
          }
          if (from == 5 && to == 12) {
            await _maybeAddColumn('accounts', 'minimum_capital_pct',
                'REAL NOT NULL DEFAULT 0.015');
            await _maybeAddColumn(
                'accounts', 'minimum_floor', 'REAL NOT NULL DEFAULT 150');
            await _createWeeklyBudgetTablesRefactored();
            await _maybeAddColumn('accounts', 'archived_at', 'TEXT');
            await _createLoansSchema();
            await _createLoansIndexes();
            return;
          }
          // Migración 8 → 11 (defensiva): combina 8→9 (archived_at) +
          // 9→11.
          if (from == 8 && to == 11) {
            await customStatement(
              'ALTER TABLE accounts ADD COLUMN archived_at TEXT',
            );
            await customStatement(
              'CREATE TABLE IF NOT EXISTS loans ('
              'id TEXT NOT NULL, '
              'name TEXT NOT NULL, '
              'principal_amount REAL NOT NULL, '
              'monthly_payment REAL NOT NULL, '
              'initial_duration_months INTEGER NOT NULL, '
              'current_duration_months INTEGER NOT NULL, '
              'payment_day INTEGER NOT NULL, '
              'contract_date TEXT NOT NULL, '
              'destination_account_id TEXT NOT NULL REFERENCES accounts (id), '
              'closed_at TEXT NULL, '
              'close_reason TEXT NULL, '
              'created_at TEXT NOT NULL, '
              'updated_at TEXT NOT NULL, '
              'deleted_at TEXT NULL, '
              'PRIMARY KEY (id))',
            );
            await customStatement(
              'ALTER TABLE journal_entries ADD COLUMN loan_id TEXT '
              'REFERENCES loans (id)',
            );
            await customStatement(
              'ALTER TABLE journal_entries ADD COLUMN principal_amount REAL',
            );
            await customStatement(
              'ALTER TABLE journal_entries ADD COLUMN interest_amount REAL',
            );
            await customStatement(
              'ALTER TABLE journal_entries ADD COLUMN is_monthly_payment '
              'INTEGER NOT NULL DEFAULT 0 '
              'CHECK (is_monthly_payment IN (0, 1))',
            );
            await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_entries_loan '
              'ON journal_entries(loan_id) WHERE loan_id IS NOT NULL',
            );
            return;
          }
          // Migración 13 → 14 (sprint flutter-integer-cents-v1): convierte
          // todas las columnas monetarias de REAL (double IEEE 754) a
          // INTEGER (centavos). Elimina de raíz la clase de bugs de
          // precisión que hoy se mitigaba con tolerancias `+ 0.005`.
          //
          // Los ratios 0-1 (`interest_rate`, `minimum_payment_pct`,
          // `minimum_capital_pct`) NO se tocan: siguen como REAL (RN-IC-02).
          if (from == 13 && to == 14) {
            await _convertMoneyColumnsToInteger(m);
            return;
          }
          // Ramas defensivas X → 14: componen la cadena de migraciones
          // intermedias y cierran con la conversión a centavos. Mismo patrón
          // que las X→13 y X→12. Todos los helpers son idempotentes.
          if (from == 12 && to == 14) {
            await _addIsDoneColumn();
            await _convertMoneyColumnsToInteger(m);
            return;
          }
          if (from == 11 && to == 14) {
            await _createLoansIndexes();
            await _addIsDoneColumn();
            await _convertMoneyColumnsToInteger(m);
            return;
          }
          if (from == 10 && to == 14) {
            await _maybeAddColumn(
                'journal_entries',
                'is_monthly_payment',
                'INTEGER NOT NULL DEFAULT 0 CHECK (is_monthly_payment IN (0, 1))');
            await _createLoansIndexes();
            await _addIsDoneColumn();
            await _convertMoneyColumnsToInteger(m);
            return;
          }
          if (from == 9 && to == 14) {
            await _createLoansSchema();
            await _createLoansIndexes();
            await _addIsDoneColumn();
            await _convertMoneyColumnsToInteger(m);
            return;
          }
          if (from == 8 && to == 14) {
            await _maybeAddColumn('accounts', 'archived_at', 'TEXT');
            await _createLoansSchema();
            await _createLoansIndexes();
            await _addIsDoneColumn();
            await _convertMoneyColumnsToInteger(m);
            return;
          }
          if (from == 7 && to == 14) {
            await _maybeAddColumn('weekly_budgets', 'is_template',
                'INTEGER NOT NULL DEFAULT 0 CHECK (is_template IN (0, 1))');
            await customStatement(
                'DROP TABLE IF EXISTS budget_template_items');
            await customStatement('DROP TABLE IF EXISTS budget_templates');
            await customStatement(
                'DROP INDEX IF EXISTS idx_bt_items_template_sort');
            await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_weekly_budgets_template '
              'ON weekly_budgets(is_template) WHERE is_template = 1',
            );
            await _maybeAddColumn('accounts', 'archived_at', 'TEXT');
            await _createLoansSchema();
            await _createLoansIndexes();
            await _addIsDoneColumn();
            await _convertMoneyColumnsToInteger(m);
            return;
          }
          if (from == 6 && to == 14) {
            await _createWeeklyBudgetTablesRefactored();
            await _maybeAddColumn('accounts', 'archived_at', 'TEXT');
            await _createLoansSchema();
            await _createLoansIndexes();
            await _addIsDoneColumn();
            await _convertMoneyColumnsToInteger(m);
            return;
          }
          if (from == 5 && to == 14) {
            await _maybeAddColumn('accounts', 'minimum_capital_pct',
                'REAL NOT NULL DEFAULT 0.015');
            await _maybeAddColumn(
                'accounts', 'minimum_floor', 'REAL NOT NULL DEFAULT 150');
            await _createWeeklyBudgetTablesRefactored();
            await _maybeAddColumn('accounts', 'archived_at', 'TEXT');
            await _createLoansSchema();
            await _createLoansIndexes();
            await _addIsDoneColumn();
            await _convertMoneyColumnsToInteger(m);
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

  /// Hotfix quality-review M4: `ALTER TABLE ADD COLUMN` no acepta `IF NOT
  /// EXISTS` en SQLite. Probamos primero contra `pragma_table_info` para
  /// que las migraciones defensivas sean idempotentes bajo reintento
  /// parcial y contra BDs de test recreadas.
  Future<void> _maybeAddColumn(
    String table,
    String column,
    String spec,
  ) async {
    final probe = await customSelect(
      "SELECT COUNT(*) AS c FROM pragma_table_info('$table') WHERE name = ?",
      variables: [Variable.withString(column)],
    ).getSingle();
    if (probe.read<int>('c') == 0) {
      await customStatement('ALTER TABLE $table ADD COLUMN $column $spec');
    }
  }

  /// Hotfix quality-review M4: helper compartido para las migraciones
  /// defensivas que aterrizan en v11 desde versiones anteriores a 8. Crea
  /// las tablas `weekly_budgets`/`weekly_budget_items` post-refactor
  /// (sin `budget_templates`) y sus índices. Idempotente vía IF NOT EXISTS.
  Future<void> _createWeeklyBudgetTablesRefactored() async {
    await customStatement(
      'CREATE TABLE IF NOT EXISTS weekly_budgets ('
      'id TEXT NOT NULL, '
      'week_start_date TEXT NOT NULL, '
      'label TEXT NOT NULL, '
      'is_template INTEGER NOT NULL DEFAULT 0 CHECK (is_template IN (0, 1)), '
      'created_at TEXT NOT NULL, '
      'updated_at TEXT NOT NULL, '
      'PRIMARY KEY (id))',
    );
    await customStatement(
      'CREATE TABLE IF NOT EXISTS weekly_budget_items ('
      'id TEXT NOT NULL, '
      'budget_id TEXT NOT NULL REFERENCES weekly_budgets (id), '
      'name TEXT NOT NULL, '
      'category_id TEXT NULL REFERENCES categories (id), '
      'amount REAL NOT NULL, '
      'kind TEXT NOT NULL, '
      'sort_order INTEGER NOT NULL, '
      'created_at TEXT NOT NULL, '
      'updated_at TEXT NOT NULL, '
      'PRIMARY KEY (id))',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_weekly_budgets_start '
      'ON weekly_budgets(week_start_date)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_wb_items_budget_sort '
      'ON weekly_budget_items(budget_id, sort_order)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_weekly_budgets_template '
      'ON weekly_budgets(is_template) WHERE is_template = 1',
    );
  }

  /// Hotfix quality-review M4: helper compartido para el schema de préstamos
  /// (tabla `loans` + 4 columnas en `journal_entries` + índice parcial).
  /// Idempotente vía IF NOT EXISTS. Sólo agrega `is_monthly_payment` si
  /// aún no existe (defensa contra bump inline previo).
  Future<void> _createLoansSchema() async {
    await customStatement(
      'CREATE TABLE IF NOT EXISTS loans ('
      'id TEXT NOT NULL, '
      'name TEXT NOT NULL, '
      'principal_amount REAL NOT NULL, '
      'monthly_payment REAL NOT NULL, '
      'initial_duration_months INTEGER NOT NULL, '
      'current_duration_months INTEGER NOT NULL, '
      'payment_day INTEGER NOT NULL, '
      'contract_date TEXT NOT NULL, '
      'destination_account_id TEXT NOT NULL REFERENCES accounts (id), '
      'closed_at TEXT NULL, '
      'close_reason TEXT NULL, '
      'created_at TEXT NOT NULL, '
      'updated_at TEXT NOT NULL, '
      'deleted_at TEXT NULL, '
      'PRIMARY KEY (id))',
    );
    // `ALTER TABLE ADD COLUMN` NO acepta IF NOT EXISTS en SQLite. Reusamos
    // `_maybeAddColumn` para probar antes de agregar.
    await _maybeAddColumn(
        'journal_entries', 'loan_id', 'TEXT REFERENCES loans (id)');
    await _maybeAddColumn('journal_entries', 'principal_amount', 'REAL');
    await _maybeAddColumn('journal_entries', 'interest_amount', 'REAL');
    await _maybeAddColumn('journal_entries', 'is_monthly_payment',
        'INTEGER NOT NULL DEFAULT 0 CHECK (is_monthly_payment IN (0, 1))');
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_entries_loan '
      'ON journal_entries(loan_id) WHERE loan_id IS NOT NULL',
    );
  }

  /// Sprint flutter-budgets-item-completion-v1: agrega `is_done` a
  /// `weekly_budget_items` de forma idempotente (probe pragma_table_info).
  /// DEFAULT 0 aplica a filas existentes.
  Future<void> _addIsDoneColumn() async {
    await _maybeAddColumn(
      'weekly_budget_items',
      'is_done',
      'INTEGER NOT NULL DEFAULT 0 CHECK (is_done IN (0, 1))',
    );
  }

  /// Hotfix quality-review B20: índices en la tabla `loans` (11→12).
  Future<void> _createLoansIndexes() async {
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_loans_deleted ON loans(deleted_at)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_loans_dest_account '
      'ON loans(destination_account_id) WHERE deleted_at IS NULL',
    );
  }

  /// Sprint flutter-integer-cents-v1 (schemaVersion 14): convierte las 9
  /// columnas monetarias de REAL a INTEGER (centavos).
  ///
  /// **Por qué `alterTable` y no un `UPDATE`**: SQLite aplica *type affinity*
  /// por columna. En una columna declarada `REAL`, un `UPDATE ... SET amount =
  /// CAST(ROUND(amount * 100) AS INTEGER)` vuelve a guardar el valor como
  /// REAL (`17377.0`), y drift al leerlo con `read<int>()` explota. La única
  /// forma correcta es recrear la tabla con la declaración nueva. `alterTable`
  /// de drift hace exactamente eso: `CREATE TABLE _new` con el schema Dart
  /// vigente (ya INTEGER) + `INSERT INTO _new SELECT <transform> FROM old` +
  /// `DROP old` + `RENAME`.
  ///
  /// `ROUND` y no `CAST` directo: truncar perdería el centavo en valores con
  /// residuo IEEE 754 (`173.7699999 * 100 = 17376.99999` → truncado daría
  /// `17376`, redondeado da `17377`).
  ///
  /// NULL propaga limpio: `ROUND(NULL * 100)` es NULL, así que las columnas
  /// nullables (`principal_amount`, `interest_amount`, `monthly_limit`) no
  /// necesitan un `CASE WHEN`.
  ///
  /// Idempotente por probe de `pragma_table_info`: si `journal_entries.amount`
  /// ya está declarada INTEGER, la conversión ya corrió (reintento tras crash
  /// a mitad de migración) y la función es no-op.
  ///
  /// `alterTable` pierde los índices creados por `customStatement` en
  /// `onCreate` (no están declarados en el schema Dart), así que se recrean
  /// explícitamente al final — mismo caveat que la migración 4→5 documenta
  /// para `idx_accounts_deleted`.
  Future<void> _convertMoneyColumnsToInteger(Migrator m) async {
    final probe = await customSelect(
      "SELECT type FROM pragma_table_info('journal_entries') "
      "WHERE name = 'amount'",
    ).getSingleOrNull();
    if (probe != null &&
        probe.read<String>('type').toUpperCase() == 'INTEGER') {
      return;
    }

    const toCents = 'CAST(ROUND(%s * 100) AS INTEGER)';
    CustomExpression<int> cents(String column) =>
        CustomExpression<int>(toCents.replaceAll('%s', column));

    await m.alterTable(TableMigration(
      journalEntries,
      columnTransformer: {
        journalEntries.amount: cents('amount'),
        journalEntries.principalAmount: cents('principal_amount'),
        journalEntries.interestAmount: cents('interest_amount'),
      },
    ));
    await m.alterTable(TableMigration(
      accounts,
      columnTransformer: {
        accounts.creditLimit: cents('credit_limit'),
        accounts.minimumFloor: cents('minimum_floor'),
      },
    ));
    await m.alterTable(TableMigration(
      loans,
      columnTransformer: {
        loans.principalAmount: cents('principal_amount'),
        loans.monthlyPayment: cents('monthly_payment'),
      },
    ));
    await m.alterTable(TableMigration(
      weeklyBudgetItems,
      columnTransformer: {
        weeklyBudgetItems.amount: cents('amount'),
      },
    ));
    await m.alterTable(TableMigration(
      categories,
      columnTransformer: {
        categories.monthlyLimit: cents('monthly_limit'),
      },
    ));

    // Re-crear índices que viven fuera del schema Dart (customStatement en
    // onCreate) y que `alterTable` dropea junto con la tabla original.
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_entries_origin '
      'ON journal_entries(account_origin_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_entries_dest '
      'ON journal_entries(account_destination_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_entries_deleted '
      'ON journal_entries(deleted_at)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_entries_kind ON journal_entries(kind)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_entries_occurred_active '
      'ON journal_entries(occurred_at DESC) WHERE deleted_at IS NULL',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_entries_loan '
      'ON journal_entries(loan_id) WHERE loan_id IS NOT NULL',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_accounts_deleted ON accounts(deleted_at)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_categories_deleted '
      'ON categories(deleted_at)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_wb_items_budget_sort '
      'ON weekly_budget_items(budget_id, sort_order)',
    );
    await _createLoansIndexes();
  }
}
