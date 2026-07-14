# Implementation Review: flutter-language-cleanup-v1

## Resumen de lo implementado

Sprint 2 del roadmap de la auditoría de diseño 2026-07-14. Purga total del voseo rioplatense en `mobile/lib/` y `mobile/test/`, más un test guardrail que blindea contra regresión futura.

- **10 sitios de voseo verbal en `lib/`** migrados a español neutral (verbo tú directo, infinitivo impersonal o voz impersonal según contexto).
- **15 comentarios "acá" → "aquí"** en `lib/` (11) y `test/` (4). "querés" en `widget_test_harness.dart` también neutralizado.
- **1 mención de "kinds"** en `settings_screen.dart:501` → "tipos de movimientos, reportes, presupuestos y respaldo".
- **5 matchers de `integration_test/`** actualizados al copy neutral actual (estaban apuntando a strings ya inexistentes en `lib/` — heredado de un cambio previo sin propagar a tests).
- **3 matchers de widget tests** (`entry_form_kinds_test`, `settings_screen_test`, `monthly_average_tab_test`) actualizados al nuevo copy — consecuencia esperada del sprint según RF-008.
- **Test guardrail nuevo** `mobile/test/language/no_voseo_test.dart` que escanea `lib/` y falla si detecta voseo. Corre con `flutter test`.
- **`CLAUDE.md`** con la convención documentada en "Convenciones del repo".
- Bump `0.21.0+97` → `0.21.1+98` (patch).

## Archivos principales modificados

### Copy visible al usuario (`lib/`)
- `widgets/kind_picker.dart` — "Pagás una tarjeta…" → "Pagar una tarjeta…"
- `widgets/entries_paginated_list.dart` — "Acotá filtros…" → "Reducir el rango de filtros…"
- `widgets/entries_empty_state.dart` — "Probá ajustarlos" → "Ajusta los filtros o cambia el rango"
- `widgets/error_snackbar.dart` — "Probá con 1-50" → "Debe tener entre 1 y 50" (+ 1 "acá" en comentario)
- `screens/entry_form_screen.dart` — "Pagás desde" → "Pago desde" (+ 1 "acá" en comentario)
- `screens/entries_filters_screen.dart` — "Configurá al menos…" → "Configura al menos…"
- `screens/saved_views_list_screen.dart` — "Configurá filtros y tap" → "Configura filtros y toca"
- `screens/reports/monthly_average_tab.dart` — "Necesitás al menos 1 mes…" → "Se necesita al menos 1 mes…"
- `screens/settings_screen.dart` — "FAQ sobre kinds…" → "FAQ sobre tipos de movimientos, reportes, presupuestos y respaldo" (+ 1 "acá")
- `screens/onboarding_screen.dart` — 2 líneas del docstring citaban copy voseado desactualizado.
- `data/daos/saved_views_dao.dart` — mismo mensaje "Probá con 1-50" duplicado del snackbar.

### Comentarios "acá" → "aquí" adicionales en `lib/`
- `main.dart`, `screens/first_run_screen.dart`, `screens/weekly_budgets/calendar_screen.dart`, `screens/weekly_budgets/list_screen.dart`, `data/backup.dart`, `data/reports.dart`, `data/app_preferences_keys.dart`, `theme/fincore_motion.dart`.

### Tests actualizados
- `test/screens/entry_form_kinds_test.dart` — 4 matchers "Pagás desde" → "Pago desde" + 1 comentario docstring + 1 título de test.
- `test/screens/settings_screen_test.dart` — 1 matcher del FAQ.
- `test/screens/monthly_average_tab_test.dart` — 1 matcher del mensaje empty.
- `test/screens/reports/income_heatmap_tab_test.dart` — 1 "acá" en comentario.
- `test/screens/entries_filters_screen_test.dart` — 1 "acá" en comentario.
- `test/helpers/widget_test_harness.dart` — 1 "querés" + 1 "acá" en comentario.
- `integration_test/account_form_test.dart` — 2 matchers + 1 comentario docstring.
- `integration_test/category_form_test.dart` — 2 matchers.

### Nuevo
- `mobile/test/language/no_voseo_test.dart` — test guardrail.

### Documentación y versión
- `CLAUDE.md` — línea de convención de español neutral en "Convenciones del repo".
- `mobile/pubspec.yaml` — bump `0.21.1+98` + comentario changelog.
- `mobile/android/app/build.gradle.kts` — `versionCode = 98, versionName = "0.21.1"`.

## Tareas completadas

