# Resumen ejecutivo — flutter-reports-top-movements-v1

## Qué se implementó

Tercer tab "Top movimientos" en `/reports`. Diego ahora puede:

- Abrir Reportes → tap "Top movimientos" → ver los 20 movimientos más
  grandes del rango ordenados por monto desc.
- Acotar el tipo via chips multi-select en el header (Ingreso, Gasto,
  Gasto a tarjeta, Pago de tarjeta, Transferencia). Default: los 5
  seleccionados.
- Tap en cualquier row para navegar a `/entries/:id/edit` y revisar
  o cambiar.
- Cambiar el rango con los presets de fecha (Este mes, Mes pasado,
  Año, Custom).

Completa la trifecta analítica de `/reports`:
- **Categorías** (dónde gasté)
- **Cashflow** (cómo cambia mes a mes)
- **Top movimientos** (outliers para auditar)

## Impacto esperado

- **Producto**: cierra el set analítico esperado. Auditoría de
  movimientos atípicos sin scrollear `/entries`.
- **Performance**: cero impacto. La query usa `LIMIT 20` y se ejecuta
  reactivamente vía drift.
- **APK size**: cero impacto. Sin deps externas.
- **Schema**: cero migración. Solo lectura.

## Riesgos o pendientes relevantes

- Sin riesgos productivos detectados.
- **TabBar scrollable**: con 3 labels el TabBar pasa a `isScrollable:
  true`. Diego puede deslizarlo si no cabe — ajuste visual menor.
- **Smoke manual pendiente**: SM-01..SM-09 con APK `0.8.0+60` en cel
  real.

## Estado de pruebas

- `flutter test` → **266/266 verdes** (251 previos + 15 nuevos).
- `flutter analyze` → 0 errores.
- APK `0.8.0+60` construido + verify-apk OK.
- Sin regresión: tests existentes del DAO, `reports_screen_test`,
  `cashflow_tab_test`, etc., siguen verdes.
