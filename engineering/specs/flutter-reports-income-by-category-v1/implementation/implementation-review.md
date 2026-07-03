# Implementation Review: flutter-reports-income-by-category-v1

## Resumen de lo implementado

Octavo tab "Ingreso por categoría" en `/reports`, análogo al tab existente "Gasto por categoría". Agrupa la suma de `journal_entries.amount` con `kind='income'` por `category_id` dentro de un rango configurable (chips Este mes / Mes pasado / Año / Custom). Solo incluye categorías con `applies_to != 'expense'`. Drill-down por bucket abre `/entries` con filtros pre-cargados (`kinds: ['income']`, categoría del bucket, rango exacto). Sprint aditivo puro; sin schema bump.

## Archivos principales modificados

- `mobile/lib/data/reports.dart` — nuevos modelos `IncomeReport` + `IncomeBucket`, nuevo método `ReportsService.incomeByCategory` con helper `_buildIncomeReport`.
- `mobile/lib/data/entries_filters.dart` — nuevo factory `EntriesFilters.forIncomeBucket`.
- `mobile/lib/screens/reports/income_by_category_tab.dart` (nuevo) — copia idiomática de `SpendingByCategoryTab` con: label del tab, color positive del total, ícono `trending_up` en empty, deep link con `forIncomeBucket`.
- `mobile/lib/screens/reports_screen.dart` — 7 → 8 tabs.
- `mobile/lib/screens/onboarding_screen.dart` — 8ª fila en slide 3 + párrafo actualizado.
- `mobile/lib/screens/help_screen.dart` — FAQ "8 pestañas" + bullet nuevo.
- `mobile/pubspec.yaml` + `mobile/android/app/build.gradle.kts` — 0.15.0+77.

Tests nuevos:
- `mobile/test/data/reports_test.dart` — grupo nuevo `incomeByCategory (sprint income-by-category)` con UT-I01..I10 (10 tests).
- `mobile/test/data/entries_filters_test.dart` — grupo nuevo `forIncomeBucket` con UT-I11 y UT-I12 (2 tests).
- `mobile/test/screens/reports/income_by_category_tab_test.dart` (nuevo) — WT-I01..I03 (3 tests).

Ajuste de regresión:
- `mobile/test/screens/reports/credit_cards_tab_test.dart` — WT-15 conteo de tabs de 7 → 8.

## Tareas completadas

- T001..T004 (Backend): modelos, factory, servicio con SQL y `_buildIncomeReport`.
- T005..T008 (Frontend widget): tab completo con header de chips, DatePickers custom, StreamBuilder de 4 estados, `_IncomeBucketRow` con bar chart + drill-down.
- T009 (Integración): octavo tab en `ReportsScreen`.
- T010..T011 (Docs UI): onboarding + FAQ.
- T012..T016 (Pruebas): 15 tests nuevos, ajuste de regresión, `flutter test` 452/452 verdes.
- T017..T021 (Version + validación): version bump, analyze limpio, APK release + verify OK.

## Tareas pendientes

- **T022 (smokes SM-01..09 con Diego)**: pendientes de ejecución en cel real.
- **T023 (`branch-quality-review`)**: pendiente de invocar antes del commit final.
- **T024 (commit final)**: pendiente.

## Riesgos residuales

- **R2 del plan — Filtro `applies_to != 'expense'` en JOIN vs WHERE**: implementado en el JOIN (correcto). UT-I03 blindaje con `customStatement` que fuerza el edge legacy y verifica que el income cae en "Sin categoría".
- **R1 — Confusión con Cashflow**: mitigado con FAQ actualizado. Diego valida en smoke SM-01.
- **R3 — División por cero en percent**: cubierto por `total > 0 ? r.total / total : 0`. Test defensivo indirecto vía UT-I01 (empty).
- **R7 — Sin refactor compartido con spending_by_category_tab**: intencional. Los 2 archivos son casi idénticos; refactor común queda para sprint de limpieza. Mientras tanto, cambios se deben aplicar en ambos si tocan lógica compartida.

## Pruebas realizadas

- `flutter analyze` → 4 hints info pre-existentes tolerados.
- `flutter test` → **452/452 verdes** (437 baseline + 15 nuevos del sprint).
- Build APK release `--split-per-abi` OK; `verify-apk.sh` OK con versionCode 2077 / versionName 0.15.0.
- Servicio cubre: empty, sin categoría (3 casos mergedos), applies_to='both' incluida, orden por total desc, tiebreak alfabético, percent, reactividad, kinds excluidos, rango con exclusión.
- Factory `forIncomeBucket`: con id → `kinds=['income']`, `datePreset=custom`, `categoryIds` correcto; con null → token de "sin categoría".
- Widget: empty state, con datos (Total + 2 buckets), "Sin categoría" cuando `category_id` es null.

## Pruebas recomendadas

- **SM-01..09** en cel real. Especialmente:
  - SM-01: 8vo tab visible.
  - SM-03: buckets con montos correctos según los ingresos reales de Diego.
  - SM-05: tap en bucket navega a `/entries` con filtros pre-cargados (verificable comparando movimientos listados con el bucket).
- **UT-I04 con `applies_to='both'`**: cubierto por UT-I04 con `catBothMisc` (categoría creada con `both`).
- **Drill-down en widget test**: cobertura básica implícita en el patrón; un test que verifica navegación específica al `/entries` con filtro correcto sería útil pero requiere setup complejo del harness. Diego valida vía SM-05.

## Posibles regresiones

- **Tab de gastos**: se copió el patrón sin refactorizar helpers compartidos. Cero riesgo de regresión en `spendingByCategory`.
- **Otros 6 reportes**: intocados; tests existentes de reports_test.dart pasan.
- **Onboarding**: la 8ª fila del slide 3 acomoda dentro del `SingleChildScrollView + LayoutBuilder + ConstrainedBox + IntrinsicHeight` del sprint budgets. Tests WT-O01..O06 siguen verdes.
- **HelpScreen**: el tile "¿Cómo se calculan los reportes?" pasa a "8 pestañas" con un bullet nuevo. WT-H01..H04 siguen verdes.
- **ReportsScreen tests**: el WT-15 del sprint credit-cards fue actualizado de 7 → 8 tabs.

## Recomendaciones para code review humano

1. Verificar que el filtro `applies_to != 'expense'` está en la posición correcta del SQL (dentro del `ON` del LEFT JOIN, línea después de `AND c.deleted_at IS NULL`). El test UT-I03 valida el comportamiento indirectamente.
2. Confirmar que el color `positive` (verde) del `_TotalCard` no genera confusión visual con el tab de gastos (`negative`, rojo). El contraste es intencional para diferenciar semánticamente.
3. El `_IncomeBucketRow` usa el color de la categoría (colorBySlug) para la barra, no `positive`. Consistente con el tab de gastos que también usa el color de la categoría en su barra. Se puede iterar en un patch UX futuro si Diego lo prefiere.
4. Ejecutar `branch-quality-review` con slug `flutter-reports-income-by-category-v1` antes del commit final.
