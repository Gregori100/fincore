# Plan técnico — flutter-reports-income-by-category-v1

## Enfoque tecnico

Sprint chico-mediano puramente aditivo sobre la infraestructura del sprint `flutter-reports-v1` (tab "Gasto por categoría"). Estrategia:

1. **Data layer**: espejo casi 1:1 del método `spendingByCategory`. Nuevo modelo `IncomeReport` + `IncomeBucket`, nuevo método `incomeByCategory({from, to})`. La única diferencia real con el patrón de gastos: el filtro `WHERE kind = 'income'` en vez de `kind IN ('expense', 'credit_expense')`, y el `AND c.applies_to != 'expense'` en el LEFT JOIN para excluir categorías fantasma (blindaje simétrico al de Presupuestos).

2. **Filtros**: nuevo factory `EntriesFilters.forIncomeBucket({categoryId, from, to})` en `entries_filters.dart` con `kinds: ['income']` y `categoryIds: [id ?? kUncategorizedFilterToken]`. Copia idiomática de `forCategoryBucket`.

3. **UI**: nuevo widget `IncomeByCategoryTab` en `mobile/lib/screens/reports/income_by_category_tab.dart`. Copia del `SpendingByCategoryTab` con:
   - Texto del empty state contextual a "ingresos".
   - Color del bar chart en `positive` (verde) en vez de `accent`.
   - Deep link usa el factory nuevo `forIncomeBucket`.
   - Sin selector de rango temporal distinto — mismo patrón de chips.

4. **Integración**: `ReportsScreen` pasa de 7 a 8 tabs. Slide 3 del onboarding gana la 8ª fila con `Icons.trending_up`. FAQ Ayuda agrega bullet.

5. **Versión**: `0.14.4+76 → 0.15.0+77` (minor por feature visible).

## Requisitos funcionales cubiertos

- **RF-001, RF-002** (modelos): `IncomeReport` con `total`, `count`, `from`, `to`, `buckets`, getter `isEmpty`. `IncomeBucket` con `categoryId`, `categoryName`, `colorSlug`, `iconSlug`, `total`, `count`, `percent`. Ambos en `mobile/lib/data/reports.dart` cerca de `SpendingReport`/`SpendingBucket`.

- **RF-003** (servicio): `Stream<IncomeReport> incomeByCategory({required DateTime from, required DateTime to})` con SQL:
  ```
  SELECT c.id, c.name, c.color_slug, c.icon_slug,
         SUM(j.amount) AS total, COUNT(*) AS count
  FROM journal_entries j
  LEFT JOIN categories c
    ON c.id = j.category_id
    AND c.deleted_at IS NULL
    AND c.applies_to != 'expense'
  WHERE j.kind = 'income'
    AND j.deleted_at IS NULL
    AND j.occurred_at >= ?
    AND j.occurred_at <= ?
  GROUP BY c.id, c.name, c.color_slug, c.icon_slug
  ```
  `readsFrom: {journalEntries, categories}` para reactividad. Post-fetch: orden RN-I06 en Dart + cálculo `percent`.

- **RF-004** (factory filtros): `EntriesFilters.forIncomeBucket({categoryId, from, to})` con `datePreset: DateRangePreset.custom`, `from`, `to`, `kinds: const ['income']`, `categoryIds: [categoryId ?? kUncategorizedFilterToken]`. En `mobile/lib/data/entries_filters.dart`.

- **RF-005..008** (widget + header): `IncomeByCategoryTab` StatefulWidget cachea `_reportStream` en `didChangeDependencies` (patrón obligado, ver M5 del quality review v1 de reports). Header con chips `DateRangePreset.values` + DatePickers en modo custom.

- **RF-009** (states): `StreamBuilder<IncomeReport>` con 4 estados (error, loading estático, empty contextual, con datos).

- **RF-010** (BucketList): chip 36×36 con color+icono, nombre categoría, monto `formatAmount`, barra horizontal `positive` proporcional al percent, label del percent (1 decimal), count de movimientos.

- **RF-011** (drill-down): `context.push('/entries?filter=$json')` con `EntriesFilters.forIncomeBucket(...).toDeepLink()`. Confirmar que la ruta `/entries` acepta el mismo query param que el tab de gastos.

- **RF-012** (integración TabBar): actualizar `mobile/lib/screens/reports_screen.dart` de `length: 7` a `length: 8`; agregar `Tab(text: 'Ingreso por categoría')` y `IncomeByCategoryTab()` al final. Actualizar comentario doc con el 8vo tab.

- **RF-013** (onboarding): 8ª fila `_KindRow(icon: Icons.trending_up, color: FincoreColors.positive, label: 'Ingreso por categoría')` en el slide 3. Actualizar párrafo a "8 reportes". El slide 3 ya usa `LayoutBuilder + ConstrainedBox + IntrinsicHeight` desde el sprint budgets → sin necesidad de tocar el layout.

- **RF-014** (FAQ): bullet nuevo dentro del tile "¿Cómo se calculan los reportes?" con la explicación del nuevo tab. El tile ya lista los 7 tabs; se agrega el 8vo.

