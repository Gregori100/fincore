# Branch Quality Review — por-cuenta-drilldown

**Fecha**: 2026-06-10 19:35
**Rama**: `main` (working tree, sin commits aún) — 17 modificados + 4 nuevos código + 3 tests + spec/plan/implementation docs.
**Base**: `origin/main` (1 commit detrás conceptualmente; los cambios viven en working tree).
**Alcance**: cobertura de `engineering/specs/por-cuenta-drilldown/`.
**Implementation review**: `engineering/specs/por-cuenta-drilldown/implementation/implementation-review.md`.

Revisión paralelizada en 4 dimensiones: backend seguridad/SQL/scope; frontend mapeo de filtros (RF-007); modal + EntriesTable detalle; cobertura de tests.

## Resumen ejecutivo

- **0 bloqueantes para merge en el contexto del proyecto** (uso personal en MX). El feature está correcto, los tests cubren bien los riesgos críticos (322 backend + 53 frontend verde, smoke real end-to-end exitoso).
- **2 hallazgos ALTOS** que vale la pena atender antes del commit: zona horaria en `EntriesTable.applyQueryToFilters` (no rompe en MX pero sí en GMT+) y cobertura HTTP del endpoint `/finance/reports/by-account` (solo hay test del Service, no HTTP feature).
- **2 hallazgos MEDIOS** sobre defense-in-depth y UX de buckets con valor 0.
- **Hallazgos BAJOS**: pequeñas inconsistencias de estilo y casos borde benignos.

Recomendación: arreglar los 2 altos antes de commit (cambios pequeños y testeables). Los medios y bajos pueden ir como follow-up si se quiere.

## Hallazgos bloqueantes

Ninguno.

## Hallazgos ALTO

### A1 — Zona horaria en `applyQueryToFilters` (EntriesTable.vue)

`frontend/src/components/finance/EntriesTable.vue` (función `applyQueryToFilters`, líneas ~120-139).

La traducción de `year_month` a `from`/`to` usa `new Date(y, m - 1, 1).toISOString().slice(0, 10)`. `toISOString()` convierte a UTC, así que en zonas GMT positivas (Sydney GMT+10, p.ej.) el día se "atrasa": `new Date(2026, 4, 31)` (31 mayo local) → en UTC se vuelve `2026-05-30T14:00:00Z` → slice da `2026-05-30`.

**Confirmación empírica en MX (GMT-6)**: `new Date(2026, 4, 31).toISOString().slice(0,10)` = `2026-05-31` ✅ — el bug no afecta al usuario actual. Pero es deuda real para cualquier deploy futuro con usuarios en otra zona.

**Fix** (one-liner): reemplazar `toISOString().slice(0, 10)` por concatenación local:

```js
const iso = (d) => `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`
```

O importar `toISODate(date)` desde `@/utils/dates` si ya existe.

**Severidad**: ALTO conceptual / BAJO operacional (uso actual no expone el bug).

---

### A2 — Cobertura HTTP del endpoint `/finance/reports/by-account`

`backend/tests/Feature/Http/FinanceApiTest.php` no tiene tests del endpoint. Solo está cubierto el Service en `ByAccountReportTest` (10 casos unit, todos verdes).

El plan (T020) menciona "agregar al `FinanceApiTest` los casos del endpoint by-account (shape, scope, default range)". No se hizo.

**Riesgo**: si el controller introduce un bug en validación, default range o serialización, no hay test que lo capture. El smoke real cubrió shape; pero no scope (usuario A no ve datos de B) ni default range explícitamente vía HTTP.

**Fix**: agregar ~3 casos a `FinanceApiTest`:

```php
public function test_by_account_report_returns_shape(): void
public function test_by_account_respects_user_and_excludes_archived(): void
public function test_by_account_default_range_is_current_month(): void
```

~50 LOC, reusan el `setUp()` existente.

## Hallazgos MEDIO

### M1 — `exists:accounts,id` y `exists:categories,id` sin scope user_id

`FinanceController::entriesByBucket` (validación líneas ~451-457) y `listEntries` (~223-229).

Las validaciones aceptan IDs válidos pertenecientes a OTROS usuarios sin disparar 422. El query principal con `where('user_id', $userId)` previene fuga de datos (defense-in-depth), pero permite probing ("¿existe este UUID?") y el feedback al cliente es ambiguo.

**Fix opcional**: cambiar a `'exists:accounts,id,user_id,'.$request->user()->id`. Trabajo ~1 línea por validación.

**Severidad**: MEDIO conceptual / BAJO operacional (la fuga de datos está bloqueada por el scope del query).

---

### M2 — Buckets con valor 0 son clickeables en 3 reportes

- `CategoryBreakdownList.vue:46`
- `MonthComparisonList.vue:67`
- `BudgetsList.vue:48`

Si un bucket llega con `total=0` o `current=0` (categoría sin actividad en el periodo), el `<li>` mantiene cursor pointer y dispara `@click="emit('drilldown', b)"`. El modal abre vacío.

En la práctica los Services del proyecto filtran a buckets con actividad, así que no aparece. Pero si el filtrado cambia o si una categoría tiene 0 hoy pero historial, podría salir.

**Fix**: agregar condicional en `@click`:

```vue
@click="(b.total ?? b.current ?? 0) > 0 && emit('drilldown', b)"
```

`ReportsByAccountView` ya lo hace bien con `r.income > 0 && openDrilldown(...)` — patrón consistente.

