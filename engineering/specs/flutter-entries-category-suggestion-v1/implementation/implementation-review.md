# Implementation Review: flutter-entries-category-suggestion-v1

## Resumen de lo implementado

- `CategorySuggestionService` con cascada de 3 queries (descripción exacta → monto+cuenta últimos 90 días → más usada últimos 30 días) en `mobile/lib/data/category_suggestion.dart`.
- Inyección del servicio en `AppDependencies.fromDatabase()`.
- Sugerencia integrada en `entry_form_screen.dart`:
  - Debounce de 300 ms para tipeo en descripción/monto.
  - Trigger inmediato al cambiar kind o cuenta.
  - Wrapper de `CategoryPicker.onChanged` para distinguir cambio manual de pre-selección automática.
  - Protección contra race con `_suggestionGeneration` (descarte de resultados obsoletos).
  - `Timer.cancel()` y `removeListener()` en `dispose()`.
- Widget privado `_SuggestionChip` con `Icons.auto_awesome` + texto "Sugerida", color accent suave debajo del picker.
- Sin schema bump, sin deps nuevas. Backward compatible al 100%.
- Versión bumped a `0.11.2+65`.

## Archivos principales modificados

- `mobile/lib/data/category_suggestion.dart` — **archivo nuevo**, servicio + 3 queries privadas + helper `_validAppliesTo`. ~210 líneas.
- `mobile/lib/app_dependencies.dart` — agrega field + inyección.
- `mobile/lib/screens/entry_form_screen.dart` — +130 líneas: state nuevo, listeners, `_recalcSuggestion`, wrapper de `CategoryPicker.onChanged`, render del chip, `_SuggestionChip` privado.
- `mobile/pubspec.yaml` — `0.11.1+64 → 0.11.2+65` + nota del sprint.
- `mobile/android/app/build.gradle.kts` — versionCode 65, versionName 0.11.2.
- `mobile/test/data/category_suggestion_test.dart` — **archivo nuevo**, 18 unit tests.
- `mobile/test/screens/entry_form_suggestion_test.dart` — **archivo nuevo**, 4 widget tests (WT-S01..WT-S04).

## Tareas completadas

- **T001..T003**: servicio + inyección. ✅
- **T004..T008**: state + triggers + chip + wrapper de `onChanged`. ✅
- **T009..T011**: 18 unit tests (UT-01..UT-18). El plan pedía 16; sumé UT-17 (kinds no soportados) y UT-18 (credit_expense usa origin) por completitud. ✅
- **T012**: 4 widget tests (WT-S01..WT-S04). ✅
- **T013, T014**: `flutter analyze` limpio + `flutter test` 343/343 verdes. ✅
- **T015**: bump `0.11.2+65`. ✅
- **T018**: documentación de implementación (este archivo + resumen-ejecutivo + resumen-extenso). ✅

## Tareas pendientes

- **T016**: `branch-quality-review` — pendiente, Diego decide si la lanzamos antes del commit.
- **T017**: smoke manual SM-01..SM-06 — Diego confirma tras instalar el APK.

## Riesgos residuales

- **R-A** (R-04 del plan, SQLite `LOWER` ASCII-only): descripciones históricas guardadas con acentos en MAYÚSCULA (e.g. `"CAFÉ"`) no matchean con tipeo en minúscula (`"café"`). Diego en uso real escribe en minúscula consistente, por lo que el riesgo es bajo. Documentado en CB-D16 del test-plan.
- **R-B** (perf con journal grande, R-06 del plan): paso 3 con `GROUP BY` no fue medido en escenarios >10k entries. Volumen single-user lejos de eso. Aceptable.
- **R-C** (chip "Sugerida" puede confundir a usuario nuevo): es la primera feature "asistida" del repo. Si Diego en uso real lo siente intrusivo, se desactiva con un toggle futuro. Sin smoke validado todavía.
- **R-D** (categoría sugerida del paso 3 cuando descripción está vacía): si Diego está escribiendo monto y aún no eligió descripción, la cascada cae al paso 3 (más usada) y pre-selecciona una categoría. Comportamiento intencional pero puede sorprender en el primer uso.

