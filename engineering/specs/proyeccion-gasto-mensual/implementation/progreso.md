# Progreso de implementación

Todas las tareas T001..T022 completadas. Sin pendientes del sprint.

## Tareas completadas

### Backend (T001-T008)

- [x] T001 — Service `SpendingForecastReport` con 1 query agregada (SUMs condicionales + leftJoin + HAVING).
- [x] T002 — 16 tests unit del Service (shape, fórmula, ventana, cobertura, archivadas, sin categorizar, cancelados, kinds, scope, calendario, orden, totals).
- [x] T003 — `FinanceController::reportForecast` sin params.
- [x] T004 — ruta `GET /api/finance/reports/forecast`.
- [x] T005 — `ReportExportController::forecast` reusando `ReportExporter`.
- [x] T006 — ruta `GET /api/finance/reports/forecast/export.xlsx`.
- [x] T007 — 5 tests HTTP del endpoint JSON.
- [x] T008 — 5 tests HTTP del endpoint xlsx.

### Frontend (T009-T016)

- [x] T009 — `ReportsForecastView.vue` clonando estructura de `ReportsBudgetsView`.
- [x] T010 — Integración con `EntriesDrilldownModal` (click en fila).
- [x] T011 — Integración con `ExcelExportButton`.
- [x] T012 — Badges de color (verde ≤0, amarillo 0-20, rojo >20, neutral null).
- [x] T013 — 7° tab "Proyección" en `ReportsSubnav.vue`.
- [x] T014 — Ruta `/reports/forecast` en `router/index.js`.
- [x] T015 — `reportForecast()` agregado a `frontend/src/api/finance.js`.
- [x] T016 — 6 tests smoke del componente.

### Documentación (T017-T018)

- [x] T017 — 2 filas nuevas en tabla de rutas de `CLAUDE.md`.
- [x] T018 — Sección "Proyección" en `docs/api/reports.md` + actualización de "Export a Excel".

### Validación (T019-T022)

- [x] T019 — Suite backend completa: 386/386 verde. Pint sobre archivos nuevos: limpio.
- [x] T020 — Suite frontend completa: 116/116 verde.
- [x] T021 — Smoke manual con Playwright: empty state, fetch con datos seedeados ($2,500 × 30/11 = $6,818.18, Δ +13.6% amarillo), drill-down abre modal con entries correctas.
- [x] T022 — `branch-quality-review` ejecutado. Reporte en `engineering/quality-review/proyeccion-gasto-mensual/2026-06-11-1706-branch-quality-review.md`. 0 bloqueantes del sprint; 2 hallazgos preexistentes documentados para backlog.

## Validación previa de consistencia

Sin hallazgos bloqueantes. Plan, spec y test-plan alineados.

## Estado de pruebas

- Backend: 26 tests nuevos, todos verde. Total suite: 386/386, 919 assertions, 5.92s.
- Frontend: 6 tests nuevos, todos verde. Total suite: 116/116, 3.45s.
- Smoke Playwright real: 4/4 escenarios OK (empty state, fetch con datos, badge color correcto según umbral, drill-down con filtros).
- Pint: aplicado a 5 archivos backend nuevos (2 auto-fixes triviales).
- Quality review: 0 bloqueantes, 0 altos del sprint, 2 preexistentes (P1, P2 del endpoint `entriesByBucket`), 2 bajos opcionales.
