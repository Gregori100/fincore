# Bundle de mejoras al Dashboard

## Resumen

Sprint agregando 3 features aditivas al Dashboard en un solo commit,
sin schema bump ni cambios en otras pantallas:

1. **Vista "Hoy"** — card arriba del dashboard con ingresos/gastos/neto
   del día calendario en curso.
2. **Sparkline** — mini-gráfico horizontal de la evolución del saldo
   diario en los últimos 30 días, agregado debajo de cada uno de los
   3 `_TotalCard` (BO, DE, CR).
3. **Filtro rápido por cuenta** — chips scrollables justo arriba de la
   lista "Últimos movimientos" para filtrarla por una cuenta específica.

Se implementan como un solo sprint porque comparten superficie (mismo
archivo `dashboard_screen.dart`), state y diseño visual del dashboard.
Hacerlas separadas obliga a 3 rondas de spec-driven + 3 commits sobre
la misma pantalla.

## Problema a resolver

El dashboard actual muestra:

- 3 totales agregados (Bolsa, Deuda, Crédito) sin contexto de
  evolución.
- Lista de cuentas.
- Últimos 10 movimientos sin filtro.

Es la primera pantalla que Diego ve cada vez que abre la app pero no
comunica **tendencia** (¿está creciendo tu bolsillo?), no muestra
**contexto del día** (¿te movió algo hoy?) y no permite **filtrar por
cuenta** cuando querés ver qué pasó específicamente con una tarjeta o
con la Bolsa.

Los 3 gaps se cierran con features chicas, aditivas, sin regresión.
Todos usan el mismo archivo `dashboard_screen.dart` — no tiene sentido
sprintearlas separadas.

## Objetivo

Al abrir el dashboard, en menos de 2 segundos Diego debería poder
responder:

- **"¿Me moví hoy?"** — vista "Hoy".
- **"¿Está creciendo o bajando mi bolsillo?"** — sparkline.
- **"¿Qué pasó en la Bolsa?"** — filtro rápido por cuenta.

Todo sin abrir otro reporte ni cambiar de pantalla. Cero fricción
adicional en el flujo actual (usuarios que ignoren el filtro siguen
viendo los 10 movimientos consolidados).

## Alcance

### Vista "Hoy" — nuevo widget arriba del dashboard

- Nuevo widget `_TodayCard` que se renderea arriba de los 3
  `_TotalCard`.
- Muestra: fecha del día formateada (`DateFormat('EEE d MMM', 'es_MX')`
  capitalizada, ej. `Sáb 13 jul`), monto de ingresos del día (color
  `positive`), monto de gastos del día (color `negative`), neto del
  día (color según signo, con signo `+`/`-` explícito para el neto).
- Nueva query en `ReportsService.watchTodaySummary({DateTime? now})`
  que retorna `Stream<TodaySummary>` con `totalIncome`,
  `totalExpense`, `net` para el día calendario local del `now`
  (default `DateTime.now()`).
- SQL: `WHERE strftime('%Y-%m-%d', occurred_at, 'localtime') = ?` con
  el día actual formateado como `YYYY-MM-DD` (patrón heredado del
  calendar/heatmap).
- Filtra `kind IN ('income', 'expense', 'credit_expense')`;
  `transfer` y `debt_payment` excluidos por ser movimientos internos.
- `deleted_at IS NULL` para excluir cancelados.
- `readsFrom: {journalEntries}` para reactividad.
- Se muestra **siempre**, incluso sin movimientos del día
  (`$0 · $0 · Neto $0` en `textMuted`).

### Sparkline — dentro de cada `_TotalCard`

- Nueva query en `ReportsService.watchDailyBalance30d({required String
  accountId, required String accountType, DateTime? now})` que retorna
  `Stream<List<DailyBalance>>` con exactamente 30 puntos (uno por día
  calendario local desde `hoy - 29d` hasta `hoy`).
- Cálculo del saldo día a día:
  - Cash/debit: `Σ destination.amount − Σ origin.amount` acumulado
    hasta el fin del día.
  - Credit: invertido — `Σ origin.amount − Σ destination.amount`
    acumulado (deuda: cargos suben, pagos bajan).
