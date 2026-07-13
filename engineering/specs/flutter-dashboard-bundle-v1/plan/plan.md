# Plan técnico — flutter-dashboard-bundle-v1

## Enfoque tecnico

Sprint aditivo puro sobre `dashboard_screen.dart` + servicio de
reportes. Sin schema bump. 3 features ortogonales que comparten
superficie visual pero son tecnológicamente independientes:

### 1. Vista "Hoy" (servicio + widget)

- **Servicio**: nuevo método
  `ReportsService.watchTodaySummary({DateTime? now})`. SQL:
  ```sql
  SELECT
    SUM(CASE WHEN kind = 'income' THEN amount ELSE 0 END) AS income,
    SUM(CASE WHEN kind IN ('expense', 'credit_expense') THEN amount ELSE 0 END) AS expense
  FROM journal_entries
  WHERE deleted_at IS NULL
    AND kind IN ('income', 'expense', 'credit_expense')
    AND strftime('%Y-%m-%d', occurred_at, 'localtime') = ?
  ```
  Variable con `now` formateado como `YYYY-MM-DD` local. `readsFrom:
  {journalEntries}`.
- **Modelo**: `TodaySummary { day, totalIncome, totalExpense, net }`
  const-inmutable.
- **UI**: `_TodayCard` (nuevo `StatelessWidget`) arriba de los 3
  `_TotalCard`. Layout `BaseCard` con `Text` de fecha + 3 columnas
  (Ingresos, Gastos, Neto). Fecha formateada con
  `DateFormat('EEE d MMM', 'es_MX')` capitalizada.
- **Estado**: cachear `_todayStream` en `_DashboardScreenState`.

### 2. Sparkline (servicio + custom paint)

- **Servicio**: nuevo método `ReportsService.watchDailyBalance30d({
  required String kind, DateTime? now})` — cambio respecto a spec: el
  parámetro no es `accountId + accountType` sino `kind` que indica cuál
  de los 3 agregados computar (`'bo'`, `'de'`, `'cr'`). Simplifica la
  API y coincide con cómo el dashboard ya piensa (BO/DE/CR).
- **Algoritmo**:
  1. Query única que trae todos los `journal_entries` no cancelados
     con `strftime('%Y-%m-%d', occurred_at, 'localtime')` desde
     `hoy - 29d` en adelante O sin filtro de fecha si necesitamos el
     saldo inicial del rango.
  2. En Dart: calcular saldo inicial (todos los entries anteriores al
     rango) y después recorrer los 30 días acumulando cambios diarios.
  3. Backfillear días sin movimientos con el saldo del día previo.
- **Query optimizada** (single-pass, 3 fases):
  ```sql
  -- Fase A: saldo hasta ayer inicial (fin de hoy-30d)
  SELECT
    a.id AS account_id, a.type AS account_type,
    a.credit_limit AS credit_limit,
    COALESCE(SUM(CASE WHEN j.account_destination_id = a.id THEN j.amount ELSE 0 END), 0)
    - COALESCE(SUM(CASE WHEN j.account_origin_id = a.id THEN j.amount ELSE 0 END), 0)
    AS balance_before_range
  FROM accounts a
  LEFT JOIN journal_entries j
    ON (j.account_origin_id = a.id OR j.account_destination_id = a.id)
    AND j.deleted_at IS NULL
    AND j.occurred_at < ?  -- inicio del rango 30d
  WHERE a.deleted_at IS NULL
  GROUP BY a.id, a.type, a.credit_limit
  ```
  Después query dentro del rango agrupada por día (`strftime`).
- **Simplificación**: en vez de 2 queries separadas, hacer **una sola**
  que trae todos los rows relevantes (accounts + entries con
  `occurred_at IN rango + entries acumulados anteriores`) y computar
  todo en Dart. Aceptable para dataset típico single-user (< 5k
  entries totales).
- **Modelo**: `DailyBalance { day, balance }` const-inmutable.
- **UI**: `_Sparkline` (nuevo `StatelessWidget` con `CustomPaint`)
  agregado dentro del `_TotalCard`. Altura 28 px. `_SparklinePainter`
  con `Path` polyline suave (o `quadraticBezierTo` para curva) y
  escala min-max local a los 30 puntos. Color = `color` del
  `_TotalCard`.

