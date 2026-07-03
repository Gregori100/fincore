# Reporte de ingreso por categoría

## Resumen

Octavo tab "Ingreso por categoría" en `/reports`, análogo al tab existente "Gasto por categoría" pero para movimientos de tipo `income`. Agrega la suma de `journal_entries.amount` con `kind='income'` agrupada por `category_id` dentro de un rango de fecha configurable (chips Este mes / Mes pasado / Año / Custom). Solo considera categorías con `applies_to ∈ {income, both}`. Reactivo, con drill-down por bucket que navega a `/entries` con filtros precargados. Sin schema bump.

## Problema a resolver

La app hoy tiene 7 reportes pero el vocabulario de todos gira en torno al gasto (por categoría, cashflow que suma agregado, top movimientos, presupuestos, tarjetas, saldo, promedio). El usuario que lleva sus ingresos separados por categoría (ej: sueldo principal, freelance, rentas, ventas) no tiene manera de responder preguntas simples como "en qué mes cobré más de freelance" o "qué porcentaje de mis ingresos vienen de rentas este año". El campo `applies_to` de las categorías ya distingue income/expense/both y el kind `income` ya existe en `journal_entries`, pero ningún reporte los agrupa.

## Objetivo

1. Nuevo tab "Ingreso por categoría" (8vo en `/reports`) que muestra bar chart horizontal + lista con monto absoluto y porcentaje por categoría.
2. Rango configurable con chips (Este mes / Mes pasado / Año / Custom) y default `thisMonth`, idéntico al patrón del tab de gastos.
3. Drill-down: tap en un bucket navega a `/entries` con filtros precargados (`kind=income`, `categoryId` del bucket, rango exacto del reporte).
4. Reactivo: registrar un nuevo `income` o cancelar uno existente actualiza el reporte sin refresh manual.

## Alcance

- Servicio nuevo: `ReportsService.incomeByCategory({from, to})` que devuelve `Stream<IncomeReport>`.
- Modelos nuevos inmutables: `IncomeReport` (total, count, from, to, buckets) y `IncomeBucket` (categoryId, categoryName, colorSlug, iconSlug, total, count, percent).
- Widget nuevo: `IncomeByCategoryTab` en `mobile/lib/screens/reports/income_by_category_tab.dart`.
- Integración al `TabBar` de `ReportsScreen` (pasa de 7 a 8 tabs).
- Nuevo factory `EntriesFilters.forIncomeBucket({categoryId, from, to})` con `kinds: ['income']`.
- Empty state con texto contextual cuando no hay ingresos en el rango.
- Loading state estático (mismo patrón que el tab de gastos, sin animación que cuelgue `pumpAndSettle`).
- Actualizar slide 3 del `OnboardingScreen` a "8 reportes" con fila nueva "Ingreso por categoría".
- Actualizar FAQ de `HelpScreen`: mencionar el nuevo tab.
- Tests: DAO no cambia; servicio + widget + factory de filtros.

## Fuera de alcance

- Rediseño del cashflow existente para desglosarlo por categoría (queda como sprint aparte si aparece necesidad).
- Comparación mes a mes de ingresos por categoría (equivalente al `month-comparison` legacy). Sprint aparte.
- Presupuestos de ingreso (metas mensuales de "quiero ganar X"). Fuera de alcance.
- Reporte de flujo de ingresos por cuenta (quién recibe qué).
- Predicción/forecast de ingresos futuros.
- Filtro por rango de monto dentro del reporte.
- Excel/CSV export.

## Reglas de negocio

- **RN-I01**: Solo cuenta `journal_entries` con `kind = 'income'`. Cualquier otro kind (expense, credit_expense, debt_payment, transfer) se excluye.
- **RN-I02**: Solo cuenta entries activos (`deleted_at IS NULL`).
- **RN-I03**: Rango temporal `[from, to]` inclusivo en ambos extremos (mismo patrón que `spendingByCategory`, RN-R05).
- **RN-I04**: Entries con `category_id NULL` o cuya categoría fue archivada (`categories.deleted_at IS NOT NULL`) agrupan en un bucket especial "Sin categoría". El `LEFT JOIN ... AND c.deleted_at IS NULL` deja `c.id` en NULL para ambos casos y SQLite los combina automáticamente en el `GROUP BY`.
- **RN-I05**: Categorías con `applies_to = 'expense'` **NO** aparecen ni siquiera si tienen entries con `kind='income'` asignados por error legacy. Blindaje simétrico al del reporte de presupuestos.
- **RN-I06**: Orden en la lista: por `total` desc con tiebreak alfabético asc por `categoryName`. El bucket "Sin categoría" cae al final del orden por defecto si su total es 0; si tiene monto, se ordena como cualquier otro bucket por `total`.
- **RN-I07**: El `percent` de cada bucket = `total_bucket / total_general × 100`. Si `total_general == 0`, todos los percent son 0 y el reporte muestra empty state.
- **RN-I08**: El reporte es reactivo. Usa `customSelect(sql, readsFrom: {journalEntries, categories}).watch()` para que se actualice al registrar/cancelar/editar income o al archivar categorías.
- **RN-I09**: Drill-down por bucket → navega a `/entries` con `EntriesFilters.forIncomeBucket(categoryId, from, to)` = `kinds: ['income']`, `categoryIds: [categoryId ?? kUncategorizedFilterToken]`, `datePreset: custom`, `from`/`to` exactos.
- **RN-I10**: Default de rango al abrir el tab: `DateRangePreset.thisMonth` (día 1 a último día del mes calendario, mismo helper que gastos).
- **RN-I11**: En rango `custom`, los DatePickers permiten desde 2020-01-01 hasta 2100-12-31 (mismo rango que gastos).
- **RN-I12**: Si `from > to`, se muestra snackbar warning "El rango no es válido. Verificar las fechas." y no se aplica el cambio (validación en el DatePicker antes de setear estado).

