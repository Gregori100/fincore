# Test plan — flutter-entries-category-suggestion-v1

## Casos borde detectados

Más allá de los listados en `spec.md`, esta lista cubre escenarios concretos que pueden romper la sugerencia o el form:

- **CB-D01**: `description == null` y `amount == null` y `accountId == null` → cascada cae a paso 3 (más usada por kind sin filtro de cuenta) o retorna `null`. **Decisión a implementar**: el paso 3 requiere `accountId`; si todo es null, retornar `null` sin tocar BD.
- **CB-D02**: BD totalmente vacía (sin entries ni categorías) → retornar `null` rápido.
- **CB-D03**: Hay entries pero ninguna categoría activa (todas archivadas) → todos los pasos retornan `null` por el JOIN con `categories.deleted_at IS NULL`.
- **CB-D04**: Match exacto de descripción pero la categoría tiene `applies_to` incompatible con el kind actual. El SQL ya filtra; el paso 1 retorna null y se intenta paso 2.
- **CB-D05**: Múltiples entries con la misma descripción exacta y categorías distintas. El SQL con `ORDER BY occurred_at DESC LIMIT 1` retorna el más reciente.
- **CB-D06**: Paso 2 con monto exacto pero entry histórico tiene `category_id == null`. El JOIN elimina ese candidato (no hay categoría que sugerir).
- **CB-D07**: Paso 3 empate de frecuencia entre 2 categorías. Tiebreak por `MAX(occurred_at)` DESC.
- **CB-D08**: Paso 3 con `accountId` correcto pero ningún entry en últimos 30 días. Retornar null sin error.
- **CB-D09**: Diego escribe descripción muy rápido (10 chars en 200ms). El debounce de 300ms agrupa todos los cambios en una sola query final.
- **CB-D10**: Diego cambia kind de `expense` a `income` mientras una query del paso 1 está en flight. El resultado de esa query no debe aplicarse (race). Mitigar con `_suggestionGeneration`.
- **CB-D11**: Diego escribe descripción "Café" → la sugerencia setea "Café" → Diego cambia a "Compras" manualmente → escribe " Starbucks" al final. La sugerencia NO debe volver a calcularse porque `_categoryTouched = true`.
- **CB-D12**: Diego abre `/entries/new`, kind por default ya seleccionado. La sugerencia se dispara automáticamente con descripción/monto/cuenta vacíos → cascada cae a paso 3 (si tiene cuenta), o `null`.
- **CB-D13**: Diego sale del form sin guardar (`Navigator.pop`). El `Timer` debe cancelarse en `dispose` para evitar `setState after dispose`.
- **CB-D14**: Editar entry existente con `widget.entryId != null`. El `_recalcSuggestion` debe early-return sin tocar `_categoryId`.
- **CB-D15**: Diego cambia descripción → debounce dispara → query lenta (~100ms simulado) → Diego cambia descripción otra vez antes de que termine. El primer resultado debe descartarse.
- **CB-D16**: Entry histórico con descripción `"  CAFÉ  "` (espacios + mayúsculas + acento). Diego escribe `"café"`. ¿Matchea?
  - Normalización en Dart (`'café'.trim().toLowerCase()` = `'café'`) → OK.
  - SQL: `LOWER(TRIM(j.description))` con `'  CAFÉ  '` → SQLite `LOWER` ASCII-only retorna `'  cafÉ  '` (la É no se baja). El `TRIM` quita espacios → `'cafÉ'` ≠ `'café'`. **Falla**.
  - Mitigación: normalizar en Dart ambos lados es imposible (no podemos pre-normalizar la columna en SQL). Aceptamos la limitación: matches solo con descripciones ASCII o con acentos consistentes en minúscula histórica. Documentar en R-02 del spec.
- **CB-D17**: Categoría sugerida con `applies_to = 'both'` para un kind income. Debe seguir siendo válida (el filtro `IN ('income', 'both')` la incluye).

## Pruebas unitarias necesarias

Ubicación: `mobile/test/data/category_suggestion_test.dart` (archivo nuevo).

- **UT-01**: BD vacía → `null`.
- **UT-02**: Paso 1 match exacto: descripción "Café" coincide con entry previo `expense` con categoría "Café" activa → retorna el ID de "Café".
- **UT-03**: Paso 1 con normalización de espacios y mayúsculas: descripción "  café  " del input + entry histórico con "Café" → matchea (ambos normalizados en Dart). Validar el caso ASCII; CB-D16 documentado como limitación.
- **UT-04**: Paso 1 ignora categorías archivadas: histórico con "Café" pero "Café" archivada → cascada baja al paso 2.
- **UT-05**: Paso 1 ignora `applies_to` incompatible: histórico income con categoría "Salario" (income), query con kind expense → no matchea, cascada baja.
- **UT-06**: Paso 2 monto+cuenta: amount=1500 + accountId=banamex_id + kind=expense en últimos 90 días → retorna categoría del entry más reciente con esos atributos.
- **UT-07**: Paso 2 ignora entries fuera de los 90 días: entry con match a 91 días atrás → cascada baja al paso 3.
- **UT-08**: Paso 2 con kind income usa `account_destination_id` en lugar de `account_origin_id`.
- **UT-09**: Paso 3 más usada por kind+cuenta últimos 30 días: 3 entries de "Comida" (last 25 days) vs 1 de "Transporte" → retorna "Comida".
- **UT-10**: Paso 3 tiebreak: 2 categorías con 5 usos cada una en ventana → la con `MAX(occurred_at)` más reciente gana.
- **UT-11**: Cascada completa: matchea ninguna → retorna `null`.
- **UT-12**: `accountId == null` → pasos 2 y 3 se saltan; solo se evalúa paso 1.
- **UT-13**: `description == null` o empty → paso 1 se salta.
- **UT-14**: `amount == null` o 0 → paso 2 se salta.
- **UT-15**: `now` inyectable: con `now = 2026-03-15`, paso 3 filtra correctamente entries de 2026-02-13 (30 días).
- **UT-16**: Soft-deleted entry no aparece como candidato (filtro `journal_entries.deleted_at IS NULL`).

