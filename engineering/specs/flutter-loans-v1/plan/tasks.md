# Tareas — flutter-loans-v1

## Base de datos

- [ ] T001 Base de datos: agregar tabla `Loans` en `mobile/lib/data/database.dart` con los 13 campos declarados (id, name, principal_amount, monthly_payment, initial_duration_months, current_duration_months, payment_day, contract_date, destination_account_id FK Accounts, closed_at, close_reason, created_at, updated_at, deleted_at). Agregar 3 columnas nullable en `JournalEntries`: `loanId TEXT REFERENCES Loans #id`, `principalAmount REAL`, `interestAmount REAL`. Bump `schemaVersion` de 9 a 10. Registrar `LoansDao` en `@DriftDatabase.daos`.
  RF: RF-001
  Depende de: ninguna
  Paralelizable: no
  Criterio de terminado: tabla declarada, columnas en JournalEntries, schemaVersion=10, `flutter pub run build_runner build` corre sin errores.

- [ ] T002 Base de datos: agregar rama `from == 9 && to == 10` en `MigrationStrategy.onUpgrade` con `CREATE TABLE loans` completo + `ALTER TABLE journal_entries ADD COLUMN loan_id TEXT` + `ALTER TABLE journal_entries ADD COLUMN principal_amount REAL` + `ALTER TABLE journal_entries ADD COLUMN interest_amount REAL` + `CREATE INDEX IF NOT EXISTS idx_entries_loan ON journal_entries(loan_id) WHERE loan_id IS NOT NULL`. Preservar guardrail `UnimplementedError`. Ramas defensivas para `from ∈ {6, 7, 8} && to == 10` que combinan las migraciones intermedias del sprint anterior + este delta.
  RF: RF-001
  Depende de: T001
  Paralelizable: no
  Criterio de terminado: rama presente antes del throw, migración corre en test de integración desde v9 a v10 sin corrupción.

- [ ] T003 Base de datos: regenerar `mobile/lib/data/database.g.dart` corriendo `dart run build_runner build --delete-conflicting-outputs`.
  RF: RF-002
  Depende de: T001
  Paralelizable: no
  Criterio de terminado: `flutter analyze` sin errores en `mobile/`; clase `Loan` data class disponible.

## Backend (DAO + State + Reports)

- [ ] T004 Backend: crear archivo `mobile/lib/data/daos/loans_dao.dart` con clase `LoansDao` + `LoansDaoError` (código + mensaje). Implementar `create({name, principalAmount, monthlyPayment, initialDurationMonths, paymentDay, contractDate, destinationAccountId})` que valida cuenta destino (existe, tipo cash|debit, no archivada, no eliminada) y crea `Loan` + `income` inicial ligado (`loan_id`) en una transacción.
  RF: RF-003, RF-004
  Depende de: T003
  Paralelizable: no
  Criterio de terminado: método compila; test unitario verifica que create genera loan + income en la misma transacción con el mismo `loan_id`.

- [ ] T005 Backend: `LoansDao.updateLoan({id, name?, monthlyPayment?, currentDurationMonths?, paymentDay?, contractDate?})`. Valida existencia, rechaza cambios a `principal_amount` o `destination_account_id` con `immutable_loan_field`, valida rango de `payment_day` (1-28).
  RF: RF-005
  Depende de: T004
  Paralelizable: no
  Criterio de terminado: método compila; tests unitarios cubren campos editables y bloqueados.

- [ ] T006 Backend: `LoansDao.closeManual(id)` setea `closed_at = now, close_reason = 'manual'`. Valida que el préstamo esté abierto. `LoansDao.reopen(id)` limpia `closed_at + close_reason` sólo si `close_reason == 'manual'`; sobre `paid` lanza `cannot_reopen_paid`.
  RF: RF-006
  Depende de: T004
  Paralelizable: no
  Criterio de terminado: métodos compilan; tests cubren transiciones válidas e inválidas.

- [ ] T007 Backend: `LoansDao.deleteLoan(id, [FinancialStateService?])` cascada soft-delete en transacción: setea `deleted_at` en el `Loan`, en el `income` inicial (`loan_id == id AND kind == 'income'`) y en todos los `loan_payment` del préstamo. Invalida cache si `stateService` presente.
  RF: RF-007
  Depende de: T004
  Paralelizable: no
  Criterio de terminado: método compila; tests verifican cascada atómica y que balances se recomputen correctamente.

