# Implementation Review: flutter-reports-balance-at-date-v1

## Resumen de lo implementado

Sprint cerrado. Se agregó el cuarto tab "Saldo a fecha" al `/reports`
completando el set analítico de 4 tabs. Permite consultar BO/DE/CR a
una fecha pasada arbitraria via replay del journal hasta el fin del
día (inclusivo). Lista de cuentas con saldo individual a la fecha
debajo de los totales. Date picker single con `lastDate = hoy` y
default `_asOf = fin del mes anterior` (decisión P-001 — apuntando a
reconciliación bancaria). Sin schema bump, sin deps externas, sin
cambios productivos breaking.

## Archivos principales modificados

Nuevos:

- `mobile/lib/screens/reports/balance_at_date_tab.dart` (~370 líneas).
- `mobile/test/screens/balance_at_date_tab_test.dart` (3 widget tests).

Modificados:

- `mobile/lib/data/reports.dart` (+~165 líneas: modelos
  `BalanceAtDateReport`, `AccountBalanceAtDate`, método `balanceAtDate`
  + helper `_endOfDay` + builder `_buildBalanceAtDateReport`).
- `mobile/lib/screens/reports_screen.dart` (TabBar 3 → 4 tabs).
- `mobile/test/data/reports_test.dart` (+8 tests data en 3 grupos +
  import de `FinancialStateService` para validación cruzada).
- `mobile/pubspec.yaml` (versión 0.9.0+61 + nota).
- `mobile/android/app/build.gradle.kts` (versionCode 61 / versionName
  0.9.0).

## Tareas completadas

Las 29 tareas del plan cerradas en orden con un ajuste estructural en
F1 documentado en desviaciones:

- **F0** (T001): baseline 266 verdes confirmado.
- **F1** (T002-T006): modelos + servicio + builder + helper. El plan
  pedía 4 queries SQL separadas; la implementación las consolidó en
  **1 sola query** con CASE WHEN (ver desviaciones).
- **F2** (T007-T014): 8 tests data en 3 grupos.
- **F3** (T015-T020): UI del `BalanceAtDateTab` con date picker + 3
  cards BO/DE/CR + lista de cuentas + estados.
- **F4** (T021-T022): TabBar 3 → 4. `isScrollable: true` ya activo.
  5 tests de `reports_screen_test.dart` verdes sin cambios.
- **F5** (T023-T025): 3 widget tests. Helper `openBalanceAtDateTab`
  requiere `ensureVisible` antes del tap (el 4to tab queda fuera del
  viewport inicial con TabBar scrollable).
- **F6** (T026-T029): suite 277 verde, bump 0.9.0+61, APK + verify,
  docs.

## Tareas pendientes

Ninguna del plan. Pendiente del usuario (no del sprint):

- Smoke manual SM-01..SM-06 con APK `0.9.0+61`.

## Riesgos residuales

- **R-T01 del plan** (cerrado): `reports_screen_test.dart` verde tras
  bump 3→4 sin cambios.
- **R-T02 y R-T03 del plan** (resueltos): no son riesgo — la
  consolidación en 1 sola query SQL los elimina.
- **R-T04 del plan** (cerrado): `_endOfDay` sin tocar timezone.
  Coherente con el resto del DAO.
- **R-T05 del plan** (cerrado): truco día 0 validado por UT-04 +
  smoke implícito (`DateTime(now.year, now.month, 0)` retorna último
  día del mes anterior en Dart).
- **Hallazgo del WT-03**: tap en el cuarto tab requiere `ensureVisible`
  porque `isScrollable: true` lo deja fuera del viewport inicial. Para
  futuros tabs, replicar el helper.

## Pruebas realizadas

- `flutter analyze` → 0 errores, 4 hints `info` cosméticos
  pre-existentes (no del sprint).
- `flutter test` completo → **277/277 verdes** en 22s (266 previos +
  11 nuevos).
- `flutter test test/data/reports_test.dart --name 'balanceAtDate'`
  → 8/8 verdes en 1s.
- `flutter test test/screens/balance_at_date_tab_test.dart` → 3/3
  verdes en 3s.
- `flutter test test/screens/reports_screen_test.dart` → 5/5 verdes
  sin cambios post bump.
- `flutter build apk --release --split-per-abi` → 3 APKs.
- `bash scripts/verify-apk.sh` → versionCode 2061 / versionName 0.9.0
  consistentes.

## Pruebas recomendadas

Smoke manual en cel real con APK `0.9.0+61`:

- SM-01: `/reports` → ver 4 tabs scrollables.
- SM-02: tap "Saldo a fecha" → field con fecha default (fin del mes
  anterior) + 3 cards + lista de cuentas.
- SM-03: cambiar fecha a hoy → BO/DE/CR coinciden con dashboard.
- SM-04: cambiar fecha a inicio del mes → reporte refresca.
- SM-05: registrar entry y volver → reporte refresca.
- SM-06: tap field → date picker con `lastDate = hoy`.

## Posibles regresiones

Cero detectadas en automatizado. Áreas a vigilar en smoke manual:

- **Validación cruzada dashboard vs tab**: UT-02 ya prueba que
  `balanceAtDate(asOf=hoy) == watchBo/De/Cr` con seed estándar. En
  smoke real con data del usuario, validar visualmente.
- **`/dashboard`** y otros 3 tabs sin cambios — no afectados.
- **Tab scroll**: con 4 tabs el TabBar se desliza. Verificar que el
  tab activo se mantiene visible al cambiar.

## Recomendaciones para code review humano

- Verificar la consolidación de 4 queries en 1: el SQL del
  `balanceAtDate` usa subqueries inline con CASE WHEN para calcular
  el balance por cuenta según su tipo. Drift parametriza los 4
  `endOfDay` (uno por cada subquery) con `Variable.withDateTime`.
- El truco `DateTime(now.year, now.month, 0)` es estándar de Dart
  para "día 0 del mes = último día del mes anterior". Validado con
  el smoke.
- `_endOfDay` sin tocar timezone — coherente con el resto del DAO.
  Si el usuario viaja con cambio de TZ, sin garantías especiales.
- UT-02 valida coherencia con `FinancialStateService` a fecha=hoy.
  Si en el futuro el patrón de `watchBo/De/Cr` cambia, sincronizar el
  SQL de `balanceAtDate`.
- `branch-quality-review` disponible pero NO invocado. Si Diego
  quiere revisión exhaustiva: `branch-quality-review
  flutter-reports-balance-at-date-v1`.