### 3. Filtro por cuenta (widget)

- **Widget**: `_AccountFilterChips` (nuevo `StatefulWidget` o
  `StatelessWidget` con callback). `SingleChildScrollView` horizontal
  con `ChoiceChip`s: "Todas" + una por cuenta activa.
- **Estado**: en `_DashboardScreenState` agregar
  `String? _selectedAccountId` y `Stream<List<db.Account>>?
  _accountsStream` (ya existe para "Mis cuentas"). Reusar el mismo
  stream — cambiar el `setState` solo cuando cambia el chip.
- **Filtro reactivo**: al cambiar `_selectedAccountId`, recomputar
  `_recentEntriesStream = deps.entriesDao.watchPage(limit: 10,
  accountIds: _selectedAccountId != null ? [_selectedAccountId!] :
  null)`.
- **Archivo de cuenta con chip seleccionado**: `_accountsStream` está
  filtrado por activas → si la cuenta seleccionada desaparece de la
  lista, un listener en `didChangeDependencies` chequea y hace
  `setState(() => _selectedAccountId = null)`.

### Documentación

- FAQ del Help agrega bullet nuevo mencionando las 3 novedades.

**Bump**: `0.18.2+92` → `0.19.0+93`.

## Requisitos funcionales cubiertos

- **RF-001** (watchTodaySummary): T002.
- **RF-002** (SQL con strftime + localtime): T002.
- **RF-003** (watchDailyBalance30d): T003.
- **RF-004** (modelos TodaySummary + DailyBalance): T004.
- **RF-005** (`_TodayCard` arriba de `_TotalCard`s): T005.
- **RF-006** (sparkline en `_TotalCard`): T006-T007.
- **RF-007** (chips filtro): T008.
- **RF-008** (state `_selectedAccountId` + cache): T008.
- **RF-009** (stream de lista reactivo al filtro): T008.
- **RF-010** (fallback a null si archiva la seleccionada): T008.
- **RF-011** (FAQ): T009.
- **RF-012** (15+ tests): T010-T012.
- **RF-013** (bump 0.19.0+93): T013.

## Archivos o modulos probablemente afectados

Confirmados por inspección:

- `mobile/lib/data/reports.dart` — 2 métodos nuevos + 2 modelos
  nuevos.
- `mobile/lib/screens/dashboard_screen.dart` — nuevo layout con
  `_TodayCard`, sparkline dentro de `_TotalCard`, y chips arriba de
  "Últimos movimientos".
- `mobile/lib/screens/help_screen.dart` — bullet FAQ.
- `mobile/pubspec.yaml` + `mobile/android/app/build.gradle.kts` —
  bump.

Tests:

- `mobile/test/data/reports_test.dart` — grupo nuevo `watchTodaySummary`
  con UT-TD01..05 + grupo `watchDailyBalance30d` con UT-SP01..07.
- `mobile/test/screens/dashboard_screen_test.dart` (por confirmar
  existencia; probable) — WT-DB01..05 con harness.

Sin cambios:

- Schema, migraciones, DAOs (ya soporta filtro `accountIds`).
- `FinancialStateService` (sigue usándose intacto).
- `EntriesDao.watchPage` (ya acepta `accountIds`).
- Backup, forms, otros reportes.

## Entidades y estados afectados

- `TodaySummary` (nuevo, memoria): `day`, `totalIncome`,
  `totalExpense`, `net`. Const-inmutable. Sin persistencia.
- `DailyBalance` (nuevo, memoria): `day: DateTime`,
  `balance: double`. Const-inmutable.
- `_DashboardScreenState`:
  - Nuevos campos: `Stream<TodaySummary>? _todayStream`,
    `Stream<List<DailyBalance>>? _boSparkStream, _deSparkStream,
    _crSparkStream`, `String? _selectedAccountId`.
  - Handler nuevo: `_onFilterChanged(String? newId)` que reconstruye
    `_recentEntriesStream`.
  - Listener que resetea `_selectedAccountId` cuando la cuenta
    seleccionada se archiva.
