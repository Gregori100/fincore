# Plan técnico — flutter-onboarding-for-testers-v1

## Enfoque técnico

- **Schema bump v3 → v4** con tabla `app_preferences (key TEXT PK, value TEXT)`. Aditivo, no destructivo. Migración explícita + ramas defensivas + guardrail `UnimplementedError`, siguiendo RN-H02 del repo.
- **Patrón DAO**: nuevo `AppPreferencesDao` con `@DriftAccessor` siguiendo la convención existente (`SavedViewsDao` como referencia).
- **Estado de arranque**: extender `FirstRunState` para incluir `onboardingSeen` además del `hasBolsa` existente. Reemplazar el `ValueNotifier<bool?>` actual por un `ChangeNotifier` con dos `bool?` (o un wrapper). El router consume ambos en el `redirect` callback.
- **Router**: nueva ruta `/onboarding` antes de `/first-run`. Redirect lógico:
  - `hasBolsa == null || onboardingSeen == null` → `/splash` (chequeo pendiente).
  - `hasBolsa == true` → `/dashboard` (Diego o tester con datos importados).
  - `hasBolsa == false && onboardingSeen == false` → `/onboarding`.
  - `hasBolsa == false && onboardingSeen == true` → `/first-run`.
- **Onboarding**: `OnboardingScreen` con `PageView` horizontal de 3 slides. `PageController` para navegación bidireccional. `SmoothPageIndicator` NO es dep nueva — hacemos los dots manualmente con `Row` + `Container` circulares pequeños. Botón "Saltar" en top-right (`AppBar.actions`). Botón principal en bottom: "Siguiente" (slides 1-2) / "Empezar" (slide 3).
- **Help**: `HelpScreen` con `ListView` scrolleable de 6 `ExpansionTile`. Textos hardcoded en español. Estilo coherente con `BaseCard` (cada `ExpansionTile` envuelto en card para visual de cuerpo expandible).
- **Backup recordatorio**: nuevo widget privado `_LastExportInfo` en `settings_screen.dart`. `FutureBuilder<String?>` que lee `last_export_at` del DAO en `didChangeDependencies`. Cálculo de días en Dart con `DateTime.now().difference(parsed)`. 3 estados de render según RN-A07.
- **Persistencia del timestamp**: `_exportInternal` (en `settings_screen.dart`) ya retorna `bool exported`. Cuando `success`, llamar `appPreferencesDao.set(kPrefLastExportAt, DateTime.now().toIso8601String())` antes del `return true`.
- **Wipe**: extender `BackupService._wipeTablesInternal` para incluir `_db.delete(_db.appPreferences).go()` dentro de la misma transacción. Mismo patrón que `saved_views`.
- **`app_preferences` NO se serializa en backup JSON v1**: son estado de UI, no datos del usuario. Misma decisión que `saved_views`.

## Requisitos funcionales cubiertos

