# Tasks — flutter-movements-filters-v1

Orden y dependencias derivadas del plan. Tareas pequeñas con criterio de terminado verificable.

## Frontend — F1 Refactor preparatorio

- [ ] T001 Frontend: crear `mobile/lib/constants/date_range_presets.dart` con copia de `mobile/lib/screens/reports/range_presets.dart` renombrando `ReportRangePreset` → `DateRangePreset`, `reportRangeForPreset` → `dateRangeForPreset`, `ReportRangePresetLabel` → `DateRangePresetLabel`.
  RF: RF-018
  Depende de: ninguna
  Paralelizable: no
  Criterio de terminado: archivo nuevo compila aislado (sin referencias en el resto del repo todavía).

- [ ] T002 Frontend: crear `mobile/lib/widgets/date_field_outlined.dart` con `_DateFieldOutlined` extraído de `spending_by_category_tab.dart`, renombrado a `DateFieldOutlined` (público).
  RF: RF-019
  Depende de: ninguna
  Paralelizable: sí (con T001)
  Criterio de terminado: archivo compila; sin referencias todavía.

- [ ] T003 Frontend: actualizar `mobile/lib/screens/reports/spending_by_category_tab.dart` para importar de `lib/constants/date_range_presets.dart` y `lib/widgets/date_field_outlined.dart`. Eliminar el `_DateFieldOutlined` privado y todas las referencias a `ReportRangePreset`.
  RF: RF-018, RF-019
  Depende de: T001, T002
  Paralelizable: no
  Criterio de terminado: `flutter analyze` limpio sobre el archivo; `flutter test test/screens/reports_screen_test.dart` verde.

- [ ] T004 Frontend: eliminar `mobile/lib/screens/reports/range_presets.dart` (helper viejo).
  RF: RF-018
  Depende de: T003
  Paralelizable: no
  Criterio de terminado: archivo borrado; no hay otros imports al path viejo.

## Pruebas — F1

- [ ] T005 Pruebas: mover/copiar `mobile/test/screens/reports/range_presets_test.dart` → `mobile/test/constants/date_range_presets_test.dart` con imports actualizados al nuevo path + nombres `DateRangePreset`.
  RF: RF-018
  Depende de: T001, T004
  Paralelizable: no
  Criterio de terminado: archivo nuevo verde con los 14 tests preservados; archivo viejo eliminado.

- [ ] T006 Pruebas: correr `flutter test` completo tras F1. Validar 168 verdes con migración del helper. 0 regresiones.
  RF: ninguna (gate)
  Depende de: T005
  Paralelizable: no
  Criterio de terminado: suite verde.

## Backend (capa de datos) — F2

- [ ] T007 Backend: definir constante exportada `kUncategorizedFilterToken = '__null__'` en `mobile/lib/data/daos/entries_dao.dart` (top-level del archivo).
  RF: RF-004
  Depende de: T006
  Paralelizable: no
  Criterio de terminado: constante accesible desde otros archivos vía import.

- [ ] T008 Backend: extender `EntriesDao.watchPage` con params `kinds: List<String>?` y `categoryIds: List<String>?`. Mantener `kind: String?` como `@Deprecated`. Si `kind != null` y `kinds == null`, internamente armar `kinds = [kind]`.
  RF: RF-001, RF-005, RF-017
  Depende de: T007
  Paralelizable: no
  Criterio de terminado: firma compila; los callers existentes con `kind` siguen funcionando.

- [ ] T009 Backend: implementar query SQL para `kinds`: si `kinds.isNotEmpty`, agregar `WHERE kind IN (?, ?, ...)` usando placeholders dinámicos de drift (`Variable.withString` por cada).
  RF: RF-002
  Depende de: T008
  Paralelizable: no
  Criterio de terminado: query rinde correcto cuando `kinds` tiene 1, 2, 3 elementos.

- [ ] T010 Backend: implementar query SQL para `categoryIds`: si contiene `kUncategorizedFilterToken`, generar `(category_id IN (...) OR category_id IS NULL OR category_id IN (SELECT id FROM categories WHERE deleted_at IS NOT NULL))`. Si no, solo `WHERE category_id IN (...)`.
  RF: RF-003
  Depende de: T009
  Paralelizable: no
  Criterio de terminado: query rinde correcto en los 4 escenarios (vacío, sin `__null__`, solo `__null__`, mix).

## Pruebas — F2

- [ ] T011 Pruebas: crear `mobile/test/data/entries_dao_filters_test.dart` con setUp de BD in-memory + seed (Bolsa + 2 cuentas + 4 categorías + 1 archivada).
  RF: RF-020
  Depende de: T010
  Paralelizable: no
  Criterio de terminado: archivo de test arranca con harness limpio + 1 test smoke verde.

