# Tasks — flutter-weekly-budgets-v1

## Preparación

- [ ] T001 Documentación: leer patrones existentes que este sprint va
  a tocar.
  RF: N/A
  Depende de: ninguna
  Paralelizable: sí
  Criterio de terminado: notas locales (no persistidas) con
  ubicaciones exactas de `AppPreferencesDao`, `MigrationStrategy.onUpgrade`,
  `BackupService.wipeAll`, `AppDependencies`, `app_router.dart`
  (patrón de rutas anidadas), `SettingsScreen` (dónde insertar
  la sección Preferencias), `DashboardScreen.AppBar.actions`
  (dónde insertar IconButton nuevo), `KindPicker` existente
  (evaluar si sirve o hay que crear versión light), `CategoryPicker`
  y `AmountFormatter`. Confirmar S-01 (`ON DELETE SET NULL` en
  category_id de journal_entries).

## Base de datos

- [ ] T002 Base de datos: definir las 4 tablas nuevas en drift.
  RF: RF-013 (base)
  Depende de: T001
  Paralelizable: no
  Criterio de terminado: `WeeklyBudgets`, `WeeklyBudgetItems`,
  `BudgetTemplates`, `BudgetTemplateItems` como `class ... extends
  Table` en `mobile/lib/data/database.dart`, con PK uuid v7, FK
  cascade a parent (`budget_id`/`template_id`), FK `SET NULL` en
  `category_id`, timestamps con default `currentDateAndTime`. Sin
  `deleted_at`. Registradas en `@DriftDatabase.tables`. `dart run
  build_runner build --delete-conflicting-outputs` sin errores.

- [ ] T003 Base de datos: migración v6→v7 aditiva.
  RF: RF-013
  Depende de: T002
  Paralelizable: no
  Criterio de terminado: `schemaVersion` bump a 7 en `database.dart`.
  Nueva rama `if (from == 6 && to == 7) { ... }` en `onUpgrade`
  con `m.createTable(weeklyBudgets)`, `m.createTable(weeklyBudgetItems)`,
  `m.createTable(budgetTemplates)`, `m.createTable(budgetTemplateItems)`
  + 2 índices sobre `(budget_id, sort_order)` y `(template_id,
  sort_order)`. Guardrail `UnimplementedError` preservado. Test
  MG-01, MG-02, MG-04 verde.

- [ ] T004 Base de datos: nueva constante
  `kPrefWeekStartDow = 'week_start_dow'` en
  `mobile/lib/data/app_preferences_keys.dart`.
  RF: RF-009
  Depende de: ninguna
  Paralelizable: sí
  Criterio de terminado: constante exportada + doc-comment
  explicando semántica (ISO 8601: 1=Lun...7=Dom, default 5).

## Backend / DAO

- [ ] T005 Backend: `WeeklyBudgetsDao` — CRUD del budget.
  RF: RF-001, RF-011, RF-012
  Depende de: T002, T003
  Paralelizable: no
  Criterio de terminado: métodos `createBudget`, `updateBudget`
  (con guard `immutable_field` para `weekStartDate`), `deleteBudget`
  (hard delete con cascade), `findById`, `watchAll` en
  `mobile/lib/data/daos/weekly_budgets_dao.dart`. Errores tipados
  `WeeklyBudgetsDaoError` con codes `invalid_budget_label`,
  `immutable_field`, `not_found`. Tests UT-WB01..UT-WB07, UT-WB21
  verdes.

- [ ] T006 Backend: `WeeklyBudgetsDao` — CRUD del item + reorder.
  RF: RF-004, RF-005, RF-006, RF-007, RF-013
  Depende de: T005
  Paralelizable: no
  Criterio de terminado: métodos `addItem`, `updateItem`,
  `deleteItem`, `reorderItems` (transaccional). Errores tipados
  `invalid_item_name`, `invalid_item_amount`, `invalid_kind`,
  `invalid_category_reference`, `not_found`. `sort_order`
  asignado en bloques de 100 al agregar. Tests UT-WB08..UT-WB17
  verdes.

