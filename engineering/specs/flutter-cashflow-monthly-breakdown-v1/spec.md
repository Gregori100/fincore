# Desglose mensual por categoría en Cashflow

## Resumen

Agrega un desglose por categoría dentro del tab "Cashflow mensual" (`/reports`, tab 2). Al tapear la fila de un mes se abre un bottom sheet que separa las categorías de ingresos y las categorías de gastos con monto, porcentaje y color/ícono. El sheet incluye un botón "Ver movimientos →" que hace drill-down a `/entries` filtrado al rango completo del mes. Sin cambios en el layout base del tab ni en el modelo `CashflowReport` existente.

## Problema a resolver

Los 3 reportes existentes cubren dimensiones distintas y complementarias:

- **Cashflow mensual** — corte temporal (mes-a-mes) pero plano: solo `income`, `expense`, `net`. No dice a qué categorías se destinó el ingreso ni el gasto de cada mes.
- **Gasto por categoría** — agrega el período completo por categoría de gasto pero pierde el corte mensual.
- **Ingreso por categoría** — idem para ingresos.

Diego usa el cashflow para revisar mes a mes cómo va evolucionando su libreta. Para responder "¿por qué el mes X gasté más que el Y?" hoy tiene que ir a `/entries` con filtros manuales o cambiar el rango de `spending-by-category` a un mes específico y anotar mentalmente los números para compararlos con otro mes.

Falta el corte "mes específico, todas las categorías". Es el aporte diferencial que ninguno de los reportes existentes cubre.

## Objetivo

Entregar un desglose por categoría dentro del tab cashflow que:

- Se accede sin fricción con un tap en la fila del mes.
- Muestra las categorías de ingresos y las de gastos del mes con monto, porcentaje del total del mes y color/ícono.
- Reactivo: si cambia un movimiento en el mes visible o se renombra una categoría, el sheet re-emite sin refresh manual.
- Incluye drill-down a `/entries` filtrado al mes para ver movimientos individuales.
- Sin regresión visual ni funcional del tab base (query agregada del cashflow sigue siendo la misma).

## Alcance

- **Servicio** (`mobile/lib/data/reports.dart`):
  - Nuevo método `ReportsService.cashflowMonthBreakdown({DateTime monthAnchor})` que retorna `Stream<MonthBreakdown>`.
  - Query con SQL parametrizado: `strftime('%Y-%m', occurred_at, 'localtime') = ?` como filtro de mes (patrón heredado del sprint calendar/heatmap para timezone-safe).
  - `GROUP BY j.category_id, j.kind` agregando `SUM(amount)` por bucket.
  - `LEFT JOIN categories c ON c.id = j.category_id AND c.deleted_at IS NULL` para incluir "Sin categoría" cuando la categoría es null o está archivada.
  - Filtra `kind IN ('income', 'expense', 'credit_expense')`. Excluye `transfer` y `debt_payment` (misma regla del cashflow — son internos y doble contarían).
  - `readsFrom: {journalEntries, categories}` para reactividad completa.
  - Helper `_buildMonthBreakdown` en Dart que separa las filas en 2 buckets (income vs expense/credit_expense), calcula percent, resuelve la label "Sin categoría" y ordena descendente por amount.

- **Modelos** (`mobile/lib/data/reports.dart`):
  - `MonthBreakdown { firstDay: DateTime, totalIncome: double, totalExpense: double, net: double, incomeBuckets: List<CategoryFlow>, expenseBuckets: List<CategoryFlow> }`. Const-inmutable.
  - `CategoryFlow { categoryId: String?, label: String, colorSlug: String?, iconSlug: String?, amount: double, percent: double }`. Const-inmutable. Cuando `categoryId == null`, `label = "Sin categoría"` y `colorSlug/iconSlug = null` (UI muestra un ícono/color neutro).

