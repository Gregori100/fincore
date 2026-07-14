# Tasks — flutter-design-tokens-v1

## Frontend

- [ ] T001 Frontend: Crear `mobile/lib/theme/fincore_typography.dart` con 7 tokens semánticos (`displayXL`, `headingL`, `headingM`, `bodyM`, `bodyS`, `label`, `overline`) como `const TextStyle`, con `fontSize`, `fontWeight`, `letterSpacing` y `color` (default `FincoreColors.textPrimary`, algunos con `textMuted`/`textSubtle` según semántica).
  RF: RF-001
  Depende de: ninguna
  Paralelizable: si
  Criterio de terminado: el archivo compila con `flutter analyze` limpio; los 7 tokens son `const TextStyle` importables desde otros archivos.

- [ ] T002 Frontend: Crear `mobile/lib/theme/fincore_spacing.dart` con 7 constantes `double` (`kSpace2xs=2`, `kSpaceXs=4`, `kSpaceSm=8`, `kSpaceMd=12`, `kSpaceLg=16`, `kSpaceXl=24`, `kSpace2xl=32`) + 4 `EdgeInsets` derivados (`kEdgeCard`, `kEdgeListItem`, `kEdgeDialog`, `kEdgeScreen`) + helper `kFabClearance` documentado.
  RF: RF-002
  Depende de: ninguna
  Paralelizable: si
  Criterio de terminado: compila; los tokens son `const`; el archivo incluye docstring explicando cómo usar cada semántico derivado.

- [ ] T003 Frontend: Crear `mobile/lib/theme/fincore_radii.dart` con 5 constantes `double` (`kRadiusSm=6`, `kRadiusMd=8`, `kRadiusLg=12`, `kRadiusXl=20`, `kRadiusPill=999`).
  RF: RF-003
  Depende de: ninguna
  Paralelizable: si
  Criterio de terminado: compila; los tokens son `const`.

- [ ] T004 Frontend: Extender `mobile/lib/theme/fincore_colors.dart` agregando 4 `double` const (`alphaHover=0.08`, `alphaHairline=0.12`, `alphaTint=0.15`, `alphaSelected=0.20`) al final de la clase con comentarios de uso.
  RF: RF-004
  Depende de: ninguna
  Paralelizable: si
  Criterio de terminado: compila; los alphas son accesibles como `FincoreColors.alphaTint`.

- [ ] T005 Frontend: Crear `mobile/lib/theme/fincore_motion.dart` con 5 `Duration` const (`kMotionInstant=100ms`, `kMotionFast=200ms`, `kMotionMedium=300ms`, `kMotionSlow=500ms`, `kMotionPulse=1100ms`) + 4 `Curve` const (`kCurveStandard=Curves.easeOutCubic`, `kCurveExit=Curves.easeIn`, `kCurveEmphasized=Cubic(0.2, 0, 0, 1)`, `kCurveLinear=Curves.linear`) + docstring al inicio con filosofía de motion (causalidad + suavizar cambios de estado, nunca decorar).
  RF: RF-005
  Depende de: ninguna
  Paralelizable: si
  Criterio de terminado: compila; los tokens son `const`; docstring presente.

- [ ] T006 Frontend: Cablear `textTheme` de `mobile/lib/theme/fincore_theme.dart` mapeando los 15 slots M3 a los 7 tokens tipográficos con `fontSize`, `fontWeight`, `letterSpacing` y `color` explícitos según el mapping definido en `spec.md` Alcance.
  RF: RF-006
  Depende de: T001
  Paralelizable: no
  Criterio de terminado: `Theme.of(context).textTheme.bodyMedium?.fontSize == 14` y equivalentes para todos los slots. `flutter analyze` limpio.