## Pruebas realizadas

### Unit tests (`mobile/test/data/category_suggestion_test.dart`)

18 verdes:

- **UT-01..UT-05**: paso 1 (descripción) — BD vacía, match exacto, normalización ASCII, ignora archivadas con fallback al paso 3, ignora `applies_to` incompatible.
- **UT-06..UT-08**: paso 2 (monto+cuenta) — match en ventana, fuera de 90 días, income usa destination.
- **UT-09..UT-10**: paso 3 (más usada) — categoría más frecuente, tiebreak por más reciente.
- **UT-11..UT-16**: short-circuits y edge cases — sin matches retorna null, `accountId` null saltea pasos 2/3, descripción null/empty saltea paso 1, amount null/0 saltea paso 2, `now` inyectable, soft delete excluye.
- **UT-17..UT-18**: otros kinds — transfer/debt_payment retorna null sin tocar BD, credit_expense usa origin (tarjeta).

### Widget tests (`mobile/test/screens/entry_form_suggestion_test.dart`)

4 verdes:

- **WT-S01**: sugerencia visible al matchear descripción.
- **WT-S02**: cambio manual desactiva el chip y no se recalcula.
- **WT-S03**: edit no dispara sugerencia.
- **WT-S04**: BD sin histórico no muestra el chip.

### Suite completa

- `flutter test`: **343 tests verdes** (antes 321; +22 nuevos).
- `flutter analyze`: 0 errores nuevos. 4 hints `info prefer_const_constructors` pre-existentes (tolerados según CLAUDE.md).

## Pruebas recomendadas

- **Smoke SM-01..SM-06**: smoke manual sobre BD real, ver `test-plan.md` para el detalle.
- **Performance opcional**: medir tiempo de la cascada con journal de 5k+ entries (no implementado; el volumen real está lejos).
- **A/B en uso**: tras 2 semanas, Diego puede evaluar % de sugerencias aceptadas vs cambiadas y decidir si ajustar umbrales o agregar configuración.

## Posibles regresiones

- **PR-01**: el form de captura ya tenía tests del flujo edit (cancelar, submit en edición) y de los 5 kinds. La suite completa los corrió todos verdes. Sin regresión detectada.
- **PR-02**: el `CategoryPicker` se reusa en `EntriesFiltersScreen`. NO se modificó el widget; la lógica de sugerencia vive 100% en el form. Sin riesgo de regresión cross-pantalla.
- **PR-03**: el `Timer` puede tener un edge case raro si Diego abre el form, escribe rápido y sale antes de que el timer dispare. Mitigado con `_suggestionDebounce?.cancel()` en `dispose()` y `if (!mounted) return` en el callback.

## Recomendaciones para code review humano

- **Revisar el wrapper `_onCategoryPickerChanged`**: la lógica de "es manual si el valor entrante != `_suggestedCategoryId`" es elegante pero puede confundir. Validar mentalmente que no detecta como "manual" el setState interno cuando la sugerencia se aplica (la sugerencia setea `_suggestedCategoryId` ANTES de que el `CategoryPicker` re-renderice, así que cuando el widget llame `onChanged(suggestionId)` el wrapper compara contra el ID recién seteado y NO lo marca como manual — funciona pero depende del orden).
- **Revisar la normalización en Dart vs SQL**: el código normaliza descripción en Dart antes de pasarla al SQL. Pero el SQL también aplica `LOWER(TRIM(j.description))`. La doble normalización es defensiva pero redundante; revisar si vale simplificar.
- **Revisar el flag `_categoryTouched`**: se resetea en `_selectKind`. Si Diego cambia kind 5 veces rápido, el flag se resetea cada vez. Comportamiento correcto según RN-S07 + CB-T07.
- **No se invocó `branch-quality-review`**: Diego puede dispararlo antes del commit final si quiere auditoría adversarial.