- **Widget** (`mobile/lib/screens/reports/cashflow_tab.dart`):
  - Agregar `onTap` en cada fila de mes del breakdown numérico existente.
  - `onTap` invoca `showModalBottomSheet` con `isScrollControlled: true` (patrón heatmap) y monta `_MonthBreakdownSheet(monthAnchor)`.
  - `_MonthBreakdownSheet` es `StatefulWidget` que cachea el Stream una sola vez (patrón cashflow tab) y renderea:
    - Handle drag arriba.
    - Encabezado: mes formateado (ej. "Junio 2026") + fila con Ingresos $ y Gastos $ + Neto $ (respetando FincoreColors positive/negative).
    - Sección "Ingresos por categoría" (oculta si `incomeBuckets.isEmpty`) con `_CategoryFlowRow` por bucket.
    - Sección "Gastos por categoría" (oculta si `expenseBuckets.isEmpty`) idem.
    - Fallback: si ambos vacíos, mensaje "Sin movimientos en este mes." (edge de mes con solo transfers/debt_payments).
    - Botón "Ver movimientos →" al final con `Icons.arrow_forward`.
  - Al tapear "Ver movimientos →": `Navigator.pop(context)` para cerrar el sheet + `context.push('/entries', extra: EntriesFilters(datePreset: DateRangePreset.custom, from: firstDayOfMonth, to: lastDayOfMonth))`.
  - Widget interno `_CategoryFlowRow` con `CategoryBadge` (o ícono neutro para "Sin categoría") + label + amount formateado + percent con 0-1 decimales.

- **`EntriesFilters`** (`mobile/lib/data/entries_filters.dart`):
  - Nuevo factory `EntriesFilters.forMonth({DateTime firstDay})` que arma el rango `[firstDay 00:00, lastDayOfMonth 23:59:59.999]`. Reutilizable por otros reportes futuros.

- **Loading/empty/error states del sheet**:
  - Loading: skeleton con 2-3 filas.
  - Error: banner con mensaje + retry (patrón heatmap).
  - Empty: mensaje "Sin movimientos en este mes." con ícono neutro.

- **FAQ del Help** (`mobile/lib/screens/help_screen.dart`): bullet nuevo en "¿Cómo se calculan los reportes?" mencionando el nuevo drill-down mensual.

- **Tests**:
  - UT servicio: agregación básica, uncategorized, categorías archivadas, filtro por kind, percent, orden desc, reactividad con `emitsThrough`.
  - Widget: tap en la fila del mes abre el sheet, sheet muestra ambas secciones cuando corresponde, botón "Ver movimientos" navega a `/entries` con el filtro correcto.

- **Bump**: `0.16.5+87` → `0.17.0+88`.

## Fuera de alcance

- Gráficos dentro del sheet (donuts, barras). Solo lista con barra de progreso inline opcional.
- Comparación mes anterior / año anterior dentro del sheet.
- Filtros adicionales dentro del sheet (por cuenta, por kind específico).
- Export del breakdown a CSV o imagen.
- Presupuesto vs realidad dentro del sheet (existe el reporte de presupuestos aparte).
- Lista de movimientos individuales dentro del sheet — para eso está el drill-down a `/entries`.
- Rediseño del tab base del cashflow: layout, presets, bar chart. Todo se conserva.
- Recompute del modelo `MonthCashflow` existente. Sigue siendo el mismo agregado plano.
- Categorías del tab que están archivadas: se agrupan en "Sin categoría" (convención del proyecto).

## Reglas de negocio

- **RN-CB01 (filtro por mes)**: el sheet muestra las categorías del mes específico usando `strftime('%Y-%m', occurred_at, 'localtime')` para que la agrupación respete la zona horaria local del dispositivo (patrón calendar/heatmap).
- **RN-CB02 (kinds admitidos)**: solo `income` (para bucket ingresos), `expense` y `credit_expense` (para bucket gastos). `transfer` y `debt_payment` excluidos (movimientos internos, coherente con `cashflowByMonth`).
- **RN-CB03 (Sin categoría en gastos)**: bucket "Sin categoría" para gastos agrupa 3 fuentes:
  - `category_id IS NULL`.
  - Categoría archivada (`categories.deleted_at IS NOT NULL`).
  - Categoría con `applies_to = 'income'` (edge legacy simétrico al drilldown-parity del proyecto).
- **RN-CB04 (Sin categoría en ingresos)**: simétrico a RN-CB03. Agrupa:
  - `category_id IS NULL`.
  - Categoría archivada.
  - Categoría con `applies_to = 'expense'`.
