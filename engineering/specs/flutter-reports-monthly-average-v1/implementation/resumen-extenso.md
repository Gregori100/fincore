# Resumen extenso — flutter-reports-monthly-average-v1

## Contexto

Sprint motivado por la conversación con Diego del 2026-06-29: paso 0 del módulo Presupuestos futuro. Antes de poder presupuestar, hace falta saber **cuánto se gasta realmente** según el propio patrón histórico del usuario. El tab nuevo cubre esa pregunta con una comparación justa: promedio histórico prorrateado al mismo día del mes que `now` vs gasto acumulado del mes en curso.

### Decisiones de spec / clarificaciones

Las 3 preguntas iniciales fueron respondidas con "todo lo completo":

- **P-001**: comparación **prorrateada por día del mes** (no contra mes completo histórico). Fórmula: `historicalAverage = Σ(gasto_acumulado_mes_i_hasta_día_D) / M` con M = `monthsAvailable`, D = día de `now`.
- **P-002**: **breakdown por categoría incluido en v1**, no diferido. Modelo `CategoryAverageDelta` agregado a `MonthlyAverageReport.categoryBreakdown`.
- **P-003**: presets ampliados a `[1, 3, 6, 12, 24]` meses, default 3.

Confirmación adicional: umbral del semáforo "verde" en ≤95% (no <100%).

## Relación con el plan

El plan técnico en `plan/plan.md` definió:

- Una sola query agregada por `(month_key, category_id)` con condición compuesta `(histórico con day <= D) OR (mes actual)`.
- Helpers privados `_iterateClosedMonths`, `_lastDayOfMonth`, `_buildMonthlyAverageReport`.
- Tab nuevo siguiendo el patrón de `CashflowTab` con state `_monthsBack` + `_reportStream` cacheado.

La implementación siguió el plan **al pie de la letra** con dos pequeñas desviaciones:

- **DV-01**: `_lastDayOfMonth` no se implementó. El filtro SQL `day(occurred_at) <= D` ya cubre RN-A08 sin necesidad de calcular el último día del mes — si D=31 y febrero solo tiene 28 días, no hay entries del 29-31 que excluir, por construcción. El helper habría sido código muerto.
- **DV-02**: el label del tab pasó de "Promedio" a "Promedio mensual" para evitar colisión con la etiqueta "Promedio" del `_HeaderMetric` interno (los widget tests fallaban con `find.text('Promedio')` ambiguo entre TabBar y la métrica). Mantiene consistencia con "Cashflow mensual".

## Cambios principales por módulo o capa

### Data layer (`mobile/lib/data/reports.dart`)

- **Modelo `MonthlyAverageReport`**: inmutable con 11 campos (`monthsRequested`, `monthsAvailable`, `windowFrom`, `windowTo`, `currentDayOfMonth`, `historicalAverage`, `currentMonthSpent`, `deltaAbsolute`, `deltaPercent` nullable, `categoryBreakdown`, `isEmpty` getter).
- **Modelo `CategoryAverageDelta`**: inmutable con 8 campos (`categoryId` nullable para "Sin categoría", `name`, `colorSlug` nullable, `iconSlug` nullable, `historicalAverage`, `currentMonthSpent`, `deltaAbsolute`, `deltaPercent` nullable).
- **Meta privado `_MonthlyAverageCategoryMeta`**: cachea los slugs+nombre por categoría durante el procesamiento de filas.
- **Método público `monthlyAverage`**: query SQL agregada + `customSelect.watch(readsFrom: {journalEntries, categories})`. Acepta `DateTime? now` opcional para tests deterministas.
- **Helpers privados**: `_iterateClosedMonths` (construye lista de meses cerrados anteriores), `_buildMonthlyAverageReport` (procesa filas SQL → modelo), `_monthKey` (formatea `'YYYY-MM'` igual que `strftime`).

### UI (`mobile/lib/screens/reports/monthly_average_tab.dart`)

