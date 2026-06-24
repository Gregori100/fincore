# Tasks — flutter-reports-v1

Orden y categorías derivadas del plan. Tareas pequeñas con dependencia real declarada.

## Backend (capa de datos Flutter)

- [ ] T001 Backend: crear `mobile/lib/data/reports.dart` con clases `SpendingReport` y `SpendingBucket` inmutables.
  RF: RF-002, RF-003
  Depende de: ninguna
  Paralelizable: no
  Criterio de terminado: archivo compila, modelos exportados, `flutter analyze` limpio sobre el archivo nuevo.

- [ ] T002 Backend: implementar `ReportsService` en `mobile/lib/data/reports.dart` con constructor que recibe `AppDatabase`.
  RF: RF-001
  Depende de: T001
  Paralelizable: no
  Criterio de terminado: clase instanciable con BD in-memory en un test stub.

- [ ] T003 Backend: implementar `ReportsService.spendingByCategory({from, to})` con `customSelect` + JOIN + agregación por categoría.
  RF: RF-001, RF-004, RF-005
  Depende de: T002
  Paralelizable: no
  Criterio de terminado: el método retorna `SpendingReport` con buckets ordenados por monto desc y tiebreak alfabético; query usa LEFT JOIN y filtra correctamente por kind/deleted_at/rango/categoría archivada (NULL bucket).

- [ ] T004 Backend: lógica de cálculo de `percent` en `SpendingBucket` evitando división por cero cuando `total == 0`.
  RF: RF-003
  Depende de: T003
  Paralelizable: no
  Criterio de terminado: con buckets vacíos, retorna `total = 0, buckets = []`; con buckets, `percent` suma 1.0 ± epsilon.

- [ ] T005 Backend: agregar metadatos del bucket "Sin categoría" (`name = 'Sin categoría'`, `colorSlug = 'gray'`, `iconSlug = 'category_outlined'`) cuando `categoryId IS NULL` o categoría archivada.
  RF: RN-R03, RN-R04, RN-R08
  Depende de: T003
  Paralelizable: no
  Criterio de terminado: bucket de NULL/archivada usa los metadatos correctos sin colisión con categorías activas.

## Base de datos

No aplica. Sin cambios de schema.

## Pruebas — capa de datos

- [ ] T006 Pruebas: crear `mobile/test/data/reports_test.dart` con setup de BD in-memory + harness existente.
  RF: RF-015
  Depende de: T003
  Paralelizable: no
  Criterio de terminado: archivo de test arranca con BD limpia + seed defaults + 1 test smoke verde.

- [ ] T007 Pruebas: tests unitarios UT-01 a UT-07 de `ReportsService.spendingByCategory` (BD vacía, expense único, agregación misma categoría, orden por monto, tiebreak alfabético, mezcla expense+credit_expense, exclusión transfer/debt_payment/income).
  RF: RF-015, RN-R01, RN-R02, RN-R05, RN-R07
  Depende de: T006
  Paralelizable: sí (con T008, T009)
  Criterio de terminado: 7 tests verdes.

- [ ] T008 Pruebas: tests unitarios UT-08 a UT-10 del bucket "Sin categoría" (entry con NULL, entry con categoría archivada, mezcla NULL + archivadas).
  RF: RF-015, RN-R03, RN-R04
  Depende de: T006
  Paralelizable: sí (con T007, T009)
  Criterio de terminado: 3 tests verdes.

- [ ] T009 Pruebas: tests unitarios UT-11 a UT-17 (fuera de rango, soft-delete, límites inclusivos, percent suma 1.0, invariante total).
  RF: RF-015, RN-R05, RN-R07
  Depende de: T006
  Paralelizable: sí (con T007, T008)
  Criterio de terminado: 7 tests verdes.

- [ ] T010 Pruebas: tests de integración IT-01 a IT-03 (DAOs + ReportsService end-to-end).
  RF: RF-015
  Depende de: T007, T008, T009
  Paralelizable: no
  Criterio de terminado: 3 tests verdes; valida que cancelar entry y archivar categoría se reflejan en el reporte.

- [ ] T011 Pruebas: correr `flutter test` completo y validar 126 + nuevos verdes, 0 regresiones.
  RF: ninguna (gate)
  Depende de: T007, T008, T009, T010
  Paralelizable: no
  Criterio de terminado: suite completa verde.

## Frontend — Scaffold UI

- [ ] T012 Frontend: agregar `fl_chart: ^0.69.0` en `mobile/pubspec.yaml` (sección `dependencies`).
  RF: RF-014
  Depende de: T011
  Paralelizable: no
  Criterio de terminado: `flutter pub get` resuelve sin conflictos.

- [ ] T013 Frontend: crear `mobile/lib/screens/reports_screen.dart` con `Scaffold` + `AppBar` "Reportes" + `TabBar` y `TabBarView` con una tab placeholder.
  RF: RF-007
  Depende de: T012
  Paralelizable: no
  Criterio de terminado: pantalla compila y monta; placeholder de tab visible en `flutter run -d linux`.

