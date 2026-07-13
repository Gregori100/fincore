# Resumen ejecutivo — flutter-dashboard-bundle-v1

## Qué se implementó

Tres features en el Dashboard, todas aditivas y sin fricción de config:

1. **Vista "Hoy"**: card arriba del dashboard con la fecha del día +
   ingresos, gastos y neto de la jornada. Reactiva; excluye
   transferencias y pagos de tarjeta.
2. **Sparklines**: mini-gráficos horizontales debajo de cada card
   BO/DE/CR mostrando la evolución del saldo agregado en los últimos
   30 días. Patrón fintech clásico.
3. **Filtro rápido por cuenta**: chips scrollables arriba de "Últimos
   movimientos" para filtrar la lista por una cuenta específica.
   State en memoria; default "Todas" al abrir.

## Impacto esperado

- Diego responde "¿me moví hoy?", "¿está creciendo mi bolsillo?" y
  "¿qué pasó en la Bolsa?" en 2-3 segundos sin salir del dashboard.
- Cero cambio de schema, cero migración, cero regresión en otros
  reportes o forms.
- Base para features futuros: rango configurable del sparkline,
  persistencia del filtro, tooltip por día en el sparkline,
  comparación hoy-vs-promedio.

## Riesgos o pendientes relevantes

- **Cambio visual mayor** del dashboard — Diego lo notará
  inmediatamente. Vista Hoy arriba + cards más altos por sparkline +
  chips debajo de "Últimos movimientos".
- **Reactividad ruidosa**: al registrar un movimiento, re-emiten 7-8
  streams simultáneos del dashboard. Aceptable en single-user;
  documentado.
- **Smokes SM-01..07 pendientes** — Diego los hará en cel real.
  Especialmente SM-02 (layout de sparklines en cel real), SM-04
  (reactividad al registrar hoy) y SM-05 (archivar cuenta filtrada).
- **`branch-quality-review`** pendiente antes del commit final.

## Estado de pruebas

- **590/590 tests verdes** (572 baseline + 14 UT servicio + 5 widget +
  4 aserciones de tests preexistentes ajustadas por el nuevo chip).
- `flutter analyze` limpio.
- APK release compilado y verificado con
  `versionCode 2093 / versionName 0.19.0`.

Sprint apto para smoke con Diego + branch-quality-review previo al
commit final.