- Sin cambios en `Account`, `Category`, `JournalEntry`.

## Compatibilidad con datos y procesos existentes

- Cero cambio de schema.
- Backup JSON sin cambios.
- Reportes existentes (`/reports`) sin cambios.
- `FinancialStateService` sin cambios — `_TotalCard` sigue leyendo
  `watchBo/watchDe/watchCr`; el sparkline es un stream paralelo.
- `EntriesDao.watchPage` ya acepta `accountIds` — sin refactor.
- Regresión posible en `dashboard_screen_test.dart` si existía:
  layout cambia (nuevos widgets arriba y en `_TotalCard`). Los
  tests que buscan por texto o tipos concretos deben actualizarse.
- Cero regresión visual en cuentas archivadas / lista de cuentas —
  esos widgets no cambian.

## Cambios de datos si aplica

No aplica.

## Cambios de API si aplica

No aplica (app local-first).

## Cambios de integraciones si aplica

No aplica.

## Cambios de UI si aplica

Dashboard con 3 elementos nuevos:

1. `_TodayCard` como primer child del `ListView`.
2. Sparkline dentro de cada `_TotalCard`, debajo del balance y arriba
   del `hint`.
3. `_AccountFilterChips` entre la `SectionTitle('Últimos movimientos')`
   y el StreamBuilder de la lista.

FAQ Help: 1 bullet nuevo.

Sin cambios en otras pantallas.

## Cambios de permisos si aplica

No aplica.

## Riesgos tecnicos

- **R1 — Compute cost del sparkline con 3 queries paralelas**: los 3
  cards abren 3 streams simultáneos. Cada uno joinea `journal_entries`
  con `accounts` filtrando por tipo. Si el dataset crece a 10k+
  entries totales, puede notarse. Mitigación: query única por card
  con `readsFrom` explícito; distinct por día en Dart. Verificar
  con dataset real en SM.
- **R2 — Reactividad ruidosa**: registrar un movimiento re-emite
  4 streams (Today + 3 sparklines) + BO/DE/CR + lista + Mis cuentas
  = 7-8 re-emits. Cada uno recomputa desde cero. Aceptable en
  single-user esporádico. Mitigación futura: `distinctUntilChanged`
  sobre el hash del resultado.
- **R3 — Ancho del `_TotalCard` con sparkline**: los 3 cards viven
  en un `Row > Expanded` con `SizedBox(width: 8)` entre ellos. La
  sparkline responsive al ancho debería quedar bien, pero puede
  romperse en landscape o pantallas anchas. Verificar SM.
- **R4 — Chips no persisten entre sesiones**: documentado como
  simplificación intencional. Diego puede pedirlo después.
- **R5 — Cruzar medianoche con dashboard abierto**: la vista "Hoy"
  no cambia hasta refresh. Documentado RN-DB15.
- **R6 — Archivar cuenta con chip seleccionado**: manejo via
  listener del `_accountsStream`. Necesita test explícito.
- **R7 — Layout inicial con Skeleton**: mientras los streams cargan,
  ver skeletons para vista "Hoy", sparklines y lista. Verificar que
  no se ve mal (múltiples skeletons apilados).
- **R8 — Bezier vs polyline en `_SparklinePainter`**: la spec
  menciona "línea suave". Bezier suave pero puede ocultar
  variaciones cortas. Polyline recta es preciso pero se ve dentado
  con pocos datos. Recomendación: polyline con anti-alias por
  simplicidad; suavizar si se ve mal en SM.

## Estrategia de pruebas

Ver `test-plan.md`. Foco:

- **UT servicio Today** (5 tests): agregación, kinds excluidos,
  cancelados excluidos, sin movimientos, reactividad.
- **UT servicio Sparkline** (7 tests): 30 puntos, backfill, semántica
  cash+debit vs credit, cuenta archivada, transfer/debt_payment,
  cambio de saldo día a día, reactividad.