- Días sin movimientos se backfillean con el saldo del día previo.
- El `_TotalCard` de BO/DE/CR es un **agregado de N cuentas** — el
  sparkline muestra el agregado. Para BO: suma de todas las cash+debit.
  Para DE: suma de todos los credit balances (deuda). Para CR: suma
  de `(credit_limit − balance)` de todas las credit.
- Nueva clase `_Sparkline` con `CustomPaint` — línea suave (curva
  Bezier o polyline simple), color según tipo del card
  (`FincoreColors.positive` para BO, `negative` para DE, `accent` o
  neutro para CR), altura ~28 px, ancho responsivo. Sin ejes ni
  labels; opcionalmente `30d` a la derecha en `textSubtle` fontSize
  10.
- Escala vertical: min-max del rango de 30 días. Si min == max
  (todos los saldos iguales), pintar una línea horizontal en el
  centro.
- `readsFrom: {journalEntries, accounts}` — cambio en cualquier
  movimiento o creación/archivado de cuenta afecta el histórico
  del agregado.

### Filtro rápido por cuenta — chips arriba de "Últimos movimientos"

- Nuevo widget `_AccountFilterChips` justo arriba de la lista
  "Últimos movimientos".
- Chips horizontales en un `SingleChildScrollView` horizontal:
  `Todas` (siempre primero) + una `ChoiceChip` por cada cuenta
  activa (obtenida de `accountsDao.watchAll()` reactivo).
- State en memoria del `_DashboardScreenState`
  (`String? _selectedAccountId`) — `null` significa "Todas".
- Al tapear un chip, `setState` cambia el `_selectedAccountId` y
  reemplaza el stream del listado.
- Stream del listado: `entriesDao.watchPage(limit: 10, accountIds:
  _selectedAccountId != null ? [_selectedAccountId] : null)`.
- El listado existente sigue mostrando los mismos 10 movimientos con
  el mismo layout (`MovementRow`); solo cambia el filtro.
- **No persiste entre sesiones**: al re-abrir la app, el default es
  siempre `Todas`.
- Chip visualmente consistente con el patrón `ChoiceChip` M3 usado
  en el resto del proyecto (ej. presets del cashflow tab).

### Modelos nuevos (`reports.dart`)

- `class TodaySummary { double totalIncome; double totalExpense;
  double net; DateTime day; }` const-inmutable.
- `class DailyBalance { DateTime day; double balance; }`
  const-inmutable.

### Documentación

- FAQ del Help: bullet nuevo en "Cómo funciona el dashboard" (o
  crear si no existe) mencionando las 3 novedades: vista "Hoy",
  sparkline y filtro.

## Fuera de alcance

- **Persistir el filtro entre sesiones** (en `AppPreferences`).
  Simplicidad: state en memoria, default siempre "Todas".
- **Tooltip / long-press en sparkline** para ver saldo específico
  de un día.
- **Selector de rango** (7d / 30d / 90d / año) para el sparkline.
  Fijo en 30d.
- **Vista "Hoy" con desglose por categoría o cuenta**. Solo
  agregados. Cashflow y otros reportes cubren desglose.
- **Comparación "hoy vs ayer" o "hoy vs promedio"** en la vista
  "Hoy". Sprint futuro si Diego lo pide.
- **Personalización del orden de las cards** (drag & drop). Layout
  fijo.
- **Sparkline en las cuentas individuales de la lista de cuentas**
  (`_AccountTile`). Solo en los 3 `_TotalCard` agregados.
- **Filtro por cuenta que afecte BO/DE/CR o la lista de cuentas** —
  solo la lista de "Últimos movimientos".
- **Filtros combinables** (cuenta + kind + fecha) en el chip. Solo
  cuenta. Filtro completo sigue en `/entries`.
- **Animación de transición** al cambiar el chip (fade, slide). El
  StreamBuilder actualiza el listado sin transición explícita.

## Reglas de negocio

