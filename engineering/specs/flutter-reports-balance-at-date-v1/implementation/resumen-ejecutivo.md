# Resumen ejecutivo — flutter-reports-balance-at-date-v1

## Qué se implementó

Cuarto tab "Saldo a fecha" en `/reports`. Diego ahora puede:

- Abrir Reportes → tap "Saldo a fecha" → ver BO/DE/CR a fecha pasada
  (default: fin del mes anterior).
- Tap en el field → date picker para elegir cualquier fecha entre
  2020-01-01 y hoy.
- Ver el desglose por cuenta debajo de los 3 totales: cada cuenta
  con su saldo individual a esa fecha.

Completa el set analítico de `/reports` (4 tabs):
- **Categorías** (dónde gasté)
- **Cashflow** (cómo cambia mes a mes)
- **Top movimientos** (outliers)
- **Saldo a fecha** (estado histórico para reconciliación)

## Impacto esperado

- **Producto**: cierra el módulo de reportes. Reconciliación contra
  estados de cuenta del banco sin cálculo mental.
- **Performance**: cero impacto. 1 sola query SQL agregada por reporte.
- **APK size**: cero impacto. Sin deps externas.
- **Schema**: cero migración. Solo lectura.

## Riesgos o pendientes relevantes

- Sin riesgos productivos detectados.
- **Smoke manual pendiente**: SM-01..SM-06 con APK `0.9.0+61` en cel
  real.

## Estado de pruebas

- `flutter test` → **277/277 verdes** (266 previos + 11 nuevos).
- `flutter analyze` → 0 errores.
- APK `0.9.0+61` construido + verify-apk OK.
- Sin regresión: tests existentes verdes (los 3 tabs anteriores
  intactos).
