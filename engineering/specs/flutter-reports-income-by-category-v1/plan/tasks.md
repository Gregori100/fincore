# Tareas — flutter-reports-income-by-category-v1

## Backend

- [ ] T001 Backend: Definir clase inmutable `IncomeReport` en `mobile/lib/data/reports.dart` con `total`, `count`, `from`, `to`, `buckets` y getter `bool get isEmpty`.
  RF: RF-001
  Depende de: ninguna
  Paralelizable: sí (con T002, T003)
  Criterio de terminado: clase compila con const constructor y `isEmpty` correcto.

- [ ] T002 Backend: Definir clase inmutable `IncomeBucket` en `mobile/lib/data/reports.dart` con `categoryId` (nullable), `categoryName`, `colorSlug` (nullable), `iconSlug` (nullable), `total`, `count`, `percent`.
  RF: RF-002
  Depende de: ninguna
  Paralelizable: sí (con T001, T003)
  Criterio de terminado: clase compila con const constructor.

- [ ] T003 Backend: Agregar factory `EntriesFilters.forIncomeBucket({categoryId, from, to})` en `mobile/lib/data/entries_filters.dart`. `datePreset: custom`, `from`, `to`, `kinds: const ['income']`, `categoryIds: [categoryId ?? kUncategorizedFilterToken]`.
  RF: RF-004
  Depende de: ninguna
  Paralelizable: sí (con T001, T002)
  Criterio de terminado: UT-I11, UT-I12 pasan.

- [ ] T004 Backend: Agregar método `Stream<IncomeReport> incomeByCategory({required DateTime from, required DateTime to})` a `ReportsService` en `mobile/lib/data/reports.dart`. SQL con `LEFT JOIN c ON c.id = j.category_id AND c.deleted_at IS NULL AND c.applies_to != 'expense'`. `WHERE j.kind = 'income' AND j.deleted_at IS NULL AND j.occurred_at >= ? AND j.occurred_at <= ?`. `readsFrom: {journalEntries, categories}`. Orden RN-I06 + cálculo percent en Dart post-fetch.
  RF: RF-003
  Depende de: T001, T002
  Paralelizable: no
  Criterio de terminado: UT-I01..I10 pasan.

## Frontend

- [ ] T005 Frontend: Crear `mobile/lib/screens/reports/income_by_category_tab.dart` con `IncomeByCategoryTab` StatefulWidget. Cachea `_reportStream` en `didChangeDependencies`. State para `_from`, `_to`, `_preset`. Default preset `thisMonth`.
  RF: RF-005
  Depende de: T004
  Paralelizable: sí (con T006, T007)
  Criterio de terminado: widget compila y monta sin errores.

- [ ] T006 Frontend: Implementar header del `IncomeByCategoryTab` con chips `DateRangePreset.values` (ChoiceChip) + resumen del rango efectivo en modo no-custom + dos DatePickers en modo custom (Desde / Hasta) con validación `from ≤ to`.
  RF: RF-006, RF-007, RF-008
  Depende de: T005
  Paralelizable: no
  Criterio de terminado: WT-I03, WT-I05 pasan.

- [ ] T007 Frontend: Implementar `StreamBuilder<IncomeReport>` en `IncomeByCategoryTab` con 4 estados: `_ErrorState` (con retry), `_LoadingState` estático (SkeletonCard), `_EmptyState` contextual, `_IncomeBucketsList` con datos.
  RF: RF-009
  Depende de: T005
  Paralelizable: sí (con T006)
  Criterio de terminado: WT-I01 pasa; los 4 estados son alcanzables.

- [ ] T008 Frontend: Implementar `_IncomeBucketsList` + `_BucketTile` privados con chip categoría (36×36 color+icono), nombre, monto formateado, barra horizontal `positive` proporcional al percent, label del percent (1 decimal), count de movimientos. Tap → `context.push` a `/entries` con `EntriesFilters.forIncomeBucket(...).toDeepLink()`.
  RF: RF-010, RF-011
  Depende de: T007, T003
  Paralelizable: no
  Criterio de terminado: WT-I02, WT-I04 pasan.

- [ ] T009 Frontend: Integrar octavo tab en `mobile/lib/screens/reports_screen.dart` — `length: 7 → 8`, agregar `Tab(text: 'Ingreso por categoría')` y `IncomeByCategoryTab()` al final. Actualizar comentario doc del archivo.
  RF: RF-012
  Depende de: T005
  Paralelizable: no
  Criterio de terminado: WT-I06 pasa; el tab es visible al abrir `/reports`.

- [ ] T010 Frontend: Actualizar slide 3 del `OnboardingScreen`: agregar `_KindRow(icon: Icons.trending_up, color: FincoreColors.positive, label: 'Ingreso por categoría')`. Actualizar párrafo del slide a "8 reportes".
  RF: RF-013
  Depende de: ninguna (independiente)
  Paralelizable: sí (con T011)
  Criterio de terminado: WT-I07 pasa; slide 3 con 8 filas.

