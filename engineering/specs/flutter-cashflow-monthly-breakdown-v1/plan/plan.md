# Plan técnico — flutter-cashflow-monthly-breakdown-v1

## Enfoque tecnico

Feature 100% aditiva sobre el tab `Cashflow mensual` existente. Ninguna
migración de schema. 5 puntos de cambio ortogonales:

1. **Servicio** (`mobile/lib/data/reports.dart`):
   - Nuevo método `ReportsService.cashflowMonthBreakdown({DateTime
     monthAnchor})` que retorna `Stream<MonthBreakdown>`.
   - SQL con `strftime('%Y-%m', occurred_at, 'localtime') = ?` (patrón
     del calendar/heatmap para timezone-safe).
   - `LEFT JOIN categories c ON c.id = j.category_id AND c.deleted_at
     IS NULL` — categorías archivadas caen al bucket "Sin categoría".
   - Filtro `kind IN ('income', 'expense', 'credit_expense')` +
     `j.deleted_at IS NULL`.
   - `readsFrom: {journalEntries, categories}` para que rename/archive
     de categoría dispare re-emit.
   - Helper Dart `_buildMonthBreakdown` que:
     - Separa rows por kind (income vs expense/credit_expense).
     - Aplica la simetría RN-CB03/CB04: en el bucket de gastos,
       categorías con `applies_to='income'` caen a "Sin categoría";
       simétrico en ingresos.
     - Calcula `percent = amount / totalDelLado × 100`.
     - Ordena descendente por `amount`.

2. **Modelos** (`mobile/lib/data/reports.dart`, al final del archivo
   junto con los otros modelos del cashflow):
   - `MonthBreakdown` (const-inmutable): `firstDay`, `totalIncome`,
     `totalExpense`, `net`, `incomeBuckets`, `expenseBuckets`.
   - `CategoryFlow` (const-inmutable): `categoryId?`, `label`,
     `colorSlug?`, `iconSlug?`, `amount`, `percent`.

3. **Filtros** (`mobile/lib/data/entries_filters.dart`):
   - Nuevo factory `EntriesFilters.forMonth({DateTime firstDay})` que
     construye `[firstDay 00:00, DateTime(y, m+1, 0, 23, 59, 59, 999)]`
     (último día del mes con subsegundo, consistente con `forDay`).

4. **Widget del tab** (`mobile/lib/screens/reports/cashflow_tab.dart`):
   - `_BreakdownRow` deja de ser `Padding` puro y se envuelve con
     `InkWell` con `borderRadius` para affordance visual.
   - `onTap`: `showModalBottomSheet<void>(context: context,
     isScrollControlled: true, backgroundColor: FincoreColors.surface,
     builder: (_) => _MonthBreakdownSheet(monthAnchor: month.firstDay))`.
   - Nueva clase `_MonthBreakdownSheet` (StatefulWidget) que:
     - Cachea el Stream una sola vez en `didChangeDependencies`
       (patrón del cashflow tab / heatmaps).
     - StreamBuilder con loading / error / data / empty states.
     - Layout: DraggableScrollableSheet o `Padding` con `SafeArea` +
       `SingleChildScrollView` (evaluar; el patrón heatmap usa el 2do).
     - Encabezado: mes formateado (`DateFormat('MMMM y', 'es_MX')`
       capitalizado) + Row con Ingresos/Gastos + Neto.
     - Sección "Ingresos por categoría" (oculta si vacía) —
       `_CategoryFlowRow` por cada bucket.
     - Sección "Gastos por categoría" idem.
     - Fallback "Sin movimientos en este mes." si ambos vacíos.
     - Botón "Ver movimientos →" al final que hace:
       ```dart
       final navigator = Navigator.of(context);
       final router = GoRouter.of(context);
       await navigator.maybePop();
       if (!mounted) return;
       router.push('/entries',
         extra: EntriesFilters.forMonth(firstDay: monthAnchor));
       ```
   - `_CategoryFlowRow`: fila con `CategoryBadge` (o "Sin categoría"
     variant) + label + `formatAmount(amount)` + percent 1 decimal.

5. **FAQ** (`mobile/lib/screens/help_screen.dart`): un bullet extra
   dentro del tema "¿Cómo se calculan los reportes?" mencionando el
   drill-down mensual del cashflow.

