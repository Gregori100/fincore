# Tasks — Export Excel de reportes

## Backend

- [ ] T001 Backend: agregar dependencia `phpoffice/phpspreadsheet` (^4.0) vía `composer require` dentro del container `api`.
  RF: RF-001..RF-012 (habilita todo el sprint)
  Depende de: ninguna
  Paralelizable: no (bloqueante para el resto del backend)
  Criterio de terminado: `composer.json` y `composer.lock` actualizados; `php artisan test` no rompe; `composer validate` sin warnings.

- [ ] T002 Backend: crear `App\Domain\Finance\Reports\Export\ReportExporter` con métodos `sheetTitle`, `header`, `table`, `footer`, `download`.
  RF: RF-006, RF-007, RF-008, RF-009, RF-010, RF-003
  Depende de: T001
  Paralelizable: no
  Criterio de terminado: clase compila; los métodos devuelven `$this` (fluent) salvo `download()` que devuelve un `StreamedResponse` (o equivalente con binario válido); cobertura con T003.

- [ ] T003 Pruebas: tests unitarios de `ReportExporter` (al menos 6 casos: header, table, footer con valores, footer vacío, formato moneda, formato pct, truncado de nombre de hoja).
  RF: RF-006..RF-010
  Depende de: T002
  Paralelizable: no (depende de la clase)
  Criterio de terminado: tests pasan en `php artisan test --filter=ReportExporter`.

- [ ] T004 Backend: crear `App\Http\Controllers\ReportExportController` con método `byCategory(Request $request)` que valida params, invoca `CategoryBreakdownReport`, arma headers/rows/columnFormats según RF-011 y devuelve `ReportExporter::download(filename)` con el patrón RF-012.
  RF: RF-001, RF-003, RF-011, RF-012
  Depende de: T002
  Paralelizable: no (gate del patrón end-to-end)
  Criterio de terminado: endpoint responde 200 con xlsx descargable manualmente; ruta registrada en `routes/api.php`.

- [ ] T005 Backend: ruta `GET /api/finance/reports/by-category/export.xlsx` en `routes/api.php` dentro del grupo `auth:sanctum + verified`.
  RF: RF-001
  Depende de: T004
  Paralelizable: no
  Criterio de terminado: `php artisan route:list` muestra la ruta.

- [ ] T006 Pruebas: tests HTTP del endpoint `byCategory` (3 mínimo: returns_xlsx_with_correct_headers, xlsx_matches_json_endpoint, empty_report_returns_zero_total).
  RF: RF-001, RF-003
  Depende de: T005
  Paralelizable: no (gate del contrato)
  Criterio de terminado: tests pasan; firma del contrato (content-type, filename regex, parseo del binario) validada.

- [ ] T007 Backend: método `cashflowMonthly` en `ReportExportController` + ruta + estructura RF-011 (cols `Año-Mes | Ingresos | Gastos | Neto`, footer con totales).
  RF: RF-002, RF-011
  Depende de: T006
  Paralelizable: sí (con T008..T011)
  Criterio de terminado: endpoint 200; tests HTTP T012 pasan.

- [ ] T008 Backend: método `monthComparison` + ruta + estructura RF-011 (cols `Categoría | Mes anterior | Mes actual | Δ | Δ %`).
  RF: RF-002, RF-011
  Depende de: T006
  Paralelizable: sí
  Criterio de terminado: endpoint 200; tests T013 pasan; filename con patrón `YYYY-MM`.

- [ ] T009 Backend: método `creditCards` + ruta + estructura RF-011 (cols Tarjeta + métricas, sin footer); celdas vacías para metadata null.
  RF: RF-002, RF-011, RF-012
  Depende de: T006
  Paralelizable: sí
  Criterio de terminado: endpoint 200; tests T014 pasan; filename `fincore-tarjetas-credito.xlsx` (sin rango).

- [ ] T010 Backend: método `budgets` + ruta + estructura RF-011 (cols Categoría | Límite | Gastado | Restante | Consumido %).
  RF: RF-002, RF-011
  Depende de: T006
  Paralelizable: sí
  Criterio de terminado: endpoint 200; tests T015 pasan.

- [ ] T011 Backend: método `byAccount` + ruta + estructura RF-011 (cols Cuenta | Tipo | Ingresos | Gastos | Neto).
  RF: RF-002, RF-011
  Depende de: T006
  Paralelizable: sí
  Criterio de terminado: endpoint 200; tests T016 pasan.

## Pruebas (backend)

- [ ] T012 Pruebas: tests HTTP `cashflowMonthly` (returns_xlsx + xlsx_matches_json + filename con rango por fechas).
  RF: RF-002, RF-003, RF-012
  Depende de: T007
  Paralelizable: sí (con T013..T016)
  Criterio de terminado: tests pasan.

- [ ] T013 Pruebas: tests HTTP `monthComparison` (incluye filename con `YYYY-MM` y comparativo con categoría nueva en mes actual).
  RF: RF-002
  Depende de: T008
  Paralelizable: sí
  Criterio de terminado: tests pasan.

- [ ] T014 Pruebas: tests HTTP `creditCards` (returns_xlsx + no_footer_row + empty_metadata_renders_blank_cells).
  RF: RF-002, RF-010
  Depende de: T009
  Paralelizable: sí
  Criterio de terminado: tests pasan.

- [ ] T015 Pruebas: tests HTTP `budgets` (returns_xlsx + incluye formato pct + categoría con monthly_limit=0 renderiza 999% correctamente).
  RF: RF-002, RF-009
  Depende de: T010
  Paralelizable: sí
  Criterio de terminado: tests pasan.