- [ ] T012 Pruebas: UT-01 a UT-03 (`kinds` con 1, 2, vacío / null).
  RF: RF-020, RN-M01
  Depende de: T011
  Paralelizable: sí (con T013, T014)
  Criterio de terminado: 3 tests verdes.

- [ ] T013 Pruebas: UT-04 a UT-07 (`categoryIds` con 1, 2, `__null__`, mix).
  RF: RF-020, RN-M02, RN-M03
  Depende de: T011
  Paralelizable: sí (con T012, T014)
  Criterio de terminado: 4 tests verdes.

- [ ] T014 Pruebas: UT-08 a UT-12 (combinación AND, soft-delete, orden, compatibilidad `kind` deprecado).
  RF: RF-020
  Depende de: T011
  Paralelizable: sí (con T012, T013)
  Criterio de terminado: 5 tests verdes.

- [ ] T015 Pruebas: migrar callers existentes de `kind: String?` a `kinds: List<String>?`. Archivos: `entries_list_screen.dart` (vía T020), `entries_list_screen_test.dart` (2 tests), cualquier otro caller.
  RF: RF-017
  Depende de: T014
  Paralelizable: no
  Criterio de terminado: `grep -rn "watchPage(kind:" mobile/` retorna 0 matches.

- [ ] T016 Pruebas: correr `flutter test` completo tras F2. Validar 168 + 12 nuevos = 180 verdes esperado.
  RF: ninguna (gate)
  Depende de: T015
  Paralelizable: no
  Criterio de terminado: suite verde.

## Backend — modelo `EntriesFilters`

- [ ] T017 Backend: crear `mobile/lib/data/entries_filters.dart` con clase inmutable `EntriesFilters` (`final` fields: `from`, `to`, `kinds`, `accountId`, `categoryIds`, `datePreset`). Métodos: `copyWith`, `activeCount`, factory `thisMonth()`, factory `defaultEmpty()`, `withPreset(DateRangePreset)`, `serialize() → Map<String,String>`, static `parse(Map<String,String>) → EntriesFilters`.
  RF: RF-006 (apoyo)
  Depende de: T006 (F1 cerrado)
  Paralelizable: sí (con tareas de F2 backend, distintas áreas)
  Criterio de terminado: clase compila; tests siguientes pueden importarla.

- [ ] T018 Pruebas: crear `mobile/test/data/entries_filters_test.dart` con UT-13 a UT-17 (factory `thisMonth`, round-trip serialize/parse, omisión de defaults, parse de URL malformado, deduplicación).
  RF: RF-020
  Depende de: T017
  Paralelizable: sí (con tests del DAO en F2)
  Criterio de terminado: 5 tests verdes.

## Frontend — F3 Pantalla de filtros

- [ ] T019 Frontend: crear `mobile/lib/screens/entries_filters_screen.dart` con scaffold (`Scaffold`, `AppBar("Filtros")` con `IconButton(Icons.close)` en leading), body `ListView` placeholder, `bottomNavigationBar` con dos botones placeholder.
  RF: RF-006
  Depende de: T017
  Paralelizable: no
  Criterio de terminado: pantalla compila; se puede instanciar con un `EntriesFilters` inicial.

- [ ] T020 Frontend: implementar sección Fecha en el panel: chips con `DateRangePreset.values`. Si activo es `custom`, mostrar 2 `DateFieldOutlined` debajo.
  RF: RF-007
  Depende de: T019
  Paralelizable: no
  Criterio de terminado: tap en chips cambia el rango. Custom muestra los date fields. Cambio de Custom dispara DatePicker.

- [ ] T021 Frontend: implementar sección Tipo en el panel: chips (Todos / Ingreso / Gastos / Pago de tarjeta / Transferencia). "Gastos" mapea a `kinds = ['expense', 'credit_expense']`; los otros a 1 kind.
  RF: RF-008, RN-M01
  Depende de: T019
  Paralelizable: sí (con T020)
  Criterio de terminado: tap en chip actualiza el state local. Solo un chip seleccionado a la vez.

- [ ] T022 Frontend: implementar sección Cuenta en el panel: chips inline con `accountsDao.watchActive()`. Chip "Todas" primero. Single-select.
  RF: RF-009
  Depende de: T019
  Paralelizable: sí (con T020, T021)
  Criterio de terminado: chips se renderean desde el stream. Tap actualiza state.

- [ ] T023 Frontend: implementar sección Categorías en el panel: chips multi-select con badge (color + icono). Primer chip "Sin categoría" con icono `label_off_outlined` color gris.
  RF: RF-010, RN-M03
  Depende de: T019
  Paralelizable: sí (con T020, T021, T022)
  Criterio de terminado: tap toggle de cada chip. Multi-select funcional.

