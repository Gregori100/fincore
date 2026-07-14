# Plan técnico — flutter-language-cleanup-v1

## Enfoque tecnico

Sprint mecánico de reemplazo de strings + agregar un test guardrail. Se compone de 4 partes:

1. **Reemplazo de voseo verbal en `lib/`** (10 sitios) con criterio contextual (tú directo o infinitivo impersonal).
2. **Reemplazo mecánico `acá` → `aquí`** en comentarios de `lib/` (11) y `test/` (4).
3. **Reemplazo de "kinds" → "tipos de movimientos"** en `settings_screen.dart:501` (1 sitio).
4. **Test guardrail nuevo** en `mobile/test/language/no_voseo_test.dart` que escanea `lib/` con la regex del voseo y falla si encuentra match.

Pre-implementación obligatoria: investigar el estado de los 5 matchers en `integration_test/` que apuntan a strings inexistentes (R-01 de la spec).

Cero refactor estructural. Cero cambios de comportamiento. Cero schema. Bump patch `0.21.0+97` → `0.21.1+98`.

## Requisitos funcionales cubiertos

- **RF-001** (10 sitios de voseo verbal migrados) → T001-T003 (agrupados por afinidad para minimizar diffs).
- **RF-002** (15 "acá" → "aquí" en comentarios) → T004.
- **RF-003** ("kinds" → "tipos de movimientos" en Settings) → T005.
- **RF-004** (5 matchers de integration_test actualizados) → T006 (con investigación previa T000).
- **RF-005** (test guardrail nuevo) → T007.
- **RF-006** (CLAUDE.md convención) → T008.
- **RF-007** (bump versión) → T009.
- **RF-008** (analyze + tests verdes) → T010-T011.

## Archivos o modulos probablemente afectados

**Modificados en `mobile/lib/screens/`**:
- `entry_form_screen.dart` (label debtPayment + comentario "acá").
- `entries_filters_screen.dart` (mensaje "Configurá").
- `saved_views_list_screen.dart` (mensaje "Configurá filtros y tap").
- `settings_screen.dart` (comentario "acá" + copy "kinds").
- `first_run_screen.dart` (comentario "acá").
- `onboarding_screen.dart` (comentario + posible slide copy).
- `weekly_budgets/calendar_screen.dart` (comentario "acá").
- `weekly_budgets/list_screen.dart` (comentario "acá").
- `reports/monthly_average_tab.dart` (mensaje "Necesitás").
- `main.dart` (comentario "acá").

**Modificados en `mobile/lib/widgets/`**:
- `kind_picker.dart` (descripción "Pagás una tarjeta").
- `entries_paginated_list.dart` (mensaje "Acotá filtros").
- `entries_empty_state.dart` (mensaje "Probá ajustarlos").
- `error_snackbar.dart` (mensaje "Probá con 1-50" + comentario "acá").

**Modificados en `mobile/lib/data/`**:
- `backup.dart` (comentario "acá").
- `reports.dart` (comentario "acá").
- `app_preferences_keys.dart` (comentario "acá").
- `daos/saved_views_dao.dart` (mensaje "Probá con 1-50").

**Modificados en `mobile/lib/theme/`**:
- `fincore_motion.dart` (comentario "acá" — es el docstring que escribí ayer).

**Modificados en `mobile/test/`**:
- `screens/reports/income_heatmap_tab_test.dart` (comentario "acá").
- `screens/entries_filters_screen_test.dart` (comentario "acá").
- `helpers/widget_test_harness.dart` (comentarios "querés" + "acá").

**Modificados en `mobile/integration_test/`** (depende de investigación R-01):
- `account_form_test.dart` (2 matchers + comentario "Ingresá").
- `category_form_test.dart` (2 matchers).

**Nuevos**:
- `mobile/test/language/no_voseo_test.dart`.

**Raíz**:
- `CLAUDE.md` (convención de español neutral).
- `mobile/pubspec.yaml` (bump `0.21.1+98`).
- `mobile/android/app/build.gradle.kts` (bump).

**Total**: ~24 archivos modificados + 1 archivo nuevo.

## Entidades y estados afectados

No aplica. Sprint sin dominio.

## Compatibilidad con datos y procesos existentes

- **BD SQLite**: sin cambios.
- **Backup JSON v1**: sin cambios.
- **Tests existentes**: 680/680 deben seguir verdes. Los 5 matchers de integration_test pueden requerir update (R-01).
- **APK vs versión previa**: bump patch `0.21.1+98`, compatible con `adb install -r`.

## Cambios de datos si aplica

No aplica.

## Cambios de API si aplica

No aplica.

## Cambios de integraciones si aplica

No aplica.

## Cambios de UI si aplica

10 strings visibles al usuario cambian. Ejemplos con longitud comparativa:

