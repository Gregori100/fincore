// Tests del sprint flutter-accounts-archive-v1.
//
// Cubre la separación de los 3 métodos del `AccountsDao`:
// - `archive` (reversible, no toca movimientos).
// - `unarchive` (revierte archive).
// - `deleteAccount` (destructivo cascada, ex-`archive` previo al sprint).
//
// Los tests del comportamiento cascada de `deleteAccount` viven en
// `database_test.dart` e `invariants_test.dart` renombrados en el mismo
// sprint. Aquí sólo va la semántica NUEVA de archive/unarchive y los
// streams `watchActive` / `watchArchived`.

import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:fincore/data/daos/accounts_dao.dart';
import 'package:fincore/data/daos/categories_dao.dart';
import 'package:fincore/data/daos/entries_dao.dart';
import 'package:fincore/data/database.dart';
import 'package:fincore/data/seed.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/factories.dart';
import '../helpers/sqlite_override.dart';

void main() {
  setUpAll(initSqliteOverride);

  late FincoreDatabase db;
  late AccountsDao accountsDao;
  late EntriesDao entriesDao;
  late String bolsaId;
  late String debitId;

  setUp(() async {
    db = FincoreDatabase(NativeDatabase.memory());
    accountsDao = AccountsDao(db);
    entriesDao = EntriesDao(db);
    await seedDefaults(
      db: db,
      accountsDao: accountsDao,
      categoriesDao: CategoriesDao(db),
    );
    final bolsa = await accountsDao.listAll().then(
        (l) => l.firstWhere((a) => a.type == 'cash'));
    bolsaId = bolsa.id;
    debitId = await accountsDao.create(name: 'Débito de prueba', type: 'debit');
  });

  tearDown(() async {
    await db.close();
  });

  group('AccountsDao.archive', () {
    test('marca archivedAt en la cuenta objetivo', () async {
      await accountsDao.archive(debitId);
      final account = await accountsDao.findById(debitId);
      expect(account, isNotNull);
      expect(account!.archivedAt, isNotNull);
      expect(account.deletedAt, isNull);
    });

    test('no toca los journal_entries asociados', () async {
      final incomeId = await entriesDao.registerIncome(
        accountDestinationId: debitId,
        amount: 10000,
        occurredAt: DateTime.utc(2026, 7, 1),
      );
      await accountsDao.archive(debitId);
      final entry = await entriesDao.findById(incomeId);
      expect(entry, isNotNull);
      expect(entry!.entry.deletedAt, isNull);
    });

    test('sobre la Bolsa lanza protected_account', () async {
      expect(
        () => accountsDao.archive(bolsaId),
        throwsA(isA<AccountsDaoError>()
            .having((e) => e.code, 'code', 'protected_account')),
      );
    });

    test('sobre id inexistente lanza not_found', () async {
      expect(
        () => accountsDao.archive('nonexistent'),
        throwsA(isA<AccountsDaoError>()
            .having((e) => e.code, 'code', 'not_found')),
      );
    });

    test('idempotente: llamar dos veces no rompe', () async {
      await accountsDao.archive(debitId);
      await accountsDao.archive(debitId);
      final account = await accountsDao.findById(debitId);
      expect(account!.archivedAt, isNotNull);
    });
  });

  group('AccountsDao.unarchive', () {
    test('limpia archivedAt de una cuenta archivada', () async {
      await accountsDao.archive(debitId);
      await accountsDao.unarchive(debitId);
      final account = await accountsDao.findById(debitId);
      expect(account!.archivedAt, isNull);
      expect(account.deletedAt, isNull);
    });

    test('sobre cuenta ya activa: no-op silencioso', () async {
      await accountsDao.unarchive(debitId);
      final account = await accountsDao.findById(debitId);
      expect(account!.archivedAt, isNull);
    });

    test('sobre Bolsa lanza protected_account', () async {
      expect(
        () => accountsDao.unarchive(bolsaId),
        throwsA(isA<AccountsDaoError>()
            .having((e) => e.code, 'code', 'protected_account')),
      );
    });

    test('sobre id inexistente lanza not_found', () async {
      expect(
        () => accountsDao.unarchive('nonexistent'),
        throwsA(isA<AccountsDaoError>()
            .having((e) => e.code, 'code', 'not_found')),
      );
    });
  });

  group('watchActive / watchArchived', () {
    test('watchActive excluye archivadas', () async {
      await accountsDao.archive(debitId);
      final active = await accountsDao.watchActive().first;
      expect(active.any((a) => a.id == debitId), isFalse);
      // Bolsa sigue activa.
      expect(active.any((a) => a.id == bolsaId), isTrue);
    });

    test('watchArchived sólo devuelve archivadas', () async {
      var archived = await accountsDao.watchArchived().first;
      expect(archived, isEmpty);

      await accountsDao.archive(debitId);
      archived = await accountsDao.watchArchived().first;
      expect(archived.length, 1);
      expect(archived.first.id, debitId);
    });

    test('watchArchived excluye eliminadas', () async {
      await accountsDao.archive(debitId);
      // Simular delete manual (cascada) sobre la misma cuenta archivada.
      await accountsDao.deleteAccount(debitId);
      final archived = await accountsDao.watchArchived().first;
      expect(archived, isEmpty);
    });
  });

  group('listAll(includeArchived)', () {
    test('por default excluye archivadas', () async {
      await accountsDao.archive(debitId);
      final list = await accountsDao.listAll();
      expect(list.any((a) => a.id == debitId), isFalse);
    });

    test('includeArchived: true incluye archivadas', () async {
      await accountsDao.archive(debitId);
      final list = await accountsDao.listAll(includeArchived: true);
      expect(list.any((a) => a.id == debitId), isTrue);
    });

    test('nunca incluye eliminadas', () async {
      await accountsDao.deleteAccount(debitId);
      final list = await accountsDao.listAll(includeArchived: true);
      expect(list.any((a) => a.id == debitId), isFalse);
    });
  });

  group('findActiveOrArchivedById', () {
    test('devuelve cuenta activa', () async {
      final account = await accountsDao.findActiveOrArchivedById(debitId);
      expect(account, isNotNull);
      expect(account!.id, debitId);
    });

    test('devuelve cuenta archivada', () async {
      await accountsDao.archive(debitId);
      final account = await accountsDao.findActiveOrArchivedById(debitId);
      expect(account, isNotNull);
      expect(account!.archivedAt, isNotNull);
    });

    test('retorna null para cuenta eliminada', () async {
      await accountsDao.deleteAccount(debitId);
      final account = await accountsDao.findActiveOrArchivedById(debitId);
      expect(account, isNull);
    });

    test('retorna null para id inexistente', () async {
      final account = await accountsDao.findActiveOrArchivedById('nonexistent');
      expect(account, isNull);
    });
  });

  group('semántica de reportes', () {
    test('una cuenta archivada sigue apareciendo en journal_entries queries',
        () async {
      final incomeId = await entriesDao.registerIncome(
        accountDestinationId: debitId,
        amount: 25000,
        occurredAt: DateTime.utc(2026, 7, 1),
      );
      await accountsDao.archive(debitId);
      // Simula un caller que lee entries directamente (como los reportes):
      // el entry sigue vivo con deletedAt IS NULL.
      final entry = await entriesDao.findById(incomeId);
      expect(entry, isNotNull);
      expect(entry!.entry.deletedAt, isNull);
      // Y el join a Account devuelve la cuenta archivada (para que los
      // reportes puedan sumarla).
      final account = await accountsDao.findActiveOrArchivedById(debitId);
      expect(account, isNotNull);
      expect(account!.archivedAt, isNotNull);
    });
  });

  group('countAssociatedEntries (usado por DestructiveDialog)', () {
    test('cuenta 0 cuando la cuenta no tiene movimientos', () async {
      final count = await accountsDao.countAssociatedEntries(debitId);
      expect(count, 0);
    });

    test('cuenta N movimientos donde figura como origen o destino', () async {
      await entriesDao.registerIncome(
        accountDestinationId: debitId,
        amount: 10000,
        occurredAt: DateTime.utc(2026, 7, 1),
      );
      await entriesDao.registerExpense(
        accountOriginId: debitId,
        amount: 5000,
        occurredAt: DateTime.utc(2026, 7, 2),
      );
      final count = await accountsDao.countAssociatedEntries(debitId);
      expect(count, 2);
    });

    test('ignora movimientos cancelados', () async {
      final id = await entriesDao.registerIncome(
        accountDestinationId: debitId,
        amount: 10000,
        occurredAt: DateTime.utc(2026, 7, 1),
      );
      await entriesDao.cancel(id);
      final count = await accountsDao.countAssociatedEntries(debitId);
      expect(count, 0);
    });
  });

  group('bootstrap: schemaVersion 9 preserva la columna archived_at', () {
    test('insert directo con archivedAt persiste en round-trip', () async {
      final now = DateTime.utc(2026, 7, 10);
      await db.into(db.accounts).insert(
            Factories.debit(id: 'archived-account', name: 'Archivada seed')
                .copyWith(archivedAt: drift.Value(now)),
          );
      final account = await accountsDao.findById('archived-account');
      expect(account, isNotNull);
      expect(account!.archivedAt, now);
    });
  });
}
