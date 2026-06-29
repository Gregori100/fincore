# Clarificaciones

## 2026-06-29

- Pregunta: P-001
  Decision: comparación **prorrateada por día del mes** (opción a). El promedio histórico se calcula como `Σ(gasto_acumulado_mes_i_hasta_día_D) / M` donde D = día de `now` y M = meses disponibles. Si D no existe en un mes histórico (e.g. D=31 en febrero), usar el último día disponible.
  Impacto en spec: integrada en RN-A07, RN-A08, RF-003, RF-004, AC-02, AC-03. Modelo `MonthlyAverageReport` retiene `currentDayOfMonth`. Subtítulo de UI explica el prorrateo. Eliminada la variante "modo de comparación" del modelo (queda fijo `prorated`).

- Pregunta: P-002
  Decision: **breakdown por categoría incluido en v1**. Agregado modelo `CategoryAverageDelta` con `categoryId` nullable, nombre, slugs, promedio prorrateado, gasto actual, delta absoluto y porcentual. Lista `categoryBreakdown` en `MonthlyAverageReport`. UI: sección scrolleable debajo de la card principal con filas tipo `BaseCard` ordenadas por delta absoluto descendente.
  Impacto en spec: nuevo RF-006 (sección desglose) + RF-010 (modelo `CategoryAverageDelta`). Reglas RN-A09 (categorías archivadas → "Sin categoría"), RN-A12 (orden), RN-A13 (sin histórico), RN-A14 (sin gasto actual). Casos CP-06, CB-T10, CB-T11. Criterios AC-08, AC-09. Saca el "diferido a v2" de Fuera de alcance.

- Pregunta: P-003
  Decision: presets de N ampliados a `[1, 3, 6, 12, 24]` meses.
  Impacto en spec: RF-002 y S-04 actualizados con la lista nueva. Default N=3 sin cambio.

## 2026-06-29 (post-quality-review)

- Pregunta: B1 quality review v1 — ¿el divisor del promedio cuenta meses-con-datos o todos los meses cerrados?
  Decision: **meses con al menos un entry de gasto** (decisión deliberada, no degradación). El promedio es "condicional al uso": un mes cerrado sin entries no participa ni en numerador ni en denominador. Razón: para single-user que registra gastos día a día, un mes con 0 entries típicamente significa "no usó la app", no "consumo real = 0". Dividir por meses sin uso diluye el promedio con ceros artificiales y daña la utilidad del reporte como base de presupuesto.
  Impacto en spec: RN-A04 reescrita para clarificar que `monthsAvailable` = meses-con-datos (no meses-cerrados-de-la-ventana). CB-T04 reescrita para confirmar que mes vacío no contribuye. Nuevo S-12 documentando la decisión "condicional al uso". El código en `reports.dart` ya implementa esto correctamente; no se modifica.