- [ ] T007 Backend: `WeeklyBudgetsDao.watchBudgetBalance`.
  RF: RF-008
  Depende de: T006
  Paralelizable: no
  Criterio de terminado: método `watchBudgetBalance(id)` con
  `customSelect(sql, readsFrom: {weeklyBudgetItems}).watchSingle()`
  que retorna `Stream<double>` (Σincome − Σexpense) reactivo.
  Tests UT-WB18..UT-WB20 verdes.

- [ ] T008 Backend: `BudgetTemplatesDao` — CRUD template + items.
  RF: RF-016, RF-017, RF-018 (base para T009)
  Depende de: T003
  Paralelizable: sí (con T005 en paralelo)
  Criterio de terminado: análogo a T005+T006 aplicado a
  `budget_templates` y `budget_template_items` en
  `mobile/lib/data/daos/budget_templates_dao.dart`. Errores tipados
  `invalid_template_name`, `duplicate_template_name`,
  `immutable_field` no aplica (name es mutable). Tests
  UT-BT01..UT-BT07 verdes.

- [ ] T009 Backend: snapshot copiers en ambas direcciones.
  RF: RF-014, RF-018
  Depende de: T005, T006, T008
  Paralelizable: no
  Criterio de terminado: `BudgetTemplatesDao.createTemplateFromBudget({budgetId,
  name})` copia snapshot items del budget al template con nuevos
  `id` en transacción. `WeeklyBudgetsDao.createBudgetFromTemplate({weekStartDate,
  label, templateId})` copia snapshot items del template al budget
  con nuevos `id` en transacción. Ambas dirección validan
  existencia; error `not_found` si no existe parent. Tests
  UT-WB23..UT-WB25, UT-BT08 verdes.

- [ ] T010 Backend: `AppPreferencesDao` — helpers `weekStartDow` /
  `setWeekStartDow`.
  RF: RF-009, RF-022
  Depende de: T004
  Paralelizable: sí
  Criterio de terminado: método `weekStartDow()` retorna `int` con
  default 5 y robusto ante valores no numéricos y fuera de rango.
  `setWeekStartDow(int)` valida 1..7 con `assert`. Tests
  UT-AP01..UT-AP05 verdes.

- [ ] T011 Backend: `BackupService.wipeAll` extendido.
  RF: RG-04 (regression)
  Depende de: T002
  Paralelizable: sí
  Criterio de terminado: `wipeAll()` borra las 4 tablas nuevas
  antes de `journal_entries` (para respetar FKs) dentro de la
  transacción existente. Import defensivo: ignora arrays
  `weekly_budgets`, `weekly_budget_items`, `budget_templates`,
  `budget_template_items` si aparecen en el JSON entrante. Tests
  RG-01..RG-04 verdes.

- [ ] T012 Backend: registrar los DAOs nuevos en `AppDependencies`.
  RF: N/A (plumbing)
  Depende de: T005, T008
  Paralelizable: no
  Criterio de terminado: `weeklyBudgetsDao` y `budgetTemplatesDao`
  agregados al constructor y expuestos como getters en
  `mobile/lib/app_dependencies.dart`. Sin regresión en el `pumpFincoreApp`
  harness.

- [ ] T013 Backend: helpers puros de dominio.
  RF: RF-010, RF-002
  Depende de: T001
  Paralelizable: sí
  Criterio de terminado: `mobile/lib/data/weekly_budgets.dart` con:
  - `suggestedWeekStartDate({DateTime now, int weekStartDow})`
    (RN-B02).
  - `weekRangeOf(DateTime weekStartDate)` → `DateTimeRange` (7
    días).
  - `groupBudgetsByRange({List<WeeklyBudget> budgets, DateTime
    now, int weekStartDow})` → `{esta, próximas, pasadas}` con
    ordering.
  - `calculateBalance(List<WeeklyBudgetItem> items)` → double.
  Tests UT-H01..UT-H09 verdes.

## Frontend / Router

- [ ] T014 Frontend: rutas nuevas en `app_router.dart`.
  RF: N/A (plumbing)
  Depende de: T005, T008
  Paralelizable: no
  Criterio de terminado: 4 rutas nuevas en `buildAppRouter`:
  `/budgets` (list), `/budgets/:id` (detail),
  `/budget-templates` (list), `/budget-templates/:id` (detail).
  Convención con `context.push` (no `context.go`) verificada.

