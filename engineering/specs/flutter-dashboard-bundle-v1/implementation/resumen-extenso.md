# Resumen extenso — flutter-dashboard-bundle-v1

## Contexto

El Dashboard actual era la primera pantalla que Diego veía cada vez que
abría la app pero no comunicaba tendencia (¿está creciendo el
bolsillo?), no mostraba contexto del día (¿te movió algo hoy?), y no
permitía filtrar rápidamente por cuenta al mirar los últimos
movimientos.

Los 3 gaps se cierran con features chicas, aditivas, sin regresión.
Todas usan el mismo archivo `dashboard_screen.dart` — se hizo un solo
sprint para evitar 3 rondas de spec-driven + 3 commits sobre la misma
pantalla.

Decisiones tomadas antes de spec (via AskUserQuestion):
1. **Filtro por cuenta**: chip arriba de "Últimos movimientos" →
   filtra solo esa lista. Cards BO/DE/CR y lista de cuentas siguen
   mostrando el consolidado.
2. **Sparkline data**: saldo diario últimos 30 días (patrón fintech).
3. **Vista "Hoy" scope**: gasto incluye expense + credit_expense
   (consistente con cashflow mensual).

## Relación con `plan/plan.md` y `plan/tasks.md`

Se ejecutaron **T001-T014 completas** en el orden del plan.
**T015-T017 (smokes, quality-review, commit final)** pendientes.

RF cubiertos: RF-001..RF-013. RN-DB01..DB15 implementadas y
verificadas con UT + WT.

## Cambios principales por módulo o capa

### Data (`reports.dart`)

- **`watchTodaySummary({DateTime? now})`**: query única con
  `SUM(CASE WHEN kind = ...)`, filtro `strftime('%Y-%m-%d',
  occurred_at, 'localtime') = ?`, `kind IN ('income', 'expense',
  'credit_expense')`, `deleted_at IS NULL`.
  `readsFrom: {journalEntries}`. Retorna `TodaySummary { day,
  totalIncome, totalExpense, net }`.
- **`watchDailyBalance30d({required String kind, DateTime? now})`**:
  2 sub-queries + helper Dart `_buildDailyBalance30d`:
  1. `sqlInitial`: balance por cuenta ANTES del rango (`occurred_at
     < rangeStart`) para inicializar el acumulador.
  2. `sqlChanges`: deltas por `(day, account_id)` DENTRO del rango.
  3. Helper: itera 30 días, aplica deltas a cada cuenta, backfillea
     días vacíos con el balance del día previo, y colapsa al
     agregado según `kind`:
     - `bo` = suma de balances (cash + debit).
     - `de` = suma de deudas (`-rawBalance` de credit).
     - `cr` = suma de `(credit_limit - deuda)` de credit.
  `readsFrom: {journalEntries, accounts}`. Retorna
  `List<DailyBalance>` con exactamente 30 puntos.
- **Modelos**: `TodaySummary`, `DailyBalance` const-inmutables.
- **Clase privada** `_AccountBalanceMeta` para el acumulador.

### UI (`dashboard_screen.dart`)

- **`_TodayCard`**: card arriba con fecha (`DateFormat('EEE d MMM',
  'es_MX')` capitalizada) + 3 métricas (`_TodayMetric`). Colores
  positive/negative para ingresos/gastos; neto con signo `+`/`-`.
  Sin movimientos → todos los montos en `textMuted`.
- **`_Sparkline`**: `StreamBuilder<List<DailyBalance>>` → `SizedBox
  (height: 24) + CustomPaint(painter: _SparklinePainter)`. Sin datos
  → `SizedBox.shrink()`. Layout responsive al ancho del `_TotalCard`.
- **`_SparklinePainter`**: `Path` polyline con `moveTo` + `lineTo`.
  Escala vertical al min-max local del rango. Si min == max → línea
  horizontal centrada. `Paint` con `strokeWidth: 1.5`, `strokeCap:
  round`, anti-alias.
- **`_TotalCard` extendido**: nuevo parámetro opcional
  `sparklineStream`. Se renderea entre el balance y el hint.
- **`_AccountFilterChips`**: `SizedBox(height: 34)` con `ListView`
  horizontal de `ChoiceChip`s. "Todas" primero + una por cuenta
  activa (obtenida del `_accountsStream` ya cacheado). `showCheckmark:
  false` + estilos consistentes con presets del cashflow tab.
