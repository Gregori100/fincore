# Tasks — flutter-entries-category-suggestion-v1

Tareas en orden de dependencia. IDs estables `T001`, `T002`, ...

## Base de datos

No aplica. Sin migración. Sin schema bump.

## Backend (data layer)

- [ ] **T001 Backend**: crear `mobile/lib/data/category_suggestion.dart` con clase `CategorySuggestionService` que recibe `FincoreDatabase` en constructor. Patrón idéntico a `ReportsService`.
  RF: RF-001
  Depende de: ninguna
  Paralelizable: sí
  Criterio de terminado: la clase compila con `flutter analyze` limpio y el constructor no requiere parámetros adicionales.

- [ ] **T002 Backend**: implementar método `suggestForNewEntry({required String kind, required String? accountId, required String? description, required double? amount, DateTime? now})` con la cascada de 3 queries.
  - Paso 1: match exacto de descripción normalizada (Dart `trim().toLowerCase()`) con `applies_to` compatible.
  - Paso 2: match de monto+cuenta+kind dentro de últimos 90 días.
  - Paso 3: categoría más usada por kind+cuenta últimos 30 días con tiebreak por `MAX(occurred_at)`.
  - Para income: usar `account_destination_id` como "cuenta relevante"; resto: `account_origin_id`.
  - Short-circuit: `description` null/empty salta paso 1; `amount` null/0 salta paso 2; `accountId` null salta pasos 2 y 3.
  RF: RF-001, RF-002, RN-S01, RN-S03, RN-S04, RN-S05, RN-S06
  Depende de: T001
  Paralelizable: no
  Criterio de terminado: método retorna `Future<String?>` correcto. UT-01..UT-16 pasan.

- [ ] **T003 Backend**: registrar `CategorySuggestionService` en `mobile/lib/app_dependencies.dart`:
  - Agregar field `final CategorySuggestionService categorySuggestionService;`.
  - Instanciarlo en `AppDependencies.fromDatabase()`.
  - Agregarlo al constructor `required`.
  RF: SP-11 (acceso vía `AppDependencies.of(context).categorySuggestionService`)
  Depende de: T001
  Paralelizable: no
  Criterio de terminado: el servicio se inyecta y se accede desde el form sin errores de compilación.

## Frontend

- [ ] **T004 Frontend**: agregar state al `_EntryFormScreenState` en `entry_form_screen.dart`:
  - `bool _categoryTouched = false`
  - `bool _categorySuggested = false`
  - `Timer? _suggestionDebounce`
  - `int _suggestionGeneration = 0`
  - `String? _suggestedCategoryId` (para distinguir el ID que vino de sugerencia vs manual)
  RF: RF-004, RF-006, RF-007
  Depende de: T003
  Paralelizable: no
  Criterio de terminado: state declarado, sin uso aún. Compila.

- [ ] **T005 Frontend**: implementar `_recalcSuggestion()` en el form:
  - Early-return si `_isEdit` (RF-008 + R-03).
  - Early-return si `_categoryTouched`.
  - Cancelar `_suggestionDebounce` previo.
  - Incrementar `_suggestionGeneration` y capturar el valor.
  - Programar `Timer(Duration(milliseconds: 300), ...)` que invoque el servicio con los inputs actuales.
  - Tras await del servicio: si `_suggestionGeneration` cambió o el form se desmontó (`!mounted`), descartar; sino setear `_categoryId` + `_categorySuggested = true` + `_suggestedCategoryId = result`.
  - Para income: pasar `_destId`; resto: `_originId`.
  RF: RF-003, RF-009, R-01, R-02, R-08
  Depende de: T004
  Paralelizable: no
  Criterio de terminado: método invocable y testeable. Test del race (CB-D10) pasa.

- [ ] **T006 Frontend**: agregar triggers de `_recalcSuggestion()`:
  - Listeners en `_descCtrl` y `_amountCtrl` (`addListener` en `initState` o `_bootstrap`).
  - Invocación desde `_selectKind()` (debe resetear `_categoryTouched = false` también, ya que el kind cambió todo).
  - Invocación desde `setState` cuando cambia `_originId` o `_destId` (en los handlers de `AccountPicker.onChanged`).
  - Limpiar listeners y cancelar Timer en `dispose()`.
  RF: RF-003, CB-T07, CB-T08, CB-T13, R-01
  Depende de: T005
  Paralelizable: no
  Criterio de terminado: triggers funcionan. Test del debounce (WT-S01) pasa.