Bump `0.16.5+87` → `0.17.0+88`.

## Requisitos funcionales cubiertos

- **RF-001** (nuevo método servicio): T002 + T003.
- **RF-002** (modelos `MonthBreakdown` y `CategoryFlow`): T004.
- **RF-003** (filtro strftime localtime): T002.
- **RF-004** (LEFT JOIN categories deleted_at IS NULL): T002.
- **RF-005** (kinds y deleted_at journal): T002.
- **RF-006** (separar buckets por kind en Dart): T003.
- **RF-007** (readsFrom con categories): T002.
- **RF-008** (simetría applies_to): T003.
- **RF-009** (percent): T003.
- **RF-010** (orden desc por amount): T003.
- **RF-011** (onTap fila mes + showModalBottomSheet): T007.
- **RF-012** (`_MonthBreakdownSheet` con StreamBuilder + estados): T008.
- **RF-013** (botón "Ver movimientos" con pop + push): T009.
- **RF-014** (`EntriesFilters.forMonth`): T005.
- **RF-015** (FAQ Help): T010.
- **RF-016** (12-15 tests nuevos): T011-T014.
- **RF-017** (bump 0.17.0+88): T015.

## Archivos o modulos probablemente afectados

Confirmados por inspección:

- `mobile/lib/data/reports.dart` — nuevo método + modelos.
- `mobile/lib/data/entries_filters.dart` — nuevo factory `forMonth`.
- `mobile/lib/screens/reports/cashflow_tab.dart` — onTap +
  `_MonthBreakdownSheet` + `_CategoryFlowRow`.
- `mobile/lib/widgets/category_badge.dart` — reusar como está
  (soporta `Category?` con fallback "Sin categoría"). Confirmado.
- `mobile/lib/screens/help_screen.dart` — bullet FAQ.
- `mobile/pubspec.yaml` + `mobile/android/app/build.gradle.kts` —
  bump.

Tests:

- `mobile/test/data/reports_test.dart` — grupo nuevo
  `cashflowMonthBreakdown` con UT-CB01..12.
