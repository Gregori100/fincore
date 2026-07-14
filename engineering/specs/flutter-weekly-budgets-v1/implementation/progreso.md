# Progreso — flutter-weekly-budgets-v1

## Validación previa de consistencia

Comparación spec ↔ preguntas ↔ plan ↔ tasks ↔ test-plan:

- Todas las P-001..P-009 respondidas y trazadas en `preguntas.md`.
- Cada RF del `spec.md` tiene tarea correspondiente en `tasks.md`.
- Casos borde CB-01..CB-20 (spec) + CB-P01..CB-P07 (plan) +
  CB-T01..CB-T21 (test-plan) cubren el espacio conocido.
- Sin contradicciones detectadas entre criterios de aceptación,
  plan técnico y test-plan.
- Sin bloqueos que impidan arrancar la implementación.

## Estado de tareas

- [x] **T001** — Lectura de patrones existentes.
- [x] **T002** — Definir las 4 tablas drift en `database.dart`.
- [x] **T003** — Migración v6→v7 aditiva con guardrail preservado.
- [x] **T004** — Constante `kPrefWeekStartDow` en
  `app_preferences_keys.dart`.
- [x] **T005** — `WeeklyBudgetsDao` CRUD budget.
- [x] **T006** — Items del budget + reorder.
- [x] **T007** — `watchBudgetBalance` reactivo.
- [x] **T008** — `BudgetTemplatesDao` completo.
- [x] **T009** — Snapshot copiers cross-DAO bidireccionales.
- [x] **T010** — Helpers `weekStartDow` / `setWeekStartDow`.
- [x] **T011** — `BackupService.wipeAll` extendido.
- [x] **T012** — Registro de DAOs en `AppDependencies`.
- [x] **T013** — Helpers puros (`weekly_budgets.dart`).
- [x] **T014** — 4 rutas nuevas en `app_router.dart`.
- [x] **T015** — `BudgetKindPicker` widget.
- [x] **T016** — `BudgetItemFormSheet` reutilizable.
- [x] **T017** — `ItemsSection` con drag&drop por handle.
- [x] **T018** — `BalanceFooter` sticky reactivo.
- [x] **T019** — `WeeklyBudgetScreen` (detalle).
- [x] **T020** — `WeeklyBudgetsListScreen` (listado).
- [x] **T021** — `BudgetTemplatesScreen`.
- [x] **T022** — `BudgetTemplateDetailScreen`.
- [x] **T023** — IconButton en Dashboard AppBar (+ reorg fix A5).
- [x] **T024** — Sección "Preferencias" en Settings.
- [x] **T025** — FAQ en HelpScreen.
- [x] **T026** — Tests helpers puros.
- [x] **T027** — Tests `WeeklyBudgetsDao`.
- [x] **T028** — Tests `BudgetTemplatesDao`.
- [x] **T029** — Tests `AppPreferencesDao` helpers.
- [x] **T030** — Tests widget list_screen.
- [x] **T031** — Tests widget detail_screen.
- [x] **T032** — Tests widget templates_screen (WT-TS04 skipped
  documentado).
- [x] **T033** — Tests widget UX cross (settings + dashboard +
  help).
- [x] **T034** — Tests regresión backup.
- [x] **T035** — Tests migración v6→v7.
- [x] **T036** — `flutter analyze` limpio + full suite 671 verdes.
- [x] **T037** — APK release + `verify-apk.sh` OK
  (versionCode 2094 / versionName 0.20.0).
- [ ] **T038** — Smokes SM-01..SM-16 pendientes (requiere cel real
  con Diego).
- [x] **T039** — Branch quality-review ejecutado. Reporte en
  `engineering/quality-review/flutter-weekly-budgets-v1/2026-07-13-branch-quality-review.md`.
  21 hallazgos, 10 resueltos (5 altas + 5 medias), 0 bloqueantes.