- [ ] T008 Backend: `LoansDao.watchActive()` (`deleted_at IS NULL AND closed_at IS NULL`) + `watchClosed()` (`deleted_at IS NULL AND closed_at IS NOT NULL`, orden `closed_at DESC`) + `findById(id)` (retorna cerrados, excluye eliminados) + `balanceOf(id)` + `watchBalance(id)` (reactivo) + `countActivePayments(id)`.
  RF: RF-003
  Depende de: T004
  Paralelizable: si
  Criterio de terminado: métodos compilan; tests verifican streams y filtros.

- [ ] T009 Backend: en `mobile/lib/data/daos/entries_dao.dart` agregar `'loan_payment'` al set `_validKinds`. Ajustar `EntryWithRelations` si es necesario para exponer los nuevos campos.
  RF: RF-008
  Depende de: T003
  Paralelizable: si
  Criterio de terminado: `_validKinds` actualizado, tests de `_validKinds` (si existen) verdes.

- [ ] T010 Backend: nuevo `EntriesDao.registerLoanPayment({loanId, accountOriginId, amount, principalAmount, interestAmount, occurredAt, description?})`. Valida: loan existe + abierto + no eliminado; cuenta origen existe + cash|debit + no archivada + no eliminada; `principal ≥ 0`, `interest ≥ 0`, `amount > 0`, `principal + interest = amount` (tolerancia `< 0.005`). Insert del entry con `loan_id`, `principal_amount`, `interest_amount`, `kind = 'loan_payment'`. En la misma transacción: si `LoansDao.balanceOf(loanId) ≤ 0` y préstamo estaba abierto, setea `closed_at = now, close_reason = 'paid'`.
  RF: RF-008
  Depende de: T004, T008, T009
  Paralelizable: no
  Criterio de terminado: método compila; tests cubren happy path + validaciones + auto-cierre paid.

- [ ] T011 Backend: nuevo `EntriesDao.deleteLoanPayment(entryId)`. Soft delete del entry. En la misma transacción: si el préstamo asociado estaba con `close_reason = 'paid'` y ahora `balanceOf > 0`, limpia `closed_at + close_reason` (reapertura auto). Los `close_reason = 'manual'` no se tocan.
  RF: RF-008
  Depende de: T010
  Paralelizable: no
  Criterio de terminado: método compila; tests cubren reapertura sobre paid y no-reapertura sobre manual.

- [ ] T012 Backend: en `EntriesDao.updateEntry`, agregar gate al inicio: si el entry cargado tiene `loan_id != null` (ya sea `income` inicial o `loan_payment`), lanzar `immutable_loan_payment` (código nuevo). Mensaje: "Este movimiento pertenece a un préstamo. Se administra desde /loans.".
  RF: RF-008
  Depende de: T004
  Paralelizable: si
  Criterio de terminado: gate presente, tests verifican rechazo sobre income de préstamo y sobre loan_payment.

- [ ] T013 Backend: en `mobile/lib/data/daos/accounts_dao.dart`, `deleteAccount(id)` gana pre-check: consultar `SELECT id FROM loans WHERE destination_account_id = ? AND deleted_at IS NULL`. Si existe ≥1, lanzar `AccountsDaoError('account_in_use_by_loan', "Esta cuenta está atada al préstamo <name>. Elimina el préstamo primero.")`. Consultar el nombre del primer préstamo para el mensaje.
  RF: RF-009
  Depende de: T004
  Paralelizable: si
  Criterio de terminado: método rechaza correctamente; tests verifican con préstamo activo + cerrado + eliminado.

- [ ] T014 Backend: `FinancialStateService.watchTotalLoans()` retorna `Stream<double>` con la suma de `balanceOf` de todos los préstamos activos (`deleted_at IS NULL AND closed_at IS NULL`). Reactivo sobre `loans` y `journal_entries`. Usar `customSelect(sql, readsFrom: {loans, journalEntries}).watchSingle()`.
  RF: RF-010
  Depende de: T008
  Paralelizable: si
  Criterio de terminado: método compila; test verifica reactividad al crear/pagar/cerrar/eliminar préstamos.

- [ ] T015 Backend: crear `mobile/lib/constants/reports_tokens.dart` con `const kLoanInterestSyntheticId = '__synthetic_loan_interest__'`. Documentar en comentario que este token identifica el renglón sintético del reporte y NO existe en `categories`.
  RF: RF-011
  Depende de: ninguna
  Paralelizable: si
  Criterio de terminado: archivo creado, exportado correctamente.