- [ ] T007 Frontend: Migrar subthemes de `fincore_theme.dart` (`cardTheme`, `inputDecorationTheme`, `filledButtonTheme`, `chipTheme`) para consumir tokens de radio, spacing y tipografía. `borderRadius: BorderRadius.circular(kRadiusMd)` para inputs/botones, `kRadiusLg` para cards y chips (era 16, se homologa a 12). `filledButtonTheme.padding` usa `EdgeInsets.symmetric(horizontal: kSpaceXl, vertical: kSpaceMd)` (era `24, 14`; 14 se redondea a 12). Documentar las homologaciones en el diff con comentarios `// era N → kRadiusX/kSpaceX`.
  RF: RF-007
  Depende de: T002, T003
  Paralelizable: no
  Criterio de terminado: subthemes compilan; `flutter analyze` limpio; homologaciones documentadas.

- [ ] T008 Frontend: Migrar widgets estructurales (`base_card.dart`, `skeleton.dart`, `category_badge.dart`) a consumir tokens. `fincore_logo.dart` queda como excepción documentada (no se migra su `fontSize` proporcional, sí lo demás si aplica).
  RF: RF-008
  Depende de: T001, T002, T003, T004, T005
  Paralelizable: si (grupo T008-T013)
  Criterio de terminado: cero `fontSize`/`SizedBox`/`BorderRadius`/`alpha` literales fuera de escala en los 3 archivos (salvo excepciones marcadas); `flutter analyze` limpio.

- [ ] T009 Frontend: Migrar dialogs (`confirm_dialog.dart`, `destructive_dialog.dart`, `save_view_dialog.dart`) a consumir tokens. Especial atención al hero icon de `destructive_dialog` (marcar como `token-exception:` si el diámetro/padding requiere valor no-token).
  RF: RF-008
  Depende de: T001, T002, T003, T004, T005
  Paralelizable: si (grupo T008-T013)
  Criterio de terminado: cero literales fuera de escala; excepciones marcadas y contadas.

- [ ] T010 Frontend: Migrar pickers (`account_picker.dart`, `account_type_picker.dart`, `applies_to_picker.dart`, `category_picker.dart`, `color_picker.dart`, `icon_picker.dart`, `kind_picker.dart`) a tokens. **NO** cambiar iconografía (fuera de scope).
  RF: RF-008
  Depende de: T001, T002, T003, T004, T005
  Paralelizable: si (grupo T008-T013)
  Criterio de terminado: cero literales fuera de escala en los 7 pickers; excepciones marcadas.

- [ ] T011 Frontend: Migrar widgets de amount y fecha (`amount_formatter.dart`, `date_field_outlined.dart`) a tokens. `AmountFormatter` puede ser puro string (sin cambios); verificar.
  RF: RF-008
  Depende de: T001, T002, T003, T004, T005
  Paralelizable: si (grupo T008-T013)
  Criterio de terminado: cero literales fuera de escala; si `amount_formatter.dart` no requiere migración, documentarlo en el diff.

- [ ] T012 Frontend: Migrar widgets de movement y entries (`movement_row.dart`, `entries_active_filters_bar.dart`, `entries_empty_state.dart`, `entries_paginated_list.dart`, `entry_account_label.dart`) a tokens.
  RF: RF-008
  Depende de: T001, T002, T003, T004, T005
  Paralelizable: si (grupo T008-T013)
  Criterio de terminado: cero literales fuera de escala en los 5 archivos.

- [ ] T013 Frontend: Migrar widgets de feedback (`error_snackbar.dart`, `account_balance_hint.dart`) a tokens. En `error_snackbar`, migrar tipografía + spacing + margin, **NO** el color de fondo saturado (permanece igual).
  RF: RF-008
  Depende de: T001, T002, T003, T004, T005
  Paralelizable: si (grupo T008-T013)
  Criterio de terminado: cero literales fuera de escala; fondo saturado del snackbar preservado.