- [x] **T040** — `implementation-review.md`, `resumen-ejecutivo.md`,
  `resumen-extenso.md` creados con las secciones requeridas.
- [ ] **T041** — Commit final pendiente hasta revisión de Diego.

## Iteración post-review de Diego (2026-07-14)

Diego solicitó ronda de cambios adicional tras primera revisión:

### Aplicados

- **Quitar banner "no se incluyen en respaldo"** de list_screen.
- **Simplificar empty state**: sin fecha, solo 1 CTA "Crear primer
  presupuesto", FAB oculto cuando la lista está vacía.
- **Ícono en empty state de plantillas**
  (`Icons.dashboard_customize_outlined` 64px).
- **Acciones rápidas edit/delete** en cada `_BudgetCard` del list
  vía `PopupMenuButton` con "Editar label", "Comparar con..."
  (condicional si hay same-week siblings), "Eliminar".
- **Español neutral**: purga de voseo en list, detail, template
  detail, templates, item form sheet, help FAQ, comments de DAOs.
  Memoria `feedback_spanish_neutral.md` guardada como regla
  vinculante.

### Nueva feature: Vista calendario

- Ruta nueva `/budgets/calendar`.
- Pantalla `BudgetCalendarScreen` reutilizando `table_calendar`
  (ya en pubspec por el reporte de movimientos).
- Marcas por día con `week_start_date`; multi-plan → 2 dots.
- Tap día → navegación directa o bottom sheet con selector si
  hay múltiples budgets. Tap día vacío → crear presupuesto para
  esa fecha (bonus fuera de spec original).
- IconButton nuevo en AppBar de list_screen para entrar.
- Tests CS-01..CS-03 verdes.

### Nueva feature: Comparación entre presupuestos

- Ruta nueva `/budgets/compare/:a/:b`.
- Pantalla `BudgetCompareScreen` con layout side-by-side:
  header con labels + balances, secciones income/expense con
  matching por `name.trim().toLowerCase()`, deltas en items
  compartidos, footer con totales comparativos.
- Restricciones defensivas: `A == B` → snackbar + pop; budget
  inexistente → snackbar + pop; distinta `week_start_date` →
  snackbar + pop.
- Entry point: `PopupMenuButton` de `_BudgetCard` con "Comparar
  con..." condicional (aparece si hay ≥1 sibling misma semana),
  abre bottom sheet con selector.
- Tests CP-01..CP-04 verdes.

### Refactor BalanceFooter — Opción C

- Nueva firma: `Stream<BudgetTotals>` (income + expense) en vez
  de `Stream<double>`.
- Layout nuevo: `LinearProgressIndicator` (gasto/ingreso) +
  "GASTOS PLANEADOS" con porcentaje + row grande con ícono
  `trending_up/down/remove` + label "Sobra/Faltan/En equilibrio"
  + monto 26px bold color semántico.
- Callers (`detail_screen.dart`, `template_detail_screen.dart`)
  actualizados con stream de totales cacheado en `didChangeDependencies`.
- **2 defectos de correctness fixeados en el mismo pass**:
  1. `Column` sin `mainAxisSize: MainAxisSize.min` en el
     `bottomNavigationBar` corrompía hit-testing del Scaffold
     completo (silenciosamente rompía WT-DS02..DS11).
  2. Stream recreado en cada `build()` reseteaba
     `StreamBuilder.ConnectionState` — footer flicker en cada
     rebuild.

### 7 quick wins UI/UX aplicados

- QW2: presupuestos pasados con `Opacity(0.7)`.
- QW3: botón "Agregar" en `ItemsSection` como
  `IconButton.filledTonal` tintado por kind + tooltip.
- QW4: ícono empty state templates (ya cubierto).
- QW5: banner backup (ya quitado).
- QW6: borde lateral 3px en `_ItemRow` con color del kind.
- QW7: rango de fechas del detail 12px + `textMuted`.
- QW8: preview de plantillas con conteo "N ingresos · M gastos".

### Estado final

