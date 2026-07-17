# Plan técnico — flutter-loans-v1

## Enfoque tecnico

Cambio grande pero incremental. Se agrega una entidad nueva (`Loan`) y un kind nuevo de `journal_entries` (`loan_payment`) sin tocar la mecánica actual del ledger. El schema crece aditivamente (nueva tabla + tres columnas nullable en `journal_entries`), la migración es aditiva pura y el guardrail se preserva. Los saldos de los préstamos se derivan on-the-fly (`principal_amount − Σ loan_payment.principal_amount`), consistente con el patrón de balances derivados del `FinancialStateService`. Los pagos son `journal_entries` con FK opcional al préstamo, así se integran naturalmente en `/entries`, en reportes y en filtros existentes sin duplicar mecanismos.

Las dos transiciones automáticas (cierre `paid` al llegar saldo=0 tras un `registerLoanPayment`, reapertura auto al eliminar un pago que devuelve saldo>0 sobre un préstamo `paid`) se encapsulan dentro de las mismas transacciones de escritura para que sean atómicas. El estado `manual` (cierre forzado) sólo transiciona por acción de UI y sólo esos préstamos se pueden reabrir vía `LoansDao.reopen`.

La UI reutiliza patrones del sprint anterior (`flutter-accounts-archive-v1`): `SegmentedButton` para separar Activos de Cerrados, menú overflow contextual al estado, banners de color acento para modos read-only, `showDestructiveDialog` con chips de impacto reales. Se agregan tres pantallas nuevas (list, form, detail) más dos formularios especializados de pago.

El backup JSON bumpa a v2 preservando compatibilidad hacia atrás: `BackupService.exportToJson` siempre escribe v2, `BackupService.importFromJson` acepta v1 (loans queda vacío) y v2 (importa loans + splits). Esto sienta las bases para futuros bumps sin romper archivos históricos.

Los reportes existentes no se tocan estructuralmente. `ReportsService.spendingByCategory` gana un post-processing que agrega un renglón sintético "Intereses de préstamos" al final de la lista existente, con un token especial (`kLoanInterestSyntheticId`) que identifica esa fila como "no viene de la tabla categories". Cualquier caller que asuma "todos los renglones son categorías reales" debe ser auditado (probablemente ninguno lo hace hoy, pero se verifica en implementación).

## Requisitos funcionales cubiertos

- RF-001: T001 (nueva tabla `loans` + 3 columnas en `journal_entries` + `schemaVersion 9 → 10`), T002 (rama nueva en `MigrationStrategy.onUpgrade` para `9 → 10` con `CREATE TABLE loans` + 3 `ALTER TABLE journal_entries ADD COLUMN`). Ramas defensivas para `from ∈ {6, 7, 8} && to == 10`.
- RF-002: T003 (regenerar `database.g.dart` con build_runner).
- RF-003: T004-T011 (nuevo `LoansDao` con todos los métodos declarados en spec + tests).
- RF-004: T004 (`LoansDao.create` genera atómicamente el `income` inicial con `loan_id` en una transacción).
- RF-005: T005 (`LoansDao.updateLoan` rechaza cambios en `principal_amount` y `destination_account_id` con `immutable_loan_field`).
- RF-006: T006 (`closeManual` + `reopen`, con guard `cannot_reopen_paid`).
- RF-007: T007 (`deleteLoan` cascada sobre `income` + `loan_payment`s).
- RF-008: T012-T014 (extensión de `EntriesDao`: `registerLoanPayment`, `deleteLoanPayment`, `updateEntry` rechaza `loan_payment`, `_validKinds` gana `'loan_payment'`).
- RF-009: T015 (`AccountsDao.deleteAccount` gana pre-check contra `loans.destination_account_id` → `account_in_use_by_loan`).
- RF-010: T016 (`FinancialStateService.watchTotalLoans()`).
- RF-011: T017 (`ReportsService.spendingByCategory` gana post-processing con renglón sintético "Intereses de préstamos").
- RF-012: T018 (nuevas rutas en `app_router.dart`).
- RF-013: T019 (nueva pantalla `loans_list_screen`).
- RF-014: T020 (nueva pantalla `loan_form_screen` create/edit con campos inmutables en edit + menú overflow contextual).
- RF-015: T021 (nueva pantalla `loan_detail_screen`).
- RF-016: T022 (nueva pantalla `loan_monthly_payment_form` con split editable).
- RF-017: T023 (nueva pantalla `loan_capital_payment_form`).
- RF-018: T024 (`entry_form_screen` detecta `loan_id != null` y entra en read-only con enlace).
- RF-019: T025 (`dashboard_screen` gana KPI naranja + chip PRÓXIMO PAGO + entry point AppBar).
- RF-020: T026 (`movement_row` gana chip `· préstamo`).
- RF-021: T019-T023, T027 (`showConfirmDialog` + `showDestructiveDialog` en los handlers correspondientes).
- RF-022: T028-T029 (`BackupService` bump a v2, export siempre v2, import acepta v1 y v2 con validación de referencias).
- RF-023: T037 (bump `pubspec.yaml` a `0.27.0+110` y `build.gradle.kts` a `versionCode = 110`).