- [ ] T016 Backend: en `mobile/lib/data/reports.dart`, `ReportsService.spendingByCategory` gana post-processing: tras armar `SpendingReport` normal, ejecutar segunda query `SELECT SUM(interest_amount) FROM journal_entries WHERE kind = 'loan_payment' AND deleted_at IS NULL AND occurred_at BETWEEN ? AND ?`. Si el total > 0, agregar `CategoryTotal` con `id = kLoanInterestSyntheticId, name = 'Intereses de préstamos', colorSlug = 'orange', iconSlug = 'trending-down', total = <valor>` al final del array. Reordenar la lista completa por total DESC. Documentar en JSDoc que la fila con `kLoanInterestSyntheticId` es sintética.
  RF: RF-011
  Depende de: T015
  Paralelizable: no
  Criterio de terminado: reporte incluye/no-incluye fila según haya interés en el periodo; tests verifican comportamiento y orden.

## Frontend

- [ ] T017 Frontend: en `mobile/lib/router/app_router.dart`, agregar 6 rutas nuevas dentro del árbol:
  - `/loans` → `LoansListScreen()`
  - `/loans/new` → `LoanFormScreen(loanId: null)`
  - `/loans/:id` → `LoanDetailScreen(loanId: params.id)`
  - `/loans/:id/edit` → `LoanFormScreen(loanId: params.id)`
  - `/loans/:id/payments/new/monthly` → `LoanMonthlyPaymentForm(loanId: params.id)`
  - `/loans/:id/payments/new/capital` → `LoanCapitalPaymentForm(loanId: params.id)`
  RF: RF-012
  Depende de: ninguna
  Paralelizable: si
  Criterio de terminado: rutas resuelven sin `null` builder; navegación desde consola de dev con `context.push` funciona.

- [ ] T018 Frontend: crear `mobile/lib/screens/loans_list_screen.dart` con `SegmentedButton<LoansSegment>` (Activos | Cerrados), enum público `LoansSegment { active, closed }`, streams cacheados en `didChangeDependencies`, FAB `+` sólo en Activos, cards con nombre + saldo hero + subtítulo + estado vacío contextual. Cerrados con opacidad + badge (Pagado verde / Cerrado manual naranja). Tap navega a `/loans/:id`.
  RF: RF-013
  Depende de: T008, T017
  Paralelizable: no
  Criterio de terminado: pantalla renderiza correctamente en desktop y android; segmentado conmuta streams; navegación al detalle funciona.

- [ ] T019 Frontend: crear `mobile/lib/screens/loan_form_screen.dart` con modo create/edit. Campos: name (TextFormField), principal_amount (currency), monthly_payment (currency), initial_duration_months (int), payment_day (int con validador 1-28), contract_date (date picker), destination_account_id (AccountPicker cash|debit activas). Modo edit: `principal_amount` y `destination_account_id` con `enabled: false` + helperText "No editable · atado al ingreso inicial". Menú overflow AppBar en modo edit con acciones contextuales al estado (Activo/Manual/Paid) descritas en spec. Botón principal "Crear préstamo" o "Guardar cambios".
  RF: RF-014
  Depende de: T004-T007, T013, T017
  Paralelizable: no
  Criterio de terminado: create funciona (loan + income aparecen); edit funciona con campos deshabilitados correctos; overflow abre diálogos y dispara acciones DAO.

- [ ] T020 Frontend: crear `mobile/lib/screens/loan_detail_screen.dart` con header (nombre + saldo hero + chips) + badge de estado + lista de pagos (`loan_payment`s ordenados `occurred_at DESC`, cada renglón con fecha/total/split/cuenta) + FAB dividido (Pago del mes accent + Abono a capital outline, oculto si cerrado) + enlace "Ver ingreso inicial" que navega a `/entries/:income_id/edit` (read-only via T023) + menú overflow AppBar con `Editar contrato` + acciones del estado.
  RF: RF-015
  Depende de: T008, T017, T019
  Paralelizable: no
  Criterio de terminado: header muestra saldo actualizado en tiempo real; lista de pagos scrolleable; FAB navega a formularios correctos; enlace al income abre entry_form read-only.

