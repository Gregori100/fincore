# Plan técnico — flutter-entries-category-suggestion-v1

## Enfoque técnico

- **Sin schema bump, sin migración**: el servicio solo lee `journal_entries` + `categories`.
- **Nuevo servicio `CategorySuggestionService`** en `mobile/lib/data/category_suggestion.dart`. Constructor recibe `FincoreDatabase`. Patrón idéntico al de `ReportsService`.
- **Algoritmo en cascada de 3 queries** (`getSingleOrNull`), ejecutadas en orden hasta que una retorne resultado. NO se usa `watch()` — la sugerencia es puntual (no reactiva): se computa una vez con los inputs actuales del form y se aplica.
- **Inyección** en `AppDependencies.fromDatabase()` siguiendo el patrón existente (`final categorySuggestionService = CategorySuggestionService(database);`).
- **Form `entry_form_screen.dart`**:
  - Nuevo state: `bool _categoryTouched = false`, `bool _categorySuggested = false`, `Timer? _suggestionDebounce`.
  - Método `_recalcSuggestion()` invoca el servicio con debounce 300 ms; respeta `_categoryTouched` (short-circuit si es true).
  - Triggers:
    - `_selectKind()` → cancelar debounce previo + disparar nuevo cálculo (también resetea `_categoryTouched` porque cambiar kind implica reset del form).
    - `_descCtrl` / `_amountCtrl` `addListener` → disparar con debounce.
    - Cambio de `_originId` / `_destId` → disparar inmediato (sin debounce porque es click, no tipeo).
  - `CategoryPicker.onChanged` envuelto: si el cambio viene del usuario (cualquier valor distinto al actual seteado por sugerencia), setear `_categoryTouched = true` + `_categorySuggested = false`.
- **Sello visual**: chip pequeño **debajo** del `CategoryPicker`, NO modificando el widget. Render condicional en el form: `if (_categorySuggested && _categoryId != null) _SuggestionChip()`. Widget privado del form (`_SuggestionChip`) con icono `Icons.auto_awesome` (sparkle) + texto "Sugerida", color accent con alpha bajo, borde accent. Removerlo es inserción puntual en el `Column` del form.
- **Compatibilidad `applies_to`**: el SQL filtra por `c.applies_to IN (...)` usando los valores derivados de `JournalKind.validCategoryAppliesTo`. Para expense/credit_expense: `'expense', 'both'`. Para income: `'income', 'both'`.
- **Normalización en Dart**: el servicio normaliza `description?.trim().toLowerCase()` antes de mandarla como `Variable.withString` para evitar depender de SQLite `LOWER`/`TRIM` (RN-A02 del repo: SQLite `LOWER` es ASCII-only; ver R-02 del spec).
- **`now` inyectable**: el método acepta `DateTime? now` opcional para tests deterministas. Default `DateTime.now()`.

## Requisitos funcionales cubiertos

- **RF-001** (método del servicio): `CategorySuggestionService.suggestForNewEntry({required String kind, required String? accountId, required String? description, required double? amount, DateTime? now})` retorna `Future<String?>`. La firma queda con `accountId` único; el form decide qué pasar.
- **RF-002** (cascada con filtros): cada paso de la cascada se ejecuta como query separada con `getSingleOrNull`. Sin tratar de combinarlas en una sola query — la lógica del "fallthrough" es más clara con queries explícitas y el costo total es trivial (3 queries con LIMIT 1).
- **RF-003** (triggers del form): listeners en TextField + setState en `_selectKind`/cambios de account + debounce 300 ms via `Timer`.
- **RF-004** (estado de sugerencia): flag `_categorySuggested` se setea junto con `_categoryId` cuando proviene de la sugerencia.
- **RF-005** (sello visual): `_SuggestionChip` widget privado dentro del archivo del form.
- **RF-006 / RF-007** (manual touch): el `onChanged` del `CategoryPicker` (envuelto) marca `_categoryTouched = true` cuando el usuario cambia el valor.
- **RF-008** (reset al volver a entrar): el form es `StatefulWidget`. Al popearse y volver, el state se recrea con `_categoryTouched = false`.
- **RF-009** (índices): la query del paso 1 usa `idx_entries_kind` + filtro por descripción; los pasos 2 y 3 usan `idx_entries_kind` + `idx_entries_occurred_active`. Sin necesidad de índices nuevos para volúmenes single-user.

## Archivos o módulos probablemente afectados