- [ ] T016 Pruebas: tests HTTP `byAccount` (returns_xlsx + cuentas archivadas excluidas).
  RF: RF-002
  Depende de: T011
  Paralelizable: sí
  Criterio de terminado: tests pasan.

- [ ] T017 Pruebas: tests de aislamiento y permisos (user A no ve data de user B en los 6 endpoints; sin token → 401; sin verify → 403).
  RF: RF-001, RF-002
  Depende de: T011 (todos los endpoints ya existen)
  Paralelizable: no
  Criterio de terminado: 8 tests verde (6 scope + 1 unauth + 1 unverified) en `ReportExportTest`.

- [ ] T018 Pruebas: tests de regresión sobre soft delete (entries cancelados y categorías archivadas).
  RF: RF-011
  Depende de: T011
  Paralelizable: no
  Criterio de terminado: tests pasan.

## Frontend

- [ ] T019 Frontend: composable `useExcelDownload` en `frontend/src/composables/useExcelDownload.js` con `download(url, params)`, `loading`, `error`. Lee filename del header, crea blob URL, click anchor, revoke.
  RF: RF-005
  Depende de: ninguna (puede hacerse en paralelo con backend)
  Paralelizable: sí (paralelo a backend tras T002)
  Criterio de terminado: composable exporta función + refs; T020 pasa.

- [ ] T020 Pruebas: test del composable `useExcelDownload` (6 casos: blob+anchor+revoke, filename simple, filename RFC 5987, loading flag, doble click, error JSON).
  RF: RF-005
  Depende de: T019
  Paralelizable: no
  Criterio de terminado: tests pasan en `npm run test`.

- [ ] T021 Frontend: componente `ExcelExportButton.vue` en `frontend/src/components/finance/` con props `{ url, params, disabled, label }`, consume composable, emite `done`/`error`.
  RF: RF-004
  Depende de: T019
  Paralelizable: no (depende del composable)
  Criterio de terminado: componente renderiza; T022 pasa.

- [ ] T022 Pruebas: test del componente `ExcelExportButton.vue` (disabled no clickea, loading muestra spinner, click llama composable con url/params correctos).
  RF: RF-004, RF-005
  Depende de: T021
  Paralelizable: no
  Criterio de terminado: tests pasan.

- [ ] T023 Frontend: integrar `ExcelExportButton` en `ReportsByCategoryView.vue` con URL `/api/finance/reports/by-category/export.xlsx` y params reactivos (kind, account_id, from, to).
  RF: RF-004, RF-005
  Depende de: T021
  Paralelizable: sí (con T024..T028)
  Criterio de terminado: botón visible junto a filtros; click descarga archivo.

- [ ] T024 Frontend: integrar `ExcelExportButton` en `ReportsCashflowView.vue` (params: from, to, account_id).
  RF: RF-004, RF-005
  Depende de: T021
  Paralelizable: sí
  Criterio de terminado: botón visible; descarga funciona.

- [ ] T025 Frontend: integrar `ExcelExportButton` en `ReportsMonthComparisonView.vue` (params: kind, account_id, month).
  RF: RF-004, RF-005
  Depende de: T021
  Paralelizable: sí
  Criterio de terminado: botón visible; descarga funciona.

- [ ] T026 Frontend: integrar `ExcelExportButton` en `ReportsCreditCardsView.vue` (sin params).
  RF: RF-004
  Depende de: T021
  Paralelizable: sí
  Criterio de terminado: botón visible; descarga funciona.

- [ ] T027 Frontend: integrar `ExcelExportButton` en `ReportsBudgetsView.vue` (sin params).
  RF: RF-004
  Depende de: T021
  Paralelizable: sí
  Criterio de terminado: botón visible; descarga funciona.

- [ ] T028 Frontend: integrar `ExcelExportButton` en `ReportsByAccountView.vue` (params: from, to).
  RF: RF-004, RF-005
  Depende de: T021
  Paralelizable: sí
  Criterio de terminado: botón visible; descarga funciona.

## Documentacion

- [ ] T029 Documentación: agregar 6 filas en la tabla de rutas API en `CLAUDE.md`.
  RF: ninguno directo (documentación de soporte)
  Depende de: T011
  Paralelizable: sí (con T030)
  Criterio de terminado: las 6 rutas listadas con método + path + middleware + descripción.

- [ ] T030 Documentación: actualizar `docs/api/README.md` si lista endpoints por reporte (verificar al implementar; si no aplica, registrar).
  RF: ninguno directo
  Depende de: T011
  Paralelizable: sí
  Criterio de terminado: docs actualizadas o nota en `implementation/` confirmando que no hay sección a actualizar.

## Validacion de calidad

- [ ] T031 Validación: suite completa backend + frontend verde sin regresiones.
  RF: criterios mínimos del test-plan
  Depende de: T029, T030, todos los tests
  Paralelizable: no
  Criterio de terminado: `php artisan test` + `npm run test` en verde.

- [ ] T032 Validación: smoke manual de los 6 reportes (descargar cada uno, abrir en LibreOffice/Excel, validar headers, totales, formato moneda y rangos).
  RF: criterios mínimos del test-plan
  Depende de: T031
  Paralelizable: no
  Criterio de terminado: 6/6 reportes con archivo descargado y validado a ojo; capturas o nota en `implementation/`.

- [ ] T033 Validación: ejecutar `branch-quality-review` con `slug=export-excel-reportes`.
  RF: validación final del test-plan
  Depende de: T032
  Paralelizable: no
  Criterio de terminado: reporte generado en `engineering/quality-review/export-excel-reportes/`; sin hallazgos bloqueantes (o todos resueltos antes de merge).