- [ ] T021 Frontend: crear `mobile/lib/screens/loan_monthly_payment_form.dart` con AccountPicker (cash|debit activas), amount total con formateo currency (default = loan.monthly_payment), split editable (dos fields Capital + Intereses con validador `principal + interest = total` tolerancia `< 0.005`, helper text visible), fecha (default hoy), descripción opcional, sin CategoryPicker. Botón "Registrar pago" llama `EntriesDao.registerLoanPayment`.
  RF: RF-016
  Depende de: T010, T017
  Paralelizable: no
  Criterio de terminado: form valida split localmente, DAO acepta el pago, saldo del préstamo baja, auto-cierre paid dispara snackbar si aplica.

- [ ] T022 Frontend: crear `mobile/lib/screens/loan_capital_payment_form.dart` similar al anterior pero sin split visible (backend guarda `principal = amount, interest = 0`). Amount libre sin default. Fecha + descripción opcional. Botón "Registrar abono".
  RF: RF-017
  Depende de: T010, T017
  Paralelizable: no
  Criterio de terminado: form registra el abono, saldo baja el equivalente al amount, no aparece en spending_by_category.

- [ ] T023 Frontend: en `mobile/lib/screens/entry_form_screen.dart` agregar getter `_lockedByLoan` que detecta `entry.loan_id != null` (usar el entry cargado en `_bootstrap`). Cuando true: banner `_LoanEntryBanner` (nuevo widget privado) con acento naranja y enlace "Ver préstamo" que navega a `/loans/:loan_id`. Todo el form entra en read-only (misma técnica `AbsorbPointer + Opacity` del sprint anterior). Botón "Eliminar movimiento" deshabilitado (los pagos se eliminan desde loan_detail_screen, el income desde deleteLoan).
  RF: RF-018
  Depende de: T004, T017
  Paralelizable: no
  Criterio de terminado: al abrir /entries/:id/edit con un entry ligado a préstamo, form es read-only con banner y botón habilitado sólo para "Ver préstamo".

- [ ] T024 Frontend: en `mobile/lib/widgets/movement_row.dart`, cuando `item.entry.loanId != null` agregar chip pequeño naranja "· préstamo" al lado del subtítulo (después de cuenta/fecha/kind, antes o después según orden visual). Sin conflicto con el sufijo `(archivada)` del sprint anterior.
  RF: RF-020
  Depende de: T003
  Paralelizable: si
  Criterio de terminado: chip aparece en /entries y en Dashboard para movimientos ligados a préstamos.

- [ ] T025 Frontend: en `mobile/lib/screens/dashboard_screen.dart`:
  - Cachear en `didChangeDependencies` streams `_totalLoansStream = stateService.watchTotalLoans()` y `_activeLoansStream = loansDao.watchActive()`.
  - Agregar KPI naranja "PRÉSTAMO" en el row de KPIs (junto a BO/DE/CR), condicional (`total > 0`). Widget `_LoanKpiCard` con icon `Icons.request_quote_outlined`. Tap → `/loans`. Considerar layout Wrap si 4 KPIs no caben en cel angosto.
  - Nueva fila horizontal desplazable bajo los KPIs `_UpcomingPaymentsRow` que renderiza chips "PRÓXIMO PAGO" por préstamo activo con `daysUntil(payment_day) ≤ 5`. Copy: "BBVA · en 3 días" o "BBVA · hoy". Sin fila si no hay ninguno próximo. Tap → `/loans/:id`.
  - En AppBar, agregar `IconButton(Icons.request_quote_outlined)` → `/loans`. Ubicar junto a Categorías o dentro de un menú overflow si el layout no acomoda.
  RF: RF-019
  Depende de: T008, T014, T017
  Paralelizable: no
  Criterio de terminado: KPI aparece/desaparece según total; chips aparecen sólo con payment_day próximo; entry point navega correctamente.

- [ ] T026 Frontend: en `mobile/lib/widgets/error_snackbar.dart`, mapear los nuevos códigos de error a mensajes amigables en español: `immutable_loan_field`, `immutable_loan_payment`, `invalid_loan_split`, `invalid_loan_data`, `invalid_payment_day`, `account_in_use_by_loan`, `loan_closed`, `cannot_reopen_paid`.
  RF: cross-cutting
  Depende de: T005, T006, T010, T012, T013
  Paralelizable: si
  Criterio de terminado: `domainErrorToMessage` (o equivalente) devuelve mensaje amigable para cada código nuevo.

