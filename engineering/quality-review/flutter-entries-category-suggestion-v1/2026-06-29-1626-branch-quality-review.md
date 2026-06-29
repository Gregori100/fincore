# Branch Quality Review: flutter-entries-category-suggestion-v1

## Metadata

- Fecha: 2026-06-29
- Rama revisada: `main` (cambios uncommitteados sobre `45010b0`)
- Rama base: `main`
- Rango: working tree vs HEAD
- Commit HEAD: `45010b0`
- Autor de revisión: Claude Code (4 carriles paralelos con asignación de modelo: 2 Sonnet, 2 Haiku).
- Carpeta de reporte: `engineering/quality-review/flutter-entries-category-suggestion-v1/`

## Resumen ejecutivo

- Sprint introduce `CategorySuggestionService` con cascada de 3 queries + integración en `entry_form_screen.dart` con debounce + race protection + chip "✨ Sugerida". 343/343 tests verdes, analyze limpio.
- **Sin hallazgos críticos ni bloqueantes**. La arquitectura es sólida: el patrón de race condition (`_suggestionGeneration`) está bien ejecutado, ciclo de vida del Timer correcto, separación form/servicio limpia.
- **6 hallazgos accionables** distribuidos como 3 Medias triviales (~5 min total) y 3 Bajas (decisión sutil + marginales).
- **Gaps de cobertura menores** en tests: 3 casos borde simples sin cobertura (CB-D05/D06/D08) y 4 casos de race/timing (CB-D09/D10/D13/D15) intencionalmente difíciles de testear.
- Carril Arquitectura cerró sin hallazgos. Sincronía de versión OK. Documentación completa.

## Alcance revisado

- Cambios working tree sobre commit `45010b0`:
  - `mobile/lib/data/category_suggestion.dart` (nuevo, ~210 líneas)
  - `mobile/lib/app_dependencies.dart` (inyección)
  - `mobile/lib/screens/entry_form_screen.dart` (+130 líneas: state nuevo, listeners, `_recalcSuggestion`, wrapper `onChanged`, render del chip, `_SuggestionChip`)
  - `mobile/pubspec.yaml` (`0.11.2+65`)
  - `mobile/android/app/build.gradle.kts` (versionCode 65)
  - `mobile/test/data/category_suggestion_test.dart` (nuevo, 18 UT)
  - `mobile/test/screens/entry_form_suggestion_test.dart` (nuevo, 4 WT)
- Áreas: cascada SQL nueva, race condition con Timer + generation counter, integración con form complejo, widget chip nuevo.

## Hallazgos bloqueantes

Ninguno.

## Hallazgos no bloqueantes

### M1. Comentario contradictorio en `_recalcSuggestion`

- Severidad: **Media** (no es bug runtime pero es trampa de mantenimiento)
- Área: documentación inline del form
- Evidencia: `mobile/lib/screens/entry_form_screen.dart:153-157`. El comentario dice *"No tocamos `_categoryId` — si había una sugerencia previa la dejamos hasta que algo la reemplace. Decisión: invalidar cuando deja de haber match."* — pero la línea siguiente hace `_categoryId = null`. La primera oración es remanente de versión pre-DV-02; la segunda describe el comportamiento real.
- Impacto: cualquier lectura en diagonal cree que el comportamiento es el opuesto al real.
- Recomendación: reescribir el comentario para reflejar DV-02 (invalidar sugerencia previa cuando la cascada deja de matchear).
- Depende de: nada. ~2 min.

### M2. Comentario inline sobre limitación SQLite `LOWER` ASCII-only

- Severidad: Media (mejora mantenibilidad)
- Área: SQL del paso 1 / documentación
- Evidencia: `mobile/lib/data/category_suggestion.dart:118`. La query usa `LOWER(TRIM(j.description)) = ?`. SQLite `LOWER` es ASCII-only: descripciones históricas con acentos en mayúscula (`"CAFÉ"`) no matchean con tipeo normalizado en Dart (`"café"`). El docstring del método no lo menciona.
- Impacto: bajo en uso real (Diego escribe en minúscula). Pero la limitación está documentada en R-04 del plan y CB-D16 del test-plan, no en el código.
- Recomendación: agregar comentario inline en la línea del SQL aclarando que `LOWER` es ASCII-only y que la normalización Dart cubre UTF-8.
- Depende de: nada. ~1 min.

### M3. Cobertura de tests: 3 casos borde simples sin cubrir

- Severidad: Media (gaps de cobertura)
- Área: tests
- Evidencia:
  - **CB-D05**: múltiples entries históricos con misma descripción y categorías distintas. El SQL usa `ORDER BY occurred_at DESC LIMIT 1`, pero sin test que blinde el orden.
  - **CB-D06**: entry histórico con `category_id IS NULL`. El `INNER JOIN` lo excluye, pero sin test demostrándolo.
  - **CB-D08**: paso 3 con `accountId` correcto pero ventana sin entries en últimos 30 días → null. Sin test directo.
- Impacto: si alguien cambia el ORDER BY o el INNER JOIN, los tests existentes no atrapan la regresión.
- Recomendación: agregar 3 UT cortos (~10 min total).
- Depende de: nada.

### B1. Confirmar sugerencia desde el picker (mismo valor) no marca touched