- **Widget tests dashboard** (5+ tests): vista Hoy visible con
  datos, sparklines renderean, chip cambia el listado, archivar
  cuenta filtrada resetea el chip, empty state.
- **Smokes SM-01..07** con Diego en cel real.

## Estrategia de rollback

Feature 100% aditiva. `git revert` del commit final elimina la
funcionalidad sin residuo:

- Zero schema/data.
- Modelos nuevos no persisten.
- `EntriesDao.watchPage` sigue aceptando `accountIds` (parámetro que
  ya existía).
- FAQ actualizado se revierte con el commit.

Si aparece bug bloqueante post-deploy, patch `0.19.1+94` con fix.

## Orden sugerido de implementacion

1. **T001**: leer código actual detallado —
   `dashboard_screen.dart` (`_DashboardScreenState`, `_TotalCard`,
   `_AccountTile`), `reports.dart` (patrón de queries reactivas),
   `EntriesDao.watchPage` (signature con accountIds),
   `FinancialStateService.watchAccountBalance` (cálculo de saldo
   cash vs credit).
2. **T002** (servicio Today): `watchTodaySummary`.
3. **T003** (servicio Sparkline): `watchDailyBalance30d` con
   agregado por kind (bo/de/cr).
4. **T004** (modelos): `TodaySummary` + `DailyBalance`.
5. **T005** (widget `_TodayCard`).
6. **T006** (widget `_Sparkline` + `_SparklinePainter`).
7. **T007** (integrar sparkline dentro de `_TotalCard`).
8. **T008** (widget `_AccountFilterChips` + state en
   `_DashboardScreenState` + listener para archive).
9. **T009** (FAQ Help).
10. **T010** (UT-TD01..05 vista Hoy).
11. **T011** (UT-SP01..07 sparkline).
12. **T012** (WT-DB01..05 dashboard).
13. **T013** (suite verde + analyze + bump + APK).
14. **T014** (smokes SM-01..07 con Diego).
15. **T015** (`branch-quality-review`).
16. **T016** (commit final).

## Casos borde que condicionan la solucion

Ver `test-plan.md` para el listado completo (CB-01..18 spec +
CB-P01..P05 plan).

Casos borde nuevos identificados en el plan:

- **CB-P01**: `_TotalCard` con dataset muy denso (200+ movimientos
  en 30 días para BO) — la query agrupada por día trae ~30 rows.
  Compute negligible; el `_SparklinePainter` pinta 30 puntos.
- **CB-P02**: dispositivo en landscape / pantallas anchas — los
  cards son `Expanded` en un `Row`. Sparkline responsive por
  `CustomPaint` con constraints del padre.
- **CB-P03**: multiple listeners simultáneos sobre `journal_entries`
  → drift no colapsa. Cada stream re-emite independiente.
- **CB-P04**: usuario con solo Bolsa → chip "Todas" + "Bolsa"
  visibles. Filtro no aporta pero no rompe.
- **CB-P05**: usuario con 20+ cuentas → chips scrollean
  horizontalmente. Verificar en SM.

## Preguntas o supuestos que siguen afectando la implementacion

Sin preguntas bloqueantes.

Supuestos operativos que se mantienen desde la spec:

- El `_TotalCard` acepta agregar contenido debajo del balance sin
  refactor mayor. Confirmado por lectura del archivo.
- `deps.accountsDao.watchActive()` existe y retorna
  `Stream<List<Account>>`. Confirmado en `dashboard_screen.dart:34`.
- `EntriesDao.watchPage(limit, accountIds)` acepta filtro por
  cuenta. Confirmado en `entries_dao.dart:73`.
- La lista `_recentEntriesStream` cambia solo con `setState` cuando
  cambia el filtro; drift no requiere `.cancel()` explícito.
- `intl` con `es_MX` está disponible (patrón heredado).
- `_SparklinePainter` con `Path` recto (polyline) sin curva Bezier
  es suficiente para MVP. Suavizado se puede agregar después.
- Bump `0.19.0+93` es apropiado (minor por bundle grande visible).
- 15 tests nuevos son suficientes; tests widget adicionales se
  agregan si aparece regresión.