## Archivos o modulos probablemente afectados

- `mobile/lib/data/database.dart` — nueva tabla `Loans`, columnas nuevas en `JournalEntries`, `schemaVersion = 10`, ramas nuevas en `onUpgrade`, registro del nuevo DAO.
- `mobile/lib/data/database.g.dart` — regenerado por `build_runner`.
- `mobile/lib/data/daos/loans_dao.dart` — archivo nuevo.
- `mobile/lib/data/daos/entries_dao.dart` — nuevo kind, `registerLoanPayment`, `deleteLoanPayment`, `updateEntry` gate, load de columnas nuevas en lecturas.
- `mobile/lib/data/daos/accounts_dao.dart` — `deleteAccount` gana pre-check.
- `mobile/lib/data/financial_state.dart` — nuevo `watchTotalLoans`.
- `mobile/lib/data/reports.dart` — `spendingByCategory` gana post-processing sintético. Nueva estructura `SpendingReport` acepta la fila sintética (posiblemente sólo un flag en `CategoryTotal` o un renglón con `id = kLoanInterestSyntheticId`).
- `mobile/lib/data/backup.dart` — bump `_supportedVersion = 2`, export/import v2, validación de referencias `loan_id` y `destination_account_id`.
- `mobile/lib/constants/reports_tokens.dart` — probablemente archivo nuevo o extensión de `mobile/lib/constants/filter_tokens.dart` con `kLoanInterestSyntheticId`.
- `mobile/lib/app_dependencies.dart` — expone `loansDao` via `attachedDatabase.loansDao`.
- `mobile/lib/router/app_router.dart` — 6 rutas nuevas.
- `mobile/lib/screens/loans_list_screen.dart` — archivo nuevo.
- `mobile/lib/screens/loan_form_screen.dart` — archivo nuevo.
- `mobile/lib/screens/loan_detail_screen.dart` — archivo nuevo.
- `mobile/lib/screens/loan_monthly_payment_form.dart` — archivo nuevo.
- `mobile/lib/screens/loan_capital_payment_form.dart` — archivo nuevo.
- `mobile/lib/screens/entry_form_screen.dart` — detección `_lockedByLoan`, banner `_LoanEntryBanner`, enlace "Ver préstamo".
- `mobile/lib/screens/dashboard_screen.dart` — KPI naranja `_LoanKpiCard` (o extensión del row de KPIs existente), chip fila `_UpcomingPaymentsRow`, entry point AppBar.
- `mobile/lib/widgets/movement_row.dart` — chip `· préstamo` cuando `entry.loan_id != null`.
- `mobile/lib/widgets/error_snackbar.dart` — mapear nuevos códigos `immutable_loan_field`, `immutable_loan_payment`, `invalid_loan_split`, `invalid_loan_data`, `invalid_payment_day`, `account_in_use_by_loan`, `loan_closed`, `cannot_reopen_paid`.
- Tests nuevos: `test/data/loans_dao_test.dart`, `test/data/loan_payments_test.dart`, tests extra en `test/data/{invariants,backup,reports}_test.dart`, widget tests puntuales en `test/screens/`.
- `pubspec.yaml`, `android/app/build.gradle.kts` — bump.

## Entidades y estados afectados

