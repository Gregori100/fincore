# Tasks — flutter-reports-top-movements-v1

## F0 — Validación pre-sprint

- [ ] T001 Validación de calidad: confirmar baseline.
  RF: —
  Depende de: ninguna
  Paralelizable: no
  Criterio de terminado: `flutter test` → 251/251 verdes,
  `flutter analyze` → 0 errores.

## F1 — Modelos + servicio (data)

- [ ] T002 Backend: definir modelos `TopMovementsReport` y
  `TopMovementEntry` en `mobile/lib/data/reports.dart`.
  RF: RF-002, RF-003
  Depende de: T001
  Paralelizable: no
  Criterio de terminado:
  - `TopMovementsReport({from, to, entries})` con getter `isEmpty`.
  - `TopMovementEntry({id, kind, amount, occurredAt, description,
    category})` con `category` siendo el modelo opcional con `name`,
    `colorSlug`, `iconSlug`.

- [ ] T003 Backend: implementar `ReportsService.topMovements(from,
  to, kinds, limit=20)` con atajo defensivo y query SQL.
  RF: RF-001, RF-004
  Depende de: T002
  Paralelizable: no
  Criterio de terminado:
  - Si `kinds.isEmpty` retorna `Stream.value(TopMovementsReport(...,
    entries: []))` sin tocar BD.
  - SQL: `SELECT j.id, j.kind, j.amount, j.occurred_at, j.description,
    c.id AS cat_id, c.name AS cat_name, c.color_slug, c.icon_slug
    FROM journal_entries j LEFT JOIN categories c ON c.id =
    j.category_id AND c.deleted_at IS NULL WHERE j.kind IN (...) AND
    j.deleted_at IS NULL AND j.occurred_at BETWEEN ? AND ? ORDER BY
    j.amount DESC, j.occurred_at DESC, j.created_at DESC LIMIT ?`.
  - `readsFrom: {_db.journalEntries, _db.categories}` para
    reactividad.

- [ ] T004 Backend: implementar `_buildTopReport(rows, from, to)`
  que mapea filas a `TopMovementEntry`.
  RF: RF-002, RF-003
  Depende de: T003
  Paralelizable: no
  Criterio de terminado:
  - Para cada fila: si `cat_id` is null → `category = null`. Si no →
    construir el modelo `Category` simplificado.
  - Retorna `TopMovementsReport(from, to, entries: [...])`.

- [ ] T005 Backend: helper `_buildEmptyTopReport(from, to)` para el
  atajo defensivo.
  RF: RF-001
  Depende de: T002
  Paralelizable: si (con T003, T004)
  Criterio de terminado: retorna `TopMovementsReport(from, to,
  entries: const [])`.

## F2 — Tests del DAO

- [ ] T006 Pruebas: agregar grupos `topMovements — agregación básica`,
  `soft delete y archivos`, `limit`, `rango temporal`, `filtro de
  kinds` en `mobile/test/data/reports_test.dart`.
  RF: —
  Depende de: T005
  Paralelizable: no
  Criterio de terminado: 5 grupos vacíos esperando los tests.

- [ ] T007 Pruebas: UT-01 BD vacía → entries=[], isEmpty=true.
  RF: RN-T03, RN-T04
  Depende de: T006
  Paralelizable: si (T007..T015)
  Criterio de terminado: el reporte de un rango sin entries retorna
  lista vacía.

- [ ] T008 Pruebas: UT-02 orden por monto desc.
  RF: RN-T06
  Depende de: T006
  Paralelizable: si
  Criterio de terminado: 3 entries con montos 100, 500, 300 → ids
  ordenados según `[500, 300, 100]`.

- [ ] T009 Pruebas: UT-03 tiebreak por occurred_at desc.
  RF: RN-T06
  Depende de: T006
  Paralelizable: si
  Criterio de terminado: 2 entries con monto idéntico, occurred_at
  distintos → más reciente primero.

- [ ] T010 Pruebas: UT-04 entry soft-deleted excluido.
  RF: RN-T04
  Depende de: T006
  Paralelizable: si
  Criterio de terminado: tras cancel del DAO, entry no aparece.