## Requisitos funcionales

- **RF-001**: Nuevo modelo `IncomeReport` en `mobile/lib/data/reports.dart` con campos `double total`, `int count`, `DateTime from`, `DateTime to`, `List<IncomeBucket> buckets`. Getter `bool get isEmpty => buckets.isEmpty`.
- **RF-002**: Nuevo modelo `IncomeBucket` en el mismo archivo con `String? categoryId`, `String categoryName`, `String? colorSlug`, `String? iconSlug`, `double total`, `int count`, `double percent`.
- **RF-003**: Nuevo método `Stream<IncomeReport> incomeByCategory({required DateTime from, required DateTime to})` en `ReportsService`. `customSelect` con `LEFT JOIN` sobre `categories` filtrado por `c.deleted_at IS NULL AND c.applies_to != 'expense'`. `WHERE j.kind = 'income' AND j.deleted_at IS NULL AND j.occurred_at >= ? AND j.occurred_at <= ?`. `GROUP BY c.id, c.name, c.color_slug, c.icon_slug`. Orden RN-I06 aplicado en Dart post-fetch.
- **RF-004**: Nuevo factory `EntriesFilters.forIncomeBucket({required String? categoryId, required DateTime from, required DateTime to})` en `mobile/lib/data/entries_filters.dart` con `datePreset: custom`, `from`, `to`, `kinds: ['income']`, `categoryIds: [categoryId ?? kUncategorizedFilterToken]`.
- **RF-005**: Nuevo widget `IncomeByCategoryTab` StatefulWidget en `mobile/lib/screens/reports/income_by_category_tab.dart`. Cachea `_reportStream` en `didChangeDependencies` (patrón obligado por harness de tests, ver M5 del quality review de reports v1).
- **RF-006**: Header con chips `DateRangePreset.values` (Este mes / Mes pasado / Este año / Custom). Chip seleccionado en color accent; el resto en surface. Reusa el patrón visual del tab de gastos.
- **RF-007**: En modo `custom`, dos DatePickers de fecha (Desde / Hasta) con validación `from ≤ to`. Rango de fecha aceptado 2020-01-01 a 2100-12-31.
- **RF-008**: Debajo de los chips, línea con el rango efectivo formateado en `es_MX` ("1 jul 2026 — 31 jul 2026") en modo no-custom.
- **RF-009**: Body con `StreamBuilder<IncomeReport>`:
  - `snap.hasError` → `_ErrorState` con botón "Reintentar".
  - `!snap.hasData` → `_LoadingState` estático (Card con Skeleton, sin animación).
  - `snap.data!.isEmpty` → `_EmptyState` con texto contextual ("No se registraron ingresos en el período. Ajustar las fechas o registrar un movimiento.").
  - Con datos → `_IncomeBucketsList` con bar chart horizontal + lista.
- **RF-010**: Cada bucket renderea:
  - Chip inline con `colorSlug + iconSlug` de la categoría (36×36, similar al del tab de gastos).
  - Nombre de categoría (o "Sin categoría" si `categoryId==null`).
  - Monto formateado con `formatAmount`.
  - Barra horizontal proporcional al `percent` (color `positive`, altura ~6px).
  - Porcentaje al lado derecho formateado a 1 decimal.
  - `count` de entries en línea secundaria: "3 movimientos".