- **`Loan`** (entidad nueva). Estados:
  - **Activo**: `deleted_at IS NULL AND closed_at IS NULL`.
  - **Cerrado (paid)**: `deleted_at IS NULL AND closed_at IS NOT NULL AND close_reason = 'paid'`. Terminal (no se reabre por acción de UI).
  - **Cerrado (manual)**: `deleted_at IS NULL AND closed_at IS NOT NULL AND close_reason = 'manual'`. Reabrible.
  - **Eliminado**: `deleted_at IS NOT NULL`. Cascada de `income` inicial + `loan_payment`s.
- Transiciones:
  - Activo → Activo (con actualizaciones): `updateLoan` (name, monthly_payment, current_duration_months, payment_day, contract_date). `principal_amount` y `destination_account_id` no cambian.
  - Activo → Paid (auto): `registerLoanPayment` que deja `balanceOf(id) ≤ 0`, dentro de la misma transacción del insert. Setea `closed_at + close_reason='paid'`.
  - Activo → Manual: `closeManual(id)` desde UI. Setea `closed_at + close_reason='manual'`.
  - Paid → Activo (auto): `deleteLoanPayment(entryId)` que deja `balanceOf(id) > 0` sobre un préstamo con `close_reason='paid'`. Limpia `closed_at + close_reason`. Sólo en esta ruta.
  - Manual → Activo: `reopen(id)` desde UI. Limpia `closed_at + close_reason`. Sólo válido para `close_reason='manual'`; sobre `paid` lanza `cannot_reopen_paid`.
  - Cualquiera → Eliminado: `deleteLoan(id)` cascada. Setea `deleted_at` en el préstamo + `income` inicial (via `loan_id`) + todos los `loan_payment`s del préstamo.
- Invariantes:
  - `principal_amount` inmutable post-create (RN-L01).
  - `destination_account_id` inmutable post-create (RN-L02).
  - `payment_day ∈ [1, 28]` (RN-L05, evita meses cortos).
  - `saldo = principal_amount − Σ(loan_payment.principal_amount con deleted_at IS NULL)` (RN-L10, derivado on-the-fly, nunca persistido).
  - Un préstamo `paid` no puede reabrirse por acción manual, sólo por la ruta auto de eliminar un pago (RN-L13).
  - La cuenta destino de un préstamo activo o cerrado (no eliminado) no puede eliminarse; puede archivarse (RN-L09).
- **`JournalEntry` ligado a préstamo** (extensión de la entidad existente):
  - **Income inicial**: `kind='income'`, `loan_id != null`, `principal_amount == null`, `interest_amount == null`, `accountDestinationId = loan.destination_account_id`, `amount = loan.principal_amount`.
  - **Loan payment**: `kind='loan_payment'`, `loan_id != null`, `principal_amount != null`, `interest_amount != null`, `accountOriginId ∈ cash|debit`, `accountDestinationId = null`, `principal_amount + interest_amount = amount`.
  - Ambos son inmutables desde `updateEntry` (RN-L15). Sólo se eliminan (income vía cascada de `deleteLoan`; loan_payment vía `deleteLoanPayment` desde loan_detail_screen).

## Compatibilidad con datos y procesos existentes

- **Migración schemaVersion 9 → 10**: aditiva pura. `CREATE TABLE loans` + `ALTER TABLE journal_entries ADD COLUMN loan_id TEXT REFERENCES loans(id)` + `ALTER TABLE journal_entries ADD COLUMN principal_amount REAL` + `ALTER TABLE journal_entries ADD COLUMN interest_amount REAL`. Cero backfill: todos los campos nuevos son NULL en filas existentes. Corre fuera de transacción usuario (limitación conocida de drift + `alterTable`) pero es idempotente por naturaleza (`CREATE TABLE IF NOT EXISTS` no aplica con `m.createTable`, así que se usa `customStatement` para consistencia con el patrón previo del repo).
- **Rama única `to == 10`**: cubre `from == 9`. Se agregan ramas defensivas para `from ∈ {6, 7, 8}` que combinan las migraciones intermedias del sprint anterior + el delta de este sprint. Cadenas para `from < 6` siguen chocando con el guardrail — no es regresión, es el estado del repo.
- **Datos históricos**: los `journal_entries` existentes quedan con `loan_id = null`, `principal_amount = null`, `interest_amount = null`. Comportamiento sin cambios: aparecen en `/entries`, contribuyen a BO/DE/CR, salen en reportes sin distinción.
- **BackupService JSON v1 → v2**:
  - Export desde este sprint escribe v2. Un backup v2 importado sobre una versión previa de la app fallaría con `unsupported_version` (comportamiento esperado; la app previa nunca supo de préstamos).
  - Import acepta v1 (compat total) y v2. Actualiza `_supportedVersion = 2` y elimina el rechazo por `version < _supportedVersion` (que hoy rechaza v0/v-1). Ahora aceptamos exactamente 1 y 2.
  - Un backup v2 se puede importar sobre una app con préstamos preexistentes; el `wipeAll` previo limpia toda la BD, así que los préstamos se reemplazan (mismo comportamiento que categorías/cuentas existentes).
