# Tasks — flutter-reports-balance-at-date-v1

## F0 — Validación pre-sprint

- [ ] T001 Validación de calidad: confirmar baseline.
  RF: —
  Depende de: ninguna
  Paralelizable: no
  Criterio de terminado: `flutter test` → 266/266 verdes,
  `flutter analyze` → 0 errores, working tree limpio.

## F1 — Modelos + servicio (data)

- [ ] T002 Backend: definir modelos `BalanceAtDateReport` y
  `AccountBalanceAtDate` en `mobile/lib/data/reports.dart`.
  RF: RF-002, RF-003
  Depende de: T001
  Paralelizable: no
  Criterio de terminado:
  - `BalanceAtDateReport({asOf, bo, de, cr, accounts})` con getter
    `isEmpty` (true si `accounts.isEmpty`).
  - `AccountBalanceAtDate({id, name, type, creditLimit, balance})`.

- [ ] T003 Backend: helper privado `_endOfDay(DateTime asOf)` que
  retorna `DateTime(asOf.year, asOf.month, asOf.day, 23, 59, 59, 999)`.
  RF: RN-B04
  Depende de: T002
  Paralelizable: si (con T004)
  Criterio de terminado: función pura testeable.

- [ ] T004 Backend: implementar `ReportsService.balanceAtDate(asOf)`
  que retorna `Stream<BalanceAtDateReport>` ejecutando 4 queries SQL
  (3 totales BO/DE/CR + 1 lista de cuentas) combinadas con
  `Stream.combineLatest` o equivalente.
  RF: RF-001, RF-004, RF-005
  Depende de: T002, T003
  Paralelizable: no
  Criterio de terminado: el método retorna stream reactivo que
  combina las 4 queries. Cada query usa
  `customSelect(...).readsFrom: {accounts, journalEntries}.watch()`.

- [ ] T005 Backend: SQL de las 3 queries de totales clonado del
  `FinancialStateService` con `AND occurred_at <= ?` agregado a cada
  subquery de SUM.
  RF: RN-B01, RN-B02, RN-B03
  Depende de: T004
  Paralelizable: no
  Criterio de terminado:
  - BO clona `watchBo` agregando `AND occurred_at <= ?` a las dos
    subqueries.
  - DE clona `watchDe` idem.
  - CR clona `watchCr` idem.

- [ ] T006 Backend: SQL de la lista de cuentas con saldo individual a
  fecha. Ordenamiento `CASE WHEN type = 'cash' THEN 1 WHEN type =
  'debit' THEN 2 WHEN type = 'credit' THEN 3 END ASC, name ASC`.
  RF: RF-005, RN-B08
  Depende de: T004
  Paralelizable: no
  Criterio de terminado: query retorna filas con id, name, type,
  credit_limit, balance computed según el tipo. Para cash/debit:
  `(SUM destination) - (SUM origin)`. Para credit: `(SUM origin) -
  (SUM destination)` (deuda).

## F2 — Tests del DAO

- [ ] T007 Pruebas: agregar grupos en
  `mobile/test/data/reports_test.dart`.
  RF: —
  Depende de: T006
  Paralelizable: no
  Criterio de terminado: 3 grupos esqueleto (`balanceAtDate —
  totales`, `— soft delete y archivos`, `— lista de cuentas`).

- [ ] T008 Pruebas: UT-01 BD sin entries → BO=0, DE=0, CR=0.
  RF: —
  Depende de: T007
  Paralelizable: si (T008..T014)
  Criterio de terminado: el reporte de una fecha cualquiera retorna
  los 3 totales en 0. La lista de cuentas contiene Bolsa + las
  sembradas (debit, credit) con balance=0.

- [ ] T009 Pruebas: UT-02 fecha = hoy coincide con
  `FinancialStateService.watchBo/De/Cr`.
  RF: RN-B01, RN-B02, RN-B03
  Depende de: T007
  Paralelizable: si
  Criterio de terminado: con seed estándar, los 3 totales de
  `balanceAtDate(asOf=hoy)` son `==` a los del
  `FinancialStateService.watchBo().first` etc.

- [ ] T010 Pruebas: UT-03 fecha pasada filtra entries posteriores.
  RF: RN-B01
  Depende de: T007
  Paralelizable: si
  Criterio de terminado: 2 entries sembrados, uno antes y otro
  después de `asOf`. El reporte solo cuenta el primero.

- [ ] T011 Pruebas: UT-04 fin de día inclusivo.
  RF: RN-B04
  Depende de: T007
  Paralelizable: si
  Criterio de terminado: entry con `occurred_at = asOf 23:59:59`
  cuenta. Entry con `asOf 00:00:00` del día siguiente NO cuenta.

- [ ] T012 Pruebas: UT-05 soft-deleted excluido.
  RF: —
  Depende de: T007
  Paralelizable: si
  Criterio de terminado: registrar + cancel un entry → no cuenta en
  el reporte.

- [ ] T013 Pruebas: UT-06 credit_limit null/0.
  RF: RN-B03
  Depende de: T007
  Paralelizable: si
  Criterio de terminado: cuenta credit sin `credit_limit` no
  contribuye a CR pero sí a DE. Cuenta con `credit_limit = 0`
  contribuye a CR con 0.

- [ ] T014 Pruebas: UT-07 orden de la lista + UT-08 cuenta sin
  movimientos balance=0.
  RF: RN-B08
  Depende de: T007
  Paralelizable: si
  Criterio de terminado: lista ordenada por tipo + alfabético.
  Cuentas sin movimientos hasta `asOf` aparecen con balance=0.