- **RF-011**: Tap en un bucket → `context.push('/entries?filter={json}')` con `EntriesFilters.forIncomeBucket(...).toDeepLink()` como argumento, análogo al tab de gastos.
- **RF-012**: `ReportsScreen` agrega octavo `Tab(text: 'Ingreso por categoría')` al `TabBar` y `IncomeByCategoryTab()` al `TabBarView`. Mantener `isScrollable: true`.
- **RF-013**: Actualizar slide 3 de `OnboardingScreen`: 8ª fila `_KindRow(icon: Icons.trending_up, color: FincoreColors.positive, label: 'Ingreso por categoría')`. Actualizar párrafo a "8 reportes".
- **RF-014**: Actualizar FAQ de `HelpScreen`: en el tile "¿Cómo se calculan los reportes?" agregar bullet nuevo ("Ingreso por categoría: suma de tus ingresos del período agrupados por categoría, con drill-down por bucket para ver los movimientos exactos.").
- **RF-015**: Bump `pubspec.yaml` + `android/app/build.gradle.kts` a `0.15.0+77` (minor por feature visible).

## Casos principales

1. Diego registró 3 ingresos este mes: sueldo $30000, freelance $5000, freelance $3000. Al abrir el tab con default "Este mes" ve 2 buckets: Sueldo (30000, 78.9%), Freelance (8000, 21.1%).
2. Diego cambia el chip a "Este año" → ve todos los buckets del año con el sueldo dominando.
3. Diego cambia a "Custom" → selecciona 2026-01-01 a 2026-06-30 (semestre) → ve el ranking de ingresos del semestre.
4. Diego tapea el bucket "Freelance" → navega a `/entries` con filtros pre-cargados (Freelance + kind=income + rango del mes) y ve los 2 movimientos individuales.
5. Diego registra un nuevo income "Renta $8000" mientras el tab está abierto → el bucket "Renta" aparece automáticamente sin refresh.
6. Tester nuevo abre el tab sin haber registrado ningún ingreso → ve empty state contextual.

## Casos borde

- **CB-01**: Rango sin ningún income (aunque haya expenses en ese rango) → `isEmpty=true` → empty state.
- **CB-02**: Un income sin `category_id` (registrado sin elegir categoría) → agrupa en bucket "Sin categoría".
- **CB-03**: Un income con `category_id` que apunta a categoría archivada → mismo bucket "Sin categoría" (mezcla con CB-02 gracias al `LEFT JOIN AND c.deleted_at IS NULL`).
- **CB-04**: Legacy: una categoría con `applies_to='expense'` que por algún backup histórico tiene un income asignado → el filtro `applies_to != 'expense'` la excluye. El income asociado también queda excluido (no aparece ni siquiera en "Sin categoría"). Documentado como comportamiento intencional para consistencia con RN-B07 de presupuestos.
- **CB-05**: Todas las categorías con `applies_to='expense'` y algún income asociado → reporte se ve vacío aunque haya movimientos con `kind=income` en el rango. Aceptado; simétrico a RN-I05.
- **CB-06**: Empate en `total` entre 2 buckets → tiebreak alfabético asc.
- **CB-07**: 100+ categorías con ingresos → performance aceptable (<10ms con volumen típico single-user).
- **CB-08**: Cambio de rango mientras el stream está activo → el `_reportStream` se re-construye y el `StreamBuilder` re-suscribe al nuevo stream.
- **CB-09**: Diego cancela (soft delete) un income mientras el tab está abierto → el bucket correspondiente actualiza monto y percent, y el bucket se remueve si su total llega a 0.
- **CB-10**: Un income con `category_id` de una categoría `applies_to='both'` → aparece en el reporte (RN-I05 solo excluye `expense`).
- **CB-11**: Rango que cruza medianoche del último día del mes → sin trade-off temporal como en Presupuestos porque el rango es explícito (from/to), no derivado de "ahora".
- **CB-12**: Backup import v1 legacy con categoría `applies_to='income'` y `monthly_limit != null` → el filtro de este reporte NO la excluye (a diferencia del de Presupuestos), porque la lógica de RN-I05 es sobre `applies_to`, no sobre `monthly_limit`. La categoría aparece si tiene incomes en el rango.

## Criterios de aceptacion

- Al abrir `/reports` se ve el nuevo tab "Ingreso por categoría" al final del TabBar.
- Con 0 ingresos en el rango: empty state con texto contextual y sin errores.
- Con 1+ ingresos: barras horizontales + lista con monto absoluto, percent (1 decimal), count de movimientos.
- Orden: por total desc, tiebreak alfabético.
- Rango default "Este mes"; cambiar a "Mes pasado", "Este año", "Custom" actualiza el reporte reactivamente.
- En modo custom, `from > to` dispara snackbar warning sin aplicar el cambio.
- Tap en un bucket navega a `/entries` con filtros: `kind=income`, `categoryId` del bucket, `datePreset=custom`, `from`/`to` del reporte.
- Registrar un income mientras el tab está abierto: el reporte se actualiza sin refresh manual.
- Categorías `applies_to='expense'` con incomes asociados: no aparecen en el reporte.
- Slide 3 del onboarding menciona "8 reportes" con fila "Ingreso por categoría".
- FAQ Ayuda actualizado con el nuevo tab.
- `flutter test` verde. Objetivo ≥ 452 tests (437 previos + ≥ 15 nuevos).
- `flutter analyze` 0 errores.

