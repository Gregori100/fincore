# Plan técnico — Proyección de gasto mensual por categoría

## Enfoque tecnico

Reutilizar el patrón establecido por los 6 reportes previos (Service en `Domain/Finance/Reports/` + endpoint en `FinanceController` + endpoint xlsx en `ReportExportController` + vista lazy-loaded + tab en `ReportsSubnav` + ruta en router). El sprint es **aditivo puro**: ningún archivo existente cambia su contrato, sólo se agregan entradas a 2 archivos centralizados (`ReportsSubnav.vue` array de tabs y `router/index.js` array de rutas).

### Backend en 3 capas

1. **Domain (Service)** — `App\Domain\Finance\Reports\SpendingForecastReport`:
   - Constructor `__construct(private string $userId)`.
   - Método único `generate(): array`. Sin parámetros porque el mes en curso es fijo (deriva de `now()`).
   - Internamente:
     - Calcula `today`, `days_in_month`, `days_elapsed`, `window_from`, `window_to` con Carbon.
     - Hace **1 sola query** que selecciona `category_id, name, color_slug, icon_slug` + 2 sumas condicionales: `current_spent` (entries del mes en curso) y `historical_total` (entries de la ventana). Usar `SUM(CASE WHEN occurred_at >= window_from AND occurred_at <= window_to_end_of_day THEN amount ELSE 0 END)` y análogo para mes en curso. `leftJoin('categories', ...)` para conservar nombres históricos de categorías archivadas — patrón idéntico al de `CategoryBreakdownReport.php:60-71`.
     - Filtros base: `journal_entries.user_id = $userId`, `kind IN ('expense', 'credit_expense')`, `deleted_at IS NULL` (vía scope global), `occurred_at` entre `window_from` y `end_of_today_in_curr_month` (rango unificado más amplio que cubre ambas ventanas).
     - `GROUP BY journal_entries.category_id, categories.name, categories.color_slug, categories.icon_slug`.
     - `HAVING SUM(...) > 0` sobre `historical_total` para aplicar la regla de cobertura **directamente en SQL** (categorías sin historial en la ventana se excluyen antes de llegar a PHP).
   - Calcula en PHP: `historical_average = historical_total / 3`, `projection = current_spent * days_in_month / days_elapsed`, `delta_pct = (projection - historical_average) / historical_average * 100` (`null` si `historical_average === 0.0`).
   - Ordena buckets por `delta_pct DESC` con `null` al final (alfabético entre los `null`).
   - Calcula `totals` con la misma fórmula aplicada a los agregados.
   - Devuelve el array con la estructura exacta de RF-003.

2. **HTTP (Controller)** — `FinanceController::reportForecast(Request $request)`:
   - No valida nada (sin params).
   - Instancia el Service con `$request->user()->id`, llama `generate()`, devuelve `response()->json($report)`.

3. **HTTP Export (Controller)** — `ReportExportController::forecast(Request $request)`:
   - Llama al mismo Service.
   - Arma rows: `[name, current_spent, historical_average, projection, delta_pct_fraction]` (donde `delta_pct_fraction = delta_pct / 100` para que el formato `0.0%` de Excel pinte correctamente, o `''` si null — patrón idéntico al de `monthComparison` en el sprint export-excel-reportes).
   - Footer: TOTAL con los agregados.
   - Filename: `fincore-proyeccion-gasto-YYYY-MM.xlsx`.

### Frontend en 2 capas

1. **Vista (`ReportsForecastView.vue`)**:
   - Estructura idéntica a `ReportsBudgetsView.vue` (es el más parecido: sin rango configurable, mes en curso, badge color por categoría, lista de buckets, drill-down).
   - Sin `DateRangePreset` (no aplica).
   - Hero opcional con los 4 totales agregados.
   - Tabla con 5 columnas: Categoría (badge + nombre) | Gastado este mes | Promedio histórico | Proyección | Δ%.
   - Cada fila clickeable → `EntriesDrilldownModal` con filtros: `category_id` (o `null` para "Sin categorizar"), `kind = 'expense'`, `from = primer día del mes en curso`, `to = hoy`. La lógica de drill-down con `kind=expense` ya incluye `credit_expense` por convención usada en el resto de los reportes — verificar en `entriesByBucket` si se mapea automáticamente.
   - Botón "Exportar a Excel" a la derecha de los headers, reusando `ExcelExportButton` con URL `/finance/reports/forecast/export.xlsx` y `params: {}`.
   - Empty state: si `categories.length === 0`, mostrar mensaje "Aún no tienes suficiente historial para proyectar; vuelve después de registrar movimientos por al menos un mes" con `BaseButton` opcional a `/entries`.

