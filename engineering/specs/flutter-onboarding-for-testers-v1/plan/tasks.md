# Tasks — flutter-onboarding-for-testers-v1

Tareas en orden de dependencia. IDs estables `T001`, `T002`, ...

## Base de datos

- [ ] **T001 BD**: agregar tabla `AppPreferences` en `mobile/lib/data/database.dart` con `TextColumn get key => text()();`, `TextColumn get value => text()();`, `primaryKey = {key}`.
  RF: RF-001
  Depende de: ninguna
  Paralelizable: no
  Criterio de terminado: tabla declarada con `@DataClassName('AppPreferenceRow')` (para no chocar con potencial clase pública). `flutter analyze` limpio.

- [ ] **T002 BD**: bumpear `schemaVersion` de 3 a 4 en `database.dart`. Agregar rama explícita `if (from == 3 && to == 4) { await m.createTable(appPreferences); return; }` en `onUpgrade`. Agregar ramas defensivas `if (from == 2 && to == 4) { ... }` y `if (from == 1 && to == 4) { ... }` que combinen migraciones intermedias. El guardrail `UnimplementedError` queda intacto al final.
  RF: RF-001
  Depende de: T001
  Paralelizable: no
  Criterio de terminado: `flutter analyze` limpio. Schema bump comentado en el archivo con referencia al sprint.

- [ ] **T003 BD**: registrar `AppPreferencesDao` en `@DriftDatabase(daos: [...])` de `database.dart`.
  RF: RF-002
  Depende de: T001, T004
  Paralelizable: no
  Criterio de terminado: codegen corre, `database.g.dart` se actualiza, `database.appPreferencesDao` accesible.

## Backend (data layer)

- [ ] **T004 Backend**: crear `mobile/lib/data/daos/app_preferences_dao.dart` con `class AppPreferencesDao extends DatabaseAccessor<FincoreDatabase> with _$AppPreferencesDaoMixin`. Métodos `Future<String?> get(String key)` y `Future<void> set(String key, String value)` con `insertOnConflictUpdate`.
  RF: RF-002
  Depende de: T001
  Paralelizable: sí (con T005)
  Criterio de terminado: DAO compila. UT-01..UT-05 listos para correr.

- [ ] **T005 Backend**: crear `mobile/lib/data/app_preferences_keys.dart` con constantes `kPrefOnboardingSeen = 'onboarding_seen'` y `kPrefLastExportAt = 'last_export_at'`. Documentación inline breve.
  RF: RF-003
  Depende de: ninguna
  Paralelizable: sí
  Criterio de terminado: archivo creado. Importable desde el resto del código.

- [ ] **T006 Backend**: agregar `final AppPreferencesDao appPreferencesDao;` a `mobile/lib/app_dependencies.dart`. Inyectar en `AppDependencies.fromDatabase()` como `database.appPreferencesDao`.
  RF: RF-002
  Depende de: T003
  Paralelizable: no
  Criterio de terminado: compila. Accesible vía `AppDependencies.of(context).appPreferencesDao`.

- [ ] **T007 Backend**: extender `_wipeTablesInternal` de `mobile/lib/data/backup.dart` para agregar `await _db.delete(_db.appPreferences).go();` dentro de la transacción.
  RF: RF-015
  Depende de: T001
  Paralelizable: sí (con T004, T005)
  Criterio de terminado: `wipeAll` borra `app_preferences`. Test extendido pasa.

## State / Router

- [ ] **T008 Router**: refactorizar `FirstRunState` en `mobile/lib/router/app_router.dart` de `ValueNotifier<bool?>` a `ChangeNotifier` con dos campos `bool? _hasBolsa` y `bool? _onboardingSeen`, getters públicos y métodos `setHasBolsa(bool)`, `setOnboardingSeen(bool)`, `markFirstRunComplete()`. Mantener getter `value` para compat backward (retorna `_hasBolsa`).
  RF: RF-009
  Depende de: ninguna
  Paralelizable: no
  Criterio de terminado: compila. Tests existentes del harness siguen verdes (compat backward).

- [ ] **T009 Router**: extender `initializeFirstRunState` en `mobile/lib/data/bootstrap.dart` para cargar `hasBolsa` y `onboarding_seen` en paralelo con `Future.wait`. Setear ambos en el state.
  RF: RF-009
  Depende de: T006, T008
  Paralelizable: no
  Criterio de terminado: splash carga ambos campos antes de notificar.

