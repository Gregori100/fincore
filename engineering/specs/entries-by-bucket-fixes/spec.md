# Fixes al endpoint entries-by-bucket

## Resumen

Atender dos hallazgos preexistentes del endpoint `GET /api/finance/reports/entries-by-bucket` que generan inconsistencias en el drill-down de los 7 reportes del módulo. **P1**: el bucket "Sin categorizar" (categoría `null`) hoy muestra entries de todas las categorías porque el filtro `category_id=null` se descarta en el cliente. **P2**: el drill-down con `kind=expense` no incluye `credit_expense`, así el modal puede mostrar menos entries que el bucket suma. Ambos fixes son cambios de comportamiento del endpoint y un ajuste al pruneo del modal en el frontend. Cero cambios en los Report Services, cero migraciones.

## Problema a resolver

Los reportes `ReportsByCategoryView` y `ReportsForecastView` exponen el bucket "Sin categorizar" para entries con `category_id IS NULL`, y todos los reportes que agrupan gastos suman `kind IN (expense, credit_expense)` por categoría. El endpoint de drill-down `entriesByBucket`, sin embargo:

1. Valida `category_id` como `uuid` sin aceptar `null` explícito, y `pruneFilters` del cliente además descarta el campo si su valor es `null`. Resultado: el filtro nunca llega al backend, el endpoint devuelve entries de todas las categorías del rango, y el modal muestra una lista que no corresponde al bucket que el usuario clickeó.
2. Aplica `kind` con match estricto (`where('kind', $value)`). Cuando llega `kind=expense`, solo trae entries `expense` puras, omitiendo las `credit_expense`. Los buckets de los reportes que suman ambos kinds quedan inconsistentes con su drill-down.

Ambas inconsistencias erosionan la confianza en el drill-down y son fáciles de reproducir por cualquier usuario con entries sin categoría o con cargos a tarjeta.

## Objetivo

Que el contenido del modal de drill-down siempre cuadre exactamente con el bucket clickeado en el reporte: misma cantidad de entries, misma suma, misma semántica. El cambio queda localizado al endpoint `entriesByBucket`, su validación, y la función `pruneFilters` del modal. Sin tocar Report Services ni vistas individuales.

## Alcance

- Backend: `app/Http/Controllers/FinanceController.php`:
  - Validación del endpoint `entriesByBucket`: `category_id` pasa a aceptar `null` explícito.
  - Helper `applyEntryFilters`: trata `category_id` con `whereNull` cuando el valor es `null`, mantiene `where('category_id', $id)` cuando llega un UUID.
  - Helper `applyEntryFilters`: cuando recibe `kind=expense`, aplica `whereIn('kind', ['expense', 'credit_expense'])`. Cualquier otro `kind` mantiene `where('kind', $value)` literal.
  - Helper `buildBucketLabel`: el caso "Sin categorizar" debe rotular correctamente cuando llega `category_id=null` (hoy devuelve un label genérico porque no detecta el null).
- Frontend: `frontend/src/components/finance/EntriesDrilldownModal.vue`:
  - `pruneFilters`: preservar `category_id: null` cuando la key existe explícitamente en `props.filters`. Otros campos siguen prunándose si son `null`/`''`/`undefined`.
- Tests backend: ampliar `EntriesByBucketTest` con los nuevos casos (drill-down de bucket null, drill-down kind=expense incluye credit_expense, kind=credit_expense literal, kind=transfer literal).
- Tests frontend: actualizar `EntriesDrilldownModal.spec.js` para cubrir el nuevo comportamiento de `pruneFilters` con `category_id: null` explícito.

## Fuera de alcance

- Modificar el comportamiento de los 7 Report Services (siguen sumando `expense + credit_expense` correctamente).
- Refactor mayor del modal o del endpoint.
- Cambios en otros filtros (`account_id`, `from`, `to`, `year_month`).
- Agregar nuevos parámetros como `kind_group`, `category_ids`, listas o arrays.
- Migración o cambios de schema.
- Cambios en `listEntries` (paginado de `/entries`): aunque comparte `applyEntryFilters`, el efecto colateral es deliberado y deseable (ver "Riesgos").
- Modificar la documentación visual de las 7 vistas o de los exports.

## Reglas de negocio