- [ ] T014 Frontend: registrar ruta `/reports` en `mobile/lib/router/app_router.dart` apuntando a `ReportsScreen`.
  RF: RF-006
  Depende de: T013
  Paralelizable: no
  Criterio de terminado: navegación `context.push('/reports')` desde cualquier sub-pantalla funciona; `flutter analyze` limpio.

## Frontend — Tab "Gasto por categoría"

- [ ] T015 Frontend: crear `mobile/lib/screens/reports/spending_by_category_tab.dart` con scaffold básico (Column + header de fechas + placeholder de chart + placeholder de tabla).
  RF: RF-008
  Depende de: T014
  Paralelizable: no
  Criterio de terminado: la tab placeholder de T013 se reemplaza por este widget; renderiza con defaults sin crashear.

- [ ] T016 Frontend: integrar dos `OutlinedButton.icon` para pickers "Desde" y "Hasta" en el header con `DateFormat.yMMMd('es_MX')` para mostrar el rango.
  RF: RF-008, RF-009
  Depende de: T015
  Paralelizable: no
  Criterio de terminado: tap en cada botón abre `showDatePicker`; al seleccionar fecha, el texto del botón se actualiza con la nueva fecha.

- [ ] T017 Frontend: implementar default del rango al abrir la tab (`from = primer día del mes corriente 00:00`, `to = DateTime.now()` end-of-day).
  RF: RF-009
  Depende de: T016
  Paralelizable: no
  Criterio de terminado: al abrir la tab, los botones muestran las fechas default correctas.

- [ ] T018 Frontend: integrar `FutureBuilder<SpendingReport>` que invoca `ReportsService.spendingByCategory` con `from`/`to` actuales.
  RF: RF-010
  Depende de: T017, T003
  Paralelizable: no
  Criterio de terminado: cambio de fechas re-invoca el service y rerenderiza; durante el await muestra `SkeletonCard`.

- [ ] T019 Frontend: integrar `BarChart` horizontal con `fl_chart`. `BarTouchData(enabled: false)`. Alto = `min(buckets.length * 48, 400)` px. Colores derivados de `bucket.colorSlug` vía `categoryColorFromSlug`.
  RF: RF-008
  Depende de: T018
  Paralelizable: no
  Criterio de terminado: chart renderiza visualmente con barras correctas, sin interactividad ni animaciones perpetuas.

- [ ] T020 Frontend: implementar tabla con `ListView.separated` + `SpendingBucketTile` por bucket (badge + nombre + monto + %).
  RF: RF-008
  Depende de: T018
  Paralelizable: sí (con T019)
  Criterio de terminado: tabla renderiza con todos los buckets en orden desc por monto.

- [ ] T021 Frontend: card de header con total acumulado (`AmountFormatter`) + texto "Total del período" + texto "X movimientos".
  RF: RF-008
  Depende de: T018
  Paralelizable: sí (con T019, T020)
  Criterio de terminado: card visible arriba del chart con datos formateados.

- [ ] T022 Frontend: implementar estado vacío con `Center` + icono `Icons.bar_chart_outlined` + texto "No hay gastos en el rango seleccionado" + sugerencia.
  RF: RF-011
  Depende de: T018
  Paralelizable: sí (con T019, T020, T021)
  Criterio de terminado: cuando `buckets.isEmpty`, la tab muestra estado vacío en lugar de chart vacío.

- [ ] T023 Frontend: validar `from > to` tras DatePicker. Mostrar `SnackBar` warning con `showErrorSnackbar` o equivalente. Revertir al rango previo.
  RF: RF-012, RN-R06
  Depende de: T017
  Paralelizable: sí (con T019, T020, T021, T022)
  Criterio de terminado: seleccionar fechas invertidas dispara SnackBar y el rango previo se preserva.

## Frontend — Acceso desde Dashboard

- [ ] T024 Frontend: agregar `IconButton(icon: Icons.bar_chart, tooltip: 'Reportes')` en el `AppBar.actions` del `DashboardScreen`, antes del icono de Settings. `onPressed: () => context.push('/reports')`.
  RF: RF-013
  Depende de: T014
  Paralelizable: sí (con cualquier task de F3)
  Criterio de terminado: tap del icono navega a `/reports`.

## Pruebas — UI

- [ ] T025 Pruebas: crear `mobile/test/screens/reports_screen_test.dart` con setup `pumpFincoreApp` + 1 test smoke (BD vacía, push `/reports`, find `ReportsScreen`).
  RF: RF-016
  Depende de: T022
  Paralelizable: no
  Criterio de terminado: 1 test verde de smoke; estructura del archivo lista para sumar tests.

- [ ] T026 Pruebas: agregar WT-02 (render con buckets — seed con 3 expenses en 2 categorías, validar chart + tabla + total).
  RF: RF-016
  Depende de: T025
  Paralelizable: sí (con T027, T028)
  Criterio de terminado: test verde.

