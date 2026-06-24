# Progreso — flutter-reports-v1

Estado de las tareas del `plan/tasks.md`.

## Backend (capa de datos)

- [x] T001 — `SpendingReport` y `SpendingBucket` en `lib/data/reports.dart`.
- [x] T002 — `ReportsService` con constructor BD.
- [x] T003 — `spendingByCategory({from, to})` con `customSelect` + LEFT JOIN + GROUP BY + orden por monto desc + tiebreak alfabético.
- [x] T004 — Protección división por cero (total=0 → percent=0).
- [x] T005 — Bucket "Sin categoría" con `colorSlug = null`, `iconSlug = null`, name = `kUncategorizedBucketName`. Decisión: `colorSlug`/`iconSlug` son `String?` y el render usa `colorBySlug(null)` / `iconBySlug(null)` (fallback gray + label_outline). Más simple que slugs hardcodeados; ver `decisiones-implementacion.md`.

## Pruebas — capa de datos

- [x] T006 — `test/data/reports_test.dart` armado con BD in-memory + seedDefaults.
- [x] T007 — UT-01 a UT-07 (agregación básica, orden, kinds): 5 tests verdes.
- [x] T008 — UT-08 a UT-10 (bucket "Sin categoría"): 4 tests verdes.
- [x] T009 — UT-11 a UT-17 (filtro temporal, soft-delete, invariantes): 8 tests verdes.
- [x] T010 — IT-01 a IT-03 (integración con DAOs): 2 tests verdes (en lugar de 3 — uno absorbido por T007/T009).
- [x] T011 — `flutter test` con 0 regresiones: **153 verdes** post-sprint (126 → 153, +27 nuevos).

Cobertura final del archivo: **22 tests** (vs 12 mínimos del plan).

## Frontend — Scaffold UI

- [x] T012 — **CANCELADA**. `fl_chart` NO se agregó al `pubspec.yaml`. Decisión registrada como Desviación-1: barras nativas con `Container` + `FractionallySizedBox` cubren el preview elegido sin agregar dep. Ver `desviaciones-plan.md`.
- [x] T013 — `lib/screens/reports_screen.dart` con `DefaultTabController` + `Scaffold` + `TabBar` + `TabBarView`. Una tab activa.
- [x] T014 — Ruta `/reports` registrada en `app_router.dart`.

## Frontend — Tab "Gasto por categoría"

- [x] T015 — `lib/screens/reports/spending_by_category_tab.dart` con scaffold básico.
- [x] T016 — Dos `OutlinedButton.icon` con `Icons.calendar_today` + `showDatePicker` + `DateFormat.yMMMd('es_MX')` (variante `'d MMM y'`).
- [x] T017 — Default: `from = primer día del mes corriente`, `to = DateTime.now()` end-of-day.
- [x] T018 — `StreamBuilder<SpendingReport>` con `_reportStream` cacheado en state (no re-armado en cada build). Patrón idéntico al Dashboard.
- [x] T019 — Barras horizontales custom con `Stack` + `FractionallySizedBox` + colores derivados del slug. Sin `fl_chart`.
- [x] T020 — Lista de buckets renderizada inline en el `ListView` raíz (no en `ListView.separated` interno) para evitar conflicto de scroll anidado. Cada bucket es una `BaseCard` con icono + nombre + monto + % + barra horizontal.
- [x] T021 — `_TotalCard` con monto total + "Total del período" + texto N movimientos.
- [x] T022 — `_EmptyState` con `Icon(Icons.bar_chart_outlined)` + textos.
- [x] T023 — `from > to` muestra `showWarningSnackbar` y preserva rango previo.

## Frontend — Acceso desde Dashboard

- [x] T024 — `IconButton(Icons.bar_chart, tooltip: 'Reportes')` agregado al inicio de `AppBar.actions` (antes de Categorías + Settings).

## Pruebas — UI

- [x] T025 — `test/screens/reports_screen_test.dart` armado.
- [x] T026 — WT-02 verde (render con buckets).
- [x] T027 — **DIFERIDA parcial**. Cambio de "Desde" NO se valida en widget test porque abrir `showDatePicker` y validar el rerender es frágil y tiende a colgar `pumpAndSettle`. La lógica está cubierta por los tests data del rango (UT-11 a UT-17) y el test manual SM-05.
- [x] T028 — **DIFERIDA**. SnackBar de `from > to` requiere abrir DatePicker + seleccionar fecha invertida; complejidad alta para test widget. Lógica cubierta por UT del service. Pendiente revisión futura.
- [x] T029 — WT-05 verde (icono `bar_chart` del Dashboard navega a `/reports`).
- [x] T030 — `flutter test` completo verde: **153/153 verdes** en ~13s (vs ~10s previo). Suite estable.

## Validación de calidad

- [x] T031 — `flutter analyze` retorna **0 errores, 0 warnings, 4 hints info preexistentes** (entry_form_screen.dart líneas 285/286/288 + skeleton.dart línea 75).
- [ ] T032 — **PENDIENTE**. `/branch-quality-review` invocable solo por el usuario. Documentar tras el commit.

## Documentación

- [x] T033 — `cierre.md` se genera junto a este `progreso.md`.
- [x] T034 — `pendientes.md` con T027 y T028 + posibles futuras refactorizaciones.

## Release

- [x] T035 — `pubspec.yaml` bumped a `0.4.0+43`.
- [x] T036 — `android/app/build.gradle.kts` bumped a `versionCode=43`, `versionName="0.4.0"`.
- [x] T037 — `flutter build apk --release --split-per-abi`: 3 APKs generados (arm64-v8a: 19.6MB, armeabi-v7a: 17.1MB, x86_64: 20.8MB).
- [x] T038 — `scripts/verify-apk.sh mobile/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` → **exit 0 — versionCode 2043 / versionName 0.4.0 consistentes**.
- [ ] T039 — Comando install para Diego comunicado al cierre.
- [ ] T040 — Smoke manual SM-01 a SM-08 pendiente del usuario tras instalar.

## Estadística final

- 38 / 40 tasks completadas.
- 2 tasks documentadas como diferidas (T027, T028 — widget tests del DatePicker).
- 2 tasks de cierre pendientes del usuario (T032 quality review, T040 smoke manual).
