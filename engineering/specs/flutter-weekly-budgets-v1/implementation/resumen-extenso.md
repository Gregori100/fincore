# Resumen extenso — flutter-weekly-budgets-v1

## Contexto

FinCore es una app Flutter Android local-first single-user de
finanzas personales. Ya existían dos flujos relacionados:

- Ledger de movimientos reales (`journal_entries`) — retrospectivo.
- Reporte "Presupuestos" mensual por categoría (`monthly_limit` en
  categorías) — mide gasto vs límite.

Diego pidió un **planeador anticipado** distinto: antes de recibir
plata, listar ingresos esperados y gastos previstos para una
semana concreta y ver cuánto sobra. Motivación real: le pagan cada
viernes; quiere planificar los $6500 desde antes en lugar de
hacer mental math cuando llega el momento.

Decisiones tomadas con Diego durante `spec-definir` y
`spec-clarificar`:

1. **Línea del presupuesto** = nombre libre + categoría opcional +
   monto. **Sin cuenta** (planeación libre, no ledger).
2. **Día de inicio de semana** configurable en Settings (default
   viernes). Solo sugerido del picker — no forzado.
3. **Multi-plan por semana**: se permiten varios presupuestos por
   la misma `week_start_date` para comparar escenarios.
4. **Label obligatorio** para diferenciar planes de la misma
   semana.
5. **Renglón** (no "línea") como nombre canónico del elemento del
   presupuesto.