- **RF-001** (tabla SQLite): `class AppPreferences extends Table` + `schemaVersion: 3 → 4` + nueva rama en `onUpgrade` + ramas defensivas 1→4 y 2→4. Guardrail preservado.
- **RF-002** (DAO): `AppPreferencesDao` con `get(key)` y `set(key, value)`. `set` usa `INSERT OR REPLACE INTO app_preferences (key, value) VALUES (?, ?)` vía `customStatement` o `into(appPreferences).insertOnConflictUpdate(...)`.
- **RF-003** (constantes): nuevo archivo `lib/data/app_preferences_keys.dart` con `const String kPrefOnboardingSeen = 'onboarding_seen';` y `const String kPrefLastExportAt = 'last_export_at';`.
- **RF-004 / RF-005 / RF-006** (Onboarding pantalla y slides): `OnboardingScreen` stateful con `PageController`, 3 widgets privados `_Slide1`/`_Slide2`/`_Slide3`, indicador de dots, botón "Saltar" / "Siguiente" / "Empezar".
- **RF-007** (persistir + navegar): al completar/saltar, `await deps.appPreferencesDao.set(kPrefOnboardingSeen, 'true')` + `firstRunState.markOnboardingSeen()` + `context.go(...)`.
- **RF-008** (ruta `/onboarding`): nueva entrada en `routes` del router + actualización del `redirect` callback.
- **RF-009** (FirstRunState extendido): cambia de `ValueNotifier<bool?>` a `ChangeNotifier` con dos fields (`hasBolsa`, `onboardingSeen`) y método `notifyListeners()` manual tras cada cambio. Alternativa: mantener `ValueNotifier<BootstrapState>` con clase wrapper inmutable. Voto: opción 1 (más simple, sin clase extra). Backward compat: API pública mantiene `value` para `hasBolsa` (renombrado a `hasBolsa` getter).
- **RF-010** (HelpScreen): `lib/screens/help_screen.dart` con 6 `ExpansionTile` en `ListView`. Textos en español, 1-3 párrafos cada uno, redactados para tono didáctico.
- **RF-011** (ruta `/help`): nueva entrada en router.
- **RF-012** (entrada en Settings): nueva `BaseCard` con icono `Icons.help_outline`, label "Ayuda", subtítulo "FAQ sobre kinds, reportes y backup". Tap → `context.push('/help')`. Ubicada en la sección "Acerca de" o nueva sección "Ayuda" — voto: nueva sección dedicada justo encima de "Acerca de" para claridad.
- **RF-013** (widget `_LastExportInfo`): `FutureBuilder<String?>` con `appPreferencesDao.get(kPrefLastExportAt)`. Cálculo en Dart, 3 estados render.
- **RF-014** (actualizar timestamp tras export success): integrar `appPreferencesDao.set(kPrefLastExportAt, ...)` en `_exportInternal` después del `result.status == ShareResultStatus.success`.
- **RF-015** (wipeAll extendido): agregar línea en `_wipeTablesInternal` para borrar `app_preferences`.
- **RF-016 / RF-017 / RF-018 / RF-019** (tests): cobertura por archivos nuevos `test/data/app_preferences_dao_test.dart`, extensiones a `test/data/database_migration_test.dart` (rama v3→v4), nuevos widget tests `test/screens/onboarding_screen_test.dart`, `test/screens/help_screen_test.dart`, extensión a `test/screens/settings_screen_test.dart`.

## Archivos o módulos probablemente afectados

### Nuevos

- `mobile/lib/data/app_preferences_keys.dart` — constantes.
- `mobile/lib/data/daos/app_preferences_dao.dart` — DAO + `@DriftAccessor`.
- `mobile/lib/screens/onboarding_screen.dart` — pantalla nueva con `PageView`.
- `mobile/lib/screens/help_screen.dart` — pantalla nueva con `ExpansionTile`.
- `mobile/test/data/app_preferences_dao_test.dart` — tests DAO.
- `mobile/test/screens/onboarding_screen_test.dart` — widget tests.
- `mobile/test/screens/help_screen_test.dart` — widget tests.

### Modificados

- `mobile/lib/data/database.dart` — tabla `AppPreferences`, schema v4, DAO registrado, migración v3→v4 + ramas defensivas v1→v4 y v2→v4.
- `mobile/lib/app_dependencies.dart` — field nuevo + inyección de `appPreferencesDao`.
- `mobile/lib/data/backup.dart` — `_wipeTablesInternal` extendido.
- `mobile/lib/router/app_router.dart` — `FirstRunState` extendido + `redirect` actualizado + ruta `/onboarding` y `/help`.
- `mobile/lib/data/bootstrap.dart` — `initializeFirstRunState` extendido para cargar también `onboarding_seen`.
- `mobile/lib/screens/settings_screen.dart` — entrada "Ayuda" + widget `_LastExportInfo` + actualización de `_exportInternal`.
- `mobile/lib/screens/first_run_screen.dart` — POSIBLE: si el "import respaldo" debe marcar onboarding como visto (ver R-02 + supuesto S-10 nuevo abajo). Decisión: SÍ, marcar `onboarding_seen = true` tras import exitoso para evitar que el tester vea onboarding después de importar.
- `mobile/test/data/database_migration_test.dart` — rama v3→v4 + ramas defensivas + assert guardrail.
- `mobile/test/screens/settings_screen_test.dart` — agregar tests del widget `_LastExportInfo` con 3 estados.
- `mobile/test/helpers/widget_test_harness.dart` — POSIBLE: si necesita exponer `appPreferencesDao` directamente. Probable que sí, agregar al harness para los widget tests del Onboarding.
- `mobile/pubspec.yaml` + `mobile/android/app/build.gradle.kts` — bump `0.11.4+67 → 0.12.0+68` (minor por feature visible significativo: schema bump + nueva pantalla de arranque).