## Pruebas de integración o API necesarias

No aplica. FinCore no expone HTTP. Las pruebas de integración aquí son las unit tests sobre SQLite real (`NativeDatabase.memory()`).

## Pruebas de UI o flujo necesarias

Ubicación: `mobile/test/screens/entry_form_screen_test.dart` (extender existente) y/o nuevo grupo.

- **WT-S01**: Form nuevo expense con histórico sembrado → escribir descripción que matchea → chip "Sugerida" aparece + picker pre-seleccionado.
- **WT-S02**: Form nuevo expense → chip aparece tras la sugerencia → tappear otra categoría en el picker → chip desaparece + `_categoryTouched = true` (no se recalcula con escribir más texto).
- **WT-S03**: Editar entry existente con categoría seteada → chip nunca aparece + categoría intacta tras escribir descripción.
- **WT-S04**: BD vacía + form nuevo → escribir descripción → chip NO aparece, picker vacío como hoy.

## Pruebas de permisos y seguridad

No aplica (single-user, BD local).

## Pruebas de datos, migración o compatibilidad

No aplica (sin schema bump). Smoke manual confirma que abrir el APK nuevo sobre BD existente no causa regresión.

## Pruebas de regresión sobre flujos existentes

- **RG-01**: Suite completa (`flutter test`) verde. Espera 321 → ~337-340 tests (+16-19 nuevos).
- **RG-02**: Tests existentes de `entry_form_screen_test.dart` + `entry_form_kinds_test.dart` siguen verdes sin cambios (la sugerencia no rompe el flujo de captura sin histórico).
- **RG-03**: Test del flujo de edit (cancelar entry, modificar) verde.
- **RG-04**: `flutter analyze` sin warnings nuevos. Los 4 hints `info` pre-existentes siguen tolerados.

## Pruebas manuales o smoke tests necesarios

- **SM-01**: Instalar APK sobre BD real. Abrir `/entries/new`. Validar que el flujo de captura sin histórico es idéntico al actual (sin sugerencia visible).
- **SM-02**: Crear un par de entries con misma descripción (e.g. "Café"). Crear otro entry nuevo con `kind=expense` y escribir "Café" → la sugerencia debe pre-seleccionar la categoría usada antes + chip "✨ Sugerida".
- **SM-03**: Crear entries de income con misma descripción (e.g. "Salario") → crear nuevo entry income → la sugerencia debe funcionar igual que con expense.
- **SM-04**: Cambiar la sugerencia manualmente → seguir escribiendo descripción → el chip no debe volver, la categoría no debe cambiar.
- **SM-05**: Cambiar el kind tras tener una sugerencia (sin tocar el picker) → la sugerencia debe recalcularse para el nuevo kind.
- **SM-06**: Editar entry existente → el chip "Sugerida" nunca aparece, la categoría se mantiene como estaba.

## Datos de prueba recomendados

Para los unit tests del servicio:

- BD in-memory con Bolsa + 1 debit + 1 credit.
- 3-5 categorías activas: "Comida_T" (expense), "Café_T" (expense), "Transporte_T" (expense), "Salario_T" (income), "Misc_T" (both).
- 1 categoría archivada: "Old_T" (expense).
- Entries históricos diversos: varios "Café", varios "Comida", uno con descripción única, uno fuera de la ventana de 30 días, uno fuera de 90 días.

Para widget tests:

- Reusar `pumpFincoreApp` con seed extra. Sembrar 5-10 entries históricos para tener al menos un match.

## Comandos o validaciones locales sugeridas

```bash
cd mobile

# Unit tests del servicio
flutter test test/data/category_suggestion_test.dart

# Widget tests del form (extendidos)
flutter test test/screens/entry_form_screen_test.dart

# Suite completa (regresión)
flutter test

# Lint
flutter analyze

# Validación de versión del APK release
flutter build apk --release --split-per-abi
scripts/verify-apk.sh build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

## Criterios mínimos para aprobar la implementación

- `flutter analyze` con 0 errores nuevos.
- `flutter test` verde con ~16 unit tests + 4 widget tests nuevos.
- Smoke SM-01 + SM-02 confirmados manualmente.
- Cumple AC-01 → AC-10 del spec.
- Sin cambios en `pubspec.lock` más allá del version bump.
- Cancelación del Timer en `dispose` verificable por test (no debe haber `setState after dispose` warnings).

## Validación final recomendada

Tras implementar, invocar `branch-quality-review` con argumento `flutter-entries-category-suggestion-v1`. El reporte se generará en `engineering/quality-review/flutter-entries-category-suggestion-v1/`.

Si la skill no se invoca, hacer revisión equivalente manual:

- Verificar que el servicio no tiene queries N+1.
- Verificar que el `Timer` se cancela en `dispose`.
- Verificar que el `_suggestionGeneration` protege contra races.
- Verificar que el wrapper de `onChanged` del `CategoryPicker` distingue cambios manuales de pre-selección.
- Verificar que el version bump está sincronizado entre `pubspec.yaml` y `android/app/build.gradle.kts`.
- Verificar que no se agrega lógica de sugerencia al `CategoryPicker` (reusable).
