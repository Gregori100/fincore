# Tasks — Proyección de gasto mensual

## Backend

- [ ] T001 Backend: crear `App\Domain\Finance\Reports\SpendingForecastReport` con constructor que recibe `string $userId` y método `generate(): array` que devuelve la estructura RF-003 completa. Reusa `firstDayOfMonth`/`startOfMonth` de Carbon; calcula `days_in_month` y `days_elapsed` con `now()->daysInMonth` y `now()->day` (clamp a 1 para defensa). Hace 1 sola query con SUMs condicionales + leftJoin a categories. Aplica HAVING SUM > 0 para excluir categorías sin historial. Ordena buckets por delta_pct DESC con null al final.
  RF: RF-001 a RF-005, RF-011, RF-012
  Depende de: ninguna
  Paralelizable: no (gate)
  Criterio de terminado: clase compila y devuelve array con shape exacto.

- [ ] T002 Pruebas: tests unitarios de `SpendingForecastReportTest` cubriendo todos los casos del test-plan (shape correcto, fórmula al día 10, día 1 con 0, último día, ventana 3 meses, cobertura, archivadas con histórico, sin categorizar, cancelados, kinds correctos, scope user, promedio 0 → null, orden, totals, empty user, año bisiesto, cruce de año en ventana).
  RF: RF-001 a RF-005, RF-011, RF-012
  Depende de: T001
  Paralelizable: no
  Criterio de terminado: 17+ tests verde en `php artisan test --filter=SpendingForecastReportTest`.

- [ ] T003 Backend: agregar método `reportForecast(Request $request)` a `FinanceController`. Sin validación. Instancia el Service, llama `generate()`, devuelve `response()->json($report)`.
  RF: RF-001, RF-002, RF-003
  Depende de: T001
  Paralelizable: sí (con T005)
  Criterio de terminado: endpoint responde 200 manualmente; ruta registrada en `routes/api.php`.

- [ ] T004 Backend: agregar ruta `GET /api/finance/reports/forecast` en `routes/api.php` dentro del grupo `auth:sanctum + verified`, después de las rutas existentes de reports.
  RF: RF-001
  Depende de: T003
  Paralelizable: no
  Criterio de terminado: `php artisan route:list` muestra la ruta.

- [ ] T005 Backend: agregar método `forecast(Request $request)` a `ReportExportController`. Reusa el Service, arma rows con [name, current_spent, historical_average, projection, delta_pct/100 o ''], formatos [TEXT, MONEY, MONEY, MONEY, PCT]. Footer con totales. Filename `fincore-proyeccion-gasto-YYYY-MM.xlsx`.
  RF: RF-006
  Depende de: T001
  Paralelizable: sí (con T003)
  Criterio de terminado: endpoint responde 200 con xlsx válido manualmente.

- [ ] T006 Backend: agregar ruta `GET /api/finance/reports/forecast/export.xlsx` en `routes/api.php`.
  RF: RF-006
  Depende de: T005
  Paralelizable: no
  Criterio de terminado: ruta registrada y descarga manual funciona.

## Pruebas (backend)

- [ ] T007 Pruebas: tests HTTP `ForecastReportTest` para el endpoint JSON. Cubre: auth/verify, shape correcto, ignora params extra, empty state, scope isolation.
  RF: RF-001, RF-002, RF-003, RF-012
  Depende de: T004
  Paralelizable: sí (con T008)
  Criterio de terminado: 5+ tests verde.

- [ ] T008 Pruebas: tests HTTP `ForecastReportTest` para el endpoint xlsx. Cubre: 200 + headers, filename pattern, content matches JSON, empty categories aún genera xlsx, scope isolation.
  RF: RF-006
  Depende de: T006
  Paralelizable: sí
  Criterio de terminado: 5+ tests verde.

## Frontend

- [ ] T009 Frontend: crear `frontend/src/views/app/ReportsForecastView.vue`. Estructura inspirada en `ReportsBudgetsView.vue` (sin filtros, mes en curso, hero + tabla). Fetch a `financeApi.reportForecast()`. Empty state si `categories.length === 0`.
  RF: RF-007, RF-012
  Depende de: T004
  Paralelizable: sí (con T011)
  Criterio de terminado: vista renderiza con dataset real y muestra 5 columnas + hero.

