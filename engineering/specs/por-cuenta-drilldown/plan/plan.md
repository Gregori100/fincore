# Plan técnico — Reporte "por cuenta" + drill-down transversal

## Enfoque tecnico

Dos piezas independientes que se entregan juntas porque comparten el modal y se influyen en UX. El **reporte por cuenta** es un Service nuevo en `Domain/Finance/Reports/` análogo a los cinco existentes, con su endpoint en `FinanceController`. El **drill-down transversal** es un endpoint genérico `entries-by-bucket` (también en `FinanceController`) que reusa la lógica de filtros de `listEntries`. Para evitar duplicar la armada de query, se extrae un helper privado `applyEntryFilters` dentro del propio controller (más simple que crear un Service ahora; si en el futuro aparece un tercer consumidor, se promueve a `Domain/Finance/Support/EntryQueryBuilder`).

En frontend, un componente reusable `EntriesDrilldownModal.vue` centraliza la UI; cada reporte le pasa un objeto de filtros y el modal hace el fetch al endpoint genérico, arma el label, renderiza la tabla compacta y ofrece "Ir a /entries" con query params. Los 5 reportes existentes ganan handlers de click que abren el modal. La vista `/entries` lee query params en mount para precargar filtros sin tocar su UI.

## Requisitos funcionales cubiertos

- RF-001 (endpoint by-account): `ByAccountReport::execute($userId, $from, $to)` arma el array por cuenta no archivada y `FinanceController::reportByAccount` lo expone en `GET /api/finance/reports/by-account`.
- RF-002 (scope y soft-deleted): el Service filtra `JournalEntry` activos por `user_id` y `Account` activos por `user_id`.
- RF-003 (endpoint drill-down): `FinanceController::entriesByBucket` con filtros `kind`, `account_id`, `category_id`, `from`, `to`, `year_month` (este último se traduce a from/to). Respuesta `{ entries, truncated, total_count, bucket_label }`.
- RF-004 (cap 100 + eager loading): query con `with(['origin','destination','category'])` + `limit(100)` + `count()` separado para `total_count`. Orden `occurred_at DESC`.
- RF-005 (vista by-account con celdas clickeables): `ReportsByAccountView.vue` renderiza tabla con onClick por celda.
- RF-006 (subnav): se agrega `{ name: 'reports-by-account', label: 'Por cuenta' }` al array de tabs de `ReportsSubnav.vue`.
- RF-007 (mapeo de filtros por reporte): cada uno de los 5 reportes existentes implementa su handler con el mapeo exacto de la spec; centralizado el modal, la diferencia es solo el objeto de filtros que se le pasa.
- RF-008 (UI del modal): `EntriesDrilldownModal` con header (bucket_label + total), tabla compacta, footer con Cerrar / Ir a /entries.
- RF-009 (query params en /entries): `EntriesTable.vue` (donde viven los filtros) lee `route.query` en mount; los aplica a `filters.value` si están presentes.
- RF-010 (aviso de truncado): el modal muestra el aviso cuando `truncated: true`.
- RF-011 (accesibilidad modal): `BaseModal` ya cubre Escape, click-fuera, foco trampado; `EntriesDrilldownModal` no pasa `persistent`.
- RF-012 (auth): rutas dentro del grupo `['auth:sanctum','verified']` existente.

## Archivos o modulos probablemente afectados

### Backend (nuevo)

- `backend/app/Domain/Finance/Reports/ByAccountReport.php`
- `backend/tests/Feature/Finance/ByAccountReportTest.php`
- `backend/tests/Feature/Http/EntriesByBucketTest.php`

### Backend (modificado)

- `backend/app/Http/Controllers/FinanceController.php`:
  - Extraer helper privado `applyEntryFilters(Builder $q, array $filters)` reusado por `listEntries` y `entriesByBucket`.
  - Agregar método `reportByAccount`.
  - Agregar método `entriesByBucket`.
- `backend/routes/api.php`: 2 rutas nuevas bajo `/finance/reports/*`.
- `backend/tests/Feature/Http/FinanceApiTest.php`: agregar smoke del endpoint by-account; verificar que `listEntries` no regrese tras el refactor del helper.

### Frontend (nuevo)

- `frontend/src/views/app/ReportsByAccountView.vue`
- `frontend/src/components/finance/EntriesDrilldownModal.vue`

### Frontend (modificado)

- `frontend/src/api/finance.js`: agregar `reportByAccount({ from, to })` y `entriesByBucket(filters)`.
- `frontend/src/components/finance/ReportsSubnav.vue`: agregar sexto tab.
- `frontend/src/router/index.js`: ruta `/reports/by-account` lazy.
- Los 5 reportes existentes para emitir/abrir el modal:
  - `frontend/src/views/app/ReportsByCategoryView.vue` (+ posibles componentes hijos: `CategoryBreakdownChart`, `CategoryBreakdownList`).
  - `frontend/src/views/app/ReportsCashflowView.vue` (+ `MonthlyCashflowChart` para emit en click de barra).
  - `frontend/src/views/app/ReportsMonthComparisonView.vue` (+ `MonthComparisonList`).
  - `frontend/src/views/app/ReportsCreditCardsView.vue` (+ `CreditCardSummary`).
  - `frontend/src/views/app/ReportsBudgetsView.vue` (+ `BudgetsList`).