- [ ] **T007 Frontend**: envolver `CategoryPicker.onChanged` para detectar interacción manual:
  - Si el valor entrante es distinto al `_suggestedCategoryId` (es decir, no es la pre-selección automática), marcar `_categoryTouched = true` y `_categorySuggested = false`.
  - Si Diego cambia a `null` (Sin categoría), también marca como touched.
  RF: RF-006, RF-007
  Depende de: T005
  Paralelizable: sí (con T008)
  Criterio de terminado: cambiar la sugerencia desactiva el flag. Test WT-S02 pasa.

- [ ] **T008 Frontend**: implementar widget privado `_SuggestionChip` en el mismo archivo del form:
  - Container pequeño con `Icons.auto_awesome` + texto "Sugerida".
  - Color `FincoreColors.accent` con alpha 0.15 para fondo, border accent.
  - Padding/margin proporcional al diseño del form.
  - Render condicional en el build: `if (_categorySuggested && _categoryId != null) _SuggestionChip()` debajo del `CategoryPicker`.
  RF: RF-005, SP-01
  Depende de: T004
  Paralelizable: sí (con T007)
  Criterio de terminado: el chip se renderiza solo cuando hay sugerencia activa. Visualmente coherente con el theme.

## Pruebas

- [ ] **T009 Pruebas**: crear `mobile/test/data/category_suggestion_test.dart` con UT-01 a UT-05 (BD vacía, paso 1 match exacto, normalización, archivados, `applies_to` incompatible).
  RF: RF-001, RN-S03 paso 1, RN-S04, RN-S06
  Depende de: T002
  Paralelizable: sí
  Criterio de terminado: 5 tests verdes.

- [ ] **T010 Pruebas**: agregar UT-06 a UT-10 (paso 2 monto+cuenta, fuera de 90 días, income usa destination, paso 3 más usada, tiebreak).
  RF: RN-S03 pasos 2 y 3, RN-S01 (income)
  Depende de: T002
  Paralelizable: sí
  Criterio de terminado: 5 tests verdes.

- [ ] **T011 Pruebas**: agregar UT-11 a UT-16 (cascada que retorna null, accountId null, description null, amount null, `now` inyectable, soft delete).
  RF: edge cases, RF-001 con `now` opcional
  Depende de: T002
  Paralelizable: sí
  Criterio de terminado: 6 tests verdes.

- [ ] **T012 Pruebas**: agregar WT-S01..WT-S04 en `mobile/test/screens/entry_form_screen_test.dart` (o archivo separado si crece mucho): sugerencia visible al matchear, manual override desactiva, edit no dispara, BD vacía no muestra chip.
  RF: RF-003, RF-005, RF-006, RF-007, RF-008
  Depende de: T005, T006, T007, T008
  Paralelizable: no
  Criterio de terminado: 4 widget tests verdes.

## Validación de calidad

- [ ] **T013 Validación**: `flutter analyze` con 0 errores nuevos. Los 4 hints `info` pre-existentes siguen tolerados.
  Depende de: T001..T012
  Paralelizable: no
  Criterio de terminado: salida limpia.

- [ ] **T014 Validación**: `flutter test` verde con la suite completa (~337-340 tests esperados).
  Depende de: T001..T012
  Paralelizable: no
  Criterio de terminado: "All tests passed!".

- [ ] **T015 Validación**: bump de versión en `mobile/pubspec.yaml` (`0.11.1+64 → 0.11.2+65`) y `mobile/android/app/build.gradle.kts` (`versionCode = 65`, `versionName = "0.11.2"`).
  Depende de: T013, T014
  Paralelizable: no
  Criterio de terminado: ambos archivos sincronizados. `scripts/verify-apk.sh` pasa al construir el APK.

- [ ] **T016 Validación**: invocar skill `branch-quality-review` con argumento `flutter-entries-category-suggestion-v1`. Si surgen hallazgos bloqueantes, corregirlos antes del commit final.
  Depende de: T015
  Paralelizable: no
  Criterio de terminado: reporte generado en `engineering/quality-review/flutter-entries-category-suggestion-v1/`. Hallazgos Altas/Críticas atendidos o documentados con criterio.

- [ ] **T017 Validación**: smoke manual SM-01..SM-06 (Diego confirma).
  Depende de: T015
  Paralelizable: sí (con T016)
  Criterio de terminado: Diego confirma "todo OK".

## Documentación

- [ ] **T018 Documentación**: crear `engineering/specs/flutter-entries-category-suggestion-v1/implementation/resumen-ejecutivo.md` (1-2 párrafos), `resumen-extenso.md` (decisiones tomadas, casos cubiertos, pendientes), `implementation-review.md` (formato estándar).
  Depende de: T013, T014
  Paralelizable: sí
  Criterio de terminado: 3 archivos creados con contenido real (no stubs).
