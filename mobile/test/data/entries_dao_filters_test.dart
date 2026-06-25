import 'package:drift/native.dart';
import 'package:fincore/data/daos/accounts_dao.dart';
import 'package:fincore/data/daos/categories_dao.dart';
import 'package:fincore/data/daos/entries_dao.dart';
import 'package:fincore/data/database.dart';
import 'package:fincore/data/seed.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/sqlite_override.dart';

/// Tests de los nuevos filtros multi-valor de `EntriesDao.watchPage`
/// (sprint flutter-movements-filters-v1, RF-001 a RF-005).
void main() {
  setUpAll(initSqliteOverride);

  late FincoreDatabase db;
  late AccountsDao accountsDao;
  late CategoriesDao categoriesDao;
  late EntriesDao entriesDao;

  late String bolsa;
  late String debit;
  late String credit;
  late String catComida;
  late String catTransporte;
  late String catArchivada;

  Future<void> seedEntries() async {
    // Distribución intencionada para cubrir todas las RN:
    // - income con cat null
    // - expense en Comida activa
    // - expense en Transporte activa
    // - expense en categoría archivada
    // - credit_expense en Comida
    // - transfer + debt_payment sin categoría
    await entriesDao.registerIncome(
      accountDestinationId: bolsa,
      amount: 5000,
      occurredAt: DateTime(2026, 6, 1),
      description: 'Salario',
    );
    await entriesDao.registerExpense(
      accountOriginId: debit,
      categoryId: catComida,
      amount: 200,
      occurredAt: DateTime(2026, 6, 5),
    );
    await entriesDao.registerExpense(
      accountOriginId: bolsa,
      categoryId: catTransporte,
      amount: 150,
      occurredAt: DateTime(2026, 6, 10),
    );
    await entriesDao.registerExpense(
      accountOriginId: debit,
      categoryId: catArchivada,
      amount: 300,
      occurredAt: DateTime(2026, 6, 12),
    );
    await entriesDao.registerExpense(
      accountOriginId: debit,
      amount: 100,
      occurredAt: DateTime(2026, 6, 15),
    );
    await entriesDao.registerCreditExpense(
      accountOriginId: credit,
      categoryId: catComida,
      amount: 800,
      occurredAt: DateTime(2026, 6, 20),
    );
    await entriesDao.registerTransfer(
      accountOriginId: debit,
      accountDestinationId: bolsa,
      amount: 500,
      occurredAt: DateTime(2026, 6, 22),
    );
    // Archivar la categoría después de registrar el entry — el filtro debe
    // tratarla como "Sin categoría".
    await categoriesDao.archive(catArchivada);
  }

  setUp(() async {
    db = FincoreDatabase(NativeDatabase.memory());
    accountsDao = AccountsDao(db);
    categoriesDao = CategoriesDao(db);
    entriesDao = EntriesDao(db);

    await seedDefaults(
      db: db,
      accountsDao: accountsDao,
      categoriesDao: categoriesDao,
    );
    bolsa = (await accountsDao.listAll())
        .firstWhere((a) => a.type == 'cash')
        .id;
    debit = await accountsDao.create(name: 'Banamex', type: 'debit');
    credit = await accountsDao.create(
      name: 'Visa',
      type: 'credit',
      creditLimit: 50000,
    );
    catComida = await categoriesDao.create(
      name: 'Comida_Test',
      appliesTo: 'expense',
      colorSlug: 'red',
      iconSlug: 'shopping-cart',
    );
    catTransporte = await categoriesDao.create(
      name: 'Transporte_Test',
      appliesTo: 'expense',
      colorSlug: 'blue',
      iconSlug: 'truck',
    );
    catArchivada = await categoriesDao.create(
      name: 'Educación_Test',
      appliesTo: 'expense',
      colorSlug: 'purple',
      iconSlug: 'book-open',
    );

    await seedEntries();
  });

  tearDown(() async {
    await db.close();
  });

  group('watchPage — kinds (RN-M01)', () {
    test('kinds = [income] retorna solo income', () async {
      final entries =
          await entriesDao.watchPage(kinds: ['income'], limit: 100).first;
      expect(entries, hasLength(1));
      expect(entries.first.entry.kind, 'income');
    });

    test('kinds = [expense, credit_expense] retorna ambos kinds', () async {
      final entries = await entriesDao
          .watchPage(kinds: ['expense', 'credit_expense'], limit: 100)
          .first;
      expect(entries.length, 5,
          reason: '4 expense + 1 credit_expense en el seed');
      for (final e in entries) {
        expect(['expense', 'credit_expense'], contains(e.entry.kind));
      }
    });

    test('kinds = [] sin filtro (igual que null)', () async {
      final empty = await entriesDao.watchPage(kinds: [], limit: 100).first;
      final nullSet = await entriesDao.watchPage(limit: 100).first;
      expect(empty.length, nullSet.length);
    });

    test('kinds = null no filtra por tipo', () async {
      final entries = await entriesDao.watchPage(limit: 100).first;
      expect(entries.length, 7,
          reason: 'Seed: 1 income + 4 expense + 1 credit_expense + 1 transfer');
    });
  });

  group('watchPage — categoryIds (RN-M02, RN-M03)', () {
    test('categoryIds = [catComida] retorna solo Comida', () async {
      final entries = await entriesDao
          .watchPage(categoryIds: [catComida], limit: 100)
          .first;
      expect(entries, hasLength(2),
          reason: '1 expense + 1 credit_expense en Comida');
      for (final e in entries) {
        expect(e.entry.categoryId, catComida);
      }
    });

    test('categoryIds = [catComida, catTransporte] retorna ambas', () async {
      final entries = await entriesDao
          .watchPage(categoryIds: [catComida, catTransporte], limit: 100)
          .first;
      expect(entries, hasLength(3),
          reason: '2 Comida + 1 Transporte');
    });

    test('categoryIds = [__null__] retorna NULL + categoría archivada (RN-R03/R04)',
        () async {
      final entries = await entriesDao.watchPage(
        categoryIds: [kUncategorizedFilterToken],
        limit: 100,
      ).first;
      // Seed contiene:
      // - 1 income con cat null
      // - 1 expense con cat null
      // - 1 expense en cat archivada
      // - 1 transfer sin cat
      expect(entries.length, 4);
    });

    test('categoryIds = [catComida, __null__] mix retorna ambos sets',
        () async {
      final entries = await entriesDao.watchPage(
        categoryIds: [catComida, kUncategorizedFilterToken],
        limit: 100,
      ).first;
      // 2 Comida + 4 sin-categoría
      expect(entries.length, 6);
    });
  });

  group('watchPage — combinaciones AND (RN-M06)', () {
    test('kinds + categoryIds: AND entre dimensiones', () async {
      // Solo gastos en Comida (excluye income, transfer, otras categorías).
      final entries = await entriesDao.watchPage(
        kinds: ['expense', 'credit_expense'],
        categoryIds: [catComida],
        limit: 100,
      ).first;
      expect(entries.length, 2);
      for (final e in entries) {
        expect(['expense', 'credit_expense'], contains(e.entry.kind));
        expect(e.entry.categoryId, catComida);
      }
    });

    test('kinds + categoryIds = __null__ excluye income con cat null', () async {
      // Solo "Gastos sin categoría". El income con cat null NO debe contar.
      final entries = await entriesDao.watchPage(
        kinds: ['expense', 'credit_expense'],
        categoryIds: [kUncategorizedFilterToken],
        limit: 100,
      ).first;
      // Seed: 1 expense con cat null + 1 expense en cat archivada
      expect(entries.length, 2);
      for (final e in entries) {
        expect(['expense', 'credit_expense'], contains(e.entry.kind));
      }
    });

    test('rango temporal acota correctamente', () async {
      final entries = await entriesDao.watchPage(
        from: DateTime(2026, 6, 10),
        to: DateTime(2026, 6, 15),
        limit: 100,
      ).first;
      // Día 10, 12, 15.
      expect(entries.length, 3);
    });

    test('combinación completa (filtros + rango + cuenta)', () async {
      final entries = await entriesDao.watchPage(
        kinds: ['expense'],
        categoryIds: [catComida, catTransporte],
        accountIds: [debit],
        from: DateTime(2026, 6, 1),
        to: DateTime(2026, 6, 30),
        limit: 100,
      ).first;
      // Expense en Comida(debit, día 5).
      // Transporte está en bolsa (origin), no debit → NO entra.
      expect(entries.length, 1);
      expect(entries.first.entry.categoryId, catComida);
      expect(entries.first.entry.accountOriginId, debit);
    });

    test('accountIds multi: matchea entries en cualquiera de las cuentas',
        () async {
      final entries = await entriesDao
          .watchPage(accountIds: [bolsa, debit], limit: 100)
          .first;
      // Casi todos los entries del seed (income en bolsa, expense en debit,
      // expense en bolsa, credit_expense en credit, transfer debit→bolsa).
      // Excluye solo el credit_expense que es origin=credit (sin bolsa ni debit).
      expect(entries.length, 6);
    });

    test(
        'M14: transfer debit→bolsa aparece en accountIds=[debit] (origin)',
        () async {
      final entries = await entriesDao
          .watchPage(accountIds: [debit], kinds: ['transfer'], limit: 100)
          .first;
      expect(entries, hasLength(1));
      expect(entries.first.entry.accountOriginId, debit);
      expect(entries.first.entry.accountDestinationId, bolsa);
    });

    test(
        'M14: mismo transfer aparece en accountIds=[bolsa] (destination)',
        () async {
      final entries = await entriesDao
          .watchPage(accountIds: [bolsa], kinds: ['transfer'], limit: 100)
          .first;
      expect(entries, hasLength(1));
      expect(entries.first.entry.accountOriginId, debit);
      expect(entries.first.entry.accountDestinationId, bolsa);
    });
  });

  group('watchPage — soft-delete (RN-M07)', () {
    test('entry cancelado no aparece independiente de filtros', () async {
      final all1 = await entriesDao.watchPage(limit: 100).first;
      // Cancelar el primer expense (catComida).
      final target =
          all1.firstWhere((e) => e.entry.categoryId == catComida);
      await entriesDao.cancel(target.entry.id);

      final filtered = await entriesDao
          .watchPage(categoryIds: [catComida], limit: 100)
          .first;
      // 1 menos (era 2: 1 expense + 1 credit_expense).
      expect(filtered.length, 1);
    });
  });

  group('watchPage — orden + compatibilidad', () {
    test('orden occurred_at DESC se preserva con filtros', () async {
      final entries = await entriesDao.watchPage(
        kinds: ['expense', 'credit_expense'],
        limit: 100,
      ).first;
      DateTime? prev;
      for (final e in entries) {
        if (prev != null) {
          expect(e.entry.occurredAt.isBefore(prev) ||
                  e.entry.occurredAt.isAtSameMomentAs(prev),
              isTrue);
        }
        prev = e.entry.occurredAt;
      }
    });

    test('compatibilidad: kind: String (deprecado) sigue funcionando', () async {
      // ignore: deprecated_member_use_from_same_package
      final entries = await entriesDao.watchPage(
        // ignore: deprecated_member_use_from_same_package
        kind: 'income',
        limit: 100,
      ).first;
      expect(entries, hasLength(1));
      expect(entries.first.entry.kind, 'income');
    });
  });
}
