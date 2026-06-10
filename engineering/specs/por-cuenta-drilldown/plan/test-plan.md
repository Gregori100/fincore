# Test plan — Reporte "por cuenta" + drill-down transversal

## Casos borde detectados

- Reporte by-account sin movimientos: tabla con cuentas listadas, todos los valores en 0.
- Reporte by-account con todas las cuentas archivadas: tabla vacía con copy "Sin cuentas activas".
- Movimiento `transfer` Bolsa→Banamex: aporta `expense` en Bolsa y `income` en Banamex. El neto agregado a nivel usuario suma cero.
- Movimiento `debt_payment` Bolsa→Visa: aporta `expense` en Bolsa y `income` en Visa (pagaste deuda → la deuda baja).
- Movimiento `credit_expense` en Visa: aporta `expense` en Visa (deuda sube). Sin contraparte.
- Cuenta crédito con cero movimientos en el rango: fila con ceros, sin links clickeables.
- Cuenta archivada después de generar el reporte: no aparece en la tabla; si llega un drill-down con su id, el endpoint sirve sus entries históricos.
- Drill-down con `year_month` y `from`/`to` mezclados: `year_month` prevalece.
- Drill-down con `kind=transfer` + `category_id`: 0 resultados, sin error.
- Drill-down con 100 entries exactos: `truncated: false`.
- Drill-down con 101 entries: `truncated: true`, `total_count: 101`, devolución 100.
- Drill-down con 0 entries: tabla vacía en modal, mensaje "Sin movimientos en este bucket", footer presente.
- Drill-down con `account_id` y `category_id` simultáneos: aplica ambos filtros (AND).
- Drill-down sin filtros (todos opcionales): rechazar con 422 para evitar dump de toda la cuenta. Defensivo.
- Eager loading: el endpoint debe ejecutar exactamente 1 query principal + relaciones (origin, destination, category) en una sola pasada. Validado con `DB::enableQueryLog()` + recuento.
- `/entries` con query params `?from=...&to=...&account_id=...` precarga filtros; sin query params, comportamiento idéntico al actual.
- `/entries` con query params mientras el usuario ya tiene filtros distintos: query params priman en mount (decisión).
- Reporte by-account con rango futuro: tabla con todos ceros.
- Reporte by-account con rango invertido (`from > to`): 422.
- Scope: usuario A no debe ver datos de usuario B en ninguno de los dos endpoints.
- `year_month` malformado ("2026-13", "abc"): 422 con mensaje claro.
- Movimiento con `category_id` de categoría archivada: en el modal, badge muestra guion (categoría null por default de Eloquent).
- Movimiento con cuenta origen archivada: nombre histórico aparece (eager load con `withTrashed`).
- Click en bucket de monto 0 en cualquier reporte: no abre el modal (handler bloquea o el cursor cambia indicando no-click).

## Pruebas unitarias necesarias

`ByAccountReportTest` con `RefreshDatabase`:

- `test_no_movements_returns_zero_for_each_account`: usuario con 3 cuentas, sin entries → cada cuenta `income: 0, expense: 0, net: 0`.
- `test_income_only_aggregates_in_destination`: registra income a Bolsa → Bolsa.income = monto, Bolsa.expense = 0, neto positivo.
- `test_expense_only_aggregates_in_origin`: registra expense desde Bolsa → Bolsa.expense = monto, income = 0, neto negativo.
- `test_transfer_aggregates_on_both_sides`: registra transfer Bolsa→Banamex → Bolsa.expense ↑, Banamex.income ↑; sum total de netos del user = 0.
- `test_debt_payment_aggregates_correctly`: registra pago Bolsa→Visa → Bolsa.expense ↑, Visa.income ↑ (la deuda bajó).
- `test_credit_expense_aggregates_in_credit_account_expense`: registra cargo en Visa → Visa.expense ↑, sin contraparte.
- `test_excludes_archived_accounts`: una cuenta archivada con movimientos no aparece en la respuesta.
- `test_excludes_soft_deleted_entries`: un entry cancelado no se suma.
- `test_respects_user_scope`: usuario A no ve agregaciones del usuario B.
- `test_respects_date_range`: entries fuera del rango no se cuentan.

## Pruebas de integracion o API necesarias

`EntriesByBucketTest` (HTTP, `RefreshDatabase`, Sanctum):

- `test_returns_entries_for_account_and_kind`: filtros válidos devuelven los entries esperados.
- `test_year_month_translates_to_from_to`: filtra por year_month, valida que solo entren los del mes.
- `test_year_month_overrides_from_to_if_both`: mezcla → year_month prevalece.
- `test_caps_at_100_with_truncated_flag`: seedea 105 entries, devuelve 100 + truncated true + total_count 105.
- `test_exactly_100_is_not_truncated`: 100 exactos → truncated false.
- `test_zero_entries_returns_empty_array`: filtros válidos sin matches → entries: [], truncated: false, total_count: 0.
- `test_rejects_when_all_filters_empty`: sin ningún filtro → 422.
- `test_rejects_malformed_year_month`: "2026-13" → 422.
- `test_scope_isolation`: usuario A solo ve sus entries.
- `test_eager_loads_relations_no_n_plus_1`: usar `DB::enableQueryLog()`, hacer la request, contar queries; debe ser ≤ 4 (entries + 3 eager loads). Sin N+1 por entry.
- `test_includes_archived_account_entries_when_filtered_by_archived_account_id`: drill-down sobre una cuenta archivada devuelve sus históricos.
- `test_bucket_label_includes_account_or_category_name`: el campo `bucket_label` es descriptivo y humano.

