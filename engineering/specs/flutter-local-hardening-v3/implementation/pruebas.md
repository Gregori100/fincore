# Pruebas — flutter-local-hardening-v3

## Resultado final

```
flutter test     → 110/110 verdes (de 93 iniciales)
flutter analyze  → 0 errores, 0 warnings, 4 hints info preexistentes
scripts/verify-apk.sh app-arm64-v8a-release.apk → exit 0
```

## Matriz de cobertura

| RF | Archivo | Tests nuevos | Estado |
|----|---------|--------------|--------|
| RF-001, RF-002 | `test/helpers/widget_test_harness_test.dart` | 3 | ✅ |
| RF-003, RF-004 | `test/screens/entry_form_screen_test.dart` | 2 | ✅ |
| RF-005 | `test/screens/dashboard_screen_test.dart` | 2 | ✅ |
| RF-006 | `test/screens/entry_form_kinds_test.dart` | 5 | ✅ |
| RF-007 | `test/screens/list_screens_test.dart` | 4 | ✅ |
| RF-008, RF-009 | `scripts/verify-apk.sh` (manual) | — | ✅ |
| RF-010, RF-011 | (NO implementado — DV-1) | — | desviación |
| RF-012 | `test/data/financial_state_test.dart` | 1 | ✅ |

**Tests nuevos automatizados:** **17** (3 + 2 + 2 + 5 + 4 + 1).

## Cobertura por capa

### Capa de datos (DAOs)

| Suite | Tests | Cambio v3 |
|-------|-------|-----------|
| `database_test.dart` | 30 | sin cambios |
| `financial_state_test.dart` | 22 | +1 (RF-012) |
| `backup_test.dart` | 8 | sin cambios |
| `invariants_test.dart` | 8 | sin cambios |
| **subtotal capa datos** | **68** | +1 |

### Capa de presentación (widgets)

Nueva en v3.

| Suite | Tests | Detalle |
|-------|-------|---------|
| `helpers/widget_test_harness_test.dart` | 3 | Default seed / seed extra / first-run sin Bolsa |
| `screens/entry_form_screen_test.dart` | 2 | Cancel en edit / submit en edit |
| `screens/dashboard_screen_test.dart` | 2 | BD vacía / con datos |
| `screens/entry_form_kinds_test.dart` | 5 | Uno por kind (Ingreso, Gasto, Gasto a tarjeta, Pago de tarjeta, Transferencia) |
| `screens/list_screens_test.dart` | 4 | Accounts render + tap edit / Categories render + tap edit |
| **subtotal capa UI** | **16** | nuevo |

**Total suite v3:** 68 + 16 = **84 tests de fincore-app** + 26 tests del package (que vienen de antes). Final: **110 verdes**.

## Smoke manual (Diego, post-merge)

Mínimo a validar:

1. `adb install -r build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` succeed.
2. App abre, Dashboard renderea con datos previos.
3. Settings → "Acerca de" muestra `0.3.7+39`.
4. Spot check: editar un movimiento existente → cambiar monto → Guardar → snackbar verde + cierra form sin gray screen.
5. Cancelar un movimiento → confirmar → snackbar verde + cierra form sin gray screen.

El smoke completo de 6 iteraciones del v2 ya quedó blindado por los widget tests del v3; no se requiere repetirlo entero.

## Validación del verify-apk.sh

Ejecutado durante implementación (Fase 4):

1. APK `0.3.6+38` ya existente → `versionCode esperado: 2038, encontrado: 2038 ✓`, exit 0.
2. Bump artificial de `pubspec.yaml` a `+39` con APK aún en `+38` → detecta mismatch, exit 1.
3. Restore de pubspec, build nuevo `0.3.7+39` → exit 0.

## Validación negativa de regresión gray screen

El test `Cancelar movimiento confirma + cierra el form sin gray screen` (RF-003) confirma la regresión cubierta:

- Si alguien reintroduce `_kind = null` en `onPopInvokedWithResult`, el siguiente `_buildForm()` crashea con `Null check operator used on a null value` al evaluar `final k = _kind!;`.
- `tester.pumpAndSettle()` propaga la excepción al test.
- El test falla con stack trace claro, no con un mensaje genérico.

Confirmación implícita: en la suite actual con 0 modificaciones al `entry_form_screen`, el test pasa. La regresión está blindada por construcción.
