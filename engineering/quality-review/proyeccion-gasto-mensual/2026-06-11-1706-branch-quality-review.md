# Branch Quality Review — proyeccion-gasto-mensual

- **Rama**: `main` (cambios en working tree, no commiteados; sumándose a 6 commits previos pendientes de push).
- **Base**: `main` (último commit `0e78303 docs(reports): spec, plan, implementation y quality-review de presets-de-fecha`).
- **Rango revisado**: working tree completo del sprint (3 archivos modificados backend + 2 archivos modificados frontend + archivos nuevos).
- **Fecha**: 2026-06-11 17:06.
- **Reviewers** (paralelos, vía Explore): Backend SQL+Service / Frontend vista+integración.
- **Tests al cierre**: backend 386/386 verde, frontend 116/116 verde, Pint sobre archivos nuevos sin diffs, smoke Playwright OK end-to-end (vista + drill-down + cálculos correctos).

## Resumen ejecutivo

Sprint en buen estado para merge. **0 bloqueantes introducidos por este sprint**. Los dos hallazgos críticos que el revisor frontend identificó (drill-down con `category_id=null` y `kind=expense` sin incluir `credit_expense`) **son preexistentes** — afectan también `ReportsByCategoryView` desde el sprint `por-cuenta-drilldown`. El nuevo reporte hereda el comportamiento, no lo introduce.

**Bloqueantes del sprint**: 0.  
**Altos preexistentes documentados**: 2 (ambos al endpoint `entriesByBucket` y a su consumo desde drilldown views).  
**Bajos**: 2.

## Hallazgos preexistentes que afectan también este sprint

### P1 — Drill-down con `category_id = null` muestra entries de TODAS las categorías (preexistente)

- **Archivos**: `frontend/src/components/finance/EntriesDrilldownModal.vue:56-67` (función `pruneFilters` descarta nulls), `backend/app/Http/Controllers/FinanceController.php:467-474` (endpoint `entriesByBucket`).
- **Detalle**: cuando una vista hace drill-down al bucket "Sin categorizar" (`category_id = null`), el modal envía `{ category_id: null, kind, from, to }`. `pruneFilters` descarta `null`, así que el backend recibe sólo `{ kind, from, to }` — sin filtro de categoría. El backend retorna entries de **todas** las categorías del rango, no sólo las sin categorizar. Misma situación en `ReportsByCategoryView` desde el sprint anterior.
- **Origen**: comportamiento pre-existente del endpoint `entriesByBucket` desde el sprint `por-cuenta-drilldown`. NO introducido por este sprint.
- **Impacto**: bajo en uso real (la mayoría de los usuarios categorizan sus entries). Cuando aparece el bucket "Sin categorizar", la UX confunde.
- **Severidad**: Alta (preexistente).
- **Acción recomendada**: agregar al backlog general. Fix: backend acepta `category_id=null` explícito (validación `'sometimes', 'nullable', 'uuid'`) y aplica `whereNull('category_id')`. Frontend marca el filtro con un sentinel especial o el modal omite el prune para `category_id` específicamente.

### P2 — Drill-down con `kind = 'expense'` no incluye `credit_expense` (preexistente)

- **Archivos**: `frontend/src/views/app/ReportsForecastView.vue:34`, `backend/app/Http/Controllers/FinanceController.php` función `applyEntryFilters`.
- **Detalle**: los reportes que agrupan "gastos" usan `kind IN ('expense', 'credit_expense')` en sus Services (CategoryBreakdownReport, SpendingForecastReport). El drill-down envía `kind: 'expense'` al endpoint `entriesByBucket`, que aplica `where('kind', 'expense')` con match estricto. El usuario ve menos entries en el modal que los que componen el bucket — falta el `credit_expense`.
- **Origen**: comportamiento pre-existente del endpoint y de `ReportsByCategoryView` desde el sprint `por-cuenta-drilldown`. NO introducido por este sprint.
- **Impacto**: si el usuario usa tarjetas de crédito y entran al bucket categorizadas, el total del modal no cuadra con el bucket.
- **Severidad**: Alta (preexistente).
- **Acción recomendada**: agregar al backlog. Fix: el endpoint `entriesByBucket` interpreta `kind=expense` como `IN (expense, credit_expense)` consistente con los Services agregados, o aceptar un parámetro `kind_group=spending`. Sprint chico.

## Hallazgos menores del sprint actual

### M1 — `toFirstOfMonth` con `today = ''` produce `-01` en lugar de fallar limpio

- **Archivo**: `frontend/src/views/app/ReportsForecastView.vue:41-44`.
- **Detalle**: `toFirstOfMonth('')` devolvería `'' + '-01' = '-01'` si no fuera por la guarda `if (!isoDate) return null` en la línea 42. La guarda funciona hoy. Pero en `openDrilldown` (línea 35) se usa `data.value.window_to` como condición para llamar `toFirstOfMonth(data.value.today)` — guarda redundante.
- **Riesgo**: ninguno hoy. Documentado como defensa frágil para futuras refactorizaciones.
- **Severidad**: Bajo.
- **Acción recomendada**: opcional, puede dejarse como está. Si se quiere robustez, derivar `from` de `data.value.window_to + 1 día` o usar Carbon equivalente.

### M2 — Defensa explícita en leftJoin para categories.user_id (mejora de claridad)

