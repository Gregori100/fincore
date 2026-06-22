# Plan — flutter-local-hardening-v3

## Estrategia

Sprint atacado en 5 fases secuenciales con dependencia clara: el **harness de widget tests (Fase 1)** desbloquea las **fases 2-3** (todos los widget tests). El script `verify-apk.sh` (Fase 4) y el cleanup del cache (Fase 5) son independientes y se pueden intercalar.

El cambio más sensible es la **inyección de `AppDependencies` con BD in-memory**, porque hoy el bootstrap del `main.dart` instancia la BD real. Si `AppDependencies` no expone constructor de testing, agregar uno con la mínima fricción.

Versionado: `0.3.7+39` (patch, sin features).

## Fases

### Fase 1 — Harness de widget tests (RF-001, RF-002)

**Objetivo:** dejar `mobile/test/helpers/widget_test_harness.dart` operativo y un primer test de humo del dashboard que lo prueba.

- T001: leer `mobile/lib/app_dependencies.dart` y `mobile/lib/main.dart` para entender cómo se instancia hoy.
- T002: agregar (si hace falta) constructor `AppDependencies.forTesting({required AppDatabase db})` que reusa los DAOs sobre la BD inyectada.
- T003: crear `mobile/test/helpers/widget_test_harness.dart` con `pumpFincoreApp(tester, {initialRoute, seed})`.
- T004: test smoke `mobile/test/helpers/widget_test_harness_test.dart` que monta `/dashboard` con BD vacía y verifica que aparece "Bolsa".

**Criterio de salida:** `flutter test test/helpers/widget_test_harness_test.dart` verde.

### Fase 2 — Widget test del entry_form_screen edit (RF-003, RF-004)

**Objetivo:** blindar la regresión del gray screen.

- T005: agregar `mobile/test/screens/entry_form_screen_test.dart` con `cancel en edit` y `submit en edit`.
- T006: verificar que el test falla si se reintroduce `_kind = null` durante `_saving` (validación negativa).

**Criterio de salida:** 2 tests nuevos verdes; regresión protegida.

### Fase 3 — Widget tests T043-T045 del MVP (RF-005, RF-006, RF-007)

**Objetivo:** cobertura mínima de las pantallas core.

- T007: `mobile/test/screens/dashboard_screen_test.dart` — BD vacía + con datos (2 tests).
- T008: `mobile/test/screens/entry_form_kinds_test.dart` — 5 tests, uno por kind, valida cuentas disponibles según RN-011.
- T009: `mobile/test/screens/accounts_list_screen_test.dart` y `categories_list_screen_test.dart` — 2 tests cada uno (renderiza + tap navega a edit).

**Criterio de salida:** ≥ 11 tests nuevos verdes (2+5+2+2).

### Fase 4 — Script verify-apk.sh (RF-008, RF-009)

**Objetivo:** tooling local de validación.

- T010: crear `scripts/verify-apk.sh` con `set -euo pipefail`, lectura de `pubspec.yaml`, búsqueda de `aapt2` en `~/Android/Sdk/build-tools/*/`, parseo de `versionCode` del APK, comparación con `2000 + N`.
- T011: probar el script manualmente con un APK pre-existente (`0.3.6+38` debería dar `versionCode esperado: 2038, encontrado: 2038 ✓`).

**Criterio de salida:** script ejecutable que detecta mismatch.

### Fase 5 — onCancel en _ReplayBalanceStream (RF-010, RF-011, RF-012)

**Objetivo:** cleanup defensivo del cache.

- T012: leer `mobile/lib/data/financial_state.dart` para entender la implementación actual de `_ReplayBalanceStream`.
- T013: agregar parámetro `onLastListenerCanceled` al constructor + lógica en `_handleListen` y en el `onCancel` del controller.
- T014: en `FinancialStateService.watchAccountBalance`, pasarle `onLastListenerCanceled: () => _balanceCache.remove(cacheKey)`.
- T015: agregar test `subscribe → unsubscribe → re-subscribe genera nuevo stream` en `financial_state_test.dart`.
- T016: anotar el patrón en `CLAUDE.md` (sección "Capa de datos").

**Criterio de salida:** 1 test nuevo verde; el patrón documentado.

### Fase 6 — Release (RF-013, RF-014)

**Objetivo:** APK 0.3.7+39 validado por el script.

- T017: bumpear versión en `pubspec.yaml` y `android/app/build.gradle.kts`.
- T018: `flutter build apk --release --split-per-abi`.
- T019: ejecutar `scripts/verify-apk.sh` sobre el APK arm64.
- T020: smoke manual mínimo: instalar, abrir, ver "Acerca de" con `0.3.7+39`.

**Criterio de salida:** APK instalado en Redmi, versión visible correcta.

### Fase 7 — Cierre

**Objetivo:** trazabilidad completa.

- T021: `progreso.md` con detalle de cada fase.
- T022: `pendientes.md` con el ítem diferido (`EntriesDao` en `@DriftDatabase`).
- T023: `pruebas.md` con la matriz de tests por RF.
- T024: `desviaciones-plan.md` (vacío si no hay desviaciones).
- T025: `resumen-ejecutivo.md` + `resumen-extenso.md`.
- T026: `branch-quality-review` antes de commits.
- T027: commits lógicos + push.

## Mapeo RF → Tasks

| RF | Tasks |
|----|-------|
| RF-001 | T002, T003 |
| RF-002 | T003 |
| RF-003 | T005 |
| RF-004 | T006 |
| RF-005 | T007 |
| RF-006 | T008 |
| RF-007 | T009 |
| RF-008 | T010 |
| RF-009 | T010 |
| RF-010 | T013 |
| RF-011 | T014, T016 |
| RF-012 | T015 |
| RF-013 | T017 |
| RF-014 | T018-T020 |