- **Reportes existentes**: sin cambios estructurales. `spendingByCategory` retorna la misma lista con un renglón adicional al final si hay `interest_amount > 0` en el periodo. `cashflow`, `topMovements`, `movementsCalendar`, `income_by_category`, etc. no cambian (el `loan_payment` sale como un journal_entry normal en cashflow, no cuenta como income, y en topMovements aparece como cualquier otro con su descripción).
- **`FinancialStateService.watchBo/De/Cr`**: sin cambios. Los préstamos no contribuyen a esos KPIs. El nuevo `watchTotalLoans` es aparte.
- **`AccountsDao.deleteAccount`**: gana pre-check antes de la cascada. Los tests existentes del método siguen funcionando (no crean préstamos). El pre-check sólo aplica cuando hay ≥1 préstamo con esa cuenta como destino.
- **Widget tests existentes**: `test/screens/list_screens_test.dart`, `dashboard_screen_test.dart`, `entry_form_screen_test.dart` siguen verdes porque los cambios en dashboard son aditivos (nuevo KPI condicional que no aparece sin préstamos) y en entry_form_screen sólo agregan una detección más de `loan_id != null` que no dispara sin datos ligados.
- **Callsites de `updateEntry`**: ninguno hoy llama sobre `loan_payment` (no existe). Cuando exista, la validación nueva bloquea. Sin regresión.
- **Import v1 sobre app v2**: el user perdería préstamos si los tenía. Documentado en el copy del import (opcional, si el flujo actual ya advierte de reemplazo total, no requiere nuevo copy).

## Cambios de datos si aplica

- Tabla nueva `loans` con 13 columnas.
- Tres columnas nuevas en `journal_entries`: `loan_id`, `principal_amount`, `interest_amount` — todas nullable.
- Índice nuevo opcional: `CREATE INDEX idx_entries_loan ON journal_entries(loan_id) WHERE loan_id IS NOT NULL` — reduce el costo de `balanceOf(id)` y de las cascadas de `deleteLoan`. Aplica en `onCreate` y en `onUpgrade` de la nueva rama.
- Índice nuevo opcional: `CREATE INDEX idx_loans_active ON loans(closed_at) WHERE deleted_at IS NULL` — para `watchActive` y KPI naranja. Se puede omitir si `loans` es pequeño (esperado <10 filas en single-user).
- Cero cambios en `accounts`, `categories`, `saved_views`, `weekly_budgets`, `weekly_budget_items`, `app_preferences`.
- Backup JSON: v2 gana `loans: [...]` y campos nuevos en `journal_entries`.

## Cambios de UI si aplica

- **`loans_list_screen`** (nuevo):
  - Scaffold + AppBar con back.
  - `SegmentedButton<LoansSegment>` bajo AppBar: `Activos | Cerrados`.
  - Stream según segmento: `_activeStream = watchActive()`, `_closedStream = watchClosed()`.
  - Card por préstamo: nombre + icono naranja + saldo hero + subtítulo (monthly + payment_day) + progreso lineal opcional. Cerrados con opacidad y badge `Pagado` (verde) o `Cerrado manual` (naranja).
  - FAB `+` sólo en Activos.
  - Estado vacío: "Aún no tienes préstamos." / "No hay préstamos cerrados.".