## Frontend / Widgets base

- [ ] T015 Frontend: `_KindPickerBudget` widget (segmented buttons
  simple).
  RF: RF-004
  Depende de: T001
  Paralelizable: sí
  Criterio de terminado: widget en
  `mobile/lib/screens/weekly_budgets/widgets/kind_picker_budget.dart`
  con 2 opciones (Ingreso / Gasto). Si el `KindPicker` existente
  del ledger sirve directamente sin cuenta, se reutiliza y esta
  tarea se cierra sin código nuevo (registrar en el criterio).

- [ ] T016 Frontend: `BudgetItemFormSheet` reutilizable.
  RF: RF-004, RF-005
  Depende de: T015, T007
  Paralelizable: no
  Criterio de terminado: bottom sheet
  `mobile/lib/screens/weekly_budgets/widgets/budget_item_form_sheet.dart`
  con TextField name (1..60), `_KindPickerBudget`, `AmountFormatter`
  para monto (> 0), `CategoryPicker` opcional. Botones Guardar /
  Cancelar. Emite el modelo o el update. Valida antes del submit.
  Reutilizable para budget item y template item vía callback
  parametrizable.

- [ ] T017 Frontend: `_ItemsSection` con `ReorderableListView` +
  handle.
  RF: RF-003, RF-007
  Depende de: T016
  Paralelizable: no
  Criterio de terminado: widget en
  `mobile/lib/screens/weekly_budgets/widgets/items_section.dart`
  que renderiza título + list + botón "+" contextual. Usa
  `ReorderableListView` con `buildDefaultDragHandles: false` +
  `ReorderableDragStartListener` envolviendo `Icons.drag_indicator`.
  Tap en row abre edit (no reorder). Delete via swipe o long-press
  con dialog. Sección propia para income y expense.

- [ ] T018 Frontend: `_BalanceFooter` sticky.
  RF: RF-008
  Depende de: T007
  Paralelizable: sí
  Criterio de terminado: widget en
  `mobile/lib/screens/weekly_budgets/widgets/balance_footer.dart`
  con `StreamBuilder<double>` que renderiza texto formateado
  ("Sobra $X" verde, "Faltan $Y" rojo, "En equilibrio" gris) más
  fondo `surfaceElevated`.

## Frontend / Pantallas

- [ ] T019 Frontend: `WeeklyBudgetScreen` (detalle presupuesto).
  RF: RF-003, RF-004..RF-008, RF-011, RF-012, RF-014
  Depende de: T017, T018, T009
  Paralelizable: no
  Criterio de terminado: pantalla en
  `mobile/lib/screens/weekly_budgets/detail_screen.dart` con:
  AppBar (label editable inline vía tap → dialog +
  `updateBudget`), rango fijo bajo el label. Menú AppBar con
  "Crear plantilla desde este presupuesto" y "Eliminar
  presupuesto" (con dialog destructivo). 2 `_ItemsSection`
  (income + expense). `_BalanceFooter` sticky abajo. FAB
  contextual `+ Ingreso`/`+ Gasto` según sección tapeada, o dos
  FAB si es más simple.

- [ ] T020 Frontend: `WeeklyBudgetsListScreen` con FAB dual.
  RF: RF-002, RF-019, RF-020
  Depende de: T013, T014, T019
  Paralelizable: no
  Criterio de terminado: pantalla en
  `mobile/lib/screens/weekly_budgets/list_screen.dart` con:
  AppBar "Presupuestos semanales" + IconButton "Plantillas" (nav a
  `/budget-templates`). Body: 3 secciones agrupadas + card por
  budget. FAB "+ Presupuesto" abre bottom sheet con "En blanco" o
  "Desde plantilla" (esta desactivada si `templates.isEmpty`).
  "En blanco" abre picker de fecha (default RN-B02) + form de
  label → `createBudget` → nav a detalle. "Desde plantilla" abre
  selector de plantilla → picker de fecha + label →
  `createBudgetFromTemplate` → nav a detalle.

