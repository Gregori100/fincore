# Branch Quality Review — entries-by-bucket-fixes

- **Rama**: `main` (cambios en working tree, no commiteados; sumándose a 9 commits previos pendientes de push).
- **Base**: `main` (último commit `14824e8 docs(reports): spec, plan, implementation y quality-review de proyeccion-gasto-mensual`).
- **Rango revisado**: working tree del sprint (1 archivo backend modificado + 1 archivo backend de tests modificado + 1 archivo frontend modificado + 1 archivo frontend de tests modificado).
- **Fecha**: 2026-06-11 17:48.
- **Reviewers**: 2 Explore en paralelo (backend SQL+helper; frontend pruneFilters+consumidores).
- **Tests al cierre**: backend 394/394 verde, frontend 119/119 verde, Pint limpio en archivos del sprint, smoke con Playwright end-to-end exitoso para P1+P2.

## Resumen ejecutivo

Sprint en buen estado para merge para los **2 escenarios principales validados en smoke**: drill-down del bucket "Sin categorizar" (P1) y drill-down con `kind=expense` incluyendo `credit_expense` (P2). Cero bloqueantes nuevos introducidos por el sprint en esos flujos.

Durante la implementación apareció **un fix emergente necesario**: el filtro `to` del helper `applyEntryFilters` aplicaba `<= $to` sin hora, excluyendo entries del último día. Sin el fix, P2 no se veía funcionar en smoke aunque los unit tests pasaran. Se corrigió a `<= $to.' 23:59:59'` alineando con los Report Services.

El QR identificó **2 hallazgos preexistentes** que afectan flujos vecinos pero **NO son responsabilidad de este sprint**:

- **F1**: `listEntries` valida `category_id` sin `nullable`. El flujo "Ir a Movimientos" desde el bucket "Sin categorizar" navega a `/entries?category_id=`, EntriesTable hace truthy check `if (q.category_id)` que falla con `''`, y el filtro nunca se aplica. Resultado: el usuario llega a `/entries` y ve todos los movimientos. Documentado para backlog como sprint chico: requiere validación nullable + EntriesTable sentinel + opción "Sin categorizar" en BaseSelect.
- **F2**: bucket "Otras" sintético (cuando hay más de 6 categorías en `ReportsByCategoryView`) navega con `category_id='__others__'`, que falla la validación UUID del endpoint con 422. Preexistente desde el sprint `por-cuenta-drilldown`.

Otros hallazgos menores (debt_payment/adjustment sin tests literales, cobertura de edge cases) son aceptables como mejoras opcionales.

**Bloqueantes del sprint**: 0.  
**Altos**: 0.  
**Medios preexistentes documentados**: 2 (F1, F2).  
**Bajos**: 3.

## Hallazgos

### M1 (preexistente) — "Ir a Movimientos" desde "Sin categorizar" no completa el filtro en /entries

- **Archivos**: `frontend/src/components/finance/EntriesTable.vue:137` (`applyQueryToFilters`), `backend/app/Http/Controllers/FinanceController.php:228` (validación `listEntries`).
- **Detalle**: tras el sprint, el modal del drill-down funciona y la navegación "Ir a Movimientos" pasa `category_id=''` por query string. Pero:
  - `applyQueryToFilters` hace `if (q.category_id)` que es falsy con `''` → el filtro local no se aplica.
  - `fetchEntries` hace `if (filters.value.category_id)` que es falsy con `''`/`null` → no se envía al backend.
  - `listEntries` valida `['sometimes', 'uuid', 'exists:...']` sin `nullable` → rechazaría `category_id=''` con 422 si llegara.
- **Origen**: comportamiento pre-existente desde el sprint `por-cuenta-drilldown`. El sprint actual mejoró el drill-down modal (P1 ✓), pero el flujo "Ir a Movimientos" sigue roto para "Sin categorizar".
- **Impacto**: el usuario hace click en "Ir a Movimientos" desde el bucket "Sin categorizar" y `/entries` muestra todos los movimientos. Confuso. Mismo problema que P1 antes del fix, pero en otro punto del flujo.
- **Severidad**: Medio (preexistente).
- **Acción recomendada**: sprint chico dedicado. Requiere: validación `listEntries` con `nullable`; `applyQueryToFilters` y `fetchEntries` con detección de presencia de key (no truthy); opción "Sin categorizar" en el `BaseSelect` de categorías de `EntriesTable` o sentinel UI; tests.
- **Decisión de este sprint**: se intentó incluir el fix completo durante el QR, pero requería más cambios (UI del BaseSelect, sentinel value) que excederían el alcance acordado. Se revirtió y se documentó.

### M2 (preexistente) — Bucket "Otras" en ReportsByCategoryView falla la validación al hacer drill-down

- **Archivo**: `frontend/src/views/app/ReportsByCategoryView.vue:69` (computed `chartBuckets`).
- **Detalle**: cuando hay más de 6 categorías, el cómputo agrupa el resto como un bucket sintético con `category_id: '__others__'`. Si el usuario hace click en él, el drill-down envía `category_id='__others__'` al backend, que falla la validación `uuid` con 422.
- **Origen**: comportamiento pre-existente desde el sprint `por-cuenta-drilldown`.
- **Impacto**: bajo (sólo afecta a usuarios con muchas categorías que clickean el bucket "Otras"). Sin error visible en la mayoría de casos.
- **Severidad**: Medio (preexistente).
- **Acción recomendada**: en `ReportsByCategoryView`, el bucket "Otras" debería deshabilitar el click o filtrar al endpoint por exclusión (`category_id NOT IN (top_6)`). Documentar en backlog.