- `frontend/src/components/finance/EntriesTable.vue`: leer `route.query` en `onMounted` y precargar `filters` si vienen.
- `frontend/tests/components/EntriesDrilldownModal.spec.js` (smoke).

### Documentación

- `CLAUDE.md`: agregar fila para los dos endpoints nuevos.

## Entidades y estados afectados

- **Account**: solo lectura, scope por `user_id` y `deleted_at IS NULL`. `is_protected` no relevante acá. Cuentas archivadas no aparecen en la tabla del reporte, pero sí pueden aparecer como referencia histórica si el modal abre con un `account_id` archivado.
- **JournalEntry**: solo lectura, scope por `user_id` y por defecto sin `withTrashed`. Eager load de `origin`, `destination` (ambos `withTrashed` por convención del proyecto para preservar nombres históricos), `category`.
- **Category**: solo lectura; en el modal se muestra el badge cuando existe; archivada → `null` (Eloquent default sin `withTrashed`), la UI muestra guion.
- Sin transiciones de estado ni efectos secundarios; ninguna escritura.

## Compatibilidad con datos y procesos existentes

- **Sin cambios de schema**, sin migraciones.
- **Refactor del helper de filtros** en `FinanceController`: el helper privado encapsula la misma lógica que ya tiene `listEntries`. Tests existentes de `/entries` deben seguir verdes sin modificación.
- **Reportes existentes**: cambian su template/handlers para drill-down. La data que ya devuelven sus endpoints se mantiene; el frontend solo agrega interactividad.
- **/entries con query params**: hoy ignora `route.query`; lo nuevo es leerlos en mount. Compatible: si no vienen, el comportamiento es idéntico al actual. La E2E del flujo de entries (que no usa query params) no se ve afectada.
- **CLI commands**: no se tocan.

## Cambios de datos

Ninguno.

## Cambios de API

Nuevas rutas dentro de `Route::middleware(['auth:sanctum','verified'])->prefix('finance')->group(...)`:

- `GET /finance/reports/by-account?from=YYYY-MM-DD&to=YYYY-MM-DD` → devuelve `{ from, to, accounts: [{ account_id, name, type, income, expense, net }, ...] }`. Rango por defecto: mes en curso si no se pasan parámetros.
- `GET /finance/reports/entries-by-bucket` → query params: `kind`, `account_id`, `category_id`, `from`, `to`, `year_month`. Respuesta: `{ entries: [{...}], truncated: bool, total_count: int, bucket_label: string }`.

Errores estándar: 422 en validación, 401/403 en auth. `year_month` malformado → 422.

`listEntries` queda con su contrato intacto.

## Cambios de UI

- Nuevo tab "Por cuenta" en `ReportsSubnav`. Orden: lo agrego al final del array.
- Vista `/reports/by-account` con: hero opcional (totales agregados), filtros de rango (mismo patrón que `/reports/by-category`), tabla con columnas Cuenta | Ingresos | Gastos | Neto. Cada celda numérica y el nombre de la cuenta clickeables.
- Modal `EntriesDrilldownModal`: header con label y total, tabla compacta (fecha, monto con signo, descripción, cuentas, badge categoría), aviso de truncado cuando aplica, footer con "Cerrar" y "Ir a /entries".
- Los 5 reportes existentes ganan handlers; idealmente el bucket se ve igual pero con cursor pointer + hover sutil para indicar que es clickeable. Buckets de monto 0 no son clickeables (cursor default, sin handler).
- Copy en `/reports/by-account`: párrafo bajo el header explicando la semántica en tarjetas ("Para una tarjeta de crédito, 'Entradas' son los pagos recibidos a la deuda y 'Salidas' son los cargos hechos a la tarjeta").

## Cambios de permisos

Ninguno nuevo. Ambos endpoints bajo `auth:sanctum + verified`, scoped por `request->user()->id`.

## Riesgos tecnicos

- **Refactor de listEntries**: si el helper privado introduce un cambio sutil de comportamiento (orden, índices), `entries endpoint paginates and filters` (test existente) podría fallar. Mitigación: el refactor preserva exactamente la query original; correr el test existente como gate.
- **N+1 en el modal**: si el frontend olvida pasar `bucket_label` o la respuesta es lenta por falta de eager load, hay degradación. Mitigación: query en backend siempre eager-loaded; assert en tests anti-N+1 con `DB::enableQueryLog()` + recuento de queries.
- **Buckets clickeables con $0**: si por error se permite click en un bucket vacío, el modal abre con tabla vacía. Mitigación: deshabilitar click con un condicional `:class` + `@click="amount > 0 && openDrilldown(...)"`.
- **Mapeo de filtros incorrecto por reporte**: error en un mapeo (RF-007) produce un drill-down que no coincide con el bucket. Mitigación: una constante o helper por reporte que arme el objeto de filtros, testeable por inspección visual y al menos un smoke por reporte.
- **`/entries` precarga incorrecta**: si los query params se aplican mal, los filtros quedan vacíos o desfasados al volver a la vista. Mitigación: aplicarlos solo si el filtro actual está vacío (no pisar cambios manuales del usuario), o siempre aplicar si vienen presentes.
- **Performance del reporte by-account con muchos movimientos**: agregaciones de income/expense por cuenta hacen scan de `journal_entries`. Para usuarios con cientos de movimientos no es problema; con miles podría requerir índice. Mitigación: existe `(user_id, occurred_at)` en `journal_entries`; suficiente para el rango típico.
- **Inconsistencia visual entre reportes**: cada reporte tiene su look; agregar clickabilidad sin saturar requiere disciplina. Mitigación: clase utilitaria compartida (`cursor-pointer hover:bg-...`) aplicada uniformemente.

