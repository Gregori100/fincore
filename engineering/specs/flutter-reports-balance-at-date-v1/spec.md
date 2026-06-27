# Saldo a fecha — cuarto tab del `/reports`

## Resumen

Agregar el tab **"Saldo a fecha"** a `/reports`, completando el set
de 4 tabs analíticos (categorías + cashflow + outliers + saldo
histórico). El tab permite consultar **BO, DE, CR a una fecha pasada
arbitraria** via replay del journal hasta ese día inclusive. Útil
para **reconciliar contra estados de cuenta del banco a fecha de
corte**. Date picker single (no rango). Reusa la infraestructura de
`ReportsService`.

## Problema a resolver

Hoy Diego ve BO/DE/CR **al momento actual** en el dashboard. Cuando le
llega el estado de cuenta del banco con fecha de corte del 15 de cada
mes, NO tiene forma de ver qué saldo tenía en esa fecha exacta para
reconciliar contra el corte. Tiene que recordar movimientos manualmente
o asumir que el saldo de hoy − movimientos del rango da el saldo del
corte (cálculo mental propenso a errores).

El uso clave es **auditoría temporal**: ver el estado financiero a una
fecha puntual del pasado.

## Objetivo

Que Diego pueda abrir `/reports` → tab "Saldo a fecha" → seleccionar
una fecha pasada con el date picker → ver:
- BO a esa fecha (cuentas líquidas).
- DE a esa fecha (deudas).
- CR a esa fecha (crédito disponible).
- Lista de cuentas con su saldo individual a esa fecha (decisión
  P-002).

Sin abrir Excel, sin sumar a mano, sin asumir cosas.

## Alcance

- Nuevo tab "Saldo a fecha" en `/reports` (TabBar 3 → 4 tabs).
- Nuevo widget `BalanceAtDateTab` en
  `lib/screens/reports/balance_at_date_tab.dart`.
- Nuevos métodos en `ReportsService`:
  - `balanceAtDate({DateTime asOf})` retorna `Stream<BalanceAtDateReport>`.
- Nuevos modelos `BalanceAtDateReport` y `AccountBalanceAtDate`
  (inmutables).
- Date picker single en el header del tab.
- 3 cards con BO, DE, CR a la fecha (estilo dashboard).
- Lista de cuentas con tipo + nombre + saldo individual a la fecha
  (decisión P-002).
- Empty state si BD vacía (sin cuentas activas).
- Reactividad via `customSelect.watch()` (cambios en journal_entries
  re-emiten el reporte).
- Tests data + widget tests.

## Fuera de alcance

- Comparativo "saldo a fecha X vs fecha Y" (delta).
- Gráfico de saldo a lo largo del tiempo (sería F5b sprint dedicado).
- Replay con hora del día — el corte es siempre a fin del día (23:59:59).
- Saldo proyectado a fecha futura (forecast).
- Filtro por cuenta específica.
- Export del estado a CSV/PDF.
- Tap en cuenta para drill-down a movimientos hasta la fecha.
- Fidelidad histórica de cuentas archivadas posteriormente (RN-B05
  documenta el comportamiento simplificado).

## Reglas de negocio

- **RN-B01**: `BO a fecha` = `Σ saldo(cash + debit activos)` con
  entries `occurred_at <= asOf` y `deleted_at IS NULL`. Misma fórmula
  que `watchBo()` pero con filtro temporal extra.
- **RN-B02**: `DE a fecha` = `Σ deuda(credit activos)` con entries
  `occurred_at <= asOf` y `deleted_at IS NULL`. Misma fórmula que
  `watchDe()`.
- **RN-B03**: `CR a fecha` = `Σ (credit_limit − deuda(credit activos
  con credit_limit set))` con entries `occurred_at <= asOf` y
  `deleted_at IS NULL`. Misma fórmula que `watchCr()`.
- **RN-B04**: `asOf` es **inclusivo al final del día** (23:59:59.999)
  para que entries ocurridos cualquier hora del día seleccionado entren
  al replay. Coherente con la convención de rango temporal del resto
  del DAO.
- **RN-B05**: Solo cuentas **activas HOY** (`accounts.deleted_at IS
  NULL`). Si una cuenta fue archivada después de `asOf` pero antes de
  hoy, **NO aparece**. Simplificación intencional: los entries de esa
  cuenta se cancelaron al archive (DAO) y ya no cuentan en SUM. Sprint
  dedicado si Diego pide fidelidad histórica.
- **RN-B06**: `asOf` máximo permitido = **hoy**. No tiene sentido
  consultar saldo a fecha futura (sería igual a hoy si no hay
  movimientos futuros sembrados). DatePicker con `lastDate = DateTime.now()`.
