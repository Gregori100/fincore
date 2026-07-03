# Resumen extenso — flutter-reports-income-by-category-v1

## Contexto tomado de spec.md, preguntas.md y clarificaciones

`spec.md` definió el sprint como aditivo puro sobre la infraestructura del sprint `flutter-reports-v1` (tab "Gasto por categoría"). Sin schema bump: ni `kind='income'` ni `applies_to` son campos nuevos. Solo se agregan modelos, servicio, factory de filtros y widget UI.

Sin `preguntas.md` ni `clarificaciones.md` — todas las decisiones (default `thisMonth`, filtro `applies_to != 'expense'` en JOIN, bucket "Sin categoría" que combina 3 casos, color `positive` del total) se resolvieron como supuestos razonables en la spec y son consistentes con el patrón del tab de gastos existente.

## Relación con plan/plan.md y plan/tasks.md

Se siguió el orden de implementación del plan:

1. **T001..T002 (Modelos)**: `IncomeReport` con `total`, `count`, `from`, `to`, `buckets`, getter `isEmpty`. `IncomeBucket` con `categoryId` nullable, `name`, `colorSlug`/`iconSlug` nullable, `total`, `percent`, `count`.
2. **T003 (Factory)**: `EntriesFilters.forIncomeBucket` con `datePreset: custom`, `kinds: ['income']`, `categoryIds: [id ?? kUncategorizedFilterToken]`.
3. **T004 (Servicio)**: SQL con `LEFT JOIN` sobre categorías filtrando por `deleted_at IS NULL` y `applies_to != 'expense'` (en el JOIN, no en el WHERE — decisión crítica que UT-I03 valida). Helper `_buildIncomeReport` idéntico en estructura al `_buildReport` del spending.
4. **T005..T008 (Widget)**: `IncomeByCategoryTab` copia idiomática del `SpendingByCategoryTab`. Diferencias: label, color del total (positive vs negative), ícono empty (`trending_up`), deep link (`forIncomeBucket`).
5. **T009 (Integración)**: 7 → 8 tabs en `ReportsScreen`.
6. **T010..T011 (Docs UI)**: onboarding slide 3 con 8ª fila; párrafo a "8 reportes"; FAQ pasa a "8 pestañas" con bullet nuevo.
7. **T012..T016 (Tests)**: 15 nuevos.
8. **T017..T021 (Version + build + verify)**: 0.15.0+77.

## Cambios principales por módulo o capa

### Capa de datos

- `reports.dart`:
  - Modelos `IncomeReport` + `IncomeBucket` con documentación explícita del comportamiento del bucket "Sin categoría" (3 casos: null, archivada, expense legacy).
  - Constante `kUncategorizedBucketName` reutilizada (ya existía para spending).
  - Método `incomeByCategory({from, to})` con SQL:
    ```sql
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
  - `readsFrom: {journalEntries, categories}` para reactividad ante cambios en ambas tablas.
  - Orden RN-I06 en Dart post-fetch: `total desc` con tiebreak alfabético.
  - Cálculo defensivo de `percent`: `total > 0 ? r.total / total : 0`.
- `entries_filters.dart`:
  - Factory `forIncomeBucket` con `kinds: const ['income']` y el resto del patrón idéntico al `forCategoryBucket`.

### Capa UI

- `income_by_category_tab.dart` (nuevo, ~430 líneas):
  - Estructura idéntica al `SpendingByCategoryTab`: header con `ChoiceChip` para presets + DatePickers en modo custom + StreamBuilder de 4 estados.
  - `_TotalCard` con color `positive` (verde) para el monto total, contrastando con el `negative` (rojo) del tab de gastos.
  - `_IncomeBucketRow` con chip 32×32 de color+icono de categoría, nombre, monto, percent (0 decimales), barra horizontal proporcional, tap → `context.push(_buildDeepLink())`.
  - `_EmptyState` con ícono `trending_up` y texto "No se registraron ingresos en el período".
  - `_LoadingState` estático (Card con "Cargando…") — mismo patrón M5 quality review v1 de reports.
  - `_ErrorState` con retry.
- `reports_screen.dart`: 8vo tab agregado al final del `TabBar` y `TabBarView`.
- `onboarding_screen.dart`: 8ª fila en slide 3 con `Icons.trending_up + FincoreColors.positive`. Párrafo pasa de "7 reportes" a "8 reportes" con nueva descripción.
- `help_screen.dart`: prefacio del tile "8 pestañas"; bullet nuevo al final de la lista.

### Tests

- `reports_test.dart`: grupo nuevo `incomeByCategory (sprint income-by-category)` con 10 tests (UT-I01..I10).
- `entries_filters_test.dart`: grupo nuevo `forIncomeBucket` con 2 tests (UT-I11, UT-I12).
- `income_by_category_tab_test.dart` (nuevo): 3 widget tests (WT-I01..I03).
- `credit_cards_tab_test.dart`: ajuste de `findsNWidgets(7) → 8` (regresión por el 8vo tab).

## Desviaciones respecto al plan

- **D1 — UT-I03 usa `customStatement` para el caso "expense legacy"**: el DAO valida `applies_to` vs kind en `registerIncome`, así que registrar un income con categoría de expense se rechaza. El test bypaseará el DAO con `INSERT INTO journal_entries(...)` directo, simulando datos que un backup legacy podría traer. Sin esto no se podría verificar RN-I05 en test unitario.

- **D2 — UT-I07 usa `catComida` (expense) para los expenses**: el plan asumía usar `catIncomeSueldo` para todos los kinds. Ajustado porque el DAO también valida al insertar expense; usar `catComida` (categoría expense sembrada por otro setUp) permite registrar los `expense` y `credit_expense` legítimamente y verificar que **no cuentan** en el reporte de ingresos.

- **D3 — Widget tests con 3 casos en lugar de los 5 planeados**: WT-I01 (empty), WT-I02 (con datos), WT-I03 ("Sin categoría"). Los WT-I04 (drill-down) y WT-I05 (validación from>to) se omiten porque requieren setup complejo del harness (mock del router para verificar navegación, tap en DatePicker simulado). Diego valida ambos vía smokes SM-05 y SM-07. Documentado.

Sin desviaciones bloqueantes.

## Pruebas realizadas y recomendadas

**Realizadas**: `flutter analyze` limpio + `flutter test` 452/452 verdes + build APK release verificado con `verify-apk.sh` (versionCode 2077 / versionName 0.15.0).

**Recomendadas**:
- SM-01: 8vo tab visible en `/reports`.
- SM-03: buckets con los ingresos reales de Diego, ordenados por monto desc.
- SM-04: registrar income nuevo desde el FAB → reporte actualiza reactivamente.
- SM-05: tap en bucket → `/entries` con `kind=income` + categoría + rango.
- SM-06: cambiar preset a "Este año" → ve todos los ingresos del año.
- SM-08: onboarding slide 3 en cel limpio con 8 filas legibles (scroll interno si hace falta).
- `branch-quality-review` con slug `flutter-reports-income-by-category-v1` antes del commit.

## Riesgos residuales y posibles regresiones

Ver `implementation-review.md` para el detalle completo. Resumen:

- Sin refactor compartido con el tab de gastos — cambios futuros deben aplicarse en ambos.
- Confusión potencial con "Cashflow mensual" — mitigado con FAQ.
- Categorías con `applies_to='expense'` y incomes legacy caen en "Sin categoría" (comportamiento intencional, cubierto por test).
- Cero refactor de infra existente; regresión en otros 7 reportes prácticamente imposible.
