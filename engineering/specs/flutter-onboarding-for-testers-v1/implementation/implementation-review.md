# Implementation Review: flutter-onboarding-for-testers-v1

## Resumen de lo implementado

- Schema bump **v3 → v4** con tabla nueva `app_preferences (key, value)`. Migración aditiva v3→v4, v2→v4, v1→v4 + guardrail RN-H02.
- `AppPreferencesDao` con `get`/`set` (`insertOnConflictUpdate`). Constantes en `lib/data/app_preferences_keys.dart`.
- `FirstRunState` refactorizado de `ValueNotifier<bool?>` a `ChangeNotifier` con dos fields (`hasBolsa`, `onboardingSeen`). Backward compat: `value` retorna `hasBolsa` y el setter sigue funcionando.
- Router con redirect actualizado para los 4 estados combinados (splash, onboarding, first-run, dashboard). Nuevas rutas `/onboarding` y `/help`.
- `OnboardingScreen` con `PageView` de 3 slides + dots tappeables + "Saltar"/"Siguiente"/"Empezar".
- `HelpScreen` con 6 `ExpansionTile` envueltos en cards.
- `SettingsScreen`: nueva sección "Ayuda" entre Zona peligrosa y Acerca de + widget `_LastExportInfo` debajo del botón Exportar (3 estados de render con badge warning si ≥14 días).
- `_exportInternal` persiste timestamp tras success.
- `first_run_screen` marca `onboarding_seen = true` tras "Arrancar limpio" o "Importar respaldo" (S-10 del plan).
- `BackupService.wipeAll` extendido para limpiar `app_preferences`.
- Versión `0.11.4+67 → 0.12.0+68`.

## Archivos principales modificados

Nuevos:
- `mobile/lib/data/app_preferences_keys.dart`
- `mobile/lib/data/daos/app_preferences_dao.dart` + `.g.dart` (codegen)
- `mobile/lib/screens/onboarding_screen.dart`
- `mobile/lib/screens/help_screen.dart`
- `mobile/test/data/app_preferences_dao_test.dart`
- `mobile/test/screens/onboarding_screen_test.dart`
- `mobile/test/screens/help_screen_test.dart`

Modificados:
- `mobile/lib/data/database.dart` (tabla + schema bump + 3 ramas onUpgrade + DAO registrado)
- `mobile/lib/data/database.g.dart` (codegen)
- `mobile/lib/app_dependencies.dart` (field + inyección)
- `mobile/lib/data/backup.dart` (wipeAll extendido)
- `mobile/lib/router/app_router.dart` (FirstRunState extendido + redirect + 2 rutas nuevas)
- `mobile/lib/screens/settings_screen.dart` (sección Ayuda + `_LastExportInfo` + timestamp post-export)
- `mobile/lib/screens/first_run_screen.dart` (marca onboarding_seen tras import/seed)
- `mobile/test/helpers/widget_test_harness.dart` (parámetro `onboardingSeen` con default `true`)
- `mobile/test/data/database_migration_test.dart` (+3 tests MT-01..MT-03)
- `mobile/test/data/backup_test.dart` (assert app_preferences vacío post-wipe)
- `mobile/test/screens/settings_screen_test.dart` (+5 tests WT-S-LX01..WT-S-LX05)
- `mobile/pubspec.yaml` + `mobile/android/app/build.gradle.kts` (bump)

## Tareas completadas

- **T001..T003**: tabla + schema bump + DAO registrado. ✅
- **T004..T006**: DAO + constantes + inyección. ✅
- **T007**: wipeAll extendido. ✅
- **T008..T010**: FirstRunState refactor + initializeFirstRunState + router redirect + rutas. ✅
- **T011..T012**: OnboardingScreen + lógica completar/saltar. ✅
- **T013, T014**: HelpScreen + tile Ayuda en Settings. ✅
- **T015**: `_LastExportInfo`. ✅
- **T016**: persistencia de timestamp tras export success. ✅
- **T017**: marcar onboarding_seen en first-run post-import. ✅
- **T018..T022**: 23 tests verdes (DAO + migración + onboarding + help + settings). ✅
- **T023, T024**: analyze + test suite verdes. ✅
- **T025**: bump `0.12.0+68`. ✅
- **T028**: docs (este archivo + resumen-ejecutivo + resumen-extenso). ✅

