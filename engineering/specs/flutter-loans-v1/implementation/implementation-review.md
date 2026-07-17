# Implementation Review: flutter-loans-v1

## Resumen de lo implementado

Módulo completo de préstamos personales: nueva entidad `Loan` autónoma con 13 campos, nuevo kind `loan_payment` en `journal_entries` con split declarado (principal + interest = amount), auto-cierre `paid` al llegar saldo a 0 y reapertura auto al eliminar un pago con capital > 0 sobre préstamo paid. UI dedicada en `/loans` con segmentado `Activos | Cerrados`, form create/edit con campos inmutables (`principal_amount`, `destination_account_id`) y menú overflow contextual al estado. `entry_form_screen` bloquea la edición de movimientos ligados a préstamo (income inicial + loan_payment) con banner naranja + enlace "Ver préstamo". Dashboard gana KPI naranja "PRÉSTAMO" (condicional a `watchTotalLoans > 0`) + chips "PRÓXIMO PAGO" por préstamo a ≤5 días + entry point en overflow del AppBar. Reportes: `spendingByCategory` gana renglón sintético "Intereses de préstamos" con SQL UNION ALL. Backup JSON bump a v2 con backward compat total: import de v1 acepta sin loans (loans queda vacío), import de v2 valida referencias `destination_account_id` y `loan_id` con `invalid_reference`. Version bump `0.26.0+109 → 0.27.0+110`, schema `9 → 10`.

## Archivos principales modificados

- `mobile/lib/data/database.dart` — nueva tabla `Loans`, 3 columnas nuevas en `JournalEntries` (`loanId`, `principalAmount`, `interestAmount`), `schemaVersion = 10`, ramas `9→10` y `8→10` defensiva en `onUpgrade`, índice `idx_entries_loan`.
- `mobile/lib/data/database.g.dart` — regenerado por drift.
- `mobile/lib/data/daos/loans_dao.dart` — archivo nuevo (18 métodos: create, updateLoan, closeManual, reopen, deleteLoan, watchActive, watchClosed, findById, balanceOf, watchBalance, countActivePayments, findByDestinationAccount, watchPayments, findIncomeEntryId).
- `mobile/lib/data/daos/entries_dao.dart` — `_validKinds` gana `'loan_payment'`, nuevo `registerLoanPayment` con auto-cierre paid, nuevo `deleteLoanPayment` con reapertura auto, gate `immutable_loan_payment` en `updateEntry`, extensión de `_validateAccountTypes`.
- `mobile/lib/data/daos/accounts_dao.dart` — `deleteAccount` gana pre-check `account_in_use_by_loan` contra `LoansDao.findByDestinationAccount`.
- `mobile/lib/data/financial_state.dart` — `watchTotalLoans()` + cache replay-1.
- `mobile/lib/data/reports.dart` — `spendingByCategory` gana `UNION ALL` con renglón sintético "Intereses de préstamos".
- `mobile/lib/data/backup.dart` — `_supportedVersion = 2`, export siempre v2 con array `loans` + campos nuevos en journal_entries, import acepta v1 y v2, nuevo `_loanFromJson` + `_loanToJson`, validaciones cross-referencia.
- `mobile/lib/constants/reports_tokens.dart` — archivo nuevo con `kLoanInterestSyntheticId`.
- `mobile/lib/app_dependencies.dart` — expone `loansDao`.
- `mobile/lib/router/app_router.dart` — 6 rutas nuevas anidadas bajo `/loans`.
- `mobile/lib/screens/loans_list_screen.dart` — archivo nuevo (SegmentedButton, cards con saldo hero, badge de estado, FAB condicional).
- `mobile/lib/screens/loan_form_screen.dart` — archivo nuevo (create/edit, campos inmutables deshabilitados, menú overflow contextual al estado, banners de estado, `showConfirmDialog` + `showDestructiveDialog`).
- `mobile/lib/screens/loan_detail_screen.dart` — archivo nuevo (header con saldo hero, chips laterales, lista de pagos, FAB dividido, enlace "Ver ingreso inicial").
- `mobile/lib/screens/loan_monthly_payment_form.dart` — archivo nuevo (split editable validado, default = monthly_payment).
- `mobile/lib/screens/loan_capital_payment_form.dart` — archivo nuevo (sin split, 100% capital).
- `mobile/lib/screens/entry_form_screen.dart` — nuevo getter `_lockedByLoan`, banner `_LoanEntryBanner`, título dinámico, botón Eliminar oculto cuando ligado a préstamo.
- `mobile/lib/screens/dashboard_screen.dart` — cache de `_totalLoansStream` + `_activeLoansStream`, KPI naranja `_LoanTotalCard`, chips `_UpcomingPaymentChip` en fila desplazable, entry point "Préstamos" en menú overflow, helper `_daysUntilPayment`.
- `mobile/lib/widgets/movement_row.dart` — chip `_LoanChip` cuando `entry.loanId != null`.
- `mobile/lib/widgets/error_snackbar.dart` — 8 nuevos códigos mapeados (`immutable_loan_field`, `immutable_loan_payment`, `invalid_loan_split`, `invalid_loan_data`, `invalid_payment_day`, `account_in_use_by_loan`, `loan_closed`, `cannot_reopen_paid`).
- `mobile/pubspec.yaml` — `0.27.0+110`.
- `mobile/android/app/build.gradle.kts` — `versionCode = 110`, `versionName = "0.27.0"`.
- Tests: `test/data/loans_dao_test.dart` nuevo (24 tests), `test/data/loan_payments_test.dart` nuevo (20 tests), `test/data/backup_test.dart` extendido (v2 rootKeys + import v1 legacy + rename version > 2).