- `'Pagás desde'` (11 chars) → `'Pago desde'` (10 chars) — imperceptible.
- `'Configurá al menos un filtro antes de guardar.'` (46) → `'Configura al menos un filtro antes de guardar.'` (46) — igual.
- `'Probá ajustarlos.'` (17) → `'Ajusta los filtros o cambia el rango.'` (37) — **+20 chars, riesgo layout en 360dp**. Revisar visual en smoke.
- `'Acotá filtros para ver entries más viejos.'` (42) → `'Reducir el rango de filtros para ver movimientos más antiguos.'` (62) — **+20 chars, similar riesgo**.
- `'Necesitás al menos 1 mes cerrado de uso para calcular promedio.'` (63) → `'Se necesita al menos 1 mes cerrado de uso para calcular el promedio.'` (68) — +5 chars, aceptable.
- `'El nombre no es válido. Probá con 1-50 caracteres.'` (50) → `'El nombre no es válido. Debe tener entre 1 y 50 caracteres.'` (59) — +9 chars, aceptable.

Los 2 casos con crecimiento notable (`Probá ajustarlos.` y `Acotá filtros`) van en pantallas con espacio suficiente (empty states + footer de paginación), pero se validan en smoke Android.

## Cambios de permisos si aplica

No aplica.

## Riesgos tecnicos

- **RT-01** (heredado R-01): 5 matchers en `integration_test/` apuntan a strings que ya NO existen en `lib/`. **Antes** de "actualizar el matcher", investigar qué copy real muestra la app hoy y si esos tests están efectivamente pasando (o si son tolerantes). Mitigación: correr esos 5 tests aislados como primera task (T000 pre-implementación).
- **RT-02** (heredado R-03): el test guardrail contiene la regex del voseo como string en su código. Cuando se corra sobre sí mismo, matcheará. Mitigación: excluir explícitamente `no_voseo_test.dart` del scan por path.
- **RT-03**: los 2 mensajes con crecimiento de +20 chars (`Ajusta los filtros...`, `Reducir el rango...`) pueden causar wrap o ellipsis en 360dp. Mitigación: smoke Android post-implementación; si algo queda mal, ajustar el copy más corto.
- **RT-04**: reemplazos de sustantivo verbal (`Pagás desde` → `Pago desde`) pueden romper si un widget consumía la string por igualdad literal (`if (label == 'Pagás desde')`). Mitigación: `grep` de cada string antes de reemplazar.

## Estrategia de pruebas

1. **`flutter analyze`** — cero errores nuevos.
2. **`flutter test`** — 680 previos + 1 nuevo (guardrail) = 681 verdes.
3. **Integration tests** (opcional, requieren emulador): correr los 5 impactados; si están rotos, adaptar.
4. **Smoke desktop** (`flutter run -d linux`): pantallas Entries + Reports + Settings para validar copy actualizado.
5. **Smoke Android**: sobre las mismas pantallas + validar layout en 360dp para los strings alargados.
6. **`branch-quality-review`** al cierre.

## Estrategia de rollback

Trivial: `git revert` del commit del sprint. Cero side effects.

Si el rollback ocurre después del release, el siguiente release debe bumpear a `0.21.2+99` (Android no permite downgrade de versionCode).

## Orden sugerido de implementacion

Sprint chico, secuencial:

1. **T000 (investigación)**: correr los 5 tests de `integration_test/` afectados (o al menos analizar el copy real que muestra la app hoy). Documentar hallazgo.
2. **T001-T003 (voseo verbal en `lib/`)**: 10 sitios agrupados por afinidad.
3. **T004 (`acá` → `aquí`)**: 15 ocurrencias con `sed` o edits mecánicos.
4. **T005 ("kinds" en Settings)**: 1 edit.
5. **T006 (matchers de integration_test)**: actualizar los 5 según hallazgo de T000.
6. **T007 (test guardrail nuevo)**: escribir + correr.
7. **T008 (CLAUDE.md convención)**: extender sección "Convenciones del repo".
8. **T009 (bump versión)**: pubspec + gradle.
9. **T010 (`flutter analyze`)**: cero errores.
10. **T011 (`flutter test`)**: 681 verdes.
11. **T012 (smoke)**: desktop + Android.
12. **T013 (docs de cierre + commit)**.

Estimado ~1 hora para Claude (~1-3 min por task promedio).

## Casos borde que condicionan la solucion

Cubiertos por spec + el hallazgo colateral de investigación (R-01). Sin novedades.

## Preguntas o supuestos que siguen afectando la implementacion

- **Supuesto**: los 5 matchers de integration_test se pueden actualizar sin bloquear el sprint. Si al investigar resulta que están fundamentalmente rotos por otra razón (no solo el string), documentar en `desviaciones-plan.md` y proceder con el resto del sprint.
- **Supuesto**: la regex del guardrail cubre los verbos comunes. Si aparecen otros (`partí/salí/dormí/tosé` en presente/imperativo voseante), se agregan post-hoc.
- **Supuesto**: el bump patch `0.21.1+98` es apropiado.