- **RN-DB01 (vista Hoy — kinds incluidos)**: la query de vista "Hoy"
  filtra `kind IN ('income', 'expense', 'credit_expense')`. Excluye
  `transfer` y `debt_payment` porque son movimientos internos (no
  suman al ingreso o gasto real). Consistente con `cashflowByMonth`
  y `cashflowMonthBreakdown`.
- **RN-DB02 (vista Hoy — día calendario local)**: el filtro usa
  `strftime('%Y-%m-%d', occurred_at, 'localtime') = ?` con la fecha
  formateada como `YYYY-MM-DD` del `now` local. Timezone-safe
  (patrón heredado del calendar/heatmap).
- **RN-DB03 (vista Hoy — soft delete)**: excluye
  `deleted_at IS NOT NULL`.
- **RN-DB04 (vista Hoy — presencia constante)**: la card siempre se
  muestra, incluso sin movimientos del día. Renderiza `$0 · $0 ·
  Neto $0` con `textMuted` para señalar visualmente ausencia.
- **RN-DB05 (sparkline — series de 30 puntos)**: la query siempre
  retorna exactamente 30 elementos (días 0 a 29). Días sin
  movimientos se backfillean con el saldo del día previo. El primer
  día del rango (`hoy - 29d`) recibe el saldo acumulado hasta ese
  día inclusive.
- **RN-DB06 (sparkline — semántica credit invertida)**: para cuentas
  credit el saldo se calcula como `Σ origin.amount − Σ destination.
  amount` (deuda: cargos aumentan, pagos disminuyen). Consistente con
  `FinancialStateService.watchAccountBalance` credit.
- **RN-DB07 (sparkline — agregado por card)**: el `_TotalCard` de BO
  muestra la suma de cash+debit. DE suma balances de todas las
  credit. CR suma `(credit_limit − balance)` de todas las credit.
  El sparkline muestra la evolución de ese agregado día a día.
- **RN-DB08 (sparkline — escala)**: eje Y se ajusta al min-max del
  rango de 30 días. Si min == max, línea horizontal en el centro
  (evita división por cero).
- **RN-DB09 (sparkline — vacío o cuenta nueva)**: si no hay ninguna
  cuenta activa del tipo del card, sparkline se oculta (no muestra
  línea plana en $0). El `_TotalCard` sigue mostrando "$0".
- **RN-DB10 (filtro cuenta — default)**: al montar el dashboard, el
  chip `Todas` está seleccionado. `_selectedAccountId == null`.
- **RN-DB11 (filtro cuenta — solo cuentas activas)**: los chips
  muestran solo cuentas con `deleted_at IS NULL`. Al archivar una
  cuenta con el chip seleccionado, el filtro cae automáticamente a
  `Todas`.
- **RN-DB12 (filtro cuenta — Bolsa no distinguida)**: la Bolsa
  aparece como una cuenta más en los chips (no hay chip especial
  para "efectivo"). Coherente con cómo se muestra en otras partes.
- **RN-DB13 (filtro cuenta — orden de chips)**: `Todas` primero, después
  cuentas en el orden de `accountsDao.listAll()` (que ya ordena por
  type + name — cash primero, debit, credit).
- **RN-DB14 (reactividad — dashboard)**: registrar/cancelar/editar
  un movimiento re-emite todas las queries relevantes:
  - Vista "Hoy" si el movimiento es de hoy.
  - Sparkline de la cuenta afectada (todos los `_TotalCard` porque
    el sparkline afecta el agregado).
  - Lista filtrada de últimos movimientos.
  - Cards BO/DE/CR consolidados (ya existente).
- **RN-DB15 (reactividad — cambio de día a medianoche)**: si el
  usuario deja el dashboard abierto y cruza medianoche, la vista
  "Hoy" NO se actualiza automáticamente al nuevo día — mantiene la
  fecha del `now` capturado al construir el stream. Se actualiza al
  navegar fuera y volver, o al registrar un movimiento nuevo.
  Aceptable single-user esporádico (documentado en riesgos).