- [ ] T027 Frontend: en handlers de `loan_form_screen`, `loan_detail_screen` y `loans_list_screen`, wiring de diálogos:
  - `Cerrar manualmente`: `showConfirmDialog` (destructive: false) → `LoansDao.closeManual`.
  - `Reabrir`: `showConfirmDialog` (destructive: false) → `LoansDao.reopen`.
  - `Eliminar préstamo`: `showDestructiveDialog` con impacts (`countActivePayments` + income inicial + "No se puede deshacer") → `LoansDao.deleteLoan(id, deps.stateService)`.
  - `Eliminar pago individual` (desde loan_detail_screen): `showConfirmDialog` (destructive: true) con copy "Eliminar el pago del <fecha> por $X. Si el préstamo estaba pagado se reabrirá automáticamente." → `EntriesDao.deleteLoanPayment(entryId)`.
  RF: RF-021
  Depende de: T019, T020
  Paralelizable: no
  Criterio de terminado: todos los diálogos disparan la acción correcta y muestran snackbar de éxito/error.

## Backup

- [ ] T028 Backend: en `mobile/lib/data/backup.dart` cambiar `const _supportedVersion = 2`. En `exportToJson`, agregar array `loans: [...]` serializando todos los `Loan` con `deleted_at IS NULL` (activos + cerrados). Serializar los nuevos campos de `journal_entries` (`loan_id`, `principal_amount`, `interest_amount`) sólo cuando aplican (omitir si null).
  RF: RF-022
  Depende de: T008
  Paralelizable: no
  Criterio de terminado: export produce JSON v2 válido; test round-trip verifica bit a bit.

- [ ] T029 Backend: en `mobile/lib/data/backup.dart` `importFromJson` aceptar `version ∈ {1, 2}`. Cualquier otra versión → `unsupported_version`. Para v2: leer array `loans`, insertar cada uno tras validar que `destination_account_id` existe en el array `accounts` importado (si no, `invalid_reference`). Para `journal_entries`, si trae `loan_id`, validar que existe en el array `loans` (si no, `invalid_reference`). Para v1: importar como hoy, ignorar campos nuevos (quedan null).
  RF: RF-022
  Depende de: T028
  Paralelizable: no
  Criterio de terminado: import v1 sigue funcionando; import v2 con referencias buenas funciona; import v2 con referencias rotas lanza `invalid_reference`.

## Pruebas

- [ ] T030 Pruebas: crear `test/data/loans_dao_test.dart` con grupos: `create` (loan + income atómico, cuenta destino invalidada), `updateLoan` (campos editables OK, principal_amount + destination_account_id rechazados con `immutable_loan_field`), `closeManual + reopen` (transiciones + `cannot_reopen_paid`), `deleteLoan` (cascada sobre income + pagos, cuenta destino recupera balance), `watchActive/watchClosed` (filtros correctos), `balanceOf` (recompute correcto).
  RF: RF-003, RF-004, RF-005, RF-006, RF-007
  Depende de: T004-T008
  Paralelizable: si
  Criterio de terminado: ≥ 15 tests nuevos, todos verdes.

- [ ] T031 Pruebas: crear `test/data/loan_payments_test.dart` con grupos: `registerLoanPayment` (validaciones RN-L07/RN-L08, happy path, auto-cierre paid al llegar saldo=0), `deleteLoanPayment` (reapertura auto sobre paid, NO reapertura sobre manual), `updateEntry` sobre `loan_payment` → `immutable_loan_payment`, `updateEntry` sobre income inicial → `immutable_loan_payment`.
  RF: RF-008
  Depende de: T009-T012
  Paralelizable: si
  Criterio de terminado: ≥ 10 tests nuevos, todos verdes.

- [ ] T032 Pruebas: en `test/data/invariants_test.dart` agregar tests: `AccountsDao.deleteAccount` sobre cuenta con préstamo activo → `account_in_use_by_loan`; con préstamo cerrado (no eliminado) → mismo error; con préstamo eliminado → permite delete. `registerLoanPayment` con cuenta origen archivada → `invalid_account_type`. Con cuenta origen credit → `invalid_account_type`. Cuenta destino tipo credit en `LoansDao.create` → rechazo.
  RF: RF-009, RN-L07
  Depende de: T010, T013
  Paralelizable: si
  Criterio de terminado: ≥ 5 tests nuevos, verdes.