- [ ] **T010 Router**: agregar ruta `/onboarding` y `/help` en `app_router.dart`. Actualizar el callback `redirect` para considerar `onboardingSeen`: si `!hasBolsa && !onboardingSeen` → `/onboarding`; si `!hasBolsa && onboardingSeen` → `/first-run`; el resto sin cambios.
  RF: RF-008, RF-011
  Depende de: T008, T013, T014
  Paralelizable: no
  Criterio de terminado: rutas registradas. Redirect cubre los 4 estados del CB-D07/D08/D09/D11.

## Frontend

- [ ] **T011 Frontend**: crear `mobile/lib/screens/onboarding_screen.dart` con `OnboardingScreen` stateful. `PageController`, `int _currentPage = 0`, 3 widgets privados `_Slide1`, `_Slide2`, `_Slide3`. Layout: AppBar transparente con botón "Saltar" en `actions`. Body: `PageView` con los 3 slides. Bottom: `Row` con dots (3 `Container` circulares) + `FilledButton` "Siguiente"/"Empezar".
  RF: RF-004, RF-005, RF-006
  Depende de: T005
  Paralelizable: sí (con T012)
  Criterio de terminado: pantalla renderea 3 slides. Swipe + tap en dots + botón Siguiente funcionan.

- [ ] **T012 Frontend**: implementar lógica de "Saltar" y "Empezar" en `OnboardingScreen`:
  - `_onSkip()`: `await deps.appPreferencesDao.set(kPrefOnboardingSeen, 'true'); firstRunState.setOnboardingSeen(true); context.go(target)` donde `target` es `/first-run` si `!hasBolsa` o `/dashboard` si `hasBolsa`.
  - `_onStart()`: idéntico a `_onSkip` pero solo accesible desde slide 3.
  - `_onNext()`: avanzar `PageController` a la siguiente página.
  RF: RF-007
  Depende de: T011, T006, T008
  Paralelizable: no
  Criterio de terminado: WT-O04 + WT-O05 verdes.

- [ ] **T013 Frontend**: crear `mobile/lib/screens/help_screen.dart` con `HelpScreen` stateless. AppBar con título "Ayuda" + back. Body: `ListView` con 6 `ExpansionTile` envueltos en `BaseCard`. Textos hardcoded en español según RF-010. Estilo coherente con `FincoreColors`.
  RF: RF-010, RF-011
  Depende de: ninguna
  Paralelizable: sí (con T011, T012)
  Criterio de terminado: pantalla renderea 6 secciones, expansión/colapso funciona.

- [ ] **T014 Frontend**: agregar entrada "Ayuda" en `mobile/lib/screens/settings_screen.dart` justo encima de la sección "Acerca de". Nueva `SectionTitle('Ayuda')` + `BaseCard` con icono `Icons.help_outline`, label "Ayuda", subtítulo "FAQ sobre kinds, reportes y backup", `onTap: () => context.push('/help')`.
  RF: RF-012
  Depende de: T013
  Paralelizable: sí (con T011..T013)
  Criterio de terminado: entrada visible en Settings. Navegación funciona.

- [ ] **T015 Frontend**: implementar widget privado `_LastExportInfo` en `settings_screen.dart`. `FutureBuilder<String?>` que llama `deps.appPreferencesDao.get(kPrefLastExportAt)` en `didChangeDependencies`. Render condicional:
  - `null` o `DateTime.tryParse(value) == null`: "Aún no exportaste un respaldo." en `textSubtle`.
  - `daysAgo < 14`: "Último respaldo: hace X días." en `textSubtle`.
  - `daysAgo >= 14`: chip con `Icons.warning_amber_rounded` + texto "Último respaldo: hace X días — te recomendamos exportar pronto." en color `warning`.
  - `daysAgo < 0` (clock futuro): tratar como `0`.
  - Ubicado debajo del botón "Exportar respaldo" en la sección "Respaldo".
  RF: RF-013, RN-O06, RN-O07, CB-T05
  Depende de: T006
  Paralelizable: sí (con T011..T014)
  Criterio de terminado: WT-S-LX01..WT-S-LX04 verdes.