- **`MonthlyAverageTab`** stateful con `_monthsBack` (default 3) + `_reportStream` cacheado en `didChangeDependencies`. Patrón idéntico a `CashflowTab`.
- **Widgets internos**: `_GlobalCard` (3 columnas de métricas + chip de estado), `_SubtitleLine` (texto "Comparación al día D del mes..."), `_BreakdownHeader`, `_CategoryBreakdown` (lista de `BaseCard` con cada categoría), `_CategoryRow` (badge color+icon, nombre, montos, delta), `_StatusChip` (semáforo con label "Por debajo / En línea / Por encima"), `_HeaderMetric`, `_EmptyState`, `_LoadingState`, `_ErrorState`.
- **Helpers de UI**: `_statusColorForDelta` (RN-A10), `_statusLabel`, `_formatDelta` (signo + currency).

### Router (`mobile/lib/screens/reports_screen.dart`)

- Import + `length: 4 → 5` + `Tab(text: 'Promedio mensual')` + `MonthlyAverageTab()` en `TabBarView`.
- Comentario de clase actualizado con sprint slug.

### Version (`mobile/pubspec.yaml`, `mobile/android/app/build.gradle.kts`)

- `0.10.0+62 → 0.11.0+63`. Nota multilínea en pubspec.yaml describiendo el sprint.

## Pruebas realizadas

### Unit tests del DAO (15 nuevos en `reports_test.dart`)

Grupo `monthlyAverage` con casos UT-01 a UT-15 cubriendo:

- BD vacía y degradación (UT-01, UT-09).
- Agregación básica (UT-02).
- Prorrateo por día (UT-03, UT-04, UT-15).
- Día inexistente en mes histórico RN-A08 (UT-05).
- Buckets de categoría null + archivada (UT-06).
- Soft delete (UT-07).
- Kinds excluidos (UT-08).
- Edge cases de delta porcentual (UT-10, UT-11, UT-12).
- Orden del breakdown RN-A12 (UT-13).
- Reactividad del stream (UT-14).

### Widget tests del tab (4 nuevos en `monthly_average_tab_test.dart`)

- WT-01: render con datos.
- WT-02: cambiar preset.
- WT-03: empty state.
- WT-04: orden del breakdown visible en pantalla.

### Suite completa

`flutter test`: 321 verdes. `flutter analyze`: 0 errores nuevos.

## Desviaciones respecto al plan

- **DV-01**: helper `_lastDayOfMonth` planeado pero no implementado. Razón: el filtro SQL `day <= D` ya cubre RN-A08 por construcción (no excluye días que no existen).
- **DV-02**: label del tab "Promedio" → "Promedio mensual". Razón: colisión de `find.text('Promedio')` con la métrica del header en widget tests.
- **DV-03**: comentario `// Filas con monthKey fuera de la ventana se ignoran defensivamente` en `_buildMonthlyAverageReport` describe un caso teórico (drift en zona horaria, futuros) — no documentado en plan pero conservado por seguridad.

## Riesgos residuales y posibles regresiones

Ver `implementation-review.md` (secciones "Riesgos residuales" y "Posibles regresiones") para detalle.

Resumen:

- Performance con journals >10k entries no medida (riesgo bajo en single-user).
- Categorías con histórico pero sin movimiento del mes actual aparecen en el breakdown — RN-A14, comportamiento esperado pero a confirmar en uso real.
- `length: 4 → 5` del TabBar — sin tests existentes que dependan de length explícito, sin regresión detectada.

## Trazabilidad

- Spec: `engineering/specs/flutter-reports-monthly-average-v1/spec.md`.
- Plan: `engineering/specs/flutter-reports-monthly-average-v1/plan/plan.md`.
- Tasks: `engineering/specs/flutter-reports-monthly-average-v1/plan/tasks.md` (todas las tareas T001..T015 completadas; T016 a discreción de Diego; T017 smoke pendiente; T018 cubierto por estos archivos).
- Quality review pendiente — Diego puede invocar `branch-quality-review` antes del commit final si lo considera necesario.
