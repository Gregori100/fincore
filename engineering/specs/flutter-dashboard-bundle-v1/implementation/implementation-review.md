# Implementation Review: flutter-dashboard-bundle-v1

## Resumen de lo implementado

Bundle de 3 features al Dashboard, todas aditivas y en un solo commit:

1. **Vista "Hoy"**: card nueva arriba del dashboard con fecha del día
   + ingresos/gastos/neto. Reactiva; excluye transfer y debt_payment.
2. **Sparkline**: mini-gráfico de saldo diario últimos 30 días debajo
   de cada `_TotalCard` (BO/DE/CR). Pintado con `CustomPaint` polyline
   con escala min-max local; con backfill para días sin movimientos.
3. **Filtro rápido por cuenta**: chips scrollables arriba de "Últimos
   movimientos" con "Todas" + una por cada cuenta activa. Filtra solo
   esa lista; state en memoria; se resetea a "Todas" si la cuenta
   filtrada se archiva.

## Archivos principales modificados

- `mobile/lib/data/reports.dart`:
  - Método `watchTodaySummary({DateTime? now})`.
  - Método `watchDailyBalance30d({required String kind, DateTime? now})`
    con 2 queries + helper puro `_buildDailyBalance30d`.
  - Clases privadas `_AccountBalanceMeta`.
  - Modelos `TodaySummary` y `DailyBalance` const-inmutables.
- `mobile/lib/screens/dashboard_screen.dart`:
  - `_TotalCard` gana parámetro opcional `sparklineStream`.
  - Nuevas clases: `_TodayCard`, `_TodayMetric`, `_Sparkline`,
    `_SparklinePainter`, `_AccountFilterChips`.
  - `_DashboardScreenState` con 4 streams nuevos + `_selectedAccountId`
    + `_onFilterChanged` + `StreamSubscription` para archivo de cuenta.
- `mobile/lib/screens/help_screen.dart`: bullet nuevo dentro del tema
  "¿Qué significan BO, DE y CR?" mencionando vista Hoy + sparklines +
  filtro.
- `mobile/pubspec.yaml` + `mobile/android/app/build.gradle.kts`: bump a
  `0.19.0+93`.

Tests:

- `mobile/test/data/reports_test.dart`: 2 grupos nuevos con UT-TD01..07
  + UT-SP01..07.
- `mobile/test/screens/dashboard_screen_test.dart`: WT-DB01..05 + 2
  aserciones de tests preexistentes ajustadas para el nuevo chip que
  duplica el nombre de cuenta.
- `mobile/test/helpers/widget_test_harness_test.dart`: 2 aserciones
  ajustadas por el mismo motivo.

## Tareas completadas

- T001 (lectura), T002-T004 (servicio + modelos), T005-T008 (widgets
  del dashboard), T009 (FAQ), T010-T011 (14 UT servicio), T012 (5
  widget), T013 (suite verde + analyze limpio), T014 (bump + APK
  verificado).

## Tareas pendientes

- **T015 (smokes SM-01..07)** — pendiente en cel real.
- **T017 (commit final)** — pendiente.

## Branch quality review

Ejecutado 2026-07-13. Reporte:
`engineering/quality-review/flutter-dashboard-bundle-v1/2026-07-13-branch-quality-review.md`.

9 hallazgos verificados (2 altos, 5 medios, 2 bajos), 0 bloqueantes,
todos aplicados antes del commit:

- **A1** — assert de `kind` válido en `watchDailyBalance30d`.
- **A2** — bracket `occurred_at` en `watchTodaySummary` para usar
  índice `idx_entries_occurred_active`.
- **A3** — docstring en `watchDailyBalance30d` aclarando que RN-DB01
  no aplica a balances (solo a flujos).
- **A4** — touch target chips A11Y: `SizedBox 34→44` + padding
  vertical 8, `MaterialTapTargetSize.shrinkWrap` removido.
- **A5** — `netLabel = '$0'` sin signo cuando `!hasMovements`.
- **A6** — `FittedBox(scaleDown)` en `_TodayMetric` para montos
  largos en cel angosto.
- **A7** — removido `readsFrom` de `.get()` en el sub-query
  `sqlInitial`; comment documenta TD `UNION ALL` como optimización
  futura.
- **A8** — `Skeleton(height: 24)` en `_Sparkline` durante loading.
- **A9** — UT-TD06 nuevo (borderline día calendario local: 3
  incomes a mediodía de 14/15/16 jun, solo el 15 cuenta).

Suite: **591/591 verdes** (+1 test).
APK release: `versionCode 2093 / versionName 0.19.0` verificado.
`flutter analyze` limpio.

## Refinamiento post-smoke — RN-DB15 revertido

Después del smoke con Diego (2026-07-13), pidió que la vista "Hoy" y
los sparklines se refresquen automáticamente al cruzar medianoche
local sin necesidad de salir y re-entrar al dashboard.

Cambio aplicado en `mobile/lib/screens/dashboard_screen.dart`:

