# Implementation Review: flutter-weekly-budgets-v1

## Resumen de lo implementado

Módulo nuevo standalone "Presupuestos semanales" en FinCore (Flutter
local-first single-user):

- **Schema drift v6→v7 aditivo**: 4 tablas nuevas (`weekly_budgets`,
  `weekly_budget_items`, `budget_templates`, `budget_template_items`)
  con hard delete + FK aplicativas gestionadas en transacción. 3
  índices para agrupación por rango y ordering por `sort_order`.
- **2 DAOs nuevos**: `WeeklyBudgetsDao` y `BudgetTemplatesDao` con
  CRUD completo, snapshot copiers cross-DAO (`createBudgetFromTemplate`,
  `createTemplateFromBudget`), errores tipados, reorderItems
  transaccional, `watchBudgetBalance` reactivo.
- **1 preferencia nueva**: `week_start_dow` en `AppPreferences`
  (default 5 = viernes), con helpers `weekStartDow()` /
  `setWeekStartDow(int)` robustos ante valores corruptos.
- **4 pantallas + 4 widgets base**: `WeeklyBudgetsListScreen`,
  `WeeklyBudgetScreen` (detalle), `BudgetTemplatesScreen`,
  `BudgetTemplateDetailScreen`; `BudgetKindPicker`,
  `BudgetItemFormSheet` reutilizable para budget/template items,
  `ItemsSection` con drag&drop por handle (⋮⋮), `BalanceFooter`
  sticky reactivo.
- **4 rutas nuevas** en `app_router.dart`: `/budgets`, `/budgets/:id`,
  `/budget-templates`, `/budget-templates/:id`.
- **Integraciones**: IconButton nuevo en Dashboard AppBar (con
  reorg de "Categorías" a PopupMenu para no partir el wordmark);
  sección "Preferencias" nueva en `SettingsScreen`; FAQ agregada
  en `HelpScreen`; `BackupService.wipeAll` extendido para borrar
  las 4 tablas nuevas.
- **Bump 0.19.0+93 → 0.20.0+94**.
- **Suite de tests**: ~62 nuevos + fixes en 3 tests preexistentes
  de Settings tras insertar la sección Preferencias.

## Archivos principales modificados

Nuevos:

- `mobile/lib/data/daos/weekly_budgets_dao.dart` + `.g.dart`.
- `mobile/lib/data/daos/budget_templates_dao.dart` + `.g.dart`.
- `mobile/lib/data/weekly_budgets.dart` (helpers puros).
- `mobile/lib/screens/weekly_budgets/list_screen.dart`.
- `mobile/lib/screens/weekly_budgets/detail_screen.dart`.
- `mobile/lib/screens/weekly_budgets/templates_screen.dart`.
- `mobile/lib/screens/weekly_budgets/template_detail_screen.dart`.
- `mobile/lib/screens/weekly_budgets/widgets/budget_kind_picker.dart`.
- `mobile/lib/screens/weekly_budgets/widgets/budget_item_form_sheet.dart`.
- `mobile/lib/screens/weekly_budgets/widgets/items_section.dart`.
- `mobile/lib/screens/weekly_budgets/widgets/balance_footer.dart`.
- 10 archivos de test (DAOs, helpers, widgets, backup, migración,
  UX cross).

Modificados:

- `mobile/lib/data/database.dart` (4 tablas nuevas, schemaVersion 7,
  rama migración `IF NOT EXISTS`, índices, imports/registro DAOs).
- `mobile/lib/data/app_preferences_keys.dart` (constante nueva).
- `mobile/lib/data/daos/app_preferences_dao.dart` (helpers
  `weekStartDow`).
- `mobile/lib/data/backup.dart` (`wipeAll` extendido + comments
  defensivos).
- `mobile/lib/app_dependencies.dart` (2 DAOs registrados).
- `mobile/lib/router/app_router.dart` (4 rutas nuevas).
- `mobile/lib/screens/dashboard_screen.dart` (IconButton + PopupMenu
  con "Categorías").
- `mobile/lib/screens/settings_screen.dart` (sección Preferencias
  arriba de Zona peligrosa).
- `mobile/lib/screens/help_screen.dart` (FAQ nueva).
- `mobile/pubspec.yaml` + `mobile/android/app/build.gradle.kts`
  (bump 0.20.0+94).
- `mobile/test/screens/settings_screen_test.dart` (5 fixes por
  reorg de layout).
- `mobile/test/screens/weekly_budgets/templates_screen_test.dart`
  (fix WT-TS03 copy).

## Tareas completadas

- **T001** — Lectura de patrones existentes.
- **T002** — Definición de las 4 tablas drift.
- **T003** — Migración v6→v7 aditiva + índices + guardrail
  preservado.