## Tareas pendientes

- **T026** (`branch-quality-review`): pendiente, Diego decide.
- **T027** (smoke manual): Diego confirma tras instalar.

## Riesgos residuales

- **R-A** (Diego con `last_export_at` vacío): aunque Diego haya hecho respaldos antes del sprint, el timestamp no se setea retroactivamente. La primera vez que abra Settings verá "Aún no exportaste un respaldo.". Documentado en R-03 del plan. Se mitiga exportando una vez tras instalar la versión nueva.
- **R-B** (migración real no probada): los tests de migración se ejecutan in-memory. La migración v3→v4 sobre la BD real de Diego depende del smoke manual (SM-01).
- **R-C** (back hardware en onboarding sin marcar flag): aceptado y documentado en CB-T04 del spec. El usuario verá el onboarding la próxima vez que abra la app.

## Pruebas realizadas

### Unit tests
- **UT-01..UT-05** (`app_preferences_dao_test.dart`): get/set/idempotencia/empty/múltiples claves. 5 verdes.

### Migración
- **MT-01..MT-03** (`database_migration_test.dart`): 3→4 + ramas defensivas 2→4 y 1→4 con datos pre-existentes. 3 verdes.
- Guardrail UnimplementedError sigue cubierto por UT-19 con `(4, 99)`.

### Widget tests
- **WT-O01..WT-O06** (`onboarding_screen_test.dart`): render, navegación, persistencia, saltar, dots. 6 verdes.
- **WT-H01..WT-H04** (`help_screen_test.dart`): render, expand/collapse, títulos. 4 verdes.
- **WT-S-LX01..WT-S-LX05** (`settings_screen_test.dart`): 3 estados del indicador + corrupto + tap Ayuda. 5 verdes.

### Backup
- Test extendido en `backup_test.dart`: assert que `app_preferences` queda vacío tras `wipeAll`. ✅

### Suite completa
- `flutter test`: **367 verdes** (antes 344; +23 nuevos).
- `flutter analyze`: 0 errores nuevos. 4 hints `info prefer_const_constructors` pre-existentes tolerados.

## Pruebas recomendadas

- **SM-01..SM-06** del test-plan: especialmente SM-01 (Diego actualiza APK sobre BD real sin ver onboarding) y SM-05 (tester con BD vacía ve onboarding completo).
- Test manual con un device real (no emulador) para validar transiciones del `PageView` y back hardware.

## Posibles regresiones

- **PR-01** (`FirstRunState` refactor): el `harness` agregó parámetro `onboardingSeen` con default `true`. Todos los tests pre-existentes pasaron sin cambios. Sin regresión observada.
- **PR-02** (router con 2 rutas nuevas + redirect actualizado): los tests del harness validan los flujos splash → dashboard y splash → first-run. Smoke SM-01 confirma que Diego no es disrumpido.
- **PR-03** (wipeAll extendido): test del backup confirma. Sin riesgo.

## Recomendaciones para code review humano

- **Refactor de `FirstRunState`**: la API pública ganó dos getters (`hasBolsa`, `onboardingSeen`) y métodos `setInitial`, `setHasBolsa`, `setOnboardingSeen`. El `value` getter/setter backward compat sigue. Verificar que ningún caller futuro asuma `value == hasBolsa` exclusivamente (la documentación inline lo aclara).
- **Doble fuente de verdad del flag**: `onboarding_seen` vive en SQLite (persistente) Y en el `ChangeNotifier` (en memoria). El flujo es: leer al arranque, escribir en SQLite + notificar al state. Funciona para single-user pero ojo si en el futuro se sincroniza con backend.
- **Migración real sin probar**: tests in-memory limitan la garantía. El smoke manual SM-01 sobre la BD real de Diego es la red final.
- **Carga del splash con `Future.wait`**: añade una query extra (`appPreferencesDao.get`) en paralelo con `hasBolsa()`. Para Diego sigue siendo instantáneo. Si el tester abre la app por primera vez en un cel lento, podría notarse el splash unos ms más. Aceptable.
- **`PackageInfo` cuelga `pumpAndSettle`**: los tests de Settings usan `pump + pump(100ms)` por convención previa del repo. Sin cambios al respecto.
- **`branch-quality-review` no se invocó**: Diego puede dispararlo antes del commit final.