- [ ] T027 Pruebas: agregar WT-03 (cambio de fecha "Desde" repega la query).
  RF: RF-016
  Depende de: T025
  Paralelizable: sí (con T026, T028)
  Criterio de terminado: test verde.

- [ ] T028 Pruebas: agregar WT-04 (selección inválida `from > to` muestra SnackBar y preserva rango).
  RF: RF-016, RN-R06
  Depende de: T025
  Paralelizable: sí (con T026, T027)
  Criterio de terminado: test verde.

- [ ] T029 Pruebas: extender `mobile/test/screens/dashboard_screen_test.dart` con WT-05 (tap icono `bar_chart` → navega a `/reports`).
  RF: RF-017
  Depende de: T024
  Paralelizable: sí (con T026, T027, T028)
  Criterio de terminado: test verde + suite completa verde.

- [ ] T030 Pruebas: correr `flutter test` completo. Valida 126 + 17 nuevos (mínimo) = ≥143 verdes, 0 regresiones.
  RF: ninguna (gate)
  Depende de: T026, T027, T028, T029
  Paralelizable: no
  Criterio de terminado: suite completa verde.

## Validación de calidad

- [ ] T031 Validación: `flutter analyze` debe quedar en 0 errores, 0 warnings.
  RF: CA-10
  Depende de: T030
  Paralelizable: no
  Criterio de terminado: output limpio salvo hints info preexistentes documentados (skeleton.dart, entry_form_screen.dart líneas 285/286/288).

- [ ] T032 Validación: invocar `/branch-quality-review` para revisión exhaustiva del sprint antes del commit formal.
  RF: ninguna (gate)
  Depende de: T031
  Paralelizable: no
  Criterio de terminado: reporte generado en `engineering/quality-review/flutter-reports-v1/`; hallazgos críticos resueltos.

## Documentación

- [ ] T033 Documentación: crear `engineering/specs/flutter-reports-v1/implementation/cierre.md` con resumen del sprint, lecciones aprendidas, decisiones tomadas durante implementación (ej. si se hizo F3 con `Future` o `Stream`).
  RF: ninguna (gate)
  Depende de: T032
  Paralelizable: no
  Criterio de terminado: archivo creado siguiendo formato de cierres anteriores (`flutter-ui-test-coverage-v2/implementation/cierre.md`).

- [ ] T034 Documentación: si surgieron pendientes o diferidos (ej. reactividad con Stream postpuesta, índice nuevo de `journal_entries`), agregar `engineering/specs/flutter-reports-v1/implementation/pendientes.md` con justificación y condición de re-activación.
  RF: ninguna (gate)
  Depende de: T033
  Paralelizable: sí (con T035)
  Criterio de terminado: si no hay pendientes, omitir archivo. Si hay, documentar al menos 1 entrada con `Cuando atacar:`.

## Release

- [ ] T035 Release: bump `mobile/pubspec.yaml` a `version: 0.4.0+43`.
  RF: RF-018
  Depende de: T032
  Paralelizable: sí (con T036)
  Criterio de terminado: línea actualizada correctamente.

- [ ] T036 Release: bump `mobile/android/app/build.gradle.kts` a `versionCode = 43` y `versionName = "0.4.0"`.
  RF: RF-018
  Depende de: T032
  Paralelizable: sí (con T035)
  Criterio de terminado: ambas líneas actualizadas.

- [ ] T037 Release: ejecutar `flutter build apk --release --split-per-abi` desde `mobile/`.
  RF: RF-019
  Depende de: T035, T036
  Paralelizable: no
  Criterio de terminado: 3 APKs generados en `build/app/outputs/flutter-apk/`.

- [ ] T038 Release: ejecutar `scripts/verify-apk.sh build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`.
  RF: RF-019, CA-11
  Depende de: T037
  Paralelizable: no
  Criterio de terminado: exit 0 con versionCode=2043 (prefix 2000 arm64) y versionName=0.4.0.

- [ ] T039 Release: documentar comando `adb install -r` para Diego al final del sprint.
  RF: ninguna (gate)
  Depende de: T038
  Paralelizable: no
  Criterio de terminado: comando exacto comunicado al usuario.

- [ ] T040 Release: smoke manual SM-01 a SM-08 por Diego tras instalar. Confirmación visual.
  RF: CME-04, CME-05
  Depende de: T039
  Paralelizable: no
  Criterio de terminado: Diego confirma que el reporte rinde correctamente con sus datos reales del mes en curso.

## Resumen de paralelización

- F1 (data): T007, T008, T009 paralelizables entre sí.
- F3 (tab): T019, T020, T021, T022, T023 paralelizables entre sí tras T018.
- F4 (icono Dashboard): T024 paralelizable con todo F3.
- F5 (UI tests): T026, T027, T028, T029 paralelizables entre sí tras T025.
- F6 (release): T035, T036 paralelizables entre sí.

Total de tareas: **40**. Estimado de horas (orientativo): **F1=2h, F2=1h, F3=5h, F4=0.5h, F5=2.5h, F6=1h, Doc+QR=1h ≈ 13h efectivas**. Coherente con la banda de 12-15h del spec.