- **`category_id=null`** explícito en query params significa "entries sin categoría" → `whereNull('category_id')`.
- **`category_id` ausente** del query string significa "no filtrar por categoría" → no se aplica condición.
- **`category_id`** con UUID válido significa "esa categoría específica" → `where('category_id', $id)`. El UUID debe pertenecer al usuario autenticado (validación `exists:categories,id,user_id,$userId` se mantiene).
- **`kind=expense`** significa "gasto operativo" → `whereIn('kind', ['expense', 'credit_expense'])`. Es la semántica usada por todos los Report Services agregados.
- **`kind=credit_expense`** significa "cargo a tarjeta de crédito" puntual → `where('kind', 'credit_expense')`. Filtro literal, no se mezcla.
- **`kind=income`**, **`debt_payment`**, **`transfer`**, **`adjustment`**: filtro literal, sin cambios.
- **Filtros combinables**: las reglas de `kind` y `category_id` se aplican vía AND con el resto (account_id, from, to). Sin cambios en esa lógica.
- **Soft delete**: entries cancelados (`deleted_at != null`) siguen excluidos por el scope global de `SoftDeletes` en `JournalEntry`.
- **Sin filtros**: si el cliente no manda ningún filtro válido (caso ya cubierto por `missing_filters`), sigue devolviendo 422. La regla pre-existente de "al menos un filtro" se mantiene.

## Requisitos funcionales

- RF-001: el endpoint `GET /api/finance/reports/entries-by-bucket` acepta `category_id=null` en query string como sinónimo de "sin categoría". La validación correspondiente es `'sometimes', 'nullable', 'uuid', 'exists:categories,id,user_id,$userId'`.
- RF-002: cuando el endpoint recibe `category_id=null`, internamente aplica `whereNull('journal_entries.category_id')` al query base.
- RF-003: cuando el endpoint recibe `kind=expense`, aplica `whereIn('journal_entries.kind', ['expense', 'credit_expense'])`.
- RF-004: cuando el endpoint recibe `kind=credit_expense` (o cualquier otro kind ≠ expense), aplica `where('journal_entries.kind', $value)` literal.
- RF-005: el helper `applyEntryFilters` usa `array_key_exists` (no `isset`) para detectar la presencia del filtro `category_id`, ya que `isset` devuelve `false` para `null`.
- RF-006: el frontend `EntriesDrilldownModal::pruneFilters` preserva `category_id: null` cuando la key existe en `props.filters`; no lo descarta. Otros valores `null` (de keys no relacionadas a `category_id`) siguen siendo descartados.
- RF-007: el endpoint sigue exigiendo al menos un filtro válido (regla `missing_filters` pre-existente). `category_id=null` cuenta como filtro válido para esta regla.
- RF-008: el helper `buildBucketLabel` debe rotular correctamente el bucket "Sin categorizar" cuando `category_id` viene como `null`, en lugar de devolver un label genérico (ej. "Movimientos sin categorizar").
- RF-009: el contrato JSON de respuesta del endpoint no cambia: sigue devolviendo `entries`, `truncated`, `total_count`, `bucket_label`.

## Casos principales

- Usuario en `/reports/by-category` hace click en bucket "Sin categorizar" → modal abre con entries `category_id IS NULL` del rango activo. Total mostrado y suma cuadran con el bucket.
- Usuario en `/reports/forecast` hace click en bucket "Sin categorizar" → mismo comportamiento.
- Usuario en `/reports/by-category` con `kind=expense` activo hace click en bucket "Comida" → modal abre con entries de `expense + credit_expense` con `category_id` de Comida. La suma cuadra con el bucket.
- Usuario tiene una tarjeta y hace `credit_expense` con categoría "Comida". El bucket "Comida" suma $5,000 ($3,000 expense + $2,000 credit_expense). El drill-down ahora muestra los 2 entries con la suma correcta.
- Usuario en `/reports/credit-cards` hace click en un cargo de una tarjeta → drill-down con `kind=credit_expense` literal (sin mezclar con expense). Comportamiento literal, sin cambios.
- Usuario en `/reports/cashflow` o `/reports/by-account` hace click en bucket de "ingreso" → drill-down con `kind=income` literal. Sin cambios.
- Click en "Ir a Movimientos" desde el modal navega a `/entries` con los mismos query params. Los nuevos comportamientos se preservan en `/entries` (porque `applyEntryFilters` es compartido) — el listado paginado muestra `expense + credit_expense` cuando `kind=expense`. Esto se confirma como **comportamiento deseado** porque mejora la consistencia con los reportes.

## Casos borde

