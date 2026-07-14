import 'package:drift/drift.dart';
import 'package:fincore/data/app_preferences_keys.dart';
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

  /// Retorna el día de inicio de la semana para el planeador de presupuestos
  /// (ISO 8601: 1=Lunes, 2=Martes, ..., 7=Domingo).
  ///
  /// Lógica defensiva:
  /// - Si la clave no existe → `5` (viernes, default)
  /// - Si el valor no es numérico → `5`
  /// - Si está fuera del rango `[1, 7]` → `5`
  /// - En caso contrario → retorna el int parseado
  ///
  /// Robusto ante BDs corruptas o valores legacy inválidos.
  Future<int> weekStartDow() async {
    final value = await get(kPrefWeekStartDow);
    if (value == null) return 5;
    final parsed = int.tryParse(value);
    if (parsed == null) return 5;
    if (parsed < 1 || parsed > 7) return 5;
    return parsed;
  }

  /// Establece el día de inicio de la semana para el planeador de presupuestos.
  ///
  /// `dow` debe estar en el rango `[1, 7]` (ISO 8601).
  Future<void> setWeekStartDow(int dow) async {
    assert(dow >= 1 && dow <= 7, 'week_start_dow debe estar en [1,7] ISO 8601');
    await set(kPrefWeekStartDow, dow.toString());
  }
}
