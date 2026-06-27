# Resumen extenso — flutter-reports-balance-at-date-v1

## Contexto tomado de spec.md y clarificaciones

Sprint mediano (~2h reales) que sigue al F2 (top movements). Cierra
el set analítico de `/reports` con 4 tabs.

Decisiones cerradas con `preguntas.md`:

- **P-001 (default fecha)**: respondida "fin del mes anterior"
  (opción C). `_asOf = DateTime(now.year, now.month, 0)` (truco día
  0). Apunta al uso productivo: reconciliación con estados de cuenta.
- **P-002 (desglose)**: respondida "totales + lista de cuentas"
  (opción B). El tab muestra 3 cards BO/DE/CR arriba y una lista de
  cuentas con saldo individual debajo.

Reglas de negocio críticas (RN-B01..B08):

- BO/DE/CR a fecha = formulas de `FinancialStateService` con filtro
  `AND occurred_at <= ?` extra (RN-B01..B03).
- `asOf` inclusivo al final del día (23:59:59.999) (RN-B04).
- Solo cuentas activas hoy (`deleted_at IS NULL`) (RN-B05).
- `asOf` máximo = hoy; mínimo = 2020-01-01 (RN-B06, RN-B07).
- Lista de cuentas ordenada por tipo (cash → debit → credit) +
  alfabético dentro de cada tipo (RN-B08).

## Relación con plan/plan.md y plan/tasks.md

Las **29 tareas** del plan ejecutadas en orden de fases F0 → F6 con
una desviación estructural en F1 (documentada abajo):

- **F0** (T001): baseline `flutter test` → 266 verdes.
- **F1** (T002-T006): modelos + servicio + builder. El plan original
  asumía 4 queries SQL separadas (3 totales + 1 lista) combinadas con
  `Stream.combineLatest`. **La implementación las consolidó en 1
  sola query SQL** que retorna por cuenta los datos necesarios; los 3
  totales se calculan en Dart agregando. Más eficiente y más simple.
- **F2** (T007-T014): 8 tests data en 3 grupos.
- **F3** (T015-T020): UI `BalanceAtDateTab` (~370 líneas). Clona el
  patrón del cashflow tab.
- **F4** (T021-T022): TabBar 3→4. Tests existentes verdes sin
  cambios.
- **F5** (T023-T025): 3 widget tests con helper `openBalanceAtDateTab`
  que usa `ensureVisible` antes del tap (necesario con `isScrollable:
  true`).
- **F6** (T026-T029): suite verde + bump + APK + verify + docs.

## Cambios principales por módulo o capa

### Capa de datos (`mobile/lib/data/reports.dart`)

Modelos nuevos:

- `BalanceAtDateReport({asOf, bo, de, cr, accounts})` con getter
  `isEmpty` (true si `accounts.isEmpty`).
- `AccountBalanceAtDate({id, name, type, creditLimit, balance})`.

Servicio extendido:

- `ReportsService.balanceAtDate({DateTime asOf})` retorna
  `Stream<BalanceAtDateReport>` con `readsFrom: {accounts,
  journalEntries}`.
- 1 query SQL agregada que retorna fila por cuenta activa con `id`,
  `name`, `type`, `credit_limit`, y `balance` calculado con CASE
  WHEN según el tipo:
  - `cash/debit`: `SUM(amount destination) - SUM(amount origin)` con
    `occurred_at <= endOfDay`.
  - `credit`: `SUM(amount origin) - SUM(amount destination)` (deuda).
- Orden SQL: `CASE WHEN type = 'cash' THEN 1 WHEN 'debit' THEN 2
  WHEN 'credit' THEN 3 ELSE 4 END ASC, name ASC`.
- Drift parametriza 4 instancias de `endOfDay` (una por subquery
  inline) con `Variable.withDateTime`.

Helpers privados:

- `_endOfDay(DateTime asOf)` → extiende `asOf` a `23:59:59.999`
  (RN-B04). Sin tocar timezone.
- `_buildBalanceAtDateReport(rows, asOf)` mapea filas a
  `AccountBalanceAtDate` y agrega los 3 totales en Dart:
  - BO = `SUM(balance)` donde `type IN ('cash', 'debit')`.
  - DE = `SUM(balance)` donde `type = 'credit'`.
  - CR = `SUM(credit_limit - balance)` donde `type = 'credit' AND
    credit_limit != null`.

### Capa de presentación (`mobile/lib/screens/reports/balance_at_date_tab.dart`)

Nuevo widget con:

- State: `_asOf` (default `DateTime(now.year, now.month, 0)` —
  último día del mes anterior por truco día 0), `_reportStream`.
- Header: `DateFieldOutlined` con label "Saldo al". Tap abre
  `showDatePicker` con `firstDate: 2020-01-01, lastDate:
  DateTime.now()`.
- Body con `StreamBuilder`:
  - `_BalanceCards`: Row de 3 `_BalanceCard` (BO verde, DE rojo, CR
    azul). Cada card con label + monto + subtítulo ("Líquido",
    "Deuda", "Disponible").
  - `_AccountsList` debajo: `Column` con `_AccountRow` por cada
    cuenta. Cada row: nombre + tipo label (Efectivo/Débito/Crédito) +
    monto con signo. Cuentas credit muestran "deuda" como sufijo si
    balance > 0.