## Requisitos funcionales

- RF-001: agregar `ReportsService.watchTodaySummary({DateTime? now})`
  que retorna `Stream<TodaySummary>`.
- RF-002: la query de RF-001 usa
  `strftime('%Y-%m-%d', occurred_at, 'localtime') = ?` y
  `kind IN ('income', 'expense', 'credit_expense')`.
- RF-003: agregar `ReportsService.watchDailyBalance30d({required
  String accountId, required String accountType, DateTime? now})`
  que retorna `Stream<List<DailyBalance>>` de 30 puntos backfilled.
- RF-004: agregar modelos `TodaySummary` y `DailyBalance`
  const-inmutables en `reports.dart`.
- RF-005: nuevo widget `_TodayCard` en `dashboard_screen.dart`
  arriba de los 3 `_TotalCard`.
- RF-006: extender `_TotalCard` (o envolverlo) para renderear la
  sparkline debajo del balance. El sparkline es una nueva clase
  `_Sparkline` con `CustomPaint`.
- RF-007: nuevo widget `_AccountFilterChips` justo arriba de la
  lista "Últimos movimientos" con `ChoiceChip` scrollable horizontal.
- RF-008: `_DashboardScreenState` gana `String? _selectedAccountId`
  y cache del `Stream<List<Account>>` de cuentas activas.
- RF-009: el stream de la lista de movimientos se reconstruye cuando
  cambia `_selectedAccountId`. Al cambiar cuenta, `setState` con el
  nuevo stream.
- RF-010: cuando la cuenta seleccionada se archiva, el
  `_selectedAccountId` cae a `null` automáticamente (via listener
  del stream de cuentas).
- RF-011: FAQ del Help agrega bullet sobre las 3 novedades del
  dashboard.
- RF-012: 15-18 tests nuevos aprox (10 UT servicio + 5-7 widget).
- RF-013: bump `0.18.2+92` → `0.19.0+93`.

## Casos principales

1. Diego abre la app. Ve arriba: `Sáb 13 jul · +$1,200 · -$450 · Neto +$750`. Debajo, los 3 cards BO/DE/CR con sparklines que muestran una tendencia general creciente (BO subiendo, DE bajando, CR aumentando su disponible). Sabe en 2s cómo va.
2. Diego tapea el chip "Bolsa" arriba de "Últimos movimientos". La lista se filtra a los últimos 10 movimientos que tocan la Bolsa.
3. Diego registra un income de $500 desde `/entries/new`. Al volver al dashboard, la vista "Hoy" se actualiza (+$500 en ingresos, neto +$500 más), la sparkline de BO refleja el nuevo saldo del día actual, la lista de movimientos muestra el nuevo entry.
4. Diego tapea "Todas" para desfiltrar la lista. Vuelve a ver los 10 más recientes de todas las cuentas.
5. Diego archiva una cuenta que estaba filtrada. El chip desaparece de la lista, `_selectedAccountId` cae a `null`, la lista vuelve a "Todas".

## Casos borde

