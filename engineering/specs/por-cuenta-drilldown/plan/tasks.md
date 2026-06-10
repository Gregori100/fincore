# Tasks — Reporte "por cuenta" + drill-down transversal

Orden general: refactor seguro del helper → reporte by-account end-to-end → endpoint drill-down → modal y vista by-account → integración en los 5 reportes existentes → query params en /entries → docs/revisión.

## Backend

- [ ] T001 Backend: extraer `private function applyEntryFilters(Builder $q, array $filters): void` en `FinanceController` que encapsule la lógica de filtros (account_id, category_id, kind, from, to). `listEntries` lo invoca. Sin cambio de comportamiento.
  RF: RF-003
  Depende de: ninguna
  Paralelizable: no
  Criterio de terminado: `test_entries_endpoint_paginates_and_filters` y demás del FinanceApiTest siguen verdes sin tocarlos.

- [ ] T002 Backend: Service `Domain/Finance/Reports/ByAccountReport.php` con `static execute(string $userId, string $from, string $to): array`. Devuelve `[{ account_id, name, type, income, expense, net }]` por cada cuenta no archivada del usuario, calculando income (suma como destination) y expense (suma como origin) de entries activos en el rango.
  RF: RF-001, RF-002
  Depende de: ninguna
  Paralelizable: si
  Criterio de terminado: cubre los ≥10 casos de `ByAccountReportTest`.

- [ ] T003 Backend: método `FinanceController::reportByAccount(Request $request)` que valida `from`/`to` (sometimes|date), aplica default mes en curso si faltan, invoca el Service, devuelve `{ from, to, accounts }`.
  RF: RF-001
  Depende de: T002
  Paralelizable: no
  Criterio de terminado: endpoint funcional, tests HTTP en verde.

- [ ] T004 Backend: ruta `GET /finance/reports/by-account` en `routes/api.php` dentro del grupo `['auth:sanctum','verified']`.
  RF: RF-001, RF-012
  Depende de: T003
  Paralelizable: no
  Criterio de terminado: `route:list --path=finance/reports/by-account` lista la ruta.

- [ ] T005 Backend: método `FinanceController::entriesByBucket(Request $request)`. Valida filtros (`kind`, `account_id`, `category_id`, `from`, `to`, `year_month` — todos opcionales con tipos correctos), exige que al menos un filtro esté presente (422 si no), traduce `year_month` a `from`/`to` (sobreescribe si vienen ambos), arma la query con `applyEntryFilters`, hace `count()` para `total_count`, luego `limit(100)->get()` con eager load (`origin`, `destination`, `category`). Construye `bucket_label` humano a partir de los filtros (ej. "Gastos de Comida en mayo 2026"). Devuelve `{ entries, truncated, total_count, bucket_label }`.
  RF: RF-003, RF-004
  Depende de: T001
  Paralelizable: no
  Criterio de terminado: cubre los ≥12 casos de `EntriesByBucketTest`.

- [ ] T006 Backend: ruta `GET /finance/reports/entries-by-bucket` en `routes/api.php`.
  RF: RF-003, RF-012
  Depende de: T005
  Paralelizable: no
  Criterio de terminado: ruta lista en `route:list`.

## Frontend

- [ ] T007 Frontend: en `api/finance.js`, agregar `reportByAccount({ from, to })` y `entriesByBucket(filters)` (GET con `params`).
  RF: RF-001, RF-003
  Depende de: T004, T006
  Paralelizable: si
  Criterio de terminado: ambas funciones exportadas y consumibles.

- [ ] T008 Frontend: componente `EntriesDrilldownModal.vue`. Props: `open`, `filters` (objeto). Al abrir, fetch al endpoint, almacena `entries`, `truncated`, `total_count`, `bucket_label`. Renderiza header (label + total), tabla compacta (fecha, monto con signo, descripción, cuentas origen→destino, badge de categoría — guion si null), aviso de truncado, footer con "Cerrar" y "Ir a /entries". Usa `BaseModal size="lg"` (no persistent). Emite `close` y `goToEntries(filters)`.
  RF: RF-008, RF-010, RF-011
  Depende de: T007
  Paralelizable: si
  Criterio de terminado: smoke test verde; comportamiento manual correcto en los 3 estados (con datos, vacío, truncado).

- [ ] T009 Frontend: vista `ReportsByAccountView.vue` lazy-loaded en `/reports/by-account`. Hero opcional con totales agregados. Filtros de rango (default mes en curso). Tabla `Cuenta | Ingresos | Gastos | Neto`. Cada celda numérica y nombre clickeable (no clickeable si valor = 0). Click abre el modal con los filtros correspondientes. Copy bajo el header explicando semántica de tarjetas.
  RF: RF-005, RF-007 (por cuenta)
  Depende de: T008, T007
  Paralelizable: no
  Criterio de terminado: vista carga, click abre modal con datos correctos.

- [ ] T010 Frontend: ruta `/reports/by-account` en `router/index.js`.
  RF: RF-005
  Depende de: T009
  Paralelizable: no
  Criterio de terminado: navegar a `/reports/by-account` carga la vista.

- [ ] T011 Frontend: agregar tab "Por cuenta" al array `tabs` de `ReportsSubnav.vue` apuntando a `reports-by-account`.
  RF: RF-006
  Depende de: T010
  Paralelizable: si
  Criterio de terminado: el subnav muestra los 6 tabs.