2. **Tab + ruta**:
   - `ReportsSubnav.vue`: agregar `{ name: 'reports-forecast', label: 'Proyección' }` al array.
   - `router/index.js`: agregar route `/reports/forecast` con `name: 'reports-forecast'`, `component: () => import('@/views/app/ReportsForecastView.vue')`, `meta: { requiresAuth: true }`.

## Requisitos funcionales cubiertos

- **RF-001**: ruta `GET /api/finance/reports/forecast` en `routes/api.php`, dentro del grupo `auth:sanctum + verified`.
- **RF-002**: el endpoint no valida ni acepta params; cualquier extra se ignora silenciosamente (consistente con `reportBudgets` y `reportCreditCards`).
- **RF-003**: la estructura JSON sale del Service tal cual. Tests HTTP verifican el shape contra un dataset conocido.
- **RF-004**: ordenamiento por `delta_pct DESC` con `null` al final se hace en el Service tras agrupar.
- **RF-005**: `totals` se calcula en el Service después de armar los buckets; `delta_pct` total reusa la misma fórmula sobre la suma de proyecciones y de promedios.
- **RF-006**: nuevo método `ReportExportController::forecast` reusa `ReportExporter` (helper del sprint anterior). Ruta `GET /api/finance/reports/forecast/export.xlsx`.
- **RF-007**: vista con hero + tabla + drill-down + botón export. Sin filtros configurables.
- **RF-008**: explícitamente no se usa `DateRangePreset`.
- **RF-009**: 7° tab en `ReportsSubnav`.
- **RF-010**: ruta nueva con `meta: { requiresAuth: true }`. El guard global aplica también `verified` por la convención existente.
- **RF-011**: el Service garantiza el orden `delta_pct DESC, null al final, alfabético entre nulls`.
- **RF-012**: si no hay buckets, el Service devuelve `categories: []` y `totals` en 0/null. La vista detecta `categories.length === 0` y muestra empty state.

## Archivos o modulos probablemente afectados

Backend (nuevos):
- `backend/app/Domain/Finance/Reports/SpendingForecastReport.php`
- `backend/tests/Feature/Finance/SpendingForecastReportTest.php` (unitario del Service)
- `backend/tests/Feature/Http/ForecastReportTest.php` (HTTP del endpoint JSON + xlsx)

Backend (modificados):
- `backend/app/Http/Controllers/FinanceController.php` — agregar método `reportForecast`.
- `backend/app/Http/Controllers/ReportExportController.php` — agregar método `forecast`.
- `backend/routes/api.php` — 2 rutas nuevas (JSON + xlsx).

Frontend (nuevos):
- `frontend/src/views/app/ReportsForecastView.vue`

Frontend (modificados):
- `frontend/src/components/finance/ReportsSubnav.vue` — agregar entrada al array.
- `frontend/src/router/index.js` — agregar route.

Frontend (tests, nuevos):
- `frontend/tests/components/ReportsForecastView.spec.js` (smoke con mock del store y de la API).

Documentación:
- `CLAUDE.md` — 2 filas nuevas en la tabla de rutas API.
- `docs/api/reports.md` — sección nueva "Proyección" con shape de respuesta.

Sin cambios:
- Migraciones, schema, seeders, `Domain/Finance/Actions/*`, `FinancialStateService`, modelos.
- Los 6 reportes existentes y sus exports.

## Entidades y estados afectados

No aplica como dominio nuevo. El reporte es lectura agregada sobre:
- `User` (autenticado).
- `Category` (incluye archivadas via leftJoin que no respeta SoftDelete scope para `categories`).
- `JournalEntry` filtrado por `kind IN ('expense', 'credit_expense')` y excluyendo cancelados.

Invariantes a respetar:
- Scope por `user_id`: en cada query.
- Soft delete de entries: respetar el scope global.
- Soft delete de categorías: NO respetar (mantener nombre histórico).
- Bucket "Sin categorizar": entries con `category_id = NULL` se agrupan con label `'Sin categorizar'` (constante `CategoryBreakdownReport::UNCATEGORIZED_LABEL`).

## Compatibilidad con datos y procesos existentes

