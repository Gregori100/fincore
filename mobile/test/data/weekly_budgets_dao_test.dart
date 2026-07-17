import 'package:drift/native.dart';
import 'package:fincore/data/daos/accounts_dao.dart';
import 'package:fincore/data/daos/categories_dao.dart';
import 'package:fincore/data/daos/weekly_budgets_dao.dart';
import 'package:fincore/data/database.dart';
import 'package:fincore/data/seed.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../helpers/sqlite_override.dart';

/// Tests del `WeeklyBudgetsDao` del sprint `flutter-weekly-budgets-v1` +
/// refactor `flutter-weekly-budgets-v1` (2026-07-14, consolidación de
/// "plantilla" en `is_template`). Cubre UT-WB01 a UT-WB31 del test-plan
/// (`engineering/specs/flutter-weekly-budgets-v1/plan/test-plan.md`).
void main() {
  setUpAll(() async {
    initSqliteOverride();
    // `generateAutoLabel` formatea con `DateFormat('d MMM', 'es_MX')`; sin
    // esta inicialización lanza `LocaleDataException` (mismo requisito que
    // `widget_test_harness.dart` para las pantallas).
    await initializeDateFormatting('es_MX', null);
  });

  late FincoreDatabase db;
  late AccountsDao accountsDao;
  late CategoriesDao categoriesDao;
  late WeeklyBudgetsDao weeklyBudgetsDao;

  late String catComidaActiva;
  late String catViejaArchivada;

  setUp(() async {
    db = FincoreDatabase(NativeDatabase.memory());
    accountsDao = AccountsDao(db);
    categoriesDao = CategoriesDao(db);
    weeklyBudgetsDao = WeeklyBudgetsDao(db);

    await seedDefaults(
      db: db,
      accountsDao: accountsDao,
      categoriesDao: categoriesDao,
    );

    catComidaActiva = await categoriesDao.create(
      name: 'Comida_WB',
      appliesTo: 'expense',
      colorSlug: 'red',
      iconSlug: 'shopping-cart',
    );

    catViejaArchivada = await categoriesDao.create(
      name: 'Vieja_WB',
      appliesTo: 'expense',
      colorSlug: 'gray',
      iconSlug: 'tag',
    );
    await categoriesDao.archive(catViejaArchivada);
  });

  tearDown(() async {
    await db.close();
  });

  group('Schema', () {
    test(
        'UT-WB01: las 2 tablas de presupuestos existen tras open de BD con '
        'schema v7 (incluyendo la columna is_template)', () async {
      // La sola ejecución sin excepción de selects ya confirma que el
      // schema v7 las creó correctamente.
      final budgets = await (db.select(db.weeklyBudgets)).get();
      final items = await (db.select(db.weeklyBudgetItems)).get();

      expect(budgets, isEmpty);
      expect(items, isEmpty);
    });
  });

  group('createBudget', () {
    test(
        'UT-WB02: createBudget con label válido persiste 1 fila con '
        'created_at seteado', () async {
      final id = await weeklyBudgetsDao.createBudget(
        weekStartDate: DateTime(2026, 7, 17),
        label: 'Sueldo 17',
      );

      final row = await weeklyBudgetsDao.findById(id);
      expect(row, isNotNull);
      expect(row!.label, 'Sueldo 17');
      expect(row.weekStartDate, DateTime(2026, 7, 17));
      expect(row.createdAt, isNotNull);

      final all = await (db.select(db.weeklyBudgets)).get();
      expect(all, hasLength(1));
    });

    test(
        'UT-WB03: createBudget con label vacío o whitespace lanza '
        'invalid_budget_label', () async {
      expect(
        () => weeklyBudgetsDao.createBudget(
          weekStartDate: DateTime(2026, 7, 17),
          label: '',
        ),
        throwsA(isA<WeeklyBudgetsDaoError>()
            .having((e) => e.code, 'code', 'invalid_budget_label')),
      );
      expect(
        () => weeklyBudgetsDao.createBudget(
          weekStartDate: DateTime(2026, 7, 17),
          label: '   ',
        ),
        throwsA(isA<WeeklyBudgetsDaoError>()
            .having((e) => e.code, 'code', 'invalid_budget_label')),
      );
    });

    test(
        'UT-WB04: createBudget con label > 60 chars lanza '
        'invalid_budget_label', () async {
      final tooLong = 'a' * 61;
      expect(
        () => weeklyBudgetsDao.createBudget(
          weekStartDate: DateTime(2026, 7, 17),
          label: tooLong,
        ),
        throwsA(isA<WeeklyBudgetsDaoError>()
            .having((e) => e.code, 'code', 'invalid_budget_label')),
      );
    });
  });

  group('updateBudget', () {
    test('UT-WB05: updateBudget(id, label: X) persiste; retorna 1',
        () async {
      final id = await weeklyBudgetsDao.createBudget(
        weekStartDate: DateTime(2026, 7, 17),
        label: 'Original',
      );

      final rowsUpdated =
          await weeklyBudgetsDao.updateBudget(id, label: 'Nuevo label');
      expect(rowsUpdated, 1);

      final row = await weeklyBudgetsDao.findById(id);
      expect(row!.label, 'Nuevo label');
    });

    test(
        'UT-WB06: updateBudget(id, weekStartDate: X) lanza immutable_field '
        '(CB-T10)', () async {
      final id = await weeklyBudgetsDao.createBudget(
        weekStartDate: DateTime(2026, 7, 17),
        label: 'Sueldo 17',
      );

      expect(
        () => weeklyBudgetsDao.updateBudget(
          id,
          weekStartDate: DateTime(2026, 7, 24),
        ),
        throwsA(isA<WeeklyBudgetsDaoError>()
            .having((e) => e.code, 'code', 'immutable_field')),
      );
    });
  });

  group('deleteBudget', () {
    test(
        'UT-WB07: deleteBudget remueve la fila y sus items caen por '
        'cascade aplicativa', () async {
      final id = await weeklyBudgetsDao.createBudget(
        weekStartDate: DateTime(2026, 7, 17),
        label: 'Sueldo 17',
      );
      await weeklyBudgetsDao.addItem(
        budgetId: id,
        name: 'Sueldo',
        amount: 6500,
        kind: 'income',
      );
      await weeklyBudgetsDao.addItem(
        budgetId: id,
        name: 'Renta',
        amount: 1000,
        kind: 'expense',
      );
      await weeklyBudgetsDao.addItem(
        budgetId: id,
        name: 'Comida',
        amount: 2000,
        kind: 'expense',
      );

      final itemsBefore = await (db.select(db.weeklyBudgetItems)
            ..where((i) => i.budgetId.equals(id)))
          .get();
      expect(itemsBefore, hasLength(3));

      await weeklyBudgetsDao.deleteBudget(id);

      final budgetsAfter = await (db.select(db.weeklyBudgets)).get();
      final itemsAfter = await (db.select(db.weeklyBudgetItems)
            ..where((i) => i.budgetId.equals(id)))
          .get();
      expect(budgetsAfter, isEmpty);
      expect(itemsAfter, isEmpty);
    });

    test('deleteBudget con id inexistente lanza not_found', () async {
      expect(
        () => weeklyBudgetsDao.deleteBudget('uuid-inexistente'),
        throwsA(isA<WeeklyBudgetsDaoError>()
            .having((e) => e.code, 'code', 'not_found')),
      );
    });
  });

  group('addItem — validaciones', () {
    late String budgetId;

    setUp(() async {
      budgetId = await weeklyBudgetsDao.createBudget(
        weekStartDate: DateTime(2026, 7, 17),
        label: 'Sueldo 17',
      );
    });

    test('UT-WB08: addItem con name vacío lanza invalid_item_name',
        () async {
      expect(
        () => weeklyBudgetsDao.addItem(
          budgetId: budgetId,
          name: '',
          amount: 100,
          kind: 'expense',
        ),
        throwsA(isA<WeeklyBudgetsDaoError>()
            .having((e) => e.code, 'code', 'invalid_item_name')),
      );
    });

    test('UT-WB09: addItem con amount = 0 lanza invalid_item_amount',
        () async {
      expect(
        () => weeklyBudgetsDao.addItem(
          budgetId: budgetId,
          name: 'Renta',
          amount: 0,
          kind: 'expense',
        ),
        throwsA(isA<WeeklyBudgetsDaoError>()
            .having((e) => e.code, 'code', 'invalid_item_amount')),
      );
    });

    test('UT-WB10: addItem con amount < 0 lanza invalid_item_amount',
        () async {
      expect(
        () => weeklyBudgetsDao.addItem(
          budgetId: budgetId,
          name: 'Renta',
          amount: -50,
          kind: 'expense',
        ),
        throwsA(isA<WeeklyBudgetsDaoError>()
            .having((e) => e.code, 'code', 'invalid_item_amount')),
      );
    });

    test('UT-WB11: addItem con kind inválido lanza invalid_kind', () async {
      expect(
        () => weeklyBudgetsDao.addItem(
          budgetId: budgetId,
          name: 'Renta',
          amount: 100,
          kind: 'transfer',
        ),
        throwsA(isA<WeeklyBudgetsDaoError>()
            .having((e) => e.code, 'code', 'invalid_kind')),
      );
    });

    test(
        'UT-WB12: addItem con categoryId de categoría archivada lanza '
        'invalid_category_reference', () async {
      expect(
        () => weeklyBudgetsDao.addItem(
          budgetId: budgetId,
          name: 'Renta',
          categoryId: catViejaArchivada,
          amount: 100,
          kind: 'expense',
        ),
        throwsA(isA<WeeklyBudgetsDaoError>()
            .having((e) => e.code, 'code', 'invalid_category_reference')),
      );
    });

    test('UT-WB13: addItem sin categoría persiste con categoryId = null',
        () async {
      final itemId = await weeklyBudgetsDao.addItem(
        budgetId: budgetId,
        name: 'Renta',
        amount: 100,
        kind: 'expense',
      );

      final row = await (db.select(db.weeklyBudgetItems)
            ..where((i) => i.id.equals(itemId)))
          .getSingle();
      expect(row.categoryId, isNull);
    });

    test(
        'addItem con categoryId de categoría activa persiste OK',
        () async {
      final itemId = await weeklyBudgetsDao.addItem(
        budgetId: budgetId,
        name: 'Comida',
        categoryId: catComidaActiva,
        amount: 200,
        kind: 'expense',
      );

      final row = await (db.select(db.weeklyBudgetItems)
            ..where((i) => i.id.equals(itemId)))
          .getSingle();
      expect(row.categoryId, catComidaActiva);
    });
  });

  group('addItem — sort_order', () {
    test(
        'UT-WB14: sort_order asignado incremental en bloques de 100 '
        '(10, 110, 210, ...)', () async {
      final budgetId = await weeklyBudgetsDao.createBudget(
        weekStartDate: DateTime(2026, 7, 17),
        label: 'Sueldo 17',
      );

      final id1 = await weeklyBudgetsDao.addItem(
        budgetId: budgetId,
        name: 'Sueldo',
        amount: 6500,
        kind: 'income',
      );
      final id2 = await weeklyBudgetsDao.addItem(
        budgetId: budgetId,
        name: 'Renta',
        amount: 1000,
        kind: 'expense',
      );
      final id3 = await weeklyBudgetsDao.addItem(
        budgetId: budgetId,
        name: 'Comida',
        amount: 2000,
        kind: 'expense',
      );

      final row1 = await (db.select(db.weeklyBudgetItems)
            ..where((i) => i.id.equals(id1)))
          .getSingle();
      final row2 = await (db.select(db.weeklyBudgetItems)
            ..where((i) => i.id.equals(id2)))
          .getSingle();
      final row3 = await (db.select(db.weeklyBudgetItems)
            ..where((i) => i.id.equals(id3)))
          .getSingle();

      expect(row1.sortOrder, 10);
      expect(row2.sortOrder, 110);
      expect(row3.sortOrder, 210);
    });
  });

  group('updateItem / deleteItem', () {
    test('UT-WB15: updateItem(id, amount: nuevo) persiste; balance re-emite',
        () async {
      final budgetId = await weeklyBudgetsDao.createBudget(
        weekStartDate: DateTime(2026, 7, 17),
        label: 'Sueldo 17',
      );
      final itemId = await weeklyBudgetsDao.addItem(
        budgetId: budgetId,
        name: 'Sueldo',
        amount: 6500,
        kind: 'income',
      );

      final stream = weeklyBudgetsDao.watchBudgetBalance(budgetId);
      final expectation = expectLater(
        stream,
        emitsThrough(predicate<double>((b) => b == 7000)),
      );

      final rowsUpdated =
          await weeklyBudgetsDao.updateItem(itemId, amount: 7000);
      expect(rowsUpdated, 1);

      await expectation;

      final row = await (db.select(db.weeklyBudgetItems)
            ..where((i) => i.id.equals(itemId)))
          .getSingle();
      expect(row.amount, 7000);
    });

    test('UT-WB16: deleteItem remueve fila; balance re-emite', () async {
      final budgetId = await weeklyBudgetsDao.createBudget(
        weekStartDate: DateTime(2026, 7, 17),
        label: 'Sueldo 17',
      );
      final incomeId = await weeklyBudgetsDao.addItem(
        budgetId: budgetId,
        name: 'Sueldo',
        amount: 6500,
        kind: 'income',
      );
      await weeklyBudgetsDao.addItem(
        budgetId: budgetId,
        name: 'Renta',
        amount: 1000,
        kind: 'expense',
      );

      final stream = weeklyBudgetsDao.watchBudgetBalance(budgetId);
      final expectation = expectLater(
        stream,
        emitsThrough(predicate<double>((b) => b == -1000)),
      );

      await weeklyBudgetsDao.deleteItem(incomeId);

      await expectation;

      final remaining = await (db.select(db.weeklyBudgetItems)
            ..where((i) => i.budgetId.equals(budgetId)))
          .get();
      expect(remaining, hasLength(1));
      expect(remaining.first.name, 'Renta');
    });

    test('deleteItem con id inexistente lanza not_found', () async {
      expect(
        () => weeklyBudgetsDao.deleteItem('uuid-inexistente'),
        throwsA(isA<WeeklyBudgetsDaoError>()
            .having((e) => e.code, 'code', 'not_found')),
      );
    });
  });

  group('toggleItemDone (flutter-budgets-item-completion-v1)', () {
    test('UT-WB-D01: primer toggle marca; segundo desmarca', () async {
      final budgetId = await weeklyBudgetsDao.createBudget(
        weekStartDate: DateTime(2026, 7, 17),
        label: 'Sueldo 17',
      );
      final itemId = await weeklyBudgetsDao.addItem(
        budgetId: budgetId,
        name: 'Renta',
        amount: 5000,
        kind: 'expense',
      );

      final initial = await weeklyBudgetsDao.watchBudgetItems(budgetId).first;
      expect(initial.single.isDone, isFalse,
          reason: 'default de la columna DEBE ser false');

      final afterFirst = await weeklyBudgetsDao.toggleItemDone(itemId);
      expect(afterFirst, isTrue);
      final firstQuery = await weeklyBudgetsDao.watchBudgetItems(budgetId).first;
      expect(firstQuery.single.isDone, isTrue);

      final afterSecond = await weeklyBudgetsDao.toggleItemDone(itemId);
      expect(afterSecond, isFalse);
      final secondQuery =
          await weeklyBudgetsDao.watchBudgetItems(budgetId).first;
      expect(secondQuery.single.isDone, isFalse);
    });

    test('UT-WB-D02: toggle actualiza updated_at', () async {
      final budgetId = await weeklyBudgetsDao.createBudget(
        weekStartDate: DateTime(2026, 7, 17),
        label: 'Sueldo 17',
      );
      final itemId = await weeklyBudgetsDao.addItem(
        budgetId: budgetId,
        name: 'Renta',
        amount: 5000,
        kind: 'expense',
      );
      final before =
          (await weeklyBudgetsDao.watchBudgetItems(budgetId).first).single;

      // Delay mínimo para que updated_at cambie (SQLite guarda ms).
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await weeklyBudgetsDao.toggleItemDone(itemId);

      final after =
          (await weeklyBudgetsDao.watchBudgetItems(budgetId).first).single;
      expect(after.updatedAt.isAfter(before.updatedAt), isTrue,
          reason: 'toggle DEBE tocar updated_at para invalidar caches del UI');
    });

    test('UT-WB-D03: toggle con id inexistente lanza not_found', () async {
      expect(
        () => weeklyBudgetsDao.toggleItemDone('uuid-inexistente'),
        throwsA(isA<WeeklyBudgetsDaoError>()
            .having((e) => e.code, 'code', 'not_found')),
      );
    });

    test(
        'UT-WB-D04: createBudgetFromTemplate arranca items del clon con '
        'isDone=false, incluso si la plantilla tiene items marcados', () async {
      // Arrange: plantilla con 2 items, uno marcado done.
      final templateId = await weeklyBudgetsDao.createBudget(
        weekStartDate: DateTime(2026, 7, 10),
        label: 'Plantilla semanal',
      );
      await weeklyBudgetsDao.toggleTemplateFlag(templateId);
      final marcadoId = await weeklyBudgetsDao.addItem(
        budgetId: templateId,
        name: 'Renta',
        amount: 5000,
        kind: 'expense',
      );
      await weeklyBudgetsDao.addItem(
        budgetId: templateId,
        name: 'Luz',
        amount: 500,
        kind: 'expense',
      );
      await weeklyBudgetsDao.toggleItemDone(marcadoId);

      // Act: clonar.
      final clonId = await weeklyBudgetsDao.createBudgetFromTemplate(
        weekStartDate: DateTime(2026, 7, 17),
        label: 'Semana nueva',
        templateId: templateId,
      );

      // Assert: los 2 items del clon arrancan con is_done=false.
      final clonItems = await weeklyBudgetsDao.watchBudgetItems(clonId).first;
      expect(clonItems, hasLength(2));
      expect(clonItems.every((i) => i.isDone == false), isTrue,
          reason: 'clon arranca fresco — nada se cumplió aún');

      // Sanity: la plantilla mantiene su estado.
      final templateItems =
          await weeklyBudgetsDao.watchBudgetItems(templateId).first;
      final marcadoTemplate =
          templateItems.firstWhere((i) => i.id == marcadoId);
      expect(marcadoTemplate.isDone, isTrue);
    });
  });

  group('reorderItems', () {
    test(
        'UT-WB17: reorderItems([id2, id1, id3]) renumera sort_order en '
        'transacción', () async {
      final budgetId = await weeklyBudgetsDao.createBudget(
        weekStartDate: DateTime(2026, 7, 17),
        label: 'Sueldo 17',
      );
      final id1 = await weeklyBudgetsDao.addItem(
        budgetId: budgetId,
        name: 'Item1',
        amount: 100,
        kind: 'expense',
      );
      final id2 = await weeklyBudgetsDao.addItem(
        budgetId: budgetId,
        name: 'Item2',
        amount: 200,
        kind: 'expense',
      );
      final id3 = await weeklyBudgetsDao.addItem(
        budgetId: budgetId,
        name: 'Item3',
        amount: 300,
        kind: 'expense',
      );

      await weeklyBudgetsDao.reorderItems(budgetId, [id2, id1, id3]);

      final items = await weeklyBudgetsDao.watchBudgetItems(budgetId).first;
      expect(items.map((i) => i.id).toList(), [id2, id1, id3]);
      expect(items.map((i) => i.sortOrder).toList(), [10, 110, 210]);
    });
  });

  group('watchBudgetBalance', () {
    test('UT-WB18: retorna 0 para presupuesto vacío', () async {
      final budgetId = await weeklyBudgetsDao.createBudget(
        weekStartDate: DateTime(2026, 7, 17),
        label: 'Sueldo 17',
      );

      final balance = await weeklyBudgetsDao.watchBudgetBalance(budgetId).first;
      expect(balance, 0);
    });

    test(
        'UT-WB19: retorna Σincome − Σexpense al agregar items',
        () async {
      final budgetId = await weeklyBudgetsDao.createBudget(
        weekStartDate: DateTime(2026, 7, 17),
        label: 'Sueldo 17',
      );
      await weeklyBudgetsDao.addItem(
        budgetId: budgetId,
        name: 'Sueldo',
        amount: 6500,
        kind: 'income',
      );
      await weeklyBudgetsDao.addItem(
        budgetId: budgetId,
        name: 'Freelance',
        amount: 500,
        kind: 'income',
      );
      await weeklyBudgetsDao.addItem(
        budgetId: budgetId,
        name: 'Renta',
        amount: 1000,
        kind: 'expense',
      );
      await weeklyBudgetsDao.addItem(
        budgetId: budgetId,
        name: 'Comida',
        amount: 4800,
        kind: 'expense',
      );

      final balance = await weeklyBudgetsDao.watchBudgetBalance(budgetId).first;
      expect(balance, 1200); // 6500 + 500 − 1000 − 4800
    });

    test(
        'UT-WB20: re-emite al agregar item con emitsThrough', () async {
      final budgetId = await weeklyBudgetsDao.createBudget(
        weekStartDate: DateTime(2026, 7, 17),
        label: 'Sueldo 17',
      );
      await weeklyBudgetsDao.addItem(
        budgetId: budgetId,
        name: 'Sueldo',
        amount: 1500,
        kind: 'income',
      );

      final stream = weeklyBudgetsDao.watchBudgetBalance(budgetId);
      final expectation = expectLater(
        stream,
        emitsThrough(predicate<double>((b) => b == 1200)),
      );

      await weeklyBudgetsDao.addItem(
        budgetId: budgetId,
        name: 'Comida',
        amount: 300,
        kind: 'expense',
      );

      await expectation;
    });
  });

  group('Multi-plan', () {
    test(
        'UT-WB21: 2 budgets con misma week_start_date y labels distintos '
        'coexisten sin error', () async {
      final weekStart = DateTime(2026, 7, 17);
      final idA = await weeklyBudgetsDao.createBudget(
        weekStartDate: weekStart,
        label: 'Sueldo 17',
      );
      final idB = await weeklyBudgetsDao.createBudget(
        weekStartDate: weekStart,
        label: 'Sueldo 17 Optimista',
      );

      expect(idA, isNot(idB));

      final all = await weeklyBudgetsDao.watchAll().first;
      final relevant =
          all.where((b) => b.weekStartDate == weekStart).toList();
      expect(relevant, hasLength(2));
      expect(relevant.map((b) => b.label).toSet(),
          {'Sueldo 17', 'Sueldo 17 Optimista'});
    });
  });

  group('createBudgetFromTemplate — snapshot (post-refactor: templateId es '
      'un WeeklyBudgetRow.id con is_template=true)', () {
    test(
        'UT-WB23: los items generados tienen nuevos id distintos a los del '
        'budget marcado como plantilla', () async {
      final templateId = await weeklyBudgetsDao.createBudget(
        weekStartDate: DateTime(2026, 7, 10),
        label: 'Sueldo base',
      );
      await weeklyBudgetsDao.toggleTemplateFlag(templateId);
      final templateItemId1 = await weeklyBudgetsDao.addItem(
        budgetId: templateId,
        name: 'Sueldo',
        amount: 6500,
        kind: 'income',
      );
      final templateItemId2 = await weeklyBudgetsDao.addItem(
        budgetId: templateId,
        name: 'Renta',
        amount: 1000,
        kind: 'expense',
      );

      final budgetId = await weeklyBudgetsDao.createBudgetFromTemplate(
        weekStartDate: DateTime(2026, 7, 24),
        label: 'Sueldo 24',
        templateId: templateId,
      );

      final budgetItems =
          await weeklyBudgetsDao.watchBudgetItems(budgetId).first;
      expect(budgetItems, hasLength(2));

      final budgetItemIds = budgetItems.map((i) => i.id).toSet();
      expect(budgetItemIds.contains(templateItemId1), isFalse);
      expect(budgetItemIds.contains(templateItemId2), isFalse);

      // Los valores sí se copian idénticos aunque los ids sean distintos.
      final sueldo = budgetItems.firstWhere((i) => i.name == 'Sueldo');
      final renta = budgetItems.firstWhere((i) => i.name == 'Renta');
      expect(sueldo.amount, 6500);
      expect(sueldo.kind, 'income');
      expect(renta.amount, 1000);
      expect(renta.kind, 'expense');

      // El budget derivado no queda marcado como plantilla.
      final derived = await weeklyBudgetsDao.findById(budgetId);
      expect(derived!.isTemplate, isFalse);
    });

    test('UT-WB24: createBudgetFromTemplate con template inexistente lanza '
        'not_found', () async {
      expect(
        () => weeklyBudgetsDao.createBudgetFromTemplate(
          weekStartDate: DateTime(2026, 7, 24),
          label: 'Sueldo 24',
          templateId: 'uuid-inexistente',
        ),
        throwsA(isA<WeeklyBudgetsDaoError>()
            .having((e) => e.code, 'code', 'not_found')),
      );
    });

    test(
        'UT-WB25 (CRÍTICO): editar la plantilla original post-derivación NO '
        'cambia el budget derivado (RN-B16)', () async {
      final templateId = await weeklyBudgetsDao.createBudget(
        weekStartDate: DateTime(2026, 7, 10),
        label: 'Sueldo base',
      );
      await weeklyBudgetsDao.toggleTemplateFlag(templateId);
      await weeklyBudgetsDao.addItem(
        budgetId: templateId,
        name: 'Sueldo',
        amount: 6500,
        kind: 'income',
      );
      await weeklyBudgetsDao.addItem(
        budgetId: templateId,
        name: 'Renta',
        amount: 1000,
        kind: 'expense',
      );

      final budgetId = await weeklyBudgetsDao.createBudgetFromTemplate(
        weekStartDate: DateTime(2026, 7, 24),
        label: 'Sueldo 24',
        templateId: templateId,
      );

      final budgetItemsBefore =
          await weeklyBudgetsDao.watchBudgetItems(budgetId).first;
      expect(budgetItemsBefore, hasLength(2));

      // Edita la plantilla DESPUÉS de derivar el budget: agrega un renglón
      // nuevo.
      await weeklyBudgetsDao.addItem(
        budgetId: templateId,
        name: 'Ahorro',
        amount: 500,
        kind: 'expense',
      );

      final templateItemsAfter =
          await weeklyBudgetsDao.watchBudgetItems(templateId).first;
      expect(templateItemsAfter, hasLength(3));

      // El budget derivado sigue con la misma cantidad de items originales,
      // sin el renglón nuevo — snapshot semántico, no referencia viva.
      final budgetItemsAfter =
          await weeklyBudgetsDao.watchBudgetItems(budgetId).first;
      expect(budgetItemsAfter, hasLength(2));
      expect(
        budgetItemsAfter.any((i) => i.name == 'Ahorro'),
        isFalse,
      );
    });

    test(
        'UT-WB31: createBudgetFromTemplate con templateId de budget que NO '
        'es plantilla lanza not_found', () async {
      final regularBudgetId = await weeklyBudgetsDao.createBudget(
        weekStartDate: DateTime(2026, 7, 10),
        label: 'Presupuesto normal',
      );

      expect(
        () => weeklyBudgetsDao.createBudgetFromTemplate(
          weekStartDate: DateTime(2026, 7, 24),
          label: 'Sueldo 24',
          templateId: regularBudgetId,
        ),
        throwsA(isA<WeeklyBudgetsDaoError>()
            .having((e) => e.code, 'code', 'not_found')),
      );
    });
  });

  group('toggleTemplateFlag', () {
    test('UT-WB26: invierte el flag; segundo toggle vuelve al original',
        () async {
      final id = await weeklyBudgetsDao.createBudget(
        weekStartDate: DateTime(2026, 7, 17),
        label: 'Sueldo 17',
      );
      final original = await weeklyBudgetsDao.findById(id);
      expect(original!.isTemplate, isFalse);

      final rowsUpdated = await weeklyBudgetsDao.toggleTemplateFlag(id);
      expect(rowsUpdated, 1);
      final afterFirstToggle = await weeklyBudgetsDao.findById(id);
      expect(afterFirstToggle!.isTemplate, isTrue);

      await weeklyBudgetsDao.toggleTemplateFlag(id);
      final afterSecondToggle = await weeklyBudgetsDao.findById(id);
      expect(afterSecondToggle!.isTemplate, isFalse);
    });

    test('UT-WB27: toggleTemplateFlag(inexistente) lanza not_found',
        () async {
      expect(
        () => weeklyBudgetsDao.toggleTemplateFlag('uuid-inexistente'),
        throwsA(isA<WeeklyBudgetsDaoError>()
            .having((e) => e.code, 'code', 'not_found')),
      );
    });
  });

  group('watchTemplates', () {
    test('UT-WB28: solo emite budgets con is_template=true', () async {
      final normalId = await weeklyBudgetsDao.createBudget(
        weekStartDate: DateTime(2026, 7, 10),
        label: 'Normal',
      );
      final templateId = await weeklyBudgetsDao.createBudget(
        weekStartDate: DateTime(2026, 7, 17),
        label: 'Plantilla',
      );
      await weeklyBudgetsDao.toggleTemplateFlag(templateId);

      final templates = await weeklyBudgetsDao.watchTemplates().first;
      expect(templates.map((b) => b.id), [templateId]);
      expect(templates.any((b) => b.id == normalId), isFalse);
    });
  });

  group('generateAutoLabel', () {
    test(
        'UT-WB29: sin colisión retorna "Semana del 17 jul"',
        () async {
      final label = await weeklyBudgetsDao.generateAutoLabel(
        DateTime(2026, 7, 17),
      );
      expect(label, 'Semana del 17 jul');
    });

    test(
        'UT-WB30: 2 llamadas consecutivas con la misma fecha (creando el '
        'primero en el medio) → segunda con sufijo "(2)"', () async {
      final firstLabel = await weeklyBudgetsDao.generateAutoLabel(
        DateTime(2026, 7, 17),
      );
      expect(firstLabel, 'Semana del 17 jul');

      await weeklyBudgetsDao.createBudget(
        weekStartDate: DateTime(2026, 7, 17),
        label: firstLabel,
      );

      final secondLabel = await weeklyBudgetsDao.generateAutoLabel(
        DateTime(2026, 7, 17),
      );
      expect(secondLabel, 'Semana del 17 jul (2)');
    });
  });
}