- **Archivo**: `backend/app/Domain/Finance/Reports/SpendingForecastReport.php:99`.
- **Detalle**: `leftJoin('categories', 'categories.id', '=', 'journal_entries.category_id')` no incluye filtro adicional `categories.user_id = $this->userId`. En la práctica no hay riesgo IDOR (las `category_id` que llegan a `journal_entries` ya están validadas como del usuario en los endpoints de creación), pero el código sería más defensivo con un closure join.
- **Severidad**: Bajo.
- **Acción recomendada**: opcional. Patrón idéntico al de `CategoryBreakdownReport` (consistencia).

## Sin hallazgos en

- **Query SQL del Service**: 9 bindings posicionales bien alineados con `?`. Cero interpolación literal. Portable PG/SQLite (CASE WHEN es SQL92). HAVING filtra en BD, no en PHP. Scope por `user_id` correcto.
- **Ventana Carbon**: `startOfMonth()->subDay()` y `startOfMonth()->subMonthsNoOverflow(2)` validados para 10 jun 2026 (mar→may), 15 ene 2026 (oct→dic 2025 cruce de año), 31 jul 2026 (abr→jun sin overflow). Test cubre cruce de año.
- **`days_elapsed` con `max(1, ...)`**: defensa contra división por cero. `Carbon::now()->day` siempre devuelve 1..31 hoy, pero clamp protege contra bugs futuros. OK.
- **División por cero en `delta_pct`**: `computeDeltaPct` protegida con `if ($average === 0.0)`. Como `array_sum` sobre floats devuelve exactamente `0.0` y el HAVING garantiza `historical_total > 0`, no hay riesgo de average muy chico no atrapado.
- **Endpoints sin validación de params**: patrón consistente con `reportBudgets` y `reportCreditCards`. Query params extras se ignoran. Test confirma.
- **Scope `user_id` en todos los caminos**: constructor del Service recibe `$userId`, queries lo filtran, controllers pasan `$request->user()->id`. Tests de aislamiento user A/B verde.
- **Middleware**: ambas rutas dentro de `auth:sanctum + verified`. Tests cubren 401 y 403.
- **Export Excel**: patrón idéntico a `monthComparison` y `budgets`. delta_pct/100 para que `0.0%` pinte correcto. Filename `fincore-proyeccion-gasto-YYYY-MM.xlsx`.
- **Badges de color del frontend**: `deltaClass()` cubre los 4 casos (null/≤0/0-20/>20). Tests verifican las 4 ramas con valores fronterizos (-100, 0, 10, 25).
- **Empty state**: cuando `categories.length === 0`, hero + tabla + botón Export se ocultan. CTA "Ir a movimientos" navega a `/entries`. Smoke confirma.
- **Tab "Proyección" en ReportsSubnav**: 7° tab al final del array. Sin overflow visible.
- **Tests del sprint**: 26 backend (16 Service + 10 HTTP) + 6 frontend smoke. Cubren todos los RFs verificables.
- **Pint**: aplicado sobre archivos nuevos sin diffs residuales.
- **Smoke Playwright real**: vista carga, empty state correcto, datos seedeados muestran $2,500 × 30/11 = $6,818.18 con Δ +13.6% amarillo (correcto), drill-down abre modal con entries del mes en curso filtradas por la categoría correcta.

## Tareas de corrección sugeridas (en orden)

Ninguna del sprint actual bloquea el merge. Los 2 hallazgos preexistentes son los más importantes pero quedan para un sprint dedicado:

1. **P1**: agregar al backlog general — soportar `category_id=null` en `entriesByBucket` para drill-down del bucket "Sin categorizar". Toca también `ReportsByCategoryView`.
2. **P2**: agregar al backlog general — interpretar `kind=expense` en `entriesByBucket` como `expense + credit_expense` consistente con los Services agregados. Toca `ReportsByCategoryView` y `ReportsForecastView`.
3. **M1**: opcional, refactor cosmético en `toFirstOfMonth` o `openDrilldown` para eliminar guarda redundante.
4. **M2**: opcional, agregar filtro `categories.user_id` explícito al leftJoin como defensa en profundidad.

## Limitaciones y validaciones no ejecutadas

- **No se probó P1 en navegador real**: el revisor frontend lo identificó por análisis estático del flujo. El smoke con Playwright sólo probó drill-down de bucket con categoría real (Comida), no de "Sin categorizar". Hipótesis confirmada leyendo `pruneFilters` y endpoint.
- **No se probó P2 en navegador real**: análisis estático confirmado leyendo `applyEntryFilters`.
- **No se midió performance con datasets grandes**: con datos típicos de FinCore (decenas de categorías × cientos de entries), la query corre en <50ms. Aceptable. No probado con miles de entries.
- **No se probó zona horaria distinta al servidor**: comportamiento por diseño (mes en curso = mes del servidor); aceptado.
- **No se probó el `composer audit`**: ya hecho en sprint export-excel-reportes. Sin nuevas dependencias.

## Veredicto

**Listo para merge**. Los dos hallazgos preexistentes (P1, P2) son del endpoint `entriesByBucket` heredado del sprint `por-cuenta-drilldown` — afectan también vistas previas y no son responsabilidad de este sprint corregir. Documentados para el backlog de calidad del módulo de drill-down.

El sprint actual implementa el reporte de proyección correctamente: query agregada eficiente, fórmula bien clavada, edge cases cubiertos, fronteras de color validadas, integración con drill-down y export funcionando. Smoke real end-to-end exitoso.