- **`category_id=null` con UUID de otro usuario**: imposible (null no es UUID y no pasa por la validación `exists`). N/A.
- **`category_id` con UUID válido pero de otro usuario**: ya cubierto por `exists:categories,id,user_id,$userId`. Devuelve 422. Sin cambios.
- **`category_id=null` + entries sin categoría cancelados**: scope global de SoftDeletes los excluye. Resultado correcto.
- **`kind=expense` con `category_id=null`**: combinación válida. Devuelve entries de `expense + credit_expense` sin categoría. La suma cuadra con el bucket "Sin categorizar" de `ReportsByCategoryView` y `ReportsForecastView`.
- **`kind=expense` con `category_id` archivado**: cubierto por `exists` sin filtro de soft delete (existencia se valida tolerante a archivado, consistente con el patrón actual). Los entries históricos siguen siendo recuperables.
- **`kind=credit_expense` solo**: filtro literal, mantiene semántica original. Útil para `/reports/credit-cards`.
- **`kind=income`**: filtro literal. `whereIn(['income'])` y `where('kind', 'income')` son equivalentes; se mantiene `where` para minimizar cambio.
- **`kind=transfer` / `debt_payment` / `adjustment`**: filtro literal sin cambios.
- **Endpoint sin `category_id` y sin `kind`**: cae en `missing_filters` (422), regla pre-existente, sin cambios.
- **Endpoint con `category_id=null` único** (sin `kind`, `account_id`, `from`, `to`, `year_month`): pasa `missing_filters` porque hay un filtro válido. Devuelve entries sin categoría de toda la historia del usuario, con cap de 100. Caso poco común pero documentado.
- **Frontend con `category_id` no presente en filters** (ej. drill-down de `ReportsCashflowView`): pruneFilters no envía la key, comportamiento sin cambios.
- **Frontend con `category_id: undefined`**: pruneFilters sigue descartando (consistente con la regla "presente y explícitamente null").
- **Cache de Laravel/PHP de la query**: ninguno aplica. Endpoint es lectura pura por request.
- **Consumo del endpoint por `listEntries`**: el método `listEntries` (que paginar `/entries`) también usa `applyEntryFilters` y se beneficia automáticamente del fix de `kind=expense`. Esto es **deseado** (el usuario puede filtrar por "gastos" sin distinguir tarjeta vs efectivo). El cambio no requiere acción adicional en `listEntries`, pero los tests existentes de `/entries` deben seguir pasando.
- **Tests E2E de `/entries`**: ninguno se verá afectado por el cambio porque hoy no filtran por `kind=expense` deliberadamente para excluir `credit_expense`.

## Criterios de aceptacion

- Existe la validación `'sometimes', 'nullable', 'uuid', 'exists:...'` para `category_id` en el endpoint.
- Un test HTTP verifica que `GET /api/finance/reports/entries-by-bucket?category_id=&kind=expense` (vacío) devuelve entries con `category_id IS NULL` y `kind IN (expense, credit_expense)`.
- Un test HTTP verifica que `kind=expense` incluye entries `expense` y `credit_expense` en la misma respuesta.
- Un test HTTP verifica que `kind=credit_expense` mantiene filtro literal (no mezcla expense).
- Un test HTTP verifica que `kind=income`, `transfer`, `debt_payment` mantienen comportamiento literal.
- Un test HTTP verifica que `category_id=` (null) + `kind=expense` filtra correctamente entries sin categoría de tipo gasto.
- Un test HTTP verifica que `bucket_label` para `category_id=null` es algo del estilo "Movimientos sin categorizar" (no genérico).
- Un test frontend verifica que `pruneFilters({ category_id: null, kind: 'expense' })` preserva la key `category_id` con valor `null`.
- Un test frontend verifica que `pruneFilters({ kind: 'expense' })` (sin key `category_id`) no inserta la key.
- Smoke en navegador real: click en bucket "Sin categorizar" en `/reports/by-category` y en `/reports/forecast` muestra entries correctas. Click en cualquier bucket con `kind=expense` muestra `expense + credit_expense`.
- Suite backend completa verde (sin regresiones en los 386 tests existentes + nuevos).
- Suite frontend completa verde (sin regresiones en los 116 tests existentes + nuevos).
- Pint sin diffs en archivos modificados.

## Criterios medibles de exito

- `EntriesByBucketTest` gana al menos 5 tests nuevos cubriendo los casos de RF-002, RF-003, RF-004, RF-008, y el caso combinado `category_id=null + kind=expense`.
- `EntriesDrilldownModal.spec.js` gana al menos 2 tests cubriendo el nuevo comportamiento de `pruneFilters`.
- El bucket "Sin categorizar" del reporte `ReportsByCategoryView` y `ReportsForecastView` cuadra exactamente con su drill-down (validado en smoke con dataset real).
- El bucket de cualquier categoría con `credit_expense` cuadra exactamente con su drill-down (validado en smoke con dataset real).
- Tiempo de respuesta del endpoint no degrada (cambio agrega un `whereNull` o `whereIn` triviales, sin nuevos JOINs ni subqueries).

