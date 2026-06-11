# Test plan — Proyección de gasto mensual

## Casos borde detectados

- **Día 1 del mes con current_spent = 0**: proyección debe ser 0, no NaN o exception por división. `delta_pct` debe ser -100% (verde).
- **Día 1 del mes con current_spent > 0**: proyección extrema (current × days_in_month). Esperado, sin suavizado.
- **Último día del mes**: `days_elapsed == days_in_month` → `projection == current_spent` exactamente.
- **Febrero bisiesto vs no bisiesto**: `Carbon::now()->daysInMonth` debe devolver 29 en años bisiestos, 28 en otros.
- **Cruce de año en la ventana**: si el mes en curso es enero, la ventana es oct + nov + dic del año anterior. Validar con `Carbon::setTestNow(Carbon::create($y, 1, 15))`.
- **Categoría sin historial en la ventana**: queda fuera del reporte (HAVING). Si el usuario sólo tiene actividad este mes, `categories: []`.
- **Categoría con historial sólo en 1 de los 3 meses**: sí aparece. Promedio = `gasto / 3` (siempre dividido entre 3, no entre meses con actividad).
- **Categoría con sum > 0 en la ventana pero sum = 0 este mes**: aparece. `projection = 0`, `delta_pct = -100%`.
- **Categoría archivada con historial**: aparece con nombre/color/icono históricos (leftJoin no respeta soft delete de categories).
- **Bucket "Sin categorizar" (`category_id = NULL`) con historial**: aparece como un bucket extra con label `'Sin categorizar'`.
- **Entries cancelados (`deleted_at != null`)**: excluidos por scope global de `SoftDeletes`.
- **Entries de `transfer`, `debt_payment`, `income`**: NO se cuentan (sólo `expense` y `credit_expense`).
- **Usuario sin movimientos en absoluto**: `categories: []`, `totals` con 0/null.
- **Usuario A consultando con datos del usuario B**: scope por user_id garantiza que A no ve a B.
- **Promedio histórico = 0 (caso patológico)**: `delta_pct = null`. No crash.
- **`HAVING SUM > 0` filtra correctamente**: categorías con sum = 0 en la ventana no aparecen.
- **Orden de buckets**: `delta_pct DESC` con `null` al final. Si dos buckets tienen mismo delta, orden estable (alfabético sub-orden).
- **`totals.delta_pct` cuando `totals.historical_average == 0`**: `null`, no crash.
- **`days_elapsed = 0` defensivo**: clamp a 1 para evitar división por cero (bug de Carbon improbable pero defensivo).
- **Mes en curso = mes pasado para zona horaria del cliente distinta del servidor**: comportamiento aceptado, no se cubre con test.
- **Concurrencia**: el reporte es lectura agregada, sin mutaciones. No aplica.
- **Tab nuevo en mobile (~480px)**: `flex-wrap` en `ReportsSubnav` debe acomodarlo sin overflow.
- **Drill-down con `category_id = null`**: el modal debe filtrar entries `category_id IS NULL` correctamente. Validar.
- **Export Excel con `categories: []`**: el archivo se genera con header + tabla vacía + footer TOTAL en 0. No 404 ni 422.

## Pruebas unitarias necesarias

En `backend/tests/Feature/Finance/SpendingForecastReportTest.php`:

