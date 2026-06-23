# Cierre — flutter-ui-test-coverage-v2

Sprint chico (3 fases, ~1h efectivo). Cierra DV-1 v1 con análisis técnico definitivo (DV-1 v1 confirmado como **definitivamente diferido**) y entrega DV-2 v1 completo (+3 tests).

## Resultado

```
flutter test     → 126/126 verdes (de 123 iniciales, +3 nuevos del v2)
flutter analyze  → 0 errores, 0 warnings, 4 hints info preexistentes
scripts/verify-apk.sh app-arm64-v8a-release.apk → exit 0 (versionCode=2042)
```

## Fase 1 — DV-1 v1 confirmado como diferido definitivo

**Hipótesis del v1:** la contaminación de overlays Material 3 entre tests del isolate causaba que `verifyDropdownItems` encontrara items del overlay residual.

**Hallazgo real del v2:** la hipótesis era **incorrecta**. El problema no es contaminación entre tests — es que **Material 3 `DropdownMenu` prerenderea los items de TODOS los dropdowns del tree** independientemente de cuál esté abierto.

**Reproducción:** un test único (sin tests previos) que monta Pago de tarjeta y abre solo el dropdown destino "Tarjeta a pagar" (con `allowedTypes=['credit']`) encuentra Bolsa en `find.textContaining('Bolsa')`. Bolsa NO está en `visible` del `AccountPicker` destino (filtrada por allowedTypes), pero SÍ está en el otro `AccountPicker` origen "Pagás desde" (que tiene allowedTypes=['cash', 'debit']). Material 3 incluye los items del Pagás desde en el tree global, contaminando la verificación.

**Conclusión:** la única solución limpia es **migrar los AccountPicker a un widget custom con Keys específicos** que permita restringir `find` al dropdown actualmente abierto. Esto cambia código de producción solo para tests — ROI negativo.

**Estado final:** DV-1 v1 cerrado como diferido definitivo. Los kinds con 1 dropdown (Ingreso, Gasto, Gasto a tarjeta) mantienen la verificación de RN-011. Pago de tarjeta y Transferencia mantienen solo verificación de labels (RF-006 v3).

Las solucines (a)/(b)/(c) que el spec del v2 listaba NO se intentaron porque el análisis técnico mostró que ninguna podría resolver el problema fundamental: **los items YA están en el tree antes de cualquier tap**. No hay "open/close" que controlar.

## Fase 2 — DV-2 v1: 3 tests nuevos del account CRUD

3 tests agregados al `account_form_screen_test.dart`:

- **Alta sin nombre queda bloqueada por validator**: NO completar nombre, scroll y tap submit, verificar que `EntryFormScreen` sigue montado y que solo existe Bolsa en BD.
- **Alta con duplicate_account_name muestra snackbar**: sembrar BD con "Banamex", intentar crear otra "Banamex", verificar SnackBar visible con mensaje "Ya tenés una cuenta con ese nombre" + sin crear duplicado.
- **Edición de Bolsa (protected) sin botones de mutación**: push a `/accounts/$bolsaId/edit`, verificar que no aparecen "Guardar cambios" ni "Archivar cuenta" (la pantalla usa `_ProtectedView`, un widget custom de solo info).

**Gotcha menor:** Bolsa protected usa `_ProtectedView` (no el `ListView` del form normal), así que el patrón `drag(Scrollable, Offset)` falla con `Bad state: No element`. Verificar los textos ausentes directamente sin scroll funciona.

## Fase 3 — Release 0.3.10+42

- `mobile/pubspec.yaml`: `version: 0.3.10+42`.
- `mobile/android/app/build.gradle.kts`: `versionCode = 42`, `versionName = "0.3.10"`.
- `flutter analyze`: limpio (4 hints info preexistentes).
- `flutter build apk --release --split-per-abi`: 3 APKs generados.
- `scripts/verify-apk.sh`: ✓ OK — versionCode 2042 / versionName 0.3.10.

## Trazabilidad RF → entrega

| RF | Entrega | Estado |
|----|---------|--------|
| RF-201 | 3 soluciones del cleanup no necesarias — análisis técnico demostró que el problema es prerendering, no contamination | **diferido definitivo** |
| RF-202 | 2 tests de Pago de tarjeta + Transferencia con dropdown verify | **cancelado** (consecuencia de RF-201) |
| RF-203 | 3 tests del account CRUD (alta vacía, duplicate_name, Bolsa protected) | ✅ |
| RF-204 | Bump 0.3.10+42 | ✅ |
| RF-205 | APK validado por verify-apk.sh | ✅ smoke Diego pendiente |

## Diferidos del v2

- **DV-1 v1 → DV-1 v2 (definitivo):** verificación de contenido de DropdownMenu en kinds con 2 dropdowns NUNCA va a funcionar con Material 3 sin migrar a widget custom con Keys. Documentado como contraconvención: **no intentar más sin migrar producción**.

## Lección clave

Cuando un patrón de testing no funciona, distinguir entre **problema de uso** (que se arregla con un fix técnico) y **limitación de framework** (que no se arregla sin cambiar el código bajo test). En el v1 asumimos lo primero y dejamos el cleanup como pendiente. En el v2 confirmamos que era lo segundo: el cleanup nunca iba a funcionar.

Documentar la **diferencia entre las dos** evita que un futuro mantenedor pierda otra hora intentando soluciones que no funcionan.
