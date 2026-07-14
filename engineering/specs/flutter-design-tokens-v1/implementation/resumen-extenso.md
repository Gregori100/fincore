# Resumen extenso — flutter-design-tokens-v1

## Contexto

Sprint 1 del roadmap definido en `engineering/design-audit-2026-07-14/consolidado.md` (auditoría de diseño ejecutada por 8 subagentes especializados en paralelo el 2026-07-14, con 166 hallazgos totales). Los hallazgos transversales S1 (tokens tipográficos ausentes), S2 (tokens de spacing ausentes) y P1-1/P1-2 del reporte sistémico convergen en la necesidad de un sistema de tokens explícito como base para todos los sprints siguientes.

`spec.md` define 11 RFs foliados. `plan/plan.md` explicita el enfoque de 4 capas (tokens → theme → widgets → docs) y la estrategia de subagentes paralelos para Fase 3. `plan/tasks.md` desglosa en 27 tasks con dependencias. `plan/test-plan.md` cubre 15 casos borde adicionales a los 15 de spec + guardrails con `grep`.

Cero preguntas bloqueantes en `checklist.md`.

## Relación con `plan.md` y `tasks.md`

Ejecución 100% alineada al plan. Fases 1-2 ejecutadas por Claude directo (T001-T007); Fase 3 ejecutada con 6 subagentes Sonnet paralelos (T008-T013), uno por lote afín sin overlap de archivos; Fase 4-5 ejecutadas por Claude directo (T014-T026). Task T027 (commit) pendiente de aprobación de Diego (regla del proyecto).

Desviaciones documentadas en `desviaciones-plan.md` (archivo separado si necesario; en este sprint no hay desviaciones grandes — solo 2 detectadas y resueltas: (a) `SectionTitle` inicialmente excluido del scope de T008 y migrado en Fase 5 tras detectarse en guardrail; (b) `destructive_dialog` con comentarios `token-exception:` en línea aparte del `fontSize:`, movidos inline para satisfacer el grep filter).

## Cambios principales por módulo o capa

### Capa de tokens (`mobile/lib/theme/`)

**Nuevos**:
- **`fincore_typography.dart`**: 7 `const TextStyle` exportados: `displayXL` (56/w800/-1.5), `headingL` (20/w700/-0.3), `headingM` (16/w600/0), `bodyM` (14/w400/0), `bodyS` (13/w500/0), `label` (12/w600/0.1 muted), `overline` (11/w600/1.2 subtle). Colores por default por token, override con `.copyWith(color:)`.
- **`fincore_spacing.dart`**: 7 `const double` en escala 2/4/8/12/16/24/32 alineada a grid 4dp + 4 `EdgeInsets` semánticos derivados (`kEdgeCard`, `kEdgeListItem`, `kEdgeDialog`, `kEdgeScreen`) + `kFabClearance = 96` documentado como pattern.
- **`fincore_radii.dart`**: 5 `const double` (6, 8, 12, 20, 999). `library;` para evitar `dangling_library_doc_comments`.
- **`fincore_motion.dart`**: 5 `const Duration` (100/200/300/500/1100 ms) + 4 `const Curve` (`Curves.easeOutCubic`, `Curves.easeIn`, `Cubic(0.2, 0, 0, 1)` M3 emphasized, `Curves.linear`) + docstring de filosofía ("motion existe para (1) señalizar causalidad y (2) suavizar cambios de estado; nunca para decorar").

**Extendido**:
- **`fincore_colors.dart`**: 4 `const double` alphas semánticos al final de la clase: `alphaHover = 0.08`, `alphaHairline = 0.12`, `alphaTint = 0.15`, `alphaSelected = 0.20`. Comentarios de uso.

**Reescrito**:
- **`fincore_theme.dart`**: `textTheme` cableado con `fontSize` explícito por los 15 slots M3 mapeados a los 7 tokens (documentado en el archivo con comentarios). Subthemes migrados: `cardTheme.borderRadius → kRadiusLg`, `inputDecorationTheme.borderRadius → kRadiusMd`, `filledButtonTheme.padding → symmetric(kSpaceXl, kSpaceMd)` (era 24, 14), `filledButtonTheme.textStyle → fontSize: 14` (era 15), `chipTheme.borderRadius → kRadiusLg` (era 16), `chipTheme.selectedColor → alphaSelected` (era 0.18). Import alias `as ft` para evitar colisiones con `textTheme`.

### Capa de widgets compartidos (`mobile/lib/widgets/`)

24 archivos, migrados por 6 subagentes Sonnet en paralelo:

- **Estructurales** (T008): `base_card.dart` (SectionTitle migrado a `overline` en Fase 5), `skeleton.dart`, `category_badge.dart`. `fincore_logo.dart` como excepción documentada (fontSize proporcional).
- **Dialogs** (T009): `confirm_dialog.dart`, `destructive_dialog.dart` (el más denso, ~28 cambios + 5 excepciones documentadas), `save_view_dialog.dart`.
- **Pickers** (T010): 7 archivos. Rename de field para evitar colisión con token `label` en `account_type_picker` (alias import).
- **Amount+date** (T011): `amount_formatter.dart` es puro string (sin migración necesaria); `date_field_outlined.dart` con 1 excepción documentada.
- **Movement+entries** (T012): 5 archivos, rename `_ActiveChip.label → text` en `entries_active_filters_bar`. Adoptó `kFabClearance = 96` en `entries_paginated_list.dart` (era 80).
- **Feedback** (T013): `error_snackbar.dart` + `account_balance_hint.dart`. Rename `_Chip.label → labelText`. Fondos saturados del snackbar preservados.

### Documentación del proyecto

