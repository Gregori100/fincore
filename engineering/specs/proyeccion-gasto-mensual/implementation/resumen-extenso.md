# Resumen extenso — Proyección de gasto mensual

## Contexto tomado de spec, preguntas y clarificaciones

- **Spec**: `engineering/specs/proyeccion-gasto-mensual/spec.md`. 12 RFs (RF-001..RF-012), 11 reglas de negocio, 13 casos borde, fórmula exacta clavada con edge cases.
- **Preguntas**: no se creó `preguntas.md` — las 4 decisiones grandes (método de proyección, ventana histórica, cobertura, columnas) se cerraron antes vía AskUserQuestion.
- **Checklist**: todo verde.
- **Plan**: `plan/{plan.md, tasks.md, test-plan.md}`. 22 tareas (T001..T022). Sin cambios de schema, cambios aditivos puros, reusando patrón de los 6 reportes previos y el `ReportExporter` del sprint export-excel-reportes.

## Relación con plan/plan.md y plan/tasks.md

- El plan se ejecutó completo. Sin desviaciones de alcance.
- Sin desviaciones técnicas significativas: la implementación sigue el patrón propuesto en el plan (1 query agregada con SUMs condicionales + leftJoin + HAVING, controller delgado, vista clonada de ReportsBudgetsView).

## Cambios principales por módulo o capa

### Backend — capa de dominio (Service)

- `App\Domain\Finance\Reports\SpendingForecastReport`: constructor `(string $userId)`, método único `generate(): array`.
- Calcula `today`, `days_in_month`, `days_elapsed` (clamp >= 1), `window_from`, `window_to` con Carbon.
- 1 sola query SQL parametrizada: `select` + 2 `selectRaw` con SUMs condicionales (CASE WHEN para `current_spent` y `historical_total`) + `where` por user_id + kinds + rango ancho + `leftJoin` a categories (no respeta soft delete, conserva nombres históricos) + `groupBy` (category_id + categories.name/color/icon) + `havingRaw` (SUM histórico > 0) para excluir categorías sin historial.
- En PHP: `historical_average = total / 3`, `projection = current_spent * dias_mes / dias_elapsed`, `delta_pct = ((proj - avg) / avg) * 100` redondeado a 1 decimal (`null` si avg === 0.0).
- `usort` ordena por delta_pct DESC con null al final, desempate alfabético.
- `totals` agregados con la misma fórmula aplicada a las sumas.

### Backend — capa HTTP

- `FinanceController::reportForecast(Request $request)`: sin validación de params, instancia el Service, devuelve JSON.
- `ReportExportController::forecast(Request $request)`: reusa el Service, arma rows con `delta_pct/100` o `''` para que `0.0%` de Excel pinte correcto, footer con totales, filename `fincore-proyeccion-gasto-YYYY-MM.xlsx`.
- 2 rutas en `routes/api.php` dentro del grupo `auth:sanctum + verified`.

### Backend — tests

- `SpendingForecastReportTest`: 16 tests con `Carbon::setTestNow` para reproducibilidad. Cubren shape básica, fórmula al día 10, día 1 con 0, último día, ventana 3 meses, cobertura HAVING, archivadas con histórico, "Sin categorizar", cancelados, kinds correctos, scope user A/B, promedio 0 → null, orden, totals, año bisiesto, cruce de año en ventana, sólo expense+credit_expense cuentan.
- `ForecastReportTest`: 10 tests HTTP. Auth (401), verify (403), shape JSON, ignora params extra, empty user, scope isolation. Para xlsx: headers correctos, filename pattern, content matches JSON, empty categories aún genera xlsx, unauth.

### Frontend — vista

- `ReportsForecastView.vue`: clonado estructural de `ReportsBudgetsView`. Hero con 4 totales agregados, tabla con 5 columnas, badge color por Δ%, drill-down con click en fila, export con `ExcelExportButton`, empty state con CTA a `/entries`.
- Computed `deltaClass(deltaPct)` mapea umbrales a clases CSS: null → muted, ≤0 → positive, ≤20 → warning, >20 → negative.
- `openDrilldown(bucket)` arma filtros `{ category_id, kind: 'expense', from: primerDíaDelMes, to: today }`.

### Frontend — integración

- `ReportsSubnav.vue`: agregado `{ name: 'reports-forecast', label: 'Proyección' }` al array de tabs.
- `router/index.js`: ruta `/reports/forecast` con `meta: { requiresAuth: true }`, lazy-loaded.
- `api/finance.js`: agregado `reportForecast: () => client.get('/finance/reports/forecast')`.

### Frontend — tests

- `ReportsForecastView.spec.js`: 6 tests smoke con mocks. Cubren render con dataset, badges color (verde/amarillo/rojo/neutral con valores fronterizos -100/0/10/25), empty state, click en fila dispara drill-down con filtros correctos.

### Documentación

- `CLAUDE.md`: 2 filas nuevas en la tabla de rutas API.
- `docs/api/reports.md`: sección completa con shape de respuesta y ejemplo curl, actualización de "Export a Excel" con el séptimo endpoint.

## Desviaciones respecto al plan

Sin desviaciones de alcance ni de diseño. Todo el plan se ejecutó.

## Pruebas realizadas y recomendadas

Realizadas:
- Backend 386/386 verde, frontend 116/116 verde.
- Pint limpio.
- Smoke Playwright end-to-end: empty state, fetch con datos seedeados, cálculo correcto ($2,500 × 30/11 = $6,818.18, Δ +13.6% amarillo), drill-down abre modal con entries esperadas.

Recomendadas opcionales:
- E2E Playwright dedicado al flujo completo.
- Tests del drill-down para los casos preexistentes (P1, P2 del QR).

## Riesgos residuales y posibles regresiones

Riesgos:
- **Performance**: 1 query agregada. <50ms en datasets típicos. Si crece a miles de categorías, vigilar.
- **Cálculo en zona horaria del servidor**: documentado como supuesto (mes en curso = mes del servidor).
- **2 hallazgos preexistentes del endpoint `entriesByBucket`** documentados en QR como P1 (category_id=null no filtra correctamente) y P2 (kind=expense no incluye credit_expense). Heredados del sprint `por-cuenta-drilldown`, no introducidos por este sprint.

Posibles regresiones:
- **Ninguna identificada**. Suite backend y frontend 100% verde sin cambios. Los 6 reportes previos y sus exports siguen funcionando idénticamente.

## Quality review

Reporte completo en `engineering/quality-review/proyeccion-gasto-mensual/2026-06-11-1706-branch-quality-review.md`. Resumen:

- **Bloqueantes del sprint**: 0.
- **Altos del sprint**: 0.
- **Altos preexistentes documentados**: 2 (P1, P2 del endpoint `entriesByBucket`).
- **Bajos del sprint**: 2 (M1 toFirstOfMonth defensivo, M2 leftJoin explícito user_id).

Veredicto: listo para merge.