- **RN-CB05 (percent)**: `bucket.amount / totalDelLado × 100`. `totalIncome` para buckets de ingresos, `totalExpense` para buckets de gastos. Sin normalizar contra el neto.
- **RN-CB06 (orden)**: descendente por `amount` dentro de cada lista. "Sin categoría" NO tiene privilegio de orden — cae naturalmente por su monto.
- **RN-CB07 (secciones opcionales)**: si `incomeBuckets.isEmpty` NO se renderea la sección de ingresos (y su encabezado). Idem para gastos. Si ambos vacíos, mensaje "Sin movimientos en este mes."
- **RN-CB08 (drill-down)**: el botón "Ver movimientos →" hace push a `/entries` con `EntriesFilters.forMonth(firstDay: monthAnchor)`. Sin filtro de kind (el usuario ve todos los movimientos del mes incluidos transfers/debt_payments).
- **RN-CB09 (reactividad)**: registrar/cancelar un movimiento del mes visible re-emite el sheet en tiempo real. Renombrar una categoría del mes visible re-emite también (por el join con `categories`).
- **RN-CB10 (movimientos cancelados)**: `deleted_at IS NULL` a nivel de journal_entries. Movimientos cancelados no cuentan.
- **RN-CB11 (categorías archivadas para join)**: `LEFT JOIN categories ON c.id = j.category_id AND c.deleted_at IS NULL`. Un archive de categoría con movimientos en el mes visible re-emite el sheet y los movimientos afectados migran al bucket "Sin categoría".
- **RN-CB12 (percent con total 0)**: si `totalIncome == 0` no hay buckets de ingresos (RN-CB07). Si por edge (montos negativos, imposible con la libreta libre pero defensivo) el total es 0 con buckets, el percent se calcula como 0 sin dividir por cero.

## Requisitos funcionales

- RF-001: agregar `ReportsService.cashflowMonthBreakdown({required DateTime monthAnchor})` que retorna `Stream<MonthBreakdown>` con la query especificada en Alcance.
- RF-002: implementar los modelos `MonthBreakdown` y `CategoryFlow` en `reports.dart` como clases const-inmutables.
- RF-003: la query filtra por `strftime('%Y-%m', occurred_at, 'localtime') = ?` recibiendo el año-mes del `monthAnchor` como string `YYYY-MM`.
- RF-004: `LEFT JOIN categories` con `c.deleted_at IS NULL` — categorías archivadas se cuentan como "Sin categoría".
- RF-005: filtrar `j.kind IN ('income', 'expense', 'credit_expense')` y `j.deleted_at IS NULL`.
- RF-006: separar los buckets por kind en el helper Dart: `income → incomeBuckets`, `expense | credit_expense → expenseBuckets`.
- RF-007: `readsFrom: {journalEntries, categories}` para reactividad completa.
- RF-008: aplicar los filtros simétricos RN-CB03 y RN-CB04 en el helper Dart: `applies_to='income'` cae al bucket "Sin categoría" de gastos, `applies_to='expense'` cae al bucket "Sin categoría" de ingresos.
- RF-009: cada `CategoryFlow` calcula `percent = amount / totalDelLado × 100` (RN-CB05).
- RF-010: dentro de cada lista los buckets se ordenan `amount DESC`.
- RF-011: agregar `onTap` a la fila de mes del breakdown del cashflow tab que invoca `showModalBottomSheet(context: context, isScrollControlled: true, builder: ... _MonthBreakdownSheet(monthAnchor: month.firstDay))`.
- RF-012: `_MonthBreakdownSheet` renderea el layout completo especificado en Alcance con StreamBuilder + loading/empty/error states.
- RF-013: `_MonthBreakdownSheet` incluye botón "Ver movimientos →" que ejecuta `Navigator.pop(context)` seguido de `context.push('/entries', extra: EntriesFilters.forMonth(firstDay: monthAnchor))`.
- RF-014: agregar factory `EntriesFilters.forMonth({required DateTime firstDay})` que arma el rango del mes completo.
- RF-015: FAQ del Help agrega un bullet mencionando el drill-down mensual.
- RF-016: 12-15 tests nuevos aprox (10-12 UT servicio + 3-4 widget) + tests existentes del cashflow siguen verdes.
- RF-017: bump de versión a `0.17.0+88`.

## Casos principales

