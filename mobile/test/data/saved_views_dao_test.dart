import 'package:drift/native.dart';
import 'package:fincore/data/daos/saved_views_dao.dart';
import 'package:fincore/data/database.dart';
import 'package:fincore/data/entries_filters.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/sqlite_override.dart';

/// Tests data del `SavedViewsDao`. Sprint
/// `flutter-entries-saved-views-v1` (CM-01).
void main() {
  setUpAll(initSqliteOverride);

  late FincoreDatabase db;
  late SavedViewsDao dao;

  setUp(() {
    db = FincoreDatabase(NativeDatabase.memory());
    dao = db.savedViewsDao;
  });

  tearDown(() async {
    await db.close();
  });

  EntriesFilters baseFilters() => EntriesFilters.thisMonth();

  group('SavedViewsDao — CRUD', () {
    test('UT-01: create + findById retorna la vista creada', () async {
      final id =
          await dao.create(name: 'Mi vista', filters: baseFilters());
      expect(id, isNotEmpty);
      final found = await dao.findById(id);
      expect(found, isNotNull);
      expect(found!.name, 'Mi vista');
      expect(found.filters.datePreset, baseFilters().datePreset);
    });

    test('UT-02: create con name vacío lanza invalid_name', () async {
      expect(
        () => dao.create(name: '   ', filters: baseFilters()),
        throwsA(isA<SavedViewsDaoError>()
            .having((e) => e.code, 'code', 'invalid_name')),
      );
    });

    test(
        'UT-02b: create trimea whitespace al inicio y final '
        '(sprint flutter-saved-views-polish-v1 / H12 quality review)',
        () async {
      final id = await dao.create(
        name: '  Mi vista  ',
        filters: baseFilters(),
      );
      final found = await dao.findById(id);
      expect(found!.name, 'Mi vista');
    });

    test('UT-03: create con name > 50 chars lanza invalid_name',
        () async {
      final longName = 'a' * 51;
      expect(
        () => dao.create(name: longName, filters: baseFilters()),
        throwsA(isA<SavedViewsDaoError>()
            .having((e) => e.code, 'code', 'invalid_name')),
      );
    });

    test('UT-04: create con name duplicado case-insensitive',
        () async {
      await dao.create(name: 'Comida', filters: baseFilters());
      expect(
        () => dao.create(name: 'comida', filters: baseFilters()),
        throwsA(isA<SavedViewsDaoError>()
            .having((e) => e.code, 'code', 'duplicate_name')),
      );
      expect(
        () => dao.create(name: 'COMIDA', filters: baseFilters()),
        throwsA(isA<SavedViewsDaoError>()
            .having((e) => e.code, 'code', 'duplicate_name')),
      );
    });

    test('UT-05: rename actualiza el name y valida duplicados',
        () async {
      final id1 =
          await dao.create(name: 'Original', filters: baseFilters());
      final id2 =
          await dao.create(name: 'Otra', filters: baseFilters());
      await dao.rename(id: id1, name: 'Renombrada');
      final renamed = await dao.findById(id1);
      expect(renamed!.name, 'Renombrada');
      // Renombrar id2 al nombre de id1 → duplicado.
      expect(
        () => dao.rename(id: id2, name: 'renombrada'),
        throwsA(isA<SavedViewsDaoError>()
            .having((e) => e.code, 'code', 'duplicate_name')),
      );
    });

    test('UT-06: removeById borra físicamente', () async {
      final id = await dao.create(name: 'X', filters: baseFilters());
      await dao.removeById(id: id);
      expect(await dao.findById(id), isNull);
    });

    test('UT-07: listAll retorna en orden created_at DESC', () async {
      final ids = <String>[];
      for (var i = 0; i < 3; i++) {
        final id = await dao.create(
            name: 'View $i', filters: baseFilters());
        ids.add(id);
        // Forzar diferencia mínima de timestamp.
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      final list = await dao.listAll();
      expect(list.length, 3);
      // El último creado debe ser el primero en la lista.
      expect(list.first.id, ids.last);
      expect(list.last.id, ids.first);
    });

    test('UT-08: watchAll emite tras create y tras removeById',
        () async {
      final stream = dao.watchAll();
      final emissions = <List<SavedView>>[];
      final sub = stream.listen(emissions.add);

      // Primer evento: lista vacía.
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(emissions.last, isEmpty);

      final id =
          await dao.create(name: 'Reactiva', filters: baseFilters());
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(emissions.last.map((v) => v.id), [id]);

      await dao.removeById(id: id);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(emissions.last, isEmpty);

      await sub.cancel();
    });
  });

  group('SavedViewsDao — errores tipados', () {
    test('UT-09: rename con id inexistente lanza not_found', () async {
      expect(
        () => dao.rename(id: 'no-existe', name: 'Cualquier'),
        throwsA(isA<SavedViewsDaoError>()
            .having((e) => e.code, 'code', 'not_found')),
      );
    });

    test('UT-10: removeById con id inexistente lanza not_found',
        () async {
      expect(
        () => dao.removeById(id: 'no-existe'),
        throwsA(isA<SavedViewsDaoError>()
            .having((e) => e.code, 'code', 'not_found')),
      );
    });
  });
}