- [ ] T014 Frontend: Bump de versión en `mobile/pubspec.yaml` a `version: 0.21.0+97` y en `mobile/android/app/build.gradle.kts` (`versionCode = 97`, `versionName = "0.21.0"`). Correr `scripts/verify-apk.sh` conceptualmente (sync check documental — el APK real se valida en T019).
  RF: RF-010
  Depende de: T008, T009, T010, T011, T012, T013
  Paralelizable: no
  Criterio de terminado: ambos archivos actualizados; `pubspec.yaml` con formato correcto.

## Documentacion

- [ ] T015 Documentación: Extender `CLAUDE.md` con sección nueva "Sistema de tokens de diseño" que incluya (a) los 5 archivos y su rol, (b) reglas prohibidas (`fontSize` inline, `SizedBox` con literal fuera de escala, `borderRadius.circular(N)` idem, `withValues(alpha: N)` idem), (c) excepciones (`FincoreLogo` y `// token-exception:`), (d) convención de iconografía (outlined default, filled solo current/selected), (e) convención de dialogs (`ConfirmDialog` reversible vs `DestructiveDialog` irreversible), (f) reserva de colores semánticos (positive/negative dinero, accent affordance, warning alertas NO tipo credit, categoryX taxonomía).
  RF: RF-009
  Depende de: T001, T002, T003, T004, T005 (para referenciar rutas correctas)
  Paralelizable: si (con T008-T013)
  Criterio de terminado: sección presente en CLAUDE.md; lenguaje en español neutral; convenciones alineadas con lo implementado (no dice "prohibido X" si no aplicó al 100%).

- [ ] T016 Documentación: Crear `engineering/specs/flutter-design-tokens-v1/implementation/decisiones-implementacion.md` listando todas las excepciones `// token-exception:` con archivo, línea, valor original, valor propuesto y razón. Meta: ≤ 5 excepciones totales; si supera, retro del sprint documentada al final del archivo.
  RF: RF-008 (excepciones)
  Depende de: T008-T013
  Paralelizable: no (requiere que las migraciones estén hechas)
  Criterio de terminado: archivo existe; lista con todas las excepciones; conteo total al final.

## Pruebas

- [ ] T017 Pruebas: Escribir/actualizar tests unitarios de los tokens en `mobile/test/theme/`. Al menos: `fincore_typography_test.dart` (validar 7 tokens con fontSize/weight/letterSpacing esperados), `fincore_theme_test.dart` (validar que textTheme cableado devuelve los fontSize correctos por slot M3). Los archivos de spacing/radii/motion son constantes triviales — 1 test smoke por archivo alcanza (opcional).
  RF: RF-011 (cero regresión)
  Depende de: T001, T005, T006
  Paralelizable: si
  Criterio de terminado: tests nuevos pasan; suite total sigue en 680+ tests verdes.

- [ ] T018 Pruebas: Correr `flutter analyze` desde `mobile/`. Cero errores permitidos.
  RF: RF-011
  Depende de: T008-T014, T017
  Paralelizable: no
  Criterio de terminado: `flutter analyze` reporta `No issues found!` o solo warnings cosméticos tolerados por CLAUDE.md.

- [ ] T019 Pruebas: Correr `flutter test` desde `mobile/`. Los 680 tests existentes + nuevos de T017 pasan sin modificar cuerpos (o con modificaciones mínimas documentadas en `decisiones-implementacion.md`).
  RF: RF-011
  Depende de: T008-T014, T017
  Paralelizable: no
  Criterio de terminado: suite completa en verde. Registrar output en `implementation/pruebas.md`.

- [ ] T020 Pruebas: Ejecutar checklist de guardrails del test-plan con `grep`:
  ```
  grep -rn "fontSize: [0-9]" mobile/lib/widgets/ | grep -v "fincore_logo" | grep -v "token-exception"
  grep -rn "SizedBox(height: [0-9]" mobile/lib/widgets/ | grep -v "kSpace" | grep -v "token-exception"
  grep -rn "BorderRadius.circular([0-9]" mobile/lib/widgets/ | grep -v "kRadius" | grep -v "token-exception"
  grep -rn "Theme.of(context).textTheme" mobile/lib/widgets/
  grep -rn "// token-exception:" mobile/lib/widgets/
  ```
  Registrar los conteos en `implementation/pruebas.md`.
  RF: RF-008
  Depende de: T008-T013, T016
  Paralelizable: no
  Criterio de terminado: primeros 3 grep devuelven 0 resultados; 4to grep ≥ 30 resultados; 5to grep ≤ 5 resultados.

