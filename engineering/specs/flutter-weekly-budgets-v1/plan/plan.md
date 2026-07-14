# Plan técnico — flutter-weekly-budgets-v1

## Enfoque tecnico

Módulo standalone en `mobile/lib/screens/weekly_budgets/` y
`mobile/lib/data/daos/` sin acoplamiento con el ledger existente. Se
introducen 4 tablas nuevas (`weekly_budgets`, `weekly_budget_items`,
`budget_templates`, `budget_template_items`) + 2 DAOs
(`WeeklyBudgetsDao`, `BudgetTemplatesDao`) + 1 preferencia
(`week_start_dow`) + 3 pantallas nuevas + 2 formularios reutilizables
+ 4 rutas nuevas en `go_router`.

Convenciones ya establecidas del proyecto:

- UUID v7 en todas las PKs.
- `store_date_time_values_as_text: true` en drift.
- Errores tipados con code + message por DAO.
- Streams reactivos vía `customSelect(..., readsFrom: {...}).watch()`
  o `MultiSelectable` según sea.
- Widgets base: `BaseCard`, `ConfirmDialog`, `AmountFormatter`,
  `CategoryPicker`, `KindPicker` (o versión custom si el existente
  requiere cuenta), `error_snackbar.dart`.
- Schema bump con guardrail `UnimplementedError` post-if-chain en
  `MigrationStrategy.onUpgrade`.
- `flutter analyze` gate previo al commit.

Diferencias con el resto del proyecto:

- **Hard delete** en las 4 tablas nuevas. No hay `deleted_at`, no
  hay `archive*` methods. `deleteBudget` y `deleteTemplate` borran
  la fila con FK cascade a sus items.
- **Label obligatorio** en `weekly_budgets.label` — patrón nuevo,
  ninguna otra tabla lo exige.
- **Snapshot semántico** al copiar entre budget ↔ template — se
  copian los datos, se generan `id` nuevos, NO se comparten
  referencias.
- **Sin backup**: el `BackupService.exportToJson` NO agrega arrays
  para las 4 tablas nuevas. `wipeAll` sí las borra (contrato
  "reemplazo total" preservado). Import ignora arrays si aparecen
  en el JSON (defensivo).

Riesgos técnicos principales:

- Schema bump v6 → v7 con 4 tablas nuevas y 2 índices requiere
  extender el chain de `onUpgrade`. Preservar el guardrail.
- `week_start_date` normalizado a medianoche local para evitar
  desalineación por hora al persistir vía drift (config text).
- `ReorderableListView` con `buildDefaultDragHandles: false` +
  `ReorderableDragStartListener` es el patrón para handle drag —
  hay que validar en dispositivo real.
- Snapshot vs referencia en plantillas: bug clásico si se comparte
  el mismo `id` al copiar. Cubrir con test explícito
  (edit template → verificar que el budget derivado NO cambia).

## Requisitos funcionales cubiertos

- **RF-001** (crear presupuesto con label obligatorio): `WeeklyBudgetsDao.createBudget`
  + `WeeklyBudgetsListScreen` FAB → bottom sheet → form.
- **RF-002** (listado agrupado): `WeeklyBudgetsListScreen` con
  `_groupByRange(budgets, now)` que separa "Esta semana",
  "Próximas", "Pasadas".
- **RF-003** (detalle con secciones income/expense):
  `WeeklyBudgetScreen` con dos `_ItemsSection`.
- **RF-004..RF-006** (CRUD renglones): `WeeklyBudgetsDao.addItem/updateItem/deleteItem`
  + `BudgetItemFormSheet`.
- **RF-007** (drag&drop con handle): `_ItemsSection` con
  `ReorderableListView` + `buildDefaultDragHandles: false`.
- **RF-008** (balance reactivo): `WeeklyBudgetsDao.watchBudgetBalance(id)`
  con `readsFrom: {weeklyBudgetItems}` + `_BalanceFooter`.
- **RF-009 / RF-022** (setting `week_start_dow`): `AppPreferencesDao`
  helpers + nueva sección "Preferencias" en `SettingsScreen`.