- **CB-01**: día sin movimientos → vista "Hoy" muestra `$0 · $0 · Neto $0` en `textMuted`.
- **CB-02**: usuario nuevo con solo Bolsa creada y 0 movimientos → sparklines de los 3 cards muestran línea horizontal en el centro (todos los días con balance 0 o el saldo actual).
- **CB-03**: usuario con solo 1 movimiento en los 30 días → sparkline muestra un cambio de nivel en ese día. Días previos con el balance inicial, días posteriores con el nuevo.
- **CB-04**: usuario con historia de 30+ días de movimientos → sparkline muestra la línea reactiva completa.
- **CB-05**: cuenta cash/debit con saldo negativo (libreta libre) → sparkline se ajusta al min-max, línea puede pasar por debajo del baseline (0).
- **CB-06**: credit con deuda estable (mismo balance 30d) → línea horizontal (min == max).
- **CB-07**: registrar `transfer` desde Bolsa a Banamex → NO afecta vista "Hoy" (excluido), NO afecta sparkline de BO (cash+debit), NO afecta sparkline de DE ni de CR. Solo mueve balance entre cash+debit dentro del agregado BO (que sigue siendo el mismo total).
- **CB-08**: registrar `debt_payment` de Bolsa a Visa → NO afecta vista "Hoy". SÍ afecta sparklines: BO baja (menos efectivo), DE baja (menos deuda), CR sube (más disponible).
- **CB-09**: cancelar un movimiento de hoy → vista "Hoy" recalcula, sparkline del día actual recalcula.
- **CB-10**: cancelar un movimiento de hace 10 días → sparkline recalcula desde ese día hacia adelante (todos los balances backfilled se corren).
- **CB-11**: filtrar por cuenta X y registrar un movimiento que NO toca X → la lista filtrada NO cambia (correcto — el filtro es reactivo pero el nuevo entry no matchea).
- **CB-12**: filtrar por cuenta X y registrar un movimiento que SÍ toca X (como origin o destination) → la lista filtrada se re-emite con el nuevo entry.
- **CB-13**: filtrar por cuenta X, archivar la cuenta X → el chip desaparece, `_selectedAccountId` cae a null, lista vuelve a "Todas".
- **CB-14**: BD con 10+ cuentas → los chips scrollean horizontalmente sin romper el layout.
- **CB-15**: renombrar cuenta con el chip seleccionado → el label del chip se actualiza al nombre nuevo (reactivo).
- **CB-16**: cruzar medianoche con dashboard abierto → vista "Hoy" NO cambia (mantiene fecha de `now` inicial). Se refresca al navegar o registrar (RN-DB15).
- **CB-17**: usuario con timezone borderline (movimiento a las 23:30 UTC del 12/jul que localmente es 12:30 del 13/jul) → cuenta en el día local correcto (13/jul) por `strftime('localtime')`.
- **CB-18**: sparkline con dataset muy volátil (huge swings) → escala se ajusta al min-max, línea se ve bien sin quedar toda al mismo nivel.

## Criterios de aceptacion

- `flutter test` verde con al menos 15 tests nuevos (10 UT + 5 widget).
- `flutter analyze` limpio.
- APK release `0.19.0+93` compilado; `verify-apk.sh` OK con
  `versionCode 2093 / versionName 0.19.0`.
- **SM-01 (vista Hoy)**: abrir dashboard → ver card arriba con fecha
  del día + 3 montos. Si no hubo movimientos hoy, `$0 · $0 · Neto $0`
  en gris.
- **SM-02 (sparkline)**: los 3 cards BO/DE/CR muestran una línea
  fina debajo del balance. Con seed real (30d de datos) las líneas
  reflejan la evolución.
- **SM-03 (filtro rápido)**: tapear un chip de cuenta → lista de
  últimos movimientos se filtra. Tapear "Todas" → vuelve al
  consolidado.
- **SM-04 (reactividad)**: registrar un income de hoy → vista "Hoy"
  recalcula, sparkline de BO refleja el nuevo saldo del día actual,
  lista se actualiza si el chip seleccionado incluye la cuenta
  afectada.
- **SM-05 (archivar cuenta filtrada)**: filtrar por cuenta X →
  archivar X → chip desaparece, filtro cae a "Todas", lista vuelve
  al consolidado.
- **SM-06 (persistencia)**: filtrar por cuenta X → cerrar app →
  reabrir → chip "Todas" seleccionado por default (state en memoria,
  no persiste).
- **SM-07 (medianoche)**: dashboard abierto → cruzar medianoche (o
  simular) → vista "Hoy" NO cambia hasta refresh (documentado en
  RN-DB15).
- Sin regresión: los 3 tabs de `/reports` que ya existían siguen
  funcionando.

## Criterios medibles de exito

- Suite total ≥ 587 tests verdes (572 baseline + ~15 nuevos).
- `flutter analyze` sin errores nuevos.
- Sparkline se renderea en < 30 ms por card con dataset típico
  single-user (< 500 movimientos totales).
