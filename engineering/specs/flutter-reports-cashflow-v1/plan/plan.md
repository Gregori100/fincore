# Plan técnico — flutter-reports-cashflow-v1

## Enfoque técnico

Estrategia incremental, sin cambios destructivos:

1. **Capa de datos** (data layer): extender `ReportsService` con un
   nuevo método `cashflowByMonth(from, to)` que reusa el patrón de
   `customSelect + watch + map` ya validado en `spendingByCategory`.
   Modelos inmutables nuevos: `CashflowReport` y `MonthCashflow`.
2. **Capa de presentación**: nuevo widget `CashflowTab` que **clona la
   estructura** del `SpendingByCategoryTab` existente (chips de
   presets + StreamBuilder + loading/error/empty states) y reemplaza
   el body de "lista de buckets" por (a) header de métricas, (b) bar
   chart pareado nativo, (c) breakdown numérico.
3. **Integración**: `ReportsScreen` cambia `DefaultTabController.length`
   de 1 a 2 y agrega el segundo `Tab` + entrada en `TabBarView`.
   Arranca en tab 0 (gasto por categoría) por compatibilidad.
4. **Tests**: nuevo grupo `cashflowByMonth — ...` en `reports_test.dart`
   (~11 tests data) + nuevo `cashflow_tab_test.dart` (~3 widget tests).
   Validar que `reports_screen_test.dart` sigue verde tras el bump a
   2 tabs.

Sin migración de schema. Sin deps externas. Sin tocar productivo del
spending tab.

## Requisitos funcionales cubiertos

- **RF-001**: `cashflowByMonth(from, to)` en F1 (servicio).
- **RF-002**: `CashflowReport` en F1 (modelo).
- **RF-003**: `MonthCashflow` en F1 (modelo).
- **RF-004**: query SQL con `strftime('%Y-%m', occurred_at)` +
  `kind IN ('income', 'expense', 'credit_expense')` en F1.
- **RF-005**: rellenar meses vacíos con un iterador en Dart en F1.
- **RF-006**: `CashflowTab` con header de presets + body en F3.
- **RF-007**: header con 3 métricas (Ingresos, Gastos, Neto) en F3.
- **RF-008**: bar chart pareado nativo en F3.
- **RF-009**: breakdown numérico debajo del chart en F3.
- **RF-010**: empty state cuando suma = 0 en F3.
- **RF-011**: `ReportsScreen` con TabBar de 2 tabs en F4.
- **RF-012**: arranca en tab 0 (default `DefaultTabController.initialIndex
  = 0`) en F4.

## Archivos o módulos probablemente afectados

Nuevos:

- `mobile/lib/screens/reports/cashflow_tab.dart` (~280 líneas estimadas).
- `mobile/test/screens/cashflow_tab_test.dart` (~150 líneas estimadas).

Modificados:

- `mobile/lib/data/reports.dart` (+~80 líneas: modelos + método +
  helper).
- `mobile/lib/screens/reports_screen.dart` (+~10 líneas: 2 tabs).
- `mobile/test/data/reports_test.dart` (+~250 líneas: grupo
  cashflowByMonth con 11 tests).
- `mobile/test/screens/reports_screen_test.dart` (probable ajuste
  por bump a 2 tabs).
- `mobile/pubspec.yaml` (bump 0.7.0+58 + nota).
- `mobile/android/app/build.gradle.kts` (versionCode 58 / versionName
  0.7.0).

No tocados intencionalmente:

- `spending_by_category_tab.dart` (sin regresión esperada).
- `entries_filters.dart`, `entries_paginated_list.dart` y resto del
  refactor del Sprint 2.

## Entidades y estados afectados

- **Lectura** sobre `journal_entries` (kind, amount, occurred_at,
  deleted_at). Sin escritura.
- **Lectura** sobre `categories` solo para join opcional — el cashflow
  NO desglosa por categoría, así que el join NO es necesario. Reusa el
  patrón "solo `journal_entries`" para minimizar el costo.
- Sin transiciones de estado. Sin invariantes nuevas.
- Sin auditoría adicional (single-user local).

## Compatibilidad con datos y procesos existentes

- **Backward compatible**: el método `spendingByCategory` no se toca.
- **TabBar de 2 tabs**: `DefaultTabController(length: 2)`. Tests
  existentes del `reports_screen_test.dart` podrían asumir length=1
  vía `find.byType(Tab)`; revisar en T023.
- **Sin migración** de schema (solo lectura).
- **Sin afecto a `/dashboard`**: BO/DE/CR siguen calculados por
  `FinancialStateService`, independientes del reports service.
- **Reactividad coherente**: `customSelect.watch(readsFrom: {journal_entries})`
  re-emite al insertar/cancelar entries desde otra pantalla; mismo
  comportamiento del spending tab.

## Cambios de datos

No aplica (sólo lectura).

## Cambios de API

No aplica (app local sin red).

## Cambios de integraciones

No aplica.

## Cambios de UI