1. Diego abre `/reports` → tab "Cashflow mensual". Ve la lista actual con presets/métricas/bar chart intacta. Tapea la fila "Junio 2026". Se abre el bottom sheet con el resumen del mes + 2 secciones ("Ingresos por categoría" con Sueldo 83%, Freelance 17%; "Gastos por categoría" con Comida 41%, Renta 29%, etc.). Cierra tapeando fuera del sheet.
2. Diego tapea la fila "Mayo 2026" que solo tuvo gastos. Se abre el sheet con la sección de gastos y sin la sección de ingresos (RN-CB07). Neto del mes es negativo.
3. Diego tapea la fila "Julio 2026" con solo 1 movimiento sin categoría. El sheet muestra un bucket único "Sin categoría" en la sección correspondiente. Percent = 100%.
4. Diego tapea "Ver movimientos →" del sheet abierto de Junio. Se cierra el sheet y `/entries` abre con el rango filtrado a `[2026-06-01 00:00, 2026-06-30 23:59:59.999]` sin filtro de kind. Ve todos los movimientos del mes incluidos transfers/debt_payments.
5. Diego renombra una categoría con movimientos en Junio mientras el sheet está abierto. El sheet re-emite en tiempo real con la nueva label.
6. Diego registra un expense nuevo en Junio mientras el sheet está abierto. El sheet re-emite con el nuevo bucket / suma / percent recalculado.

## Casos borde

- **CB-01**: Mes sin movimientos (todo el mes solo transfers/debt_payments o directamente vacío). Ambos buckets vacíos. Sheet muestra "Sin movimientos en este mes." (RN-CB07 fallback).
- **CB-02**: Mes con solo ingresos. Sección "Gastos por categoría" oculta. Sheet muestra solo la sección de ingresos + botón "Ver movimientos".
- **CB-03**: Mes con solo gastos. Sección "Ingresos por categoría" oculta.
- **CB-04**: Mes con `category_id IS NULL` en todos los movimientos. Bucket único "Sin categoría" en cada sección con percent 100%.
- **CB-05**: Categoría archivada con movimientos en el mes visible. Migra a "Sin categoría" (RN-CB11) por el `LEFT JOIN` con `deleted_at IS NULL`.
- **CB-06**: Categoría con `applies_to='income'` que tiene un `credit_expense` (edge legacy). Cae al bucket "Sin categoría" de gastos (RN-CB03).
- **CB-07**: Categoría con `applies_to='expense'` que tiene un `income` (edge legacy). Cae al bucket "Sin categoría" de ingresos (RN-CB04).
- **CB-08**: Mes con múltiples movimientos misma categoría. Suma correcta con `SUM(amount)`.
- **CB-09**: Movimiento cancelado (`deleted_at IS NOT NULL`) en el mes. No cuenta.
- **CB-10**: Registrar movimiento nuevo con el sheet abierto — re-emite con el bucket actualizado.
- **CB-11**: Cancelar movimiento del mes visible con el sheet abierto — re-emite; si era el único de su categoría, esa entrada desaparece del listado.
- **CB-12**: Renombrar categoría con movimientos en el mes visible — re-emite con la nueva label.
- **CB-13**: Archivar categoría con movimientos en el mes visible — re-emite y los movimientos afectados migran a "Sin categoría".
- **CB-14**: Timezone edge — movimiento el `31/mayo 23:30 UTC` que localmente cae en `1/junio 00:30`. La query con `'localtime'` lo cuenta en junio (patrón heredado del calendar).
- **CB-15**: Muchos buckets (más de 10 categorías en un mes). El sheet debe hacer scroll interno (`isScrollControlled: true`) sin overflow visual.
- **CB-16**: Drill-down "Ver movimientos" al último día del mes con hora 23:59:59.999. La query de `/entries` respeta el filtro `to` inclusivo con subsegundo.
- **CB-17**: Cambiar el rango de fechas del tab base mientras el sheet está abierto. El sheet sigue mostrando el mes original (no se sincroniza porque cachea el `monthAnchor`); al cerrarlo y reabrirlo desde una nueva fila cambia. Comportamiento aceptable — el sheet es una vista puntual.

## Criterios de aceptacion

- `flutter test` verde con al menos 12 tests nuevos.
- `flutter analyze` sin errores nuevos.
- APK release compilado con `0.17.0+88` y verificado con `scripts/verify-apk.sh`.
- **Smoke SM-01**: abrir el tab "Cashflow mensual", ver la lista con datos, tapear una fila con datos → sheet abierto con ambas secciones renderizadas.
- **Smoke SM-02**: tapear la fila de un mes que solo tuvo gastos → sheet sin sección de ingresos.
- **Smoke SM-03**: tapear "Ver movimientos →" del sheet abierto → `/entries` abre con filtro custom del mes correcto (verificable por el badge del filtro y los movimientos listados).
- **Smoke SM-04**: registrar un movimiento nuevo desde `/entries` en el mes cuyo sheet está abierto → volver al sheet (o dejarlo abierto en split), el bucket refleja el nuevo movimiento.
- **Smoke SM-05**: renombrar una categoría del mes visible → sheet re-emite con nueva label.
- **Smoke SM-06**: cerrar el sheet arrastrando hacia abajo o tapeando fuera → vuelve al tab base sin errores.
- **Smoke SM-07**: mes sin movimientos → sheet muestra "Sin movimientos en este mes." con estilo consistente.
- Regresión: los otros 10 tabs de `/reports` siguen funcionando; el tab base del cashflow conserva presets, métricas y bar chart intactos.