- Estados loading/error/empty clonados del cashflow tab.

### `ReportsScreen` (`mobile/lib/screens/reports_screen.dart`)

- `DefaultTabController.length: 3 → 4`.
- Cuarto `Tab(text: 'Saldo a fecha')`.
- Cuarto `BalanceAtDateTab()` en `TabBarView`.
- `isScrollable: true` ya activo desde sprint anterior — el cuarto
  tab se desliza si no cabe.

### Tests

`test/data/reports_test.dart` (+8 tests en 3 grupos):

- `balanceAtDate — totales`:
  - UT-01: BD vacía → BO=0, DE=0, CR=50000 (límite de Visa).
  - UT-02: fecha = hoy coincide con
    `FinancialStateService.watchBo/De/Cr` (validación cruzada).
  - UT-03: fecha pasada filtra entries posteriores.
  - UT-04: entry a 23:59:59 cuenta; entry 1 ms después NO.
- `balanceAtDate — soft delete y archivos`:
  - UT-05: entry soft-deleted excluido.
  - UT-06: credit_limit null contribuye a DE pero no a CR;
    credit_limit chico contribuye a CR según fórmula.
- `balanceAtDate — lista de cuentas`:
  - UT-07: orden por tipo + alfabético.
  - UT-08: cuenta sin movimientos hasta la fecha aparece con
    balance=0.

`test/screens/balance_at_date_tab_test.dart` nuevo (3 widget tests):

- WT-01: render con datos (3 cards + Bolsa en lista).
- WT-02: empty state cuando BD sin cuentas (`seedBolsa: false` +
  manual firstRun=true).
- WT-03: tap en field abre `DatePickerDialog`.

## Desviaciones respecto al plan

**DV-1 (estructural)** — **Consolidación de 4 queries en 1**: el plan
asumía 3 SQLs clonados de `FinancialStateService.watchBo/De/Cr` +
1 SQL para la lista de cuentas, combinados con `Stream.combineLatest`.
La implementación los consolidó en **1 sola query SQL** que retorna
filas por cuenta con el balance calculado vía CASE WHEN. Los 3
totales se calculan en Dart sumando sobre las filas.

Razones:
- Más simple: 1 stream vs combinación de 4.
- Más eficiente: 1 viaje a BD vs 4.
- Sin dependencia de `Stream.combineLatest` (que no es estándar en
  Dart sin rxdart).
- Misma reactividad: `readsFrom: {accounts, journalEntries}` cubre
  todos los cambios.

Sin impacto en RFs cubiertos. Documentado para code review.

**DV-2 (menor)** — **`ensureVisible` en el helper de WT**: el plan no
preveía que con `isScrollable: true` el cuarto tab queda fuera del
viewport inicial. El helper `openBalanceAtDateTab` agrega
`ensureVisible` + `pumpAndSettle` antes del tap. Ajuste defensivo,
sin cambio funcional.

## Pruebas realizadas y recomendadas

**Realizadas** (automatizado):

- `flutter analyze` → 0 errores, 4 hints `info` pre-existentes (no
  del sprint).
- `flutter test` completo → 277/277 verdes en 22s.
- Tests del DAO `--name 'balanceAtDate'` → 8/8 verdes en 1s.
- Tests del tab → 3/3 verdes en 3s.
- `reports_screen_test.dart` → 5/5 verdes sin cambios post bump.
- `flutter build apk --release --split-per-abi` → 3 APKs en 64s.
- `bash scripts/verify-apk.sh` → versionCode 2061 / versionName 0.9.0.

**Recomendadas** (smoke manual):

- SM-01..SM-06 documentados en `test-plan.md` y replicados en
  `implementation-review.md`.

## Riesgos residuales y posibles regresiones

- **R-T01 del plan** (cerrado): tests existentes verdes tras bump
  3→4.
- **R-T02, R-T03 del plan** (resueltos por consolidación a 1 query).
- **R-T04 del plan** (cerrado): `_endOfDay` validado por UT-04.
- **R-T05 del plan** (cerrado): truco día 0 funciona correctamente.
- **Coherencia con dashboard**: UT-02 valida cruzado. En smoke real
  Diego puede confirmar visualmente.
- Sin regresión esperada en otros 3 tabs ni en dashboard.

## Aplicación de engineering-code-standards

Skill no invocada explícitamente. Aplicación implícita de patrones del
repo: modelos inmutables, `customSelect.watch` con `readsFrom`,
parametrización segura vía `Variable.withDateTime`, doc-comments con
folios (RN-B04, RF-001, etc.), tests por archivo con grupos por
categoría, validación cruzada con `FinancialStateService` para no
desincronizar fórmulas, helper privado `_endOfDay` reutilizable.

## Aplicación de branch-quality-review

`branch-quality-review` disponible pero NO invocada (no pedida
explícitamente). Si Diego quiere revisión exhaustiva:

```bash
branch-quality-review flutter-reports-balance-at-date-v1
```