- `mobile/lib/data/category_suggestion.dart` — **archivo nuevo**, servicio + queries.
- `mobile/lib/app_dependencies.dart` — agregar field `final CategorySuggestionService categorySuggestionService;` + inyección en `fromDatabase`.
- `mobile/lib/screens/entry_form_screen.dart` — state nuevo, listeners, `_recalcSuggestion()`, render del chip, wrapper del `onChanged` del `CategoryPicker`. Probable: +60-100 líneas.
- `mobile/test/data/category_suggestion_test.dart` — **archivo nuevo** con ~10-12 unit tests.
- `mobile/test/screens/entry_form_screen_test.dart` y/o `entry_form_kinds_test.dart` — agregar widget tests del flujo de sugerencia.
- `mobile/pubspec.yaml` — bump versión `0.11.1+64 → 0.11.2+65` (patch por feature pequeño no-breaking).
- `mobile/android/app/build.gradle.kts` — bump correspondiente.

## Entidades y estados afectados

- **`JournalEntry`**: solo lectura. Filtros: `kind IN ('expense', 'credit_expense', 'income')`, `deleted_at IS NULL`, según paso de la cascada.
- **`Category`**: solo lectura. Filtros: `deleted_at IS NULL`, `applies_to IN (...)` derivado del kind.
- **Sin entidades nuevas**. Sin transiciones de estado en BD. Sin invariantes nuevas.
- **State del form**: el form gana 3 fields nuevos (`_categoryTouched`, `_categorySuggested`, `_suggestionDebounce`) y un widget privado (`_SuggestionChip`). Sin cambios en la persistencia (al guardar, `_categoryId` ya está seteado por la sugerencia o por elección manual, y el DAO no distingue origen).

## Compatibilidad con datos y procesos existentes

- **100% backward compatible**: el servicio solo lee. El form mantiene su flujo de guardado sin cambios — el `_submit` sigue pasando `_categoryId` al DAO como hoy.
- **Sin impacto en backup JSON v1**: no se agregan campos a entries ni a categorías.
- **Sin impacto en otros reportes**: ReportsService no se modifica.
- **Sin impacto en widget tests existentes**: el flujo de captura sin sugerencia (BD vacía o categoría no matcheable) es idéntico al actual. Los tests que pasan hoy seguirán pasando.
- **Compatibilidad con edit**: el form al editar ignora la sugerencia (`if (_isEdit) return` en `_recalcSuggestion`).

## Cambios de datos

No aplica. Sin migración, sin tablas/columnas nuevas, sin seeds nuevos.

## Cambios de API

No aplica (sin HTTP). El cambio público es la firma del servicio nuevo:

```dart
class CategorySuggestionService {
  Future<String?> suggestForNewEntry({
    required String kind,
    required String? accountId,
    required String? description,
    required double? amount,
    DateTime? now,
  });
}
```

## Cambios de integraciones

No aplica.

## Cambios de UI

- Sello "Sugerida" debajo del `CategoryPicker` solo en `/entries/new` cuando `_categorySuggested == true`.
- Reusa: `FincoreColors.accent`, `Icons.auto_awesome`, BaseCard NO (el chip es más liviano), padding propio.
- Sin cambios en `CategoryPicker`, `AccountPicker`, `KindPicker`, `AmountFormatter`.

## Cambios de permisos

No aplica (single-user).

## Riesgos técnicos

- **R-01** (`Timer` leak): el `_suggestionDebounce` debe cancelarse en `dispose()` del form. Sin esto, una sugerencia pendiente puede ejecutar `setState` con el form desmontado y crashear o producir error de "setState after dispose".
- **R-02** (race condition con cambio de kind): si Diego cambia el kind rápido mientras una sugerencia está en flight, el resultado puede llegar después del reset (`_selectKind`) y aplicar una categoría incorrecta. Mitigar capturando el `kind` en el momento de disparar y descartando si no coincide al volver.
- **R-03** (interacción con `_isEdit`): el `_recalcSuggestion` debe short-circuit con `if (_isEdit) return` para que no sobrescriba la categoría del entry en edición. Test específico (WT-EDIT-01).
- **R-04** (acentos en `LOWER`): la normalización en Dart (`description.trim().toLowerCase()`) maneja UTF-8 acentos correctamente. La query SQL recibe el valor ya normalizado vía `Variable.withString`. Pero las descripciones HISTÓRICAS en BD pueden estar guardadas con mayúsculas o espacios. Mitigar normalizando AMBOS lados en el SQL con `LOWER(TRIM(j.description))`. SQLite `LOWER` con UTF-8 puede no normalizar "Á" → "á"; aceptable como degradación: si Diego escribe acentos en mayúscula consistentemente, no impacta; documentar.
- **R-05** (categoría sugerida queda "fantasma" al cancelar): si Diego presiona "Cancelar" del form, no hay persistencia (el `_categoryId` solo vive en state). Sin riesgo.
- **R-06** (perf con journal grande): el paso 3 con `GROUP BY` puede ser costoso con 10k+ entries. Volumen single-user real está muy lejos de esto; aceptable.
- **R-07** (sugerencia muestra categoría compatible con kind pero el form la rechaza al guardar): el SQL filtra por `applies_to IN (...)` derivado del kind actual. Si la categoría histórica tiene `applies_to = 'both'`, sigue siendo válida. Sin desincronización esperada.
- **R-08** (Timer cancelado pero query ya disparada): si el debounce dispara la query y luego cambia el input, la query antigua puede retornar resultado obsoleto. Mitigar capturando un `int _suggestionGeneration++` y descartando resultados de generaciones viejas.

