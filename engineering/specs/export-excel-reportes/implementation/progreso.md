# Progreso de implementación

Todas las tareas T001..T033 completadas. Sin pendientes.

## Tareas completadas

### Backend

- [x] T001 — `composer require phpoffice/phpspreadsheet` (resolvió a ^5.8, ver `desviaciones-plan.md#D-001`).
- [x] T002 — `App\Domain\Finance\Reports\Export\ReportExporter` con métodos fluent + métodos extra `toBinary()` y `loadFromBinary()` para facilitar tests.
- [x] T003 — 11 tests unit del helper (header, table, formatos money/pct, footer vacío, truncado de título, sanitización de caracteres inválidos, throws con longitudes desiguales, magic bytes ZIP, headers HTTP).
- [x] T004 — Controller `ReportExportController` (con los 6 métodos en una sola pasada, ver D-003).
- [x] T005 — 6 rutas registradas en `routes/api.php`.
- [x] T006 — Tests HTTP `byCategory` (5 tests: returns_xlsx, matches_json, empty, validates_params, etc).
- [x] T007-T011 — Métodos `cashflowMonthly`, `monthComparison`, `creditCards`, `budgets`, `byAccount`.
- [x] T012-T016 — Tests HTTP por endpoint.
- [x] T017 — Tests de aislamiento (unauth 401, unverified 403, user A no ve data de B, account_id de otro user → 422).
- [x] T018 — Tests de soft delete (categoría archivada conserva nombre, entry cancelado se excluye).

### Frontend

- [x] T019 — `useExcelDownload` composable.
- [x] T020 — 9 tests del composable + `parseFilename` (filename simple, filename RFC 5987, blob+anchor+revoke, loading flag, doble click ignorado, error JSON).
- [x] T021 — `ExcelExportButton.vue` componente.
- [x] T022 — 5 tests del componente.
- [x] T023-T028 — Integración del botón en las 6 vistas Reports*.vue.

### Documentación

- [x] T029 — `CLAUDE.md` actualizado con las 6 nuevas rutas.
- [x] T030 — `docs/api/reports.md` ampliado con sección "Export a Excel (.xlsx)".

### Validación

- [x] T031 — Suite completa verde: backend 360/360 (eran 327, +33 nuevos), frontend 72/72 (eran 58, +14 nuevos).
- [x] T032 — Smoke vía curl: 6/6 endpoints responden 200 con xlsx válido (Microsoft Excel 2007+).
- [x] T033 — `branch-quality-review` queda como siguiente paso explícito antes del merge.

## Validación previa de consistencia

Sin hallazgos. La spec, plan y test-plan están alineados. No hay preguntas `pendiente`.

## Estado de pruebas

- Backend: 360 tests, 828 assertions, 5.59s.
- Frontend: 72 tests, 3.45s.
- Pint: aplicado a los 4 archivos nuevos (2 issues auto-fix de `no_unused_imports`).
- Smoke manual: 6/6 endpoints validados con curl + `file`.
