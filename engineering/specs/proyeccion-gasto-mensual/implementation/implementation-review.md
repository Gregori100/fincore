# Implementation Review: proyeccion-gasto-mensual

## Resumen de lo implementado

Séptimo reporte `/reports/forecast` y su export `.xlsx`. Para el mes en curso, por cada categoría con historial en los 3 meses calendario inmediatamente anteriores, proyecta cuánto va a gastar el usuario al cierre del mes usando la fórmula `gastado × dias_mes / dias_transcurridos` y la compara contra el promedio histórico. Badges de color verde/amarillo/rojo según los umbrales (≤0, 0-20, >20) del Δ%. Integrado con drill-down y export Excel siguiendo el patrón establecido. Cero migraciones, cero cambios en endpoints o vistas existentes.

## Archivos principales modificados

Backend nuevos:

- `backend/app/Domain/Finance/Reports/SpendingForecastReport.php`
- `backend/tests/Feature/Finance/SpendingForecastReportTest.php`
- `backend/tests/Feature/Http/ForecastReportTest.php`

Backend modificados:

- `backend/app/Http/Controllers/FinanceController.php` — método `reportForecast` agregado.
- `backend/app/Http/Controllers/ReportExportController.php` — método `forecast` agregado.
- `backend/routes/api.php` — 2 rutas nuevas (JSON + xlsx).

Frontend nuevos:

- `frontend/src/views/app/ReportsForecastView.vue`
- `frontend/tests/components/ReportsForecastView.spec.js`

Frontend modificados:

- `frontend/src/components/finance/ReportsSubnav.vue` — 7° tab "Proyección".
- `frontend/src/router/index.js` — ruta `/reports/forecast`.
- `frontend/src/api/finance.js` — método `reportForecast()`.

Docs:

- `CLAUDE.md` — 2 filas nuevas en la tabla de rutas API.
- `docs/api/reports.md` — sección nueva "GET /api/finance/reports/forecast" + actualización de "Export a Excel" con el séptimo endpoint.

Engineering docs:

- `engineering/specs/proyeccion-gasto-mensual/spec.md`, `checklist.md`, `plan/{plan,tasks,test-plan}.md`, `implementation/*`.
- `engineering/quality-review/proyeccion-gasto-mensual/2026-06-11-1706-branch-quality-review.md`.

## Tareas completadas

Todas (T001..T022). Detalle en `progreso.md`. Cero desviaciones de alcance.

## Tareas pendientes

Ninguna del sprint. El QR identificó 2 hallazgos preexistentes del endpoint `entriesByBucket` (P1: bucket "Sin categorizar" no filtra correctamente; P2: drill-down con kind=expense no incluye credit_expense). Ambos están documentados para el backlog general — heredados del sprint `por-cuenta-drilldown`, afectan también `ReportsByCategoryView` y son responsabilidad de un sprint dedicado.

## Riesgos residuales

- **P1/P2 preexistentes**: cuando un usuario hace drill-down al bucket "Sin categorizar" o tiene cargos de tarjeta categorizados, el modal puede mostrar entries inconsistentes con el bucket. Mitigación: documentado en `backlog`. No introducido por este sprint.
- **Performance**: 1 sola query agregada por usuario con SUM(CASE WHEN). Para datasets típicos de FinCore (~50ms). Si crece a miles de categorías, vigilar.

## Pruebas realizadas

- **Backend**: 26 tests nuevos (16 del Service + 10 HTTP). 386/386 verde total (eran 360 + 26).
- **Frontend**: 6 tests smoke del componente. 116/116 verde total (eran 110 + 6).
- **Pint**: limpio sobre los 4 archivos backend del sprint.
- **Smoke Playwright real**: empty state OK, datos seedeados muestran cálculo correcto ($2,500 × 30/11 = $6,818.18, Δ +13.6% amarillo), drill-down abre modal con entries del mes en curso filtradas por la categoría correcta, tab "Proyección" visible en el subnav.
- **Casos borde cubiertos**: día 1 con current=0 → proyección 0, día último → proyección = current, año bisiesto (29 días feb 2024), cruce de año en ventana (ene 2026 → oct-dic 2025), categoría archivada con histórico, bucket "Sin categorizar", entries cancelados, kinds correctos (sólo expense + credit_expense), scope user A/B, orden delta_pct desc con null al final, totals agregados correctos.

## Pruebas recomendadas

- **E2E Playwright dedicado**: no se agregó (consistente con sprints previos). Si se quiere defensa adicional, agregar un spec en `tests-e2e/`.
- **Test de drill-down con bucket "Sin categorizar"**: actualmente no cubierto. El smoke prueba solo `category_id` con UUID válido. Agregar cuando se atienda P1.
- **Test de credit_expense en bucket de drill-down**: no cubierto. Agregar cuando se atienda P2.

## Posibles regresiones

- **Ninguna identificada** en los flujos existentes. Backend 360 tests previos siguen verde, frontend 110 tests previos siguen verde.
- Los 6 reportes existentes y sus exports responden idénticos. Cashflow, Por categoría, etc. sin cambios.
- `EntriesDrilldownModal`, `ExcelExportButton`, `ReportsSubnav` se reusaron sin cambios destructivos.

## Recomendaciones para code review humano

1. **Validar el patrón de la query SQL**: 1 query con SUM(CASE WHEN) + leftJoin + HAVING. Es el patrón que recomienda el plan. ¿El revisor prefiere algo distinto (ej. 2 queries separadas, una por mes en curso y otra por ventana)?
2. **Atender P1 y P2 como backlog**: ambos hallazgos del QR son preexistentes pero ahora afectan también el nuevo reporte. Vale la pena dedicar un sprint chico al endpoint `entriesByBucket` para corregir ambos a la vez.
3. **`leftJoin` sin filtro explícito de `categories.user_id`**: defensa en profundidad. Considerar agregar para consistencia futura, aunque hoy no hay riesgo IDOR real (validado por la cadena de validaciones en endpoints de creación).
4. **Revisar el quality-review completo**: `engineering/quality-review/proyeccion-gasto-mensual/2026-06-11-1706-branch-quality-review.md`. Sin bloqueantes del sprint.