- **RF-010** (sugerencia inicial del picker): helper puro
  `suggestedWeekStartDate(now, weekStartDow)` en el módulo.
- **RF-011** (hard delete presupuesto): `deleteBudget` + `ConfirmDialog`
  destructivo en el menú del detalle.
- **RF-012** (editar label sin fecha): `updateBudget(id, {label})`
  + validación `immutable_field` si intentan pasar `weekStartDate`.
- **RF-013** (multi-plan por semana): sin constraint UNIQUE
  compuesto — se acepta N filas con misma `week_start_date`.
- **RF-014..RF-019** (plantillas): `BudgetTemplatesDao` +
  `BudgetTemplatesScreen` + `BudgetTemplateScreen` + bottom sheet
  del FAB con opción "Desde plantilla".
- **RF-020** (entrada desde Dashboard): IconButton nuevo en
  `DashboardScreen.AppBar.actions`.
- **RF-021** (FAQ): nuevo bloque en `HelpScreen`.

## Archivos o modulos probablemente afectados

Nuevos:

- `mobile/lib/data/daos/weekly_budgets_dao.dart`.
- `mobile/lib/data/daos/budget_templates_dao.dart`.
- `mobile/lib/data/weekly_budgets.dart` (helpers puros:
  `suggestedWeekStartDate`, agrupación por rango, balance).
- `mobile/lib/screens/weekly_budgets/list_screen.dart`.
- `mobile/lib/screens/weekly_budgets/detail_screen.dart`.
- `mobile/lib/screens/weekly_budgets/templates_screen.dart`.
- `mobile/lib/screens/weekly_budgets/template_detail_screen.dart`.
- `mobile/lib/screens/weekly_budgets/widgets/budget_item_form_sheet.dart`
  (reutilizable para budget + template items).
- `mobile/lib/screens/weekly_budgets/widgets/kind_picker_budget.dart`
  (o reutilizar `KindPicker` existente si el shape sirve — por
  confirmar en T001).
- `mobile/lib/screens/weekly_budgets/widgets/items_section.dart`
  (`ReorderableListView` con handle).
- `mobile/lib/screens/weekly_budgets/widgets/balance_footer.dart`.
- `mobile/test/data/weekly_budgets_dao_test.dart`.
- `mobile/test/data/budget_templates_dao_test.dart`.
- `mobile/test/data/weekly_budgets_helpers_test.dart`.
- `mobile/test/screens/weekly_budgets/list_screen_test.dart`.
- `mobile/test/screens/weekly_budgets/detail_screen_test.dart`.
- `mobile/test/screens/weekly_budgets/templates_screen_test.dart`.
- `mobile/test/screens/settings_preferences_test.dart` (o
  incorporado a `settings_screen_test.dart` si existe).

Modificados:

- `mobile/lib/data/database.dart` (4 tablas nuevas, schemaVersion
  6→7, onUpgrade con rama v6→v7, `@DriftDatabase.tables:` y
  `daos:`).
- `mobile/lib/data/app_preferences_keys.dart` (nueva constante
  `kPrefWeekStartDow`).
- `mobile/lib/data/daos/app_preferences_dao.dart` (helpers
  `weekStartDow()` y `setWeekStartDow(int)`; default `5`).
- `mobile/lib/data/backup.dart` (`wipeAll()` borra las 4 tablas
  nuevas; el export/import NO las incluye — verificar que no lea
  arrays inexistentes con NPE).
- `mobile/lib/app_dependencies.dart` (registrar los 2 DAOs
  nuevos).
- `mobile/lib/router/app_router.dart` (4 rutas nuevas).
- `mobile/lib/screens/dashboard_screen.dart` (IconButton nuevo en
  AppBar.actions).
- `mobile/lib/screens/settings_screen.dart` (sección
  "Preferencias" con DropdownButton).
- `mobile/lib/screens/help_screen.dart` (FAQ nuevo bullet).
- `mobile/pubspec.yaml` + `mobile/android/app/build.gradle.kts`
  (bump `0.19.0+93` → `0.20.0+94`).

## Entidades y estados afectados

Entidades nuevas:

- **WeeklyBudget**: `id`, `week_start_date`, `label`, `created_at`,
  `updated_at`.