- **`flutter analyze`**: limpio (4 hints info preexistentes).
- **`flutter test`**: **678 verdes** (1 skip preexistente
  documentado en WT-TS04).
- **APK release**: `versionCode 2094 / versionName 0.20.0`
  verificado.

Sprint listo end-to-end excepto smokes en cel real (T038) y
commit final (T041). Ambos requieren la presencia de Diego.

## Ronda 3 post-instalación en cel (2026-07-14)

Diego reportó bugs y solicitó ajustes tras instalar `0.20.0+94`:

### Bugs

- **Bottom sheet "Elige una plantilla"** con botones tapados por la
  barra de navegación gestual de Android. Fix: sumar
  `viewPadding.bottom` además de `viewInsets.bottom` al padding
  inferior. Aplicado en `_TemplatePickerSheet` +
  `BudgetItemFormSheet` + `SaveViewDialog` (fuera de sprint pero
  con el mismo bug).
- **`Error inesperado` al abrir presupuestos** después del refactor
  de plantillas. Causa raíz: la BD del cel de Diego estaba en
  `user_version = 7` con el schema pre-refactor (4 tablas, sin
  columna `is_template`), y la migración `v6→v7` no se re-ejecuta.
  Fix: hotfix schema `v7→v8`:
  1. `ALTER TABLE weekly_budgets ADD COLUMN is_template INTEGER NOT NULL DEFAULT 0`.
  2. `DROP TABLE budget_template_items` / `DROP TABLE budget_templates`.
  3. `DROP INDEX idx_bt_items_template_sort`.
  4. `CREATE INDEX idx_weekly_budgets_template`.
  Los presupuestos y sus renglones se preservan; las plantillas
  viejas se pierden (dato descartable, Diego reasigna con
  `Marcar como plantilla`).
  También agregada la rama `v6→v8` defensiva.

### Refactor plantillas → flag `is_template`

Diego pidió eliminar la entidad separada "plantilla" y usar un
flag `is_template` en `weekly_budgets`. Ejecutado:

- Eliminadas tablas `budget_templates` y `budget_template_items`.
- Eliminado `BudgetTemplatesDao` completo.
- Eliminadas pantallas `templates_screen.dart` y
  `template_detail_screen.dart` + rutas `/budget-templates/*`.
- Agregada columna `isTemplate` a `weekly_budgets` con índice
  parcial `WHERE is_template = 1`.
- Nuevo `toggleTemplateFlag`, `watchTemplates`, `generateAutoLabel`
  en `WeeklyBudgetsDao`.
- `_TemplatePickerSheet` renderiza `WeeklyBudgetRow` en vez de
  `BudgetTemplateRow`.
- Badge `Icons.bookmark` en `_BudgetCard` y AppBar del detalle
  cuando `isTemplate == true`.
- PopupMenu del card gana "Marcar como plantilla" / "Quitar de
  plantillas" (toggle).

### Auto-label + dialog unificado

Diego eliminó el prompt obligatorio de nombre al crear presupuesto:

- Método nuevo `WeeklyBudgetsDao.generateAutoLabel(weekStartDate)`
  → "Semana del D mmm" (ej: "Semana del 17 jul"), con sufijo
  `(2)`, `(3)`... si ya existe.
- Eliminado `_promptForLabel` de list_screen, calendar_screen,
  template_detail_screen (esta última eliminada).
- Solo queda un dialog de nombre: `showEditLabelDialog` para
  editar post-facto desde el detalle o desde el PopupMenu del card.

### Rediseño dialog "Editar nombre"

Diego reportó que el `AlertDialog` centrado se veía feo e
inconsistente. Rediseñado como bottom sheet (Propuesta 1 del
UI/UX experto):

- `showModalBottomSheet` con `showDragHandle`, `isScrollControlled`,
  `useSafeArea`, esquinas superiores 20, fondo `surface`.