- [ ] T024 Frontend: implementar footer del panel: `Row(OutlinedButton "Limpiar todo", FilledButton "Aplicar")`. "Limpiar todo" resetea al default sin pop. "Aplicar" hace `Navigator.pop<EntriesFilters>(context, _editing)`.
  RF: RF-011
  Depende de: T020, T021, T022, T023
  Paralelizable: no
  Criterio de terminado: ambos botones funcionan según contrato. Tap "Aplicar" cierra panel; tap "Limpiar" resetea sin cerrar.

- [ ] T025 Frontend: validación `from > to` en cambio de DatePicker — `showWarningSnackbar` con "El rango no es válido" + preservar rango anterior. Reusar patrón de `SpendingByCategoryTab`.
  RF: RF-007, RN-M04
  Depende de: T020
  Paralelizable: sí (con T024)
  Criterio de terminado: tap "Aplicar" tras rango inválido → SnackBar, no se cierra panel.

## Frontend — F4 Integración en EntriesListScreen

- [ ] T026 Frontend: en `entries_list_screen.dart`, leer query params del router via `GoRouterState.of(context).uri.queryParameters` en `didChangeDependencies`. Parsear a `EntriesFilters`. Si no hay params, default `EntriesFilters.thisMonth()`.
  RF: RF-012, RF-013
  Depende de: T017
  Paralelizable: no
  Criterio de terminado: navegar a `/entries?from=2026-06-01&to=2026-06-30` carga el filtro inicial.

- [ ] T027 Frontend: reemplazar `_openFilters` (showModalBottomSheet) por `Navigator.push<EntriesFilters>(MaterialPageRoute(builder: (_) => EntriesFiltersScreen(initial: _filters)))`. Al pop con resultado, hacer `setState(() => _filters = result)` y rearmar stream.
  RF: RF-006 (integración)
  Depende de: T024, T026
  Paralelizable: no
  Criterio de terminado: tap en icono del AppBar abre el panel full-screen; "Aplicar" devuelve filtros y aplica.

- [ ] T028 Frontend: cambiar `IconButton(Icons.filter_list)` por `IconButton(Icons.tune)` con badge numérico. Badge muestra `_filters.activeCount` cuando > 0.
  RF: RF-015
  Depende de: T027
  Paralelizable: no
  Criterio de terminado: badge visible cuando hay filtros activos; desaparece cuando se limpia.

- [ ] T029 Frontend: agregar fila de chips de filtros activos arriba de la lista. Para cada dimensión con valor (fecha distinto del default, kinds, accountId, categoryIds), un chip con texto resumido + "X" tappeable que remueve solo esa dimensión.
  RF: RF-014
  Depende de: T028
  Paralelizable: no
  Criterio de terminado: chips renderean correcto, tap en "X" remueve solo esa dimensión y rearma stream.

- [ ] T030 Frontend: agregar estado vacío específico "No hay movimientos con esos filtros. Probá ajustarlos." cuando `entries.isEmpty && _filters.activeCount > 0`. El existente "No hay movimientos." se mantiene para BD sin entries en absoluto.
  RF: ninguna (UX detail; cubre CB-11 del spec)
  Depende de: T029
  Paralelizable: no
  Criterio de terminado: dos estados vacíos distintos según hay filtros o no.

- [ ] T031 Frontend: eliminar `_FiltersSheet` y `_Chip` helpers locales en `entries_list_screen.dart`. Ahora viven en `entries_filters_screen.dart`.
  RF: RF-006 (cleanup)
  Depende de: T030
  Paralelizable: no
  Criterio de terminado: archivo no contiene `_FiltersSheet` ni el `_Chip` viejo; `flutter analyze` limpio.

## Frontend — F5 Deep link desde reporte

- [ ] T032 Frontend: en `spending_by_category_tab.dart`, envolver `_SpendingBucketRow` en `InkWell` o agregar `onTap` al `BaseCard`. Construir URL con `Uri(path: '/entries', queryParameters: {...}).toString()`. Para bucket "Sin categoría", `categoryIds = ['__null__']`; para bucket real, `categoryIds = [bucket.categoryId!]`. `kinds = 'expense,credit_expense'`. `from`/`to` ISO 8601.
  RF: RF-016, RN-M08
  Depende de: T026
  Paralelizable: no
  Criterio de terminado: tap en bucket navega a `/entries` con la URL correcta. La lista se filtra al instante.

## Pruebas — F6 Widget tests

- [ ] T033 Pruebas: crear `mobile/test/screens/entries_filters_screen_test.dart` con WT-01 a WT-08.
  RF: RF-021
  Depende de: T031
  Paralelizable: sí (con T034, T035)
  Criterio de terminado: 8 widget tests verdes.