- **`loan_form_screen`** (nuevo, create/edit):
  - Modo create: campos habilitados, botón "Crear préstamo".
  - Modo edit: `principal_amount` y `destination_account_id` deshabilitados con helper "No editable · atado al ingreso inicial". Menú overflow AppBar con acciones contextuales al estado:
    - Activo: `Cerrar manualmente`, divider, `Eliminar`.
    - Manual: `Reabrir`, divider, `Eliminar`.
    - Paid: sólo `Eliminar`. Banner superior "Préstamo pagado. Este préstamo se cerró automáticamente al llegar el saldo a cero.".
  - Campos: name, principal (currency), monthly_payment (currency), initial_duration_months (int), payment_day (int 1-28 con validador), contract_date (date picker), destination_account_id (AccountPicker cash|debit).
- **`loan_detail_screen`** (nuevo):
  - Header: nombre + saldo pendiente hero (con formato currency) + chips (monthly, payment_day, duration).
  - Badge de estado si cerrado (Pagado / Cerrado manual).
  - Lista de pagos (todos los `loan_payment` del préstamo, orden `occurred_at DESC`).
  - Cada renglón: fecha, total, split `capital $X · intereses $Y`, cuenta origen. Tap → `showConfirmDialog` con opción Eliminar (rojo).
  - Enlace "Ver ingreso inicial" en el header → `entry_form_screen` read-only.
  - FAB: dividido en "Pago del mes" (accent) + "Abono a capital" (outline). No aparece si préstamo cerrado.
  - Menú overflow AppBar con `Editar contrato` (navega a `/loans/:id/edit`) + acciones del estado (mismo bloque contextual del form).
- **`loan_monthly_payment_form`** (nuevo):
  - AccountPicker cash|debit activas.
  - Amount total con formateo (default = `loan.monthly_payment`).
  - Split: dos fields `Capital` y `Intereses`. Al cambiar el total, la app pre-llena proporcional (si el usuario ya editó el split, se conserva; si no, se pre-llena proporcional a la última proporción usada o a `monthly_payment` base — heurística menor).
  - Validador cliente: `principal + interest = total` con tolerancia `< 0.005`. Helper text visible.
  - Fecha (default hoy, editable).
  - Descripción opcional.
  - Sin CategoryPicker.
  - Botón "Registrar pago". Handler llama `EntriesDao.registerLoanPayment` en try/catch, mapea `AccountsDaoError`/`EntriesDaoError` a snackbars.
- **`loan_capital_payment_form`** (nuevo):
  - Similar al anterior pero sin split visible. `principal_amount = amount, interest_amount = 0`.
  - Amount libre (sin default).
  - Fecha + descripción opcional.
  - Botón "Registrar abono".
- **`entry_form_screen`** (extensión):
  - Nuevo getter `_lockedByLoan = _entry?.loan_id != null` (via findById que carga el entry completo).
  - Cuando true: banner naranja `_LoanEntryBanner` con enlace "Ver préstamo" que navega a `/loans/:loan_id`. Todo el form read-only (misma técnica de `AbsorbPointer + Opacity` que el sprint anterior). Botón Eliminar del footer deshabilitado.
- **`dashboard_screen`** (extensión):
  - `_LoansStream` cacheado en `didChangeDependencies` (`stateService.watchTotalLoans()` + `loansDao.watchActive()` para chips).
  - Nueva KPI naranja `_LoanKpiCard` en el row de KPIs BO/DE/CR/PRÉSTAMO. Condicional: sólo si `total > 0`. Icon `Icons.request_quote_outlined`.
  - Nueva fila horizontal desplazable bajo los KPIs con chips "PRÓXIMO PAGO" por préstamo activo con `daysUntil ≤ 5`. Copy: "BBVA · en 3 días". Tap → `/loans/:id`. Sin renderizar si no hay ninguno próximo.
  - Nuevo entry point en AppBar: icono `Icons.request_quote_outlined` → `/loans`. Puede colocarse junto a Categorías y Settings o dentro de un menú overflow si no cabe.
- **`movement_row`** (extensión):
  - Cuando `entry.loanId != null`, agrega chip pequeño naranja "· préstamo" al lado del subtítulo. No confunde con el sufijo `(archivada)` de cuentas (que va en el nombre de la cuenta, no como chip separado).

## Cambios de permisos si aplica

No aplica. App single-user.

## Riesgos tecnicos

