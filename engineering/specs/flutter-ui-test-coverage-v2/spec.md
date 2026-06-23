# UI Test Coverage v2 — cierre de DV-1 y DV-2 del v1

## Resumen

Sprint chico (~4-6h) que cierra los dos ítems diferidos del `flutter-ui-test-coverage-v1` (commit `fda6e1f`):

1. **DV-1 v1**: validar contenido del DropdownMenu para Pago de tarjeta y Transferencia. Hoy se difirió por contaminación de overlays Material 3 entre tests del isolate.
2. **DV-2 v1**: 3 casos del account CRUD (alta vacía bloqueada por validator, alta con duplicate_account_name muestra error, edición de Bolsa protected en modo read-only).

Sin cambios de producción. Solo cobertura aditiva de widget tests.

## Problema a resolver

El v1 entregó 11 widget tests nuevos pero quedaron 2 áreas con cobertura parcial:

### DV-1 v1 — Overlay contamination

Cuando un test abre un `DropdownMenu<String>` de Material 3, el overlay del menú queda en el OverlayManager global del isolate. `harness.dispose()` cierra DB pero no desmonta el overlay. El siguiente test arranca con un nuevo widget tree y el overlay residual sigue visible en el Layer, contaminando `find.textContaining(...)`.

Soluciones identificadas (no implementadas en v1):
- (a) `addTearDown(() => tester.binding.reset())` en cada test que abre dropdown.
- (b) `WidgetsBinding.instance.focusManager.primaryFocus?.unfocus()` + pump.
- (c) Cerrar el dropdown explícitamente antes de cada `harness.dispose()`.

### DV-2 v1 — 3 casos polishing del account CRUD

Los 5 casos del plan original del v4 se redujeron a 3 en el v1 (path crítico cubierto). Los 3 restantes son polishing que blinda regresiones visuales:

- Alta con nombre vacío bloqueada por validator (form sigue montado).
- Alta con duplicate_account_name muestra snackbar de error.
- Edición de Bolsa (protected) NO muestra botón "Guardar cambios" ni "Archivar cuenta".

## Objetivo

- Implementar el cleanup de overlays Material 3 que permita verificar dropdowns en los kinds Pago de tarjeta y Transferencia (RF-201).
- Agregar 2 tests al `entry_form_kinds_test.dart` con dropdown verify para los 2 kinds restantes (RF-202).
- Agregar 3 tests al `account_form_screen_test.dart` para los casos del DV-2 (RF-203).
- Bumpear a `0.3.10+42`.
- Subir suite de **123 → ≥ 128 verdes** (+5 tests).

## Alcance

### Familia 1 — Cleanup de overlays Material 3

- **RF-201**: probar las 3 soluciones del v1 en orden hasta que una funcione. Empezar con `tester.binding.reset()` que es la más simple. Si falla, intentar `focusManager.primaryFocus?.unfocus() + pump`. Si falla, intentar cerrar el dropdown explícitamente con un widget custom de cierre.
- **RF-202**: con el cleanup funcionando, ampliar 2 tests más en `entry_form_kinds_test.dart`:
  - **Pago de tarjeta**: dropdown "Pagás desde" con cash/debit + dropdown "Tarjeta a pagar" con credit.
  - **Transferencia**: dropdown "Cuenta origen" con cash/debit (NO el destino, que es simétrico).

### Familia 2 — Account CRUD casos restantes

- **RF-203**: 3 tests nuevos en `account_form_screen_test.dart`:
  - Alta sin nombre → tap submit → form sigue montado (validator bloqueó) + sin cuenta creada en BD.
  - Alta con duplicate_name → tap submit → snackbar de error visible + sin cuenta creada en BD.
  - Edición de Bolsa (protected) → form en read-only, sin botón "Guardar cambios" visible.

### Familia 3 — Release

- **RF-204**: bumpear a `0.3.10+42`.
- **RF-205**: build APK release split-per-abi + validar con `scripts/verify-apk.sh`.

## Fuera de alcance

- **RF-014 (hasListener guard)**: sigue diferido. Si aparece reporte real, atacar con `try/catch` puntual.
- **Migración de Material 3 DropdownMenu a custom widget**: si el cleanup con `binding.reset()` o equivalente funciona, NO se toca producción.
- **Refactor del account_form_screen** para test-friendlyness: si los 3 casos del DV-2 pasan con el patrón actual (`enterText` + `scrollUntilVisible` + tap), NO se toca producción.

## Criterios de aceptacion

- `flutter test` ≥ 128 tests verdes (de 123 actuales). Estimado 128.
- `flutter analyze` 0 errores, 0 warnings.
- `scripts/verify-apk.sh` valida `0.3.10+42`.
- Los 2 tests de Pago de tarjeta + Transferencia con dropdown verify pasan **en orden** con los demás tests del archivo (no solo aislados).
- Los 3 tests del account CRUD pasan en la suite completa.
- Documentación de cierre en `implementation/`.

## Riesgos

- **Ninguna de las 3 soluciones del cleanup funciona**: si las 3 fallan, dropear el RF-201 y dejar DV-1 v1 como definitivamente diferido. NO migrar a custom widget — el ROI no justifica tocar producción solo por tests.
- **`tester.binding.reset()` rompe estado del harness**: si reset() también limpia el FincoreApp del test actual, los `expect` posteriores fallan. Mitigación: hacer el reset solo en `addTearDown` (después de los expects).
- **Volumen pequeño no justifica sprint formal**: el sprint es chico. Si la implementación toma <2h total, los docs `implementation/` pueden ser un único archivo combinado.