## F3 — UI del tab nuevo

- [ ] T015 Frontend: crear esqueleto de `BalanceAtDateTab` en
  `mobile/lib/screens/reports/balance_at_date_tab.dart`. State `_asOf
  = DateTime(now.year, now.month, 0)` (fin del mes anterior),
  `_reportStream`.
  RF: RF-006
  Depende de: T006
  Paralelizable: no
  Criterio de terminado: archivo compila + `flutter analyze` 0
  errores. Renderiza Scaffold con `Text('TODO')`.

- [ ] T016 Frontend: agregar `DateFieldOutlined` para `_asOf` en el
  header. `showDatePicker` con `firstDate: 2020-01-01`, `lastDate:
  DateTime.now()`.
  RF: RF-007
  Depende de: T015
  Paralelizable: si (con T017, T018)
  Criterio de terminado: tap en field abre picker. Selección refresca
  el reporte vía `setState + _buildStream`.

- [ ] T017 Frontend: implementar `_BalanceCards` con 3 cards (BO
  verde, DE rojo, CR azul).
  RF: RF-008
  Depende de: T015
  Paralelizable: si
  Criterio de terminado: widget privado en `Row` con 3
  `_BalanceCard({label, amount, color})`. Cada card formatea con
  `formatAmount`.

- [ ] T018 Frontend: implementar `_AccountsList` que renderea cada
  cuenta con nombre + tipo label + monto.
  RF: RF-009
  Depende de: T015
  Paralelizable: si
  Criterio de terminado: `Column` con `_AccountRow` por cada
  `AccountBalanceAtDate`. Cada row con label de tipo (Efectivo /
  Débito / Crédito) y monto con signo apropiado (deuda en rojo).

- [ ] T019 Frontend: integrar `StreamBuilder<BalanceAtDateReport>`
  con loading/error/empty states.
  RF: RF-010, RF-012
  Depende de: T016, T017, T018
  Paralelizable: no
  Criterio de terminado: states clonados del cashflow tab. Empty
  state visible cuando `report.accounts.isEmpty`.

- [ ] T020 Frontend: ajuste fino del layout (spacing, padding,
  responsive).
  RF: RF-006
  Depende de: T019
  Paralelizable: no
  Criterio de terminado: `flutter run -d linux` muestra el tab bien
  visualmente. Cards no se enciman en cel chico.

## F4 — Integración al ReportsScreen

- [ ] T021 Frontend: bumpear `DefaultTabController.length: 3 → 4` +
  agregar `Tab(text: 'Saldo a fecha')` + `BalanceAtDateTab()` en
  TabBarView.
  RF: RF-011
  Depende de: T020
  Paralelizable: no
  Criterio de terminado: `mobile/lib/screens/reports_screen.dart`
  muestra 4 tabs. `isScrollable: true` ya activo.

- [ ] T022 Pruebas: validar que
  `mobile/test/screens/reports_screen_test.dart` sigue verde tras el
  bump.
  RF: —
  Depende de: T021
  Paralelizable: no
  Criterio de terminado: 5/5 tests verdes sin modificación esperada.

## F5 — Widget tests del tab nuevo

- [ ] T023 Pruebas: crear
  `mobile/test/screens/balance_at_date_tab_test.dart` con setUp del
  harness + helper que navega a `/reports` y tappea el 4to tab.
  RF: —
  Depende de: T021
  Paralelizable: no
  Criterio de terminado: archivo con setUp + 1 test smoke "el tab
  monta sin error".

- [ ] T024 Pruebas: WT-01 — render con datos. Sembrar 1 entry y
  validar render de cards + lista.
  RF: RF-008, RF-009
  Depende de: T023
  Paralelizable: si (con T025)
  Criterio de terminado: assertions sobre `findsOneWidget` de los
  labels "BO" / "DE" / "CR" + presencia de la Bolsa en la lista.

- [ ] T025 Pruebas: WT-02 empty state + WT-03 tap en field abre
  picker.
  RF: RF-010, RF-007
  Depende de: T023
  Paralelizable: si
  Criterio de terminado:
  - WT-02: BD vacía (`seedBolsa: false`) → "No hay cuentas activas."
    visible.
  - WT-03: tap en field abre date picker (`find.byType(DatePickerDialog)`
    visible).

## F6 — Release

- [ ] T026 Validación de calidad: `flutter analyze` + `flutter test`.
  RF: —
  Depende de: T014, T022, T024, T025
  Paralelizable: no
  Criterio de terminado: 0 errores en analyze (hints `info`
  tolerados). ~277 tests verdes.

- [ ] T027 Documentación: bump `pubspec.yaml` a `0.9.0+61` +
  `android/app/build.gradle.kts` (versionCode 61, versionName 0.9.0).
  Nota del cambio.
  RF: —
  Depende de: T026
  Paralelizable: si (con T028)
  Criterio de terminado: ambos archivos consistentes.

- [ ] T028 Validación de calidad: `flutter build apk --release
  --split-per-abi` + `bash scripts/verify-apk.sh`.
  RF: CM-04
  Depende de: T027
  Paralelizable: no
  Criterio de terminado: 3 APKs + verify OK con versionCode 2061 /
  versionName 0.9.0.

- [ ] T029 Documentación: crear
  `engineering/specs/flutter-reports-balance-at-date-v1/implementation/`
  con los 3 artefactos obligatorios.
  RF: —
  Depende de: T028
  Paralelizable: no
  Criterio de terminado: `implementation-review.md`,
  `resumen-ejecutivo.md`, `resumen-extenso.md` escritos.