- **Regenerar `database.g.dart` puede tomar 30-60s**. Task explícito para no olvidarlo tras cambios en `Loans` o `JournalEntries`.
- **Cascada de `deleteLoan` en transacción**: si el journal tiene muchos `loan_payment`s del préstamo, el UPDATE cascada es rápido en single-user pero conviene benchmark si aparece lag. Mitigar con índice `idx_entries_loan`.
- **`registerLoanPayment` auto-cierre `paid`**: si el usuario overpaga por accidente ($5,000 sobre $1,000 pendientes), el préstamo cierra. Se muestra snackbar "Préstamo pagado en su totalidad." como feedback claro. Si luego elimina el pago, se reabre auto — comportamiento diseñado en RN-L11/RN-L12 pero puede sorprender.
- **`deleteLoanPayment` reapertura auto**: sólo aplica sobre `close_reason='paid'`. Sobre `manual` no toca nada. Alta atención al invariante en tests (evitar reabrir cerrados manuales por error).
- **`spendingByCategory` con renglón sintético**: retorna una lista mezclada. Los callers actuales del método (probablemente `spending_by_category_tab.dart`) deben tolerar filas cuyo `id` no está en la tabla `categories`. Auditar en implementación. Alternativa: retornar un objeto con dos campos `List<CategoryTotal> real` + `double? syntheticLoanInterest`, pero eso rompe más el schema del retorno.
- **KPI naranja overflow**: cuatro KPIs (BO/DE/CR/PRÉSTAMO) en el row del Dashboard pueden no caber horizontalmente. Posible solución: layout wrap o segunda fila cuando aparece PRÉSTAMO. Decidir en implementación.
- **Chip "PRÓXIMO PAGO" fila desplazable**: si Diego tiene 5 préstamos con payment_day cercanos, la fila puede quedar larga. Aceptable como scroll horizontal. Si degrada, considerar un chip agregador ("N pagos próximos") como fallback.
- **`entry_form_screen` con detección `loan_id != null`**: hay que cargar el entry completo (incluidos los nuevos campos) para detectar. Si `_bootstrap` carga con `findById` y esa función retorna todos los campos, no requiere query extra. Verificar.
- **AccountsDao.deleteAccount pre-check**: puede romper tests existentes si algún test previo dejó una BD con `loan.destination_account_id = someAccount.id` y luego trata de eliminar `someAccount`. No hay tests así hoy (no existen loans), pero cuidar en implementación de tests nuevos.
- **Backup v2 sobre app v1**: si Diego rollbackea la app (por bug crítico) tras haber exportado v2, el import fallaría. Es aceptable como comportamiento esperado; la app previa nunca supo de préstamos. Documentar.
- **Reapertura auto sobre `paid` puede confundir**: si Diego pagó y quiere reabrir manualmente (raro, pero posible caso de negocio), no puede — sólo eliminando un pago. Documentado como decisión de negocio (RN-L13) por Diego.
- **`updateEntry` sobre income inicial (`loan_id != null`)**: hoy `updateEntry` no distingue kinds. El sprint agrega el gate `loan_id != null` para bloquear. Si algún flujo automático edita entries (por ejemplo, un futuro sprint de refactoring), tendrá que respetar este gate o buscar otra API.
- **`icon_slug` sintético del renglón "Intereses de préstamos"**: hoy los icons vienen de un catálogo curado. Si el reporte trata de renderizar un `icon_slug` desconocido, se cae. Usar un slug que ya existe (`trending-down` o similar) o hacerlo tolerante en el widget.
- **`SegmentedButton` con 4 KPIs preexistentes**: layout puede no acomodar bien un cuarto en cel angosto. Considerar Wrap.
- **Tests widget tolerantes al nuevo AppBar entry**: `dashboard_screen_test.dart` puede localizar por conteo de icons. Ajustar si rompe.

## Estrategia de pruebas

Ver `test-plan.md`. Resumen:
- Unitarias del `LoansDao`: create + income atómico, updateLoan campos inmutables, closeManual + reopen + cannot_reopen_paid, deleteLoan cascada.
- Unitarias de `EntriesDao`: registerLoanPayment (validaciones + auto-cierre paid), deleteLoanPayment (reapertura auto sólo sobre paid), updateEntry rechaza loan_payment.
- Invariantes: AccountsDao.deleteAccount rechaza cuenta atada a préstamo. Cuenta archivada no acepta pagos. Cuenta credit no acepta pagos.
- Backup: round-trip v2 → v2, v1 → v2, validación de referencias.
- Reportes: spending_by_category agrega renglón sintético cuando corresponde.
- Widget: loan_form_screen (campos inmutables), loan_detail_screen (renderizado), dashboard (KPI aparece/desaparece).