- [ ] T010 Frontend: integrar `EntriesDrilldownModal` en la vista. Click en fila dispara open con filtros `{ kind: 'expense', category_id, from: firstDayOfMonth, to: today }`. Maneja correctamente `category_id = null` para "Sin categorizar".
  RF: RF-007
  Depende de: T009
  Paralelizable: sí
  Criterio de terminado: click en fila abre modal con entries correctos.

- [ ] T011 Frontend: integrar `ExcelExportButton` en la vista. URL `/finance/reports/forecast/export.xlsx`. Params `{}`. Disabled si loading o si `categories.length === 0`.
  RF: RF-006, RF-007
  Depende de: T009
  Paralelizable: sí
  Criterio de terminado: click descarga xlsx.

- [ ] T012 Frontend: badges de color para Δ%. Verde si `delta_pct <= 0`, amarillo si `0 < delta_pct <= 20`, rojo si `delta_pct > 20`, neutral si null. Reusar CSS variables existentes (`--color-positive`, `--color-warning`, `--color-negative`, `--color-text-muted`).
  RF: RF-007
  Depende de: T009
  Paralelizable: sí
  Criterio de terminado: badges renderizan con la clase correcta según umbral.

- [ ] T013 Frontend: agregar 7° tab `{ name: 'reports-forecast', label: 'Proyección' }` al array `tabs` en `frontend/src/components/finance/ReportsSubnav.vue`.
  RF: RF-009
  Depende de: ninguna (paralelo a backend)
  Paralelizable: sí
  Criterio de terminado: tab aparece y enlaza correctamente.

- [ ] T014 Frontend: agregar ruta `/reports/forecast` con `name: 'reports-forecast'`, `component: () => import('@/views/app/ReportsForecastView.vue')`, `meta: { requiresAuth: true }` en `frontend/src/router/index.js`.
  RF: RF-010
  Depende de: T009
  Paralelizable: sí (con T013)
  Criterio de terminado: navegación a la ruta carga la vista.

- [ ] T015 Frontend: agregar `reportForecast()` a `frontend/src/api/finance.js` para llamar al endpoint JSON.
  RF: RF-001
  Depende de: T004
  Paralelizable: sí
  Criterio de terminado: función exportada y consumida por la vista.

## Pruebas (frontend)

- [ ] T016 Pruebas: test smoke `ReportsForecastView.spec.js` con mock de la API. Cubre: render con dataset, empty state, badges con clases correctas, click dispara apertura del drill-down.
  RF: RF-007, RF-012
  Depende de: T012
  Paralelizable: no
  Criterio de terminado: 5+ tests verde.

## Documentacion

- [ ] T017 Documentación: agregar 2 filas en la tabla de rutas API de `CLAUDE.md`: `/finance/reports/forecast` y `/finance/reports/forecast/export.xlsx`.
  RF: ninguno directo
  Depende de: T006
  Paralelizable: sí (con T018)
  Criterio de terminado: filas presentes con descripción coherente.

- [ ] T018 Documentación: agregar sección "Proyección" a `docs/api/reports.md` con shape de respuesta y query params (ninguno).
  RF: ninguno directo
  Depende de: T006
  Paralelizable: sí
  Criterio de terminado: sección presente con ejemplo curl + JSON.

## Validacion de calidad

- [ ] T019 Validación: suite backend completa verde + Pint sobre archivos nuevos.
  RF: criterios mínimos
  Depende de: T002, T007, T008
  Paralelizable: no
  Criterio de terminado: `php artisan test` verde; `./vendor/bin/pint --test` sin diffs en archivos nuevos.

- [ ] T020 Validación: suite frontend completa verde.
  RF: criterios mínimos
  Depende de: T016
  Paralelizable: sí (con T019)
  Criterio de terminado: `npx vitest run` verde.

- [ ] T021 Validación: smoke manual con Playwright o navegador real. Validar los 10 escenarios del test-plan.
  RF: criterios mínimos
  Depende de: T019, T020
  Paralelizable: no
  Criterio de terminado: 10/10 escenarios OK.

- [ ] T022 Validación: ejecutar `branch-quality-review` con slug=proyeccion-gasto-mensual. Atender hallazgos críticos antes del merge.
  RF: validación final
  Depende de: T021
  Paralelizable: no
  Criterio de terminado: reporte generado y hallazgos críticos resueltos.
