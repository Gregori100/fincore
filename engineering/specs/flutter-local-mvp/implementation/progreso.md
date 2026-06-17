# Progreso de implementación — flutter-local-mvp

Estado de cada tarea del plan.

## Fase 0 — Pre-pivote

- [x] T001 DESCARTADA por decisión del 2026-06-17 (Diego arranca de cero sin migrar datos del backend).

## Fase 1 — Preservar legacy

- [x] T002 — `git checkout -b legacy/web-and-online-flutter main` + push a origin. **Pre-commit obligatorio**: el cliente online (`mobile/`) y la spec `flutter-mvp-cliente/` nunca habían sido commiteados al repo. Commit `b02eb42 feat(mobile): cliente Flutter online del sprint flutter-mvp-cliente` (8933 insertions, 98 archivos) hecho antes de crear la rama legacy. Diego ejecutó los pushes manualmente por restricciones de auth HTTPS.
- [x] T003 — verificado con `git show origin/legacy/web-and-online-flutter:backend/composer.json`, `:mobile/lib/api/auth_api.dart` y `:frontend/package.json`. Los 3 archivos responden con contenido válido. Rama legacy preserva todo el stack previo al pivote.

## Fase 2 — Destruir legacy en main

- [ ] T004 — borrado masivo del legacy en `main`.
- [ ] T005 — verificación post-borrado de que la rama legacy sigue accesible.

## Fase 3 — Fundación Flutter local

- [ ] T006 — `flutter create` mobile/.
- [ ] T007 — build.gradle.kts applicationId, versionCode=2, versionName=0.2.0, minSdk=24, targetSdk=35.
- [ ] T008 — AndroidManifest INTERNET, label FinCore.
- [ ] T009 — pubspec.yaml con deps drift/go_router/file_picker/share_plus/etc.
- [ ] T010 — build.yaml con store_date_time_values_as_text.
- [ ] T011 — analysis_options.yaml.
- [ ] T012 — scripts run-linux/build-apk/codegen.

## Fase 4 — Portado desde legacy

- [ ] T013 — port theme/.
- [ ] T014 — port constants/.
- [ ] T015 — port widgets/ compartidos.

## Fase 5 — Capa de datos

- [ ] T016 — database.dart con tablas drift + índices.
- [ ] T017 — codegen build_runner.
- [ ] T018 — accounts_dao.
- [ ] T019 — categories_dao.
- [ ] T020 — entries_dao.
- [ ] T021 — financial_state.dart con streams.
- [ ] T022 — seed.dart con Bolsa + 10 categorías default.
- [ ] T023 — bootstrap.dart con hasBolsa.
- [ ] T024 — backup.dart con JSON v1.
- [ ] T025 — AppDependencies simplificado.

## Fase 6 — Router y pantallas

- [ ] T026 — router con redirect a /first-run.
- [ ] T027 — main.dart con DI completo.
- [ ] T028 — first_run_screen.dart.
- [ ] T029 — dashboard_screen portado.
- [ ] T030 — accounts_list_screen portado.
- [ ] T031 — account_form_screen portado.
- [ ] T032 — account_picker + category_picker nuevos.
- [ ] T033 — categories_list + category_form portados.
- [ ] T034 — entries_list_screen portado.
- [ ] T035 — entry_form_screen portado.
- [ ] T036 — settings_screen nuevo (backup export/import).

## Fase 7 — Tests

- [ ] T037 — sqlite_override.dart.
- [ ] T038 — test_app helper + factories.
- [ ] T039 — daos_test.
- [ ] T040 — financial_state_test.
- [ ] T041 — backup_test.
- [ ] T042 — financial_invariants_test.
- [ ] T043 — first_run_screen_test.
- [ ] T044 — dashboard_screen_test.
- [ ] T045 — entry_form_screen_test.
- [ ] T046 — flutter test all green ≥50.
- [ ] T047 — flutter analyze 0 issues.

## Fase 8 — Build release + smokes manuales

- [ ] T048 — manifest validado con aapt.
- [ ] T049 — build APK release < 50 MB.
- [ ] T050 — Diego instala APK + smoke Arrancar limpio + 5 kinds + edit + cancel.
- [ ] T051 — Diego smoke modo avión + export/import propio.

## Fase 9 — Documentación + QR

- [ ] T052 — README mobile/.
- [ ] T053 — CLAUDE.md raíz reescrito.
- [ ] T054 — README raíz reescrito + .gitignore simplificado.
- [ ] T055 — branch-quality-review.
