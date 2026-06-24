import 'package:drift/native.dart';
import 'package:fincore/data/daos/accounts_dao.dart';
import 'package:fincore/data/daos/categories_dao.dart';
import 'package:fincore/data/daos/entries_dao.dart';
import 'package:fincore/data/database.dart';
import 'package:fincore/data/reports.dart';
import 'package:fincore/data/seed.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/sqlite_override.dart';

/// Tests del `ReportsService.spendingByCategory` del sprint `flutter-reports-v1`.
/// Cubre RN-R01 a RN-R08 + casos borde CB-T01 a CB-T20 del test-plan.
void main() {
  setUpAll(initSqliteOverride);

  late FincoreDatabase db;
  late AccountsDao accountsDao;
  late CategoriesDao categoriesDao;
  late EntriesDao entriesDao;
  late ReportsService reports;

  late String bolsa;
  late String debit;
  late String credit;
  late String catComida;
  late String catTransporte;
  late String catSalud;

  // Rango por default amplio para tests que no especifican filtros temporales.
  final from = DateTime(2026, 6, 1);
  final to = DateTime(2026, 6, 30, 23, 59, 59, 999);

  setUp(() async {
    db = FincoreDatabase(NativeDatabase.memory());
    accountsDao = AccountsDao(db);
    categoriesDao = CategoriesDao(db);
    entriesDao = EntriesDao(db);
    reports = ReportsService(db);

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

    // Categorías expense para los tests. Las del seed son `both`, pero un
    // expense las acepta igual.
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
    catSalud = await categoriesDao.create(
      name: 'Salud_Test',
      appliesTo: 'expense',
      colorSlug: 'green',
      iconSlug: 'heart',
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('spendingByCategory — agregación básica', () {
    test('BD sin entries en el rango: total=0, buckets=[]', () async {
      final report = await reports
          .spendingByCategory(from: from, to: to)
          .first;
      expect(report.total, 0);
      expect(report.count, 0);
      expect(report.buckets, isEmpty);
      expect(report.isEmpty, isTrue);
    });

    test('Único expense: 1 bucket con total + percent 1.0', () async {
      await entriesDao.registerExpense(
        accountOriginId: debit,
        categoryId: catComida,
        amount: 1000,
        occurredAt: DateTime(2026, 6, 10),
      );
      final report = await reports
          .spendingByCategory(from: from, to: to)
          .first;
      expect(report.total, 1000);
      expect(report.count, 1);
      expect(report.buckets, hasLength(1));
      final bucket = report.buckets.first;
      expect(bucket.total, 1000);
      expect(bucket.count, 1);
      expect(bucket.percent, closeTo(1.0, 1e-9));
      expect(bucket.name, 'Comida_Test');
      expect(bucket.colorSlug, 'red');
      expect(bucket.iconSlug, 'shopping-cart');
    });

    test('Dos expense misma categoría: bucket único agregado', () async {
      await entriesDao.registerExpense(
        accountOriginId: debit,
        categoryId: catComida,
        amount: 100,
        occurredAt: DateTime(2026, 6, 10),
      );
      await entriesDao.registerExpense(
        accountOriginId: bolsa,
        categoryId: catComida,
        amount: 250,
        occurredAt: DateTime(2026, 6, 15),
      );
      final report = await reports
          .spendingByCategory(from: from, to: to)
          .first;
      expect(report.total, 350);
      expect(report.count, 2);
      expect(report.buckets, hasLength(1));
      expect(report.buckets.first.total, 350);
      expect(report.buckets.first.count, 2);
    });

    test('Distintas categorías: orden por monto desc', () async {
      await entriesDao.registerExpense(
        accountOriginId: debit,
        categoryId: catComida,
        amount: 100,
        occurredAt: DateTime(2026, 6, 10),
      );
      await entriesDao.registerExpense(
        accountOriginId: debit,
        categoryId: catTransporte,
        amount: 300,
        occurredAt: DateTime(2026, 6, 12),
      );
      await entriesDao.registerExpense(
        accountOriginId: debit,
        categoryId: catSalud,
        amount: 200,
        occurredAt: DateTime(2026, 6, 14),
      );
      final report = await reports
          .spendingByCategory(from: from, to: to)
          .first;
      expect(report.buckets.map((b) => b.name).toList(),
          ['Transporte_Test', 'Salud_Test', 'Comida_Test']);
      expect(report.buckets.map((b) => b.total).toList(), [300, 200, 100]);
    });

    test('Empate de monto: tiebreak alfabético asc', () async {
      await entriesDao.registerExpense(
        accountOriginId: debit,
        categoryId: catComida, // Comida_Test
        amount: 100,
        occurredAt: DateTime(2026, 6, 10),
      );
      await entriesDao.registerExpense(
        accountOriginId: debit,
        categoryId: catSalud, // Salud_Test
        amount: 100,
        occurredAt: DateTime(2026, 6, 11),
      );
      final report = await reports
          .spendingByCategory(from: from, to: to)
          .first;
      expect(report.buckets.map((b) => b.name).toList(),
          ['Comida_Test', 'Salud_Test']);
    });
  });

  group('spendingByCategory — filtros de kind (RN-R01/R02)', () {
    test('expense + credit_expense ambos cuentan', () async {
      await entriesDao.registerExpense(
        accountOriginId: debit,
        categoryId: catComida,
        amount: 100,
        occurredAt: DateTime(2026, 6, 10),
      );
      await entriesDao.registerCreditExpense(
        accountOriginId: credit,
        categoryId: catComida,
        amount: 200,
        occurredAt: DateTime(2026, 6, 15),
      );
      final report = await reports
          .spendingByCategory(from: from, to: to)
          .first;
      expect(report.total, 300);
      expect(report.count, 2);
      expect(report.buckets, hasLength(1));
      expect(report.buckets.first.name, 'Comida_Test');
    });

    test('transfer + debt_payment + income: ninguno cuenta', () async {
      // Sembrar fondos para el debt_payment. Sin categoryId porque catComida
      // es expense-only y el DAO valida appliesTo contra el kind.
      await entriesDao.registerIncome(
        accountDestinationId: debit,
        amount: 5000,
        occurredAt: DateTime(2026, 6, 5),
      );
      await entriesDao.registerCreditExpense(
        accountOriginId: credit,
        amount: 1000,
        occurredAt: DateTime(2026, 6, 7),
      );
      // Reporte solo de junio 12-30 para excluir el credit_expense de arriba.
      // transfer y debt_payment no aceptan categoryId por diseño del DAO
      // (movimientos internos sin categoría). El filtro de kind del reporte
      // los excluye igual.
      await entriesDao.registerTransfer(
        accountOriginId: debit,
        accountDestinationId: bolsa,
        amount: 500,
        occurredAt: DateTime(2026, 6, 13),
      );
      await entriesDao.registerDebtPayment(
        accountOriginId: debit,
        accountDestinationId: credit,
        amount: 800,
        occurredAt: DateTime(2026, 6, 14),
      );
      final report = await reports
          .spendingByCategory(
            from: DateTime(2026, 6, 12),
            to: DateTime(2026, 6, 30, 23, 59, 59, 999),
          )
          .first;
      expect(report.total, 0,
          reason: 'transfer, debt_payment e income no son gasto');
      expect(report.count, 0);
      expect(report.buckets, isEmpty);
    });
  });

  group('spendingByCategory — bucket Sin categoría (RN-R03/R04/R08)', () {
    test('expense con categoryId null va a Sin categoría', () async {
      await entriesDao.registerExpense(
        accountOriginId: debit,
        amount: 500,
        occurredAt: DateTime(2026, 6, 10),
      );
      final report = await reports
          .spendingByCategory(from: from, to: to)
          .first;
      expect(report.buckets, hasLength(1));
      final bucket = report.buckets.first;
      expect(bucket.categoryId, isNull);
      expect(bucket.name, kUncategorizedBucketName);
      expect(bucket.colorSlug, isNull,
          reason: 'colorSlug null → UI usa fallback gray');
      expect(bucket.iconSlug, isNull,
          reason: 'iconSlug null → UI usa fallback label_outline');
      expect(bucket.total, 500);
    });

    test('expense con categoría archivada va a Sin categoría (RN-R04)',
        () async {
      await entriesDao.registerExpense(
        accountOriginId: debit,
        categoryId: catComida,
        amount: 700,
        occurredAt: DateTime(2026, 6, 10),
      );
      // Archivar la categoría DESPUÉS del registro.
      await categoriesDao.archive(catComida);
      final report = await reports
          .spendingByCategory(from: from, to: to)
          .first;
      expect(report.buckets, hasLength(1));
      final bucket = report.buckets.first;
      expect(bucket.categoryId, isNull,
          reason: 'archivada se trata como Sin categoría');
      expect(bucket.name, kUncategorizedBucketName);
      expect(bucket.total, 700);
    });

    test(
        'Mezcla null + archivada se agrega en un único bucket Sin categoría',
        () async {
      await entriesDao.registerExpense(
        accountOriginId: debit,
        amount: 100,
        occurredAt: DateTime(2026, 6, 10),
      );
      await entriesDao.registerExpense(
        accountOriginId: debit,
        categoryId: catComida,
        amount: 200,
        occurredAt: DateTime(2026, 6, 11),
      );
      await categoriesDao.archive(catComida);
      final report = await reports
          .spendingByCategory(from: from, to: to)
          .first;
      expect(report.buckets, hasLength(1));
      expect(report.buckets.first.name, kUncategorizedBucketName);
      expect(report.buckets.first.total, 300);
      expect(report.buckets.first.count, 2);
    });

    test('Sin categoría coexiste con categoría activa', () async {
      await entriesDao.registerExpense(
        accountOriginId: debit,
        amount: 100,
        occurredAt: DateTime(2026, 6, 10),
      );
      await entriesDao.registerExpense(
        accountOriginId: debit,
        categoryId: catTransporte,
        amount: 300,
        occurredAt: DateTime(2026, 6, 11),
      );
      final report = await reports
          .spendingByCategory(from: from, to: to)
          .first;
      expect(report.buckets, hasLength(2));
      // Transporte_Test (300) primero, Sin categoría (100) después.
      expect(report.buckets[0].name, 'Transporte_Test');
      expect(report.buckets[1].name, kUncategorizedBucketName);
    });
  });

  group('spendingByCategory — filtro temporal (RN-R05)', () {
    test('Entry fuera del rango (antes de from) no cuenta', () async {
      await entriesDao.registerExpense(
        accountOriginId: debit,
        categoryId: catComida,
        amount: 100,
        occurredAt: DateTime(2026, 5, 30),
      );
      final report = await reports
          .spendingByCategory(from: from, to: to)
          .first;
      expect(report.total, 0);
      expect(report.buckets, isEmpty);
    });

    test('Entry fuera del rango (después de to) no cuenta', () async {
      await entriesDao.registerExpense(
        accountOriginId: debit,
        categoryId: catComida,
        amount: 100,
        occurredAt: DateTime(2026, 7, 1),
      );
      final report = await reports
          .spendingByCategory(from: from, to: to)
          .first;
      expect(report.total, 0);
    });

    test('Límite inclusivo en `from` exacto (CB-T05)', () async {
      await entriesDao.registerExpense(
        accountOriginId: debit,
        categoryId: catComida,
        amount: 100,
        occurredAt: from,
      );
      final report = await reports
          .spendingByCategory(from: from, to: to)
          .first;
      expect(report.total, 100,
          reason: 'occurred_at == from cuenta (rango inclusivo)');
    });

    test('Límite inclusivo en `to` exacto (CB-T06)', () async {
      await entriesDao.registerExpense(
        accountOriginId: debit,
        categoryId: catComida,
        amount: 100,
        occurredAt: to,
      );
      final report = await reports
          .spendingByCategory(from: from, to: to)
          .first;
      expect(report.total, 100,
          reason: 'occurred_at == to cuenta (rango inclusivo)');
    });

    test('from == to: rango de un día válido (CB-T15)', () async {
      final single = DateTime(2026, 6, 10);
      await entriesDao.registerExpense(
        accountOriginId: debit,
        categoryId: catComida,
        amount: 100,
        occurredAt: single,
      );
      await entriesDao.registerExpense(
        accountOriginId: debit,
        categoryId: catComida,
        amount: 200,
        occurredAt: DateTime(2026, 6, 11),
      );
      final report = await reports
          .spendingByCategory(from: single, to: single)
          .first;
      expect(report.total, 100,
          reason: 'rango de 1 milisegundo solo captura el entry exacto');
    });
  });

  group('spendingByCategory — soft delete (RN-R07)', () {
    test('Entry soft-deleted no cuenta', () async {
      final entryId = await entriesDao.registerExpense(
        accountOriginId: debit,
        categoryId: catComida,
        amount: 100,
        occurredAt: DateTime(2026, 6, 10),
      );
      await entriesDao.cancel(entryId);
      final report = await reports
          .spendingByCategory(from: from, to: to)
          .first;
      expect(report.total, 0);
      expect(report.buckets, isEmpty);
    });
  });

  group('spendingByCategory — invariantes', () {
    test('percent suma a 1.0 ± epsilon con buckets', () async {
      await entriesDao.registerExpense(
        accountOriginId: debit,
        categoryId: catComida,
        amount: 100,
        occurredAt: DateTime(2026, 6, 10),
      );
      await entriesDao.registerExpense(
        accountOriginId: debit,
        categoryId: catTransporte,
        amount: 200,
        occurredAt: DateTime(2026, 6, 12),
      );
      await entriesDao.registerExpense(
        accountOriginId: debit,
        categoryId: catSalud,
        amount: 700,
        occurredAt: DateTime(2026, 6, 14),
      );
      final report = await reports
          .spendingByCategory(from: from, to: to)
          .first;
      final sumPercent = report.buckets
          .map((b) => b.percent)
          .fold<double>(0, (a, b) => a + b);
      expect(sumPercent, closeTo(1.0, 1e-9));
    });

    test('total == sum(buckets.total)', () async {
      await entriesDao.registerExpense(
        accountOriginId: debit,
        categoryId: catComida,
        amount: 123.45,
        occurredAt: DateTime(2026, 6, 10),
      );
      await entriesDao.registerExpense(
        accountOriginId: debit,
        categoryId: catTransporte,
        amount: 67.89,
        occurredAt: DateTime(2026, 6, 12),
      );
      final report = await reports
          .spendingByCategory(from: from, to: to)
          .first;
      final sumBuckets = report.buckets
          .map((b) => b.total)
          .fold<double>(0, (a, b) => a + b);
      expect(report.total, closeTo(sumBuckets, 1e-9));
    });

    test('Un único bucket: percent = 1.0', () async {
      await entriesDao.registerExpense(
        accountOriginId: debit,
        categoryId: catComida,
        amount: 50,
        occurredAt: DateTime(2026, 6, 10),
      );
      final report = await reports
          .spendingByCategory(from: from, to: to)
          .first;
      expect(report.buckets, hasLength(1));
      expect(report.buckets.first.percent, closeTo(1.0, 1e-9));
    });
  });

  group('spendingByCategory — integración con DAOs', () {
    test('Cancelar entry con DAO se refleja en el reporte', () async {
      final entryId = await entriesDao.registerExpense(
        accountOriginId: debit,
        categoryId: catComida,
        amount: 500,
        occurredAt: DateTime(2026, 6, 10),
      );
      var report = await reports
          .spendingByCategory(from: from, to: to)
          .first;
      expect(report.total, 500);
      await entriesDao.cancel(entryId);
      report = await reports
          .spendingByCategory(from: from, to: to)
          .first;
      expect(report.total, 0,
          reason: 'tras cancel, el entry no debe contar');
    });

    test('Archivar categoría con DAO mueve buckets a Sin categoría', () async {
      await entriesDao.registerExpense(
        accountOriginId: debit,
        categoryId: catComida,
        amount: 300,
        occurredAt: DateTime(2026, 6, 10),
      );
      var report = await reports
          .spendingByCategory(from: from, to: to)
          .first;
      expect(report.buckets.first.name, 'Comida_Test');
      await categoriesDao.archive(catComida);
      report = await reports
          .spendingByCategory(from: from, to: to)
          .first;
      expect(report.buckets.first.name, kUncategorizedBucketName,
          reason: 'tras archivar, el bucket pasa a Sin categoría');
    });
  });
}