- [ ] T021 Frontend: `BudgetTemplatesScreen` (listado plantillas).
  RF: RF-015, RF-017
  Depende de: T014, T008
  Paralelizable: sí (con T019)
  Criterio de terminado: pantalla en
  `mobile/lib/screens/weekly_budgets/templates_screen.dart` con
  listado + card por template con preview colapsado (primeros 3
  items + balance). Empty state. Tap → detalle.

- [ ] T022 Frontend: `BudgetTemplateDetailScreen`.
  RF: RF-016, RF-017
  Depende de: T017, T018, T021
  Paralelizable: no
  Criterio de terminado: pantalla en
  `mobile/lib/screens/weekly_budgets/template_detail_screen.dart`
  reusa `_ItemsSection` y `_BalanceFooter`. AppBar con name
  editable inline + menú "Eliminar plantilla" (dialog destructivo).
  Sin picker de fecha.

- [ ] T023 Frontend: IconButton en Dashboard AppBar.
  RF: RF-020
  Depende de: T014
  Paralelizable: sí
  Criterio de terminado: IconButton nuevo en
  `mobile/lib/screens/dashboard_screen.dart.AppBar.actions`,
  posición a definir en T001, con `Icons.calendar_month`
  (o similar), navega a `/budgets` vía `context.push`. Test
  WT-DASH01 verde.

- [ ] T024 Frontend: sección "Preferencias" en Settings.
  RF: RF-022, RF-009
  Depende de: T010
  Paralelizable: sí
  Criterio de terminado: nueva sección en
  `mobile/lib/screens/settings_screen.dart` con `BaseCard` +
  título "Preferencias" + `DropdownButton<int>` para día de inicio
  (1..7 mapeado a nombres es_MX). Persiste vía
  `setWeekStartDow(int)`. Posición: arriba de "Zona peligrosa"
  (por confirmar en T001).

## Documentación

- [ ] T025 Documentación: nuevo bloque en `HelpScreen` FAQ.
  RF: RF-021
  Depende de: T024
  Paralelizable: sí
  Criterio de terminado: en `mobile/lib/screens/help_screen.dart`
  agregar 1 pregunta/respuesta:
  "¿Qué diferencia hay entre 'Presupuestos' del reporte y
  'Presupuestos semanales'?" — explicando mensual por categoría vs
  planeador semanal libre + advertencia "los presupuestos
  semanales NO se guardan en el respaldo".

## Pruebas

- [ ] T026 Pruebas: tests unitarios de helpers puros.
  RF: RF-002, RF-010
  Depende de: T013
  Paralelizable: sí
  Criterio de terminado: `mobile/test/data/weekly_budgets_helpers_test.dart`
  con UT-H01..UT-H09 verdes.

- [ ] T027 Pruebas: tests `WeeklyBudgetsDao`.
  RF: RF-001..RF-013
  Depende de: T005, T006, T007, T009
  Paralelizable: sí
  Criterio de terminado:
  `mobile/test/data/weekly_budgets_dao_test.dart` con
  UT-WB01..UT-WB25 verdes.

- [ ] T028 Pruebas: tests `BudgetTemplatesDao`.
  RF: RF-014..RF-018
  Depende de: T008, T009
  Paralelizable: sí
  Criterio de terminado:
  `mobile/test/data/budget_templates_dao_test.dart` con
  UT-BT01..UT-BT08 verdes. Incluir explícitamente snapshot
  bidireccional (edit template no afecta budget derivado y
  viceversa).

- [ ] T029 Pruebas: tests `AppPreferencesDao.weekStartDow`.
  RF: RF-009
  Depende de: T010
  Paralelizable: sí
  Criterio de terminado:
  `mobile/test/data/app_preferences_dao_test.dart` (o append al
  existente) con UT-AP01..UT-AP05 verdes.

- [ ] T030 Pruebas: tests widget `WeeklyBudgetsListScreen`.
  RF: RF-002, RF-019, RF-020
  Depende de: T020
  Paralelizable: sí
  Criterio de terminado:
  `mobile/test/screens/weekly_budgets/list_screen_test.dart` con
  WT-LS01..WT-LS05 verdes.