## Entidades y estados afectados

- **Tabla `app_preferences`** (nueva): `key TEXT PRIMARY KEY NOT NULL`, `value TEXT NOT NULL`. Persistencia simple key/value. Estado mutable por aplicación. Sin FK, sin timestamps, sin soft delete.
- **`FirstRunState`** (modificada): de `ValueNotifier<bool?>` con un solo valor → a `ChangeNotifier` con dos fields nulables (`hasBolsa`, `onboardingSeen`). Transición: `null` (chequeando) → `bool`. El router observa ambos y redirige según combinaciones.
- **`hasBolsa()` ya existente**: sin cambios. Sigue siendo el chequeo único para "hay datos del usuario".
- **`onboarding_seen`**: bool persistente con valores `'true'` o ausente (no se persiste `false`). Set una vez al saltar/completar el onboarding. Borrado por `wipeAll`.
- **`last_export_at`**: string ISO 8601 persistente. Set tras cada export exitoso (overwrite). Borrado por `wipeAll`.

## Compatibilidad con datos y procesos existentes

- **Migración v3 → v4**: aditiva, no toca datos del usuario. Crea solo la tabla nueva. Tests de migración blindarán que cuentas/categorías/entries/saved_views existentes sobreviven al upgrade.
- **Ramas defensivas v1 → v4 y v2 → v4**: combinan las migraciones intermedias para usuarios que se saltaron versiones. Guardrail `UnimplementedError` se mantiene al final.
- **Backup JSON v1**: NO cambia. `app_preferences` queda excluido del export. Los respaldos existentes siguen importándose sin romperse. Los respaldos nuevos no rompen lecturas viejas.
- **Diego (con Bolsa)**: el `redirect` lo manda directo a `/dashboard`. No ve onboarding. Su `last_export_at` puede estar vacío (porque no se setea retroactivamente) — la primera vez que abra Settings verá "Aún no exportaste un respaldo." aunque tenga uno reciente. Aceptable (es feedback más conservador), pero se documenta como R-03.
- **Importar respaldo viejo en versión nueva**: el JSON v1 no tiene `app_preferences`. Tras import, `hasBolsa = true` y `onboarding_seen` queda en estado previo. Si el tester importó respaldo viejo en una BD nueva, `onboarding_seen` aún es `false`, pero `hasBolsa = true` lo manda a dashboard (no onboarding). Decisión: marcamos `onboarding_seen = true` al confirmar import exitoso para mantener consistencia con la lógica de "ya estás en uso".

## Cambios de datos

- **Schema bump v3 → v4**: aditivo. Nueva tabla `app_preferences`.
- **Sin DROP, sin ALTER de columnas existentes.**
- **Sin seed de datos**: las preferencias arrancan vacías y se setean conforme el usuario interactúa.

## Cambios de UI

- Nueva pantalla `OnboardingScreen` (3 slides con PageView).
- Nueva pantalla `HelpScreen` (6 ExpansionTile).
- Nueva entrada "Ayuda" en `SettingsScreen`, ubicada como nueva sección entre "Zona peligrosa" y "Acerca de".
- Nuevo widget `_LastExportInfo` en `SettingsScreen` (sección "Respaldo").
- Sin cambios en dashboard, /entries, /reports, /categories, /accounts.

## Cambios de API

No aplica (sin HTTP).

API pública del data layer:

