# Resumen extenso — flutter-movements-amount-filter-v1

## Contexto tomado de spec.md y supuestos

Sprint chico (~2h reales) que sigue al **F4 cashflow** del menú post-
deuda-técnica. Cierra la última dimensión faltante del panel de filtros
de `/entries`, completando la lista (fecha, tipo, cuenta, categoría,
monto).

Sin `preguntas.md` — la spec resolvió todos los detalles con supuestos
documentados (RN-A01..A08). Los más relevantes:

- **Filtrar por amount crudo** (sin signo). Coherente con cómo Diego ve
  los montos en la lista (formateados positivos con signo cosmético
  derivado del kind).
- **Inclusivo en ambos extremos** (`>= min`, `<= max`). Coherente con
  rango de fechas y rango del spending tab.
- **Validación `min > max` al "Aplicar"** (no en tiempo real al typing).
  Patrón consistente con date picker custom.
- **Sección "Monto" entre "Cuenta" y "Categorías"** en el panel.
- **Nuevos campos opcionales con default null** — preserva firma para
  callers existentes.

## Relación con plan/plan.md y plan/tasks.md

Las 19 tareas del plan ejecutadas en orden de las 5 fases (F0 → F5)
sin desviaciones materiales. Detalle:

- **F0** (T001): baseline `flutter test` → 235/235 verdes confirmado.
- **F1** (T002-T005): modelo `EntriesFilters` + enum `FilterDimension`
  extendidos en `lib/data/entries_filters.dart`.
- **F2** (T006): DAO `EntriesDao.watchPage` con 2 params opcionales en
  `lib/data/daos/entries_dao.dart`.
- **F3** (T007-T010): UI — sección "Monto" en el panel + chip en la bar
  + paso de `min`/`max` al `watchPage` en `EntriesPaginatedList`.
- **F4** (T011-T015): 16 tests nuevos (6 DAO + 7 modelo + 3 widget).
- **F5** (T016-T019): suite verde, bump 0.7.1+59, APK + verify, docs.

## Cambios principales por módulo o capa

### Capa de modelo (`lib/data/entries_filters.dart`)

- Campos nuevos: `final double? minAmount;` y `final double? maxAmount;`.
- Constructor con dos params opcionales sin default explícito (null
  implícito).
- `copyWith` extendido con `double? minAmount`, `double? maxAmount`,
  `bool clearMinAmount = false`, `bool clearMaxAmount = false`.
  El sentinel `clear*: true` gana sobre el valor explícito (documentado
  en doc-comment).
- `activeCount` suma 1 si `minAmount != null || maxAmount != null`
  (cuenta como 1 dimensión, no 2 — RF-005).
- `clearDimension(FilterDimension.amount)` retorna copia con ambos en
  null vía `clearMinAmount: true, clearMaxAmount: true`.
- `serialize()` agrega `minAmount=X` y/o `maxAmount=Y` cuando están
  presentes; omite cuando son null para mantener URLs cortas.
- `parse` lee los query params con `_tryParseNonNegativeDouble`
  (helper privado nuevo del archivo) que retorna null para no-numérico
  o negativos — RN-A07.
- `FilterDimension` enum extendido con `amount` al final.

### Capa de datos (`lib/data/daos/entries_dao.dart`)

- `watchPage` con 2 params opcionales adicionales (`minAmount: double?`,
  `maxAmount: double?`) entre `to` y `offset` en la signature.
- Si `minAmount != null`, agrega
  `query.where(journalEntries.amount.isBiggerOrEqualValue(minAmount))`.
- Idem para `maxAmount` con `isSmallerOrEqualValue`.
- Doc-comment del método actualizado para reflejar los nuevos params.

### Capa de presentación

**Panel `EntriesFiltersScreen`** (`lib/screens/entries_filters_screen.dart`):

- 2 `TextEditingController` (`_minAmountCtrl`, `_maxAmountCtrl`)
  inicializados con los valores de `widget.initial.minAmount?.toString()`
  o cadena vacía. Disposados en `dispose()`.
- Sección "Monto" agregada entre "Cuenta" y "Categorías" con un `Row`
  de 2 `TextFormField` (Mínimo izq, Máximo der). Prefijo `$ `, keyboard
  `numberWithOptions(decimal: true)`, inputFormatter
  `FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))`.
- `_apply` parsea ambos controllers con `double.tryParse`, valida
  `min > max` con `showWarningSnackbar` + `return` (no pop), y emite
  `_editing.copyWith(...)` con sentinels apropiados.
- `_clearAll` también limpia los controllers para sincronizar UI con
  state.
- Import de `package:flutter/services.dart` agregado para
  `FilteringTextInputFormatter`.

**Bar `EntriesActiveFiltersBar`** (`lib/widgets/entries_active_filters_bar.dart`):

- Import de `package:fincore/widgets/amount_formatter.dart` agregado.
- Nuevo `_ActiveChip` condicional con `label: _amountLabel(min, max)`
  cuando al menos un extremo está presente.
- Helper `_amountLabel` con 3 casos: ambos (`"$X – $Y"`), solo min
  (`"≥ $X"`), solo max (`"≤ $X"`).

**Lista `EntriesPaginatedList`** (`lib/widgets/entries_paginated_list.dart`):

