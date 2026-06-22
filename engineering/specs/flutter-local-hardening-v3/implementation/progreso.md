# Progreso — flutter-local-hardening-v3

Sprint cerrado el 2026-06-22. APK release `0.3.7+39` construido y validado por `scripts/verify-apk.sh` (smoke en Redmi queda como confirmación manual de Diego post-merge).

## Resumen de fases

| Fase | Tasks | Estado | Tests resultantes |
|------|-------|--------|-------------------|
| 1 — Harness | T001-T004 | ✅ | 93 → 96 (+3) |
| 2 — entry_form edit | T005-T006 | ✅ | 96 → 98 (+2) |
| 3 — Widget tests T043-T045 | T007-T009 | ✅ | 98 → 109 (+11) |
| 4 — verify-apk.sh | T010-T011 | ✅ | sin tests automatizados |
| 5 — Cache stream | T012-T016 | ✅ con desviación | 109 → 110 (+1) |
| 6 — Release | T017-T020 | ✅ | — |
| 7 — Cierre | T021-T027 | en curso | — |

**Total tests:** 93 → **110 verdes** (+17, 18.3 % de crecimiento).

## Detalle por fase

### Fase 1 — Harness de widget tests

Creado `mobile/test/helpers/widget_test_harness.dart` con `pumpFincoreApp(tester, {initialRoute, seed, seedBolsa})`. El harness:

- Inicializa SQLite (reusa `sqlite_override.dart`).
- Setea `driftRuntimeOptions.dontWarnAboutMultipleDatabases = true` (cada widget test arma BD propia).
- Inicializa `initializeDateFormatting('es_MX')` la primera vez por isolate (fixed `LocaleDataException` en `entry_form_screen`).
- Construye BD in-memory + `AppDependencies.fromDatabase(database)` (que ya aceptaba inyección desde el v2).
- Por default ejecuta `seedDefaults` (Bolsa + 10 categorías). Opcional `seed: (db, deps) async {...}` para sembrar datos extra.
- Setea `FirstRunState.value` sincrónicamente según `seedBolsa` para que el redirect del router no quede colgado.
- Monta un `FincoreApp` minimalista (sin `SystemChrome`) wrappeando `AppDependenciesProvider` > `FirstRunStateProvider` > `MaterialApp.router`.
- Si el caller pide ruta distinta a `/dashboard`/`/first-run`, hace `router.go(initialRoute)` post-pump.

Smoke test: `mobile/test/helpers/widget_test_harness_test.dart` con 3 escenarios (default, seed extra, first-run sin Bolsa). 3/3 verde.

**Desviación menor**: `AppDependencies` ya tenía `fromDatabase(database)` desde el v2 (M2 del quality review), así que NO hizo falta agregar constructor `forTesting`. T002 quedó vacío.

### Fase 2 — entry_form_screen edit (cancel + submit)

Creado `mobile/test/screens/entry_form_screen_test.dart` con 2 tests:

- **Cancel en edit**: siembra 1 expense, `GoRouter.of(ctx).push('/entries/$id/edit')` para mantener el stack del Dashboard (sin esto `maybePop` no tiene a dónde volver y la regresión gray screen queda oculta), `ensureVisible` + tap en "Cancelar movimiento" → confirma en el AlertDialog tocando `descendant(of: AlertDialog, matching: widgetWithText(FilledButton, 'Cancelar movimiento'))` → verifica que `EntryFormScreen` ya no existe en el tree.
- **Submit en edit**: siembra 1 expense con monto 150.0, modifica el monto a 200, `ensureVisible` + tap en "Guardar cambios" → verifica `EntryFormScreen` desmontado + persistencia (`entriesDao.findById` retorna `amount == 200`).

**Regresión gray screen blindada implícitamente**: si alguien reintroduce `_kind = null` en `onPopInvokedWithResult`, el `_buildForm` crashea con null check, `pumpAndSettle` reporta la excepción al test y falla. T006 cubierto sin necesidad de mock especial.

2/2 verde.

### Fase 3 — Widget tests T043-T045 del MVP

- **T043 / dashboard_screen_test.dart** (RF-005): 2 tests — BD recién seedeada (verifica Bolsa 2x por nombre+tipo, cards BO/DE/CR, placeholder "Aún no hay movimientos") y BD con 1 ingreso (Salario aparece en la lista, placeholder ausente).
- **T044 / entry_form_kinds_test.dart** (RF-006): 5 tests, uno por kind. Cada test siembra bolsa + debit + credit, `push('/entries/new')`, toca la card del KindPicker, verifica las labels esperadas según RN-011:
  - Ingreso → solo "Cuenta destino"
  - Gasto → solo "Cuenta origen"
  - Gasto a tarjeta → "Tarjeta"
  - Pago de tarjeta → "Pagás desde" + "Tarjeta a pagar"
  - Transferencia → "Cuenta origen" + "Cuenta destino"
- **T045 / list_screens_test.dart** (RF-007): 4 tests (2 accounts + 2 categories) — render + tap navega al form de edición.

Ajustes finos durante implementación:

