# Tareas — flutter-dashboard-bundle-v1

## Backend

- [ ] T001 Backend: leer código actual detallado —
  `dashboard_screen.dart` (`_DashboardScreenState`,
  `_TotalCard`, `_AccountTile`); `reports.dart` (patrones de
  `customSelect + watch + map`); `entries_dao.dart` (signature
  `watchPage(limit, accountIds)`); `financial_state.dart`
  (`watchAccountBalance`, semántica cash vs credit invertida).
  RF: —
  Depende de: ninguna
  Paralelizable: no
  Criterio de terminado: identificados puntos de inserción de los
  3 features + patrón de query reactiva del servicio.

- [ ] T002 Backend: en `reports.dart`, agregar método
  `ReportsService.watchTodaySummary({DateTime? now})` que retorna
  `Stream<TodaySummary>`. SQL con `SUM(CASE WHEN ...)` sobre
  `journal_entries`, filtro `strftime('%Y-%m-%d', occurred_at,
  'localtime') = ?` con `now` formateado como `YYYY-MM-DD`
  (default `DateTime.now()`). Filtro `kind IN ('income',
  'expense', 'credit_expense')` y `deleted_at IS NULL`.
  `readsFrom: {journalEntries}`. Retorna 1 fila con `income` +
  `expense`; helper Dart construye `TodaySummary` con
  `net = income - expense`.
  RF: RF-001, RF-002
  Depende de: T001
  Paralelizable: no
  Criterio de terminado: método compila; SQL ejecutable.

- [ ] T003 Backend: agregar `ReportsService.watchDailyBalance30d({
  required String kind, DateTime? now})` donde `kind ∈ {bo, de, cr}`.
  Estrategia:
  1. Rango: `today - 29d` (00:00 local) hasta `today` (23:59 local).
  2. Query única que trae:
     - Balance inicial: `Σ` de todos los entries pre-rango por cuenta.
     - Cambios: entries dentro del rango agrupados por `(day,
       account_id)` con `SUM(CASE WHEN dest = id THEN amount ELSE 0
       END) - SUM(CASE WHEN origin = id THEN amount ELSE 0 END)`.
     - Metadata: `accounts` con `type` y `credit_limit`.
  3. En Dart: acumular por día para cada cuenta, después colapsar
     al agregado según `kind`:
     - `bo` = suma de balances de cash + debit.
     - `de` = suma de balances (invertidos) de credit.
     - `cr` = suma de `credit_limit - deuda` de credit.
  4. Backfillear 30 puntos siempre.
  5. Excluir cuentas archivadas.
  `readsFrom: {journalEntries, accounts}`.
  RF: RF-003
  Depende de: T001
  Paralelizable: si (con T002)
  Criterio de terminado: método compila; retorna exactamente 30
  puntos para cualquier `kind`.

- [ ] T004 Backend: definir modelos `TodaySummary` y `DailyBalance`
  al final de `reports.dart` con los otros modelos.
  - `TodaySummary { DateTime day, double totalIncome,
    double totalExpense, double net }` const-inmutable.
  - `DailyBalance { DateTime day, double balance }` const-inmutable.
  RF: RF-004
  Depende de: T001
  Paralelizable: si (con T002/T003)
  Criterio de terminado: modelos compilables; sin lint.

## Frontend

- [ ] T005 Frontend: en `dashboard_screen.dart`, crear
  `class _TodayCard extends StatelessWidget` que recibe
  `Stream<TodaySummary> stream`. Renderea `BaseCard` con:
  - Row: `Text(fecha, DateFormat('EEE d MMM', 'es_MX'))` con
    capitalización manual del primer char (patrón heredado).
  - Row de 3 columnas: Ingresos (positive), Gastos (negative), Neto
    (color según signo, con signo `+`/`-` explícito).
  - Sin movimientos → `$0` en `textMuted`.
  Agregar `_todayStream` en `_DashboardScreenState.didChangeDependencies`.
  Insertar el `_TodayCard` como primer child del `ListView` (arriba
  de los 3 `_TotalCard`s).
  RF: RF-005
  Depende de: T002, T004
  Paralelizable: si (con T006/T008)
  Criterio de terminado: `_TodayCard` renderea con streams reales.

- [ ] T006 Frontend: en `dashboard_screen.dart`, crear `class
  _Sparkline extends StatelessWidget` que recibe
  `Stream<List<DailyBalance>> stream` + `Color color`. Usa
  `StreamBuilder`. Cuando hay datos, envuelve en
  `SizedBox(height: 28, child: CustomPaint(painter:
  _SparklinePainter(...))`. Cuando no hay datos → `SizedBox(height:
  28)` vacío (mismo alto para no crashear el layout).
  Nueva clase `_SparklinePainter extends CustomPainter`:
  - Calcula `minY = data.min(balance)`, `maxY = data.max(balance)`.
  - Si `minY == maxY`: pinta línea horizontal en el centro.
  - Sino: mapea cada punto a coordenadas (x = index * width/29,
    y = height - ((balance-minY) / (maxY-minY)) * height).
  - `Path` polyline con `moveTo` + `lineTo` para cada punto.
  - `Paint()..color = color..strokeWidth = 1.5..style = stroke..
    strokeCap = round..isAntiAlias = true`.
  - `shouldRepaint`: comparar `data` referencia.
  RF: RF-006
  Depende de: T003, T004
  Paralelizable: si (con T005/T008)
  Criterio de terminado: `_Sparkline` renderea con datos reales.