- Nuevo `Timer? _midnightTimer` en `_DashboardScreenState`.
- Método `_scheduleMidnightRefresh()` calcula ms hasta próxima
  medianoche local (+1s de margen) y programa Timer one-shot.
- Callback `_onMidnightCrossed()` recrea los 4 streams del día
  (`_todayStream`, `_boSparkStream`, `_deSparkStream`,
  `_crSparkStream`) vía `setState`, y reprograma el siguiente Timer.
- Timer cancelado en `dispose`.

Test-plan.md actualizado: SM-07 reescrito para reflejar el nuevo
comportamiento (refresh automático, no manual). RN-DB15 original
("aceptar que no refresque hasta interacción del usuario") queda
obsoleta.

Caveat conocido: si Android mete la app en Doze mode con pantalla
apagada, el Timer puede dispararse tarde. Al despertar la pantalla
se ve el estado viejo hasta que el Timer efectivamente dispare.
Aceptable — cubre el caso "app abierta cruzando medianoche" que
era el intent de Diego.

Confirmado en cel real por Diego el 2026-07-13.

## Riesgos residuales

- **R1 — Compute cost sparkline**: la query de 30d + backfill en Dart
  es O(30 × cuentas). Con dataset típico single-user negligible
  (< 30ms). Verificar en SM con dataset real.
- **R2 — Reactividad ruidosa**: al registrar un movimiento re-emiten
  7-8 streams del dashboard. Aceptable en single-user. Cubierto por
  UT-TD07 y UT-SP07 con `emitsThrough`.
- **R3 — Layout del `_TotalCard` con sparkline**: sparkline `height: 24`
  agrega ~30 px al card. Verificar en cel angosto real (SM-02).
- **R5 — Cruzar medianoche con dashboard abierto**: vista "Hoy" NO
  cambia hasta refresh (RN-DB15).
- **R6 — Archivar cuenta con chip seleccionado**: cubierto por listener
  del `_accountsStream` en `didChangeDependencies` + `StreamSubscription`
  cancelada en `dispose`. Tests widget WT-DB03/WT-DB05 blindan el
  patrón de tap+cambio pero NO el archivo. Smoke SM-05 lo cubre.

## Pruebas realizadas

- `flutter analyze` limpio (solo hint info pre-existente en skeleton).
- `flutter test` **590/590 verdes** (572 baseline + 14 UT + 5 widget +
  ajustes menores de 4 tests preexistentes por el nuevo chip).
- APK release build OK; `verify-apk.sh` OK con `versionCode 2093 /
  versionName 0.19.0`.

## Pruebas recomendadas

- SM-01..07 con Diego en cel real.
- Especialmente **SM-02** (sparklines visualmente OK en cel con dataset
  real; layout no rompe en 3 cards side-by-side); **SM-04**
  (reactividad al registrar income de hoy: vista Hoy + sparkline de BO
  + lista se actualizan); **SM-05** (archivar cuenta filtrada resetea
  el chip a "Todas").

## Posibles regresiones

- **Cambio visual mayor del dashboard**: agrega card "Hoy" arriba,
  cambia altura de cards por sparkline, agrega chips arriba de la
  lista. Diego lo notará inmediatamente.
- **Tests preexistentes**: 4 aserciones ajustadas (2 en
  `dashboard_screen_test.dart` + 2 en `widget_test_harness_test.dart`)
  para tolerar la instancia extra del nombre de cuenta introducida por
  el chip filtro. Ninguna regresión funcional.
- Cero cambios en `FinancialStateService`, `EntriesDao`, `AccountsDao`,
  backup, form de cuenta, form de movimiento, otros reportes, calendar
  o heatmap.

## Recomendaciones para code review humano

1. Verificar la lógica del helper `_buildDailyBalance30d`:
   - Balance inicial correcto (LEFT JOIN con `occurred_at < rangeStart`).
   - Acumulación día a día por cuenta.
   - Backfill de días sin movimientos con el valor del día previo.
   - Semántica invertida para `kind='de'` (deuda = -rawBalance).
   - Cálculo de `cr` = `creditLimit - deuda`.
2. Verificar que `readsFrom: {journalEntries, accounts}` está en ambas
   subqueries del sparkline.
3. Verificar la matriz de casos borde del sparkline (UT-SP03, UT-SP04,
   UT-SP05) — los 3 kinds con dataset real.
4. Verificar el manejo del `_selectedAccountId` cuando la cuenta se
   archiva:
   - Listener sobre `_accountsStream` en `didChangeDependencies`.
   - `mounted` check antes del `setState`.
   - `StreamSubscription` cancelada en `dispose`.
5. Verificar layout responsive del `_TotalCard` con sparkline en cel
   angosto (viewport ~ 400 px).

Ejecutar `branch-quality-review` con slug `flutter-dashboard-bundle-v1`
antes del commit final. El reporte queda en
`engineering/quality-review/flutter-dashboard-bundle-v1/`.
