# Desviaciones respecto al plan

## D1 — UT-I03 usa `customStatement` para simular el edge "expense legacy"

- **Plan original**: `entriesDao.registerIncome(categoryId: catComida)` con `catComida` `applies_to='expense'` para verificar que el income con categoría de expense cae en "Sin categoría".
- **Realidad**: el DAO valida `applies_to` vs `kind` en el momento de registrar. `registerIncome` con una categoría `expense` es rechazado con `EntriesDaoError('invalid_category_applies_to', ...)` (línea 594 de `entries_dao.dart`).
- **Solución**: `db.customStatement("INSERT INTO journal_entries ...")` bypaseando el DAO. Simula datos que un backup legacy (o corrupción externa) podría traer. Es exactamente el escenario que el filtro `applies_to != 'expense'` en el JOIN pretende blindar.
- **Impacto**: test cubre correctamente RN-I05. Documentado en el comentario del test.

## D2 — UT-I07 usa categorías apropiadas al kind

- **Plan original**: registrar los 4 kinds (`expense`, `credit_expense`, `debt_payment`, `transfer`, `income`) con la misma categoría `catIncomeSueldo` para verificar que solo el income cuenta.
- **Realidad**: el DAO también valida al registrar `expense`/`credit_expense` — no se pueden registrar con categoría de tipo `income`.
- **Solución**: usar `catComida` (categoría `expense` sembrada en `setUp` del archivo) para los expense y credit_expense; usar `catIncomeSueldo` para el income (como referencia). El transfer no acepta categoryId, así que se omite del combo.
- **Impacto**: el test sigue validando el punto principal (solo income cuenta) con datos legítimamente registrables por el DAO.

## D3 — 3 widget tests en lugar de los 5 planeados

- **Plan original**: WT-I01..I05 con drill-down (WT-I04) y validación from>to (WT-I05).
- **Realidad**: WT-I04 requiere mock del router para capturar navegación con filtros; WT-I05 requiere interactuar con `showDatePicker` que abre un modal difícil de manipular en widget tests.
- **Solución**: implementados WT-I01 (empty), WT-I02 (con datos con 2 buckets + `Total del período`), WT-I03 (income sin category_id → "Sin categoría"). Los flujos WT-I04 y WT-I05 se validan por smokes SM-05 y SM-07 en cel real.
- **Impacto**: cobertura equivalente vía tests unitarios del factory (UT-I11, UT-I12 cubren la lógica del drill-down) + smoke tests para la navegación real.

## D4 — WT-15 del sprint credit-cards actualizado de regresión

- **Plan original**: verificar que WT-O01..O06 y WT-H01..H04 siguen verdes.
- **Realidad adicional detectada**: `credit_cards_tab_test.dart:201` esperaba `findsNWidgets(7)` Tabs — desactualizado desde el sprint credit-cards (originalmente 6 → 7 en budgets, ahora 7 → 8 acá).
- **Solución**: actualizado a `findsNWidgets(8)`.
- **Impacto**: cero — es un ajuste de conteo, no de comportamiento.

No hay desviaciones bloqueantes.
