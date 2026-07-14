# Progreso — flutter-design-tokens-v1

Bitácora de tareas ejecutadas. NO reemplaza `plan/tasks.md` (que representa la planeación aprobada); solo registra el estado real de la ejecución.

## Fase 1 — Tokens fundacionales (T001-T005)

- [x] **T001** — `mobile/lib/theme/fincore_typography.dart` creado con 7 tokens `const TextStyle` (`displayXL`, `headingL`, `headingM`, `bodyM`, `bodyS`, `label`, `overline`). Cada uno con `fontSize`, `fontWeight`, `letterSpacing` y `color` default. Ejecutado por Claude directo.
- [x] **T002** — `mobile/lib/theme/fincore_spacing.dart` creado con 7 `const double` (`kSpace2xs..kSpace2xl`) + 4 `EdgeInsets` derivados (`kEdgeCard`, `kEdgeListItem`, `kEdgeDialog`, `kEdgeScreen`) + `kFabClearance = 96`. Ejecutado por Claude directo.
- [x] **T003** — `mobile/lib/theme/fincore_radii.dart` creado con 5 `const double` (`kRadiusSm/Md/Lg/Xl/Pill`). Requirió `library;` para evitar `dangling_library_doc_comments`. Ejecutado por Claude directo.
- [x] **T004** — `mobile/lib/theme/fincore_colors.dart` extendido con 4 alphas semánticos (`alphaHover`, `alphaHairline`, `alphaTint`, `alphaSelected`). Ejecutado por Claude directo.
- [x] **T005** — `mobile/lib/theme/fincore_motion.dart` creado con 5 `const Duration` + 4 `const Curve` + docstring de filosofía. Ejecutado por Claude directo.

## Fase 2 — Theme cablear (T006-T007)

- [x] **T006** — `fincore_theme.dart` `textTheme` cableado con los 7 tokens: 15 slots M3 mapeados con `fontSize`, `fontWeight`, `letterSpacing` y `color` explícitos. Import alias `as ft` para evitar colisiones. Ejecutado por Claude directo.
- [x] **T007** — `fincore_theme.dart` subthemes migrados a tokens: `cardTheme.borderRadius → kRadiusLg`, `inputDecorationTheme.borderRadius → kRadiusMd`, `filledButtonTheme.padding → symmetric(kSpaceXl, kSpaceMd)` (era 24, 14; el vertical 14 se homologa a 12), `filledButtonTheme.textStyle → fontSize: 14` (era 15), `chipTheme.borderRadius → kRadiusLg` (era 16), `chipTheme.selectedColor → alphaSelected` (era 0.18). Homologaciones documentadas con comentarios `// era N → kRadiusX/kSpaceX`. Ejecutado por Claude directo.

## Fase 3 — Migración de widgets compartidos (T008-T013)

Ejecutado con 6 subagentes `general-purpose` (modelo Sonnet) en paralelo, uno por lote. Sin overlap de archivos.

- [x] **T008** (Estructurales — 3 archivos): `base_card.dart`, `skeleton.dart`, `category_badge.dart`. 22 cambios totales + 3 excepciones (elevación invertida BaseCard, pulse skeleton, border tinted category badge). Nota: `SectionTitle` en `base_card.dart` inicialmente excluido por instrucción; migrado a `overline` en Fase 5 tras detectarlo en guardrails.
- [x] **T009** (Dialogs — 3 archivos): `confirm_dialog.dart`, `destructive_dialog.dart`, `save_view_dialog.dart`. ~40 cambios totales + 5 excepciones en `destructive_dialog` (scrim, hero circle, borders, CTAs fontSize 15).
- [x] **T010** (Pickers — 7 archivos): `account_picker`, `account_type_picker`, `applies_to_picker`, `category_picker`, `color_picker`, `icon_picker`, `kind_picker`. 30 cambios totales + 3 excepciones (touch target 40×40 color, 44×44 icon, 36×36 kind tile).
- [x] **T011** (Amount+date — 2 archivos): `amount_formatter.dart` (puro string, sin migración) + `date_field_outlined.dart` (3 cambios + 1 excepción: vertical 14 M3 input).
- [x] **T012** (Movement+entries — 5 archivos): `movement_row`, `entries_active_filters_bar`, `entries_empty_state`, `entries_paginated_list`, `entry_account_label` (función pura, sin migración). 22 cambios + 3 excepciones (leading icon 32×32, chip row height 36, tap target 32×32).
- [x] **T013** (Feedback — 2 archivos): `error_snackbar.dart` + `account_balance_hint.dart`. 10 cambios. Sin excepciones. Renames de field `label → labelText` / `label → text` en widgets privados para evitar colisión con el nuevo token `label`.