- **`CLAUDE.md`**: sección nueva "Sistema de tokens de diseño" (~50 líneas) con inventario de los 5 archivos, reglas vinculantes (prohibido `fontSize/SizedBox/BorderRadius/alpha` inline fuera de escala), convenciones adicionales (iconografía outlined default, criterio de dialogs, reserva de colores semánticos con nota específica sobre `credit` type que debe migrar de `warning` a color neutral en sprint futuro), alcance del piloto y regla "boy scout" para sprints por módulo.
- **`mobile/pubspec.yaml`**: bump a `0.21.0+97` + comentario de changelog.
- **`mobile/android/app/build.gradle.kts`**: `versionCode = 97, versionName = "0.21.0"`.

### Documentación del sprint

- `engineering/specs/flutter-design-tokens-v1/spec.md` + `checklist.md`.
- `engineering/specs/flutter-design-tokens-v1/plan/{plan,tasks,test-plan}.md`.
- `engineering/specs/flutter-design-tokens-v1/implementation/{implementation-review,resumen-ejecutivo,resumen-extenso,progreso,pendientes,pruebas,decisiones-implementacion}.md`.

## Desviaciones respecto al plan

### DP-01 — `SectionTitle` migrado en Fase 5 en vez de Fase 3

**Origen**: en el prompt del subagente T008 excluí explícitamente `SectionTitle` de `base_card.dart` con la nota "será refactor de otro sprint". La razón fue prudencia — pensé que podía tener consumidores con expectativas específicas.

**Detección**: los guardrails de Fase 5 (`grep fontSize: [0-9]`) reportaron `base_card.dart:83: fontSize: 11` como violación no marcada.

**Resolución**: `SectionTitle` matcheaba exacto con el token `overline` (11/w600/textSubtle/1.2 uppercase). Migración trivial: `Text(text.toUpperCase(), style: overline)`. Cero cambio visual.

**Aprendizaje**: pre-scan del scope antes de escribir el prompt del subagente. En este caso, hubiera evitado el work adicional.

### DP-02 — Comentarios `token-exception:` en línea aparte del match

**Origen**: los subagentes de T009 (dialogs) colocaron el comentario `// token-exception:` en la línea anterior al `TextStyle` completo, describiendo el `fontSize: 15` de los CTAs del `DestructiveDialog`.

**Detección**: el guardrail `grep -v "token-exception"` filtra línea a línea; los comentarios estaban 7 líneas antes del `fontSize:`.

**Resolución**: comentarios movidos a la misma línea del `fontSize` con formato Dart inline (`fontSize: 15, // token-exception: ...`).

**Aprendizaje**: documentar en `CLAUDE.md` (implícitamente ya lo hace) que las marcas `token-exception` deben vivir en la misma línea del match para que el guardrail las detecte, no en la línea inmediatamente anterior.

## Pruebas realizadas y recomendadas

### Realizadas
- `flutter analyze --no-fatal-infos`: verde. 3 hints info pre-existentes de `entry_form_screen.dart` (screens fuera del scope).
- `flutter test`: 680/680 verdes en 2 corridas (post-Fase 3 y post-tweaks de Fase 5).
- Guardrails con `grep`: cero violaciones tras las correcciones DP-01 y DP-02.
- `flutter build apk --release --split-per-abi`: en curso en background al momento del cierre.

### Recomendadas / pendientes
- Smoke desktop (`flutter run -d linux`): Diego ejecuta las 6 pantallas del test-plan.
- Smoke Android (`adb install -r` del APK release): Diego ejecuta las 9 pantallas.
- Comparación visual side-by-side de screenshots antes/después: opcional pero útil para validar los cambios sub-perceptibles documentados.

## Riesgos residuales y posibles regresiones

### Riesgos técnicos
- **RT-01** (cambios sub-perceptibles): 6 puntos documentados. Mitigación con smoke manual.
- **RT-04** (widgets `const`): resuelto con import directo del token.
- **RT-05** (diff de alto volumen): mitigado con commits atómicos por fase (pendientes de ejecutar al confirmar Diego).

### Deuda documentada
- **`bodyL` (15/w600) faltante**: 2 usos en `DestructiveDialog` CTAs con `// token-exception:`. Si aparecen más usos, crear el token en sprint futuro.
- **`credit` type = `warning`**: hardcoded en `dashboard_screen._typeColor`. Regla de CLAUDE.md prohíbe usar `warning` para tipos de cuenta. Debe migrar a `textMuted` u otro color en el sprint que toque Dashboard.
- **Tests unitarios de tokens (T017)**: skipped por diseño (tokens son literales, tests serían tautológicos).
- **Migración de screens**: fuera del scope de este sprint. Regla "boy scout" activada en CLAUDE.md.

### Regresiones posibles
Ninguna funcional detectada por tests. Cambios visuales sub-perceptibles ya documentados. Si Diego reporta algo bloqueante en smoke, hotfix en commit adicional.

## Trazabilidad final

- **11 RF** definidos en `spec.md` → **27 tasks** planificadas en `tasks.md` → **26 ejecutadas** (T017 skipped por diseño, T027 commit pendiente de aprobación).
- **Cero preguntas bloqueantes** cerradas.
- **Cero desviaciones bloqueantes**; 2 desviaciones menores documentadas y resueltas.
- **14 excepciones** al sistema de tokens, todas justificadas en `decisiones-implementacion.md`.
- **680 tests** verdes; **0 tests** modificados.
- **10 hallazgos** del quality review manual: 0 bloqueantes, 2 de mediana severidad (deuda documentada), 1 de baja severidad (métrica cosmética).

Sprint listo para commit cuando Diego apruebe.