- "Bolsa" aparece **2x** en pantallas con accounts: como nombre y como `_typeLabel('cash')`. Los tests usan `findsNWidgets(2)`.
- `CategoriesListScreen` usa `ListView` lazy: las categorías hacia el fondo de la lista alfabética ("Sueldo", "Transporte") no se montan sin scroll. Los tests verifican las del top ("Comida", "Entretenimiento", "Hogar").
- `find.byType(Scaffold)` para resolver `BuildContext` en lugar de `find.text('FinCore')` (el wordmark usa `RichText` con TextSpans, no un simple `Text`).

11/11 verde.

### Fase 4 — Script verify-apk.sh

Creado `scripts/verify-apk.sh` con `set -euo pipefail`:

- Lee `version: X.Y.Z+N` de `mobile/pubspec.yaml`.
- Acepta APK path como primer argumento (default `mobile/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`).
- Busca `aapt2` en: PATH → `$ANDROID_HOME/build-tools/*/aapt2` → `~/Android/Sdk/build-tools/*/aapt2`. Agarra la versión más alta con `sort -V | tail -n 1`.
- Compara `versionCode` del APK (`aapt2 dump badging`) con `2000 + N` (prefix `--split-per-abi` arm64).
- Exit codes: `0` OK / `1` mismatch / `2` aapt2 no encontrado.

Gotcha resuelto: captura completa de la salida de `aapt2` antes de `sed -n '1p'` para evitar SIGPIPE bajo `pipefail`.

Validación:
- APK existente `0.3.6+38` → `versionCode=2038`, exit 0.
- Bump artificial de `pubspec.yaml` a `+39` con APK `+38` → detecta mismatch, exit 1.
- APK nuevo `0.3.7+39` → exit 0.

### Fase 5 — Cache de streams (con desviación documentada)

**Decisión tomada durante implementación**: el RF-010/RF-011 del v3 proponía agregar `onLastListenerCanceled` que libera la entry del cache cuando se va el último listener. Al releer el código actual de `_ReplayBalanceStream`, encontré que el sprint v2 documentó explícitamente la decisión opuesta:

> "Por diseño NO se cierra al perder el último listener: el cache de FinancialStateService mantiene la entrada viva hasta una invalidación explícita, así que reutilizar `watchAccountBalance(...)` después sigue retornando el último valor."

Implementar `onLastListenerCanceled` contradice esa decisión y podría reintroducir el "Skeleton eterno" del bug del v2.

**Decisión del v3**: NO implementar RF-010 ni RF-011. SÍ implementar RF-012 (test defensivo).

El nuevo test `RF-012 v3: subscribe → unsubscribe → resubscribe preserva el cache del stream` valida que:
1. Tras cancelar el último listener, una nueva llamada a `watchAccountBalance(id, type)` retorna **el mismo `Stream` (`identical(s1, s2) == true`)** — el cache NO se libera.
2. El listener nuevo recibe inmediatamente el último valor por replay-1 (sin esperar otro cambio).

Si alguien en el futuro reintroduce `onLastListenerCanceled`, este test falla con un mensaje explícito.

Ver `desviaciones-plan.md` para el detalle completo.

### Fase 6 — Release 0.3.7+39

- `mobile/pubspec.yaml`: `version: 0.3.7+39`.
- `mobile/android/app/build.gradle.kts`: `versionCode = 39`, `versionName = "0.3.7"`.
- `flutter analyze` post-bump: 0 errores, 0 warnings, 4 hints info preexistentes (3 del `entry_form_screen` y 1 del `skeleton`). Documentado en `CLAUDE.md` que son tolerables.
- Aprovechamiento: el sprint también limpió un import preexistente sin uso en `lib/data/database.dart` (`entries_dao.dart` no se importaba desde que el v2 dejó `EntriesDao` fuera del `@DriftDatabase(daos: [...])`).
- `flutter build apk --release --split-per-abi`: 3 APKs generados.
- `scripts/verify-apk.sh app-arm64-v8a-release.apk`: ✓ OK — versionCode 2039 / versionName 0.3.7.

### Fase 7 — Cierre

En curso: docs `implementation/`, `branch-quality-review`, commits.

## Trazabilidad RF → entrega

| RF | Entrega | Estado |
|----|---------|--------|
| RF-001 | `widget_test_harness.dart`, harness reusa `AppDependencies.fromDatabase` | ✅ |
| RF-002 | `sqlite_override.dart` reusado, locale init centralizado | ✅ |
| RF-003 | `entry_form_screen_test.dart` (cancel + submit) | ✅ |
| RF-004 | Implícito en RF-003 (null check propaga al test) | ✅ |
| RF-005 | `dashboard_screen_test.dart` | ✅ |
| RF-006 | `entry_form_kinds_test.dart` | ✅ |
| RF-007 | `list_screens_test.dart` | ✅ |
| RF-008 | `scripts/verify-apk.sh` | ✅ |
| RF-009 | `scripts/verify-apk.sh` fallback a `$ANDROID_HOME` y `~/Android/Sdk` | ✅ |
| RF-010 | **NO implementado** (contradicía decisión v2) | desviación |
| RF-011 | **NO implementado** (consecuencia de RF-010) | desviación |
| RF-012 | Test `RF-012 v3: subscribe → unsubscribe → resubscribe preserva el cache` | ✅ |
| RF-013 | Bump `0.3.7+39` en pubspec + gradle | ✅ |
| RF-014 | `flutter build apk` + `verify-apk.sh` validado | ✅ smoke Diego pendiente |