- [ ] T033 Pruebas: en `test/data/backup_test.dart` agregar tests: round-trip export v2 → import v2 con préstamos + pagos preserva bit a bit; import de v1 sobre app v2 funciona con `loans = []`; import de v2 con `destination_account_id` inexistente → `invalid_reference`; import de v2 con `loan_id` inexistente → `invalid_reference`; import de v2 con `close_reason` inválido → `invalid_loan_data`; import de v0/v3 → `unsupported_version`.
  RF: RF-022
  Depende de: T028, T029
  Paralelizable: si
  Criterio de terminado: ≥ 6 tests nuevos, verdes.

- [ ] T034 Pruebas: en `test/data/reports_test.dart` agregar tests: `spendingByCategory` agrega fila "Intereses de préstamos" cuando hay ≥1 `loan_payment` con `interest_amount > 0` en el periodo; no aparece si `interest = 0` o si no hay pagos; total coincide con la suma esperada; orden respeta DESC por total (fila sintética se acomoda como cualquier otra).
  RF: RF-011
  Depende de: T016
  Paralelizable: si
  Criterio de terminado: ≥ 4 tests nuevos, verdes.

- [ ] T035 Pruebas: widget tests puntuales en `test/screens/`:
  - `loan_form_screen_test.dart`: crear préstamo dispara loan + income; modo edit tiene campos inmutables deshabilitados; overflow menú muestra opciones contextuales al estado.
  - `loan_detail_screen_test.dart`: renderiza saldo actualizado; lista de pagos con split visible; FAB dividido en Activo, oculto en Cerrado.
  - `dashboard_screen_test.dart` extensión: KPI naranja aparece con ≥1 préstamo activo; chips PRÓXIMO PAGO aparecen a ≤5 días.
  - `entry_form_screen_test.dart` extensión: entry con `loan_id != null` renderiza read-only con banner y enlace "Ver préstamo".
  RF: RF-013, RF-014, RF-015, RF-018, RF-019
  Depende de: T018-T025
  Paralelizable: si
  Criterio de terminado: ≥ 5 widget tests nuevos, verdes.

- [ ] T036 Pruebas: correr `flutter analyze` y `flutter test` completos en `mobile/`. Cero errores nuevos; suite completa verde con ≥ 780 tests (base 735 + ≥ 45 nuevos).
  RF: cross-cutting
  Depende de: T030-T035
  Paralelizable: no
  Criterio de terminado: ambos comandos verdes en terminal, conteo de tests como esperado.

## Documentacion

- [ ] T037 Documentacion: bump `pubspec.yaml` a `version: 0.27.0+110` y `android/app/build.gradle.kts` a `versionCode = 110`, `versionName = "0.27.0"`.
  RF: RF-023
  Depende de: T036
  Paralelizable: no
  Criterio de terminado: `scripts/verify-apk.sh` (si se corre) confirma sincronía.

## Validacion de calidad

- [ ] T038 Validacion de calidad: build APK release arm64 desde `mobile/`. `flutter build apk --release --split-per-abi --target-platform android-arm64`.
  RF: RF-023
  Depende de: T037
  Paralelizable: no
  Criterio de terminado: APK generado sin errores; tamaño esperado ~22MB; versionCode del APK == 110 (o 2110 con prefix arm64 según convención de `verify-apk.sh`).

- [ ] T039 Validacion de calidad: crear artefactos `implementation/`:
  - `engineering/specs/flutter-loans-v1/implementation/implementation-review.md`
  - `engineering/specs/flutter-loans-v1/implementation/resumen-ejecutivo.md`
  - `engineering/specs/flutter-loans-v1/implementation/resumen-extenso.md`
  RF: cross-cutting
  Depende de: T038
  Paralelizable: no
  Criterio de terminado: 3 archivos creados con las secciones obligatorias del skill spec-implementar.

- [ ] T040 Validacion de calidad: smoke manual Android según checklist de `test-plan.md` sección "Pruebas manuales o smoke tests necesarios". Diego ejecuta.
  RF: cross-cutting
  Depende de: T038
  Paralelizable: no
  Criterio de terminado: los 20 items del smoke ejecutados por Diego y confirmados; screenshots opcionales.

- [ ] T041 Validacion de calidad: invocar `branch-quality-review` sobre el sprint antes de merge (si está disponible).
  RF: cross-cutting
  Depende de: T040
  Paralelizable: no
  Criterio de terminado: reporte en `engineering/quality-review/flutter-loans-v1/`; hallazgos críticos resueltos.
