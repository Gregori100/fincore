# Tareas — flutter-budgets-v1

## Base de datos

- [ ] T001 BD: Agregar `_validateMonthlyLimit` en `CategoriesDao` con dos errores tipados: `invalid_monthly_limit` (para valores < 0) y `invalid_monthly_limit_for_income` (para `applies_to=income + monthly_limit != null`). Llamar desde `create` y `updateCategory`.
  RF: RF-003
  Depende de: ninguna
  Paralelizable: sí (con T003)
  Criterio de terminado: UT-01..04 pasan.

## Backend

- [ ] T002 Backend: Definir clase inmutable `BudgetProgress` en `mobile/lib/data/reports.dart` con `categoryId`, `categoryName`, `colorSlug`, `iconSlug`, `monthlyLimit`, `spent`, `available`, `usedPct` (nullable), `isOverBudget`, `isWarning`, `isNoSpend`, `overBy` (nullable). Constructor factory `compute` que aplica RN-B08 y RN-B09.
  RF: RF-004
  Depende de: ninguna
  Paralelizable: sí (con T001, T003)
  Criterio de terminado: UT-13..16 pasan.

- [ ] T003 Backend: Agregar helper `monthRange(DateTime anchor) → (DateTime from, DateTime to)` en `lib/data/date_helpers.dart` para calcular rango del mes local (día 1 00:00 a día 0 del mes siguiente 23:59:59.999).
  RF: RF-005
  Depende de: ninguna
  Paralelizable: sí (con T001, T002)
  Criterio de terminado: helper funciona para meses de 28/29/30/31 días.

- [ ] T004 Backend: Agregar método `Stream<List<BudgetProgress>> watchBudgetsProgress({DateTime? monthAnchor})` a `ReportsService`. `customSelect` con LEFT JOIN entre `categories` y `journal_entries` filtrado por mes + kind. Orden RN-B11 en Dart post-fetch. Filtrar en la query las combinaciones `income + monthly_limit`.
  RF: RF-005
  Depende de: T002, T003
  Paralelizable: no
  Criterio de terminado: UT-05..12, UT-17 pasan.

## Frontend

- [ ] T005 Frontend: Agregar `_monthlyLimitCtrl = TextEditingController()` a `_CategoryFormScreenState`. Disposar en `dispose`. Cargar valor en `_loadCategory` desde `category.monthlyLimit?.toStringAsFixed(2) ?? ''`.
  RF: RF-001
  Depende de: T001
  Paralelizable: sí (con T006, T008)
  Criterio de terminado: WT-07 pasa.

- [ ] T006 Frontend: Agregar `TextFormField` "Presupuesto mensual" debajo del `AppliesToPicker` en `CategoryFormScreen`. `prefixText: '$ '`, `keyboardType: numberWithOptions(decimal: true)`, `FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))`, helper "$ 0 = meta de no gastar en esta categoría". Visible con `if (_appliesTo != 'income')`. Validator opcional: si no vacío, `_parseDecimalInput(v) != null && n >= 0`.
  RF: RF-001
  Depende de: T005
  Paralelizable: sí (con T007)
  Criterio de terminado: WT-05, WT-06 pasan.

- [ ] T007 Frontend: En `_appliesTo` callback del picker: si el nuevo valor es `'income'`, `_monthlyLimitCtrl.clear()`. En el submit, calcular `monthlyLimit = _appliesTo == 'income' ? null : _parseDecimalInput(_monthlyLimitCtrl.text)` para persistir null si vacío o si es income.
  RF: RF-002
  Depende de: T006
  Paralelizable: sí (con T008)
  Criterio de terminado: WT-08 pasa.

- [ ] T008 Frontend: Crear `mobile/lib/screens/reports/budgets_tab.dart` con `BudgetsTab` StatefulWidget:
  - `_stream` cacheado en `didChangeDependencies`.
  - `StreamBuilder<List<BudgetProgress>>`.
  - Loading = 2 `SkeletonCard`.
  - Empty = ícono + texto + `FilledButton.icon("Ir a Categorías")` → `context.push('/categories')`.
  - Data = `ListView.separated` de `_BudgetTile`.
  RF: RF-006
  Depende de: T004
  Paralelizable: sí (con T005..T007)
  Criterio de terminado: WT-01 pasa.

- [ ] T009 Frontend: Implementar `_BudgetTile` privado en `budgets_tab.dart` con `BaseCard`, `CategoryBadge` del catálogo, ring circular del % con `_UsedRing` (patrón similar a credit_cards_tab), filas gastado/límite/disponible, badge "Excedido por $X" si `isOverBudget`, badge "Sin gasto" si `isNoSpend`.
  RF: RF-007
  Depende de: T008
  Paralelizable: no
  Criterio de terminado: WT-02, WT-03, WT-04 pasan.

- [ ] T010 Frontend: Integrar séptimo tab en `mobile/lib/screens/reports_screen.dart` agregando `Tab(text: 'Presupuestos')` al TabBar y `BudgetsTab()` al TabBarView. Cambiar `length: 6` a `length: 7`. Actualizar comentario del docstring listando los 7 tabs.
  RF: RF-008
  Depende de: T008
  Paralelizable: no
  Criterio de terminado: WT-09 pasa; tab visible al final.

- [ ] T011 Frontend: Actualizar slide 3 del `OnboardingScreen`: agregar `_KindRow(icon: Icons.savings_outlined, color: FincoreColors.positive, label: 'Presupuestos')`. Actualizar párrafo a "7 reportes".
  RF: RF-009
  Depende de: ninguna (independiente)
  Paralelizable: sí
  Criterio de terminado: slide 3 visible con 7 filas.

