# Desviaciones respecto al plan

## D1 — Tests UT-DP06/07/08/09 ajustados por el seed compartido

- **Plan original**: cada test siembra su propio dataset mínimo y espera un delta específico.
- **Realidad**: `entries_dao_filters_test.dart` invoca `await seedEntries();` en el `setUp` (línea 121). Cada test arranca con:
  - 1 income sin categoría (5000).
  - 3 expenses con categoría (200, 150, 300).
  - 1 expense sin categoría (100).
  - 1 credit_expense con Comida (800).
  - 1 transfer sin categoría (500).
  - 1 categoría archivada (`catArchivada`).
- **Solución**: los asserts se ajustaron para verificar los deltas reales sobre el seed. Ejemplo: UT-DP06 espera length=1 (el income del seed con cat NULL), no `isEmpty`, y verifica que el categoryId del único entry es null (mi income con `applies_to='both'` NO aparece).
- **Impacto**: sin cambio de intención del test. Al contrario: los tests ahora validan que la lógica funciona correctamente ante datos preexistentes, no solo en escenarios aislados. Documentado en el comentario de cada test.

## D2 — UT-DP08 usa `updateCategory` en lugar de `registerExpense(categoryId=incorrecto)`

- **Plan original**: sembrar un edge (3) inverso con `entriesDao.registerExpense(categoryId: catConAppliesToIncome)`.
- **Realidad**: `EntriesDao.registerExpense` valida `applies_to` de la categoría contra el kind ('income' rechazado con `EntriesDaoError('invalid_category_applies_to')`).
- **Solución**: usar `categoriesDao.updateCategory(id: catTransporte, appliesTo: 'income')` sobre una categoría del seed con expenses ya registrados. `updateCategory` no revalida entries existentes (comportamiento esperado — el usuario puede editar la categoría, y los entries viejos quedan como edge legacy).
- **Impacto**: el test valida exactamente el escenario que motiva el sprint (edición post-facto de `applies_to`), en lugar de un flujo artificial de importación de backup.

## D3 — Bump elegido `0.15.1+78` en vez de `0.15.0+78`

- **Plan original**: bump `+78` sin especificar versionName.
- **Realidad**: el sprint cambia la semántica observable del filtro manual desde `/entries` (RN-P01/P02). Aunque no rompe callers existentes, es un cambio semántico visible al usuario que use el filtro "Sin categoría" combinado con un kind.
- **Solución**: bump patch minor a `0.15.1+78`. Justificación breve en el comentario del `pubspec.yaml` y `versionName = "0.15.1"` en `build.gradle.kts`.
- **Impacto**: cero — es solo una decisión de comunicación visual. Diego puede seguir el flujo `verify-apk.sh` sin cambios.

Sin desviaciones bloqueantes.