### B1 — `KIND_ADJUSTMENT` no mapeado en `buildBucketLabel` (preexistente)

- **Archivo**: `backend/app/Http/Controllers/FinanceController.php:548-554`.
- **Detalle**: el array `$kindLabel` mapea 5 kinds (income, expense, credit_expense, debt_payment, transfer). Si llega `kind=adjustment`, cae al fallback `'Movimientos'`. El sprint no introduce esto.
- **Origen**: preexistente.
- **Severidad**: Bajo.
- **Acción recomendada**: agregar `JournalEntry::KIND_ADJUSTMENT => 'Ajustes'` cuando se atienda el caso (Adjustment aún no se usa activamente en la app).

### B2 — Cobertura de tests no incluye `kind=debt_payment` ni `kind=adjustment` literal

- **Archivo**: `backend/tests/Feature/Http/EntriesByBucketTest.php`.
- **Detalle**: los 8 tests nuevos cubren `expense`, `income`, `credit_expense`, `transfer`. Faltan `debt_payment` y `adjustment` como casos explícitos.
- **Severidad**: Bajo.
- **Acción recomendada**: agregar 2 tests opcionales si se quiere cobertura exhaustiva.

### B3 — Test de regresión específica para el boundary del último día del rango

- **Archivos**: `backend/tests/Feature/Http/EntriesByBucketTest.php`, `backend/tests/Feature/Http/FinanceApiTest.php`.
- **Detalle**: el fix de `to` con `' 23:59:59'` no tiene un test específico que valide el caso boundary (entry creada hoy a las 23:59 con filtro `to=hoy`). El smoke con Playwright lo cubrió empíricamente, pero no hay regression test.
- **Severidad**: Bajo.
- **Acción recomendada**: agregar test específico si surge necesidad.

## Sin hallazgos en

- **Cambio del helper `applyEntryFilters` con `array_key_exists` solo para `category_id`**: las otras keys (`account_id`, `kind`, `from`, `to`) mantienen `isset`. Sin regresiones, suite verde.
- **`kind=expense` whereIn**: aplicado solo cuando `$filters['kind'] === KIND_EXPENSE`. Otros kinds caen al else con `where` literal. Test `test_kind_credit_expense_literal_does_not_mix_with_expense` confirma.
- **Validación `nullable` + `exists` con valor null**: Laravel 12 salta `exists` y `uuid` cuando el valor es null. Verificado empíricamente con el test `test_category_id_null_filters_uncategorized_entries`.
- **String vacío `''` en query string**: el frontend traduce `null` → `''` por axios; backend con `nullable` lo trata como null. Test verde end-to-end.
- **Fix `to` con `' 23:59:59'`**: aplicado al helper compartido, mejora también `listEntries`. Cero regresiones en los 394 tests existentes.
- **`buildBucketLabel` con `category_id=null`**: agrega "sin categorizar" en el orden correcto del label. Test confirma el caso para `kind=expense + category_id=null`.
- **`empty($data)` con `category_id: null`**: PHP `empty(['category_id' => null])` devuelve false porque el array tiene una key. El chequeo `missing_filters` sigue funcionando.
- **Pint sobre archivos del sprint**: limpio.
- **Smoke real con Playwright**: P1 ✓ (bucket "Sin categorizar" abre modal con title correcto y solo entries sin categoría), P2 ✓ (bucket "Comida" abre modal con expense + credit_expense, total cuadra exactamente).

## Tareas de corrección sugeridas (en orden)

Ninguna del sprint actual bloquea el merge. En orden de impacto para backlog:

1. **M1**: sprint chico para completar el flujo "Ir a Movimientos" desde "Sin categorizar". Tocaría `listEntries`, `EntriesTable.applyQueryToFilters`, `EntriesTable.fetchEntries` y la UI del filtro de categorías.
2. **M2**: en `ReportsByCategoryView`, el bucket "Otras" debe deshabilitar el click o filtrar por exclusión.
3. **B1**: agregar `KIND_ADJUSTMENT => 'Ajustes'` al `$kindLabel` cuando se reactive adjustment.
4. **B2**: 2 tests opcionales para `debt_payment` y `adjustment`.
5. **B3**: 1 test boundary opcional para el último día del rango.

## Limitaciones y validaciones no ejecutadas

- **Smoke de "Ir a Movimientos"**: no se validó en navegador real porque sabíamos por análisis estático que estaba roto. Confirmado por código en `EntriesTable.applyQueryToFilters` y `fetchEntries`.
- **Bucket "Otras"**: no se reprodujo en navegador real (requiere usuario con 7+ categorías activas).
- **Tests E2E**: no se agregaron (consistente con sprints previos del módulo).
- **`composer audit`**: cubierto en sprints previos, sin nuevas dependencias.
- **Análisis del impacto en `/entries`** del fix `kind=expense` whereIn: documentado como deseable; no medido empíricamente con usuarios reales.

## Veredicto

**Listo para merge**. El sprint cumple su objetivo declarado: arreglar P1 (drill-down a "Sin categorizar") y P2 (`kind=expense` incluye `credit_expense`) en el endpoint `entriesByBucket`. Cero bloqueantes introducidos. Fix emergente del rango `to` mejora la consistencia con los Report Services.

Los 2 hallazgos medios documentados (M1 "Ir a Movimientos" completo, M2 bucket "Otras") son flujos vecinos preexistentes que requieren su propio sprint y no comprometen este merge.