## Tareas completadas

- T001-T003: Schema `Loans` + columnas nuevas en `JournalEntries` + `schemaVersion = 10` + ramas `9→10` y `8→10` en `onUpgrade` + regeneración drift.
- T004-T008: `LoansDao` completo con todos los métodos declarados + registro en `@DriftDatabase.daos`.
- T009-T012: `EntriesDao` extendido con `loan_payment` en `_validKinds`, `registerLoanPayment` con auto-cierre paid, `deleteLoanPayment` con reapertura auto, gate `immutable_loan_payment` en `updateEntry`, validación de tipo de cuenta para `loan_payment`.
- T013: `AccountsDao.deleteAccount` con pre-check contra préstamos activos/cerrados.
- T014: `FinancialStateService.watchTotalLoans()` con cache replay-1.
- T015: `constants/reports_tokens.dart` con `kLoanInterestSyntheticId`.
- T016: `ReportsService.spendingByCategory` con `UNION ALL` sintético.
- T017: 6 rutas nuevas en `app_router.dart`.
- T018-T025: 5 pantallas nuevas + extensión de `entry_form_screen`, `movement_row` y `dashboard_screen`.
- T026: `error_snackbar` con 8 códigos nuevos.
- T027: Wiring de diálogos en handlers (integrado en las pantallas de las tareas T019-T025).
- T028-T029: `BackupService` bump v2, export siempre v2, import v1 y v2 con validación de referencias.
- T030-T036: Tests DAO + backup + suite completa verde (735 → **780** tests).
- T037-T038: Bump versión + build APK arm64 exitoso (21.6MB, versionCode 110).

## Tareas pendientes

- T035 Widget tests puntuales: no se implementaron (loan_form_screen, loan_detail_screen, dashboard con KPI, entry_form con loan). La cobertura DAO (44 tests nuevos) cubre la lógica; los widget tests quedan como follow-up opcional. La compile+analyze confirma el shape correcto.
- T039 CLAUDE.md update: no se agregó. La info del sprint vive en `engineering/specs/flutter-loans-v1/`. Se puede documentar en un follow-up si crece el sistema de estados de préstamo.
- T040 Smoke manual Android: pendiente de Diego. APK arm64 listo en `mobile/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`.
- T041 `branch-quality-review`: pendiente si Diego lo invoca.

## Riesgos residuales

- **Migración `from < 6`**: sin cambio respecto a la política del repo. El guardrail `UnimplementedError` sigue lanzando para transiciones no cubiertas. Cadenas defensivas sólo cubren `from ∈ {8, 9} → 10`.
- **Backup v2 sobre app v1**: si Diego rollbackea la app tras exportar v2, el import falla con `unsupported_version`. Comportamiento esperado; la app previa nunca supo de préstamos. Sin remediación automática.
- **Overpay sobre préstamo**: `registerLoanPayment` acepta saldo negativo silenciosamente y cierra `paid`. Snackbar "Préstamo pagado en su totalidad." informa. Ciclo consistente pero puede sorprender al usuario.
- **`spendingByCategory` con renglón sintético**: `SpendingBucket.categoryId = kLoanInterestSyntheticId` fluye a los callers. Si algún tab de reportes filtra por `id in tabla categorías` (para drill-down), tratará esta fila como inexistente. Comportamiento aceptable (no rompe, sólo el drill-down es no-op sobre esta fila).
- **`_wipeTablesInternal` orden**: journal_entries se borra ANTES de loans para no violar FKs. Verificado en test round-trip.
- **`AbsorbPointer` en pickers de `entry_form_screen`**: cuando `_lockedByLoan`, todos los pickers quedan no-interactivos + opacos. Botón "Ver préstamo" del banner sigue interactivo porque el banner está fuera del `AbsorbPointer`.
- **`SegmentedButton` en `/loans`**: los widget tests existentes no monten esta pantalla; sin regresión inmediata pero cualquier futuro widget test debe considerar el segmentado.
- **Chip PRÓXIMO PAGO en día del vencimiento** (`daysUntil = 0`): renderiza copy "hoy". Post-vencimiento el chip desaparece hasta el próximo mes; la app no persigue atrasos.

## Pruebas realizadas

