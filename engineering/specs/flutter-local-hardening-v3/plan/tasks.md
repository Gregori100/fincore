# Tasks — flutter-local-hardening-v3

Lista detallada para `spec-implementar`. Cada task tiene su RF asociado, archivos a tocar y criterio de salida.

## Fase 1 — Harness

### T001: Leer estado actual de AppDependencies y main
- **Archivos:** `mobile/lib/app_dependencies.dart`, `mobile/lib/main.dart`.
- **Criterio:** entender si `AppDependencies` permite inyección de BD.

### T002: Constructor de testing en AppDependencies (RF-001)
- **Archivo:** `mobile/lib/app_dependencies.dart`.
- **Acción:** agregar `AppDependencies.forTesting({required AppDatabase database})` si no existe equivalente. Reutilizar los DAOs sobre la BD inyectada.
- **Criterio:** `flutter analyze` limpio.

### T003: Harness pumpFincoreApp (RF-001, RF-002)
- **Archivo:** `mobile/test/helpers/widget_test_harness.dart` (nuevo).
- **Acción:** función `Future<void> pumpFincoreApp(WidgetTester tester, {String initialRoute = '/dashboard', void Function(AppDatabase)? seed, bool seedBolsa = true})`. Usa `NativeDatabase.memory()`, sembra Bolsa por default (a menos que el caller pase `seedBolsa: false`), monta `MaterialApp.router`. Reusa `test/helpers/sqlite_override.dart`.
- **Criterio:** importable desde otros tests.

### T004: Smoke test del harness
- **Archivo:** `mobile/test/helpers/widget_test_harness_test.dart` (nuevo).
- **Acción:** 1 test que monta `/dashboard` y verifica que "Bolsa" aparece.
- **Criterio:** test verde.

## Fase 2 — entry_form_screen edit

### T005: Tests cancel + submit en edit (RF-003)
- **Archivo:** `mobile/test/screens/entry_form_screen_test.dart` (nuevo).
- **Acción:** 2 tests:
  1. Cancel en edit: sembrar 1 expense, navegar a `/entries/$id/edit`, tocar "Cancelar movimiento", confirmar, verificar pantalla cerrada.
  2. Submit en edit: sembrar 1 expense, navegar a `/entries/$id/edit`, modificar monto, tocar "Guardar cambios", verificar pantalla cerrada.
- **Criterio:** 2 tests verdes.

### T006: Validación negativa de regresión (RF-004)
- **Acción:** validar mentalmente que si se reintroduce `_kind = null` en el `onPopInvokedWithResult` (que causaría el gray screen), los tests del T005 fallan con `FlutterError` capturado. Si no, agregar un test específico que monta el form con un mock que fuerza el `_kind = null` post-pop.
- **Criterio:** confianza de que la regresión está blindada.

## Fase 3 — Widget tests T043-T045

### T007: Dashboard tests (RF-005)
- **Archivo:** `mobile/test/screens/dashboard_screen_test.dart` (nuevo).
- **Acción:** 2 tests (BD vacía / con datos sembrados).
- **Criterio:** 2 tests verdes.

### T008: Entry form 5 kinds (RF-006)
- **Archivo:** `mobile/test/screens/entry_form_kinds_test.dart` (nuevo).
- **Acción:** 5 tests, uno por kind. Cada test siembra cuentas + categorías, monta `/entries/new`, selecciona kind, verifica que el `AccountPicker` muestra las cuentas correctas según RN-011.
- **Criterio:** 5 tests verdes.

### T009: Listas accounts + categories (RF-007)
- **Archivos:** `mobile/test/screens/accounts_list_screen_test.dart` y `categories_list_screen_test.dart` (nuevos).
- **Acción:** 2 tests por archivo (renderiza filas + tap navega a edit).
- **Criterio:** 4 tests verdes (2+2).

## Fase 4 — verify-apk.sh

### T010: Script verify-apk.sh (RF-008, RF-009)
- **Archivo:** `scripts/verify-apk.sh` (nuevo, crear directorio si no existe).
- **Acción:** bash con `set -euo pipefail`. Lee `version: X.Y.Z+N` de `mobile/pubspec.yaml`. Busca `aapt2` en `~/Android/Sdk/build-tools/*/aapt2` (versión más alta). Recibe APK path como `$1` con default arm64. Compara `versionCode` con `2000 + N`.
- **Criterio:** ejecutable (`chmod +x`).

### T011: Probar script contra APK existente
- **Acción:** ejecutar `scripts/verify-apk.sh` contra el APK `0.3.6+38` ya en `mobile/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` (si existe; si no, hacer un build dummy). Verificar que detecta mismatch artificial (editar pubspec temporal, ver que falla).
- **Criterio:** script reporta correctamente.

## Fase 5 — onCancel en _ReplayBalanceStream

### T012: Leer financial_state.dart
- **Archivo:** `mobile/lib/data/financial_state.dart`.
- **Criterio:** entender estructura actual de `_ReplayBalanceStream` y `_balanceCache`.

### T013: Agregar onLastListenerCanceled al stream (RF-010)
- **Archivo:** `mobile/lib/data/financial_state.dart`.
- **Acción:** constructor de `_ReplayBalanceStream` recibe `void Function()? onLastListenerCanceled`. En el `onCancel` del controller, si `_listeners` queda vacío: cancelar `_upstreamSub`, setear `null`, resetear `_last`, llamar callback.
- **Criterio:** test T015 verde.

### T014: Pasar callback desde FinancialStateService (RF-011)
- **Archivo:** `mobile/lib/data/financial_state.dart`.
- **Acción:** en `watchAccountBalance(accountId, accountType)`, al crear `_ReplayBalanceStream`, pasar `onLastListenerCanceled: () => _balanceCache.remove(cacheKey)`.
- **Criterio:** integración limpia.

### T015: Test subscribe/unsubscribe/resubscribe (RF-012)
- **Archivo:** `mobile/test/data/financial_state_test.dart`.
- **Acción:** test que se suscribe, cancela, vuelve a suscribirse y verifica que recibe valores (no Stream cerrado). Adicional: `identical(s1, s2) == false` por reset del cache.
- **Criterio:** test verde.

### T016: Documentar el patrón en CLAUDE.md
- **Archivo:** `CLAUDE.md`.
- **Acción:** nota corta en "Capa de datos" sobre el patrón `onLastListenerCanceled`.
- **Criterio:** documentación clara.

## Fase 6 — Release

### T017: Bump versión a 0.3.7+39
- **Archivos:** `mobile/pubspec.yaml`, `mobile/android/app/build.gradle.kts`.
- **Criterio:** ambos en sincronía.

### T018: Build APK release
- **Comando:** `cd mobile && flutter build apk --release --split-per-abi`.
- **Criterio:** APK arm64 generado en `build/app/outputs/flutter-apk/`.

### T019: Validar APK con verify-apk.sh
- **Comando:** `scripts/verify-apk.sh mobile/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`.
- **Criterio:** exit 0, mensaje OK.

### T020: Smoke manual mínimo en Redmi
- **Acción:** Diego instala APK, abre app, verifica Settings → "Acerca de" = `0.3.7+39`.
- **Criterio:** versión visible correcta.

## Fase 7 — Cierre

### T021-T025: Documentación de implementación
- **Archivos:** `engineering/specs/flutter-local-hardening-v3/implementation/{progreso,pendientes,pruebas,desviaciones-plan,resumen-ejecutivo,resumen-extenso}.md`.

### T026: branch-quality-review
- **Acción:** invocar el skill antes de commits.

### T027: Commits + push
- **Acción:** commits lógicos (docs primero, código después), Diego hace push.
