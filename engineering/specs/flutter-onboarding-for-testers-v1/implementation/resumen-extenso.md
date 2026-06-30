# Resumen extenso — flutter-onboarding-for-testers-v1

## Contexto

Diego pidió compartir el APK con amigos como beta testers. Hasta ese momento, la app estaba optimizada para él (que conoce el dominio, los kinds, el modelo de balance derivado). Un usuario nuevo se encontraba con un first-run minimalista ("Importar respaldo" / "Arrancar limpio") sin contexto previo. La spec definió 3 features (descartando "reportar bugs por email" que Diego rechazó para no exponer contactos personales).

### Decisiones de la spec

Sin preguntas bloqueantes: las decisiones se cerraron como supuestos:
- **S-01**: persistencia con tabla SQLite `app_preferences` (no `shared_preferences`). Consistente con el data layer + sin dep nueva + posibilidad de incluir o excluir del backup.
- **S-02**: `app_preferences` NO se serializa en backup JSON v1 (estado de UI, no datos del usuario).
- **S-04**: 3 slides en el onboarding.
- **S-07**: umbral 14 días para warning de backup.
- **S-10**: tras `import respaldo` en first-run, marcar también `onboarding_seen = true` (consistencia).

## Relación con el plan

El plan técnico (`plan/plan.md`) definió:
- Schema bump v3 → v4 con migración aditiva + ramas defensivas v2→v4 y v1→v4 + guardrail RN-H02.
- DAO nuevo con `insertOnConflictUpdate`.
- `FirstRunState` refactorizado de `ValueNotifier<bool?>` a `ChangeNotifier` con 2 fields.
- `Future.wait` paralelo en `initializeFirstRunState` para no degradar el splash de Diego.
- 3 pantallas nuevas o modificadas + `_LastExportInfo` widget.

La implementación siguió el plan **al pie de la letra**, con dos desviaciones menores:
- **DV-01**: el harness agrega parámetro `onboardingSeen` con default `true` en lugar de obligar a setearlo en cada test. Permite backward compat sin tocar los 344 tests existentes.
- **DV-02**: el botón "Ayuda" en Settings muestra "Ayuda" como label (con el SectionTitle también "Ayuda" justo arriba). Tests deben distinguir entre ambos (find con `.last` o por subtítulo).

## Cambios principales por módulo o capa

### Data layer (`mobile/lib/data/`)

- **Tabla nueva `AppPreferences`** en `database.dart`: 2 columnas, sin timestamps. `@DataClassName('AppPreferenceRow')` para no chocar con un potencial modelo público.
- **Schema bump v3 → v4** + 3 ramas en `onUpgrade` (3→4, 2→4, 1→4) + guardrail intacto.
- **DAO nuevo** `AppPreferencesDao` con `@DriftAccessor(tables: [AppPreferences])` + `get` con `getSingleOrNull` + `set` con `insertOnConflictUpdate`.
- **Constantes** `kPrefOnboardingSeen` y `kPrefLastExportAt` en `app_preferences_keys.dart`.
- **BackupService** `_wipeTablesInternal` extendido con `_db.delete(_db.appPreferences).go()`.

### Router (`mobile/lib/router/app_router.dart`)

- `FirstRunState` refactorizado a `ChangeNotifier` con `_hasBolsa` y `_onboardingSeen`. Métodos `setInitial`, `setHasBolsa`, `setOnboardingSeen`. Backward compat `value` getter/setter.
- `initializeFirstRunState` usa `Future.wait` paralelo y notifica una sola vez.
- `redirect` callback maneja 4 combinaciones.
- 2 rutas nuevas: `/onboarding` y `/help`.

### Pantallas (`mobile/lib/screens/`)

- **`onboarding_screen.dart`** (nuevo): `PageView` + `PageController` + dots tappeables + botones "Saltar"/"Siguiente"/"Empezar". 3 widgets privados de slides usando `FincoreLogo` y `Icons` del Material.
- **`help_screen.dart`** (nuevo): `ListView` de 6 `ExpansionTile` envueltos en `Container` con borde, textos hardcoded en español.
- **`settings_screen.dart`** (modificado): nueva sección "Ayuda" entre "Zona peligrosa" y "Acerca de", widget `_LastExportInfo` con 3 estados de render (nunca/<14d/≥14d), `_exportInternal` setea `last_export_at` tras success.
- **`first_run_screen.dart`** (modificado): `_completeAndGo` ahora es async y marca `onboarding_seen = true` antes de notificar al state.

### Tests

- **DAO** (`app_preferences_dao_test.dart`): 5 UT.
- **Migración** (`database_migration_test.dart`): +3 MT (3→4, 2→4 defensiva, 1→4 defensiva).
- **Backup** (`backup_test.dart`): assert extendido para `app_preferences` vacío post-wipe.
- **Harness** (`widget_test_harness.dart`): parámetro `onboardingSeen` con default `true`.
- **Onboarding** (`onboarding_screen_test.dart`): 6 WT.
- **Help** (`help_screen_test.dart`): 4 WT.
- **Settings** (`settings_screen_test.dart`): +5 WT (3 estados del indicador + corrupto + tap Ayuda).

## Desviaciones respecto al plan

- **DV-01**: harness con parámetro `onboardingSeen` default `true`. Razón: minimizar disrupción de tests existentes.
- **DV-02**: tap del "Ayuda" en Settings se ata al subtítulo "FAQ sobre kinds, reportes y backup." para evitar ambigüedad con el SectionTitle. Razón: ambos tienen "Ayuda" como texto.
- **Versión**: el plan proponía `0.12.0+68`. Implementado tal cual.

## Pruebas realizadas

Ver `implementation-review.md` sección "Pruebas realizadas". Total: 367/367 verdes (antes 344; +23 nuevos).

## Riesgos residuales y posibles regresiones

Ver `implementation-review.md` secciones "Riesgos residuales" y "Posibles regresiones".

Resumen:
- Migración real solo cubierta por tests in-memory. Smoke manual sobre BD de Diego es la red.
- `last_export_at` vacío para Diego al actualizar (esperado, documentado).
- `FirstRunState` refactor con backward compat — sin regresión detectada en suite.

## Trazabilidad

- Spec: `engineering/specs/flutter-onboarding-for-testers-v1/spec.md`.
- Plan: `engineering/specs/flutter-onboarding-for-testers-v1/plan/plan.md`.
- Tasks: `engineering/specs/flutter-onboarding-for-testers-v1/plan/tasks.md` (T001..T025 + T028 completadas; T026 y T027 a decisión de Diego).
- Quality review pendiente — Diego puede invocar `branch-quality-review` antes del commit final si lo considera necesario.