## Criterios medibles de exito

- `flutter test` total ≥ 551 tests verdes (539 baseline + ~12 nuevos).
- `flutter analyze` limpio (0 errores nuevos).
- Sheet abre en < 300 ms en un mes con hasta 20 categorías distintas.
- Percent de cada bucket suma 100 dentro de cada sección (validado en UT).
- 0 regresión en los tests existentes de `cashflowByMonth` y del widget del cashflow tab.
- APK release build < 500 KB adicional respecto de baseline.

## Riesgos

- **R1 — Reactividad de rename de categoría**: `readsFrom: {journalEntries, categories}` incluye `categories`, pero la query no la usa en el `WHERE`. Un rename dispara re-emit. Mitigación: es aceptable por consistencia (`spending-by-category` sigue el mismo patrón). Verificar en UT + SM-05.
- **R2 — Percent con total 0**: RN-CB12 defensivo. Puede pasar solo si hay buckets con amount=0 (imposible en flujo normal; posible en edge de import). Sin manejo dedicado, división 0/0 daría NaN visible en UI. Mitigación: chequear `total > 0` antes de dividir y omitir el bucket con amount=0.
- **R3 — Tests widget de bottom sheet**: patrón funciona OK en heatmaps (probado). Riesgo bajo. Se replica el patrón.
- **R4 — Scroll interno del sheet con muchos buckets**: si son 30+ categorías el sheet puede quedar largo. Mitigación: `isScrollControlled: true` + `SingleChildScrollView` interno; el sheet toma máximo ~85% de altura de pantalla.
- **R5 — Timezone edge**: `'localtime'` está probado en calendar/heatmap. Riesgo residual: si el usuario cambia zona horaria del dispositivo entre months, un movimiento borderline puede saltar. Aceptable (documentado en el patrón).
- **R6 — Drill-down navigation stack**: `Navigator.pop(context)` + `context.push('/entries', extra: ...)` es idiomatico. Riesgo: si el pop no completa antes del push, el stack queda con el sheet suspendido. Mitigación: `await Navigator.of(context).maybePop(); if (mounted) context.push(...)`.

## Supuestos

- El widget `CategoryBadge` existente acepta `null` colorSlug/iconSlug para renderizar un fallback neutro (validar durante T001 del plan; si no, agregar variante).
- `AmountFormatter` del proyecto renderea los montos consistentemente con el resto del cashflow.
- `showModalBottomSheet` con `isScrollControlled: true` funciona bien con `MaxHeight` del sistema. Patrón validado en heatmaps.
- El botón "Ver movimientos →" solo hace push a `/entries` — no navega al form ni pre-abre movimientos individuales.
- Diego no requiere presupuesto vs realidad dentro del sheet (fuera de alcance).
- El `monthAnchor` que recibe el servicio es un `DateTime(year, month, 1)` (primer día del mes en local). El servicio lo formatea a `YYYY-MM` para el SQL.
- Los tests widget usan el harness `pumpFincoreApp` con `seed` (patrón del proyecto).
- El bump `0.17.0+88` es apropiado (minor por feature aditiva visible).

## Impacto esperado

- Diego responde "por qué gasté más en junio que en mayo" en 3 taps sin fricción.
- El cashflow deja de ser un dato plano y se vuelve navegable por mes → categoría → movimientos.
- Cierre del gap conocido: los 3 reportes complementarios (cashflow, spending-by-category, income-by-category) ahora cubren las 3 dimensiones (mes-a-mes agregado, período categorizado, mes-a-mes categorizado).
- Cero cambio en el modelo de datos ni schema. Feature 100% aditiva.
- Preparación para features futuros: comparación mes vs mes (spike, drop), presupuesto vs realidad por mes, alertas contextuales por categoría.
- Cero regresión visible en cuentas, dashboard, otros reportes.