- **State del `_DashboardScreenState`**: 4 streams nuevos
  (`_todayStream`, `_boSparkStream`, `_deSparkStream`,
  `_crSparkStream`), campo `_selectedAccountId`, handler
  `_onFilterChanged(String? id)`, y `StreamSubscription
  _accountsListenerSub` para resetear el filtro cuando la cuenta
  seleccionada se archiva. Cancelada en `dispose`.

### Docs

- `help_screen.dart`: bullet dentro del tema "¿Qué significan BO, DE y
  CR?" mencionando las 3 novedades del dashboard (vista Hoy,
  sparklines, filtro por cuenta).

## Desviaciones respecto al plan

- **D1 — API del sparkline por `kind` en vez de `accountId +
  accountType`**: el plan proponía `{accountId, accountType}` pero
  eso obliga al widget a iterar cuentas y sumar. Cambio: parámetro
  `{kind: 'bo'/'de'/'cr'}` que agrega todas las cuentas del tipo
  dentro del servicio. Simplifica la API y coincide con cómo el
  dashboard ya piensa (cada `_TotalCard` es 1 kind). Documentado en
  spec-planear.
- **D2 — `_TotalCard` con parámetro opcional `sparklineStream`**: en
  vez de refactorear la firma requerida (que rompe callers de test),
  se agrega como `Stream<List<DailyBalance>>?` opcional. Compat
  hacia atrás.
- **D3 — Ajuste de aserciones en 4 tests preexistentes**: el chip
  filtro con nombre de cuenta agrega 1 instancia adicional del
  string a `find.text('<nombre>')`. Cambios:
  - `dashboard_screen_test.dart` línea 14: `findsNWidgets(2)` →
    `findsAtLeastNWidgets(2)`.
  - Mismo archivo test "row muestra": `skipOffstage: false` en 3
    finders.
  - `widget_test_harness_test.dart`: 2 aserciones ajustadas
    similarmente.
- **D4 — Los WT-DB03 y WT-DB05 necesitan doble `pump` post-tap**: el
  patrón `await tester.tap(...); await tester.pumpAndSettle()` no es
  suficiente cuando el `setState` reconstruye el `StreamBuilder` con
  un stream nuevo — drift necesita un microtask extra para emitir el
  primer valor. Ajuste: `await tester.pump(); await tester.pump(const
  Duration(milliseconds: 50)); await tester.pumpAndSettle()`.
- **D5 — Aserción visual del chip seleccionado en WT-DB03**: agregar
  `expect(chip.selected, isTrue)` post-tap ayudó a diagnosticar que
  el problema NO era del `onSelected` sino del pump timing.

## Pruebas realizadas y recomendadas

### Realizadas

- `flutter analyze` limpio (solo hint info pre-existente).
- `flutter test` 590/590 verdes:
  - UT-TD01..05, UT-TD07: cálculo del día, kinds excluidos,
    cancelados, reactividad.
  - UT-SP01..07: 30 puntos siempre, backfill, semántica cash/debit
    vs credit invertido, cuenta archivada, reactividad al registrar.
  - WT-DB01..05: vista Hoy visible + labels, chip filtra listado,
    "Todas" default al montar, restaurar consolidado.
  - 4 tests preexistentes ajustados por la nueva instancia del chip
    en el widget tree.
- APK release + `verify-apk.sh` OK (versionCode 2093 / versionName
  0.19.0).

### Recomendadas

- SM-01..07 con Diego en cel real. Especialmente **SM-02** (layout
  de sparklines en cel angosto), **SM-04** (reactividad al registrar
  income de hoy: vista Hoy + sparkline de BO + lista se actualizan
  correctamente), **SM-05** (archivar cuenta filtrada → chip
  desaparece + filtro cae a "Todas").

## Riesgos residuales y posibles regresiones

- **R1 — Compute cost sparkline**: negligible en single-user < 500
  mov totales. Verificable en SM-02 real.
- **R2 — Reactividad ruidosa**: 7-8 re-emits por movimiento
  aceptables single-user; sin throttle en este sprint.
- **R3 — Layout responsive**: cel angosto (≤ 400 px viewport) es el
  peor caso. Con `Expanded > BaseCard` y `SizedBox(height: 24)` la
  sparkline se ajusta al ancho disponible. Verificar SM.
- **R5 — Medianoche**: RN-DB15 aceptado; sin `Timer` para refresh
  automático.
- **R6 — Archivar cuenta con chip seleccionado**: cubierto por
  listener + `mounted` check. WT explícito quedaría como follow-up
  si aparece regresión.
- Cero regresión funcional en otros reportes, forms, backup,
  `EntriesDao.watchPage` (que ya soportaba `accountIds`).

Sprint completo excepto smoke + quality-review + commit final.