- `AppPreferencesDao.get(String key) → Future<String?>`.
- `AppPreferencesDao.set(String key, String value) → Future<void>`.
- `AppDependencies.appPreferencesDao` (nuevo getter).
- `FirstRunState` ahora con dos fields: `bool? hasBolsa`, `bool? onboardingSeen`. Métodos: `markOnboardingSeen()`, `markFirstRunComplete()` (existente).

## Riesgos técnicos

- **R-01 (schema bump)**: segundo schema bump del MVP. Si la migración v3→v4 falla en un cel real, queda app inservible. Mitigación: rama explícita + tests in-memory + smoke manual sobre BD real de Diego antes de distribuir.
- **R-02 (FirstRunState refactor)**: cambiar de `ValueNotifier<bool?>` a `ChangeNotifier` con dos fields es cambio invasivo. Hay tests existentes del router/harness que dependen de la API actual. Mitigación: mantener un getter `value` que retorne `hasBolsa` para compat backward, y agregar `onboardingSeen` como nuevo getter.
- **R-03 (Diego con `last_export_at` vacío)**: Diego ya tiene respaldos hechos antes de este sprint pero el timestamp NO se setea retroactivamente. La primera vez que abra Settings verá "Aún no exportaste un respaldo.". Aceptable; documentado en spec. Se podría mitigar exportando una vez tras instalar la nueva versión.
- **R-04 (delay extra al splash)**: cargar `onboarding_seen` agrega una segunda query al splash. Para Diego, el splash debe seguir siendo instantáneo. Mitigación: ejecutar `hasBolsa()` y `appPreferencesDao.get(kPrefOnboardingSeen)` en paralelo con `Future.wait`.
- **R-05 (texto del Ayuda desactualizado)**: los textos del FAQ describen features actuales (sugerencia v2.1, monthly average, etc). Si en el futuro cambian, hay que actualizar. Sin i18n, es directo. Documentar en `clarificaciones.md` futuro.
- **R-06 (back hardware en onboarding)**: si el tester presiona back, se cierra la app o vuelve al splash. NO marca `onboarding_seen`. Comportamiento aceptable y testeable.
- **R-07 (importar respaldo viejo)**: tras import en BD nueva, marcar `onboarding_seen = true` para evitar inconsistencia. Documentado en S-10 del plan.

## Estrategia de pruebas

- **Unit tests DAO**: round-trip de `AppPreferencesDao.get/set`, idempotencia de `set` (insert vs update), null cuando la clave no existe.
- **Tests de migración**: rama explícita v3→v4 + ramas defensivas v1→v4 y v2→v4. Assert guardrail dispara con `UnimplementedError` para combinaciones no implementadas (e.g. v3→v99).
- **Widget tests del Onboarding**: render de los 3 slides, navegación con "Siguiente", "Saltar" desde slide 1, "Empezar" desde slide 3, persistencia del flag, navegación al destino correcto.
- **Widget tests del Help**: render de los 6 ExpansionTile, expansión de uno, contenido visible.
- **Widget tests del SettingsScreen**: 3 estados del `_LastExportInfo` (nunca, <14 días, ≥14 días).
- **Test de regresión del wipeAll**: tras `wipeAll`, `app_preferences` queda vacía y `onboarding_seen` vuelve a no existir.
- **Smoke manual**: Diego instala el APK sobre su BD real → no ve onboarding, ve Ayuda y línea de backup en Settings. Tester nuevo instala sobre BD vacía → ve onboarding, lo completa, llega a first-run.

Detalle completo en `test-plan.md`.

## Estrategia de rollback

- **Revert simple**: el sprint agrega 7 archivos nuevos + modifica 8. Un `git revert` deja la app como antes.
- **Schema downgrade**: no soportado por drift. Si un tester instala v4 y luego intenta volver a v3, la app va a crashear al abrir (drift detecta `user_version` mayor). Para downgrade real, requiere wipe + reinstall. Documentar en `pendientes.md` del sprint si aplica.
- **Recuperar datos en caso de bug grave**: el backup JSON v1 sigue funcionando idéntico. Diego puede exportar antes de instalar, y si v4 rompe algo, reinstala v3, importa el JSON.