- [ ] T011 Pruebas: UT-05 entry con categoría archivada → category null.
  RF: RN-T07
  Depende de: T006
  Paralelizable: si
  Criterio de terminado: tras archivar la categoría, `entry.category
  == null` pero el entry sigue en el top con su monto.

- [ ] T012 Pruebas: UT-06 limit=20 con 30 entries → retorna 20.
  RF: RN-T08
  Depende de: T006
  Paralelizable: si
  Criterio de terminado: `result.entries.length == 20`.

- [ ] T013 Pruebas: UT-07 limit=20 con 5 entries → retorna 5.
  RF: RN-T08
  Depende de: T006
  Paralelizable: si
  Criterio de terminado: `result.entries.length == 5`.

- [ ] T014 Pruebas: UT-08 + UT-09 rango inclusivo en `from` y `to`.
  RF: RN-T03
  Depende de: T006
  Paralelizable: si
  Criterio de terminado: 2 tests con entries exactos en los límites.

- [ ] T015 Pruebas: UT-10 filtro de kinds + UT-11 atajo defensivo
  kinds.isEmpty.
  RF: RN-T02
  Depende de: T006
  Paralelizable: si
  Criterio de terminado:
  - UT-10: `kinds: ['expense']` retorna solo expense.
  - UT-11: `kinds: []` retorna entries=[], isEmpty=true sin
    consultar BD (verificar con un setup que la query SQL no se
    ejecutaría, ej. cerrando la BD antes).

## F3 — UI del tab nuevo

- [ ] T016 Frontend: crear esqueleto de `TopMovementsTab` en
  `mobile/lib/screens/reports/top_movements_tab.dart`. Clonar
  lifecycle del `CashflowTab` (state `_from`, `_to`, `_preset`,
  `_selectedKinds` = `Set<String>` con los 5 inicialmente,
  `_reportStream`).
  RF: RF-005, RF-006
  Depende de: T005
  Paralelizable: no
  Criterio de terminado: archivo compila + `flutter analyze` 0
  errores. Renderea un Scaffold con `Text('TODO')`.

- [ ] T017 Frontend: integrar header de presets de fecha (chips
  `DateRangePreset.values`) + `DateFieldOutlined` cuando custom.
  RF: RF-006
  Depende de: T016
  Paralelizable: si (con T018)
  Criterio de terminado: tap en preset cambia el rango efectivo.
  Idéntico al cashflow tab.

- [ ] T018 Frontend: agregar chips de kinds multi-select debajo de
  los chips de presets de fecha. Usar `_SelectableChip` privado
  clónico del panel de filtros.
  RF: RF-006b, RN-T02
  Depende de: T016
  Paralelizable: si (con T017)
  Criterio de terminado:
  - 5 chips (Ingreso, Gasto, Gasto a tarjeta, Pago de tarjeta,
    Transferencia) en `Wrap`.
  - Tap toggla el kind en `_selectedKinds`.
  - Default: los 5 seleccionados al `initState`.

- [ ] T019 Frontend: integrar `StreamBuilder<TopMovementsReport>` con
  loading/error/empty states clonados del cashflow.
  RF: RF-011, RF-009
  Depende de: T017, T018
  Paralelizable: no
  Criterio de terminado:
  - Si `_selectedKinds.isEmpty` → empty state "Seleccioná al menos
    un tipo de movimiento.".
  - Else → StreamBuilder con loading (estático "Cargando…") /
    error / empty ("No hay movimientos en este rango.") / data.

- [ ] T020 Frontend: implementar `_TopMovementRow` que renderea cada
  entry. Clonar patrón visual del `_Row` de `EntriesPaginatedList`.
  RF: RF-007, RF-008, RN-T05
  Depende de: T019
  Paralelizable: si
  Criterio de terminado:
  - `BaseCard` con `onTap: () => context.push('/entries/${entry.id}/edit')`.
  - Icono según kind + color según kind.
  - Descripción (fallback kind.label si null).
  - Fecha + kind.label + badge (si category != null).
  - Monto con signo según kind (RN-T05): income `+$X`,
    expense/credit_expense `-$X`, otros `$X` sin signo.