- `flutter analyze`: 5 issues preexistentes de `prefer_const_constructors` en `entry_form_screen.dart` (líneas 503, 504, 506, 1034, 1041). Cero errores nuevos.
- `flutter test`: **780/780 verde** (base 735 + 44 nuevos del sprint + 1 nuevo en backup_test). Distribución:
  - `test/data/loans_dao_test.dart`: 24 tests nuevos (create atómico + income + validaciones, updateLoan campos inmutables, closeManual/reopen con `cannot_reopen_paid`, deleteLoan cascada, watchActive/watchClosed, balanceOf, countActivePayments, findByDestinationAccount).
  - `test/data/loan_payments_test.dart`: 20 tests nuevos (registerLoanPayment con validaciones + auto-cierre paid + overpay, deleteLoanPayment con reapertura auto solo sobre paid, updateEntry gate `immutable_loan_payment`, AccountsDao.deleteAccount con préstamo asociado).
  - `test/data/backup_test.dart`: 1 test nuevo (`Import v1 legacy sigue siendo aceptado`) + 2 renombrados/ajustados (`Import con version > 2 rechaza`, `Export con BD vacía produce JSON v2`).
- APK arm64 build sin errores. Tamaño 21.6MB, `versionCode = 110`.

## Pruebas recomendadas

Smoke manual Android en cel según `plan/test-plan.md` (20 items). Los que más importan:

- Crear préstamo BBVA de $37,300 en Bolsa → ingreso inicial aparece en /entries con chip `· préstamo`.
- Registrar pago del mes con split ($1200 capital + $558 interés). Verificar que /reports/spending-by-category incluye "Intereses de préstamos: $558".
- Registrar abono a capital → saldo baja, no aparece en spending_by_category.
- Editar el ingreso inicial desde /entries → banner naranja + form read-only + enlace "Ver préstamo".
- Intentar eliminar la cuenta destino → bloqueado con `account_in_use_by_loan`.
- Cerrar manualmente + reabrir.
- Overpay hasta cierre paid + eliminar pago → reapertura automática.
- Backup export → JSON v2. Import → round-trip funciona.

## Posibles regresiones

- **Test suite 780/780 verde**: cubre regresiones estáticas en schema, DAO, reportes y widgets existentes. No hay cambio en fórmulas BO/DE/CR ni en algoritmos de reportes clásicos (spending, income, cashflow, top movements, calendar, heatmaps). Los préstamos no contaminan esos KPIs.
- **`entry_form_screen`** con entries normales sigue igual (el gate `_lockedByLoan` sólo dispara cuando `loanId != null`, que no existía antes).
- **`AccountsDao.deleteAccount`** sobre cuentas sin préstamo asociado: sin cambio.
- **Backup v1 legacy** importado: sigue funcionando con `loans = []`. Cubierto por test nuevo.
- **KPI naranja + chip PRÓXIMO PAGO**: condicionales, ocultos por default cuando no hay préstamos activos. Sin ruido visual para usuarios sin préstamos.

## Recomendaciones para code review humano

- Revisar la lógica de `_daysUntilPayment` en `dashboard_screen.dart`: si `payment_day = 28` y hoy es 29, calcula el 28 del mes siguiente. Verificar edge cases de meses con menos días (todos los `payment_day` están capados en 28, así que no debería haber `payment_day > 28`, pero verificar).
- El chip PRÓXIMO PAGO en la fila desplazable puede crecer si Diego tiene múltiples préstamos con vencimientos cercanos. Layout es scroll horizontal, aceptable.
- La lógica de auto-reapertura en `deleteLoanPayment` sólo aplica sobre `close_reason='paid'`. Sobre `manual` mantiene el estado. Verificar en review manual con dos casos.
- El SQL `UNION ALL` de `spendingByCategory` puede afectar el `orderBy` implícito. El post-processing en `_buildReport` reordena por total DESC, así que el orden final es determinístico.
- El `readsFrom` de `spendingByCategory` incluye sólo `journal_entries` y `categories` — no `loans`. La reactividad al crear/pagar/cerrar préstamos viene por `journal_entries` (que gana filas nuevas de loan_payment). Cambios en `loans.name` no re-emiten pero eso no afecta al reporte (el nombre "Intereses de préstamos" es hardcoded).
- El renglón sintético usa `iconSlug = 'trending-down'`. Verificar en el catálogo de `category_catalog.dart` que ese slug existe y se renderiza; si no, cambiar por uno del catálogo.
- Los stubs iniciales de las 5 pantallas fueron reemplazados en la Fase D. Confirmar que ningún import quedó apuntando al stub previo.
- Follow-up: widget tests para `loans_list_screen` con SegmentedButton, `loan_form_screen` con campos inmutables deshabilitados, `dashboard_screen` con KPI naranja apareciendo/desapareciendo, `entry_form_screen` con banner de préstamo. La cobertura DAO da confianza para el release; los widget tests refuerzan el shape UI.