## Orden sugerido de implementación

1. **Backend / Data layer** primero:
   - Tabla `AppPreferences` + schema bump + migración.
   - DAO + constantes.
   - Inyección en `AppDependencies`.
   - Extensión de `_wipeTablesInternal`.
   - Tests DAO + migración.
2. **State / Router**:
   - `FirstRunState` extendido con `onboardingSeen`.
   - `initializeFirstRunState` extendido (carga en paralelo).
   - Router: nueva ruta `/onboarding` + redirect actualizado.
3. **Frontend**:
   - `OnboardingScreen`.
   - `HelpScreen`.
   - `SettingsScreen` extendido (tile Ayuda + `_LastExportInfo` + update `_exportInternal`).
   - `FirstRunScreen` extendido (marcar `onboarding_seen = true` tras import).
4. **Tests UI**.
5. **Bump versión + analyze + test final**.
6. **`branch-quality-review`**.
7. **Smoke manual**.

Detalle en `tasks.md`.

## Casos borde que condicionan la solución

Casos que requieren atención en la implementación, no solo en testing:

- **CB-T01 (tabla no existe)**: `AppPreferencesDao.get` debe envolverse en try/catch defensivo que retorne `null` si la tabla no existe. Más seguro que confiar en que la migración corrió bien.
- **CB-T02 (parse falla)**: el render del `_LastExportInfo` debe tratar `DateTime.tryParse` que retorna `null` como "nunca exportado". No usar `DateTime.parse` que lanza.
- **CB-T05 (clock en el futuro)**: `difference.inDays` puede ser negativo. Si lo es, tratar como `0`. Evitar mostrar números negativos.
- **CB-T07 (Diego ya con Bolsa)**: el router redirige a dashboard sin tocar `onboarding_seen`. Su valor queda en `false`. Si Diego en el futuro hace `Reiniciar cuenta`, verá onboarding como un tester nuevo. Comportamiento esperado (`wipeAll` resetea todo).
- **Race del splash**: si `hasBolsa` resuelve antes que `onboardingSeen`, el `ChangeNotifier` notifica con un estado parcial. El `redirect` debe trabajar solo cuando ambos son no-null. Mitigación: condicionar a `hasBolsa != null && onboardingSeen != null`.

## Preguntas o supuestos que siguen afectando la implementación

No hay preguntas `pendiente` — la spec cerró todas las decisiones como supuestos (S-01..S-09).

Supuestos del plan que vale la pena registrar:

- **SP-01**: `FirstRunState` se refactoriza a `ChangeNotifier` con dos fields (no `ValueNotifier<wrapper>`). Razón: API más simple, sin clase wrapper extra. Tests existentes del harness siguen funcionando con compat backward (getter `value` retorna `hasBolsa`).
- **SP-02**: `AppPreferencesDao.set` usa `insertOnConflictUpdate` de drift (no `customStatement` con `INSERT OR REPLACE`). Razón: aprovecha la API tipada del codegen.
- **SP-03**: dots del onboarding se hacen manualmente con `Row` + `Container` (no `smooth_page_indicator`). Razón: sin dep nueva, control fino del color.
- **SP-04**: `_LastExportInfo` usa `FutureBuilder` (no `StreamBuilder`). Razón: el valor cambia raramente; recargar al volver a Settings es aceptable. Si en el futuro queremos reactividad inmediata tras un export sin recargar Settings, migramos a stream.
- **SP-05**: el ChangeNotifier `FirstRunState` notifica una sola vez tras cargar ambos campos en paralelo. Razón: evita "destellos" de transición en el router.
- **SP-06**: SP nuevo (S-10 en spec): tras importar respaldo en first-run, marcar `onboarding_seen = true` para mantener consistencia con "usuario que ya tiene datos".
- **SP-07**: el FAQ tiene 6 secciones según RF-010, pero el orden propuesto puede ajustarse en implementación si encontramos mejor flujo narrativo. No es contractual.