## F4 — Integración al ReportsScreen

- [ ] T021 Frontend: bumpear `DefaultTabController.length: 2 → 3` +
  agregar `Tab(text: 'Top movimientos')` y `TopMovementsTab()` en
  TabBarView.
  RF: RF-010
  Depende de: T020
  Paralelizable: no
  Criterio de terminado:
  `mobile/lib/screens/reports_screen.dart` muestra los 3 tabs. Arranca
  en tab 0.

- [ ] T022 Frontend: validar que navegación a `/reports` desde
  dashboard sigue funcionando.
  RF: —
  Depende de: T021
  Paralelizable: si (con T023)
  Criterio de terminado: tap en wordmark "Reportes" → abre `/reports`
  en tab 0.

- [ ] T023 Pruebas: ajustar `mobile/test/screens/reports_screen_test.dart`
  si algún test asume length=2.
  RF: —
  Depende de: T021
  Paralelizable: si
  Criterio de terminado: tests verdes. Si usaban
  `find.byType(Tab).single` o `findsNWidgets(2)`, cambiar a
  `findsNWidgets(3)`.

## F5 — Widget tests del tab nuevo

- [ ] T024 Pruebas: crear
  `mobile/test/screens/top_movements_tab_test.dart` con setUp del
  harness + helper que navega a `/reports` y tappea el tercer tab.
  RF: —
  Depende de: T021
  Paralelizable: no
  Criterio de terminado: archivo con setUp + 1 test smoke "el tab
  monta sin error".

- [ ] T025 Pruebas: WT-01 — render con datos. Sembrar 3 entries,
  validar 3 rows visibles + orden correcto.
  RF: RF-007
  Depende de: T024
  Paralelizable: si (con T026, T027, T028)
  Criterio de terminado: `find.byType(_TopMovementRow)` o equivalente
  con `findsNWidgets(3)`.

- [ ] T026 Pruebas: WT-02 — empty state cuando rango vacío. BD sin
  entries → `find.text('No hay movimientos en este rango.')` visible.
  RF: RF-009
  Depende de: T024
  Paralelizable: si
  Criterio de terminado: assertion sobre el texto del empty state.

- [ ] T027 Pruebas: WT-03 — empty state sin kinds. Destildar los 5
  chips → `find.text('Seleccioná al menos un tipo de movimiento.')`.
  RF: RF-009, RN-T02
  Depende de: T024
  Paralelizable: si
  Criterio de terminado: assertion sobre el texto del empty state.

- [ ] T028 Pruebas: WT-04 — tap en row navega a `/entries/:id/edit`.
  Sembrar 1 entry, tap en su row, validar
  `find.byType(EntryFormScreen)`.
  RF: RF-008
  Depende de: T024
  Paralelizable: si
  Criterio de terminado: tras tap + pumpAndSettle, el form de edición
  está montado.

## F6 — Release

- [ ] T029 Validación de calidad: `flutter analyze` + `flutter test`.
  RF: —
  Depende de: T015, T023, T025, T026, T027, T028
  Paralelizable: no
  Criterio de terminado: 0 errores en analyze. ~266 tests verdes.

- [ ] T030 Documentación: bump `pubspec.yaml` a `0.8.0+60` +
  `android/app/build.gradle.kts` (versionCode 60, versionName 0.8.0).
  Nota del cambio en pubspec.
  RF: —
  Depende de: T029
  Paralelizable: si (con T031)
  Criterio de terminado: ambos archivos consistentes.

- [ ] T031 Validación de calidad: `flutter build apk --release
  --split-per-abi` + `bash scripts/verify-apk.sh`.
  RF: CM-04
  Depende de: T030
  Paralelizable: no
  Criterio de terminado: 3 APKs construidos, verify-apk OK con
  versionCode 2060 / versionName 0.8.0.

- [ ] T032 Documentación: crear
  `engineering/specs/flutter-reports-top-movements-v1/implementation/`
  con `implementation-review.md`, `resumen-ejecutivo.md`,
  `resumen-extenso.md`.
  RF: —
  Depende de: T031
  Paralelizable: no
  Criterio de terminado: 3 archivos escritos, listos para commit.