6. **Drag & drop con handle visual** (⋮⋮) — no reorder desde row.
7. **Plantillas de presupuesto** como entidad nueva. Se **crean
   derivadas de un presupuesto existente** ("Crear plantilla desde
   este presupuesto"). Se aplican al armar un presupuesto nuevo.
   Snapshot copiado (no comparten referencia).
8. **Hard delete** con confirmación destructiva. Sin papelera.
9. **P-003 laxa**: categoría opcional en renglón sin enforce por
   `applies_to`.
10. **P-001 NO al backup**: los presupuestos y plantillas no se
    incluyen en el backup JSON — se pierden en restore. Aceptado
    como trade-off.
11. **P-006 NO card en Dashboard**: entrada solo por IconButton
    del AppBar.

## Relación con `plan/plan.md` y `plan/tasks.md`

Se ejecutaron **T001-T039 completas** en el orden del plan.
**T038 (smokes) y T041 (commit)** pendientes hasta que Diego
esté disponible.

RF cubiertos: RF-001..RF-022 de la spec. Todas las RN-B01..RN-B18
implementadas y verificadas con UT + WT + tests de regresión de
backup y migración.

## Cambios principales por módulo o capa

### Base de datos (`database.dart` schema v6 → v7)

4 tablas nuevas:

- **`weekly_budgets`**: `id` (uuid v7), `week_start_date`
  (DateTime normalizado a medianoche local), `label` (obligatorio),
  timestamps. Sin `deleted_at`.
- **`weekly_budget_items`**: `id`, `budget_id`, `name`,
  `category_id` (nullable), `amount`, `kind`, `sort_order`,
  timestamps.
- **`budget_templates`**: `id`, `name` (único case-insensitive),
  timestamps.
- **`budget_template_items`**: análogo al item de budget con
  `template_id` en vez de `budget_id`.

Migración aditiva v6→v7 con `CREATE TABLE IF NOT EXISTS`
(idempotente ante crash a mitad del upgrade — fix A1 del quality
review) + 3 índices `IF NOT EXISTS` + guardrail
`UnimplementedError` preservado. `onCreate` de BD virgen también
agrega los índices.

### Data layer (DAOs + helpers)

- **`WeeklyBudgetsDao`** (`mobile/lib/data/daos/weekly_budgets_dao.dart`):
  - CRUD del budget con validaciones tipadas
    (`invalid_budget_label`, `immutable_field`, `not_found`).
  - CRUD de items (`addItem`, `updateItem` con `clearCategory`,
    `deleteItem`, `reorderItems` transaccional).
  - `watchBudgetItems` (ordenado por sort_order ASC).
  - `watchBudgetBalance` reactivo con `readsFrom` y SQL agregado
    `Σincome - Σexpense`.
  - `createBudgetFromTemplate` — snapshot inverso (nuevos ids).
- **`BudgetTemplatesDao`** (`mobile/lib/data/daos/budget_templates_dao.dart`):
  - CRUD del template (unicidad case-insensitive en Dart, no SQL,
    para funcionar con acentos — fix A2).
  - CRUD de items análogo al del budget.
  - `createTemplateFromBudget` — snapshot desde budget.
- **`AppPreferencesDao`** ganó helpers `weekStartDow()`
  (default 5, robusto ante corrupción) y `setWeekStartDow(int)`.
- **`BackupService.wipeAll`** extendido para borrar las 4 tablas
  nuevas en orden FK-safe.
- **Helpers puros** (`mobile/lib/data/weekly_budgets.dart`):
  `suggestedWeekStartDate`, `weekRangeOf`, `groupBudgetsByRange`,
  `calculateBalance`, `WeekRange` class local, `BudgetSection` enum.

### Presentación

**4 pantallas** en `mobile/lib/screens/weekly_budgets/`:

- **`WeeklyBudgetsListScreen`**: agrupa presupuestos por sección
  ("Esta semana", "Próximas", "Pasadas"). FAB dual: "En blanco"
  o "Desde plantilla" (deshabilitada si no hay plantillas). Card
  por budget con label, rango, balance reactivo, contador de
  renglones. Empty state con CTA. Banner nuevo arriba de la lista
  informando "no se incluye en el respaldo" (fix M4).
- **`WeeklyBudgetScreen`** (detalle presupuesto): AppBar con label
  editable inline (tap → dialog) + rango fijo. Menú con "Crear
  plantilla desde este presupuesto" y "Eliminar presupuesto"
  (destructivo). Body con `_ItemsSection` income + expense
  drag&drop. Footer sticky con `_BalanceFooter` reactivo. AppBar
  minimal durante loading (fix M3).
- **`BudgetTemplatesScreen`**: listado de plantillas con preview
  (primeros 3 items + balance). Sin FAB (plantillas se crean
  desde budgets).
- **`BudgetTemplateDetailScreen`**: análogo al detalle de budget
  pero sin fecha. Menú "Eliminar plantilla" con confirmación
  destructiva que aclara "los presupuestos derivados NO se ven
  afectados". Delete de renglón ahora incluye nombre en el copy
  (fix M5).

**4 widgets base** en `mobile/lib/screens/weekly_budgets/widgets/`:

- **`BudgetKindPicker`**: `SegmentedButton<String>` con 2 opciones
  (Ingreso / Gasto).
- **`BudgetItemFormSheet`**: bottom sheet reutilizable para
  crear/editar renglones. Valida antes del submit, deshabilita
  botón durante el submit, error snackbar sin cerrar.
- **`ItemsSection`**: `ReorderableListView` con
  `buildDefaultDragHandles: false` +
  `ReorderableDragStartListener` envolviendo solo el handle. El
  handle usa `GestureDetector(behavior: HitTestBehavior.opaque)`
  para forzar hit area 44×44 real (fix A4). Tap en row abre edit
  del renglón; NO reordena. Empty state con CTA.
- **`BalanceFooter`**: `StreamBuilder<double>` reactivo con
  "Sobra $X" verde / "Faltan $Y" rojo / "En equilibrio" gris /
  skeleton durante loading.

**Router**: 4 rutas nuevas en `app_router.dart` (`/budgets`,
`/budgets/:id`, `/budget-templates`, `/budget-templates/:id`).

**Integraciones**:

- **Dashboard AppBar**: IconButton nuevo "Presupuestos semanales"
  + reorganización: "Categorías" pasó a `PopupMenuButton` con
  icono `more_vert` para no partir el wordmark FinCore en cel de
  360dp (fix A5).
- **Settings**: sección nueva "Preferencias" entre "Respaldo" y
  "Zona peligrosa" con `DropdownButton<int>` (1..7 = Lunes..
  Domingo, default viernes). Cambio persiste vía
  `AppPreferencesDao`.
- **HelpScreen**: FAQ nueva "¿Qué diferencia hay entre
  'Presupuestos' del reporte y 'Presupuestos semanales'?" con
  advertencia sobre el backup.

### Tests

~62 tests nuevos + 5 tests preexistentes de Settings actualizados.

Tests por categoría:
- Helpers puros: `weekly_budgets_helpers_test.dart` — UT-H01..H09.
- `WeeklyBudgetsDao`: `weekly_budgets_dao_test.dart` — UT-WB01..25
  + 2 extras `not_found`.
- `BudgetTemplatesDao`: `budget_templates_dao_test.dart` —
  UT-BT01..08.
- `AppPreferencesDao` extendido: UT-AP01..05.
- Widget list_screen: WT-LS01..05.
- Widget detail_screen: WT-DS01..11.
- Widget templates_screen: WT-TS01..04 (TS04 skipped documentado
  por hang de stream subscription en `close()`).
- Widget UX cross: WT-SET01/02, WT-DASH01, WT-HELP01.
- Backup regression: RG-01..04.
- Migración: MG-01..04.

## Desviaciones respecto al plan

- **D1 — `week_start_dow` como sugerido, no forzado** (P-009):
  spec original decía "restricción dura". Diego pivoteó a
  "sugerido inicial del picker" con RN-B02.
- **D2 — Multi-plan por semana** (P-004): plan inicial decía "1
  por semana". Diego pivoteó a "múltiples con label
  obligatorio". RN-B04 se revocó, se agregó RN-B14 (label
  obligatorio).
