# Progreso de implementación

## Completadas

- [x] T001 Backend: extracción `applyEntryFilters` privado. Gate `test_entries_endpoint_paginates_and_filters` verde.
- [x] T002 Backend: `Domain/Finance/Reports/ByAccountReport.php`.
- [x] T003 Backend: `FinanceController::reportByAccount`.
- [x] T004 Backend: ruta `GET /finance/reports/by-account`.
- [x] T005 Backend: `FinanceController::entriesByBucket` (con cap 100, year_month, bucket_label).
- [x] T006 Backend: ruta `GET /finance/reports/entries-by-bucket`.
- [x] T007 Frontend: `reportByAccount` y `entriesByBucket` en `api/finance.js`.
- [x] T008 Frontend: `EntriesDrilldownModal.vue`.
- [x] T009 Frontend: `ReportsByAccountView.vue`.
- [x] T010 Frontend: ruta `/reports/by-account`.
- [x] T011 Frontend: sexto tab en `ReportsSubnav`.
- [x] T012 Frontend: drill-down en `/reports/by-category` (CategoryBreakdownList + view).
- [x] T013 Frontend: drill-down en `/reports/cashflow` (MonthlyCashflowChart + view).
- [x] T014 Frontend: drill-down en `/reports/month-comparison` (MonthComparisonList + view).
- [x] T015 Frontend: drill-down en `/reports/credit-cards` (CreditCardSummary + view).
- [x] T016 Frontend: drill-down en `/reports/budgets` (BudgetsList + view).
- [x] T017 Frontend: query params en `EntriesTable.vue`.
- [x] T018 Pruebas: `ByAccountReportTest` 10/10.
- [x] T019 Pruebas: `EntriesByBucketTest` 12/12 (incluye anti-N+1).
- [x] T020 Pruebas: suite `FinanceApiTest` sin regresión tras refactor.
- [x] T021 Pruebas: `EntriesDrilldownModal.spec.js` 4/4.
- [x] T022 Pruebas: suite backend completa **322 verde**.
- [x] T023 Pruebas: suite frontend completa **53 verde**.
- [x] T026 Documentación: `CLAUDE.md` con dos rutas nuevas.

## Pendientes (post-implementación)

- [ ] T024 Recorrido manual de 10 pasos (test-plan). Pendiente del usuario.
- [ ] T025 `/branch-quality-review slug=por-cuenta-drilldown`. Recomendado pre-merge.
- [ ] T027 Memoria del proyecto: marcar "reporte por cuenta" y "drill-down" como cerrados en el backlog.

## Notas

- Sin desviaciones críticas del plan. Ajustes menores documentados en `resumen-extenso.md`.
- Stack Docker tuvo que reinicializarse al arrancar (`docker compose down && up -d`); no afectó la implementación.
- El test del modal requirió stub de `BaseModal` por la dependencia de Headless UI Dialog en `ResizeObserver` (no disponible en jsdom).
- `watch(open, ..., { immediate: true })` en el modal para disparar fetch cuando nace abierto (caso E2E y tests).