- [ ] **T016 Frontend**: integrar persistencia del timestamp en `_exportInternal` de `settings_screen.dart`. Tras `result.status == ShareResultStatus.success`, llamar `await deps.appPreferencesDao.set(kPrefLastExportAt, DateTime.now().toIso8601String())`.
  RF: RF-014, RN-O08
  Depende de: T006
  Paralelizable: sí (con T011..T015)
  Criterio de terminado: tras export exitoso, el widget `_LastExportInfo` muestra "hace 0 días" al refrescar Settings.

- [ ] **T017 Frontend**: tras import exitoso en `first_run_screen.dart`, marcar `onboarding_seen = true` para evitar inconsistencia (S-10 del spec). Llamar `await deps.appPreferencesDao.set(kPrefOnboardingSeen, 'true')` antes de `markFirstRunComplete`.
  RF: SP-06, S-10
  Depende de: T006
  Paralelizable: sí
  Criterio de terminado: tras importar respaldo, el usuario no ve onboarding al volver a abrir la app.

## Pruebas

- [ ] **T018 Pruebas**: crear `mobile/test/data/app_preferences_dao_test.dart` con UT-01..UT-05.
  RF: RF-016
  Depende de: T003, T004
  Paralelizable: sí
  Criterio de terminado: 5 tests verdes.

- [ ] **T019 Pruebas**: extender `mobile/test/data/database_migration_test.dart` con MT-01..MT-05 (v3→v4, ramas defensivas, guardrail, wipeAll borra `app_preferences`).
  RF: RF-017
  Depende de: T002
  Paralelizable: sí
  Criterio de terminado: 5 tests verdes.

- [ ] **T020 Pruebas**: crear `mobile/test/screens/onboarding_screen_test.dart` con WT-O01..WT-O07. Reusar `pumpFincoreApp` con `seedBolsa: false`.
  RF: RF-018
  Depende de: T011, T012
  Paralelizable: no
  Criterio de terminado: 7 widget tests verdes.

- [ ] **T021 Pruebas**: crear `mobile/test/screens/help_screen_test.dart` con WT-H01..WT-H04.
  RF: RF-018
  Depende de: T013
  Paralelizable: sí (con T020)
  Criterio de terminado: 4 widget tests verdes.

- [ ] **T022 Pruebas**: extender `mobile/test/screens/settings_screen_test.dart` con WT-S-LX01..WT-S-LX05.
  RF: RF-019
  Depende de: T014, T015
  Paralelizable: sí (con T020, T021)
  Criterio de terminado: 5 widget tests verdes.

## Validación de calidad

- [ ] **T023 Validación**: `flutter analyze` con 0 errores nuevos. 4 hints `info` pre-existentes siguen tolerados.
  Depende de: T001..T022
  Paralelizable: no
  Criterio de terminado: salida limpia.

- [ ] **T024 Validación**: `flutter test` verde con la suite completa (~360 tests esperados).
  Depende de: T001..T022
  Paralelizable: no
  Criterio de terminado: "All tests passed!".

- [ ] **T025 Validación**: bump de versión en `mobile/pubspec.yaml` (`0.11.4+67 → 0.12.0+68`) y `mobile/android/app/build.gradle.kts` (`versionCode = 68`, `versionName = "0.12.0"`).
  Depende de: T023, T024
  Paralelizable: no
  Criterio de terminado: ambos archivos sincronizados. `scripts/verify-apk.sh` pasa.

- [ ] **T026 Validación**: invocar skill `branch-quality-review` con argumento `flutter-onboarding-for-testers-v1`. Atender hallazgos Altas/Críticas antes del commit final.
  Depende de: T025
  Paralelizable: no
  Criterio de terminado: reporte generado, hallazgos atendidos.

- [ ] **T027 Validación**: smoke manual SM-01..SM-05 (Diego confirma).
  Depende de: T025
  Paralelizable: sí (con T026)
  Criterio de terminado: Diego confirma "todo OK" sobre BD real.

## Documentación

- [ ] **T028 Documentación**: crear `engineering/specs/flutter-onboarding-for-testers-v1/implementation/implementation-review.md`, `resumen-ejecutivo.md`, `resumen-extenso.md` con el formato estándar del repo.
  Depende de: T023, T024
  Paralelizable: sí (con T026, T027)
  Criterio de terminado: 3 archivos creados con contenido real.