- `ReportsScreen` pasa de 1 tab a 2 tabs en la AppBar.
- Cada tab conserva su scroll independiente vía `TabBarView`.
- Sin animaciones nuevas. Sin re-paletas. Patrones de `BaseCard`,
  `DateFieldOutlined`, `FincoreColors` reusados.

## Cambios de permisos

No aplica (single-user local).

## Riesgos técnicos

- **R-T01** (medio): rellenar meses vacíos en Dart requiere iterar mes
  a mes desde `from.year/month` hasta `to.year/month` sin saltarse
  meses por DST. Solución: usar `DateTime(year, month, 1)` simple
  sin tocar timezone.
- **R-T02** (bajo): bar chart pareado nativo con scroll horizontal
  requiere `SingleChildScrollView(horizontal)` + `ConstrainedBox` con
  ancho mínimo por columna (~40dp). Si la lógica supera 100 líneas,
  considerar mover el chart a un widget separado o evaluar dep
  externa en v2.
- **R-T03** (bajo): tests del `reports_screen_test.dart` que usen
  `find.byType(Tab).single` o asuman length=1 van a fallar. Mitigación:
  pasar a `findsNWidgets(2)` o filtrar por texto.
- **R-T04** (bajo): la query usa `strftime('%Y-%m', occurred_at)` —
  funciona en SQLite estándar y en `sqlite3_flutter_libs` actual
  (probado en otras queries del repo). Coherente con la query de
  spending.
- **R-T05** (bajo): el `Stream<CashflowReport>` se cachea en
  `_reportStream` del state — al cambiar preset, hay que recrear con
  `setState`. Mismo patrón del spending tab. Sin race conditions
  esperadas (validado por integration tests del Sprint 1).

## Estrategia de pruebas

3 niveles:

1. **Tests data** (11 tests en `reports_test.dart`): cubren todas las
   reglas de negocio RN-C01..C08 + casos borde CB-1..CB-9.
2. **Widget tests** (3 tests nuevos en `cashflow_tab_test.dart`): render
   con datos / empty state / cambio de preset.
3. **Smoke manual** (opcional, post-APK): validar bar chart en cel
   real con datos reales del usuario.

Ver `test-plan.md` para detalle exhaustivo.

## Estrategia de rollback

- **Sin migración** → rollback es trivial: revert del commit.
- Si el bar chart causa bugs visuales, hot-fix puede entregarse
  desactivando el segundo tab (revertir `length: 2` a `length: 1`
  + comentar la entrada del `TabBarView`) hasta arreglar.
- No hay state persistente nuevo (sin tabla, sin SharedPreferences).

## Orden sugerido de implementación

Fases en serie (cada una desbloquea la siguiente):

- **F0**: validación pre-sprint. `flutter test` verde + ramita limpia.
- **F1**: modelos + servicio + helper (data layer puro).
- **F2**: tests data del DAO. Define el contrato de F1.
- **F3**: UI del tab nuevo. Reusa el patrón del spending tab.
- **F4**: integración al `ReportsScreen` (TabBar de 2).
- **F5**: widget tests del tab nuevo.
- **F6**: release (analyze + test + APK + verify + smoke).

Dentro de cada fase, algunas tareas son paralelizables (ver `tasks.md`).

## Casos borde que condicionan la solución

Los siguientes condicionan decisiones del plan, además de los listados
en spec.md (CB-1 a CB-11):

- **CB-T01 (zonas horarias del cel)**: cuando el cel cambia de
  timezone durante el período, los entries guardan ISO con offset. La
  query agrupa por `%Y-%m` del valor almacenado. Si Diego viaja, los
  entries del mes pueden caer al mes anterior o siguiente. Decisión:
  vivir con el comportamiento actual (sin conversión a UTC) coherente
  con el resto de la app.
- **CB-T02 (entries con `amount=0`)**: técnicamente posible si Diego
  registra un movimiento erróneo. Suman 0, no afectan el cálculo.
- **CB-T03 (cancelar entry desde otra pantalla mientras el tab está
  visible)**: el Stream re-emite vía drift. Esperado.
- **CB-T04 (rango con miles de entries por mes)**: la query es
  `GROUP BY %Y-%m` puro, O(n) lineal. Sin índice nuevo. Performance
  esperada similar al spending tab.

## Preguntas o supuestos que siguen afectando la implementación

Ninguna pregunta abierta. P-001 (default `thisMonth`) y P-002 (bar
chart pareado nativo) fueron respondidas y reflejadas en spec.md y
en los RFs.

Supuestos asumidos durante el plan que vale dejar trazados:

- Subagentes / paralelización: dado que el repo es single-user y los
  archivos involucrados son pocos, este plan asume implementación
  **serial** sin worktrees ni subagentes. Si los próximos sprints crecen
  (ej. recurring entries con schema bump), reconsiderar.
- El widget `CashflowTab` clona el patrón del spending. Si el patrón
  cambia en otro sprint, mantener sincronización manual. No se extrae
  un base widget compartido porque los bodies son lo suficientemente
  diferentes para que la abstracción salga prematura.