- **WeeklyBudgetItem**: `id`, `budget_id`, `name`, `category_id?`,
  `amount`, `kind`, `sort_order`, `created_at`, `updated_at`.
- **BudgetTemplate**: `id`, `name`, `created_at`, `updated_at`.
- **BudgetTemplateItem**: `id`, `template_id`, `name`,
  `category_id?`, `amount`, `kind`, `sort_order`, `created_at`,
  `updated_at`.

Estados:

- Ninguna entidad tiene estado (activo/archivado). Existe = activo.
  Hard delete = no existe más.

Invariantes:

- Item: `amount > 0`, `name` no vacío, `kind ∈ {income, expense}`,
  `category_id` (si presente) apunta a categoría **activa** al
  crear/editar. La categoría puede archivarse post-facto sin romper.
- Budget: `label` no vacío, `week_start_date` inmutable post-create.
- Template: `name` único entre activos, no vacío.

Efectos secundarios:

- FK cascade `ON DELETE CASCADE` en `budget_id` y `template_id`
  para que borrar el parent borre sus items automáticamente en la
  BD (sin doble transacción aplicativa).
- Archivar una categoría no rompe items existentes que la referencien
  — el badge desaparece en el render (mismo patrón que el ledger).

## Compatibilidad con datos y procesos existentes

- **Schema bump v6 → v7**: rama nueva en `onUpgrade` de
  `MigrationStrategy` para crear las 4 tablas + índices. Aditivo:
  no modifica tablas existentes. El guardrail
  `UnimplementedError` debe extenderse (misma convención que
  RN-H02 documentada en CLAUDE.md).
- **Backup JSON v1**: el shape NO cambia. `exportToJson` sigue
  exportando `accounts`, `categories`, `journal_entries`. `importFromJson`
  ignora arrays no reconocidos si aparecen (defensivo, para el caso
  de que un backup de un fork o versión futura los traiga).
  `wipeAll()` se extiende para borrar las 4 tablas nuevas también.
- **`FinancialStateService`, `EntriesDao`, `AccountsDao`,
  `CategoriesDao`, `SavedViewsDao`, `AppPreferencesDao` existentes**:
  intocados. Solo `AppPreferencesDao` gana 2 helpers nuevos.
- **Reportes (`ReportsService`, `ReportsScreen`)**: intocados.
- **Dashboard**: agrega IconButton en el AppBar; el resto queda
  igual.
- **Settings**: agrega sección "Preferencias" arriba de "Zona
  peligrosa" (por confirmar posición exacta en T012).
- **Help/FAQ**: agrega bloque nuevo, no toca los existentes.
- **Onboarding**: por confirmar si se agrega slide sobre
  presupuestos semanales o queda para sprint aparte. Tentativo: no
  se toca (mantener onboarding corto).

## Cambios de datos

Ver Alcance de la spec para el DDL detallado. Resumen:

- 4 CREATE TABLE en la migración v6→v7.
- 2 índices: `idx_wb_items_budget_id ON weekly_budget_items(budget_id)`
  y `idx_wb_items_sort ON weekly_budget_items(budget_id, sort_order)`
  (similar para template_items).
- 1 constante nueva `kPrefWeekStartDow = 'week_start_dow'` en
  `app_preferences_keys.dart`.
- Sin data migration (no hay datos previos a migrar).

## Cambios de API

No aplica — no hay API externa. Todo es local via drift DAOs.

## Cambios de integraciones

- `BackupService.wipeAll()`: extender para borrar las 4 tablas
  nuevas antes de commit de la transacción.
- `AppDependencies`: registrar `weeklyBudgetsDao` y
  `budgetTemplatesDao` en el constructor y en el getter.

## Cambios de UI

Ver Alcance. Puntos clave:

- Router: 4 rutas nuevas (`/budgets`, `/budgets/:id`,
  `/budget-templates`, `/budget-templates/:id`).
- Dashboard AppBar: nuevo IconButton (icono `Icons.calendar_month`
  o similar por confirmar) que abre `/budgets`.
- Settings: nueva sección "Preferencias" con `DropdownButton<int>`
  para día de inicio (1..7 mapeado a "Lunes"..."Domingo").
