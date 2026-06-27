# Plan técnico — flutter-reports-balance-at-date-v1

## Enfoque técnico

Estrategia incremental clónica de los 3 tabs anteriores de
`/reports`:

1. **Capa de datos**: extender `ReportsService` con
   `balanceAtDate(asOf)` que retorna `Stream<BalanceAtDateReport>` via
   `customSelect.watch()`. Reusa **exactamente** los 3 SQLs de
   `FinancialStateService.watchBo/watchDe/watchCr` agregando `AND
   occurred_at <= ?` a cada subquery de SUM, más una query separada
   para el desglose por cuenta. Modelos inmutables
   `BalanceAtDateReport` y `AccountBalanceAtDate`.
2. **Capa de presentación**: nuevo widget `BalanceAtDateTab` con
   estructura del cashflow/top tabs (header con `DateFieldOutlined` +
   StreamBuilder + estados loading/error/empty). Body con 3 cards
   (BO/DE/CR) + lista de cuentas debajo con saldo individual.
3. **Integración**: `ReportsScreen` cambia `length: 3 → 4` + agrega
   cuarto `Tab` + cuarto `TabBarView`. `isScrollable: true` ya está
   activo del sprint anterior.
4. **Tests**: 8 tests data + 3 widget tests. Validar
   `reports_screen_test.dart` verde tras bump a 4 tabs.

Sin migración de schema. Sin deps externas. Sin tocar productivo del
spending, cashflow o top tabs. Reutiliza `FinancialStateService` solo
como referencia del patrón SQL.

## Requisitos funcionales cubiertos

- **RF-001**: `balanceAtDate(asOf)` en F1.
- **RF-002**: `BalanceAtDateReport` en F1.
- **RF-003**: `AccountBalanceAtDate` en F1.
- **RF-004**: SQL con `AND occurred_at <= ?` agregado a las subqueries
  de SUM, fecha extendida a fin del día en Dart antes de pasar al SQL
  (RN-B04) en F1.
- **RF-005**: query separada para lista de cuentas con balance
  individual en F1.
- **RF-006**: `BalanceAtDateTab` con header de date + body de 3 cards
  + lista en F3.
- **RF-007**: `showDatePicker` con `firstDate: 2020-01-01`, `lastDate:
  DateTime.now()`, `initialDate: _asOf = DateTime(now.year, now.month,
  0)` en F3.
- **RF-008**: 3 cards con label + monto + color en F3.
- **RF-009**: rows de cuenta con nombre + tipo label + monto en F3.
- **RF-010**: empty state si no hay cuentas activas en F3.
- **RF-011**: `ReportsScreen` con TabBar de 4 tabs en F4.
- **RF-012**: estados loading/error estáticos en F3.

## Archivos o módulos probablemente afectados

Nuevos:

- `mobile/lib/screens/reports/balance_at_date_tab.dart` (~280 líneas
  estimadas).
- `mobile/test/screens/balance_at_date_tab_test.dart` (~120 líneas
  estimadas).

Modificados:

- `mobile/lib/data/reports.dart` (+~150 líneas: 2 modelos + método +
  builder + helper de fin de día).
- `mobile/lib/screens/reports_screen.dart` (+~5 líneas: 4 tabs).
- `mobile/test/data/reports_test.dart` (+~240 líneas: grupo
  `balanceAtDate` con 8 tests).
- `mobile/test/screens/reports_screen_test.dart` (probable verde sin
  cambios — sprint anterior validó que no asumían length=3 cuando
  bumpeamos 2→3).
- `mobile/pubspec.yaml` (bump 0.9.0+61 + nota).
- `mobile/android/app/build.gradle.kts` (versionCode 61 / versionName
  0.9.0).

No tocados intencionalmente:

- `spending_by_category_tab.dart`, `cashflow_tab.dart`,
  `top_movements_tab.dart` (los 3 tabs anteriores intactos).
- `financial_state.dart` (solo se usa como referencia del patrón SQL,
  sin tocarlo).
- `dashboard_screen.dart` (sin cambios; sigue usando
  `FinancialStateService` para BO/DE/CR de hoy).

## Entidades y estados afectados

- **Lectura** sobre `journal_entries` (amount, occurred_at,
  account_origin_id, account_destination_id, deleted_at).
- **Lectura** sobre `accounts` (id, name, type, credit_limit,
  deleted_at).
- Sin escritura. Sin transiciones. Sin invariantes nuevos.
- Sin auditoría adicional.

## Compatibilidad con datos y procesos existentes

- **Backward compatible**: `spendingByCategory`, `cashflowByMonth` y
  `topMovements` intactos. `FinancialStateService.watchBo/De/Cr`
  intactos.
- **TabBar de 4 tabs**: `DefaultTabController(length: 4)`. Los 5 tests
  de `reports_screen_test.dart` no asumían length (sprint anterior
  validó). Verificar igual en T022.
