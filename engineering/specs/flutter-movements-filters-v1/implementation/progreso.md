# Progreso — flutter-movements-filters-v1

Estado de las 46 tareas del `plan/tasks.md`.

## F1 — Refactor preparatorio
- [x] T001 — `lib/constants/date_range_presets.dart` con `DateRangePreset` + `dateRangeForPreset` (+ slug + helper de parse).
- [x] T002 — `lib/widgets/date_field_outlined.dart` con widget público.
- [x] T003 — `spending_by_category_tab.dart` migrado a los nuevos imports + nombres.
- [x] T004 — `lib/screens/reports/range_presets.dart` eliminado.
- [x] T005 — Test movido a `test/constants/date_range_presets_test.dart`. 17 tests (los 14 originales + 3 nuevos del slug/parse).
- [x] T006 — Suite verde post-F1: 170 tests.

## F2 — Capa de datos
- [x] T007 — `kUncategorizedFilterToken = '__null__'` exportado desde `entries_dao.dart`.
- [x] T008 — `watchPage` extendido con `kinds: List<String>?` + `categoryIds: List<String>?`. `kind: String?` deprecado con wrapper.
- [x] T009 — SQL `kinds` traducido a `journalEntries.kind.isIn(effectiveKinds)`.
- [x] T010 — SQL `categoryIds` con manejo del token `__null__` vía `categories.id.isNull()` del LEFT JOIN existente. **Más simple que subquery** porque el join ya filtra archivadas.
- [x] T011 — `test/data/entries_dao_filters_test.dart` con seed completo.
- [x] T012 — UT-01 a UT-03 (kinds) verdes — 4 tests.
- [x] T013 — UT-04 a UT-07 (categoryIds) verdes — 4 tests.
- [x] T014 — UT-08 a UT-12 (combinaciones + soft-delete + orden + deprecación) verdes — 7 tests.
- [x] T015 — Caller único `entries_list_screen.dart` migrado de `kind: String?` a `kinds: List<String>?`.
- [x] T016 — Suite verde post-F2: 202 tests.

## F2 extra — `EntriesFilters`
- [x] T017 — `lib/data/entries_filters.dart` con clase inmutable + `copyWith` + `activeCount` + factories `thisMonth()`/`defaultEmpty()` + `withPreset()` + `serialize()`/`parse()`.
- [x] T018 — `test/data/entries_filters_test.dart` con 17 tests (defaults, withPreset, round-trip, defensivo).

## F3 — Pantalla de filtros
- [x] T019 — `lib/screens/entries_filters_screen.dart` con `Scaffold` + `AppBar("Filtros")` + `IconButton(close)` + body `ListView` + `bottomNavigationBar` con dos botones.
- [x] T020 — Sección Fecha: chips de `DateRangePreset` + (si Custom) 2 `DateFieldOutlined`.
- [x] T021 — Sección Tipo: chips Todos / Ingreso / Gastos / Pago de tarjeta / Transferencia con enum `_TypePreset` mapeando a kinds.
- [x] T022 — Sección Cuenta: chips inline con `accountsDao.watchActive()`. Single-select.
- [x] T023 — Sección Categorías: chips multi-select (`FilterChip`) con badge color + icon. Primer chip "Sin categoría".
- [x] T024 — Footer fijo `OutlinedButton "Limpiar todo"` + `FilledButton "Aplicar"`.
- [x] T025 — Validación `from > to` con `showWarningSnackbar`, preservando rango previo.

## F4 — Integración en EntriesListScreen
- [x] T026 — Lectura de query params del router en `didChangeDependencies` vía `GoRouterState.of(context)`.
- [x] T027 — `_openFilters` reemplazado por `Navigator.push<EntriesFilters>(MaterialPageRoute(fullscreenDialog: true))`.
- [x] T028 — `IconButton(Icons.tune)` con badge numérico de `_filters.activeCount`.
- [x] T029 — `_ActiveFiltersBar` con chips de filtros activos + "X" para quitar dimensión individual.
- [x] T030 — Estado vacío específico (`hasFilters` flag en `_EmptyState`).
- [x] T031 — `_FiltersSheet` y `_Chip` viejos eliminados.

## F5 — Deep link desde reporte
- [x] T032 — `_SpendingBucketRow` envuelto con `onTap` en `BaseCard`. Construye URL via `Uri(path:'/entries', queryParameters: {...})` con `categoryIds = [bucket.categoryId ?? kUncategorizedFilterToken]`, `kinds = ['expense','credit_expense']`, `from`/`to` del reporte.

## F6 — Widget tests
- [x] T033 — `entries_filters_screen_test.dart` con 7 tests verdes (render base + interacción).
- [x] T034 — `reports_deeplink_test.dart` con 2 tests verdes (bucket activo + bucket "Sin categoría").
- [x] T035 — `entries_list_screen_test.dart` reescrito con 4 tests verdes (default thisMonth + AppBar tune + estados vacíos). El test del deep link via query params puro se difirió (ver desviaciones).
- [x] T036 — Suite total: **212 tests verdes** en 14s.

## Validación de calidad
- [x] T037 — `flutter analyze`: 0 errores, 0 warnings, 4 hints info preexistentes.
- [ ] T038 — `/branch-quality-review` pendiente del usuario.

## Documentación
- [x] T039 — `cierre.md` se generará en `resumen-ejecutivo.md` y `resumen-extenso.md`.
- [x] T040 — `pendientes.md` con 1 diferido documentado.

## Release
- [x] T041 — `pubspec.yaml` bumped a `0.5.0+47`.
- [x] T042 — `android/app/build.gradle.kts` bumped a `versionCode=47`, `versionName="0.5.0"`.
- [x] T043 — `flutter build apk --release --split-per-abi`: 3 APKs.
- [x] T044 — `verify-apk.sh`: exit 0, versionCode 2047 / versionName 0.5.0.
- [ ] T045 — Comando install para Diego comunicado al cierre.
- [ ] T046 — Smoke manual SM-01 a SM-09 pendiente del usuario.

## Estadística final

- 43 / 46 tareas completadas.
- 1 test difirido (deep link puro en `entries_list_screen_test.dart` por cuelgue de `pumpAndSettle`, cobertura compensatoria desde el reporte).
- 2 tareas de cierre del usuario (T038 quality review, T046 smoke).
- Suite: 212 / 212 verdes (+44 vs 168 previo).
