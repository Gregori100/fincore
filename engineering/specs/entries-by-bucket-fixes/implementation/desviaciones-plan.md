# Desviaciones del plan

Cambios respecto a `plan/plan.md` y `plan/tasks.md`. Una ampliación necesaria + reversión durante el QR.

## D-001: Fix emergente del rango `to` en `applyEntryFilters` (ampliación)

El plan cubría 3 cambios al helper `applyEntryFilters`: `category_id` con `array_key_exists`, `kind=expense` con `whereIn`, y `buildBucketLabel` con "sin categorizar". Durante el smoke en navegador real con dataset seedeado, el bucket "Comida" mostraba 2 mov ($3,055 = $2,500 expense + $555 credit_expense), pero el modal mostraba solo 1 entry ($2,500).

**Causa**: el filtro `to` en `applyEntryFilters` aplicaba `<= $to` sin hora. Postgres interpretaba `'2026-06-11'` como `00:00:00`, excluyendo entries del último día. El credit_expense seedeado a las 23:35 caía fuera.

Comparado con los Report Services (`CategoryBreakdownReport.php:54`), que ya usan `<= $to.' 23:59:59'`, el helper tenía un bug preexistente que era invisible y se hizo visible con P2.

**Fix**: cambiar a `<= $to.' 23:59:59'` alineando con los Report Services. Cero regresiones: 394/394 verde.

Es desviación porque no estaba en `plan/tasks.md`, pero era necesario para que P2 se demostrara funcionando en smoke. Documentado.

## D-002: Frontend traduce `null` → `''` en lugar de preservar null (ajuste técnico)

El plan original decía:
> Frontend `pruneFilters`: preservar `category_id: null` cuando la key existe.

Durante el smoke, axios omitió el param con valor `null` del query string (comportamiento default de axios). El backend nunca recibió el filtro. Fix: traducir `null` → `''` (string vacío) en `pruneFilters`. Axios serializa `''` como `?category_id=`, y el backend con `nullable` lo trata como `null`.

Es ajuste técnico necesario para que el sprint funcione, no cambio de alcance. Tests del modal ajustados para esperar `category_id: ''` en lugar de `null`.

## D-003: Intentos de ampliación del alcance descartados durante el QR

El QR identificó que el flujo "Ir a Movimientos" desde el bucket "Sin categorizar" no se completa: `EntriesTable.applyQueryToFilters` y `fetchEntries` usan truthy check con `category_id`, y `listEntries` rechaza `category_id=''` por validar `uuid` sin `nullable`.

Durante el QR se intentó incluir el fix:
- Backend: validación `listEntries` con `nullable`.
- Frontend: `applyQueryToFilters` con `'category_id' in q` en lugar de truthy check.

Pero el fix completo requería también:
- Una opción "Sin categorizar" en el `BaseSelect` de filtros de `EntriesTable`.
- Un sentinel para representar "filtro = sin categoría" distinguible de "filtro = todas".
- Tests para todos esos cambios.

Esto excede el alcance acordado del sprint (atender P1+P2 del endpoint `entriesByBucket`). Los cambios intentados se **revirtieron** y se documentó M1 del QR como pendiente para un sprint chico futuro.

Resultado: el sprint cumple su objetivo principal (drill-down modal funcionando), pero el flujo "Ir a Movimientos" desde "Sin categorizar" sigue roto. Documentado en M1 del quality review para backlog.