- 3 pantallas nuevas + form sheet + widgets internos.
- Snackbars usando `error_snackbar.dart` para success/warning/error.

## Cambios de permisos

No aplica (single-user local).

## Riesgos tecnicos

- **RT-01 — Snapshot vs referencia en plantillas**: bug de
  compartir `id` al copiar. Mitigar con test explícito por dirección
  (crear plantilla + editar budget original + verificar plantilla
  intacta; aplicar plantilla + editar plantilla + verificar
  budget derivado intacto).
- **RT-02 — Zona horaria de `week_start_date`**: drift persiste
  DateTime como ISO UTC. Normalizar a medianoche local antes de
  guardar (`DateTime(y, m, d).toUtc()` — perdida de hora) o usar
  DATE-only si drift lo soporta. Por confirmar en T004.
- **RT-03 — `ReorderableListView` con handle**: patrón menos común
  que row-completo. Requiere `buildDefaultDragHandles: false` +
  `ReorderableDragStartListener` envolviendo solo el handle. Sin
  precedente en la codebase — es la primera pantalla del proyecto
  que usa reorder.
- **RT-04 — `wipeAll` sin borrar tablas nuevas**: si el commit
  olvida agregar `delete(_db.weeklyBudgets)` etc, un import de
  backup dejaría datos huérfanos. Cubrir con test explícito de
  regression.
- **RT-05 — FK cascade en SQLite**: requiere `PRAGMA foreign_keys
  = ON` que ya está activo. Verificar en test que el cascade
  funciona sin trigger manual.
- **RT-06 — Multi-plan por semana genera N cards en el listado**:
  performance del `ListView` con 20+ presupuestos en la misma
  semana. Aceptable en single-user; sin paginación por ahora.
- **RT-07 — Copy destructivo del dialog debe ser inequívoco**:
  "Esto borrará el presupuesto y sus N renglones. Esta acción no
  se puede deshacer." — validar strings en el widget test.
- **RT-08 — `AppPreferencesDao.weekStartDow()` return type**: el
  helper devuelve `int` con default `5`. Robusto ante valores no
  numéricos (BD corrupta) → catch parseError y retorna default.

## Estrategia de pruebas

Ver `test-plan.md`. Resumen:

- **DAO**: CRUD, validaciones, cascade, immutable_field, snapshot
  semántico. Tests aislados con drift in-memory.
- **Helpers puros**: `suggestedWeekStartDate`, `_groupByRange`,
  balance calc. Tests unitarios sin BD.
- **Widget**: harness `pumpFincoreApp` cubriendo cada pantalla nueva.
- **Regresión**: backup round-trip + wipeAll con las 4 tablas.
- **Smoke**: SM-01..SM-XX en cel real (definidos en test-plan).

## Estrategia de rollback

- **Rollback pre-commit**: cambios locales, `git checkout .` en el
  branch.
- **Rollback post-commit pre-release**: `git revert <sha>` del
  commit del sprint. La revert no aplica DROP TABLE (los datos
  quedan huérfanos pero inaccesibles porque el código no los
  referencia). Aceptable — se limpia con export/import posterior o
  con reset de BD.
- **Rollback post-release en producción (APK sideload)**: reinstalar
  APK 0.19.0+93 (con `-r` para preservar data). Las tablas v7
  quedan pero drift no las usa; próximo release las puede volver
  a leer sin problema.
- Sin migración destructiva → riesgo bajo. Si se necesita un
  cleanup real, sprint separado con DROP TABLE explícito en
  v7→v8.

## Orden sugerido de implementacion

1. Lectura / reconocimiento del terreno (T001).
2. Schema + migración v6→v7 + tablas drift + build_runner (T002-T003).
3. DAOs core: `WeeklyBudgetsDao` CRUD budget + items + balance
   (T004-T005).
4. DAOs plantillas: `BudgetTemplatesDao` + snapshot crossovers
   (T006-T008).
5. Preferences helper + constant (T009).
6. Errores tipados + registro en `AppDependencies` (T010-T011).
7. Backup wipeAll extension (T012).
8. Router + rutas (T013).
9. Widgets base: `BudgetItemFormSheet`, `_ItemsSection`,
   `_BalanceFooter` (T014-T016).