- **RF-015** (versión): `pubspec.yaml` con comentario del sprint + `android/app/build.gradle.kts`. `0.15.0+77`.

## Archivos o modulos probablemente afectados

- `mobile/lib/data/reports.dart` — nuevos modelos + método `incomeByCategory`.
- `mobile/lib/data/entries_filters.dart` — nuevo factory `forIncomeBucket`.
- `mobile/lib/screens/reports/income_by_category_tab.dart` — archivo nuevo.
- `mobile/lib/screens/reports_screen.dart` — 7 → 8 tabs.
- `mobile/lib/screens/onboarding_screen.dart` — 8ª fila slide 3 + párrafo.
- `mobile/lib/screens/help_screen.dart` — bullet FAQ + posible actualización de "8 tabs" en el prefacio.
- `mobile/pubspec.yaml` + `mobile/android/app/build.gradle.kts` — version bump.
- Tests nuevos:
  - `mobile/test/data/reports_test.dart` — grupo `incomeByCategory (sprint income-by-category)`.
  - `mobile/test/data/entries_filters_test.dart` (o donde vivan los tests de filtros; verificar) — tests del nuevo factory.
  - `mobile/test/screens/reports/income_by_category_tab_test.dart` — nuevo archivo.

## Entidades y estados afectados

- **`JournalEntry`**: no cambia. Se lee con `kind='income'` filtrado por rango temporal.
- **`Category`**: no cambia. Se filtra por `deleted_at IS NULL` y `applies_to != 'expense'`.
- **Modelos nuevos derivados**:
  - `IncomeReport` — DTO inmutable. Se recomputa en cada emit del stream.
  - `IncomeBucket` — 1 por categoría con al menos 1 income en el rango, ordenados por total desc con tiebreak alfabético.

Estados/transiciones que disparan re-emit del stream:
- Registrar `income` con o sin categoría → nuevo bucket o suma al existente.
- Cancelar (soft delete) un `income` → bucket baja monto o desaparece si total llega a 0.
- Editar un `income` (cambio de amount, category_id, occurred_at) → recomputación completa del rango.
- Archivar una categoría → sus incomes migran al bucket "Sin categoría" en el próximo emit.
- Cambiar `applies_to` de una categoría a `'expense'` → sale del reporte con sus incomes asociados (comportamiento intencional, RN-I05).

## Compatibilidad con datos y procesos existentes

- **Datos existentes**: Diego y testers ya pueden tener incomes en la BD (kind='income'). El reporte funciona "gratis" contra los datos actuales. Ningún backfill ni migración.
- **Backup JSON v1**: sin cambios. No serializa/deserializa nada nuevo.
- **Otros reportes**: intocados. `spendingByCategory`, `cashflowByMonth`, `topMovements`, `balanceAtDate`, `monthlyAverage`, `watchCreditCards`, `watchBudgetsProgress` siguen igual.
- **Deep link a `/entries`**: reutiliza el mecanismo existente. El listener del query param no distingue "vino de gastos" vs "vino de ingresos"; solo aplica los filtros.
- **Cashflow mensual**: convive con el nuevo tab. El usuario podría preguntarse el porqué de la diferencia — mitigado con textos claros y FAQ (R1 de riesgos).
- **Slide 3 del onboarding**: ya soporta scroll interno desde el sprint budgets. Agregar una fila más no rompe el layout.

## Cambios de datos si aplica

No aplica. No hay migración ni schema bump. La columna `journal_entries.kind` acepta `'income'` desde el schema v1.

## Cambios de API si aplica

No aplica. App local single-user.

## Cambios de integraciones si aplica

No aplica.

## Cambios de UI si aplica

- **ReportsScreen**: octavo tab. `TabBar` mantiene `isScrollable: true`; el label "Ingreso por categoría" es el más largo (19 chars) — mismo largo que "Gasto por categoría", sin problema visual.
- **IncomeByCategoryTab (nuevo)**:
  - Header con chips de presets de fecha + resumen del rango efectivo.
  - En modo custom, dos `DateFieldOutlined` (Desde / Hasta).
  - Body con StreamBuilder de los 4 estados.
  - Loading state: card con Skeleton estático (patrón M5 quality review v1 de reports).
  - Empty state: ícono `trending_up`, texto contextual, sin CTA (a diferencia de tarjetas o presupuestos, no hay una acción directa que ofrecer aquí; el usuario ya sabe registrar ingresos).
- **Onboarding slide 3**: 8ª fila.
- **HelpScreen FAQ**: bullet nuevo + el prefacio pasa a "8 pestañas" (revisar consistencia).

## Cambios de permisos si aplica

No aplica.

## Riesgos tecnicos

