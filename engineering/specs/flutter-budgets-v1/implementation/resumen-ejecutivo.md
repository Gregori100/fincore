# Resumen ejecutivo — flutter-budgets-v1

## Qué se implementó

- **Séptimo tab "Presupuestos"** en `/reports`: card por categoría con presupuesto seteado mostrando gastado del mes, % usado (progress ring), disponible, y estado visual (OK, Warning ≥80%, Excedido, Sin gasto).
- **Input UI "Presupuesto mensual"** en el form de edición de categoría (visible solo si `applies_to != income`). Al cambiar el tipo a "Ingreso", el input se limpia y el presupuesto se persiste como `null`.
- **Validaciones nuevas** en el DAO: no se puede setear presupuesto negativo ni combinarlo con categorías de tipo ingreso.
- **Onboarding** y FAQ actualizados: slide 3 pasa a "7 reportes", FAQ menciona el nuevo tab y agrega un tile con instrucciones "¿Cómo defino un presupuesto?".
- **Reactivo**: cambios de presupuesto o registro de gastos actualizan el reporte sin refresh manual.

## Impacto esperado

- Diego (y testers con al menos 1 mes de datos) ganan visibilidad clara de si están gastando por encima de sus metas mensuales por categoría.
- Complementa "Gasto por categoría" con una referencia proactiva ("cuánto me falta") en vez de retrospectiva.
- Cierra el hueco del campo `monthly_limit` huérfano post-pivote: existía en la BD y el backup lo serializaba, pero nunca se había expuesto en la UI.
- Sin schema bump: cero riesgo de migración destructiva.

## Riesgos o pendientes relevantes

- **Cambio de firma de `CategoriesDao.updateCategory`**: `monthlyLimit` pasa de `double?` a `Value<double?>` (drift) para poder distinguir "no cambiar" de "limpiar explícitamente". Solo un caller externo (el form) — actualizado. Riesgo bajo.
- **Overflow del slide 3 del onboarding con 7 filas**: se envolvió en `SingleChildScrollView` para permitir scroll interno en pantallas chicas. Tests WT-O01..06 pasan sin regresión.
- **Backup legacy con `applies_to=income + monthly_limit`**: el reporte filtra estas combinaciones inválidas en la query. Import sigue aceptándolas (compat).
- **Smokes SM-01..09** pendientes de ejecución en el cel de Diego.
- **branch-quality-review** pendiente antes del commit final.

## Estado de pruebas

- `flutter analyze`: 4 hints info pre-existentes tolerados (0 errores nuevos).
- `flutter test`: **431/431 verdes** (412 baseline + 19 nuevos del sprint).
- Build APK release + verify-apk.sh: OK, versionCode 2072 / versionName 0.14.0.