- [ ] T011 Frontend: Actualizar `HelpScreen` — el tile "¿Cómo se calculan los reportes?" pasa a mencionar "8 pestañas" y agrega bullet nuevo "Ingreso por categoría: suma de tus ingresos del período agrupados por categoría, con drill-down por bucket para ver los movimientos exactos.".
  RF: RF-014
  Depende de: ninguna (independiente)
  Paralelizable: sí (con T010)
  Criterio de terminado: WT-I08 pasa; FAQ tile lista el 8vo bullet.

## Pruebas

- [ ] T012 Pruebas: Agregar tests UT-I01..I10 en `mobile/test/data/reports_test.dart` en grupo nuevo `incomeByCategory (sprint income-by-category)`. Cubrir empty, sin categoría (3 casos merge), applies_to='both', orden, kinds excluidos, reactividad, percent, defensiva de divide-by-zero.
  RF: RF-003
  Depende de: T004
  Paralelizable: sí (con T013, T014)
  Criterio de terminado: 10 tests pasan.

- [ ] T013 Pruebas: Agregar tests UT-I11 y UT-I12 en `mobile/test/data/entries_filters_test.dart` (o donde vivan los tests del filtro; verificar el patrón existente para `forCategoryBucket`).
  RF: RF-004
  Depende de: T003
  Paralelizable: sí (con T012, T014)
  Criterio de terminado: 2 tests pasan.

- [ ] T014 Pruebas: Crear `mobile/test/screens/reports/income_by_category_tab_test.dart` con tests WT-I01..I05 (empty, con datos, cambio de rango, drill-down, validación from>to).
  RF: RF-005..011
  Depende de: T008
  Paralelizable: sí (con T012, T013)
  Criterio de terminado: 5 tests pasan.

- [ ] T015 Pruebas: Extender tests existentes de `HelpScreen` con WT-I08 y verificar que WT-H01 sigue pasando con el 8vo bullet.
  RF: RF-014
  Depende de: T011
  Paralelizable: sí (con T012..T014)
  Criterio de terminado: WT-I08 + WT-H01 verdes.

- [ ] T016 Pruebas: Verificar que los tests existentes del `OnboardingScreen` (WT-O01..O06) siguen verdes con la 8ª fila del slide 3.
  RF: RF-013
  Depende de: T010
  Paralelizable: sí (con T012..T015)
  Criterio de terminado: WT-O01..O06 verdes.

- [ ] T017 Pruebas: Correr `flutter test` completo para validar 0 regresiones y ~452 tests verdes.
  RF: todos
  Depende de: T012..T016
  Paralelizable: no
  Criterio de terminado: exit code 0.

## Documentación

- [ ] T018 Documentación: Actualizar `mobile/pubspec.yaml` con `version: 0.15.0+77` y comentario del sprint.
  RF: RF-015
  Depende de: T017
  Paralelizable: no
  Criterio de terminado: pubspec actualizado.

- [ ] T019 Documentación: Actualizar `mobile/android/app/build.gradle.kts` con `versionCode = 77` y `versionName = "0.15.0"`.
  RF: RF-015
  Depende de: T018
  Paralelizable: no
  Criterio de terminado: gradle actualizado.

## Validación de calidad

- [ ] T020 Validación: Correr `flutter analyze`. 0 errores (4 hints info pre-existentes tolerados).
  RF: todos
  Depende de: T017
  Paralelizable: no
  Criterio de terminado: análisis limpio.

- [ ] T021 Validación: Build APK release con `flutter build apk --release --split-per-abi` + `bash scripts/verify-apk.sh`. Confirmar versionCode 2077 y versionName 0.15.0.
  RF: RF-015
  Depende de: T018, T019
  Paralelizable: no
  Criterio de terminado: verify-apk OK.

- [ ] T022 Validación: Diego corre SM-01..09 en su cel real. Mínimo confirmados SM-01, SM-03, SM-05.
  RF: todos
  Depende de: T021
  Paralelizable: no
  Criterio de terminado: smokes confirmados por Diego.

- [ ] T023 Validación: Invocar skill `branch-quality-review` con slug `flutter-reports-income-by-category-v1`. Aplicar hallazgos verificados 1 por 1 con Diego.
  RF: todos
  Depende de: T022
  Paralelizable: no
  Criterio de terminado: reporte generado en `engineering/quality-review/flutter-reports-income-by-category-v1/` y hallazgos reales atendidos.

- [ ] T024 Validación: Commit final con mensaje HEREDOC describiendo el sprint.
  RF: todos
  Depende de: T023
  Paralelizable: no
  Criterio de terminado: commit visible con `git log`.
