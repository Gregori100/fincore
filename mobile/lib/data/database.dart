import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

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
  // Metadata de tarjeta (solo aplica si type='credit', NULL en cash/debit).
  RealColumn get creditLimit => real().nullable()();
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
// FincoreDatabase
// =============================================================================
@DriftDatabase(tables: [Accounts, Categories, JournalEntries])
class FincoreDatabase extends _$FincoreDatabase {
  FincoreDatabase([QueryExecutor? executor])
      : super(executor ?? driftDatabase(name: 'fincore'));

  @override
  int get schemaVersion => 1;

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
        },
        onUpgrade: (m, from, to) async {
          // Stub para futuras migraciones. Nunca recrear la BD del usuario
          // (RN-005 + spec): cada paso preserva los datos existentes.
        },
        beforeOpen: (details) async {
          // SQLite trae FKs deshabilitadas por default; sin esto las references
          // declaradas arriba no se enforzan. Crítico para integridad.
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}