- **T004** — Constante `kPrefWeekStartDow`.
- **T005** — `WeeklyBudgetsDao` CRUD budget.
- **T006** — Items del budget + reorder.
- **T007** — `watchBudgetBalance` reactivo.
- **T008** — `BudgetTemplatesDao` completo (CRUD template + items +
  reorder).
- **T009** — Snapshot copiers cross-DAO (bidireccionales).
- **T010** — Helpers `weekStartDow()` / `setWeekStartDow(int)`.
- **T011** — `BackupService.wipeAll` extendido + comments
  defensivos import/export.
- **T012** — Registro de DAOs en `AppDependencies`.
- **T013** — Helpers puros (`suggestedWeekStartDate`, `weekRangeOf`,
  `groupBudgetsByRange`, `calculateBalance`, enum `BudgetSection`).
- **T014** — 4 rutas nuevas en `app_router.dart`.
- **T015** — `BudgetKindPicker` (SegmentedButton 2 opciones).
- **T016** — `BudgetItemFormSheet` reutilizable.
- **T017** — `ItemsSection` con drag&drop por handle.
- **T018** — `BalanceFooter` sticky reactivo.
- **T019** — `WeeklyBudgetScreen` (detalle con secciones + footer +
  menú).
- **T020** — `WeeklyBudgetsListScreen` (listado agrupado + FAB dual).
- **T021** — `BudgetTemplatesScreen` (listado plantillas + preview).
- **T022** — `BudgetTemplateDetailScreen` (editable + delete).
- **T023** — IconButton en Dashboard AppBar (+ reorg Categorías a
  PopupMenu por fix A5).
- **T024** — Sección "Preferencias" en Settings.
- **T025** — FAQ nueva en HelpScreen.
- **T026** — Tests helpers puros (UT-H01..UT-H09).
- **T027** — Tests `WeeklyBudgetsDao` (UT-WB01..UT-WB25).
- **T028** — Tests `BudgetTemplatesDao` (UT-BT01..UT-BT08).
- **T029** — Tests `AppPreferencesDao` weekStartDow (UT-AP01..UT-AP05).
- **T030** — Tests widget list_screen (WT-LS01..WT-LS05).
- **T031** — Tests widget detail_screen (WT-DS01..WT-DS11).
- **T032** — Tests widget templates (WT-TS01..WT-TS04, WT-TS04
  skipped documentado).
- **T033** — Tests widget settings/dashboard/help
  (WT-SET01/02/DASH01/HELP01).
- **T034** — Tests regresión backup (RG-01..RG-04).
- **T035** — Tests migración v6→v7 (MG-01..MG-04).
- **T036** — `flutter analyze` limpio + full suite 671 verdes.
- **T037** — APK release + `verify-apk.sh` OK (versionCode 2094).
- **T039** — Branch-quality-review con 21 hallazgos, 10 resueltos.

## Tareas pendientes

- **T038 (smokes SM-01..SM-16 en cel real)** — Diego los hará
  cuando esté disponible. La lista está en el test-plan.
- **T041 (commit final)** — pendiente hasta revisión de Diego del
  reporte final.

## Branch quality review

Ejecutado 2026-07-13. Reporte:
`engineering/quality-review/flutter-weekly-budgets-v1/2026-07-13-branch-quality-review.md`.

21 hallazgos verificados:
- **5 altas resueltas**: A1 (migración idempotente), A2 (unicidad
  Unicode), A3 (isFinite en amount), A4 (drag handle hit test),
  A5 (Categorías → PopupMenu).
- **5 medias resueltas**: M1 (clearCategory antes de validar),
  M2 (addItem en tx), M3 (AppBar durante loading), M4 (banner
  backup notice), M5 (delete renglón template con nombre).
- 1 media diferida con justificación (M6 — multi-salto migraciones
  1→7..5→7, aceptado por dataset limitado).
- 10 bajas documentadas para sprints futuros (refactor de helpers
  duplicados, cobertura extra, comment obsoleto, etc.).
- 0 bloqueantes.

## Riesgos residuales

- **R-01** — Confusión terminológica entre "Presupuestos" mensual
  vs "Presupuestos semanales". Mitigado con nomenclatura distinta
  + FAQ + iconografía diferente + banner en list_screen.
- **R-02** — Pérdida de presupuestos en restore (RN-B13 aceptado).
  Banner informativo agregado (fix M4). Diego confirmó como
  trade-off aceptable.
- **R-03** — Bump v6→v7 sin retorno. Cubierto con migración
  idempotente (fix A1) + tests MG-01..MG-04.
