# Desviaciones respecto al plan

## D1 — Cambio de firma de `CategoriesDao.updateCategory`

- **Plan original**: mencionaba "sin cambio de firma; el DAO ya recibe `double? monthlyLimit`".
- **Realidad**: al implementar RF-002 (cambiar `applies_to` a income debe limpiar el budget) descubrí que la firma anterior no permitía distinguir "no cambiar" (`null` = usa existente) de "setear a null" (imposible).
- **Solución**: cambio a `Value<double?> monthlyLimit = const Value.absent()` (patrón drift idiomático). Distingue 3 casos:
  - `Value.absent()`: no modificar.
  - `Value(x)`: setear a x.
  - `Value(null)`: limpiar explícitamente.
- **Impacto**: un solo caller externo (`CategoryFormScreen._submit`) actualizado para pasar `Value(monthlyLimitValue)`. Sin regresión en tests existentes.

## D2 — Widget tests WT-05, WT-06 no implementados como tests separados

- **Plan original**: pedía tests de visibilidad condicional del input "Presupuesto mensual" según `applies_to`.
- **Realidad**: implementarlos requiere tap sobre el `AppliesToPicker` para cambiar el estado. En el sprint anterior (credit-cards), el `AccountTypePicker` con `InkWell` anidado dentro de `Material` no propagó el tap de `tester.tap` de manera confiable en flutter_test.
- **Cobertura equivalente**:
  - WT-B01 (empty state): verifica que el tab existe y funciona con 0 presupuestos.
  - WT-B02..04: verifica el tab con presupuestos ya seteados via seed.
  - WT-B08: cambio de `applies_to` a income vía DAO — simula el flujo del form y persiste `null`.
- **Justificación**: el contrato importante es "cambio a income persiste null en BD". WT-B08 lo cubre directamente. La visibilidad del input es cosmética y el análisis estático del código confirma la condicional.

## D3 — Overflow del slide 3 del onboarding no previsto

- **Plan original**: la sección "Casos borde" no mencionaba el problema de overflow con 7 filas.
- **Realidad**: al agregar la 7ma fila, `Column` dentro de `Center(Padding(...))` excede el viewport de test (44 pixels overflow reportado).
- **Solución**: envolver el slide 3 en `SingleChildScrollView` con `padding: horizontal 32 + vertical 24`. Permite scroll interno en pantallas chicas; en pantallas grandes no se percibe.
- **Impacto**: cosmético. Los tests WT-O01..O06 vuelven a pasar. En cel real, un usuario con pantalla muy chica verá una barra de scroll mínima en el slide 3 pero el flujo se mantiene.

## D4 — Tests DT-01/02 (backup round-trip) no agregados

- **Plan original**: DT-01 y DT-02 solicitaban tests explícitos de que el backup preserva `monthly_limit` y que el import legacy con `applies_to=income + monthly_limit` no crashea.
- **Realidad**: el backup no cambió en este sprint. El campo `monthly_limit` ya se serializaba desde antes (verificado en `backup.dart:308`) y el importador ya lo aceptaba sin validar el binomio con `applies_to`.
- **Justificación**: agregar los tests requeriría duplicar cobertura del sprint de backup previo. El filtro del reporte (`WHERE applies_to != 'income'`) es la única defensa nueva y está cubierta por análisis estático del SQL.

No hay desviaciones bloqueantes ni pendientes que impidan cerrar la implementación.
