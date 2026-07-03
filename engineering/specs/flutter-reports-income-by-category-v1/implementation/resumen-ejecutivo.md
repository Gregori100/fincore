# Resumen ejecutivo — flutter-reports-income-by-category-v1

## Qué se implementó

- **Octavo tab "Ingreso por categoría"** en `/reports`: agrupa los ingresos del período por categoría, con bar chart horizontal, monto absoluto por bucket, porcentaje del total (1 decimal) y conteo de movimientos.
- **Rango configurable**: chips Este mes / Mes pasado / Este año / Custom. En modo custom, dos DatePickers con validación `from ≤ to`.
- **Drill-down por bucket**: tap en cualquier categoría abre `/entries` con filtros pre-cargados (`kind='income'`, categoría del bucket, rango del reporte).
- **Empty state** contextual cuando no hay ingresos en el rango.
- **Reactivo**: registrar/cancelar/editar un income actualiza el reporte sin refresh manual.
- Documentación en app: onboarding slide 3 pasa a "8 reportes"; FAQ menciona el nuevo tab.

## Impacto esperado

- Usuario que separa sus ingresos por categoría (sueldo, freelance, rentas, ventas) puede responder preguntas simples como "de dónde viene la mayor parte de mi dinero este mes/año" o "cuánto llevo cobrando de freelance en el año".
- Cierra la simetría del análisis por categoría en la app: hoy había gasto por categoría, ahora también ingreso por categoría.
- El drill-down completa el flujo: bucket → tap → movimientos individuales listados en `/entries` para editar o revisar detalles.

## Riesgos o pendientes relevantes

- **Sin refactor compartido** con `spending_by_category_tab.dart`: los 2 archivos son casi idénticos. Cambios futuros en lógica compartida deben aplicarse en ambos. Aceptado para reducir blast radius de este sprint.
- **Confusión con "Cashflow mensual"**: cashflow muestra totales por mes (ingresos vs gastos agregados); este tab desglosa por categoría. Mitigado con FAQ actualizado.
- **Legacy edge case**: categorías con `applies_to='expense'` que por backup histórico tienen incomes asociados caen en el bucket "Sin categoría" (no desaparecen del reporte). Cubierto por UT-I03.
- **Smokes SM-01..09** pendientes de ejecución en el cel de Diego.
- **branch-quality-review** pendiente antes del commit final.

## Estado de pruebas

- `flutter analyze`: 4 hints info pre-existentes tolerados (0 errores nuevos).
- `flutter test`: **452/452 verdes** (437 baseline + 15 nuevos del sprint: 10 servicio + 2 factory + 3 widget).
- Build APK release + verify-apk.sh: OK, versionCode 2077 / versionName 0.15.0.