`FinanceApiTest` agregar:
- `test_by_account_report_returns_shape`: GET endpoint, valida shape y al menos una cuenta con valores correctos.
- `test_by_account_respects_user_and_excludes_archived`.
- `test_by_account_default_range_is_current_month`: sin from/to, usa primer día del mes a hoy.

## Pruebas de UI o flujo necesarias

vitest:

- `EntriesDrilldownModal.spec.js`:
  - Renderiza tabla con N filas según prop `entries`.
  - Render vacío cuando `entries: []` → muestra mensaje.
  - Render con `truncated: true` → aviso visible + botón "Ir a /entries" destacado.
  - Click en "Ir a /entries" emite evento con filtros.
- Smoke de `ReportsByAccountView.spec.js` opcional (renderiza, click abre modal).
- Sin tests específicos por reporte modificado (cambio chico: agregar onClick + emit).

## Pruebas de permisos y seguridad

- Ambos endpoints requieren `auth:sanctum + verified` (probados implícitamente vía el helper `Sanctum::actingAs($user)`).
- Scope estricto por `user_id` en todas las queries (tests dedicados).
- Sin riesgo SQL injection (Eloquent + parámetros bind).
- Sin exposición de soft-deleted (entries cancelados) por default.

## Pruebas de datos, migracion o compatibilidad

- Sin migraciones.
- Confirmar que `listEntries` mantiene su contrato exacto tras el refactor del helper (el test existente `test_entries_endpoint_paginates_and_filters` debe pasar sin cambios).

## Pruebas de regresion sobre flujos existentes

- Suite backend completa (línea base ~302) verde tras la implementación.
- Suite frontend (49) verde, +1 o +2 nuevos del modal.
- `/entries` sin query params se comporta idéntico (verificado manualmente y por el E2E si aplica).
- Los 5 reportes existentes siguen mostrando sus datos correctos; solo agregan click handlers.

## Pruebas manuales o smoke tests necesarios

Recorrido manual en `localhost:5173`:

1. `/reports/by-account` carga con tabla y default mes en curso. Cambiar rango y ver actualización.
2. Click en celda Ingresos de la Bolsa → modal con los entries que aportan; total coincide con la celda.
3. Click en una celda con $0 → no abre modal (cursor default).
4. Desde el modal, "Ir a /entries" → `/entries` abre con filtros precargados; los entries listados coinciden con los del modal.
5. Drill-down desde `/reports/by-category` (categoría "Comida") → modal con los gastos de Comida en el periodo.
6. Drill-down desde `/reports/cashflow` (barra de Mayo en gastos) → modal con los gastos de mayo.
7. Drill-down desde `/reports/month-comparison` (celda de gastos en una categoría) → modal con los entries de esa celda.
8. Drill-down desde `/reports/credit-cards` (cargos del mes en Visa) → modal con los `credit_expense` de Visa.
9. Drill-down desde `/reports/budgets` (categoría con presupuesto) → modal con los gastos del mes en la categoría.
10. Bucket truncado: simular con seed de 110 entries en una categoría → modal muestra "Mostrando 100 de 110…".

## Datos de prueba recomendados

- Usuario con Bolsa + Banamex (débito) + Visa (crédito).
- Mix de movimientos: ~30 entries variados (income, expense, transfer, debt_payment, credit_expense) distribuidos en 2 meses.
- 1 cuenta archivada con histórico.
- 1 categoría archivada referenciada por al menos un entry.
- Para test de truncado: seed de 110 entries de una sola categoría en un solo mes.

## Comandos o validaciones locales sugeridas

```bash
docker compose exec -T api php artisan test --filter "ByAccountReport|EntriesByBucket"
docker compose exec -T api php artisan test
cd frontend && npm run test
docker compose exec -T api php artisan route:list --path=finance/reports
```

Manual: `http://localhost:5173/reports/by-account` y recorrido de los 5 reportes existentes.

## Criterios minimos para aprobar la implementacion

1. `ByAccountReportTest` con ≥ 10 casos, todos verdes.
2. `EntriesByBucketTest` con ≥ 12 casos, incluyendo el de N+1 verde.
3. `FinanceApiTest` con casos nuevos del by-account verdes; los existentes (incluyendo el de listEntries) sin regresión.
4. Suite backend ≥ 320 (línea base ~302 + ~20 nuevos), toda verde.
5. Suite frontend ≥ 50, toda verde.
6. Recorrido manual de 10 pasos sin errores.
7. CLAUDE.md actualizado con los dos endpoints nuevos.
8. Performance: response time del endpoint by-account < 300 ms para 500 movimientos.

## Validacion final recomendada

Invocar `/branch-quality-review slug=por-cuenta-drilldown` antes del merge. Reporte en `engineering/quality-review/por-cuenta-drilldown/`. Focos del review:

- Refactor de `applyEntryFilters` no introduce cambio de comportamiento en `listEntries`.
- Eager loading correcto en `entriesByBucket` (anti N+1).
- Scope por `user_id` en todas las queries nuevas.
- Mapeo de filtros por reporte (RF-007) coherente con la spec.
- Modal informativo, no destructivo; no requiere persistent.

Si no estuviera disponible, checklist mínima: `git diff` revisado por archivos, sin `dd()`/`dump()`/`console.log`, queries con `EXPLAIN` para el rango típico, scope confirmado.