- `TextField` con `OutlineInputBorder` + `labelText: 'Nombre'`
  + `counterText: ''` (oculta el `0/60`).
- Botones "Cancelar" / "Guardar" full-width en `Row` de
  `Expanded` con padding vertical 14.
- Firma pública sin cambios — callers no se tocaron.

### Multi-select bulk

Diego pidió acciones bulk sobre presupuestos:

- **Long-press** en un `_BudgetCard` → entra en modo selección.
- **Tap** en modo selección → alterna selección del card.
- AppBar cambia dinámicamente: leading `X` (salir) + título
  "N seleccionados" + IconButton delete.
- Card seleccionado con borde `accent` + checkbox visible.
- `PopScope` intercepta el back nativo para salir del modo sin
  cerrar la pantalla.
- `_bulkDelete()` → dialog destructivo "Eliminar N presupuestos y
  todos sus renglones?" → iteración de `deleteBudget(id)` +
  snackbar.
- **`PopupMenuButton ⋮`** nuevo en el AppBar principal con
  "Eliminar todos" (solo si hay ≥1) y "Seleccionar presupuestos"
  (atajo para entrar al modo bulk sin long-press).
- Extensiones opcionales agregadas a `BaseCard`: `onLongPress`,
  `borderColor`, `borderWidth` (backward compat).

### 7 quick wins UI/UX ronda 2 (aplicados junto con BalanceFooter
Opción C)

BalanceFooter refactor completo (opción C del UI/UX):
`LinearProgressIndicator` + "GASTOS PLANEADOS" con porcentaje +
row grande con ícono `trending_up/down/remove` + label + monto
26px bold. Firma nueva `Stream<BudgetTotals>` (income + expense).
Fixeó dos defectos de correctness preexistentes en el pass:
`Column` sin `mainAxisSize: min` corrompía hit-testing del
Scaffold; stream se recreaba en cada `build()` provocando flicker.

Otros quick wins: presupuestos pasados con `Opacity(0.7)`,
botón "Agregar" tintado por kind con `IconButton.filledTonal`,
borde lateral 3px por kind en `_ItemRow`, rango de fechas 12px
+ `textMuted`, preview de plantillas con conteo income/expense.

### Vista calendario + comparación

- **Calendario**: pantalla nueva `BudgetCalendarScreen` reutiliza
  `table_calendar` con marks por día con `week_start_date`.
  Multi-plan → 2 dots. Tap día vacío → crear presupuesto para
  esa fecha.
- **Comparación**: pantalla nueva `BudgetCompareScreen` con layout
  side-by-side de 2 presupuestos misma semana. Matching por
  `name.trim().toLowerCase()`. Deltas en items compartidos.
  Entry desde PopupMenu del card ("Comparar con...", condicional
  si hay ≥1 sibling misma semana).

### UX misc

- Banner "no se incluyen en el respaldo" **quitado** de list_screen
  (era ruido visual, la info sigue en Help FAQ).
- Empty state simplificado (sin fecha, 1 CTA, FAB oculto en lista
  vacía).
- Ícono `Icons.dashboard_customize_outlined` en empty state de
  templates (antes de eliminarse la pantalla).
- Acciones edit/comparar/eliminar en PopupMenu del card.
- **Español neutral** — voseo purgado en todo el módulo. Memoria
  `feedback_spanish_neutral.md` guardada como regla vinculante
  desde 2026-07-14.

## Estado final

- **`flutter analyze`**: limpio (4 hints info preexistentes
  tolerables).
- **`flutter test`**: **680 verdes** (1 skip preexistente
  documentado en WT-TS04, ahora eliminado junto con
  templates_screen_test.dart).
- **APK release**: `versionCode 2096 / versionName 0.20.2`
  verificado.
- **Diego confirmó satisfacción** post-install de `0.20.2+96`
  (2026-07-14). Sprint apto para commit.

Sprint listo end-to-end. Falta T041 (commit final) que se ejecuta
tras revisión del reporte.