## Estrategia de pruebas

- **Unit tests** (`test/data/category_suggestion_test.dart`): ~12 tests cubriendo cada paso de la cascada + edge cases. Ver `test-plan.md`.
- **Widget tests** (`test/screens/entry_form_*_test.dart`): ~4 tests cubriendo: sugerencia aparece + sello visible, manual override hace desaparecer sello, edit no dispara sugerencia, debounce no causa flicker.
- **Sin tests de integración** (no hay HTTP).
- **Sin tests de migración**.
- **Smoke manual** sobre BD real con histórico de uso.

Detalle completo en `test-plan.md`.

## Estrategia de rollback

- **Revert simple**: el sprint solo agrega un archivo nuevo + state al form + bump de versión. `git revert` deja la app exactamente como antes. Sin schema bump, sin migraciones.
- **Toggle implícito**: si el servicio retorna error o no encuentra sugerencia, el form arranca vacío como hoy. La feature degrada sin afectar funcionalidad existente.

## Orden sugerido de implementación

1. **Backend (data layer)** primero: servicio + queries + tests unit. Le da al frontend un contrato firme.
2. **Inyección en `AppDependencies`**.
3. **Frontend**: state + listeners + `_recalcSuggestion` + sello visual + wrapper de `onChanged`.
4. **Widget tests**.
5. **Versión bump + analyze + test final**.

Detalle en `tasks.md`.

## Casos borde que condicionan la solución

- **`description` null o whitespace**: el paso 1 de la cascada se debe omitir (no buscar match exacto si no hay texto). Implementar como `if (normalized.isEmpty) skip step 1`.
- **`amount` null o 0**: el paso 2 se debe omitir. `if (amount == null || amount == 0) skip step 2`.
- **`accountId` null**: el paso 2 y paso 3 dependen de la cuenta. Si es null, ambos se omiten y solo queda el paso 1.
- **Categoría compatible pero con `applies_to = 'both'`**: cuenta como válida tanto para income como para expense/credit_expense. Sin tratamiento especial.
- **Race condition con cambio de kind durante una query en flight**: mitigar con `_suggestionGeneration` (contador) y descartar resultados de generaciones obsoletas. Patrón común para debounce + async.
- **Diego presiona el chip "Sugerida"**: el chip es informativo, no interactivo. Sin onTap. Si Diego intenta tocarlo nada pasa.
- **Categoría sugerida fue archivada justo después de la query y antes del render**: improbable (mismo isolate), pero el `CategoryPicker` ya filtra archivadas; el valor seleccionado quedaría "fantasma". Caso teórico, no se cubre activamente.

## Preguntas o supuestos que siguen afectando la implementación

Todas las preguntas (P-001..P-004) están **respondidas** y reflejadas en `spec.md` + `clarificaciones.md`. No hay bloqueos.

Supuestos del plan que merecen registro:

- **SP-01**: el sello "Sugerida" se renderiza en el form (no en `CategoryPicker`). Razón: el `CategoryPicker` debe seguir siendo reusable en otras pantallas (`EntriesFiltersScreen` lo usa para filtros) sin contaminarse con lógica de sugerencia. Trade-off: la presencia del sello queda acoplada al form.
- **SP-02**: el debounce está en el form, no en el servicio. Razón: el servicio es agnóstico al "cuándo" se le llama; el form decide la cadencia. Permite testear el servicio sin manejar Timer.
- **SP-03**: las 3 queries de la cascada se ejecutan en secuencia (no en paralelo). Razón: cada query depende de que la anterior no haya retornado; ejecutar paralelo desperdiciaría ciclos cuando el paso 1 ya matchea. Volumen es despreciable.
- **SP-04**: la API del servicio retorna solo `categoryId` (no la categoría completa con name/colorSlug). Razón: el form ya tiene la lista de categorías cargada en `_categories`; con el ID basta para identificar y renderizar. Si en el futuro se quiere "auto-completar" más campos (e.g. monto recurrente), se extiende la respuesta.
- **SP-05**: el `_suggestionGeneration` se incrementa antes de cada disparo. El resultado solo se aplica si la generación coincide con la actual. Patrón estándar para debounce + async safe.