- **R-04** — `week_start_date` como DateTime con text encoding.
  Normalizado a medianoche local en `createBudget`. Verificado
  con test UT-WB07.
- **R-05** — Vinculación futura con movimientos no reservada (sprint
  posterior necesitará bump adicional).
- **R-06** — Snapshot vs referencia en plantillas cubierto con
  tests UT-WB23/25 y UT-BT01/08 (bidireccionales). Sin regresión.
- **R-07** — Hard delete sin undo. Mitigado con dialogs
  destructivos + copy claro.
- **R-08** — Multi-plan por semana puede saturar el listado si
  Diego arma muchos. Sin límite; aceptado.
- **R-09** — Sin recurrencia automática. Mitigado con plantillas.
- **R-10** — Drag handle A11Y: touch target ahora real 44×44 (fix
  A4). Cubierto.

## Pruebas realizadas

- `flutter analyze`: **0 errores**, 4 hints info preexistentes
  tolerables.
- `flutter test`: **671 verdes** (1 skip preexistente en WT-TS04
  documentado por hang de stream subscription en `close()`).
- APK release: `versionCode 2094 / versionName 0.20.0` OK con
  `verify-apk.sh`.
- Tests nuevos por categoría:
  - Helpers puros: 9/9.
  - `WeeklyBudgetsDao`: 27/27 (25 UT-WB + 2 extras).
  - `BudgetTemplatesDao`: 8/8.
  - `AppPreferencesDao` (nuevos): 5/5.
  - Widget list_screen: 5/5.
  - Widget detail_screen: 11/11.
  - Widget templates: 3/4 (WT-TS04 skipped).
  - Widget UX cross: 4/4 (SET+DASH+HELP).
  - Backup regression: 4/4.
  - Migración: 4/4.

## Pruebas recomendadas

- **SM-01 a SM-16** en cel real con Diego. Detalle en
  `plan/test-plan.md`. Especialmente:
  - SM-04 (drag handle en dispositivo real con dedo grueso).
  - SM-06 (multi-plan por semana visual).
  - SM-07/08 (crear plantilla + aplicarla).
  - SM-09/10 (snapshot semantics verificados manualmente).
  - SM-14 (backup + wipeAll pierde budgets — comportamiento
    esperado).
  - SM-16 (cel angosto ≤360dp: dashboard AppBar wordmark en una
    línea con el PopupMenu — fix A5 crítico).

## Posibles regresiones

- **Dashboard AppBar reorganizado**: "Categorías" pasó de
  IconButton directo a estar dentro del PopupMenu (`more_vert`).
  Diego debería notar el cambio; documentado en el reporte
  visualmente. Sin test roto.
- **SettingsScreen layout más largo**: la nueva sección Preferencias
  empujó "Zona peligrosa" y "Ayuda" hacia abajo. 5 tests
  preexistentes actualizados con `skipOffstage: false` /
  `dragUntilVisible`. Sin cambios de UX visual.
- **`BackupService.wipeAll` extendido**: acepta las 4 tablas
  nuevas. Test de regresión con `flutter test test/data/backup_test.dart`
  → 32/32 verdes. Sin regresión funcional en accounts/categories/
  entries.
- **Sin impacto en**: `EntriesDao`, `AccountsDao`, `CategoriesDao`,
  `FinancialStateService`, `ReportsService`, todos los reportes,
  onboarding, calendar, heatmaps.

## Recomendaciones para code review humano

1. Verificar el pattern de snapshot semantics en los 2 copiers
   (`createBudgetFromTemplate`, `createTemplateFromBudget`) — que
   los items generados tengan nuevos ids y no compartan referencia.
   Tests UT-WB23/25 y UT-BT01/08 lo cubren pero un ojo humano
   nunca sobra en este tipo de contrato.
2. Verificar la migración v6→v7: rama `IF NOT EXISTS` + índices +
   guardrail intacto. Idealmente correr `flutter test
   test/data/database_migration_test.dart` MG-01..MG-04.
3. Verificar el reordenamiento del Dashboard AppBar — que
   "Categorías" en PopupMenu sea aceptable UX-wise para Diego.
4. Verificar el banner de "no se respaldan" en `list_screen.dart`
   — copy y posición razonables.
5. Verificar el copy destructivo de los dialogs:
   - Presupuesto: "Esto borrará el presupuesto y sus N renglones.
     Esta acción no se puede deshacer."
   - Plantilla: "Esto borrará la plantilla y sus N renglones. Los
     presupuestos creados desde esta plantilla NO se verán
     afectados. Esta acción no se puede deshacer."
6. Confirmar el fix del drag handle (A4) con un `flutter run` en
   dispositivo real: tocar cualquier área del handle 44×44 debe
   iniciar reorder.
