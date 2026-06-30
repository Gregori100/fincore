import 'package:drift/drift.dart';
import 'package:fincore/data/database.dart';

part 'app_preferences_dao.g.dart';

/// DAO para la tabla `app_preferences`. Sprint
/// `flutter-onboarding-for-testers-v1`.
///
/// Persistencia simple key/value para estado de UI que debe sobrevivir
/// reinicios de la app pero no es parte de los datos del usuario. NO se
/// serializa en backup JSON v1 (misma decisión que `saved_views`).
///
/// Claves canónicas en `lib/data/app_preferences_keys.dart`.
@DriftAccessor(tables: [AppPreferences])
class AppPreferencesDao extends DatabaseAccessor<FincoreDatabase>
    with _$AppPreferencesDaoMixin {
  AppPreferencesDao(super.db);

  /// Retorna el valor asociado a `key` o `null` si no existe.
  ///
  /// No lanza para claves ausentes — `null` es la señal canónica de
  /// "no seteado". El caller decide cómo interpretar `null` (default,
  /// preferencia inicial, etc).
  Future<String?> get(String key) async {
    final row = await (select(appPreferences)
          ..where((t) => t.key.equals(key))
          ..limit(1))
        .getSingleOrNull();
    return row?.value;
  }

  /// Inserta o sobrescribe el valor de `key`. Idempotente vía
  /// `insertOnConflictUpdate`: llamadas repetidas con el mismo `key`
  /// reemplazan el valor anterior sin lanzar `UNIQUE` constraint error.
  Future<void> set(String key, String value) async {
    await into(appPreferences).insertOnConflictUpdate(
      AppPreferencesCompanion.insert(key: key, value: value),
    );
  }
}