10. Pantalla `WeeklyBudgetScreen` (detalle) + drag&drop (T017).
11. Pantalla `WeeklyBudgetsListScreen` + FAB con bottom sheet
    (T018).
12. Pantalla `BudgetTemplatesScreen` + detalle (T019-T020).
13. Entrada desde Dashboard (T021).
14. Sección Preferencias en Settings (T022).
15. FAQ / Help (T023).
16. Tests DAO (T024-T028).
17. Tests widget (T029-T033).
18. Tests backup regression (T034).
19. `flutter analyze` + `flutter test` (T035).
20. Bump versión + APK + verify-apk.sh (T036).
21. Smokes en cel real (T037).
22. `branch-quality-review` (T038).
23. Commit final (T039).

## Casos borde que condicionan la solucion

Los definidos en `spec.md` sección "Casos borde" (CB-01..CB-20)
más los adicionales detectados en la planeación:

- **CB-P01 — `wipeAll` con FK cascade activa**: al borrar
  `categories` con `wipeAll`, ¿arrastra por FK a
  `weekly_budget_items.category_id`? Como `category_id` es
  nullable y no tiene ON DELETE CASCADE definido, drift/SQLite
  intentará SET NULL o rechazar. Verificar semantic esperada:
  probablemente `ON DELETE SET NULL` para `category_id` en items
  (mismo patrón que journal_entries → categories). Documentar y
  testear.
- **CB-P02 — Crear budget cuando la BD tiene `weekStartDow`
  corrupto**: `get('week_start_dow')` retorna `'abc'`. Helper debe
  fallback a `5` (default). Test explícito.
- **CB-P03 — Reorder con solo 1 item**: `ReorderableListView` con
  1 elemento no dispara `onReorder`. Comportamiento aceptado.
- **CB-P04 — Reorder de item movido a otra sección (income →
  expense)**: se acepta solo dentro de la misma sección. La UI
  divide en 2 ReorderableListViews independientes; para cambiar
  kind el usuario edita el item explícitamente.
- **CB-P05 — Aplicar plantilla que fue eliminada entre selección
  y guardado**: `createBudgetFromTemplate` retorna error `not_found`
  → snackbar warning y no navega.
- **CB-P06 — Editar plantilla mientras hay presupuestos abiertos
  en otra pantalla**: cada stream usa su propia query — no hay
  cross-stream leak. Verificar con test.
- **CB-P07 — Persistir `week_start_date` en TZ cambiante**: si el
  dispositivo cambia de TZ mientras el presupuesto existe, el
  DATE guardado se lee como misma fecha calendario local. Valida
  que drift retorna el DateTime con zona local del dispositivo al
  leer.

## Preguntas o supuestos que siguen afectando la implementacion

Todas las P-001..P-009 están cerradas. Nuevos supuestos que
emergen del plan:

- **S-01**: `WeeklyBudgetItem.category_id` usa
  `ON DELETE SET NULL` como el ledger. Confirmar en T004 antes
  de escribir la migración.
- **S-02**: el picker de fecha es `showDatePicker` estándar Material
  sin filtro por día. Consistente con RN-B02 (sugerido, no
  forzado).
- **S-03**: el bottom sheet del FAB del listado tiene 2 opciones
  (En blanco / Desde plantilla). "Desde plantilla" queda
  deshabilitada si no hay plantillas activas.
- **S-04**: no se agrega slide de onboarding para este sprint. Si
  Diego lo pide después, sprint aparte.
- **S-05**: el detalle de un template reusa mucho del
  `WeeklyBudgetScreen` (misma UI de secciones income/expense +
  reorder + balance + form sheet). Se abstrae la parte común en
  `_ItemsSection` reutilizable.
- **S-06**: el label del presupuesto es editable inline en la
  AppBar del detalle vía tap en el texto → dialog con TextField.
  No hay Edit mode dedicado.
- **S-07**: no hay UI para "duplicar presupuesto" — la vía
  canónica es crear plantilla → aplicar plantilla al nuevo.