- `test_returns_correct_shape_with_known_dataset`: 1 categoría "Comida" con 1 entry de $2,500 hoy (día 10 de mes 30) y entries de $5,000, $6,000, $7,000 en mar, abr, may → categoría con `current_spent=2500`, `historical_average=6000`, `projection=7500`, `delta_pct=25.0`.
- `test_projection_at_day_1_with_zero_spent_returns_zero`: día 1 sin entries este mes pero categoría con histórico → `projection = 0`, `delta_pct = -100.0`.
- `test_projection_at_last_day_equals_current_spent`: día 30 (mes 30) con $9,000 gastado → projection = 9000.
- `test_window_covers_three_months_calendar`: entries en feb NO cuentan, entries en mar/abr/may SÍ.
- `test_category_without_history_in_window_is_excluded`: categoría creada este mes sin entries previos NO aparece.
- `test_archived_category_with_history_appears_with_historic_name`: archivar categoría tras entries en la ventana → aparece con nombre original.
- `test_uncategorized_bucket_appears_when_has_history`: entries con `category_id = null` en la ventana → bucket "Sin categorizar".
- `test_cancelled_entries_excluded`: soft delete un entry → no se cuenta.
- `test_transfer_debt_payment_income_not_counted`: registrar income, transfer, debt_payment → no afectan proyección.
- `test_scope_isolation`: user A no ve datos de user B.
- `test_zero_historical_average_returns_null_delta`: categoría con entries por monto 0 en ventana (improbable real) → delta_pct null.
- `test_buckets_ordered_by_delta_desc_with_null_at_end`: validar orden.
- `test_totals_aggregate_correctly`: verificar `totals.current_spent`, `totals.historical_average`, `totals.projection`, `totals.delta_pct`.
- `test_user_without_movements_returns_empty`: 0 categorías + totals en 0/null.
- `test_february_leap_year_uses_29_days`: `Carbon::setTestNow(Carbon::create(2024, 2, 15))` → `days_in_month = 29`.
- `test_january_window_covers_previous_year_q4`: `setTestNow(create(2026, 1, 15))` → ventana es 2025-10-01 a 2025-12-31.
- `test_only_expense_and_credit_expense_kinds_counted`: explícitamente verificar que sólo esos 2 kinds suman.

## Pruebas de integracion o API necesarias

En `backend/tests/Feature/Http/ForecastReportTest.php`:

- `test_endpoint_requires_auth`: sin token → 401.
- `test_endpoint_requires_verified_email`: con token sin verify → 403.
- `test_endpoint_returns_200_with_json_shape`: GET con verify → 200 + estructura RF-003.
- `test_endpoint_ignores_extra_query_params`: `?foo=bar` → mismo resultado.
- `test_endpoint_with_no_categories_returns_empty_lists`: user sin entries → `categories: []`, `totals.delta_pct: null`.
- `test_export_xlsx_returns_binary_with_correct_headers`: GET /export.xlsx → Content-Type + Content-Disposition + binario PK.
- `test_export_xlsx_filename_pattern`: `fincore-proyeccion-gasto-YYYY-MM.xlsx`.
- `test_export_xlsx_content_matches_json`: cargar el xlsx con `IOFactory::load`, validar valores celda contra JSON del mismo dataset.
- `test_export_xlsx_with_empty_categories_still_renders`: user sin data → xlsx con header + tabla vacía + TOTAL en 0.
- `test_scope_isolation_user_a_does_not_see_user_b_data`.

## Pruebas de UI o flujo necesarias si aplica

En `frontend/tests/components/ReportsForecastView.spec.js` (smoke con mock):

- `renderiza la tabla con N filas dado un dataset mockeado`.
- `el badge de delta_pct usa la clase correcta segun el umbral (verde ≤0, amarillo 0-20, rojo >20, gris null)`.
- `empty state aparece cuando categories.length === 0`.
- `click en fila dispara apertura del drill-down` (mockear el modal).
- `boton "Exportar a Excel" recibe la URL correcta`.

## Pruebas de permisos y seguridad si aplica

Cubierto en HTTP:
- 401 sin token.
- 403 sin email verificado.
- Scope por user_id en el Service y en el endpoint (test específico).

## Pruebas de datos, migracion o compatibilidad si aplica

No aplica. Sin migraciones, sin cambios de schema. Los datos existentes (entries, categorías) se leen tal cual.

## Pruebas de regresion sobre flujos existentes

- Suite backend completa: 360/360 actuales + ~17 nuevos = ~377/377 verde.
- Suite frontend completa: 110/110 actuales + ~5-8 nuevos = ~115-118 verde.
- Los 6 reportes existentes (`by-category`, `cashflow-monthly`, `month-comparison`, `credit-cards`, `budgets`, `by-account`) responden idénticamente — sus tests HTTP siguen pasando.
- Los 6 endpoints `/export.xlsx` existentes responden idénticamente.
- `EntriesDrilldownModal` se reusa sin cambios — su test sigue pasando.
- `ExcelExportButton` se reusa sin cambios — su test sigue pasando.
- `ReportsSubnav` con 7 tabs renderiza correctamente.

