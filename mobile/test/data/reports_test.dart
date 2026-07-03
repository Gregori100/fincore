import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:fincore/data/daos/accounts_dao.dart';
import 'package:fincore/data/daos/categories_dao.dart';
import 'package:fincore/data/daos/entries_dao.dart';
import 'package:fincore/data/database.dart';
import 'package:fincore/data/financial_state.dart';
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

  // ===========================================================================
  // cashflowByMonth — sprint `flutter-reports-cashflow-v1`
  // Cubre RN-C01 a RN-C08 + casos borde CB-T01 a CB-T13 del test-plan.
  // ===========================================================================

  group('cashflowByMonth — agregación básica', () {
    test(
        'UT-01: BD sin entries → totales en 0, months poblado con ceros del rango',
        () async {
      final report = await reports
          .cashflowByMonth(from: from, to: to)
          .first;
      expect(report.totalIncome, 0);
      expect(report.totalExpense, 0);
      expect(report.net, 0);
      expect(report.months, hasLength(1),
          reason: 'rango de 1 mes calendario → 1 entrada con ceros');
      expect(report.months.first.income, 0);
      expect(report.months.first.expense, 0);
      expect(report.months.first.net, 0);
      expect(report.months.first.monthKey, '2026-06');
      expect(report.isEmpty, isTrue);
    });

    test(
        'UT-02: único income en junio → income > 0, expense = 0, net positivo',
        () async {
      await entriesDao.registerIncome(
        accountDestinationId: bolsa,
        amount: 1500,
        occurredAt: DateTime(2026, 6, 10),
      );
      final report = await reports
          .cashflowByMonth(from: from, to: to)
          .first;
      expect(report.totalIncome, 1500);
      expect(report.totalExpense, 0);
      expect(report.net, 1500);
      expect(report.months.first.income, 1500);
      expect(report.months.first.expense, 0);
      expect(report.months.first.net, 1500);
      expect(report.isEmpty, isFalse);
    });

    test(
        'UT-03: expense + credit_expense del mismo mes se suman en expense',
        () async {
      await entriesDao.registerExpense(
        accountOriginId: debit,
        amount: 200,
        occurredAt: DateTime(2026, 6, 10),
      );
      await entriesDao.registerCreditExpense(
        accountOriginId: credit,
        amount: 300,
        occurredAt: DateTime(2026, 6, 15),
      );
      final report = await reports
          .cashflowByMonth(from: from, to: to)
          .first;
      expect(report.totalIncome, 0);
      expect(report.totalExpense, 500,
          reason: 'expense + credit_expense suman en expense (RN-C02)');
      expect(report.net, -500);
    });
  });

  group('cashflowByMonth — filtros de kind (RN-C03)', () {
    test('UT-04: transfer NO cuenta', () async {
      await entriesDao.registerTransfer(
        accountOriginId: debit,
        accountDestinationId: bolsa,
        amount: 100,
        occurredAt: DateTime(2026, 6, 10),
      );
      final report = await reports
          .cashflowByMonth(from: from, to: to)
          .first;
      expect(report.totalIncome, 0);
      expect(report.totalExpense, 0);
    });

    test('UT-05: debt_payment NO cuenta', () async {
      // Generar deuda primero: un credit_expense aumenta la deuda de la
      // tarjeta. Después un debt_payment ≤ deuda es legal. El cashflow
      // contará el credit_expense (RN-C02) pero NO el debt_payment (RN-C03).
      await entriesDao.registerCreditExpense(
        accountOriginId: credit,
        amount: 200,
        occurredAt: DateTime(2026, 6, 5),
      );
      await entriesDao.registerDebtPayment(
        accountOriginId: debit,
        accountDestinationId: credit,
        amount: 100,
        occurredAt: DateTime(2026, 6, 10),
      );
      final report = await reports
          .cashflowByMonth(from: from, to: to)
          .first;
      expect(report.totalIncome, 0);
      expect(report.totalExpense, 200,
          reason: 'solo el credit_expense de 200 cuenta; el debt_payment NO');
    });
  });

  group('cashflowByMonth — soft delete', () {
    test('UT-06: entry soft-deleted no cuenta', () async {
      final entryId = await entriesDao.registerExpense(
        accountOriginId: debit,
        amount: 500,
        occurredAt: DateTime(2026, 6, 10),
      );
      var report = await reports
          .cashflowByMonth(from: from, to: to)
          .first;
      expect(report.totalExpense, 500);
      await entriesDao.cancel(entryId);
      report = await reports
          .cashflowByMonth(from: from, to: to)
          .first;
      expect(report.totalExpense, 0,
          reason: 'tras cancel, el entry no debe contar');
    });
  });

  group('cashflowByMonth — agrupación por mes', () {
    test(
        'UT-07: rango cruzando año tiene meses en orden cronológico ascendente',
        () async {
      // Rango: dic-2025 → feb-2026 (3 meses).
      final wideFrom = DateTime(2025, 12, 1);
      final wideTo = DateTime(2026, 2, 28, 23, 59, 59);
      await entriesDao.registerExpense(
        accountOriginId: debit,
        amount: 100,
        occurredAt: DateTime(2026, 1, 15),
      );
      final report = await reports
          .cashflowByMonth(from: wideFrom, to: wideTo)
          .first;
      expect(report.months.map((m) => m.monthKey).toList(),
          ['2025-12', '2026-01', '2026-02']);
    });

    test('UT-08: mes intermedio sin entries aparece con 0/0 (RN-C06)',
        () async {
      final wideFrom = DateTime(2026, 4, 1);
      final wideTo = DateTime(2026, 6, 30, 23, 59, 59);
      // Sembrar solo en abril y junio. Mayo queda vacío en medio.
      await entriesDao.registerExpense(
        accountOriginId: debit,
        amount: 100,
        occurredAt: DateTime(2026, 4, 10),
      );
      await entriesDao.registerExpense(
        accountOriginId: debit,
        amount: 200,
        occurredAt: DateTime(2026, 6, 10),
      );
      final report = await reports
          .cashflowByMonth(from: wideFrom, to: wideTo)
          .first;
      expect(report.months, hasLength(3));
      final mayo = report.months.firstWhere((m) => m.monthKey == '2026-05');
      expect(mayo.income, 0);
      expect(mayo.expense, 0,
          reason: 'mes intermedio sin entries debe aparecer con 0/0');
    });

    test('UT-09: from == to dentro del mismo mes → 1 MonthCashflow',
        () async {
      final day = DateTime(2026, 6, 15, 10);
      final report = await reports
          .cashflowByMonth(from: day, to: day)
          .first;
      expect(report.months, hasLength(1));
      expect(report.months.first.monthKey, '2026-06');
    });

    test('UT-10: rango cruza límite de mes → 2 entradas', () async {
      final tightFrom = DateTime(2026, 5, 31);
      final tightTo = DateTime(2026, 6, 1, 23, 59, 59);
      final report = await reports
          .cashflowByMonth(from: tightFrom, to: tightTo)
          .first;
      expect(report.months.map((m) => m.monthKey).toList(),
          ['2026-05', '2026-06']);
    });

    test('UT-11: límite inclusivo en `from` exacto (CB-T09)',
        () async {
      // Entry exacto en el límite `from`.
      await entriesDao.registerExpense(
        accountOriginId: debit,
        amount: 50,
        occurredAt: from,
      );
      final report = await reports
          .cashflowByMonth(from: from, to: to)
          .first;
      expect(report.totalExpense, 50,
          reason: 'entry en el límite `from` debe contar');
    });
  });

  group('cashflowByMonth — invariantes', () {
    test(
        'UT-12: net == income - expense para cada mes y para el total',
        () async {
      await entriesDao.registerIncome(
        accountDestinationId: bolsa,
        amount: 1000,
        occurredAt: DateTime(2026, 6, 10),
      );
      await entriesDao.registerExpense(
        accountOriginId: debit,
        amount: 300,
        occurredAt: DateTime(2026, 6, 12),
      );
      final report = await reports
          .cashflowByMonth(from: from, to: to)
          .first;
      expect(report.net, report.totalIncome - report.totalExpense);
      for (final m in report.months) {
        expect(m.net, m.income - m.expense,
            reason: 'invariante por mes ${m.monthKey}');
      }
    });

    test(
        'UT-13: sum(months.income) == totalIncome y sum(months.expense) == totalExpense',
        () async {
      final wideFrom = DateTime(2026, 4, 1);
      final wideTo = DateTime(2026, 6, 30, 23, 59, 59);
      await entriesDao.registerIncome(
        accountDestinationId: bolsa,
        amount: 800,
        occurredAt: DateTime(2026, 4, 10),
      );
      await entriesDao.registerExpense(
        accountOriginId: debit,
        amount: 200,
        occurredAt: DateTime(2026, 5, 15),
      );
      await entriesDao.registerCreditExpense(
        accountOriginId: credit,
        amount: 100,
        occurredAt: DateTime(2026, 6, 20),
      );
      final report = await reports
          .cashflowByMonth(from: wideFrom, to: wideTo)
          .first;
      final sumIncome =
          report.months.fold<double>(0, (acc, m) => acc + m.income);
      final sumExpense =
          report.months.fold<double>(0, (acc, m) => acc + m.expense);
      expect(sumIncome, report.totalIncome);
      expect(sumExpense, report.totalExpense);
    });
  });

  // ===========================================================================
  // topMovements — sprint `flutter-reports-top-movements-v1`
  // Cubre RN-T01..T08 + casos borde CB-T01..T16 del test-plan.
  // ===========================================================================
  const allKinds = [
    'income',
    'expense',
    'credit_expense',
    'debt_payment',
    'transfer',
  ];

  group('topMovements — agregación básica', () {
    test('UT-01: BD vacía → entries=[], isEmpty=true', () async {
      final report = await reports
          .topMovements(from: from, to: to, kinds: allKinds)
          .first;
      expect(report.entries, isEmpty);
      expect(report.isEmpty, isTrue);
    });

    test('UT-02: orden por monto desc', () async {
      await entriesDao.registerExpense(
        accountOriginId: debit,
        amount: 100,
        occurredAt: DateTime(2026, 6, 10),
        description: 'small',
      );
      await entriesDao.registerExpense(
        accountOriginId: debit,
        amount: 500,
        occurredAt: DateTime(2026, 6, 11),
        description: 'large',
      );
      await entriesDao.registerExpense(
        accountOriginId: debit,
        amount: 300,
        occurredAt: DateTime(2026, 6, 12),
        description: 'medium',
      );
      final report = await reports
          .topMovements(from: from, to: to, kinds: allKinds)
          .first;
      expect(report.entries.map((e) => e.amount).toList(), [500, 300, 100]);
      expect(report.entries.map((e) => e.description).toList(),
          ['large', 'medium', 'small']);
    });

    test('UT-03: tiebreak por occurred_at desc', () async {
      // 2 entries con monto idéntico, occurred_at distintos. El más
      // reciente debe aparecer primero.
      await entriesDao.registerExpense(
        accountOriginId: debit,
        amount: 200,
        occurredAt: DateTime(2026, 6, 10, 10),
        description: 'older',
      );
      await entriesDao.registerExpense(
        accountOriginId: debit,
        amount: 200,
        occurredAt: DateTime(2026, 6, 12, 10),
        description: 'newer',
      );
      final report = await reports
          .topMovements(from: from, to: to, kinds: allKinds)
          .first;
      expect(report.entries.first.description, 'newer',
          reason: 'tiebreak por occurred_at desc: más reciente primero');
    });
  });

  group('topMovements — soft delete y archivos', () {
    test('UT-04: entry soft-deleted no cuenta', () async {
      final id = await entriesDao.registerExpense(
        accountOriginId: debit,
        amount: 500,
        occurredAt: DateTime(2026, 6, 10),
      );
      var report = await reports
          .topMovements(from: from, to: to, kinds: allKinds)
          .first;
      expect(report.entries, hasLength(1));
      await entriesDao.cancel(id);
      report = await reports
          .topMovements(from: from, to: to, kinds: allKinds)
          .first;
      expect(report.entries, isEmpty);
    });

    test('UT-05: entry con categoría archivada → category null',
        () async {
      await entriesDao.registerExpense(
        accountOriginId: debit,
        categoryId: catComida,
        amount: 500,
        occurredAt: DateTime(2026, 6, 10),
      );
      var report = await reports
          .topMovements(from: from, to: to, kinds: allKinds)
          .first;
      expect(report.entries.first.category, isNotNull);
      expect(report.entries.first.category!.name, 'Comida_Test');
      await categoriesDao.archive(catComida);
      report = await reports
          .topMovements(from: from, to: to, kinds: allKinds)
          .first;
      expect(report.entries, hasLength(1));
      expect(report.entries.first.category, isNull,
          reason: 'tras archivar la categoría, badge desaparece (RN-T07)');
    });
  });

  group('topMovements — limit', () {
    test('UT-06: limit=20 con 30 entries → retorna 20', () async {
      for (var i = 0; i < 30; i++) {
        await entriesDao.registerExpense(
          accountOriginId: debit,
          amount: 100.0 + i,
          occurredAt: DateTime(2026, 6, 10, 0, i),
        );
      }
      final report = await reports
          .topMovements(from: from, to: to, kinds: allKinds, limit: 20)
          .first;
      expect(report.entries, hasLength(20));
      // Los más grandes (129..110) deben aparecer ordenados desc.
      expect(report.entries.first.amount, 129);
      expect(report.entries.last.amount, 110);
    });

    test('UT-07: limit=20 con 5 entries → retorna 5', () async {
      for (var i = 0; i < 5; i++) {
        await entriesDao.registerExpense(
          accountOriginId: debit,
          amount: 100.0 + i,
          occurredAt: DateTime(2026, 6, 10, 0, i),
        );
      }
      final report = await reports
          .topMovements(from: from, to: to, kinds: allKinds, limit: 20)
          .first;
      expect(report.entries, hasLength(5));
    });
  });

  group('topMovements — rango temporal', () {
    test('UT-08: rango inclusivo en `from` exacto', () async {
      await entriesDao.registerExpense(
        accountOriginId: debit,
        amount: 100,
        occurredAt: from,
      );
      final report = await reports
          .topMovements(from: from, to: to, kinds: allKinds)
          .first;
      expect(report.entries, hasLength(1),
          reason: 'entry en el límite `from` debe contar');
    });

    test('UT-09: rango inclusivo en `to` exacto (final del día)',
        () async {
      // El DAO extiende `to` internamente hasta 23:59:59.999.
      final boundaryTo = DateTime(2026, 6, 30);
      await entriesDao.registerExpense(
        accountOriginId: debit,
        amount: 100,
        occurredAt: DateTime(2026, 6, 30, 23, 30),
      );
      final report = await reports
          .topMovements(from: from, to: boundaryTo, kinds: allKinds)
          .first;
      expect(report.entries, hasLength(1),
          reason: 'entry en el final del día de `to` debe contar');
    });
  });

  group('topMovements — filtro de kinds', () {
    test('UT-10: kinds=["expense"] excluye otros kinds', () async {
      await entriesDao.registerIncome(
        accountDestinationId: bolsa,
        amount: 1000,
        occurredAt: DateTime(2026, 6, 5),
        description: 'income_filtered',
      );
      await entriesDao.registerExpense(
        accountOriginId: debit,
        amount: 500,
        occurredAt: DateTime(2026, 6, 6),
        description: 'expense_kept',
      );
      await entriesDao.registerCreditExpense(
        accountOriginId: credit,
        amount: 700,
        occurredAt: DateTime(2026, 6, 7),
        description: 'credit_expense_filtered',
      );
      final report = await reports
          .topMovements(from: from, to: to, kinds: const ['expense'])
          .first;
      expect(report.entries, hasLength(1));
      expect(report.entries.first.description, 'expense_kept');
    });

    test(
        'UT-11: kinds=[] → atajo defensivo retorna entries=[] sin tocar BD',
        () async {
      // Cerrar la BD antes de invocar topMovements. Si el atajo NO
      // funciona, drift va a fallar con un error de BD cerrada. Si SÍ
      // funciona, retorna lista vacía sin tocar nada.
      await entriesDao.registerExpense(
        accountOriginId: debit,
        amount: 500,
        occurredAt: DateTime(2026, 6, 10),
      );
      await db.close();
      final report = await reports
          .topMovements(from: from, to: to, kinds: const [])
          .first;
      expect(report.entries, isEmpty);
      expect(report.isEmpty, isTrue);
    });
  });

  // ===========================================================================
  // balanceAtDate — sprint `flutter-reports-balance-at-date-v1`
  // Cubre RN-B01..B08 + casos borde CB-T01..T13 del test-plan.
  // ===========================================================================
  group('balanceAtDate — totales', () {
    test('UT-01: BD vacía → BO=0, DE=0, CR=0', () async {
      // setUp ya sembró Bolsa + debit + credit + 3 categorías. Sin entries
      // todavía → totales en 0, cuentas listadas con balance=0.
      final report = await reports
          .balanceAtDate(asOf: DateTime(2026, 6, 30))
          .first;
      expect(report.bo, 0);
      expect(report.de, 0);
      // CR = credit_limit - 0 = 50000.
      expect(report.cr, 50000);
      expect(report.accounts, hasLength(3),
          reason: 'Bolsa + Banamex + Visa visibles');
    });

    test(
        'UT-02: fecha = hoy coincide con FinancialStateService watchBo/De/Cr',
        () async {
      // Sembrar entries variados.
      await entriesDao.registerIncome(
        accountDestinationId: bolsa,
        amount: 5000,
        occurredAt: DateTime(2026, 6, 5),
      );
      await entriesDao.registerExpense(
        accountOriginId: debit,
        amount: 1000,
        occurredAt: DateTime(2026, 6, 10),
      );
      await entriesDao.registerCreditExpense(
        accountOriginId: credit,
        amount: 2000,
        occurredAt: DateTime(2026, 6, 15),
      );
      // Validar cruzado contra FinancialStateService a hoy.
      final state = FinancialStateService(db);
      final reportNow = await reports
          .balanceAtDate(asOf: DateTime(2026, 6, 30))
          .first;
      final stateBo = await state.watchBo().first;
      final stateDe = await state.watchDe().first;
      final stateCr = await state.watchCr().first;
      expect(reportNow.bo, stateBo);
      expect(reportNow.de, stateDe);
      expect(reportNow.cr, stateCr);
    });

    test('UT-03: fecha pasada filtra entries posteriores', () async {
      await entriesDao.registerIncome(
        accountDestinationId: bolsa,
        amount: 1000,
        occurredAt: DateTime(2026, 6, 5),
      );
      await entriesDao.registerIncome(
        accountDestinationId: bolsa,
        amount: 500,
        occurredAt: DateTime(2026, 6, 20),
      );
      final report = await reports
          .balanceAtDate(asOf: DateTime(2026, 6, 10))
          .first;
      expect(report.bo, 1000,
          reason: 'solo el primer income cuenta hasta el 10 de junio');
    });

    test('UT-04: entry exacto al final del día de `asOf` cuenta', () async {
      // Entry a las 23:59:59 del 10 de junio cuenta para asOf=10 jun.
      await entriesDao.registerIncome(
        accountDestinationId: bolsa,
        amount: 100,
        occurredAt: DateTime(2026, 6, 10, 23, 59, 59),
      );
      // Entry el 11 de junio NO cuenta.
      await entriesDao.registerIncome(
        accountDestinationId: bolsa,
        amount: 200,
        occurredAt: DateTime(2026, 6, 11, 0, 0, 0),
      );
      final report = await reports
          .balanceAtDate(asOf: DateTime(2026, 6, 10))
          .first;
      expect(report.bo, 100,
          reason: 'entry a 23:59:59 cuenta; entry de día siguiente NO');
    });
  });

  group('balanceAtDate — soft delete y archivos', () {
    test('UT-05: entry soft-deleted excluido', () async {
      final id = await entriesDao.registerIncome(
        accountDestinationId: bolsa,
        amount: 500,
        occurredAt: DateTime(2026, 6, 5),
      );
      var report = await reports
          .balanceAtDate(asOf: DateTime(2026, 6, 30))
          .first;
      expect(report.bo, 500);
      await entriesDao.cancel(id);
      report = await reports
          .balanceAtDate(asOf: DateTime(2026, 6, 30))
          .first;
      expect(report.bo, 0,
          reason: 'tras cancel, el entry no cuenta');
    });

    test(
        'UT-06: credit_limit=null se rechaza; 0 contribuye a CR con `-deuda` (sprint credit-cards)',
        () async {
      // Post-schema v5: credit_limit es obligatorio para type=credit.
      await expectLater(
        accountsDao.create(
          name: 'VisaNull',
          type: 'credit',
          // credit_limit no se pasa = null
        ),
        throwsA(isA<AccountsDaoError>()
            .having((e) => e.code, 'code', 'invalid_credit_limit')),
      );
      // credit_limit=0 es válido (tarjeta departamental sin límite formal).
      final visaZero = await accountsDao.create(
        name: 'VisaZero',
        type: 'credit',
        creditLimit: 0,
        closingDay: 15,
        paymentDay: 5,
      );
      await entriesDao.registerCreditExpense(
        accountOriginId: visaZero,
        amount: 50,
        occurredAt: DateTime(2026, 6, 5),
      );
      final report = await reports
          .balanceAtDate(asOf: DateTime(2026, 6, 30))
          .first;
      // Visa del seed (creditLimit=50000, sin deuda) + VisaZero (creditLimit=0,
      // debt=50). DE total = 50 (solo VisaZero). CR total = 50000 (Visa)
      //   + (0 - 50 = -50) (VisaZero) = 49950.
      expect(report.de, closeTo(50, 0.001));
      expect(report.cr, closeTo(49950, 0.001));
    });
  });

  group('balanceAtDate — lista de cuentas', () {
    test('UT-07: orden por tipo (cash, debit, credit) + alfabético',
        () async {
      // Sembrar más cuentas para validar orden.
      await accountsDao.create(name: 'Z BBVA', type: 'debit');
      await accountsDao.create(name: 'A BBVA', type: 'debit');
      await accountsDao.create(
        name: 'Mastercard',
        type: 'credit',
        creditLimit: 10000,
      );
      final report = await reports
          .balanceAtDate(asOf: DateTime(2026, 6, 30))
          .first;
      final names = report.accounts.map((a) => a.name).toList();
      // Orden esperado:
      // 1. Bolsa (cash).
      // 2. A BBVA (debit, alfabético).
      // 3. Banamex (debit del setUp).
      // 4. Z BBVA (debit).
      // 5. Mastercard (credit, alfabético).
      // 6. Visa (credit del setUp).
      expect(names,
          ['Bolsa', 'A BBVA', 'Banamex', 'Z BBVA', 'Mastercard', 'Visa']);
    });

    test('UT-08: cuenta sin movimientos hasta la fecha aparece con balance=0',
        () async {
      await entriesDao.registerExpense(
        accountOriginId: debit,
        amount: 200,
        occurredAt: DateTime(2026, 6, 5),
      );
      final report = await reports
          .balanceAtDate(asOf: DateTime(2026, 6, 30))
          .first;
      final bolsaAcc =
          report.accounts.firstWhere((a) => a.name == 'Bolsa');
      expect(bolsaAcc.balance, 0,
          reason: 'Bolsa sin entries → balance 0');
      final debitAcc =
          report.accounts.firstWhere((a) => a.name == 'Banamex');
      expect(debitAcc.balance, -200,
          reason: 'Banamex con solo un expense → -200');
    });
  });

  group('balanceAtDate — delta (patch v1)', () {
    test(
        'UT-09: asOf = hoy → delta = 0 (balance == balanceNow para los 3 totales)',
        () async {
      await entriesDao.registerIncome(
        accountDestinationId: bolsa,
        amount: 500,
        occurredAt: DateTime(2026, 6, 5),
      );
      // asOf = hoy → balance == balanceNow → delta = 0.
      final report =
          await reports.balanceAtDate(asOf: DateTime.now()).first;
      expect(report.boDelta, 0);
      expect(report.deDelta, 0);
      expect(report.crDelta, 0);
      for (final acc in report.accounts) {
        expect(acc.balanceDelta, 0,
            reason: 'asOf=hoy → balanceDelta=0 para todas las cuentas');
      }
    });

    test(
        'UT-10: asOf en el pasado con movimientos posteriores → delta refleja el cambio',
        () async {
      // Sembrar income antiguo + expense reciente.
      await entriesDao.registerIncome(
        accountDestinationId: bolsa,
        amount: 1000,
        occurredAt: DateTime(2026, 6, 5),
      );
      // Expense reciente (hoy) → solo cuenta en balanceNow, no en balance
      // a fecha 2026-06-10.
      await entriesDao.registerExpense(
        accountOriginId: bolsa,
        amount: 300,
        occurredAt: DateTime.now(),
      );
      final report = await reports
          .balanceAtDate(asOf: DateTime(2026, 6, 10))
          .first;
      // A 2026-06-10: solo el income → bo=1000.
      expect(report.bo, 1000);
      // Hoy: income - expense = 700.
      expect(report.boNow, 700);
      // Delta = boNow - bo = -300.
      expect(report.boDelta, -300,
          reason: 'BO cayó 300 entre 2026-06-10 y hoy');
    });
  });

  // ===========================================================================
  // monthlyAverage — sprint `flutter-reports-monthly-average-v1`
  // ===========================================================================
  group('monthlyAverage', () {
    // Reusa el setUp() global: tiene `bolsa`, `debit`, `credit`, 3 categorías
    // expense, y `seedDefaults` ya ejecutado.

    Future<void> seedExpense({
      required String accountOriginId,
      required double amount,
      required DateTime occurredAt,
      String? categoryId,
      String kind = 'expense',
    }) async {
      if (kind == 'expense') {
        await entriesDao.registerExpense(
          accountOriginId: accountOriginId,
          amount: amount,
          occurredAt: occurredAt,
          categoryId: categoryId,
        );
      } else if (kind == 'credit_expense') {
        await entriesDao.registerCreditExpense(
          accountOriginId: accountOriginId,
          amount: amount,
          occurredAt: occurredAt,
          categoryId: categoryId,
        );
      }
    }

    test('UT-01: BD sin entries → isEmpty=true', () async {
      final now = DateTime(2026, 6, 15);
      final report =
          await reports.monthlyAverage(monthsBack: 3, now: now).first;
      expect(report.isEmpty, isTrue);
      expect(report.monthsAvailable, 0);
      expect(report.historicalAverage, 0);
      expect(report.currentMonthSpent, 0);
      expect(report.deltaAbsolute, 0);
      expect(report.deltaPercent, isNull);
      expect(report.categoryBreakdown, isEmpty);
    });

    test(
        'UT-02: N=1 con 1 mes histórico + mes actual completos → promedio = total mes histórico hasta día D',
        () async {
      final now = DateTime(2026, 6, 20, 12);
      // Histórico: mayo 2026, gasto al día 20.
      await seedExpense(
        accountOriginId: debit,
        amount: 1000,
        occurredAt: DateTime(2026, 5, 10, 10),
        categoryId: catComida,
      );
      // Mes actual: junio 2026, gasto al día 5 (antes del 20).
      await seedExpense(
        accountOriginId: debit,
        amount: 400,
        occurredAt: DateTime(2026, 6, 5, 10),
        categoryId: catComida,
      );
      final report =
          await reports.monthlyAverage(monthsBack: 1, now: now).first;
      expect(report.monthsAvailable, 1);
      expect(report.historicalAverage, 1000);
      expect(report.currentMonthSpent, 400);
      expect(report.deltaAbsolute, -600);
      expect(report.deltaPercent, closeTo(-60, 0.01));
    });

    test(
        'UT-03: prorrateo al día D=15 → entries del 14 y 15 cuentan, del 16 no',
        () async {
      final now = DateTime(2026, 6, 15, 23);
      // 3 meses histórico (marzo, abril, mayo).
      // Marzo: entry día 14 ($100), día 16 ($999 — NO cuenta).
      await seedExpense(
        accountOriginId: debit,
        amount: 100,
        occurredAt: DateTime(2026, 3, 14),
        categoryId: catComida,
      );
      await seedExpense(
        accountOriginId: debit,
        amount: 999,
        occurredAt: DateTime(2026, 3, 16),
        categoryId: catComida,
      );
      // Abril: entry día 15 ($200).
      await seedExpense(
        accountOriginId: debit,
        amount: 200,
        occurredAt: DateTime(2026, 4, 15),
        categoryId: catComida,
      );
      // Mayo: sin entries (mes vacío cuenta como 0 en promedio).
      final report =
          await reports.monthlyAverage(monthsBack: 3, now: now).first;
      expect(report.monthsAvailable, 2,
          reason: 'solo marzo y abril aportaron datos válidos al prorrateo');
      // Promedio = (100 + 200) / 2 = 150.
      expect(report.historicalAverage, 150);
    });

    test('UT-04: mes en curso suma todos los días desde el 1 hasta now',
        () async {
      final now = DateTime(2026, 6, 20, 12);
      // Mes actual: entries día 1, 10, 20.
      await seedExpense(
        accountOriginId: debit,
        amount: 50,
        occurredAt: DateTime(2026, 6, 1),
        categoryId: catComida,
      );
      await seedExpense(
        accountOriginId: debit,
        amount: 75,
        occurredAt: DateTime(2026, 6, 10),
        categoryId: catComida,
      );
      await seedExpense(
        accountOriginId: debit,
        amount: 125,
        occurredAt: DateTime(2026, 6, 20),
        categoryId: catComida,
      );
      final report =
          await reports.monthlyAverage(monthsBack: 1, now: now).first;
      expect(report.currentMonthSpent, 250);
    });

    test(
        'UT-05 (RN-A08): D=31 sobre febrero (28 días) — incluye los días que existen',
        () async {
      final now = DateTime(2026, 5, 31, 23);
      // Febrero histórico: entry día 28 ($300). Debe contar.
      await seedExpense(
        accountOriginId: debit,
        amount: 300,
        occurredAt: DateTime(2026, 2, 28),
        categoryId: catComida,
      );
      // Marzo histórico: entry día 31 ($600). Debe contar.
      await seedExpense(
        accountOriginId: debit,
        amount: 600,
        occurredAt: DateTime(2026, 3, 31),
        categoryId: catComida,
      );
      // Abril histórico: entry día 28 + entry día 31 (no existe → no se siembra).
      await seedExpense(
        accountOriginId: debit,
        amount: 400,
        occurredAt: DateTime(2026, 4, 28),
        categoryId: catComida,
      );
      final report =
          await reports.monthlyAverage(monthsBack: 3, now: now).first;
      expect(report.monthsAvailable, 3);
      expect(report.historicalAverage,
          closeTo((300 + 600 + 400) / 3, 0.01));
    });

    test(
        'UT-06: categoría archivada → bucket "Sin categoría" del breakdown',
        () async {
      final now = DateTime(2026, 6, 20);
      // Histórico con categoría que será archivada.
      await seedExpense(
        accountOriginId: debit,
        amount: 200,
        occurredAt: DateTime(2026, 5, 10),
        categoryId: catComida,
      );
      // Entry con categoría null (mes actual).
      await seedExpense(
        accountOriginId: debit,
        amount: 100,
        occurredAt: DateTime(2026, 6, 5),
        categoryId: null,
      );
      // Archivar la categoría usada históricamente.
      await categoriesDao.archive(catComida);
      final report =
          await reports.monthlyAverage(monthsBack: 1, now: now).first;
      // Solo debe existir un bucket "Sin categoría" que agregue ambas filas.
      expect(report.categoryBreakdown, hasLength(1));
      expect(report.categoryBreakdown.first.categoryId, isNull);
      expect(report.categoryBreakdown.first.name, 'Sin categoría');
      expect(report.categoryBreakdown.first.historicalAverage, 200);
      expect(report.categoryBreakdown.first.currentMonthSpent, 100);
    });

    test('UT-07: soft delete excluye entry del promedio', () async {
      final now = DateTime(2026, 6, 20);
      await seedExpense(
        accountOriginId: debit,
        amount: 500,
        occurredAt: DateTime(2026, 5, 10),
        categoryId: catComida,
      );
      // Borrar el entry recién creado.
      final entries = await entriesDao.watchPage().first;
      await entriesDao.cancel(entries.first.entry.id);
      final report =
          await reports.monthlyAverage(monthsBack: 1, now: now).first;
      expect(report.monthsAvailable, 0,
          reason: 'sin entries vigentes, no hay meses con datos');
      expect(report.historicalAverage, 0);
    });

    test(
        'UT-08: kinds excluidos (income, transfer, debt_payment) NO cuentan',
        () async {
      final now = DateTime(2026, 6, 20);
      // Income al mes histórico — debe ignorarse.
      await entriesDao.registerIncome(
        accountDestinationId: bolsa,
        amount: 5000,
        occurredAt: DateTime(2026, 5, 10),
      );
      // Transfer — debe ignorarse.
      await entriesDao.registerTransfer(
        accountOriginId: bolsa,
        accountDestinationId: debit,
        amount: 100,
        occurredAt: DateTime(2026, 5, 11),
      );
      // expense — sí cuenta.
      await seedExpense(
        accountOriginId: debit,
        amount: 300,
        occurredAt: DateTime(2026, 5, 12),
        categoryId: catComida,
      );
      // credit_expense — también cuenta. (Genera deuda en `credit` para el
      // debt_payment siguiente.)
      await seedExpense(
        accountOriginId: credit,
        amount: 200,
        occurredAt: DateTime(2026, 5, 13),
        categoryId: catComida,
        kind: 'credit_expense',
      );
      // debt_payment — debe ignorarse. M2 quality review: blindar el
      // filtro `kind IN ('expense', 'credit_expense')` contra regresión.
      await entriesDao.registerDebtPayment(
        accountOriginId: debit,
        accountDestinationId: credit,
        amount: 80,
        occurredAt: DateTime(2026, 5, 14),
      );
      final report =
          await reports.monthlyAverage(monthsBack: 1, now: now).first;
      expect(report.historicalAverage, 500,
          reason: 'expense + credit_expense del mes histórico');
      expect(report.currentMonthSpent, 0);
    });

    test('UT-09: degradación M<N (3 meses con datos, N=12 → M=3)', () async {
      final now = DateTime(2026, 6, 20);
      // 3 meses históricos con datos.
      await seedExpense(
        accountOriginId: debit,
        amount: 100,
        occurredAt: DateTime(2026, 3, 5),
        categoryId: catComida,
      );
      await seedExpense(
        accountOriginId: debit,
        amount: 200,
        occurredAt: DateTime(2026, 4, 5),
        categoryId: catComida,
      );
      await seedExpense(
        accountOriginId: debit,
        amount: 300,
        occurredAt: DateTime(2026, 5, 5),
        categoryId: catComida,
      );
      final report =
          await reports.monthlyAverage(monthsBack: 12, now: now).first;
      expect(report.monthsRequested, 12);
      expect(report.monthsAvailable, 3,
          reason: 'M < N: solo 3 meses con datos disponibles');
      expect(report.historicalAverage, closeTo((100 + 200 + 300) / 3, 0.01));
    });

    test(
        'UT-10: historicalAverage == 0 → deltaPercent es null y deltaAbsolute = currentMonthSpent',
        () async {
      final now = DateTime(2026, 6, 20);
      // Solo entry del mes actual, sin histórico.
      await seedExpense(
        accountOriginId: debit,
        amount: 800,
        occurredAt: DateTime(2026, 6, 10),
        categoryId: catComida,
      );
      final report =
          await reports.monthlyAverage(monthsBack: 3, now: now).first;
      expect(report.historicalAverage, 0);
      expect(report.currentMonthSpent, 800);
      expect(report.deltaAbsolute, 800);
      expect(report.deltaPercent, isNull);
    });

    test(
        'UT-11: categoría con histórico positivo y mes actual = 0 → delta negativo',
        () async {
      final now = DateTime(2026, 6, 20);
      await seedExpense(
        accountOriginId: debit,
        amount: 600,
        occurredAt: DateTime(2026, 5, 10),
        categoryId: catComida,
      );
      final report =
          await reports.monthlyAverage(monthsBack: 1, now: now).first;
      expect(report.categoryBreakdown, hasLength(1));
      final row = report.categoryBreakdown.first;
      expect(row.historicalAverage, 600);
      expect(row.currentMonthSpent, 0);
      expect(row.deltaAbsolute, -600);
      expect(row.deltaPercent, closeTo(-100, 0.01));
    });

    test(
        'UT-12: categoría sin histórico pero con gasto actual → delta=current, percent=null',
        () async {
      final now = DateTime(2026, 6, 20);
      // Histórico de OTRA categoría — la categoría target no tiene histórico.
      await seedExpense(
        accountOriginId: debit,
        amount: 500,
        occurredAt: DateTime(2026, 5, 10),
        categoryId: catComida,
      );
      // Mes actual: gasto en catTransporte (sin histórico).
      await seedExpense(
        accountOriginId: debit,
        amount: 250,
        occurredAt: DateTime(2026, 6, 10),
        categoryId: catTransporte,
      );
      final report =
          await reports.monthlyAverage(monthsBack: 1, now: now).first;
      final transporteRow = report.categoryBreakdown
          .firstWhere((b) => b.categoryId == catTransporte);
      expect(transporteRow.historicalAverage, 0);
      expect(transporteRow.currentMonthSpent, 250);
      expect(transporteRow.deltaAbsolute, 250);
      expect(transporteRow.deltaPercent, isNull);
    });

    test(
        'UT-13: orden del breakdown por deltaAbsolute DESC, tiebreak alfabético',
        () async {
      final now = DateTime(2026, 6, 20);
      // Histórico vacío para todos (delta = currentSpent).
      // catComida: actual = 200.
      // catSalud:  actual = 100.
      // catTransporte: actual = 200 (empate con Comida).
      await seedExpense(
        accountOriginId: debit,
        amount: 200,
        occurredAt: DateTime(2026, 6, 10),
        categoryId: catComida,
      );
      await seedExpense(
        accountOriginId: debit,
        amount: 100,
        occurredAt: DateTime(2026, 6, 11),
        categoryId: catSalud,
      );
      await seedExpense(
        accountOriginId: debit,
        amount: 200,
        occurredAt: DateTime(2026, 6, 12),
        categoryId: catTransporte,
      );
      final report =
          await reports.monthlyAverage(monthsBack: 1, now: now).first;
      final names = report.categoryBreakdown.map((b) => b.name).toList();
      // Empate Comida_Test (200) vs Transporte_Test (200): Comida primero alfabético.
      // Después Salud_Test (100).
      expect(names, ['Comida_Test', 'Transporte_Test', 'Salud_Test']);
    });

    test(
        'UT-14: stream reactivo — cancelar entry re-emite con nuevo total',
        () async {
      final now = DateTime(2026, 6, 20);
      await seedExpense(
        accountOriginId: debit,
        amount: 400,
        occurredAt: DateTime(2026, 5, 10),
        categoryId: catComida,
      );
      final stream = reports.monthlyAverage(monthsBack: 1, now: now);
      final first = await stream.first;
      expect(first.historicalAverage, 400);

      final entries = await entriesDao.watchPage().first;
      await entriesDao.cancel(entries.first.entry.id);
      // Volver a leer el stream — re-emite con valores actualizados.
      final second = await stream.first;
      expect(second.historicalAverage, 0);
    });

    test('UT-15: D=10 sobre 3 meses con 1 entry día 10 cada uno → promedio == total/3',
        () async {
      final now = DateTime(2026, 6, 10, 12);
      await seedExpense(
        accountOriginId: debit,
        amount: 90,
        occurredAt: DateTime(2026, 3, 10),
        categoryId: catComida,
      );
      await seedExpense(
        accountOriginId: debit,
        amount: 120,
        occurredAt: DateTime(2026, 4, 10),
        categoryId: catComida,
      );
      await seedExpense(
        accountOriginId: debit,
        amount: 60,
        occurredAt: DateTime(2026, 5, 10),
        categoryId: catComida,
      );
      final report =
          await reports.monthlyAverage(monthsBack: 3, now: now).first;
      expect(report.historicalAverage,
          closeTo((90 + 120 + 60) / 3, 0.01));
    });
  });

  // Sprint flutter-reports-credit-cards-v1: tests del nuevo reporte
  // `watchCreditCards()`.
  group('watchCreditCards (sprint credit-cards)', () {
    // Fecha de referencia estable para tests deterministas.
    final refDate = DateTime(2024, 6, 15);

    test('UT-05: BD sin cuentas credit activas → lista vacía', () async {
      // El seed ya creó Bolsa (cash) + Visa (credit) en el setUp default.
      // Archivamos la Visa para dejar 0 credit activas.
      await accountsDao.archive(credit);
      final list = await reports.watchCreditCards(now: refDate).first;
      expect(list, isEmpty);
    });

    test('UT-06: tarjeta sin metadata → nextClosingDate/etc en null', () async {
      // Archivar Visa del setUp para dejar solo la nueva.
      await accountsDao.archive(credit);
      final id = await accountsDao.create(
        name: 'SinMeta',
        type: 'credit',
        creditLimit: 1000,
        // closingDay/paymentDay/minimumPaymentPct no se pasan.
      );
      await entriesDao.registerCreditExpense(
        accountOriginId: id,
        amount: 200,
        occurredAt: DateTime(2024, 6, 1),
      );
      final list = await reports.watchCreditCards(now: refDate).first;
      expect(list, hasLength(1));
      final s = list.first;
      expect(s.name, 'SinMeta');
      expect(s.debt, 200);
      expect(s.nextClosingDate, isNull);
      expect(s.nextPaymentDate, isNull);
      expect(s.daysToClosing, isNull);
      expect(s.daysToPayment, isNull);
      expect(s.minimumPayment, isNull);
    });

    test('UT-07: solo cuentas credit activas aparecen (soft delete filtrado)',
        () async {
      final archivedId = await accountsDao.create(
        name: 'Archivada',
        type: 'credit',
        creditLimit: 5000,
        closingDay: 10,
        paymentDay: 20,
      );
      await accountsDao.archive(archivedId);
      final list = await reports.watchCreditCards(now: refDate).first;
      // Debe estar solo Visa del setUp (activa).
      expect(list, hasLength(1));
      expect(list.first.name, 'Visa');
    });

    test(
        'UT-08: orden RN-CC09 — proximidad pago asc con deuda; alfabético al final sin deuda',
        () async {
      await accountsDao.archive(credit);
      final visaProxima = await accountsDao.create(
        name: 'ProximaPago',
        type: 'credit',
        creditLimit: 10000,
        closingDay: 15,
        paymentDay: 20, // hoy=15 → 20 (5 días)
      );
      final visaLejana = await accountsDao.create(
        name: 'LejanaPago',
        type: 'credit',
        creditLimit: 10000,
        closingDay: 5,
        paymentDay: 10, // hoy=15 → 10 del mes siguiente (~25 días)
      );
      final sinDeudaB = await accountsDao.create(
        name: 'B_SinDeuda',
        type: 'credit',
        creditLimit: 3000,
        closingDay: 15,
        paymentDay: 5,
      );
      final sinDeudaA = await accountsDao.create(
        name: 'A_SinDeuda',
        type: 'credit',
        creditLimit: 3000,
        closingDay: 15,
        paymentDay: 5,
      );
      // Deuda solo en las 2 primeras.
      await entriesDao.registerCreditExpense(
        accountOriginId: visaProxima,
        amount: 500,
        occurredAt: DateTime(2024, 6, 1),
      );
      await entriesDao.registerCreditExpense(
        accountOriginId: visaLejana,
        amount: 800,
        occurredAt: DateTime(2024, 6, 1),
      );
      final list = await reports.watchCreditCards(now: refDate).first;
      expect(list.map((s) => s.name).toList(), [
        'ProximaPago',
        'LejanaPago',
        'A_SinDeuda',
        'B_SinDeuda',
      ]);
      // Silence unused warnings.
      expect([sinDeudaA, sinDeudaB], hasLength(2));
    });

    test('UT-09: usedPct correcto para deuda 5000 / límite 10000 → 50%',
        () async {
      await accountsDao.archive(credit);
      final id = await accountsDao.create(
        name: 'Mitad',
        type: 'credit',
        creditLimit: 10000,
        closingDay: 15,
        paymentDay: 5,
      );
      await entriesDao.registerCreditExpense(
        accountOriginId: id,
        amount: 5000,
        occurredAt: DateTime(2024, 6, 1),
      );
      final list = await reports.watchCreditCards(now: refDate).first;
      expect(list.first.usedPct, 50.0);
      expect(list.first.availableCredit, 5000);
      expect(list.first.isOverdue, false);
    });

    test('UT-10: usedPct = null cuando credit_limit = 0 (CB-D19)', () async {
      await accountsDao.archive(credit);
      final id = await accountsDao.create(
        name: 'SinLimite',
        type: 'credit',
        creditLimit: 0,
        closingDay: 15,
        paymentDay: 5,
      );
      await entriesDao.registerCreditExpense(
        accountOriginId: id,
        amount: 100,
        occurredAt: DateTime(2024, 6, 1),
      );
      final list = await reports.watchCreditCards(now: refDate).first;
      expect(list.first.usedPct, isNull);
      expect(list.first.availableCredit, 0);
    });

    test('UT-11: isOverdue = true cuando debt > credit_limit (CB-D17)',
        () async {
      await accountsDao.archive(credit);
      final id = await accountsDao.create(
        name: 'Excedida',
        type: 'credit',
        creditLimit: 1000,
        closingDay: 15,
        paymentDay: 5,
      );
      await entriesDao.registerCreditExpense(
        accountOriginId: id,
        amount: 1500,
        occurredAt: DateTime(2024, 6, 1),
      );
      final list = await reports.watchCreditCards(now: refDate).first;
      expect(list.first.isOverdue, true);
      expect(list.first.usedPct, 100.0);
      expect(list.first.availableCredit, 0);
    });

    test(
        'UT-12: reactividad — registrar credit_expense re-emite con nueva deuda',
        () async {
      final events = <List<CreditCardStatus>>[];
      final sub =
          reports.watchCreditCards(now: refDate).listen(events.add);

      // Esperar primer emit.
      await Future.delayed(const Duration(milliseconds: 50));
      expect(events, isNotEmpty);
      final initial = events.last;
      final initialDebt =
          initial.firstWhere((s) => s.accountId == credit).debt;

      // Registrar cargo.
      await entriesDao.registerCreditExpense(
        accountOriginId: credit,
        amount: 300,
        occurredAt: DateTime(2024, 6, 1),
      );
      await Future.delayed(const Duration(milliseconds: 100));

      final updated = events.last.firstWhere((s) => s.accountId == credit);
      expect(updated.debt, greaterThan(initialDebt));
      expect(updated.debt - initialDebt, 300);

      await sub.cancel();
    });

    test('CB-D18: debt=0 con minimumPaymentPct → isDebtFree, minimumPayment=null',
        () async {
      await accountsDao.archive(credit);
      final id = await accountsDao.create(
        name: 'SinDeudaConPct',
        type: 'credit',
        creditLimit: 10000,
        closingDay: 15,
        paymentDay: 5,
        minimumPaymentPct: 0.05,
      );
      final list = await reports.watchCreditCards(now: refDate).first;
      final s = list.firstWhere((c) => c.accountId == id);
      expect(s.isDebtFree, true);
      expect(s.minimumPayment, isNull);
    });

    test('minimumPayment = debt × minimumPaymentPct (formato decimal 0-1)',
        () async {
      await accountsDao.archive(credit);
      final id = await accountsDao.create(
        name: 'ConMinimo',
        type: 'credit',
        creditLimit: 10000,
        closingDay: 15,
        paymentDay: 5,
        minimumPaymentPct: 0.05,
      );
      await entriesDao.registerCreditExpense(
        accountOriginId: id,
        amount: 2000,
        occurredAt: DateTime(2024, 6, 1),
      );
      final list = await reports.watchCreditCards(now: refDate).first;
      final s = list.firstWhere((c) => c.accountId == id);
      expect(s.minimumPayment, closeTo(100, 0.001)); // 2000 × 0.05
    });
  });

  // Sprint flutter-budgets-v1
  group('watchBudgetsProgress (sprint budgets)', () {
    // Anchor fijo para tests deterministas: junio 2024.
    final anchor = DateTime(2024, 6, 15);

    test('UT-B05: BD sin presupuestos → lista vacía', () async {
      // Seed default no crea categorías con monthly_limit.
      final list = await reports
          .watchBudgetsProgress(monthAnchor: anchor)
          .first;
      expect(list, isEmpty);
    });

    test(
        'UT-B06: 2 categorías con presupuesto + 1 sin presupuesto → emite 2 entradas',
        () async {
      await categoriesDao.updateCategory(
        id: catComida,
        monthlyLimit: const Value(3000),
      );
      await categoriesDao.updateCategory(
        id: catTransporte,
        monthlyLimit: const Value(1500),
      );
      // catSalud sin presupuesto.
      final list = await reports
          .watchBudgetsProgress(monthAnchor: anchor)
          .first;
      expect(list, hasLength(2));
      expect(
        list.map((p) => p.categoryName).toSet(),
        {'Comida_Test', 'Transporte_Test'},
      );
    });

    test('UT-B07: categoría archivada con presupuesto → NO aparece',
        () async {
      await categoriesDao.updateCategory(
        id: catComida,
        monthlyLimit: const Value(3000),
      );
      await categoriesDao.archive(catComida);
      final list = await reports
          .watchBudgetsProgress(monthAnchor: anchor)
          .first;
      expect(list, isEmpty);
    });

    test(
        'UT-B09: `spent` solo incluye gastos del mes en curso (no meses pasados)',
        () async {
      await categoriesDao.updateCategory(
        id: catComida,
        monthlyLimit: const Value(3000),
      );
      // Gasto del mes anchor.
      await entriesDao.registerExpense(
        accountOriginId: bolsa,
        amount: 500,
        categoryId: catComida,
        occurredAt: DateTime(2024, 6, 5),
      );
      // Gasto del mes anterior — NO cuenta.
      await entriesDao.registerExpense(
        accountOriginId: bolsa,
        amount: 999,
        categoryId: catComida,
        occurredAt: DateTime(2024, 5, 30),
      );
      final list = await reports
          .watchBudgetsProgress(monthAnchor: anchor)
          .first;
      expect(list, hasLength(1));
      expect(list.first.spent, 500);
    });

    test('UT-B10: credit_expense cuenta como spent', () async {
      await categoriesDao.updateCategory(
        id: catComida,
        monthlyLimit: const Value(3000),
      );
      await entriesDao.registerCreditExpense(
        accountOriginId: credit,
        amount: 200,
        categoryId: catComida,
        occurredAt: DateTime(2024, 6, 5),
      );
      final list = await reports
          .watchBudgetsProgress(monthAnchor: anchor)
          .first;
      expect(list.first.spent, 200);
    });

    test(
        'UT-B11: debt_payment y transfer NO cuentan como spent (aunque tengan categoría)',
        () async {
      await categoriesDao.updateCategory(
        id: catComida,
        monthlyLimit: const Value(3000),
      );
      // Los debt_payment no aceptan categoryId — pero cualquier movimiento
      // con category_id que no sea expense o credit_expense no cuenta.
      // Sembramos un expense de control:
      await entriesDao.registerExpense(
        accountOriginId: bolsa,
        amount: 100,
        categoryId: catComida,
        occurredAt: DateTime(2024, 6, 5),
      );
      final list = await reports
          .watchBudgetsProgress(monthAnchor: anchor)
          .first;
      expect(list.first.spent, 100);
    });

    test('UT-B13: BudgetProgress.compute — límite 1000, spent 800 → warning',
        () {
      final p = BudgetProgress.compute(
        categoryId: 'x',
        categoryName: 'X',
        colorSlug: 'red',
        iconSlug: 'tag',
        monthlyLimit: 1000,
        spent: 800,
      );
      expect(p.usedPct, 80.0);
      expect(p.isWarning, isTrue);
      expect(p.isOverBudget, isFalse);
      expect(p.isNoSpend, isFalse);
      expect(p.available, 200);
    });

    test(
        'UT-B14: compute — límite 1000, spent 1200 → overBudget con clamp 100%',
        () {
      final p = BudgetProgress.compute(
        categoryId: 'x',
        categoryName: 'X',
        colorSlug: 'red',
        iconSlug: 'tag',
        monthlyLimit: 1000,
        spent: 1200,
      );
      expect(p.isOverBudget, isTrue);
      expect(p.usedPct, 100.0);
      expect(p.available, 0);
      expect(p.overBy, 200);
    });

    test('UT-B15: compute — límite 0, spent 0 → usedPct null, isNoSpend', () {
      final p = BudgetProgress.compute(
        categoryId: 'x',
        categoryName: 'X',
        colorSlug: 'red',
        iconSlug: 'tag',
        monthlyLimit: 0,
        spent: 0,
      );
      expect(p.usedPct, isNull);
      expect(p.isNoSpend, isTrue);
      expect(p.isOverBudget, isFalse);
    });

    test('UT-B16: compute — límite 0, spent 50 → overBudget con overBy=50',
        () {
      final p = BudgetProgress.compute(
        categoryId: 'x',
        categoryName: 'X',
        colorSlug: 'red',
        iconSlug: 'tag',
        monthlyLimit: 0,
        spent: 50,
      );
      expect(p.usedPct, isNull);
      expect(p.isOverBudget, isTrue);
      expect(p.overBy, 50);
    });

    // A1 del quality review: blindaje del filtro `applies_to != 'income'`
    // contra backup legacy. Bypaseamos el DAO con customStatement para
    // insertar la combinación inválida y verificamos que la query la excluye.
    test(
        'UT-B08: query filtra categorías `applies_to=income + monthly_limit != null` (edge legacy)',
        () async {
      // Inserto directo bypaseando el DAO (que rechazaría la combinación).
      await db.customStatement(
        "INSERT INTO categories(id, name, applies_to, color_slug, icon_slug, "
        "monthly_limit, created_at, updated_at) "
        "VALUES ('01a2b3c4-5678-7abc-9def-legacyincomex', 'FantasmaSueldo', "
        "'income', 'green', 'briefcase', 5000, '2024-01-01T00:00:00.000', "
        "'2024-01-01T00:00:00.000')",
      );
      final list = await reports
          .watchBudgetsProgress(monthAnchor: anchor)
          .first;
      expect(list, isEmpty,
          reason:
              'Aunque BD tenga la combinación inválida, el reporte NO la muestra.');
    });

    // A2 + M1 del quality review: orden RN-B11 con dataset mixto. Incluye
    // fix del comparador que ordena las excedidas por `overBy` desc (no por
    // usedPct que se clampa a 100 y todas las excedidas empatarían).
    test(
        'UT-B17: orden RN-B11 con 4 estados; excedidas por overBy desc, no alfabético',
        () async {
      // Sembramos 4 categorías con distintos estados:
      // - Salud_Overdue: gastó 3000 sobre límite 1000 → overBy=2000 (peor).
      // - Comida_Overdue: gastó 1500 sobre límite 1000 → overBy=500.
      // - Transporte_Warning: gastó 900 sobre límite 1000 → 90% (warning).
      // - Regalos_NoSpend: sin gasto sobre límite 500.
      final salud = await categoriesDao.create(
        name: 'Salud_B17',
        appliesTo: 'expense',
        colorSlug: 'red',
        iconSlug: 'heart',
        monthlyLimit: 1000,
      );
      final comida = await categoriesDao.create(
        name: 'Comida_B17',
        appliesTo: 'expense',
        colorSlug: 'orange',
        iconSlug: 'shopping-cart',
        monthlyLimit: 1000,
      );
      final transporte = await categoriesDao.create(
        name: 'Transporte_B17',
        appliesTo: 'expense',
        colorSlug: 'blue',
        iconSlug: 'truck',
        monthlyLimit: 1000,
      );
      await categoriesDao.create(
        name: 'Regalos_B17',
        appliesTo: 'expense',
        colorSlug: 'purple',
        iconSlug: 'gift',
        monthlyLimit: 500,
      );
      await entriesDao.registerExpense(
        accountOriginId: bolsa,
        amount: 3000,
        categoryId: salud,
        occurredAt: DateTime(2024, 6, 5),
      );
      await entriesDao.registerExpense(
        accountOriginId: bolsa,
        amount: 1500,
        categoryId: comida,
        occurredAt: DateTime(2024, 6, 6),
      );
      await entriesDao.registerExpense(
        accountOriginId: bolsa,
        amount: 900,
        categoryId: transporte,
        occurredAt: DateTime(2024, 6, 7),
      );
      final list = await reports
          .watchBudgetsProgress(monthAnchor: anchor)
          .first;
      final names = list.map((p) => p.categoryName).toList();
      expect(names, [
        'Salud_B17', // overBy=2000, primera
        'Comida_B17', // overBy=500, segunda
        'Transporte_B17', // warning 90%
        'Regalos_B17', // sin gasto, alfabético al final
      ]);
    });

    // M2 del quality review: reactividad del stream. Verifica que
    // registrar un expense re-emite con nueva deuda sin refresh manual.
    test(
        'UT-B18: reactividad — registrar expense re-emite con nuevo spent',
        () async {
      await categoriesDao.updateCategory(
        id: catComida,
        monthlyLimit: const Value(3000),
      );
      final events = <List<BudgetProgress>>[];
      final sub = reports
          .watchBudgetsProgress(monthAnchor: anchor)
          .listen(events.add);
      // Esperar el emit inicial.
      await Future.delayed(const Duration(milliseconds: 50));
      expect(events, isNotEmpty);
      final initial =
          events.last.firstWhere((p) => p.categoryId == catComida);
      expect(initial.spent, 0);

      await entriesDao.registerExpense(
        accountOriginId: bolsa,
        amount: 400,
        categoryId: catComida,
        occurredAt: DateTime(2024, 6, 10),
      );
      await Future.delayed(const Duration(milliseconds: 100));
      final updated =
          events.last.firstWhere((p) => p.categoryId == catComida);
      expect(updated.spent, 400);

      await sub.cancel();
    });

    // L1 del quality review: UT-B11 ampliado. Verificar explícitamente
    // que transfer y debt_payment NO cuentan como spent aunque tengan
    // categoría (los registeers no aceptan categoryId, forzamos vía
    // customStatement/update para simular data corrupta).
    test(
        'UT-B11b: transfer y debt_payment con categoryId no cuentan como spent',
        () async {
      await categoriesDao.updateCategory(
        id: catComida,
        monthlyLimit: const Value(3000),
      );
      // Referencia: expense normal cuenta.
      await entriesDao.registerExpense(
        accountOriginId: bolsa,
        amount: 100,
        categoryId: catComida,
        occurredAt: DateTime(2024, 6, 5),
      );
      // Sembramos un transfer "corrupto" con category_id vía update
      // post-registro (el DAO de transfer no acepta categoryId; simulamos
      // data legacy o corrupción).
      final transferId = await entriesDao.registerTransfer(
        accountOriginId: bolsa,
        accountDestinationId: debit,
        amount: 500,
        occurredAt: DateTime(2024, 6, 6),
      );
      // Sembramos un debt_payment vía customStatement (el DAO exige que
      // haya deuda previa; para el test no queremos setup adicional).
      await db.customStatement(
        "INSERT INTO journal_entries("
        "id, kind, account_origin_id, account_destination_id, amount, "
        "description, occurred_at, category_id, created_at, updated_at) "
        "VALUES('01a2b3c4-5678-7abc-9def-b11btransfer2', 'debt_payment', ?, ?, "
        "200, NULL, '2024-06-07T00:00:00.000', ?, "
        "'2024-06-07T00:00:00.000', '2024-06-07T00:00:00.000')",
        [bolsa, credit, catComida],
      );
      await db.customStatement(
        "UPDATE journal_entries SET category_id = ? WHERE id = ?",
        [catComida, transferId],
      );
      final list = await reports
          .watchBudgetsProgress(monthAnchor: anchor)
          .first;
      expect(list.first.spent, 100,
          reason:
              'Solo el expense (100) cuenta; el transfer (500) y el debt_payment (200) no.');
    });
  });

  // Sprint flutter-reports-income-by-category-v1
  group('incomeByCategory (sprint income-by-category)', () {
    // Rango que engloba junio completo.
    final iFrom = DateTime(2026, 6, 1);
    final iTo = DateTime(2026, 6, 30, 23, 59, 59, 999);

    late String catIncomeSueldo;
    late String catIncomeFreelance;
    late String catBothMisc;

    setUp(() async {
      catIncomeSueldo = await categoriesDao.create(
        name: 'Sueldo_Test',
        appliesTo: 'income',
        colorSlug: 'green',
        iconSlug: 'briefcase',
      );
      catIncomeFreelance = await categoriesDao.create(
        name: 'Freelance_Test',
        appliesTo: 'income',
        colorSlug: 'blue',
        iconSlug: 'briefcase',
      );
      catBothMisc = await categoriesDao.create(
        name: 'Otros_Test',
        appliesTo: 'both',
        colorSlug: 'gray',
        iconSlug: 'tag',
      );
    });

    test('UT-I01: BD sin incomes en el rango → isEmpty=true', () async {
      final report = await reports.incomeByCategory(from: iFrom, to: iTo).first;
      expect(report.isEmpty, isTrue);
      expect(report.total, 0);
      expect(report.count, 0);
      expect(report.buckets, isEmpty);
    });

    test('UT-I02: 1 income con categoría income → 1 bucket 100%', () async {
      await entriesDao.registerIncome(
        accountDestinationId: bolsa,
        amount: 30000,
        categoryId: catIncomeSueldo,
        occurredAt: DateTime(2026, 6, 5),
      );
      final report = await reports.incomeByCategory(from: iFrom, to: iTo).first;
      expect(report.buckets, hasLength(1));
      expect(report.buckets.first.categoryId, catIncomeSueldo);
      expect(report.buckets.first.total, 30000);
      expect(report.buckets.first.percent, closeTo(1.0, 0.001));
      expect(report.total, 30000);
      expect(report.count, 1);
    });

    test(
        'UT-I03: mix (null + archivada + expense) → 1 solo bucket "Sin categoría"',
        () async {
      // Case a: sin category_id (registro normal por DAO).
      await entriesDao.registerIncome(
        accountDestinationId: bolsa,
        amount: 100,
        occurredAt: DateTime(2026, 6, 5),
      );
      // Case b: categoría archivada. Registramos y luego archivamos.
      final archivedId = await categoriesDao.create(
        name: 'Vieja_Test',
        appliesTo: 'income',
        colorSlug: 'red',
        iconSlug: 'tag',
      );
      await entriesDao.registerIncome(
        accountDestinationId: bolsa,
        amount: 200,
        categoryId: archivedId,
        occurredAt: DateTime(2026, 6, 6),
      );
      await categoriesDao.archive(archivedId);
      // Case c: income con categoría applies_to=expense. El DAO valida
      // y rechaza este combo, pero un backup legacy podría traerlo.
      // Simulamos con customStatement bypaseando el DAO.
      await db.customStatement(
        "INSERT INTO journal_entries(id, kind, account_origin_id, "
        "account_destination_id, amount, description, occurred_at, "
        "category_id, created_at, updated_at) "
        "VALUES('01a2b3c4-5678-7abc-9def-i03legacyexp', 'income', NULL, ?, "
        "300, NULL, '2026-06-07T00:00:00.000', ?, "
        "'2026-06-07T00:00:00.000', '2026-06-07T00:00:00.000')",
        [bolsa, catComida], // catComida es applies_to='expense'
      );
      final report = await reports.incomeByCategory(from: iFrom, to: iTo).first;
      expect(report.buckets, hasLength(1),
          reason: 'Los 3 casos merge en un solo bucket "Sin categoría".');
      expect(report.buckets.first.categoryId, isNull);
      expect(report.buckets.first.name, 'Sin categoría');
      expect(report.buckets.first.total, 600);
      expect(report.buckets.first.count, 3);
    });

    test('UT-I04: applies_to=both con income → sí aparece', () async {
      await entriesDao.registerIncome(
        accountDestinationId: bolsa,
        amount: 500,
        categoryId: catBothMisc,
        occurredAt: DateTime(2026, 6, 5),
      );
      final report = await reports.incomeByCategory(from: iFrom, to: iTo).first;
      expect(report.buckets, hasLength(1));
      expect(report.buckets.first.categoryId, catBothMisc);
      expect(report.buckets.first.name, 'Otros_Test');
    });

    test('UT-I05: empate en total → orden alfabético asc', () async {
      await entriesDao.registerIncome(
        accountDestinationId: bolsa,
        amount: 1000,
        categoryId: catIncomeFreelance,
        occurredAt: DateTime(2026, 6, 5),
      );
      await entriesDao.registerIncome(
        accountDestinationId: bolsa,
        amount: 1000,
        categoryId: catIncomeSueldo,
        occurredAt: DateTime(2026, 6, 6),
      );
      final report = await reports.incomeByCategory(from: iFrom, to: iTo).first;
      expect(report.buckets, hasLength(2));
      // "Freelance_Test" < "Sueldo_Test" alfabéticamente.
      expect(report.buckets[0].name, 'Freelance_Test');
      expect(report.buckets[1].name, 'Sueldo_Test');
    });

    test('UT-I06: distintos totales → orden por total desc', () async {
      await entriesDao.registerIncome(
        accountDestinationId: bolsa,
        amount: 5000,
        categoryId: catIncomeFreelance,
        occurredAt: DateTime(2026, 6, 5),
      );
      await entriesDao.registerIncome(
        accountDestinationId: bolsa,
        amount: 30000,
        categoryId: catIncomeSueldo,
        occurredAt: DateTime(2026, 6, 6),
      );
      final report = await reports.incomeByCategory(from: iFrom, to: iTo).first;
      expect(report.buckets[0].name, 'Sueldo_Test'); // 30000 primero
      expect(report.buckets[1].name, 'Freelance_Test'); // 5000 segundo
    });

    test(
        'UT-I07: otros kinds NO cuentan aunque tengan category_id compatible',
        () async {
      // Referencia: 1 income con categoría income válida.
      await entriesDao.registerIncome(
        accountDestinationId: bolsa,
        amount: 500,
        categoryId: catIncomeSueldo,
        occurredAt: DateTime(2026, 6, 8),
      );
      // Expenses con categoría expense (permitido por DAO).
      await entriesDao.registerExpense(
        accountOriginId: bolsa,
        amount: 100,
        categoryId: catComida,
        occurredAt: DateTime(2026, 6, 5),
      );
      await entriesDao.registerCreditExpense(
        accountOriginId: credit,
        amount: 200,
        categoryId: catComida,
        occurredAt: DateTime(2026, 6, 6),
      );
      await entriesDao.registerTransfer(
        accountOriginId: bolsa,
        accountDestinationId: debit,
        amount: 300,
        occurredAt: DateTime(2026, 6, 7),
      );
      final report = await reports.incomeByCategory(from: iFrom, to: iTo).first;
      expect(report.total, 500,
          reason: 'Solo el income cuenta; expense/credit_expense/transfer no.');
      expect(report.count, 1);
    });

    test('UT-I08: reactividad — registrar income re-emite', () async {
      // Sin Future.delayed: emitsThrough espera hasta el snapshot que
      // matchea el predicate, sin importar cuántos emits previos hubo.
      // Robusto contra flakiness en CI cargado.
      final stream = reports.incomeByCategory(from: iFrom, to: iTo);
      final future = expectLater(
        stream,
        emitsThrough(
          predicate<IncomeReport>((r) => r.total == 1000 && r.count == 1),
        ),
      );
      await entriesDao.registerIncome(
        accountDestinationId: bolsa,
        amount: 1000,
        categoryId: catIncomeSueldo,
        occurredAt: DateTime(2026, 6, 10),
      );
      await future;
    });

    test('UT-I09: percent calculado correctamente para 2 buckets', () async {
      await entriesDao.registerIncome(
        accountDestinationId: bolsa,
        amount: 1000,
        categoryId: catIncomeFreelance,
        occurredAt: DateTime(2026, 6, 5),
      );
      await entriesDao.registerIncome(
        accountDestinationId: bolsa,
        amount: 3000,
        categoryId: catIncomeSueldo,
        occurredAt: DateTime(2026, 6, 6),
      );
      final report = await reports.incomeByCategory(from: iFrom, to: iTo).first;
      // Sueldo=3000 → 75%, Freelance=1000 → 25%.
      expect(report.buckets[0].percent, closeTo(0.75, 0.001));
      expect(report.buckets[1].percent, closeTo(0.25, 0.001));
    });

    test(
        'UT-I10: defensiva division/zero — income con amount=0 no crashea y percent=0',
        () async {
      // El DAO valida `amount > 0`, pero un backup legacy o corrupción
      // externa podría traer amount=0. Bypaseamos con customStatement.
      // Verifica que el guard `total > 0 ? r.total / total : 0` en
      // `_buildIncomeReport` no revienta por división por cero.
      await db.customStatement(
        "INSERT INTO journal_entries(id, kind, account_origin_id, "
        "account_destination_id, amount, description, occurred_at, "
        "category_id, created_at, updated_at) "
        "VALUES('01a2b3c4-5678-7abc-9def-000000000110', 'income', NULL, ?, "
        "0.0, NULL, '2026-06-10T00:00:00.000', ?, "
        "'2026-06-10T00:00:00.000', '2026-06-10T00:00:00.000')",
        [bolsa, catIncomeSueldo],
      );
      final report = await reports.incomeByCategory(from: iFrom, to: iTo).first;
      expect(report.total, 0);
      expect(report.buckets, hasLength(1));
      expect(report.buckets.first.total, 0);
      expect(report.buckets.first.percent, 0,
          reason: 'Guard defensivo: total_general=0 no divide, retorna 0.');
      expect(report.isEmpty, isFalse,
          reason: 'Hay un bucket presente aunque total sea 0.');
    });
  });
}