## Estrategia de rollback

- Commit único al final o commits por fase según se decida al implementar.
- Rollback = `git revert` del commit. La migración `ALTER TABLE ADD COLUMN` no es reversible en SQLite sin recrear la tabla; en la práctica se hace hotfix con bump de versión (no downgrade real).
- Backup v2 exportado no vuelve a v1. Si Diego rollbackea la app tras exportar v2, el archivo v2 no puede importarse en la versión previa. Único remedio: mantener export v1 en paralelo temporalmente (fuera de alcance) o hacer hotfix.

## Orden sugerido de implementacion

Fase A — Schema + generación:
1. T001 tabla `loans` + columnas nuevas en `journal_entries` + `schemaVersion = 10`.
2. T002 rama nueva en `onUpgrade` para `from == 9 && to == 10` + defensivas.
3. T003 `build_runner build`.

Fase B — DAO base:
4. T004-T008 `LoansDao`: create + updateLoan + closeManual/reopen + deleteLoan + watchActive/watchClosed + balanceOf + findById + countActivePayments + registro en `FincoreDatabase`.
5. T009-T012 `EntriesDao`: `_validKinds` + `registerLoanPayment` + `deleteLoanPayment` + `updateEntry` gate.
6. T013 `AccountsDao.deleteAccount` pre-check.

Fase C — Estado + Reportes:
7. T014 `FinancialStateService.watchTotalLoans`.
8. T015 `constants/reports_tokens.dart` con `kLoanInterestSyntheticId`.
9. T016 `ReportsService.spendingByCategory` post-processing sintético.

Fase D — Router:
10. T017 6 rutas nuevas.

Fase E — UI:
11. T018 `loans_list_screen`.
12. T019 `loan_form_screen` create/edit + overflow menu.
13. T020 `loan_detail_screen`.
14. T021 `loan_monthly_payment_form`.
15. T022 `loan_capital_payment_form`.
16. T023 `entry_form_screen` extensión `_lockedByLoan` + banner.
17. T024 `movement_row` chip `· préstamo`.
18. T025 `dashboard_screen` KPI + chips + entry point.

Fase F — Error mapping + Backup:
19. T026 `error_snackbar` mapea nuevos códigos.
20. T027 `BackupService` bump v2 + export.
21. T028 `BackupService` import v1 + v2 + validación de referencias.

Fase G — Tests:
22. T029 `test/data/loans_dao_test.dart`.
23. T030 `test/data/loan_payments_test.dart`.
24. T031 extensiones en `test/data/invariants_test.dart`.
25. T032 extensiones en `test/data/backup_test.dart`.
26. T033 extensiones en `test/data/reports_test.dart`.
27. T034 widget tests puntuales.
28. T035 `flutter analyze` + `flutter test` completos.

Fase H — Bump + APK + Artefactos:
29. T036 bump `pubspec.yaml` y `build.gradle.kts`.
30. T037 build APK arm64.
31. T038 artefactos `implementation/` (implementation-review, resumen-ejecutivo, resumen-extenso).

## Casos borde que condicionan la solucion

