# Implementation Review: flutter-reports-v1

## Resumen de lo implementado

Nueva pantalla `/reports` con `TabBar` extensible y primera tab activa **"Gasto por categoría"**: rango libre vía dos `DatePicker` (default mes corriente → hoy), card de total acumulado, lista de buckets ordenados por monto desc con barra horizontal proporcional + badge + nombre + monto + %. Acceso vía icono `bar_chart` nuevo en el AppBar del Dashboard. Reactivo: cualquier cambio en `journal_entries` o `categories` rehidrata el reporte.

Capa de datos: `ReportsService` puro en `lib/data/reports.dart` con `Stream<SpendingReport>` derivado de `customSelect` con LEFT JOIN + GROUP BY. Independiente de `FinancialStateService` (no contamina los streams del Dashboard).

Aditivo puro: sin schema bump (`schemaVersion = 2` se mantiene), sin migraciones, sin cambios en DAOs existentes ni en BackupService.

## Archivos principales modificados

Nuevos:
- `mobile/lib/data/reports.dart` (~190 líneas): `ReportsService` + `SpendingReport` + `SpendingBucket`.
- `mobile/lib/screens/reports_screen.dart` (~35 líneas): scaffold con `TabBar`.
- `mobile/lib/screens/reports/spending_by_category_tab.dart` (~340 líneas): tab principal.
- `mobile/test/data/reports_test.dart` (~440 líneas): 22 tests.
- `mobile/test/screens/reports_screen_test.dart` (~130 líneas): 4 widget tests.

Modificados:
- `mobile/lib/app_dependencies.dart`: agrega `reportsService` al bag.
- `mobile/lib/router/app_router.dart`: registra ruta `/reports`.
- `mobile/lib/screens/dashboard_screen.dart`: agrega `IconButton(Icons.bar_chart)` al AppBar.
- `mobile/test/screens/dashboard_screen_test.dart`: agrega test del icono Reportes.
- `mobile/pubspec.yaml`: bump versión a `0.4.0+43`.
- `mobile/android/app/build.gradle.kts`: bump versionCode=43, versionName=0.4.0.

## Tareas completadas

38 de 40 tareas del `plan/tasks.md` completadas. Detalle en `progreso.md`. Highlights:

- **F1 (capa data)**: T001–T011 verdes. 22 tests cubren todos los RN.
- **F2 (scaffold)**: T013, T014 verdes. T012 cancelada (no se agrega `fl_chart` — Desviación-1).
- **F3 (tab spending)**: T015–T023 verdes. Render con `Container` + `FractionallySizedBox` para barras.
- **F4 (Dashboard)**: T024 verde.
- **F5 (widget tests)**: T025–T030 verdes (excepto T027/T028 — diferidas, cobertura por UT del service).
- **F6 (release)**: T031–T038 verdes. APK `0.4.0+43` validado por `verify-apk.sh`.

## Tareas pendientes

- **T032** (`/branch-quality-review`): invocable solo por el usuario. Recomendable antes del commit.
- **T039** (comando install): se entrega al usuario en el mensaje final del skill.
- **T040** (smoke manual SM-01 a SM-08): pendiente del usuario tras `adb install`.
- **T027 + T028** (widget tests del DatePicker): diferidas. Justificación + cobertura compensatoria en `pendientes.md` y `desviaciones-plan.md`.

## Riesgos residuales

- **RR-01** (medio): query `spendingByCategory` no probada con journal grande (5000+ entries). Si el cel real degrada, mitigación en sprint siguiente con índice nuevo `idx_journal_entries_kind_occurred` (bump schemaVersion a 3 + rama nueva en `onUpgrade`).
- **RR-02** (bajo): si Diego abre `/reports` durante un `BackupService.importFromJson` (raro: import es operación rara que requiere user action), la vista podría parpadear (stream re-emite en cada paso). No bloqueante.
- **RR-03** (bajo): el `pickFrom`/`pickTo` valida `from > to` solo *post* DatePicker. Si en una operación atómica (selección rápida) se invierten, podría haber un frame transitorio inconsistente. Recuperación: SnackBar warning + restauración del rango anterior. Test cubierto en código pero no en UI.

## Pruebas realizadas

- **22 tests data** verdes (`reports_test.dart`).
- **4 widget tests** verdes (`reports_screen_test.dart`).
- **1 widget test extra** verde (`dashboard_screen_test.dart` — RF-017).
- **Suite completa**: 153/153 verdes en ~13s.
- **`flutter analyze`**: 0 errores, 0 warnings, 4 hints info preexistentes.
- **`flutter build apk --release --split-per-abi`**: 3 APKs (arm64-v8a 19.6MB, armeabi-v7a 17.1MB, x86_64 20.8MB).
- **`scripts/verify-apk.sh ...arm64-v8a-release.apk`**: exit 0 — versionCode 2043 / versionName 0.4.0.

Detalle en `pruebas.md`.

## Pruebas recomendadas

- **Smoke manual SM-01 a SM-08** por Diego post-install (ver `pruebas.md`).
- **Performance manual**: si el journal tiene 1000+ entries, abrir `/reports` y medir tiempo de primer render. Si > 200ms, considerar índice nuevo.
- **Smoke de regresión**: re-instalar sobre el `0.3.10+42` y validar que los datos sobreviven (sin schema bump, debería).

## Posibles regresiones

- **AppBar del Dashboard**: el icono nuevo `bar_chart` se suma al final de `actions`. Tests existentes de Dashboard pasan (RF-017 incluido). Bajo riesgo.
- **`AppDependencies`**: la firma del constructor cambió (campo nuevo `reportsService`). Solo `AppDependencies.fromDatabase` se usa en producción + tests; ambos actualizados. Riesgo nulo.
- **`go_router`**: ruta nueva agregada al `routes:` sin alterar las existentes. Sin riesgo.
- **`pumpFincoreApp`**: SIN cambios al harness. Solo se documenta que `initialRoute: '/reports'` no es seguro (usar push desde Dashboard). Convención nueva, no regresión.

## Recomendaciones para code review humano

1. **`reports.dart`**: revisar la SQL del LEFT JOIN + GROUP BY. Punto crítico: `c.id IS NULL` cubre tanto category_id null en journal como categorías archivadas (RN-R03/R04). SQLite agrupa NULLs juntos en GROUP BY — comportamiento documentado en la query.

2. **`spending_by_category_tab.dart`**: el cache de `_reportStream` con `??=` en `didChangeDependencies` evita el cuelgue de `pumpAndSettle` que detectamos. Si se refactoriza la tab, mantener el patrón (no armar Stream en `build`).

3. **Loading state con `SizedBox(height: 1)`**: parece feo en código, pero es intencional (Desviación-5). NO reemplazar por Skeleton/CircularProgressIndicator sin un test que demuestre que no cuelga `pumpAndSettle`.

4. **Tests del reporte usan `context.push('/reports')` desde el Dashboard**, no `initialRoute` del harness (Desviación-4). Si se replica el patrón en otros sprints, documentar.

5. **Sin `fl_chart`**: el plan lo listaba como dep nueva, la implementación lo descarta (Desviación-1). Si Diego en el futuro pide pie chart o donut, evaluar la dep aparte.

6. **`pubspec.yaml` + `build.gradle.kts`**: bump sincronizado a `0.4.0+43` validado por `verify-apk.sh`.

7. **`/branch-quality-review`** invocable por Diego antes del commit formal. Recomendado.

Reporte detallado de `branch-quality-review` (cuando se invoque) viviría en `engineering/quality-review/flutter-reports-v1/`, no acá.