- [ ] T012 Frontend: Actualizar `HelpScreen`: bullet nuevo en "¿Cómo se calculan los reportes?" mencionando "Presupuestos". Agregar tile nuevo "¿Cómo defino un presupuesto?" con instrucciones (editar categoría → llenar Presupuesto mensual → guardar → aparece en el reporte).
  RF: RF-010
  Depende de: ninguna
  Paralelizable: sí
  Criterio de terminado: FAQ actualizado; nuevo tile presente.

## Pruebas

- [ ] T013 Pruebas: Agregar tests UT-01..04 en `mobile/test/data/database_test.dart` grupo nuevo "CategoriesDao — monthly_limit (sprint budgets)".
  RF: RF-003
  Depende de: T001
  Paralelizable: sí (con T014..T017)
  Criterio de terminado: 4 tests pasan.

- [ ] T014 Pruebas: Agregar tests UT-05..12 + UT-17 en `mobile/test/data/reports_test.dart` grupo nuevo "watchBudgetsProgress (sprint budgets)" cubriendo empty, con presupuestos, archivada, income+budget filtrado, cálculo spent, kinds, reactividad, orden.
  RF: RF-005
  Depende de: T004
  Paralelizable: sí (con T013, T015..T017)
  Criterio de terminado: 9 tests pasan.

- [ ] T015 Pruebas: Agregar tests UT-13..16 en un archivo o dentro del grupo anterior cubriendo `BudgetProgress.compute` con los 4 estados (OK/Warning/Overdue/NoSpend + `usedPct=null` cuando límite es 0).
  RF: RF-004
  Depende de: T002
  Paralelizable: sí (con T013, T014, T016, T017)
  Criterio de terminado: 4 tests pasan.

- [ ] T016 Pruebas: Extender `mobile/test/screens/category_form_screen_test.dart` con tests WT-05..08 (visibilidad condicional del input, load correcto en edit, cambio applies_to → income limpia el valor).
  RF: RF-001, RF-002
  Depende de: T005, T006, T007
  Paralelizable: sí (con T013..T015, T017)
  Criterio de terminado: 4 tests pasan.

- [ ] T017 Pruebas: Crear `mobile/test/screens/reports/budgets_tab_test.dart` con tests WT-01..04 (empty state, con datos, badge Excedido, badge Sin gasto).
  RF: RF-006, RF-007
  Depende de: T008, T009
  Paralelizable: sí (con T013..T016)
  Criterio de terminado: 4 tests pasan.

- [ ] T018 Pruebas: Extender `mobile/test/data/backup_test.dart` con DT-01 (round-trip preserva monthly_limit) y DT-02 (income+budget legacy no crashea).
  RF: (compat)
  Depende de: T001
  Paralelizable: sí (con T013..T017)
  Criterio de terminado: 2 tests pasan.

- [ ] T019 Pruebas: Correr `flutter test` completo para validar 0 regresiones y ~434 tests verdes.
  RF: todos
  Depende de: T013..T018, T010, T011, T012
  Paralelizable: no
  Criterio de terminado: exit code 0.

## Documentación

- [ ] T020 Documentación: Actualizar `mobile/pubspec.yaml` con `version: 0.14.0+72` y comentario del sprint.
  RF: RF-011
  Depende de: T019
  Paralelizable: no
  Criterio de terminado: pubspec actualizado.

- [ ] T021 Documentación: Actualizar `mobile/android/app/build.gradle.kts` con `versionCode = 72` y `versionName = "0.14.0"`.
  RF: RF-011
  Depende de: T020
  Paralelizable: no
  Criterio de terminado: gradle actualizado.

- [ ] T022 Documentación: Actualizar `CLAUDE.md` sección "Reports" (si existe) o "Capa de datos" para mencionar el uso de `categories.monthly_limit` post-sprint.
  RF: N/A
  Depende de: T019
  Paralelizable: sí (con T020, T021)
  Criterio de terminado: nota agregada.

## Validación de calidad

- [ ] T023 Validación: Correr `flutter analyze`. Debe quedar en 0 errores (4 hints info pre-existentes tolerados).
  RF: todos
  Depende de: T019
  Paralelizable: no
  Criterio de terminado: análisis limpio.

- [ ] T024 Validación: Build APK release con `flutter build apk --release --split-per-abi` + `bash scripts/verify-apk.sh`. Confirmar versionCode 2072 y versionName 0.14.0.
  RF: RF-011
  Depende de: T020, T021
  Paralelizable: no
  Criterio de terminado: verify-apk OK.

- [ ] T025 Validación: Diego corre SM-01..09 en su cel real. Reportar cualquier issue como blocker antes del commit final.
  RF: todos
  Depende de: T024
  Paralelizable: no
  Criterio de terminado: mínimo SM-01, SM-03 confirmados por Diego.

- [ ] T026 Validación: Invocar skill `branch-quality-review` con slug `flutter-budgets-v1`. Aplicar hallazgos verificados 1 por 1.
  RF: todos
  Depende de: T025
  Paralelizable: no
  Criterio de terminado: reporte generado en `engineering/quality-review/flutter-budgets-v1/` y hallazgos reales atendidos.

- [ ] T027 Validación: Commit final con mensaje HEREDOC.
  RF: todos
  Depende de: T026
  Paralelizable: no
  Criterio de terminado: commit visible con `git log`.