## Hallazgos BAJO

- **B1 `pruneFilters`** (`EntriesDrilldownModal.vue:56-64`): la condición elimina `0` y `false` además de `null`/`undefined`/`''`. No afecta hoy (ningún filtro usa booleano/0), pero deuda menor si la API cambia.
- **B2 N+1 en `ByAccountReport`** (`backend/app/Domain/Finance/Reports/ByAccountReport.php`): 2N queries para N cuentas (income + expense por cada). Aceptable para uso personal (N≤10); patrón consistente con `BudgetsReport`. Documentar.
- **B3 `MonthlyCashflowChart.vue` sin tests propios**. El emit en click de barra está cableado correctamente por inspección y verificado en runtime, pero no hay test vitest.
- **B4 Concatenación `$to.' 23:59:59'`** en `ByAccountReport` líneas 48, 55 — inconsistente con el patrón de `CashflowMonthlyReport`. No afecta funcionalidad (Eloquent bindea), solo estilo.
- **B5 `EntriesByBucketTest` no cubre explícitamente** `kind=transfer + category_id` (debería devolver vacío) ni `account_id + category_id` simultáneos. Casos benignos.
- **B6 Test del flujo "Ir a Movimientos"** en el modal verifica el emit pero no el `router.push`. Asumido funcional por smoke real.

## Lo que está OK (sin hallazgos)

- ✅ **Refactor `applyEntryFilters`** es 1:1 con la lógica original; el test gate `test_entries_endpoint_paginates_and_filters` verde inmediatamente tras T001.
- ✅ **Scope por `user_id`** en `entriesByBucket`, `reportByAccount` y `ByAccountReport`.
- ✅ **SoftDeletes**: heredado correctamente; `buildBucketLabel` usa `withTrashed()` para preservar nombres históricos.
- ✅ **Cap 100 + truncated**: `(clone $query)->count()` separado de `limit(100)->get()`.
- ✅ **Validación `missing_filters`**: 422 con `code: missing_filters`.
- ✅ **`year_month`**: regex estricto `^\d{4}-(0[1-9]|1[0-2])$`, prevalece sobre from/to, traducción a Carbon `endOfMonth()` cubre 28/29/30/31.
- ✅ **Eager loading anti-N+1**: confirmado por test `test_eager_loads_relations_no_n_plus_1` (assertLessThan(10) con 20 entries).
- ✅ **Rutas** en grupo `auth:sanctum + verified`.
- ✅ **Mapeo de filtros RF-007**: 6/6 reportes correctos. El handler `openDrilldown(row, kindOverride)` en `ReportsByAccountView` mapea bien la semántica de tarjetas (income → debt_payment, expense → credit_expense).
- ✅ **Chart cashflow**: discrimina datasetIndex 2 (Neto, línea) y NO emite drilldown. Cursor pointer condicional con `onHover`.
- ✅ **Buckets con valor 0 en `ReportsByAccountView`**: condicional `r.income > 0 &&` correctamente aplicado.
- ✅ **EntriesTable**: query params aplicados antes del fetch; `props.accountId` tiene precedencia sobre `filters.value.account_id` (caso `/accounts/:uuid/entries`).
- ✅ **EntriesDrilldownModal**:
  - `watch(open, ..., { immediate: true })` correcto — sólo fetch cuando isOpen=true.
  - Botón "Ir a Movimientos" deshabilitado solo cuando 0 entries y no truncado.
  - Manejo de errores 422 muestra `payload?.error` legible.
  - Manejo de archivados: badge guion cuando `e.category=null`; nombre histórico cuando `e.origin/destination` vienen con `withTrashed()` del backend.
- ✅ **Sin SQL injection**: todo Eloquent con bindings.

## Tareas de corrección (ordenadas por dependencia)

1. **A1** — Fix TZ: 1 LOC en `EntriesTable.vue`, reemplazar `toISOString().slice(0, 10)` por helper local. Sin tests nuevos (el flujo manual ya validó).
2. **A2** — Tests HTTP del endpoint by-account: 3 casos en `FinanceApiTest`. ~50 LOC. Suite ≥ 325.
3. **M1** *(opcional)* — Validación `exists:..., user_id`: 2 cambios pequeños en `entriesByBucket` y `listEntries`. No requiere nuevos tests (la cobertura de scope ya existe).
4. **M2** *(opcional)* — Condicional `>0` en `@click` en los 3 list components. UX más limpia.

Los hallazgos BAJO pueden seguir como follow-ups; no son riesgos reales para este merge.

## Limitaciones y validaciones no ejecutadas

- **Performance bajo carga real**: ningún benchmark con N>50 cuentas o >10k entries. Para uso personal no aplica.
- **E2E del flujo "modal → /entries → aplicar filtros"**: validado manualmente vía Playwright (paso 3 del smoke), no automatizado.
- **Multi-zona horaria del usuario**: deploy actual solo en GMT-6 (MX).
- **Bundle size**: no se inspeccionó si el modal se duplica en chunks. Recomendado un `npm run build` + ver tamaños antes de un release público (no de este sprint).

## Conclusión

La rama está **lista para commit** desde la perspectiva del usuario actual del proyecto (uso personal en MX). Los dos hallazgos ALTO son baratos de arreglar (~30-45 min total) y mejorarían claramente la calidad — recomiendo hacerlos antes de los commits.

Si se opta por mergear sin arreglarlos, dejar issue para hacer follow-up.