- [ ] T021 Pruebas: Smoke manual desktop (`flutter run -d linux`) validando SM-01 a SM-06 del test-plan. Comparar visualmente con memoria reciente o screenshots pre-sprint si están disponibles. Documentar cualquier cambio perceptible en `implementation/pruebas.md`.
  RF: RF-011 + regresión visual
  Depende de: T018, T019
  Paralelizable: no
  Criterio de terminado: 6 flujos smoke ejecutados sin regresión visual bloqueante; hallazgos documentados.

- [ ] T022 Pruebas: Build APK Android release (`flutter build apk --release --split-per-abi`) y verificar con `scripts/verify-apk.sh` el sync entre pubspec y build.gradle.kts. Diego ejecuta el `adb install -r` y valida SM-01 a SM-09.
  RF: RF-010
  Depende de: T014, T018, T019
  Paralelizable: no
  Criterio de terminado: APK arm64-v8a generado en `mobile/build/app/outputs/flutter-apk/`; script verify-apk sin errores; Diego confirma instalación y smoke OK.

## Validacion de calidad

- [ ] T023 Validación: Ejecutar la skill `branch-quality-review` sobre la rama del sprint. Reporte queda en `engineering/quality-review/flutter-design-tokens-v1/`.
  RF: transversal
  Depende de: T020, T021
  Paralelizable: no
  Criterio de terminado: reporte generado; findings triados; los bloqueantes se abordan como hotfix en el sprint, los low se dejan documentados para retro/futuro.

- [ ] T024 Documentación: Crear/actualizar `engineering/specs/flutter-design-tokens-v1/implementation/implementation-review.md` con las secciones obligatorias del skill spec-implementar (Resumen, Archivos modificados, Tareas completadas, Tareas pendientes, Riesgos residuales, Pruebas realizadas, Pruebas recomendadas, Posibles regresiones, Recomendaciones code review humano). Incluir referencia al reporte de `branch-quality-review`.
  RF: transversal (cierre)
  Depende de: T023
  Paralelizable: no
  Criterio de terminado: archivo completo con las 9 secciones.

- [ ] T025 Documentación: Crear `engineering/specs/flutter-design-tokens-v1/implementation/resumen-ejecutivo.md` (breve, orientado a negocio) y `implementation/resumen-extenso.md` (técnico, trazable).
  RF: transversal (cierre)
  Depende de: T024
  Paralelizable: no
  Criterio de terminado: ambos archivos completos según formato del skill spec-implementar.

- [ ] T026 Documentación: Crear `engineering/specs/flutter-design-tokens-v1/implementation/progreso.md` como bitácora de tareas ejecutadas (marcar T001-T025 como completadas al terminar el sprint). Bitácora, no plan.
  RF: transversal (cierre)
  Depende de: T025
  Paralelizable: no
  Criterio de terminado: bitácora con estado final de cada task.

- [ ] T027 Documentación: Antes del commit final, reportar a Diego: (a) resumen de cambios, (b) hallazgos del quality review, (c) pendientes documentados, (d) confirmar bump de versión, (e) pedir smoke Android antes de commitear. Diego ejecuta `adb install` y confirma OK. Solo entonces, commit único con mensaje largo (o serie de commits atómicos por fase — decisión al cierre).
  RF: transversal (cierre)
  Depende de: T022, T023, T024, T025, T026
  Paralelizable: no
  Criterio de terminado: commit realizado con mensaje que referencia spec, plan e implementation-review; working tree limpio; Diego notificado.