## Riesgos

- **Cambio de semántica del endpoint compartido por `listEntries`**: el helper `applyEntryFilters` es usado tanto por `entriesByBucket` como por `listEntries`. El fix de `kind=expense` afecta también `/entries`. Decisión: el cambio es **deseado** (usuario filtra "gastos" sin distinguir tarjeta vs efectivo), pero cualquier consumidor downstream que dependa del comportamiento literal anterior se ve afectado. Mitigación: documentar en `casos borde` y verificar tests existentes de `/entries`.
- **`array_key_exists` vs `isset`**: confundir uno por otro genera bug silencioso. `isset($filters['category_id'])` devuelve `false` cuando el valor es `null`, lo cual es exactamente el caso que estamos atendiendo. Mitigación: tests específicos del helper.
- **`category_id=` (string vacío) en query string**: Laravel puede interpretar el valor como `''` o `null` dependiendo de la versión y middleware. La regla `nullable` acepta ambos. Validar empíricamente en tests.
- **`exists:categories,id,user_id,$userId` con valor `null`**: Laravel's `exists` rule no se ejecuta para valores `nullable` cuando son `null`. Verificar.
- **Performance del `whereNull`**: con índice por `(user_id, category_id)`, el filtro de nulls es eficiente. Sin índice específico, Postgres usa el scan parcial. Aceptable para el volumen de FinCore.
- **bucket_label con `category_id=null`**: hoy `buildBucketLabel` podría no detectar el null y devolver un texto genérico. Ajustar para usar "Movimientos sin categorizar" cuando aplique.
- **Compatibilidad con clientes existentes**: el modal hoy no envía `category_id=null` (porque pruneFilters lo descarta). El cambio en el frontend es necesario para que el fix backend se active desde la UI. Pero si algún test o consumidor manda `category_id=null` directo al endpoint, ahora obtendrá comportamiento nuevo. Coherente con la corrección.

## Supuestos

- Los Report Services no cambian: siguen sumando `expense + credit_expense` para "gastos". El fix alinea el endpoint con esa semántica, no al revés.
- `pruneFilters` solo se invoca con `props.filters` que viene de las vistas (controlado). No hay riesgo de un caller pasando estructuras raras.
- Las 7 vistas que abren `EntriesDrilldownModal` ya pasan `category_id: bucket.category_id ?? null` o similar. No requieren cambios.
- El usuario espera que el bucket y el drill-down coincidan: cualquier diferencia es un bug.
- La regla "al menos un filtro" del endpoint sigue siendo válida después del cambio: `category_id=null` cuenta como filtro válido.
- La validación `exists:categories,id,user_id,$userId` con `nullable` no se aplica a `null`, así que no romp e el scope de seguridad.
- El cambio en `applyEntryFilters` aplica también a `listEntries` y se considera deseable.
- Los tests del sprint anterior (`ForecastReportTest`, `ReportsForecastView.spec.js`) NO requieren modificación: validan el reporte, no el drill-down.

## Impacto esperado

- 1 archivo backend modificado: `app/Http/Controllers/FinanceController.php` (validación + helper).
- 1 archivo frontend modificado: `frontend/src/components/finance/EntriesDrilldownModal.vue` (`pruneFilters`).
- 1 archivo de tests backend ampliado: `backend/tests/Feature/Http/EntriesByBucketTest.php` (+5 tests).
- 1 archivo de tests frontend ampliado: `frontend/tests/components/EntriesDrilldownModal.spec.js` (+2 tests).
- Sin migraciones.
- Sin cambios en CLAUDE.md ni en `docs/api/*` (el contrato no cambia: el endpoint sigue aceptando `category_id` y `kind`, pero ahora interpreta `null` y `expense` con la semántica nueva).
- Cero impacto en los 7 reportes existentes (no se tocan).
- Cero impacto en el módulo Plan, Settings, Auth.
- Mejora directa de UX en `ReportsByCategoryView` + `ReportsForecastView` (P1) y en todos los 7 reportes que usan `kind=expense` (P2).
- Mejora colateral en `/entries`: el filtro "Tipo = Gasto" ahora también incluye cargos de tarjeta.