## Pruebas manuales o smoke tests necesarios

Levantar stack:

```bash
./scripts/fincore start
```

En navegador:

1. Login con user de prueba con data histórica (>3 meses de actividad).
2. Navegar a `/reports/forecast`.
3. Verificar que el subnav muestra los 7 tabs incluyendo "Proyección".
4. Verificar la tabla: nombres de categorías, valores numéricos coherentes, badges de color en Δ%.
5. Click en una fila → modal de drill-down con los entries del mes en curso.
6. Click en "Ir a Movimientos" → navega a `/entries` con filtros correctos.
7. Click en "Exportar a Excel" → descarga `fincore-proyeccion-gasto-YYYY-MM.xlsx`.
8. Abrir el xlsx en LibreOffice/Excel: header + tabla + TOTAL.
9. Probar en user sin historia (registrar uno nuevo): vista muestra empty state con mensaje y CTA.
10. Probar en `~/480px` (mobile): subnav con flex-wrap acomoda 7 tabs.

## Datos de prueba recomendados

- 1 user con email verificado.
- 5-7 categorías de gasto con `applies_to ∈ {expense, both}`.
- 1 categoría archivada con histórico en la ventana.
- Entries distribuidos durante los últimos 4 meses (mar, abr, may, jun si hoy es jun) con diferentes montos:
  - "Comida": $5000 en mar, $6000 en abr, $7000 en may, $2500 en jun (día 10).
  - "Transporte": $1000 en cada mes, $800 en jun.
  - "Streaming": $450 fijo en cada mes incluyendo jun.
  - "Ropa": $300 en abr, sin entries en jun.
  - 1 entry sin categoría en may.
  - 1 entry cancelado (soft delete) en abr.
- Para test de empty state: user con 0 entries.

## Comandos o validaciones locales sugeridas

```bash
# Backend
docker compose exec -T -w /var/www/html api php artisan test --filter=Forecast
docker compose exec -T -w /var/www/html api php artisan test
docker compose exec -T -w /var/www/html api ./vendor/bin/pint --test

# Frontend
npx vitest run tests/components/ReportsForecastView.spec.js
npx vitest run

# Smoke manual (opcional, navegador)
./scripts/fincore start
# navegar a http://localhost:5173/reports/forecast
```

## Criterios minimos para aprobar la implementacion

- Backend: suite completa verde (360 actuales + ~17 nuevos esperados).
- Frontend: suite completa verde (110 actuales + ~5-8 nuevos esperados).
- Pint: sin diffs en archivos nuevos.
- `composer validate` sin warnings.
- 2 endpoints nuevos responden 200 con shape correcta.
- Vista `/reports/forecast` carga y muestra tabla + drill-down + export funcionando.
- Empty state coherente.
- Tab "Proyección" aparece en el subnav.
- Sin regresiones en los 6 reportes existentes ni en sus exports.
- `CLAUDE.md` y `docs/api/reports.md` actualizados.

## Validacion final recomendada

Ejecutar `branch-quality-review` con `slug=proyeccion-gasto-mensual` antes de mergear. Reporte en `engineering/quality-review/proyeccion-gasto-mensual/`. Foco recomendado:

1. **Aislamiento por user_id**: query del Service y validación del endpoint.
2. **Edge case día 1 con current_spent > 0**: proyección extrema pero no error.
3. **Cobertura HAVING en SQL**: categorías sin historial no se cuelan.
4. **Manejo de `delta_pct = null`**: backend devuelve null sin crash; frontend lo renderiza neutral.
5. **Drill-down con `category_id = null`**: confirmar que el bucket "Sin categorizar" abre el modal con filtros correctos.
6. **Performance**: 1 query agregada por usuario. Confirmar que con índice por `(user_id, occurred_at)` la latencia es <100ms en datasets típicos.
7. **Export xlsx con dataset vacío**: archivo se genera sin error.
