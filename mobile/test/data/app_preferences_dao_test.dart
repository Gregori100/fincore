import 'package:drift/native.dart';
import 'package:fincore/data/database.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/sqlite_override.dart';

/// Tests del `AppPreferencesDao`. Sprint
/// `flutter-onboarding-for-testers-v1`.
void main() {
  setUpAll(initSqliteOverride);

  late FincoreDatabase db;

  setUp(() {
    db = FincoreDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('UT-01: get con clave inexistente retorna null', () async {
    final result = await db.appPreferencesDao.get('no-existe');
    expect(result, isNull);
  });

  test('UT-02: set + get recupera el valor seteado', () async {
    await db.appPreferencesDao.set('key1', 'value1');
    final result = await db.appPreferencesDao.get('key1');
    expect(result, 'value1');
  });

  test('UT-03: set con misma clave sobrescribe (idempotencia)',
      () async {
    await db.appPreferencesDao.set('key1', 'value1');
    await db.appPreferencesDao.set('key1', 'value2');
    final result = await db.appPreferencesDao.get('key1');
    expect(result, 'value2');
  });

  test('UT-04: set con valor empty string lo recupera como empty (no null)',
      () async {
    await db.appPreferencesDao.set('key_empty', '');
    final result = await db.appPreferencesDao.get('key_empty');
    expect(result, '');
    expect(result, isNotNull);
  });

  test('UT-05: múltiples claves coexisten sin interferencia',
      () async {
    await db.appPreferencesDao.set('onboarding_seen', 'true');
    await db.appPreferencesDao.set('last_export_at', '2026-06-29T10:00:00.000');
    final seen = await db.appPreferencesDao.get('onboarding_seen');
    final exportAt = await db.appPreferencesDao.get('last_export_at');
    expect(seen, 'true');
    expect(exportAt, '2026-06-29T10:00:00.000');
  });
}