- **T000** (investigación integration_test) — hallazgo documentado: 5 matchers apuntaban a strings inexistentes (`Ingresá un nombre.`, `Ya tenés una cuenta con ese nombre`). App real usa `Ingresar un nombre.` y `Ya existe una cuenta con ese nombre.`. Matchers actualizados en T006.
- **T001-T003** (10 sitios de voseo verbal en lib/) — todos migrados.
- **T004** (15 "acá" → "aquí" en lib/ y test/) — todos migrados.
- **T005** ("kinds" en Settings) — migrado.
- **T006** (5 matchers de integration_test) — migrados al copy neutral actual.
- **T007** (test guardrail `no_voseo_test.dart`) — creado. Corre en `flutter test`. Verde tras 1 iteración de refinamiento (falso positivo por Unicode `\b` que matcheaba `partía` — se removió `partí/salí/dormí` del regex por ser ambiguos con formas neutrales).
- **T008** (CLAUDE.md) — convención agregada.
- **T009** (bump versión) — pubspec + gradle actualizados.
- **T010** (`flutter analyze`) — verde (3 hints info pre-existentes tolerados).
- **T011** (`flutter test`) — 681/681 verdes (680 previos + guardrail nuevo; 3 tests actualizados en el sprint).
- **T013** (build APK) — lanzado en background.
- **T014-T015** (docs de cierre) — este archivo + resumen ejecutivo/extenso + progreso.

## Tareas pendientes

- **T012** (smoke desktop) — Diego lo ejecuta al abrir la app.
- **T013** (smoke Android SM-06) — foco en las 2 strings alargadas (`Ajusta los filtros…` y `Reducir el rango…`) en 360dp. Diego lo ejecuta post-`adb install`.
- **T016** (commit) — pendiente de aprobación explícita de Diego (regla del proyecto). Nota: como Sprint 1 también está sin commitear, Diego decide si es un commit por sprint o uno combinado.

## Riesgos residuales

- **RT-01 mitigado** (integration_test rotos): los 5 matchers estaban apuntando a strings inexistentes; sprint los actualizó. Riesgo colateral detectado: los tests probablemente no corren en CI por no ejecutarse `flutter test integration_test/`. Recomendación futura: agregar los integration_test al pipeline de release.
- **RT-02 resuelto** (auto-referencia del guardrail): el test guardrail vive en `test/` y solo escanea `lib/`. Sin auto-referencia. Regex construida con string literales, sin hack de concatenación.
- **RT-03** (strings alargadas): 2 mensajes crecieron notablemente:
  - `'Probá ajustarlos.'` (17 chars) → `'Ajusta los filtros o cambia el rango.'` (37).
  - `'Acotá filtros para ver entries más viejos.'` (42) → `'Reducir el rango de filtros para ver movimientos más antiguos.'` (62).
  Mitigación: smoke Android en 360dp por Diego. Si algo hace wrap raro, hotfix con copy más corto.
- **RT-04 resuelto** (dependencias por igualdad literal en `'Pagás desde'`): grep no encontró dependencias externas. Cambio seguro.
- **Falso positivo del guardrail**: regex `\b` con caracteres Unicode acentuados es inconsistente en Dart RegExp. El sprint removió verbos ambiguos (`partí/salí/dormí`) del regex. Trade-off aceptado: el guardrail no detecta `¡Partí!` como voseo, pero eso es imperativo puro voseo raro en copy financiero.

## Pruebas realizadas

- `flutter analyze --no-fatal-infos`: **verde**. 3 hints info pre-existentes de `entry_form_screen.dart` (heredados del sprint anterior, screens fuera del scope).
- `flutter test`: **681/681 verdes** (680 previos + 1 guardrail nuevo). 3 tests actualizados dentro del sprint por matchers que apuntaban al copy voseado (RF-008 aclara que esto es aceptable).
- `flutter test test/language/no_voseo_test.dart`: verde en 500ms.
- Guardrails con `grep`:
  - `\b(pagás|configurá|probá|…|acá|allá|andá|seteás|fijate|dale)\b` en `lib/`: **0**.
  - Mismo grep en `test/`: **0**.
  - `"kinds"` en `settings_screen.dart`: **0** en copy visible.

## Pruebas recomendadas

- **Smoke desktop** (`flutter run -d linux`): validar los 5 mensajes que cambiaron (SM-01 a SM-05 del test-plan).
- **Smoke Android** (`adb install -r` del APK release): foco en SM-06 (layout de las 2 strings alargadas en 360dp).
- **Correr `flutter test integration_test/` en emulador** (fuera del scope, pero recomendado): confirma que los 5 matchers actualizados efectivamente pasan en runtime real.

## Posibles regresiones

Ninguna detectada. Los 3 tests actualizados dentro del sprint reflejan cambios de copy intencionales y su lógica sigue igual.

## Recomendaciones para code review humano

- **Ver el test guardrail primero** (`mobile/test/language/no_voseo_test.dart`) para entender la regla que se aplica automáticamente.
- **Ver la sección nueva en CLAUDE.md** (`Convenciones del repo` — línea nueva con la regla + referencia al test).
- **Diff de copy**: cada string modificada es un cambio de tono, no de lógica. Los 10 sitios visibles al usuario son de bajo riesgo funcional.
- **Nota del test guardrail**: la regex omite `partí/salí/dormí` por ambigüedad con pretérito neutro (`yo partí`). Si un tester nuevo introduce `¡Partí!` (imperativo voseo), el guardrail no lo detecta — pero esos verbos raramente aparecen en copy financiero.
- **Hallazgo colateral**: los 5 matchers de `integration_test/` estaban obsoletos antes del sprint. Recomendación separada: verificar si los integration_test se corren periódicamente en emulador.