- `mobile/test/screens/cashflow_tab_test.dart` — extender con
  WT-CB01..04 (tap abre sheet, sheet muestra buckets, botón "Ver
  movimientos" navega, sheet vacío).
- `mobile/test/data/entries_filters_test.dart` (si existe;
  confirmar en T001) — UT del factory `forMonth`. Si no hay archivo
  específico, inline en un test existente que ya use `EntriesFilters`.

Sin cambios en:

- Schema, migraciones, DAOs.
- `FinancialStateService`, `BackupService`.
- Router, otros tabs del reporte.

## Entidades y estados afectados

- `MonthBreakdown` (nuevo modelo de memoria):
  - `firstDay: DateTime` — primer día del mes en local.
  - `totalIncome`, `totalExpense`, `net: double`.
  - `incomeBuckets: List<CategoryFlow>` — puede estar vacía.
  - `expenseBuckets: List<CategoryFlow>` — puede estar vacía.
  - Const-inmutable, sin efectos secundarios.
- `CategoryFlow` (nuevo modelo de memoria):
  - `categoryId: String?` — null solo para "Sin categoría".
  - `label: String`, `colorSlug: String?`, `iconSlug: String?`,
    `amount: double`, `percent: double`.
  - Invariante: `percent ∈ [0, 100]`.
- `EntriesFilters`:
  - Nuevo factory `forMonth` — no altera el modelo existente, solo
    agrega una construcción canónica.
- Sin cambios en `Account`, `Category`, `JournalEntry`.

## Compatibilidad con datos y procesos existentes

- **Datos históricos**: sin cambio. La query es de solo lectura.
- **Backup JSON**: sin cambio. Ningún campo nuevo en el schema.
- **Cashflow base (`cashflowByMonth`)**: sin cambio. Los tests
  existentes deben seguir verdes.
- **Otros reportes**: sin cambio. El nuevo método solo se llama
  desde el sheet nuevo.
- **`/entries` filter**: nuevo `EntriesFilters.forMonth` es aditivo.
  Otros factories existentes (`thisMonth`, `forDay`,
  `forCategoryBucket`) no cambian.
- **Regresión visual del tab**: el tap en la fila de mes ahora tiene
  affordance (`InkWell` + `borderRadius`). El resto del tab (header,
  chart, breakdown numérico) es idéntico.
- **Convención "Sin categoría"**: replica exactamente la semántica
  del `drilldown-parity` del proyecto (aplica el filtro simétrico
  `applies_to`) — consistente con `spending_by_category` /
  `income_by_category`.

## Cambios de datos si aplica

No aplica.

## Cambios de API si aplica

No aplica (app local-first sin red).

## Cambios de integraciones si aplica

No aplica.

## Cambios de UI si aplica

- Fila de mes ahora tap-able con affordance visual (`InkWell`).
- Nuevo bottom sheet con encabezado + 2 secciones + botón drill-down.
- Sin cambios en Dashboard, `/entries`, otros tabs.
- FAQ Help gana un bullet nuevo (no cambia el conteo de tiles).

## Cambios de permisos si aplica

No aplica. Single-user.

## Riesgos tecnicos

- **R1 — Reactividad por rename de categoría**: `readsFrom:
  {journalEntries, categories}` provoca re-emit cuando cambia
  cualquier categoría (aunque no esté en el mes visible). Aceptable —
  patrón heredado de `spending_by_category`. Overhead negligible en
  single-user.
- **R2 — Percent con `totalIncome`/`totalExpense` = 0**: solo puede
  pasar si un bucket tiene `amount = 0` (imposible en flujo normal
  por RN-CB02). Mitigación: guard `total > 0 ? amount/total*100 :
  0.0` en el helper.
- **R3 — Navegación `pop + push`**: `context` puede desmontarse
  entre pop y push. Mitigación: capturar `Navigator.of(context)` y
  `GoRouter.of(context)` antes del await; chequear `mounted` después.
- **R4 — Scroll interno del sheet**: si hay 30+ categorías + textos
  largos, el sheet puede overflow. Mitigación: `isScrollControlled:
  true` + `SingleChildScrollView` con altura contenida por padding
  externo (patrón validado en heatmaps).
- **R5 — Timezone edge**: `'localtime'` está probado en calendar y
  heatmap. Aceptable. Coherente con la agrupación mensual del
  cashflow base (que usa `strftime('%Y-%m', occurred_at)` sin
  `localtime`; ver R6).
- **R6 — Divergencia con `cashflowByMonth`**: el cashflow base agrupa
  por `strftime('%Y-%m', occurred_at)` (UTC). El nuevo breakdown
  usará `'localtime'`. Un movimiento borderline (23:30 UTC del último
  día del mes que localmente es del mes siguiente) puede aparecer en
  distintos meses entre el agregado del tab base y el sheet
  detallado. Mitigación: aceptar la divergencia por consistencia con
  calendar/heatmap; documentar en la spec e implementación review.
  Alternativa: bumpear el cashflow base a `'localtime'` en un sprint
  aparte para uniformar.
- **R7 — `Divider` entre filas rompe el `InkWell` splash**: el
  `_CashflowBreakdown` renderea `Divider(height: 1)` entre filas.
  El InkWell del `_BreakdownRow` debe quedar dentro del row para
  que el splash respete su área, no atravesar el divider.
- **R8 — CategoryBadge con Category legacy**: `CategoryBadge` acepta
  `Category?` (drift-generated). Como el servicio no expone objetos
  `Category` completos sino `CategoryFlow`, el widget del sheet debe
  construir un `Category` sintético o usar `_Chip` directamente. Voto
  por `_Chip` directo con `colorBySlug`/`iconBySlug` (funciones puras
  del catálogo).

## Estrategia de pruebas

Ver `test-plan.md`. Foco:

- **UT servicio** (10-12 tests): validar cálculo, orden, "Sin
  categoría" simétrica (`applies_to`), reactividad, timezone.
- **UT filtro** (2 tests): `EntriesFilters.forMonth` rango correcto
  (inicio y fin con subsegundo).
- **Widget tests** (3-4 tests): tap en fila abre sheet, sheet muestra
  ambas secciones, botón "Ver movimientos" navega, sheet vacío.
- **Smokes SM-01..07** con Diego en cel real.

## Estrategia de rollback

Feature 100% aditiva. Un `git revert` del commit final elimina la
funcionalidad sin efectos residuales:

- Zero cambio de schema.
- Zero cambio de datos.
- Modelo `MonthBreakdown` y `CategoryFlow` no persistidos.
- `EntriesFilters.forMonth` no usado por nadie más.

Si aparece un bug bloqueante post-deploy, sprint patch `0.17.1+89`
con fix específico. Sin necesidad de "downgrade path".

## Orden sugerido de implementacion

1. **T001**: leer código actual detallado de `reports.dart` (patrones
   de `cashflowByMonth`, `spendingByCategory`, `_buildCashflowReport`);
   `entries_filters.dart` (patrón de `forDay`); `cashflow_tab.dart`
   (`_BreakdownRow`); `spending_heatmap_tab.dart` (patrón de sheet
   modal).
2. **T002-T003** (servicio + modelos): query + helper +
   `MonthBreakdown` + `CategoryFlow`.
3. **T004** (test-friendliness): confirmar que el helper es unit
   testable pasando rows mockeados (opcional; podemos ir directo a
   integration test con BD in-memory).
4. **T005** (`EntriesFilters.forMonth`): factory + UT-CB13.
5. **T006** (opcional; solo si el helper del servicio quiere unit
   test aislado): extraer y testear. Sino, testear vía UT-CB01..12
   integration con BD.
6. **T007** (onTap + `showModalBottomSheet`).
7. **T008** (`_MonthBreakdownSheet` con StreamBuilder + secciones +
   estados).
8. **T009** (botón "Ver movimientos" con pop+push).
9. **T010** (FAQ Help).
10. **T011** (UT-CB01..12 del servicio).
11. **T012** (UT-CB13 del `forMonth`).
12. **T013** (WT-CB01..04 del widget).
13. **T014** (suite completa verde).
14. **T015** (bump + APK + verify).
15. **T016** (smokes SM-01..07 con Diego).
16. **T017** (`branch-quality-review`).
17. **T018** (commit final).

## Casos borde que condicionan la solucion

Ver `test-plan.md` para el listado completo (CB-01..CB17 de la spec
+ CB-P01..CB-P05 nuevos del plan que agrego abajo).

Casos borde nuevos que el plan identifica y que no están en la
spec:

- **CB-P01**: `applies_to='both'` — categorías bidireccionales aceptan
  income y expense. NO caen a "Sin categoría" en ningún caso; se
  cuentan en el bucket que corresponde al kind del movimiento.
  Documentado.
- **CB-P02**: Movimiento del mes con `category_id` no existente
  (backup import de un JSON con FK huérfana). El `LEFT JOIN` devuelve
  category null → cae a "Sin categoría". Correcto.
- **CB-P03**: Amount = 0 (edge legacy). El bucket entra con
  `amount=0` y `percent=0`. Mitigación en el helper: filtrar buckets
  con `amount == 0` antes de agregar a la lista, por elegancia visual
  y evitar división 0/0 en percent.
- **CB-P04**: Amount negativo (imposible en el schema pero defensivo).
  Filtrar en el helper igual que CB-P03.
- **CB-P05**: 2 movimientos misma categoría en el mismo mes con
  distintos kinds (uno income + uno expense) para una categoría con
  `applies_to='both'`. La categoría aparece 2 veces, una en cada
  sección con su respectivo amount. Correcto (RN-CB01 agrupa por
  category_id + kind).

## Preguntas o supuestos que siguen afectando la implementacion

Sin preguntas bloqueantes.

Supuestos operativos que se mantienen desde la spec + refuerzos:

- El `monthAnchor` que recibe el servicio es `DateTime(y, m, 1)` en
  local. El servicio formatea a `YYYY-MM` con `.year`/`.month` sin
  padding manual — sí padding manual porque `month` < 10 sin
  `padLeft` sale como `2026-6`.
- El widget del sheet construye un `_Chip` directamente en vez de
  usar `CategoryBadge` (que espera un objeto `Category` completo).
  Aceptable porque el catálogo (`colorBySlug`, `iconBySlug`) es
  puro.
- El navegador del drill-down usa `context.push('/entries', extra:
  EntriesFilters.forMonth(...))`. La pantalla `/entries` debe aceptar
  `EntriesFilters` en `extra` — confirmado en el patrón del calendar.
- IVA del cashflow: N/A. Este sprint no toca cálculos monetarios.
- El sheet permanece abierto hasta que el usuario lo cierra. No hay
  autoclose por cambio de rango en el tab base (CB-17 de la spec).