- [ ] T034 Pruebas: crear `mobile/test/screens/reports_deeplink_test.dart` con WT-09 (categoría) y WT-10 (Sin categoría).
  RF: RF-022
  Depende de: T032
  Paralelizable: sí (con T033, T035)
  Criterio de terminado: 2 widget tests verdes.

- [ ] T035 Pruebas: extender `mobile/test/screens/entries_list_screen_test.dart` con WT-11 (badge), WT-12 (chips activos "X"), WT-13 (deep link pre-carga), WT-14 (estado vacío con filtros).
  RF: RF-021 + cobertura adicional
  Depende de: T031
  Paralelizable: sí (con T033, T034)
  Criterio de terminado: 4 nuevos tests verdes + tests previos de `entries_list_screen` migrados a la nueva API.

- [ ] T036 Pruebas: correr `flutter test` completo. Validar 168 + 16 nuevos mínimo = ≥ 184 verdes.
  RF: ninguna (gate)
  Depende de: T033, T034, T035
  Paralelizable: no
  Criterio de terminado: suite completa verde.

## Validación de calidad

- [ ] T037 Validación: `flutter analyze` retorna 0 errores, 0 warnings.
  RF: CA-10
  Depende de: T036
  Paralelizable: no
  Criterio de terminado: output limpio salvo hints info preexistentes documentados.

- [ ] T038 Validación: invocar `/branch-quality-review flutter-movements-filters-v1` para revisión exhaustiva.
  RF: ninguna (gate)
  Depende de: T037
  Paralelizable: no
  Criterio de terminado: reporte generado en `engineering/quality-review/flutter-movements-filters-v1/`; hallazgos críticos resueltos.

## Documentación

- [ ] T039 Documentación: crear `engineering/specs/flutter-movements-filters-v1/implementation/cierre.md` con resumen del sprint, decisiones tomadas durante implementación (ej. si se mantuvo o cambió el default de `/entries`).
  RF: ninguna (gate)
  Depende de: T038
  Paralelizable: no
  Criterio de terminado: archivo creado siguiendo formato de cierres anteriores.

- [ ] T040 Documentación: crear `engineering/specs/flutter-movements-filters-v1/implementation/pendientes.md` si surgieron diferidos (paginación, filtros por monto, búsqueda textual, multi-account). Documentar con condición de re-activación.
  RF: ninguna (gate)
  Depende de: T039
  Paralelizable: sí (con T041)
  Criterio de terminado: archivo creado si hay pendientes; omitir si no.

## Release

- [ ] T041 Release: bump `mobile/pubspec.yaml` a `version: 0.5.0+47`.
  RF: RF-023
  Depende de: T038
  Paralelizable: sí (con T042)
  Criterio de terminado: línea actualizada.

- [ ] T042 Release: bump `mobile/android/app/build.gradle.kts` a `versionCode=47`, `versionName="0.5.0"`.
  RF: RF-023
  Depende de: T038
  Paralelizable: sí (con T041)
  Criterio de terminado: ambas líneas actualizadas.

- [ ] T043 Release: ejecutar `flutter build apk --release --split-per-abi` desde `mobile/`.
  RF: RF-023
  Depende de: T041, T042
  Paralelizable: no
  Criterio de terminado: 3 APKs generados.

- [ ] T044 Release: ejecutar `scripts/verify-apk.sh build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`.
  RF: RF-023, CA-11
  Depende de: T043
  Paralelizable: no
  Criterio de terminado: exit 0 con versionCode=2047 / versionName=0.5.0.

- [ ] T045 Release: documentar comando `adb install -r` para Diego al final del sprint.
  RF: ninguna (gate)
  Depende de: T044
  Paralelizable: no
  Criterio de terminado: comando comunicado.

- [ ] T046 Release: smoke manual SM-01 a SM-09 por Diego tras instalar. Confirmación de:
  - Panel abre rápido (CME-04).
  - Deep link desde reporte funciona.
  - Chips de filtros activos con "X" funcionan.
  - Estado vacío con filtros distinto del genérico.
  RF: CME-04, CME-05
  Depende de: T045
  Paralelizable: no
  Criterio de terminado: Diego confirma cada smoke item.

## Resumen de paralelización

- F1 (T001, T002): paralelizables entre sí.
- F2 tests (T012, T013, T014): paralelizables tras T011.
- F3 secciones del panel (T020, T021, T022, T023): paralelizables tras T019.
- F6 widget tests (T033, T034, T035): paralelizables tras F4+F5.
- Release (T041, T042): paralelizables.

Total tareas: **46**. Estimado de horas: **F1=1.5h, F2=3h, F3=4h, F4=2.5h, F5=1h, F6=2h, Doc+QR+Release=1.5h ≈ 15.5h efectivas**. Sprint mediano.