- [ ] T031 Pruebas: tests widget `WeeklyBudgetScreen`.
  RF: RF-003..RF-008, RF-011, RF-012
  Depende de: T019
  Paralelizable: sí
  Criterio de terminado:
  `mobile/test/screens/weekly_budgets/detail_screen_test.dart` con
  WT-DS01..WT-DS11 verdes. Incluir explícitamente WT-DS06 (copy
  del dialog destructivo) y WT-DS08 (handle vs row).

- [ ] T032 Pruebas: tests widget templates.
  RF: RF-015, RF-016, RF-017, RF-018
  Depende de: T021, T022
  Paralelizable: sí
  Criterio de terminado:
  `mobile/test/screens/weekly_budgets/templates_screen_test.dart`
  y `template_detail_screen_test.dart` con WT-TS01..WT-TS04 verdes.

- [ ] T033 Pruebas: tests widget Settings + Dashboard entry.
  RF: RF-020, RF-022
  Depende de: T023, T024
  Paralelizable: sí
  Criterio de terminado: WT-SET01, WT-SET02, WT-DASH01, WT-HELP01
  en los archivos correspondientes.

- [ ] T034 Pruebas: tests de regresión de backup.
  RF: RG-01..RG-04
  Depende de: T011
  Paralelizable: sí
  Criterio de terminado:
  `mobile/test/data/backup_test.dart` extendido (o nuevo archivo)
  con RG-01..RG-04 verdes.

- [ ] T035 Pruebas: tests de migración v6→v7.
  RF: MG-01..MG-04
  Depende de: T003
  Paralelizable: sí
  Criterio de terminado:
  `mobile/test/data/database_test.dart` extendido con MG-01..MG-04
  verdes.

## Validación de calidad

- [ ] T036 Validación: `flutter analyze` + `flutter test` verdes.
  RF: N/A
  Depende de: T026..T035
  Paralelizable: no
  Criterio de terminado: analyze en 0 errores (hints info
  preexistentes aceptables) + suite full-green (591 previos +
  todos los nuevos).

- [ ] T037 Validación: bump versión + build APK + verify.
  RF: N/A
  Depende de: T036
  Paralelizable: no
  Criterio de terminado: `pubspec.yaml` en `0.20.0+94` y
  `android/app/build.gradle.kts` con `versionCode = 94` y
  `versionName = "0.20.0"`. `flutter build apk --release
  --split-per-abi` OK. `bash scripts/verify-apk.sh` OK con
  versionCode 2094 / versionName 0.20.0.

- [ ] T038 Validación: smokes en cel real con Diego.
  RF: N/A
  Depende de: T037
  Paralelizable: no
  Criterio de terminado: SM-01..SM-16 confirmados por Diego. Los
  resultados quedan en `implementation/pruebas.md` o análogo.
  Feedback post-smoke incorporado antes del quality-review si
  hay findings.

- [ ] T039 Validación: `branch-quality-review` del sprint.
  RF: N/A
  Depende de: T038
  Paralelizable: no
  Criterio de terminado: reporte en
  `engineering/quality-review/flutter-weekly-budgets-v1/YYYY-MM-DD-branch-quality-review.md`.
  Findings altas/medias resueltas antes del commit; bajas
  documentadas o deferidas explícitamente.

## Documentación

- [ ] T040 Documentación: `implementation-review.md`,
  `resumen-ejecutivo.md`, `resumen-extenso.md` bajo
  `engineering/specs/flutter-weekly-budgets-v1/implementation/`.
  RF: N/A
  Depende de: T037, T039
  Paralelizable: no
  Criterio de terminado: los 3 archivos creados con secciones
  requeridas por `spec-implementar`. Referencian el reporte de
  quality-review + smokes confirmados.

- [ ] T041 Documentación: commit final del sprint.
  RF: N/A
  Depende de: T040
  Paralelizable: no
  Criterio de terminado: commit con mensaje formato
  `feat(mobile): sprint flutter-weekly-budgets-v1 — ...` incluyendo
  todos los archivos modificados/nuevos + carpetas
  `engineering/specs/flutter-weekly-budgets-v1/`
  y `engineering/quality-review/flutter-weekly-budgets-v1/`.
  Working tree limpio post-commit.