- **Overpay accidental**: `registerLoanPayment` con `principal_amount > balance` cierra automáticamente el préstamo (RN-L11). Se acepta silenciosamente, snackbar informa. Si Diego elimina el pago, se reabre auto (RN-L12).
- **Split `principal = 0, interest = amount`**: pago 100% intereses (mes de gracia). Válido, no cambia el saldo. Común en primeros meses de hipoteca.
- **Split `principal = amount, interest = 0`**: equivalente a "Abono a capital". Válido.
- **`principal_amount + interest_amount ≠ amount`**: rechaza con `invalid_loan_split` (tolerancia `< 0.005`). Cliente valida antes.
- **Cuenta destino tipo credit**: rechazada en `create` con `invalid_account_type` (cinturón adicional al filtro de UI).
- **Cuenta origen archivada en payment forms**: no aparece en picker (default excluye), pero si por algún deep-link llega, DAO rechaza.
- **`payment_day` > 28**: rechazado en form + DAO. Copy explica.
- **`current_duration_months < initial_duration_months`**: aceptado (Diego pagó anticipado). El DAO no valida esto (menor a 0 sí).
- **Reabrir manual sobre paid**: `cannot_reopen_paid`. Sólo la ruta auto de eliminar un pago puede.
- **Eliminar el `income` inicial desde `/entries`**: bloqueado por `updateEntry` gate + banner read-only en `entry_form_screen`. La única vía es `deleteLoan`.
- **Eliminar un `loan_payment` desde `/entries`**: bloqueado igual. Sólo desde `loan_detail_screen`.
- **Backup import v2 con `loan.destination_account_id` inexistente**: `invalid_reference`.
- **Backup import v2 con `close_reason` no en `{'paid', 'manual'}`**: `invalid_loan_data`.
- **Chip PRÓXIMO PAGO en día del vencimiento (`daysUntil = 0`)**: aparece con copy "hoy". Al día siguiente (`daysUntil = -1` para el mes actual, se recalcula al siguiente mes), desaparece.
- **Zonas horarias**: `payment_day` es un int, no una fecha. `daysUntil` calcula desde `DateTime.now()` local. Sin timezone drift.
- **Concurrencia**: single-user, no aplica.
- **Múltiples préstamos activos**: KPI suma todos, chips uno por préstamo. Lista escala sin problemas.
- **Cero préstamos**: KPI oculto, chips no aparecen, `spending_by_category` sin renglón sintético.
- **Renglón sintético con `Σ interest_amount = 0`**: no se renderiza.
- **Cambio de `monthly_payment` post-abono**: sólo altera el default del form del próximo "Pago del mes". Pagos históricos no se recalculan.
- **Eliminar cuenta destino de préstamo eliminado**: `deleteAccount` verifica sólo préstamos con `deleted_at IS NULL`. Un préstamo eliminado (`deleted_at != null`) no bloquea. Verificar test.

## Preguntas o supuestos que siguen afectando la implementacion

- **Supuesto (UX del renglón sintético)**: al tap sobre "Intereses de préstamos" en `spending_by_category_tab`, el drill-down no se abre (comportamiento no-op) o navega a `/loans`. Primera opción es más segura y consistente (los otros renglones abren drill-down por category_id). Si se decide navegar a `/loans`, agregar detección del token especial en el handler del tap. Decisión aplazada, resolver en implementación con "no-op" como default.
- **Supuesto (layout KPI naranja)**: cuatro KPIs pueden requerir cambiar el row a Wrap o mover PRÉSTAMO a una fila propia si la anchura no da. Decisión en implementación tras primer build visual.
- **Supuesto (heurística de split del "Pago del mes")**: pre-llena proporcional al último pago o al `monthly_payment` inicial. Si Diego no ha registrado ningún pago aún, propone `interest = principal * 0.3 aproximado` como sugerencia visible que Diego puede sobrescribir. Alternativa: no pre-llenar, dejar en blanco. Se decide en implementación; preferencia: no pre-llenar el split (dejar en cero) para forzar al usuario a copiar del banco.
- **Supuesto (icon_slug del renglón sintético)**: usar `trending-down` que existe en catálogo curado. Si no existe, usar `credit-card` o algún ícono directo de Flutter fuera del catálogo (el widget que renderiza no sabría, requiere adaptar).
- **Supuesto (entry point en Dashboard)**: entra en AppBar junto a Categorías y Settings. Si el layout no acomoda, se agrupa en un menú overflow con Preferencias/Categorías/Préstamos/Settings.
- **Supuesto (formulario de creación defaults)**: `contract_date = DateTime.now()`, `initial_duration_months` sin default (Diego lo mete), `payment_day` sin default, `destination_account_id` sin default (obliga a elegir).
- **Supuesto (name del préstamo obligatorio)**: min 1 char, max 100. Sin validación de unicidad (Diego puede tener dos préstamos con el mismo nombre si quiere, aunque no es común).
- **Supuesto (contract_date editable)**: aceptado en RN-L01-L04 como editable. En edit, cambiar contract_date NO mueve el `occurred_at` del income inicial (son datos independientes). Decisión aplazada: si Diego cambia contract_date en edit, ¿mueve el income? Preferencia: NO, el income es un journal_entry inmutable como los pagos. Si Diego quiere corregir la fecha del income, tiene que eliminar el préstamo entero y recrearlo.