- Vista "Hoy" query en < 10 ms (filtro por día, dataset chico).
- APK release build < 500 KB adicional respecto a 0.18.2+92.
- 0 regresión en tests existentes del `FinancialStateService` y
  `EntriesDao.watchPage`.

## Riesgos

- **R1 — Sparkline compute cost**: recalcular saldo día a día para
  cada card puede ser costoso si hay muchos movimientos. Mitigación:
  query única que agrupa por día con `strftime` y acumula en Dart
  (single pass sobre 30 días × N cuentas del tipo). Con < 500 mov
  totales, sub-30ms.
- **R2 — Reactividad de sparklines**: cambio en cualquier
  `journal_entry` re-emite los 3 sparklines + vista "Hoy" + lista +
  BO/DE/CR consolidados. Puede ser ruidoso. Aceptable
  (single-user esporádico). Mitigación futura: throttle o
  `distinctUntilChanged` en el stream.
- **R3 — Sparkline visual con pocos datos**: usuario nuevo con 0-3
  movimientos → sparkline se ve rara. Mitigación: RN-DB08 con
  fallback a línea horizontal. Documentado en CB-02/03.
- **R4 — Filtro que no persiste**: user puede querer que su filtro
  favorito quede seleccionado. Aceptado como simplificación
  intencional (fuera de alcance). Si Diego lo pide, sprint futuro
  con `AppPreferences`.
- **R5 — Vista "Hoy" que no cambia a medianoche**: usuario que deja
  dashboard abierto verá "Hoy" con la fecha del día anterior hasta
  refrescar. Aceptable single-user. Mitigación futura: `Timer` que
  refresca a medianoche.
- **R6 — Divergencia timezone entre vista Hoy y otros reportes**:
  ya documentado en R6 del sprint padre. Vista "Hoy" usa `localtime`
  (coherente con calendar / heatmap / breakdown). Cashflow base usa
  UTC. Coherente internamente.
- **R7 — Sparkline con eje Y basado en min-max local**: 30 días con
  saldos estables (min == max = $1000) se muestran como línea
  horizontal aunque hubiera micro-variaciones. Aceptable.
- **R8 — Densidad visual del dashboard**: agregar vista Hoy + 3
  sparklines + chip filtro puede sentirse cargado. Mitigación:
  sparklines pequeñas (altura 28 px), chip discreto, colores
  suaves. Verificar en SM.

## Supuestos

- El `_TotalCard` actual acepta agregar contenido debajo del balance
  sin refactor mayor.
- `accountsDao.watchAll()` (o equivalente reactivo) existe o es
  fácil de agregar.
- `entriesDao.watchPage` acepta `accountIds` como filtro (ya
  verificado).
- El widget de la lista de movimientos existente (probablemente
  `MovementRow`) no requiere cambios para funcionar con el filtro
  aplicado.
- `intl` con locale `es_MX` está registrado en el proyecto (usado en
  otros lugares).
- `FincoreColors` tiene los colores `positive`, `negative`, `accent`,
  `textMuted`, `textSubtle` que el sparkline necesita.
- Bump `0.19.0+93` es apropiado (minor por bundle grande visible).
- 15 tests nuevos son suficientes; si aparece más superficie durante
  implementación, se agregan.
- Diego prefiere ver el sparkline aunque haya poca variación (línea
  chata) sobre no verlo.

## Impacto esperado

- **Contexto en 2 segundos**: Diego responde "¿me moví hoy?" y
  "¿está creciendo mi bolsillo?" sin abrir otro reporte.
- **Filtro contextual**: cuando registra un movimiento pesado en una
  cuenta específica, puede verificar el efecto tapeando su chip.
- **Base para features futuros**: sparkline con selector de rango
  (7d / 90d / año), tooltip de saldo por día, comparación
  hoy-vs-promedio, persistencia del filtro en `AppPreferences`.
- **Cero regresión** en dashboard existente. Users que ignoren las
  novedades ven el mismo layout con 3 elementos nuevos.
- **Cero cambio de schema, cero migración, cero cambio en otros
  reportes o forms**.
- Feature 100% reversible con `git revert`.