## Estrategia de pruebas

- **Backend unit/feature**:
  - `ByAccountReportTest`: 6+ casos (sin movimientos, con income/expense/transfer/debt_payment/credit_expense, neto correcto, excluye archivados, scope por usuario, rango respetado).
  - `EntriesByBucketTest`: filtros, cap 100, `truncated/total_count`, year_month, scope, eager loading sin N+1.
  - `FinanceApiTest`: smoke del endpoint by-account y del entries-by-bucket; verificar que `listEntries` sigue verde tras refactor del helper.
- **Regresión**: suite backend completa (302+) verde. Especialmente `test_entries_endpoint_paginates_and_filters` que valida el contrato de `listEntries`.
- **Frontend**:
  - Smoke de `EntriesDrilldownModal` (render con datos, render vacío, render truncado).
  - Smoke de `ReportsByAccountView` (render tabla + click abre modal).
  - Sin tests específicos por cada reporte modificado: el cambio es agregar onClick + emit, manual smoke alcanza.
- **Manual**: recorrido del flujo en cada reporte (6 puntos), verificación de query params en `/entries`.

## Estrategia de rollback

- Feature aditiva: revertir el commit borra los archivos nuevos y vuelve los modificados a su estado anterior sin daño.
- Sin migraciones que revertir.
- El refactor de `applyEntryFilters` es interno al controller; si se revierte, `listEntries` recupera su forma anterior sin perder funcionalidad.

## Orden sugerido de implementacion

1. **Refactor `applyEntryFilters` en FinanceController** (sin cambios funcionales). Suite verde como gate.
2. **`ByAccountReport` Service + tests unit** (capa de dominio aislada).
3. **Endpoint `reportByAccount` + ruta + test HTTP** (capa HTTP).
4. **Endpoint `entriesByBucket` + ruta + test HTTP** (usa el helper del paso 1).
5. **`api/finance.js`**: nuevas funciones.
6. **`EntriesDrilldownModal.vue`** (sin integración con reportes todavía; smoke test).
7. **`ReportsByAccountView.vue`** + ruta + tab en subnav. Drill-down del propio reporte primero (válida el modal en uso).
8. **Integración del drill-down en los 5 reportes existentes**, uno por uno con validación visual.
9. **`/entries` lee query params en mount**.
10. **CLAUDE.md** + memoria del proyecto.
11. **`branch-quality-review`** antes del merge.

## Casos borde que condicionan la solucion

- **Cuenta archivada con `account_id` en filtros**: el endpoint entries-by-bucket no filtra por `Account` activa; usa el id directo en `journal_entries`. Permite auditar histórico. Documentado.
- **`year_month` y `from/to` mezclados**: si vienen ambos, prevalece `year_month` (es atajo). Tests para confirmar.
- **`kind` con valor `transfer` y `category_id` simultáneos**: transfer no se categoriza; la combinación dará 0 resultados (no error). Aceptable.
- **`/entries` ya con filtros locales**: los query params se aplican solo si no hay filtros previos en el componente (estado inicial), para no pisar cambios manuales si el usuario ya estaba en la vista. Decisión: usar siempre query params como source of truth en el mount; subsecuentes cambios del usuario priman.
- **Reporte by-account con todas las cuentas en cero**: tabla con cuentas listadas, ceros, sin links clickeables.
- **Movimientos `adjustment` o futuros kinds**: ignorados por el reporte by-account (kind no soportado en cálculo). Documentado.
- **Cap exacto = 100 entries**: el endpoint devuelve los 100 con `truncated: false` (porque total_count == 100). Solo si hay 101+ se marca truncated.
- **Eager loading de origin/destination cuando uno está archivado**: usar `withTrashed()` en la relación para mostrar nombre histórico, igual que en `listEntries`.

## Preguntas o supuestos que siguen afectando la implementacion

Sin preguntas pendientes. Supuestos heredados de la spec:

- Cap 100 por bucket (revisable si en uso real es molesto).
- `/entries` aplica query params en mount siempre (no condicionado al estado previo del componente).
- `bucket_label` lo arma el backend en `entriesByBucket` para uniformidad; el frontend solo lo muestra. Si el frontend prefiere armarlo por sí mismo, el endpoint sigue retornándolo pero el frontend puede ignorarlo.
- Para el reporte by-account, el "default range" es mes en curso, consistente con `/entries`.
