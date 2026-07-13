# Resumen ejecutivo — flutter-cashflow-monthly-breakdown-v1

## Qué se implementó

Un tap en la fila de cualquier mes del tab "Cashflow mensual" ahora abre
un sheet con el desglose por categoría del mes: encabezado con
ingresos/gastos/neto, sección de "Ingresos por categoría", sección de
"Gastos por categoría", y un botón "Ver movimientos →" que abre
`/entries` filtrado al rango completo del mes. Las categorías se muestran
con monto, porcentaje del total del mes y chip visual con color + ícono.
Movimientos sin categoría (o con categoría archivada / applies_to
incompatible) se agrupan en "Sin categoría" siguiendo la convención del
proyecto.

## Impacto esperado

- Diego responde "¿por qué gasté más en junio que en mayo?" en 3 taps
  sin fricción — antes tenía que ir a `/entries` con filtros manuales o
  cambiar el rango del reporte "Gasto por categoría" mes a mes.
- Los 3 reportes complementarios (cashflow, spending-by-category,
  income-by-category) ahora cubren las 3 dimensiones (mes-a-mes agregado,
  período categorizado, mes-a-mes categorizado).
- Feature 100% aditiva: cero schema bump, cero migración, cero cambio en
  otros reportes, dashboard, backup ni forms.

## Riesgos o pendientes relevantes

- **Divergencia timezone** con el cashflow base: el sheet usa
  `'localtime'` mientras el tab base agrupa por UTC. En movimientos
  borderline (23:30 UTC del último día del mes) el detalle puede caer en
  un mes distinto al agregado plano. Aceptado; documentado en el plan.
- **Smokes SM-01..07 con Diego** pendientes en cel real, principalmente
  SM-05 (reactividad al renombrar categoría con sheet abierto).
- **`branch-quality-review`** pendiente antes del commit final.

## Estado de pruebas

- **558/558 tests verdes** (539 baseline + 19 nuevos: 13 UT servicio +
  2 UT `forMonth` + 4 widget).
- `flutter analyze` limpio.
- APK release compilado y verificado con `versionCode 2088 /
  versionName 0.17.0`.

Sprint apto para smoke con Diego + branch-quality-review previo al
commit final.