- `_filtersChanged` agrega 2 comparaciones: `a.minAmount != b.minAmount`
  y `a.maxAmount != b.maxAmount`.
- `_buildStream` pasa `widget.filters.minAmount` y
  `widget.filters.maxAmount` al `watchPage` del DAO.

### Tests

**`test/data/entries_dao_filters_test.dart`** (+6 tests):

- Grupo nuevo `cashflowByMonth — amount (RN-A01..A08)` con 6 tests
  UT-01..UT-06. Cobertura: solo min, solo max, rango, igualdad,
  combinado con kind+fecha, regresión sin filtro.

**`test/data/entries_filters_test.dart`** (+7 tests):

- Grupo nuevo `EntriesFilters — amount (RF-001..RF-007)` con 7 tests
  UT-07..UT-13. Cobertura: copyWith con sentinels (UT-07),
  clearDimension (UT-08), activeCount (UT-09), parse válido (UT-10),
  parse no-numérico (UT-11), parse negativos (UT-12), toDeepLink (UT-13).

**`test/screens/entries_filters_screen_test.dart`** (+3 widget tests +
1 ajuste):

- Grupo nuevo `EntriesFiltersScreen — sección Monto` con 3 widget tests
  WT-01..WT-03. Cobertura: render de la sección, ingresar min + aplicar,
  validación min > max con snackbar.
- Ajuste defensivo en test "Default thisMonth está seleccionado al
  abrir": `scrollUntilVisible` antes del expect de "Sin categoría"
  porque la sección "Monto" lo empuja fuera del viewport inicial.

## Desviaciones respecto al plan

Sin desviaciones materiales. Tres ajustes menores durante la ejecución:

1. **Helper `_tryParseNonNegativeDouble`**: el plan no lo nombraba
   explícitamente. Lo agregué como detalle de implementación interno
   para mantener `parse` legible. Aceptable porque la spec sí pedía
   la regla de "negativos null" (RN-A07).
2. **Tests UT-01..UT-06 inicialmente fallaron** (6 fails) porque cada
   test llamaba `await seedEntries()` duplicando el seed que ya hace
   el `setUp`. Corrección: removidas las llamadas duplicadas. Tests
   pasaron en el segundo intento.
3. **Ajuste en test "Default thisMonth"** (no estaba en el plan): tras
   agregar la sección "Monto" al panel, el chip "Sin categoría" quedó
   fuera del viewport inicial del `ListView` lazy. Solución defensiva
   con `scrollUntilVisible` antes del expect. No es regresión productiva
   — solo refleja la realidad de un panel más largo.

## Pruebas realizadas y recomendadas

**Realizadas** (automatizado):

- `flutter analyze` → 0 errores, 4 hints `info` cosméticos
  pre-existentes (no del sprint).
- `flutter test` completo → 251/251 verdes en 17s (235 previos + 16
  nuevos).
- Tests del DAO `--name 'amount'` → 6/6 verdes en 1s.
- Tests del modelo `--name 'amount'` → 7/7 verdes en 1s.
- Tests del panel `--name 'sección Monto'` → 3/3 verdes en 6s.
- `flutter build apk --release --split-per-abi` → 3 APKs en 48s.
- `bash scripts/verify-apk.sh` → versionCode 2059 / versionName 0.7.1
  consistentes.

**Recomendadas** (smoke manual, no del sprint):

- SM-01..SM-07 documentados en `test-plan.md` y `implementation-review.md`.

## Riesgos residuales y posibles regresiones

- **R-T05 del plan** (mitigado): tests existentes del `EntriesFilters`
  siguen verdes — los campos opcionales con default null preservan
  callers.
- **R-T02 del plan** (aceptado): el `inputFormatter` `[0-9.]` permite
  múltiples puntos. Mitigación implícita en `_apply` con `double.tryParse`
  que retorna null para input inválido. Si Diego quiere feedback
  explícito en tiempo real, agregar `validator` al `TextFormField`.
- **Default vacío vs filtro pre-cargado**: si Diego abre el panel con
  `initial.minAmount = 100`, el controller muestra `"100.0"` (con
  decimal). Aceptable visualmente.
- Sin regresión esperada en cashflow ni en spending tab.
- Reactividad: el `customSelect.watch` del DAO re-emite cuando cambian
  `journal_entries`. Validado por construcción (mismo patrón usado en
  el resto del DAO).

## Aplicación de engineering-code-standards

La skill `engineering-code-standards` no se invocó explícitamente.
Aplicación implícita de patrones del repo: inmutables vía `final`,
constructor con campos opcionales para preservar callers, sentinels
explícitos para limpiar nullable, doc-comments con folios (RN-A02,
RF-003, etc.), validación en boundary (UI capa con snackbar, no en el
modelo defensivo), tests por archivo con grupos por categoría,
nombres en español para grupos de tests.

## Aplicación de branch-quality-review

`branch-quality-review` disponible pero NO invocado (no pedido por el
usuario explícitamente). Si Diego quiere revisión exhaustiva:

```bash
# Invocar la skill manualmente.
branch-quality-review flutter-movements-amount-filter-v1
```

Genera reporte en `engineering/quality-review/<slug>/`.
