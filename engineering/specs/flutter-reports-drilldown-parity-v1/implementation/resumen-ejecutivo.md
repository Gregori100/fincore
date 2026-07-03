# Resumen ejecutivo — flutter-reports-drilldown-parity-v1

## Qué se implementó

- **Paridad reporte ↔ drill-down** para el bucket "Sin categoría" en los 2 tabs por categoría de `/reports` (ingresos y gastos). El reporte y el drill-down comparten la misma definición operativa cuando la consulta está restringida a un único tipo de flujo.
- **Blindaje simétrico** del reporte de gastos: el JOIN de `spendingByCategory` ahora filtra `applies_to != 'income'` (análogo al `!= 'expense'` que ya tenía `incomeByCategory`). Un expense con categoría cuyo `applies_to` fue cambiado a `income` post-facto cae en "Sin categoría" en lugar de aparecer con el nombre de la categoría income-only.
- **DAO alineado**: `EntriesDao.watchPage` expande la definición del token `__null__` cuando el filtro `kinds` es puramente `{income}` o puramente `{expense, credit_expense}`. En `kinds` `null`, vacío o mixto, el comportamiento clásico se preserva (no expande).

## Impacto esperado

- Al tapear el bucket "Sin categoría" en cualquiera de los 2 tabs, `/entries` lista exactamente el mismo número de movimientos que reporta el bucket. Cero dinero fantasma.
- Al usar el filtro manual "Sin categoría" en `/entries` con kind income o expense, el listado incluye ahora el edge de categorías editadas post-facto. Comportamiento intuitivo ("todo lo que quedó sin categoría desde este tipo de flujo").
- Cero cambio visual. Feature invisible para el usuario excepto en el escenario específico del edge legacy.
- Fundamentos limpios para futuras iteraciones: el helper `_uncategorizedCondition` centraliza la regla y es fácil de extender si aparecen más kinds con desglose por categoría.

## Riesgos o pendientes relevantes

- **Cero cambios de UI ni schema**, riesgo de regresión visual nulo.
- **Filtro manual desde `/entries`**: la lógica es la misma que la del drill-down programático (mismo DAO). Diego valida con SM-04 en el smoke.
- **Smokes SM-01..04** pendientes de ejecución en el cel de Diego.
- **branch-quality-review** pendiente antes del commit final.

## Estado de pruebas

- `flutter analyze`: 4 hints info pre-existentes tolerados (0 errores nuevos).
- `flutter test`: **461/461 verdes** (452 baseline + 9 nuevos del sprint: 5 en `reports_test` + 4 en `entries_dao_filters_test`).
- Build APK release + `verify-apk.sh`: OK, versionCode 2078 / versionName 0.15.1.