## Criterios medibles de exito

- 8 tabs en `/reports` (pasa de 7 a 8).
- ≥ 8 tests nuevos data-layer (empty, buckets básicos, orden, sin categoría, categoría archivada, filtro `applies_to=expense`, percent, reactividad).
- ≥ 4 widget tests (empty state, con datos, drill-down navega a `/entries`, cambio de rango dispara re-stream).
- ≥ 2 tests del factory `EntriesFilters.forIncomeBucket`.
- Version `0.15.0+77` visible en Configuración → Acerca de.
- `verify-apk.sh` OK.

## Riesgos

- **R1 — Confusión con "Cashflow mensual"**: el usuario podría preguntarse "¿en qué se diferencia?". Diferencia: Cashflow agrega totales por mes calendario (ingresos vs gastos, sin desglose); este tab desglosa ingresos por categoría en un rango libre. Mitigación: textos claros en el tab + FAQ.
- **R2 — Categorías con `applies_to='both'`**: pueden acumular incomes y expenses. El reporte solo suma sus incomes. Nombre del bucket es el mismo tanto en el tab de gastos como en el de ingresos, lo cual es correcto pero puede confundir. Mitigación: aceptable, es semántica del dominio.
- **R3 — Categorías legacy con `applies_to='expense'` y incomes asociados**: aunque el DAO valida al insertar (RN-011 + kind vs applies_to), un import de backup legacy podría tener la combinación. Mitigación: RN-I05 los excluye del reporte.
- **R4 — Similar a M1 del quality review credit-cards**: si el usuario deja el tab abierto cruzando medianoche del último día del mes con preset "Este mes", el rango no se actualiza. **NO aplica acá**: el preset se recalcula solo al re-tapear el chip. Como el `_from`/`_to` se setean al construir el widget con `dateRangeForPreset(thisMonth, DateTime.now())`, quedan fijos hasta que Diego cambie explícitamente. Idéntico al comportamiento del tab de gastos existente.
- **R5 — Performance con volúmenes altos**: el `LEFT JOIN` sobre `journal_entries` filtrado por kind + rango + deleted_at. Con `idx_entries_kind`, `idx_entries_occurred_active` y `idx_entries_deleted` ya existentes, la query aprovecha índices. Sub-10ms típico.
- **R6 — Percent con `total_general == 0`**: división por cero. Mitigación: si `total_general == 0`, retornar `isEmpty=true` sin calcular percent.
- **R7 — Deep link con custom range**: al pasar `from`/`to` con `.toDeepLink()`, la URL puede quedar larga. Ya cubierto por el patrón existente del tab de gastos; sin problema real.

## Supuestos

- El `LEFT JOIN` con `AND c.deleted_at IS NULL AND c.applies_to != 'expense'` en el JOIN (no en el WHERE) es la forma correcta de que las categorías archivadas o expense se traten como "sin categoría" en el bucket, en lugar de excluir las filas del income entero. Verificable: si se pasa al WHERE, un income con categoría expense desaparecería del `total_general`.
- La UX del bar chart horizontal es la misma que el reporte de gastos existente. Diego ya la conoce y le funciona.
- El color del bar (positive verde) transmite la naturaleza del ingreso, en contraste con el rojo/naranja del gasto. Consistente con la paleta del app.
- No se ofrece filtro por cuenta en este reporte (a qué cuenta llegó el income). Fuera de alcance; el drill-down lo cubre.
- El sprint no toca `spendingByCategory` — evita regresión en el reporte de gastos existente.
- El nuevo icono en el onboarding (`Icons.trending_up`) diferencia visualmente los ingresos de los gastos (que usa `Icons.pie_chart_outline`).

## Impacto esperado

- Diego (y usuarios con múltiples fuentes de ingreso) pueden responder "cuánto entra de cada fuente" en cualquier rango.
- Cierra la simetría del análisis por categoría: hoy hay gasto por categoría, mañana también ingreso por categoría.
- El drill-down completa el flujo de exploración: veo el bucket → toco → veo los movimientos individuales → puedo editar/cancelar.
- Base para features futuros del backlog: `month-comparison` (mes vs mes por categoría, aplicable a ambos ingresos y gastos), forecast de ingresos, promedio de ingresos mensual.
- Sin schema bump. Cero riesgo de migración destructiva.