- **D3 — Plantillas de presupuesto como entidad nueva** (P-008):
  plan inicial era un método simple `duplicateBudget`. Diego
  pivoteó a plantillas de primera clase: se crean derivadas de
  un budget existente, se aplican al armar uno nuevo, editables.
  2 tablas + DAO + 2 pantallas nuevas.
- **D4 — Hard delete en vez de soft delete** (T008 confirmó):
  spec original tenía `deleted_at` en las 4 tablas. Diego
  pivoteó a hard delete con confirmación destructiva. Sin
  papelera ni undo.
- **D5 — Backup NO incluye los presupuestos** (P-001): spec
  original consideraba bumpear el backup a v2 con las tablas
  nuevas. Diego pivoteó a NO. Se mantiene backup v1. Banner
  agregado en list_screen para comunicar el trade-off (fix M4).
- **D6 — Reorganización del Dashboard AppBar** (fix A5 del
  quality review): "Categorías" movida a PopupMenu para no
  partir el wordmark en 360dp. Diego debería confirmarlo.
- **D7 — Test WT-TS04 skipped**: documentado en el archivo por
  hang de `close()` con stream subscription pendiente en
  `_confirmDeleteTemplate`. Cubierto por smoke SM-12 manual.

## Pruebas realizadas y recomendadas

### Realizadas

- `flutter analyze` limpio (4 hints info preexistentes).
- `flutter test` 671 verdes (1 skip WT-TS04).
- APK release + `verify-apk.sh` OK con versionCode 2094 /
  versionName 0.20.0.
- Branch quality-review ejecutado (21 hallazgos, 10 resueltos, 0
  bloqueantes).

### Recomendadas

Smokes SM-01..SM-16 con Diego en cel real. Especialmente:

- **SM-04** (drag handle en dispositivo real con dedo grueso: fix
  A4 crítico).
- **SM-06** (multi-plan por semana: verificar UX).
- **SM-07/08** (crear plantilla + aplicarla).
- **SM-09/10** (snapshot semantics manual: editar plantilla no
  toca budget derivado y viceversa).
- **SM-11/12** (eliminar budget/plantilla con dialog destructivo).
- **SM-13** (cambiar `week_start_dow` no afecta existentes).
- **SM-14** (backup + wipeAll pierde budgets — esperado).
- **SM-16** (cel angosto ≤360dp: dashboard wordmark en una línea
  con PopupMenu — fix A5 crítico).

## Riesgos residuales y posibles regresiones

Ver `implementation-review.md` sección "Riesgos residuales" para
lista completa. Highlights:

- Pérdida de budgets en restore es una decisión consciente pero
  Diego debe estar cómodo con ello.
- Reorganización del Dashboard AppBar (Categorías al PopupMenu)
  puede sorprender a Diego en el primer contacto.
- Fix A4 (drag handle) es un cambio de comportamiento que solo se
  verifica en cel real; smoke SM-04 obligatorio.

Cero regresión funcional en:
- `EntriesDao`, `AccountsDao`, `CategoriesDao`,
  `FinancialStateService`, `ReportsService`, `SavedViewsDao`.
- Reportes existentes (cashflow, spending heatmap, income heatmap,
  calendar, credit cards, monthly average, categories, drilldown).
- Backup export/import (v1 sigue funcionando idénticamente).
- Onboarding, first-run, help screen (excepto la FAQ nueva
  agregada).

Sprint completo excepto **smokes en cel real (T038)** y **commit
final (T041)**. Ambos requieren la presencia de Diego.