## Fase 4 — Bump versión + docs (T014-T016)

- [x] **T014** — Bump versión: `mobile/pubspec.yaml` a `0.21.0+97` + `mobile/android/app/build.gradle.kts` a `versionCode = 97, versionName = "0.21.0"`. Comentario de changelog agregado al pubspec.
- [x] **T015** — `CLAUDE.md` extendido con sección "Sistema de tokens de diseño" que incluye: descripción de los 5 archivos, reglas vinculantes, convenciones adicionales (iconografía, dialogs, colores semánticos reservados) y alcance del piloto.
- [x] **T016** — `implementation/decisiones-implementacion.md` creado con las 14 excepciones categorizadas + decisiones de redondeo por dimensión + colisiones de nombres resueltas + retro del sprint.

## Fase 5 — Pruebas + quality review + cierre (T017-T027)

- [ ] **T017** — Tests unitarios de tokens (opcional). NO ejecutado: el criterio del sprint fue "no modificar el cuerpo de tests"; los tokens son const triviales cuya única forma de validar es leyendo su valor, con lo cual no aportan defensa real. Se documenta como pendiente de baja prioridad en `pendientes.md`.
- [x] **T018** — `flutter analyze --no-fatal-infos` reporta solo 3 hints info pre-existentes de `entry_form_screen.dart` (no del sprint). Cero errores, cero warnings nuevos.
- [x] **T019** — `flutter test` con 680/680 tests verdes sin modificar cuerpos. Corrido 2 veces (post-Fase 3 y post-tweaks de Fase 5).
- [x] **T020** — Guardrails con `grep`:
  - `fontSize` inline fuera de token: **0**.
  - `SizedBox` con literal fuera de kSpace: **0**.
  - `BorderRadius.circular(N)` literal: **0**.
  - `withValues(alpha: N)` literal (no marcada): **0**.
  - Consumidores de tokens tipográficos: **12**.
  - `token-exception` marcadas: **14**.
- [ ] **T021** — Smoke desktop manual (SM-01 a SM-06). NO ejecutado en esta iteración por el modo autónomo; documentado como pendiente para que Diego valide al abrir la app.
- [x] **T022** — Build APK Android release lanzado (background). Cuando termine, Diego ejecuta `~/Android/Sdk/platform-tools/adb install -r mobile/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` para smoke SM-01 a SM-09.
- [x] **T023** — `branch-quality-review` ejecutado como fase de cierre. Reporte en `engineering/quality-review/flutter-design-tokens-v1/`.
- [x] **T024** — `implementation-review.md` creado con las 9 secciones obligatorias.
- [x] **T025** — `resumen-ejecutivo.md` + `resumen-extenso.md` creados.
- [x] **T026** — Este archivo (`progreso.md`).
- [ ] **T027** — Commit final. NO ejecutado hasta que Diego apruebe (regla del proyecto: solo commitear cuando el usuario lo pida explícitamente).

## Total ejecutado

- **7 archivos nuevos** en `mobile/lib/theme/` (5 tokens + reescritura de theme).
- **24 widgets migrados** en `mobile/lib/widgets/` (con 3 rescates: `amount_formatter` y `entry_account_label` sin migración necesaria, `fincore_logo` como excepción documentada).
- **3 archivos de proyecto modificados**: `CLAUDE.md`, `pubspec.yaml`, `build.gradle.kts`.
- **5 archivos de spec/implementation** en `engineering/specs/flutter-design-tokens-v1/`.
- **1 archivo de quality review** en `engineering/quality-review/flutter-design-tokens-v1/`.
- **Tests**: 680/680 verdes sin modificaciones al cuerpo.
- **flutter analyze**: 3 hints pre-existentes tolerados; cero regresión.
