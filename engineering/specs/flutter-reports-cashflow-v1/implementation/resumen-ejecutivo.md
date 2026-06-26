# Resumen ejecutivo — flutter-reports-cashflow-v1

## Qué se implementó

Nuevo tab "Cashflow mensual" en `/reports` que muestra ingresos vs
gastos por mes calendario, junto al existente "Gasto por categoría".
Bar chart pareado nativo (verde ingresos / rojo gastos) por columna,
3 métricas del período (ingresos, gastos, neto) y breakdown numérico
debajo del chart.

Diego ahora puede abrir Reportes y ver:

- En qué meses ingresó más / menos.
- En qué meses gastó más / menos.
- Si el saldo del período es positivo (verde) o negativo (rojo).

## Impacto esperado

- **Producto**: cubre el hueco analítico de tendencias mes a mes. El
  reporte deja de responder solo "dónde gasté" y empieza a responder
  "cómo cambia mes a mes".
- **Performance**: cero impacto. La query es `GROUP BY %Y-%m` lineal
  sobre `journal_entries`. Reactividad coherente con drift.
- **APK size**: cero impacto. Sin deps externas.
- **Schema**: cero migración. Solo lectura.

## Riesgos o pendientes relevantes

- **Default `thisMonth` muestra 1 sola columna**: si en uso real Diego
  prefiere ver más meses al abrir, agregar preset `last6Months` en
  una v2.
- **Smoke manual pendiente** (no del sprint): Diego debe instalar el
  APK `0.7.0+58` y validar en cel real los flujos SM-01 a SM-06
  documentados en `implementation-review.md`.

## Estado de pruebas

- `flutter test` → **235/235 verdes** (219 previos + 16 nuevos).
- `flutter analyze` → 0 errores.
- APK `0.7.0+58` construido y validado por `verify-apk.sh`.
- Sin regresión en `reports_screen_test.dart` (5/5 verdes post bump
  a 2 tabs).
- Sin regresión en el resto de la suite.