- Severidad: Baja (edge case real pero raro)
- Área: UX / state del form
- Evidencia: `mobile/lib/screens/entry_form_screen.dart:170-179`. `_onCategoryPickerChanged` define `isManualChange = value != _suggestedCategoryId`. Si Diego abre el dropdown, ve la sugerencia ya seleccionada y la vuelve a tocar (mismo valor), `isManualChange == false` → `_categoryTouched` queda en `false`. Si después tipea más descripción y la cascada cambia la sugerencia, la "confirmación" se pierde.
- Impacto: Diego puede percibir que la app le "borró" una elección que sintió haber confirmado. Escenario raro pero técnicamente inconsistente con el espíritu de RN-S07.
- Recomendación: cualquier interacción con el picker (incluso seleccionar el mismo valor) debería marcar `_categoryTouched = true`. Cambio trivial pero requiere repensar la heurística (¿es interacción manual o re-selección incidental?). Recomiendo dejar como **Baja para discutir**, no fixear ciegamente.
- Depende de: decisión de UX.

### B2. Tiebreak indeterminístico en paso 3 con empate total

- Severidad: Baja
- Área: SQL / determinismo
- Evidencia: `mobile/lib/data/category_suggestion.dart:201`. `ORDER BY uses DESC, last_use DESC`. Si dos categorías tienen idéntico `COUNT(*)` E idéntico `MAX(occurred_at)` (al segundo), el resultado depende del orden interno de SQLite.
- Impacto: muy bajo en single-user (timestamps únicos al segundo). Tests potencialmente flaky si el empate ocurre.
- Recomendación: agregar `j.category_id ASC` como tercer criterio. Trivial.
- Depende de: nada.

### B3. Interpolación de `accountColumn` en SQL string

- Severidad: Baja
- Área: SQL / defensa en profundidad
- Evidencia: `mobile/lib/data/category_suggestion.dart:154,194`. El identificador de columna (`account_origin_id` o `account_destination_id`) se interpola directamente en el SQL string. No es inyección porque el valor proviene de whitelist derivada del `kind`, pero es el único lugar del repo con interpolación de identificador.
- Impacto: nulo en el código actual. Si un futuro PR introduce un path que pase `accountColumn` de fuente externa, el patrón se vuelve peligroso.
- Recomendación: agregar `assert(accountColumn == 'account_origin_id' || accountColumn == 'account_destination_id')` para blindar la intención.
- Depende de: nada.

### B4. `onPopInvokedWithResult` no resetea flags de sugerencia

- Severidad: Baja (sin impacto observable)
- Área: state del form / consistencia
- Evidencia: `mobile/lib/screens/entry_form_screen.dart:484-495`. Al hacer back desde el form al KindPicker, los 3 flags de sugerencia quedan stale. El chip solo se renderiza dentro de `_buildForm()` (que solo corre con `_kind != null`), y `_selectKind` los resetea cuando se elige nuevo kind.
- Impacto: ninguno observable.
- Recomendación: por consistencia, resetear los 3 flags en el `onPopInvokedWithResult`. Opcional.
- Depende de: nada.

### B5. Casos race/timing sin tests (CB-D09, CB-D10, CB-D13, CB-D15)

- Severidad: Baja
- Área: tests
- Evidencia:
  - **CB-D09**: debounce agrupa múltiples cambios rápidos. El test usa un solo cambio + `pump(350ms)`.
  - **CB-D10**: race tras cambio de kind. El `_suggestionGeneration` protege, pero sin test.
  - **CB-D13**: dispose cancela Timer. El código lo hace, sin test.
  - **CB-D15**: dos queries lentas en sucesión. El `_suggestionGeneration` protege, sin test.
- Impacto: el código sí protege; lo que falta es validación. Tests de race/timing son notoriamente difíciles en Flutter sin mocks.
- Recomendación: dejar como deuda técnica. Si se quiere subir cobertura, requiere mocks o `FakeAsync`.
- Depende de: decisión.

## Plan de corrección ordenado

1. **M1** — reescribir comentario contradictorio. ~2 min.
2. **M2** — agregar comentario inline sobre LOWER ASCII-only. ~1 min.
3. **B2** — agregar `j.category_id ASC` como tercer tiebreak en paso 3. ~1 min.
4. **B3** — agregar `assert` defensivo en helpers del paso 2/3. ~2 min.
5. **B4** — resetear flags de sugerencia en `onPopInvokedWithResult`. ~2 min.
6. **M3** — agregar 3 UT para CB-D05, CB-D06, CB-D08. ~10 min.
7. **B1** — decisión de UX sobre touched al seleccionar mismo valor. Discutir.
8. **B5** — race/timing tests opcional. Difícil sin mocks.

Total accionable (1-6): ~20 min para todo el lote no discutible.

## Validaciones recomendadas

```bash
cd mobile
flutter test test/data/category_suggestion_test.dart
flutter test test/screens/entry_form_suggestion_test.dart
flutter test
flutter analyze
```

Smoke manual (T017 del plan):

- SM-01..SM-06 del test-plan.
- Especialmente SM-02 (match descripción), SM-03 (income), SM-04 (manual override).

## Limitaciones

- Review sobre cambios working-tree, no sobre commit final. Los cambios pueden ajustarse antes de commit.
- No se ejecutó `flutter test` durante la revisión (el implementation-review confirma 343/343).
- Race conditions: validamos el código protege, pero no testamos comportamiento bajo carga (notoriamente difícil sin `FakeAsync`).
- B1 (touched al seleccionar mismo valor) es decisión de UX que requiere input de Diego.
- Performance con journal grande no medida (consistente con sprint anterior, aceptable para single-user).
