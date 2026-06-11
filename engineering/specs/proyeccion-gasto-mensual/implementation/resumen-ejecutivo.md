# Resumen ejecutivo — Proyección de gasto mensual

## Qué se implementó

Séptimo reporte en `/reports/forecast`: para el mes en curso, por categoría, proyecta cuánto va a gastar el usuario al cierre del mes usando su ritmo actual y lo compara contra su promedio histórico de los 3 meses anteriores. Cada categoría aparece con 4 métricas: gastado este mes, promedio histórico, proyección y Δ% (con badge verde/amarillo/rojo según los umbrales). Solo aparecen categorías con al menos 1 movimiento de gasto en los 3 meses previos.

Incluye drill-down (click en categoría abre los movimientos del mes en curso), export a Excel, y tab nuevo en el subnav de reportes.

## Impacto esperado

- El usuario anticipa excesos antes de que ocurran, basado en su comportamiento real.
- Complementa al Plan (prescriptivo, basado en eventos declarados) y a Presupuestos (compara contra límite fijado a mano).
- Cambio aditivo: cero impacto en flujos existentes, cero migraciones, cero cambios en endpoints o vistas previas.

## Riesgos o pendientes relevantes

- **Sin nuevos riesgos** del sprint.
- **2 hallazgos preexistentes** (P1, P2) del endpoint `entriesByBucket` afectan el nuevo reporte y también `ReportsByCategoryView` desde el sprint `por-cuenta-drilldown`:
  - **P1**: drill-down al bucket "Sin categorizar" muestra entries de todas las categorías porque el filtro `category_id=null` se descarta en el cliente. Documentado para backlog general.
  - **P2**: drill-down con `kind=expense` no incluye `credit_expense`, así que el modal puede mostrar menos entries que los que componen el bucket cuando hay cargos a tarjeta. Documentado para backlog general.
- **Performance**: query agregada eficiente (1 sola SQL con SUM/CASE WHEN). Para datasets típicos de FinCore corre en <50ms.

## Estado de pruebas

- **Backend**: 386/386 verde (eran 360; +26 nuevos: 16 unit del Service + 10 HTTP).
- **Frontend**: 116/116 verde (eran 110; +6 smoke).
- **Pint**: limpio sobre archivos nuevos.
- **Smoke Playwright real**: empty state OK, cálculo correcto ($2,500 × 30/11 = $6,818.18, Δ +13.6% amarillo), drill-down abre modal con entries esperadas.
- **Quality review**: 0 bloqueantes, 0 altos del sprint, 2 hallazgos preexistentes documentados para backlog, 2 bajos opcionales.

Listo para merge.
