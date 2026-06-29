# Preguntas abiertas

## UX / Modelo de comparación

- ID: P-001
  Estado: respondida
  Pregunta: ¿La comparación del mes en curso vs el promedio histórico debe ser **prorrateada por día del mes** o **contra el total del mes completo**?
  Por qué importa: define la fórmula central del reporte. Opción (a) prorrateado: "al día 22 del mes actual gastaste $4200, en promedio al día 22 de los meses anteriores habías gastado $4500 → vas $300 abajo" — comparación justa intra-mes pero requiere reconstruir el gasto histórico día por día. Opción (b) mes completo: "este mes vas $4200 / promedio de mes completo $5800" — simple pero engañosa al inicio del mes (al día 5 mostrará "vas muy abajo" por construcción).
  Impacto si cambia: la fórmula del `historicalAverage` cambia, el modelo `MonthlyAverageReport` gana o pierde el campo `currentDayOfMonth`, el subtítulo de la card cambia, y los tests de data layer son diferentes.
  Respuesta o decisión: **(a) Prorrateado por día del mes**. El promedio histórico se reduce al gasto acumulado promedio hasta el día D del mes donde D = día de `now`. Integrado en RN-A07, RN-A08, RF-003, RF-004, AC-02, AC-03 y modelo `MonthlyAverageReport.historicalAverage` + `currentDayOfMonth`. Día inexistente en mes histórico usa último día disponible (RN-A08).

## Alcance

- ID: P-002
  Estado: respondida
  Pregunta: ¿El **breakdown por categoría** va en v1 o se difiere a v2?
  Por qué importa: agregar breakdown duplica aproximadamente el scope del tab (otra query agregada por categoría + tabla / lista de filas con delta por categoría). Hace al reporte más útil para identificar dónde se desvió el gasto, pero también lo aproxima visualmente al tab "Gasto por categoría" existente. En v1 minimalista el reporte responde la pregunta "¿estoy gastando más o menos?", en v2 responde "¿en qué?".
  Impacto si cambia: agrega ~50% de scope (modelo extiende con `List<CategoryDelta>`, UI suma una sección, ~6-8 tests más).
  Respuesta o decisión: **Incluido en v1**. La card principal sigue siendo la métrica global; debajo se agrega sección "Desglose por categoría" con filas (badge, nombre, promedio prorrateado, gasto actual, delta abs+%) ordenadas por delta absoluto descendente. Integrado como nuevo modelo `CategoryAverageDelta` (RF-010), lista en `MonthlyAverageReport.categoryBreakdown` (RF-009), sección dedicada en UI (RF-006), reglas RN-A09 / RN-A12 / RN-A13 / RN-A14, casos CP-06 / CB-T10 / CB-T11, criterio AC-08 / AC-09.

## UX menor (resoluble con supuesto razonable, dejado como consulta opcional)

- ID: P-003
  Estado: respondida
  Pregunta: ¿Los presets de N (3, 6, 12 meses) son los correctos? ¿Querés que también haya "1 mes" (compara este mes vs solo el anterior) o "24 meses" (2 años)?
  Por qué importa: UX. No bloquea.
  Impacto si cambia: trivial — un literal en el código.
  Respuesta o decisión: **Presets ampliados a `[1, 3, 6, 12, 24]`**. 1 mes = comparativa contra solo el mes anterior; 24 = 2 años para usuarios con histórico largo. Integrado en RF-002 y S-04.