- **R1 — Confusión con Cashflow**: el usuario puede no entender la diferencia. Mitigación cubierta en FAQ.
- **R2 — Filtro `applies_to != 'expense'` en el JOIN, no en el WHERE**: importante — si se pasa al WHERE, un income con categoría expense desaparecería del conteo. En el JOIN correctamente cae en el bucket "Sin categoría". Test explícito (CB-D04).
- **R3 — División por cero al calcular `percent`**: si `total_general = 0`, no calcular percent (el reporte queda vacío por RN-I07 antes de llegar acá). Defensivo: `percent = total == 0 ? 0 : bucket.total / total * 100`.
- **R4 — Deep link con `custom` range**: la URL de `/entries` acepta el filtro como query param. Ya validado por el sprint de gastos. Sin problema si se sigue el mismo patrón.
- **R5 — SQL performance**: con `idx_entries_kind`, `idx_entries_occurred_active`, `idx_entries_deleted` existentes, la query es sub-10ms. No es hot path.
- **R6 — Reactividad con `readsFrom: {categories, journalEntries}`**: mismo trade-off que otros reportes; aceptable. Cualquier update en esas tablas re-emite. Con volumen single-user es imperceptible.
- **R7 — Regresión en el tab de Gastos**: al copiar el patrón, hay tentación de refactorizar helpers compartidos. NO hacerlo en este sprint — mantener los dos tabs separados para reducir blast radius. Refactor común queda para un sprint de limpieza aparte.

## Estrategia de pruebas

- **Data layer**: 8+ tests unitarios del servicio (empty, sin categoría, con categoría archivada, categoría expense con income asociado, orden, tiebreak, percent, reactividad).
- **Filtros**: 2+ tests del factory `forIncomeBucket` verificando que arma `kinds: ['income']`, `datePreset: custom`, `categoryIds` correctos, incluyendo el token "sin categoría".
- **Widget**: 4+ tests (empty state, con datos, cambio de rango dispara re-stream, drill-down navega a `/entries` con filtro correcto).
- **Regresión**: los 7 reportes existentes + reports_test.dart siguen verdes. El onboarding con 8 filas sigue centrado.

## Estrategia de rollback

- Sprint aditivo puro. Revertir el commit deja el estado previo intacto.
- APK previo `0.14.4+76` sigue disponible en `build/app/outputs/flutter-apk/` si no se sobrescribió y en `git log` del branch main.
- Sin datos migrados: `incomeByCategory` es solo lectura, no modifica BD.
- Backup exportado con la app 0.15.0+77 es idéntico al de 0.14.4+76 — sin campo nuevo.

## Orden sugerido de implementacion

1. **Modelos + servicio (`reports.dart`)** — `IncomeReport` + `IncomeBucket` + `incomeByCategory`. Tests UT.
2. **Factory de filtros (`entries_filters.dart`)** — `forIncomeBucket`. Tests UT.
3. **Widget (`income_by_category_tab.dart`)** — copiar el patrón de `spending_by_category_tab.dart` y ajustar (label, color, empty state, deep link).
4. **Integración tab (`reports_screen.dart`)** — 8vo tab.
5. **Onboarding + Help** — 8ª fila del slide 3 + bullet FAQ.
6. **Version bump + build APK + verify-apk.sh** — 0.15.0+77.
7. **Tests + analyze**.
8. **Smokes SM-01..07** en cel real de Diego.
9. **branch-quality-review** con slug `flutter-reports-income-by-category-v1`.

## Casos borde que condicionan la solucion

- **Filtro `applies_to != 'expense'` en JOIN, no en WHERE** — condiciona la forma del SQL. Si se equivoca la posición, se pierden incomes válidos.
- **Bucket "Sin categoría"** debe merge de: (a) incomes con `category_id NULL`, (b) incomes con categoría archivada, (c) incomes con categoría de `applies_to='expense'`. Los 3 casos deben mezclar en un solo bucket porque el `LEFT JOIN` deja `c.id` NULL en todos ellos.
- **Cambio de mes/año en modo custom**: el `dateRangeForPreset(custom, ...)` puede devolver `null` en algunos casos edge; usar `dateRangeForPreset` con `currentFrom/currentTo` para preservar el rango custom del usuario.
- **Empty state**: cuando `total = 0` no calcular percent para evitar división por cero. `isEmpty` deriva de `buckets.isEmpty`, no de `total == 0` directo — si hay un solo bucket con total 0 (edge, income cancelado que dejó el bucket vacío) el reporte debería marcarlo como empty.

## Preguntas o supuestos que siguen afectando la implementacion

- **S1**: el `LEFT JOIN` con `AND c.deleted_at IS NULL AND c.applies_to != 'expense'` es la posición correcta para agrupar los 3 casos de "Sin categoría" en un solo bucket. Documentado y verificable con test explícito.
- **S2**: reuso del deep link a `/entries` con el mismo mecanismo del tab de gastos. El listener acepta el filtro serializado sin distinguir origen.
- **S3**: el color `positive` (verde) del bar chart transmite semántica correcta. No hay conflicto con otros usos del color en la app.
- **S4**: sin refactor de helpers compartidos entre `spending_by_category_tab.dart` e `income_by_category_tab.dart` — diferido a un sprint de limpieza específico si aparece la necesidad.
- **S5**: `Icons.trending_up` es el icono correcto para el onboarding (contrasta con `pie_chart_outline` del tab de gastos).

Sin preguntas bloqueantes.
