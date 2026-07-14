# Progreso — flutter-language-cleanup-v1

Bitácora de tareas ejecutadas. NO reemplaza `plan/tasks.md`; solo registra el estado real de la ejecución.

- [x] **T000** — Discovery de integration_test: strings `'Ingresá un nombre.'` y `'Ya tenés una cuenta/categoría con ese nombre'` no existen en `lib/`; la app real muestra `'Ingresar un nombre.'` y `'Ya existe una cuenta/categoría con ese nombre.'`. Los 5 matchers están obsoletos desde un sprint anterior.
- [x] **T001** — Widgets (4 archivos): `kind_picker`, `entries_paginated_list`, `entries_empty_state`, `error_snackbar`. Migrados a español neutral.
- [x] **T002** — Screens (5 archivos): `entry_form_screen`, `entries_filters_screen`, `saved_views_list_screen`, `reports/monthly_average_tab`, `onboarding_screen` (docstring citando copy real ya neutral).
- [x] **T003** — Data layer (1 archivo): `daos/saved_views_dao.dart`.
- [x] **T004** — 15 ocurrencias de "acá" → "aquí" en 11 archivos de `lib/` + 4 de `test/`. También `querés → quieres` + `pasá → pasar` en `widget_test_harness.dart`.
- [x] **T005** — `settings_screen.dart:501` `"FAQ sobre kinds, reportes y backup."` → `"FAQ sobre tipos de movimientos, reportes, presupuestos y respaldo."`.
- [x] **T006** — 5 matchers de `integration_test/account_form_test.dart` (2 + 1 comentario) y `integration_test/category_form_test.dart` (2). Basado en el hallazgo T000.
- [x] **T007** — `mobile/test/language/no_voseo_test.dart` creado. Regex ajustada tras falso positivo (`partí` matcheaba `partía` por `\b` Unicode).
- [x] **T008** — `CLAUDE.md` "Convenciones del repo" con línea nueva sobre español neutral + referencia al test.
- [x] **T009** — Bump `0.21.1+98` en `pubspec.yaml` y `build.gradle.kts`.
- [x] **T010** — `flutter analyze --no-fatal-infos`: verde (3 hints pre-existentes tolerados).
- [x] **T011** — `flutter test`: 681/681 verdes. 3 iteraciones (post-copy: 678/681, post-matchers: 681/681, confirmación: 681/681).
- [ ] **T012** — Smoke desktop (`flutter run -d linux`). Pendiente de Diego.
- [x] **T013** — `flutter build apk --release --split-per-abi` lanzado en background.
- [x] **T014** — Revisión equivalente manual a `branch-quality-review` (skill no expuesta): grep guardrails + analyze + test + verificación de excepciones documentadas.
- [x] **T015** — Docs de cierre: `implementation-review.md`, `resumen-ejecutivo.md`, `resumen-extenso.md`, este `progreso.md`.
- [ ] **T016** — Commit final. Pendiente de aprobación de Diego (regla del proyecto). Nota: Sprint 1 sigue sin commitear también; Diego decide si va un commit combinado o dos separados.

## Total ejecutado

- **26 archivos modificados** (`lib/` + `test/` + `integration_test/`).
- **1 archivo nuevo** (`mobile/test/language/no_voseo_test.dart`).
- **3 archivos de raíz** (`CLAUDE.md`, `pubspec.yaml`, `build.gradle.kts`).
- **5 archivos de spec/implementation** (`engineering/specs/flutter-language-cleanup-v1/`).
- **Tests**: 681/681 verdes (680 previos + 1 nuevo).
- **flutter analyze**: verde.
- **Cero regresión** funcional o visual esperada (todos los cambios son de copy).