- [ ] T007 Frontend: extender `_TotalCard` para recibir opcional
  `Widget? footer` y renderearlo debajo del balance y arriba del
  hint. En el dashboard, pasar `footer: _Sparkline(stream: _bo/de/
  crSparkStream, color: <color del card>)` a los 3 `_TotalCard`s.
  Cachear `_boSparkStream, _deSparkStream, _crSparkStream` en
  `_DashboardScreenState.didChangeDependencies` invocando
  `deps.reportsService.watchDailyBalance30d(kind: 'bo'/'de'/'cr')`.
  RF: RF-006
  Depende de: T006
  Paralelizable: no
  Criterio de terminado: los 3 cards muestran sparkline; layout no
  rompe en cel angosto.

- [ ] T008 Frontend: en `dashboard_screen.dart`, crear
  `class _AccountFilterChips extends StatelessWidget` que recibe
  `Stream<List<db.Account>> stream`, `String? selectedId`,
  `ValueChanged<String?> onChanged`. Renderea
  `SingleChildScrollView(scrollDirection: Axis.horizontal)` con Row
  de `ChoiceChip`s: "Todas" (selected si `selectedId == null`) +
  una por cuenta activa (selected si `id == selectedId`).
  En `_DashboardScreenState`:
  - Agregar `String? _selectedAccountId`.
  - `_onFilterChanged(String? id)` que hace `setState(() {
    _selectedAccountId = id; _recentEntriesStream = deps.entriesDao
    .watchPage(limit: 10, accountIds: id != null ? [id] : null); })`.
  - Listener sobre `_accountsStream` (via `StreamBuilder` externo
    o `.listen()` en `didChangeDependencies`): si `_selectedAccountId
    != null` y no aparece en la lista activa → resetear a null.
  Insertar `_AccountFilterChips` entre `SectionTitle('Últimos
  movimientos')` y el `StreamBuilder` de la lista.
  RF: RF-007, RF-008, RF-009, RF-010
  Depende de: T001
  Paralelizable: si (con T005-T007)
  Criterio de terminado: chip cambia el filtro; archivar cuenta
  seleccionada resetea a "Todas".

## Documentación

- [ ] T009 Documentación: en `help_screen.dart`, agregar bullet
  nuevo bajo el tema del dashboard (o crear si no existe) con:
  "El dashboard muestra un resumen del día actual arriba, mini-
  gráficos de tendencia (últimos 30 días) debajo de los saldos
  BO/DE/CR, y chips para filtrar rápidamente la lista de últimos
  movimientos por cuenta."
  RF: RF-011
  Depende de: ninguna
  Paralelizable: si
  Criterio de terminado: bullet visible en el FAQ.

## Pruebas

- [ ] T010 Pruebas: agregar grupo `watchTodaySummary (sprint
  dashboard-bundle)` en `mobile/test/data/reports_test.dart` con
  UT-TD01..07. UT-TD07 usa `emitsThrough` para reactividad.
  RF: RF-012
  Depende de: T002, T004
  Paralelizable: si (con T011/T012)
  Criterio de terminado: 7 tests verdes.

- [ ] T011 Pruebas: agregar grupo `watchDailyBalance30d (sprint
  dashboard-bundle)` en `mobile/test/data/reports_test.dart` con
  UT-SP01..07. UT-SP07 usa `emitsThrough`.
  RF: RF-012
  Depende de: T003, T004
  Paralelizable: si (con T010/T012)
  Criterio de terminado: 7 tests verdes.

- [ ] T012 Pruebas: crear (o extender) `mobile/test/screens/
  dashboard_screen_test.dart` con WT-DB01..05 usando el harness
  `pumpFincoreApp`. Cubrir vista Hoy con datos, empty state, chip
  filtra listado, archivar cuenta seleccionada resetea filtro,
  chip "Todas" restaura consolidado.
  RF: RF-012
  Depende de: T005, T007, T008
  Paralelizable: si (con T010/T011)
  Criterio de terminado: 5 widget tests verdes.

- [ ] T013 Pruebas: correr `flutter analyze` (0 errores nuevos) +
  `flutter test` completo. Suite ≥ 584 verdes (572 baseline + 12
  nuevos).
  RF: RF-012
  Depende de: T010, T011, T012
  Paralelizable: no
  Criterio de terminado: suite verde + analyze limpio.

## Validación de calidad

- [ ] T014 Validación: bump de versión en `mobile/pubspec.yaml`
  (`0.19.0+93`) + `mobile/android/app/build.gradle.kts`
  (`versionCode = 93`, `versionName = "0.19.0"`). Correr `flutter
  build apk --release --split-per-abi` + `scripts/verify-apk.sh`.
  RF: RF-013
  Depende de: T013
  Paralelizable: no
  Criterio de terminado: APK compilado + `verify-apk.sh` OK con
  versionCode 2093.

- [ ] T015 Validación: smokes SM-01..07 con Diego en cel real.
  Si algún smoke falla, generar patch (`0.19.1+94`).
  RF: —
  Depende de: T014
  Paralelizable: no
  Criterio de terminado: Diego confirma los 7 smokes o reporta
  regresión con patch aplicado.

- [ ] T016 Validación: ejecutar `branch-quality-review` con slug
  `flutter-dashboard-bundle-v1`. Consolidar hallazgos en
  `engineering/quality-review/flutter-dashboard-bundle-v1/`.
  Aplicar los bloqueantes antes del commit.
  RF: —
  Depende de: T015
  Paralelizable: no
  Criterio de terminado: reporte generado; hallazgos bloqueantes
  resueltos.

- [ ] T017 Validación: commit final. NO pushear inmediatamente
  (Diego lo hará en batch cuando confirme smokes).
  RF: —
  Depende de: T016
  Paralelizable: no
  Criterio de terminado: `git status` limpio; main + N commits
  ahead de origin.