- **RN-B07**: `asOf` mínimo = `2020-01-01` (coherente con
  `dateRangeForPreset` y date pickers del proyecto).
- **RN-B08**: la lista de cuentas se ordena por **tipo** primero
  (cash → debit → credit) y luego **alfabéticamente por nombre**.
  Coherente con el orden del dashboard.

## Requisitos funcionales

- **RF-001**: `ReportsService.balanceAtDate({DateTime asOf})` retorna
  `Stream<BalanceAtDateReport>` reactivo a cambios en `journal_entries`.
- **RF-002**: `BalanceAtDateReport` contiene: `asOf`, `bo` (double),
  `de` (double), `cr` (double), `accounts` (List<AccountBalanceAtDate>).
- **RF-003**: `AccountBalanceAtDate` contiene: `id`, `name`, `type`
  (string), `creditLimit` (double opcional para credit), `balance`
  (double a la fecha). Para credit, balance es la deuda.
- **RF-004**: la query SQL clona el patrón de `watchBo`/`watchDe`/
  `watchCr` agregando `AND occurred_at <= ?` a las subqueries de SUM.
  La fecha extendida a fin del día se calcula en Dart antes de pasar
  al SQL (RN-B04).
- **RF-005**: query separada (o subselect) para la lista de cuentas
  con su balance individual a fecha. Sin desglosar por categoría —
  solo el saldo agregado por cuenta.
- **RF-006**: `BalanceAtDateTab` widget. Header con `DateFieldOutlined`
  para `asOf`. Body con 3 cards (BO verde, DE rojo, CR azul) + lista
  de cuentas debajo.
- **RF-007**: tap en el field de fecha abre un `showDatePicker` con
  `firstDate: DateTime(2020, 1, 1)`, `lastDate: DateTime.now()`,
  `initialDate: _asOf`. Default `_asOf = DateTime(now.year, now.month,
  0)` (último día del mes anterior — decisión P-001). El día 0 de un
  mes es un truco estándar de Dart/JavaScript que retorna el último
  día del mes previo.
- **RF-008**: cada card muestra label (BO / DE / CR), monto formateado
  con `formatAmount`, color del valor (verde positive, rojo negative
  para DE, azul accent para CR).
- **RF-009**: cada row de cuenta muestra nombre + label de tipo
  (Efectivo / Débito / Crédito) + monto.
- **RF-010**: empty state si la BD no tiene cuentas activas:
  "No hay cuentas activas." (improbable si hay Bolsa, pero
  defensivo).
- **RF-011**: `ReportsScreen` actualizado a `TabBar` con 4 tabs.
  `DefaultTabController(length: 4)`. `initialIndex = 0`. `isScrollable:
  true` ya está.
- **RF-012**: estados loading / error igual que los otros tabs.

## Casos principales

- **CP-1 — Reconcilar contra estado de cuenta**: tap "Saldo a fecha" →
  picker → seleccionar fecha de corte (ej. 15 del mes pasado) → ver
  saldo de cuentas a esa fecha. Comparar contra el papel del banco.
- **CP-2 — Auditoría general**: ver el saldo a fin del año anterior
  para registro contable.
- **CP-3 — Reactividad**: registrar entry nuevo desde otra pantalla →
  el reporte refresca si la fecha del entry está dentro del replay.
- **CP-4 — Cambio de fecha**: tap field → seleccionar otra fecha →
  reporte recalcula.
- **CP-5 — Cuenta sin movimientos hasta la fecha**: aparece en la
  lista con balance = 0.

## Casos borde

- **CB-1 — Fecha = hoy**: el reporte muestra el mismo saldo que el
  dashboard. Coherencia esperada.
- **CB-2 — Fecha muy antigua (ej. 2020-01-01)**: si la BD se sembró
  desde cero hoy, BO=0, DE=0, CR=0 + lista de cuentas todas en 0.
- **CB-3 — Entry registrado HOY con `occurred_at` ayer**: SÍ cuenta
  para saldo a ayer (RN-B04 inclusivo en el día).
- **CB-4 — Entry registrado AYER con `occurred_at` HOY**: NO cuenta
  para saldo a ayer.
- **CB-5 — Soft-deleted entry**: NO cuenta (RN-B01..B03 incluyen
  `deleted_at IS NULL`).
- **CB-6 — Cuenta credit con `credit_limit = null`**: NO contribuye a
  CR pero sí a DE. Lista la muestra con balance (deuda).
- **CB-7 — Cuenta archivada DESPUÉS de `asOf`**: NO aparece (RN-B05).
  Sus entries históricos fueron cancelados al archive — quedan en BD
  con `deleted_at != NULL` y no entran al SUM (RN-B01..B03).