- [ ] T012 Frontend: integrar drill-down en `ReportsByCategoryView` + componentes hijos. Click en bucket (dona o lista) → emit/abre el modal con `{ kind, category_id, from, to }`.
  RF: RF-007 (por categoría)
  Depende de: T008
  Paralelizable: si
  Criterio de terminado: smoke manual: click en un slice abre modal con entries esperados.

- [ ] T013 Frontend: integrar drill-down en `ReportsCashflowView` + `MonthlyCashflowChart`. El chart emite `drilldown` con `{ year_month, kind }` al click en una barra; la vista abre el modal.
  RF: RF-007 (cashflow)
  Depende de: T008
  Paralelizable: si
  Criterio de terminado: smoke manual del flujo de drill-down desde una barra.

- [ ] T014 Frontend: integrar drill-down en `ReportsMonthComparisonView` + `MonthComparisonList`. Celda de monto clickeable → modal con `{ kind, category_id, year_month }`.
  RF: RF-007 (comparativo)
  Depende de: T008
  Paralelizable: si
  Criterio de terminado: smoke manual.

- [ ] T015 Frontend: integrar drill-down en `ReportsCreditCardsView` + `CreditCardSummary`. Monto de "Cargos del mes" clickeable → modal con `{ account_id, kind: 'credit_expense', from, to }`.
  RF: RF-007 (tarjetas)
  Depende de: T008
  Paralelizable: si
  Criterio de terminado: smoke manual.

- [ ] T016 Frontend: integrar drill-down en `ReportsBudgetsView` + `BudgetsList`. Categoría con presupuesto clickeable → modal con `{ category_id, kind: 'expense', from: primer día del mes, to: hoy }`.
  RF: RF-007 (presupuestos)
  Depende de: T008
  Paralelizable: si
  Criterio de terminado: smoke manual.

- [ ] T017 Frontend: `EntriesTable.vue` lee `route.query` en `onMounted`, mapea (account_id, category_id, kind, from, to) a `filters.value` si vienen. El modal navega a `/entries` con esos query params al click en "Ir a /entries".
  RF: RF-009
  Depende de: T008
  Paralelizable: no
  Criterio de terminado: navegar manualmente `/entries?account_id=…&kind=expense` precarga los filtros correctamente.

## Pruebas

- [ ] T018 Pruebas: `backend/tests/Feature/Finance/ByAccountReportTest.php` con los ≥10 casos del test-plan.
  RF: RF-001, RF-002
  Depende de: T002
  Paralelizable: si
  Criterio de terminado: todos verdes.

- [ ] T019 Pruebas: `backend/tests/Feature/Http/EntriesByBucketTest.php` con los ≥12 casos del test-plan, incluyendo el de N+1.
  RF: RF-003, RF-004
  Depende de: T006
  Paralelizable: si
  Criterio de terminado: todos verdes; el de N+1 confirma ≤4 queries.

- [ ] T020 Pruebas: agregar al `FinanceApiTest` los casos del endpoint by-account (shape, scope, default range). Verificar que el endpoint existente de `listEntries` sigue sin regresión.
  RF: RF-001
  Depende de: T004
  Paralelizable: si
  Criterio de terminado: pasa.

- [ ] T021 Pruebas: `frontend/tests/components/EntriesDrilldownModal.spec.js` con los 3 estados (con datos, vacío, truncado) y emit de "go to entries".
  RF: RF-008, RF-010
  Depende de: T008
  Paralelizable: si
  Criterio de terminado: pasa.

- [ ] T022 Pruebas: ejecutar suite backend completa, sin regresión (≥ 320 total).
  RF: todos
  Depende de: T018, T019, T020
  Paralelizable: no
  Criterio de terminado: `php artisan test` exit 0.

- [ ] T023 Pruebas: ejecutar suite frontend completa (≥ 50).
  RF: todos
  Depende de: T012, T013, T014, T015, T016, T017, T021
  Paralelizable: no
  Criterio de terminado: `npm run test` exit 0.

- [ ] T024 Pruebas: recorrido manual de 10 pasos del test-plan en localhost.
  RF: todos
  Depende de: T022, T023
  Paralelizable: no
  Criterio de terminado: los 10 pasos pasan sin errores.

## Validacion de calidad

- [ ] T025 Validación: `/branch-quality-review slug=por-cuenta-drilldown`. Focos: refactor de filters sin regresión, eager loading anti N+1, scope por user, mapeo de filtros por reporte.
  RF: todos
  Depende de: T024
  Paralelizable: no
  Criterio de terminado: reporte sin hallazgos bloqueantes en `engineering/quality-review/por-cuenta-drilldown/`.

## Documentacion

- [ ] T026 Documentación: actualizar `CLAUDE.md` con los dos endpoints nuevos (`GET /finance/reports/by-account` y `GET /finance/reports/entries-by-bucket`) en la tabla de rutas. Mención breve del comportamiento drill-down si aporta.
  RF: todos
  Depende de: T006
  Paralelizable: si
  Criterio de terminado: tabla coherente.

- [ ] T027 Documentación: actualizar memoria del proyecto. Marcar "reporte por cuenta" y "drill-down" como cerrados en el backlog.
  RF: todos
  Depende de: T024
  Paralelizable: si
  Criterio de terminado: backlog actualizado.