- **Backend**: sin migraciones. Los endpoints existentes no cambian. La suite backend de 360 tests pasa intacta.
- **Frontend**: las 6 vistas de reportes no cambian; el componente `ReportsSubnav` gana 1 tab adicional sin alterar las anteriores. La suite de 110 tests pasa intacta.
- **Drill-down**: `EntriesDrilldownModal` ya acepta `{kind, category_id, from, to}` (sprint por-cuenta-drilldown). No requiere cambios.
- **Export**: `ReportExporter` ya soporta el patrón usado (header + table + footer + download). `ExcelExportButton` ya genérico.
- **Performance**: la query del Service hace **1 sola pasada por `journal_entries`** filtrada por `user_id` + rango ancho (3 meses + lo que va del actual) con un solo GROUP BY. Para volúmenes típicos de FinCore (cientos de entries por mes), el costo es trivial. El índice implícito por `(user_id, occurred_at)` y la PK por `(category_id)` son suficientes. No requiere índice nuevo.

## Cambios de datos

No aplica.

## Cambios de API

Aditivos. 2 endpoints nuevos:

- `GET /api/finance/reports/forecast` — bajo `auth:sanctum + verified`. Sin query params. Responde JSON con shape de RF-003.
- `GET /api/finance/reports/forecast/export.xlsx` — bajo `auth:sanctum + verified`. Sin query params. Responde binario xlsx con headers `Content-Type` y `Content-Disposition` correctos.

## Cambios de integraciones

No aplica. Sin nuevas dependencias composer ni npm.

## Cambios de UI

- 1 vista nueva `/reports/forecast`.
- 7° tab "Proyección" en `ReportsSubnav` (sin alterar los 6 previos).
- Estilo coherente con `ReportsBudgetsView` (el más parecido por estructura).
- Badges de color para Δ%: verde (`text-positive` o equivalente para ≤0), amarillo (`text-warning` para 0-20), rojo (`text-negative` para >20), gris (`text-muted` para null). Reusar los CSS variables existentes.

## Cambios de permisos

No aplica. Mismo middleware `auth:sanctum + verified` que el resto.

## Riesgos tecnicos

- **Performance con muchas categorías y muchos entries**: la query con `CASE WHEN` requiere escanear los entries del rango. Para volúmenes de FinCore actuales (decenas de categorías × cientos de entries) es negligible. Si crece a miles, el plan de query lo detecta vía `EXPLAIN ANALYZE` (no se hará en este sprint).
- **Cálculo de DST en `days_elapsed`**: usar `now()->day` (Carbon devuelve el día del mes local, libre de DST). `now()->daysInMonth` también seguro. No usar aritmética de timestamps.
- **`historical_total` con suma 0 que pasa el HAVING**: si una categoría tiene entries en la ventana pero todos por monto 0 (caso patológico, no debería darse en prod pero contemplable), pasaría el `HAVING SUM > 0`? **No**, porque la condición es estricta. Aceptado: filtra el ruido. Documentar en spec si surge.
- **División por cero al calcular `delta_pct`**: si `historical_average === 0.0` (no debería pasar dado HAVING), devolver `null`. Cubrir con test defensivo.
- **`current_spent = 0` con día > 1**: proyección = 0, `delta_pct = -100%` para cualquier categoría con histórico. Verde. Comportamiento correcto.
- **Categoría "Sin categorizar" con histórico**: aparece como un bucket adicional con `category_id = null`, `name = 'Sin categorizar'`. Cubrir en test.
- **Drill-down con `category_id = null`**: `EntriesDrilldownModal` ya soporta esto (sprint por-cuenta-drilldown lo verificó). Pero confirmar al implementar que la lista de drill-down efectivamente filtra entries sin categoría.
- **Cache de Carbon `now()`**: en tests, usar `Carbon::setTestNow($fixedDate)` para reproducibilidad. El Service debe respetar `Carbon::now()` (no `new \DateTime()`).
- **Tab en `ReportsSubnav` no agrega altura visible**: el `flex-wrap` actual maneja overflow. Verificar en mobile (~480px de ancho).

## Estrategia de pruebas

- **Service `SpendingForecastReport`** (unitario, con `RefreshDatabase`):
  - Smoke con dataset conocido → estructura JSON completa.
  - Fórmula de proyección: 1 entry de $2,500 al día 10 de jun (mes de 30) → proyección $7,500.
  - Ventana de 3 meses correcta: entries en abril/mayo/marzo cuentan; entries en febrero NO.
  - Cobertura: categoría sin historial en ventana → NO aparece.
  - Categoría archivada con histórico → SÍ aparece con nombre original.
  - Bucket "Sin categorizar" → aparece si tiene historial.
  - Entries cancelados → no se cuentan.
  - Scope por user → datos de otros users no se filtran.
  - Day 1 + current_spent = 0 → proyección = 0, sin division by zero.
  - Promedio = 0 (patológico) → delta_pct = null.
  - Orden: delta_pct DESC con null al final.
  - Totals agregan correctamente.
