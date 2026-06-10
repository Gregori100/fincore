# Resumen ejecutivo — Presets de fecha

## Qué se implementó

Dropdown "Período" con 7 presets útiles ("Hoy", "Esta semana", "Este mes", "Mes pasado", "Últimos 30 días", "Últimos 90 días", "Este año") + opción "Personalizado" para rango libre. Reemplaza los inputs from/to sueltos en 3 vistas:

- `/reports/by-category` (Por categoría).
- `/reports/by-account` (Por cuenta).
- `/entries` y `/accounts/:uuid` (Historial de movimientos).

Cuando hay un preset activo, los inputs from/to se ocultan; cuando se selecciona "Personalizado", reaparecen para edición manual. Default: "Este mes" — mismo comportamiento que las vistas tenían antes.

## Impacto esperado

- Cambio de rango en **1 click** en lugar de tipear fechas a mano.
- Casos típicos (mes pasado, últimos 30 días, este año) ahora son inmediatos.
- Consistencia: `ReportsByAccountView` ahora refetchea automáticamente al cambiar el rango (resuelve inconsistencia UX preexistente).

## Riesgos o pendientes relevantes

- `ReportsCashflowView` (`/reports/cashflow`) queda fuera del sprint por tener un rango fijo de 12 meses sin inputs editables. Si se quiere unificar, sprint chico aparte.
- Cambio sutil en `EntriesTable`: `to` por default ahora es HOY (antes era último día del mes). Consistente con el preset "Este mes" y con los otros reportes.

## Estado de pruebas

- **Frontend**: 110/110 verde (eran 72; +38 nuevos: 27 del helper, 11 del componente).
- **Backend**: 360/360 sin cambios.
- **Smoke con Playwright**: 4/4 OK.
- **Quality review**: 0 bloqueantes, 0 altos, 2 medios atendidos durante el sprint, 1 medio + 3 bajos opcionales.

Listo para merge.