- **Sin migración** de schema.
- **`isScrollable: true`** ya activo desde sprint anterior — 4 labels
  caben con scroll horizontal.
- **Sin afecto a `/dashboard`**: BO/DE/CR del dashboard siguen
  calculados por `FinancialStateService.watchBo/De/Cr` con el patrón
  cacheado, independientes del reports service.

## Cambios de datos

No aplica (sólo lectura).

## Cambios de API

No aplica (app local sin red).

## Cambios de integraciones

No aplica.

## Cambios de UI

- `ReportsScreen` pasa de 3 tabs a 4 tabs. El TabBar ya es scrollable
  desde el sprint anterior.
- El nuevo tab tiene un `DateFieldOutlined` en el header (mismo patrón
  que `Custom` de los otros tabs, pero único en vez de par).

## Cambios de permisos

No aplica (single-user local).

## Riesgos técnicos

- **R-T01** (bajo): bump de `DefaultTabController.length: 3 → 4`. Los
  3 sprints anteriores (1→2, 2→3) no rompieron tests; estimar lo
  mismo.
- **R-T02** (bajo): la query de 3 totales (BO/DE/CR) clona el patrón
  de 3 SQLs separados. Alternativa: query compuesta con `UNION` o
  subselects. Decisión: 3 queries separadas para mantener legibilidad
  y coherencia con `FinancialStateService`. Si en uso real degrada,
  refactor.
- **R-T03** (bajo): la lista de cuentas requiere otra query con
  subselect por cuenta. 4 queries SQL en total por reporte. Para BD
  chica de Diego (<10 cuentas) no aplica. Si crece, refactor a query
  agregada compuesta.
- **R-T04** (bajo): el `asOf` se extiende a fin del día en Dart
  (`DateTime(asOf.year, asOf.month, asOf.day, 23, 59, 59, 999)`).
  Sin tocar timezone. Coherente con el resto del DAO.
- **R-T05** (bajo): `DateTime(now.year, now.month, 0)` es el truco
  estándar para "último día del mes anterior" (día 0 = último del
  mes previo). Validado por el built-in de Dart. Test específico de
  default en F2.

## Estrategia de pruebas

3 niveles:

1. **Tests data** (8 tests): cubren RN-B01..B08 + casos borde.
2. **Widget tests** (3 tests): render con datos, empty state, tap en
   field abre picker.
3. **Smoke manual** (post-APK): especialmente coincidencia con
   dashboard a fecha = hoy.

Ver `test-plan.md` para detalle.

## Estrategia de rollback

- **Sin migración** → rollback trivial: revert del commit.
- Si el tab causa bugs, hot-fix puede revertir `length: 4 → 3` y
  comentar el `BalanceAtDateTab` en `TabBarView`.
- No hay state persistente nuevo.

## Orden sugerido de implementación

Fases en serie:

- **F0** (T001): baseline 266 verdes.
- **F1** (T002-T006): modelos + 4 helpers SQL + servicio + builder.
- **F2** (T007-T014): 8 tests data.
- **F3** (T015-T020): UI del tab (esqueleto + date picker + 3 cards +
  lista + empty state).
- **F4** (T021-T022): `ReportsScreen` 3→4 + verificar tests.
- **F5** (T023-T025): 3 widget tests.
- **F6** (T026-T029): release + APK + docs.

## Casos borde que condicionan la solución

Además de los listados en spec.md (CB-1 a CB-10):

- **CB-T01** (`occurred_at` exactamente igual al fin del día de
  `asOf`): cuenta. RN-B04 inclusivo.
- **CB-T02** (entry con `occurred_at` en el futuro de hoy): aceptado
  por el tab si Diego sembró entries futuros (raros pero posibles
  para test). No cuenta hasta que `asOf` los cubra. Sin lógica
  especial.
- **CB-T03** (cuenta archivada con `accounts.deleted_at != NULL`): NO
  aparece (RN-B05).
- **CB-T04** (categoría archivada): no aplica — el tab no desglosa por
  categoría.
- **CB-T05** (cambio de `asOf` mientras hay stream activo): el state
  recrea `_reportStream` → drift cancela el anterior limpio.

## Preguntas o supuestos que siguen afectando la implementación

Sin preguntas abiertas. P-001 (default fin del mes anterior) y P-002
(totales + lista) respondidas y reflejadas en spec.md.

Supuestos del plan vale dejar trazados:

- `BalanceAtDateTab` clona patrón de `CashflowTab` (header + date
  picker + StreamBuilder + estados). Si patrón cambia en otro sprint,
  sincronización manual.
- 4 queries SQL separadas por reporte. Si el patrón crece más allá de
  este sprint, considerar compuesta.
- Implementación serial sin worktrees ni subagentes.