- **HTTP `forecast`**:
  - Endpoint sin auth → 401.
  - Endpoint sin email verificado → 403.
  - Endpoint OK → JSON con shape correcto.
  - Endpoint ignora query params extras.
  - Endpoint con user sin movimientos → `categories: []` y totals en 0/null.
- **HTTP `forecast/export.xlsx`**:
  - Endpoint OK → 200 + headers correctos + binario PK.
  - Filename con patrón `fincore-proyeccion-gasto-YYYY-MM.xlsx`.
  - Parseo del xlsx: encabezado en filas 1-2, tabla en fila 4 con headers, TOTAL al final.
- **Frontend smoke (vitest)**:
  - Render con dataset mockeado → tabla con N filas, totales en hero.
  - Empty state cuando `categories: []`.
  - Click en fila dispara emit / abre modal (depende de cómo se conecte).
  - El badge de Δ% tiene la clase correcta según umbrales (≤0 verde, ≤20 amarillo, >20 rojo, null neutral).
- **Smoke manual con Playwright**: opcional al cierre, validar la vista visualmente.

## Estrategia de rollback

Trivial. Revertir los commits del sprint deja todo igual: ninguna migración, ningún cambio de schema, ningún endpoint modificado. La suite vuelve a 360/110.

## Orden sugerido de implementacion

1. **Service** `SpendingForecastReport` con tests unit primero (TDD light). Validar la fórmula y cobertura.
2. **Controller** `reportForecast` en `FinanceController` + ruta JSON. Tests HTTP.
3. **Controller** `forecast` en `ReportExportController` + ruta xlsx. Tests HTTP.
4. **Vista** `ReportsForecastView.vue` clonando estructura de `ReportsBudgetsView`. Conectar a la API.
5. **Tab + ruta** en `ReportsSubnav` y `router/index.js`.
6. **Drill-down** + export integrados.
7. **Empty state** y badges de color.
8. **Tests frontend** smoke.
9. **Docs** (`CLAUDE.md` + `docs/api/reports.md`).
10. **QR** (`branch-quality-review`).

## Casos borde que condicionan la solucion

- Día 1 con `current_spent = 0`: proyección = 0.
- Último día del mes: proyección == current_spent.
- Febrero bisiesto: `daysInMonth` devuelve 29 (Carbon lo maneja).
- Cruce de año (enero): la ventana son `oct + nov + dic` del año anterior. Test cubre.
- Categoría con actividad sólo en 1 de 3 meses: cobertura OK, promedio = gasto / 3.
- Categoría archivada: aparece con nombre histórico vía leftJoin.
- Bucket "Sin categorizar" con histórico: aparece como bucket extra.
- Promedio = 0 (patológico): delta_pct = null, no rompe.
- Usuario sin movimientos: empty state.

## Preguntas o supuestos que siguen afectando la implementacion

- **`HAVING SUM > 0` para cobertura**: estamos filtrando en SQL para que el resultado de `categories` no incluya categorías sin actividad en la ventana. Decisión de plan: hacerlo así por simplicidad y performance. Si el patrón de Eloquent es incómodo, fallback a filtrar en PHP tras agrupar.
- **Comparación con `BudgetsReport`**: en futuro se podría mostrar "Excedería presupuesto" al lado de la proyección si la categoría tiene `monthly_limit`. Por spec, NO en v1. Documentar como posible evolución.
- **Locale del Excel**: el patrón existente usa formato `"$"#,##0.00` (MXN) y `0.0%`. Reusar las constantes públicas `ReportExporter::FORMAT_MONEY` y `ReportExporter::FORMAT_PCT`.
- **Mes en curso = mes del servidor**: `Carbon::now()` respeta `APP_TIMEZONE`. Si el usuario está en otra zona y abre el reporte exactamente en la medianoche local, podría ver "mes pasado" todavía. Aceptado.
- **`days_elapsed = 0` improbable**: si `now()->day` devolviera 0 por algún bug de Carbon, dividir por 0. Defensive: clamp con `max(1, $daysElapsed)`.