- **CB-8 — `asOf` futuro**: bloqueado por el DatePicker (`lastDate =
  now`). Imposible.
- **CB-9 — Concurrencia**: cancelar entry desde otra pantalla con el
  tab visible → el reporte re-emite y los saldos refrescan (drift
  reactivo).
- **CB-10 — Cambio de zona horaria del cel**: `DateTime.now()` da el
  local del dispositivo. El comportamiento es coherente con el resto
  de la app (no normaliza a UTC).

## Criterios de aceptacion

- Tap "Reportes" desde dashboard → TabBar con **4 tabs visibles**.
- Tap tab "Saldo a fecha" → ver field de fecha con default + 3 cards
  con BO/DE/CR + lista de cuentas con sus saldos individuales.
- Tap en el field de fecha abre date picker con `lastDate = hoy`.
- Cambio de fecha refresca el reporte.
- Fecha = hoy: BO/DE/CR coinciden con el dashboard.
- Registrar entry con `occurred_at` dentro del replay desde otra
  pantalla → el reporte refresca.
- BD vacía (sin Bolsa siquiera) → empty state.
- `flutter test` sigue verde tras los tests data + widget tests
  nuevos.

## Criterios medibles de exito

- **CM-01**: 8+ tests data de `balanceAtDate`:
  - 1 test empty (BD sin cuentas).
  - 1 test fecha = hoy coincide con `watchBo/De/Cr` actuales.
  - 1 test fecha pasada filtra entries posteriores.
  - 1 test entries del día exacto cuentan (RN-B04 inclusivo final
    día).
  - 1 test soft-deleted excluido.
  - 1 test cuenta credit sin credit_limit contribuye a DE pero no a
    CR.
  - 1 test lista de cuentas ordenada por tipo + nombre.
  - 1 test cuenta sin movimientos hasta la fecha aparece con balance
    = 0.
- **CM-02**: 3+ widget tests del `BalanceAtDateTab`:
  - render con datos.
  - empty state.
  - tap en field abre picker (smoke).
- **CM-03**: 0 errores `flutter analyze`.
- **CM-04**: APK release `0.9.0+61` validado por `verify-apk.sh`.

## Riesgos

- **R-01** (medio): `ReportsScreen.length: 3 → 4` puede romper tests
  del `reports_screen_test.dart` si alguno asume length=3. El sprint
  anterior validó que el bump 2→3 no rompió nada (con `isScrollable:
  true`); estimar lo mismo.
- **R-02** (bajo): la query SQL es similar a `watchBo/De/Cr`. Las
  3 cards requieren 3 queries separadas (o una compuesta). Decisión:
  query compuesta con `UNION ALL` o subqueries para minimizar viajes
  a BD. Si el patrón crece, considerar refactor.
- **R-03** (bajo): la lista de cuentas con balance individual requiere
  query separada con GROUP BY o subselect por cuenta. Performance OK
  para Diego (< 10 cuentas).
- **R-04** (bajo): el `asOf` se compara con `occurred_at`. Si hay
  entries con `occurred_at` en el futuro (raro pero posible para
  recurring sembradas adelantadas), el saldo "a hoy" puede no incluir
  movimientos futuros. Aceptable — coherente con el dashboard.

## Supuestos

- **`asOf` inclusivo al final del día**: 23:59:59.999. Coherente con
  rangos del DAO.
- **Solo cuentas activas hoy** (RN-B05). Simplificación documentada.
- **Lista de cuentas siempre presente** (no opcional). Decisión P-002.
- **Default `asOf` = fin del mes anterior** (decisión P-001). Apunta
  al uso productivo del tab (reconciliación bancaria).
- **Lista de cuentas con saldo individual** (decisión P-002, opción
  B). Es el valor diferencial del tab vs el dashboard.
- **Sin gráfico temporal** ni delta entre fechas — alcance ajustado.
- **Sin drill-down** desde una cuenta a sus movimientos hasta la fecha.
  Sprint dedicado si Diego pide.
- **TabBar con `isScrollable: true`** ya activo del sprint anterior
  (4 labels caben con scroll).

## Impacto esperado

- **Producto**: cierra el set analítico esperado de `/reports` (4
  tabs). Reconciliación contra estados de cuenta sin cálculo mental.
- **Código**: `reports.dart` crece ~120 líneas. `reports_screen.dart`
  +6 líneas. Nuevo `balance_at_date_tab.dart` ~250 líneas.
- **Tests**: +8 data + 3 widget = ~277 verdes post.
- **APK size**: cero impacto.
- **Sin migración** de BD.
- **Sin regresión** esperada en los otros 3 tabs.
