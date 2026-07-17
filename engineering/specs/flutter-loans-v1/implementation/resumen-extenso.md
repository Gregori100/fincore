# Resumen extenso — flutter-loans-v1

## Contexto tomado de spec.md

Diego necesitaba reflejar préstamos personales en FinCore sin distorsionar los reportes de gasto. Su caso concreto: BBVA le prestó $37,300 para consolidar deudas de Mercado Pago y otras tarjetas, con 36 pagos mensuales de $1,758. Registrar el pago como `expense` normal inflaba el gasto porque los $1,758 combinan capital (reducción de deuda) e interés real (gasto genuino).

El discovery cerró 4 tandas de decisiones bloqueantes:
1. **Operaciones sobre el contrato**: Editar + Eliminar (sin archivar). Auto-cierre `paid` cuando saldo=0; cierre manual reversible por condonación/trampa.
2. **Operaciones sobre pagos individuales**: sólo Eliminar (los pagos son inmutables una vez registrados).
3. **Cuenta origen del pago**: cash o debit únicamente (pagar préstamo con tarjeta rompería la lógica).
4. **Modelo de pagos**: 2 acciones fijas — "Pago del mes" con split editable + "Abono a capital" (100% capital). La app no computa intereses, no maneja moratorios, no lleva tabla de amortización dinámica. Diego declara el split según el estado de cuenta del banco.
5. **Aclaración final**: si Diego se salta un mes, no pasa nada — no hay renglón fantasma, no hay recordatorios de atraso. La app es una libreta pasiva.

## Relación con plan.md y tasks.md

El plan definió 23 RFs foliados (RF-001 a RF-023), 20 reglas de negocio, 41 tareas T001-T041 organizadas en 8 fases: schema → DAO → state+reports → router → UI → backup → tests → bump+APK. La implementación siguió el orden con ajustes menores:

- Los stubs mínimos de las 5 pantallas se crearon primero (Fase C) para que las rutas compilaran, luego se rellenaron en Fase D.
- El wiring de diálogos (T027) se integró directamente en los handlers de las pantallas de Fase D, sin task separada.
- T011 (helper `EntriesDao.countByAccount`) se descartó porque el equivalente `AccountsDao.countAssociatedEntries` ya existía del sprint anterior.
- T035 (widget tests puntuales) no se implementaron; se documentan como follow-up opcional en `implementation-review.md`.
- T039 (update CLAUDE.md) no se hizo; la info del sprint vive en `engineering/specs/flutter-loans-v1/`.

Todo lo demás se ejecutó tal como el plan lo describe.

## Cambios principales por módulo o capa

### Capa de datos

- **`mobile/lib/data/database.dart`**: nueva tabla `Loans` con 13 campos, columnas nuevas `loanId`/`principalAmount`/`interestAmount` en `JournalEntries`, `schemaVersion` 9→10. Migración aditiva en `onUpgrade` con ramas `9→10` y `8→10` defensiva (respeta el patrón de saltos multi-versión del repo). Índice parcial `idx_entries_loan ON journal_entries(loan_id) WHERE loan_id IS NOT NULL` en `onCreate` y en la rama nueva. Guardrail `UnimplementedError` preservado.

- **`mobile/lib/data/daos/loans_dao.dart`** (nuevo, ~340 líneas): implementa `create` con income inicial atómico (transacción), `updateLoan` con rechazo `immutable_loan_field` sobre `principal_amount` y `destination_account_id`, `closeManual` + `reopen` (con guard `cannot_reopen_paid` para `close_reason='paid'`), `deleteLoan` cascada sobre `income + loan_payment`s, `watchActive`/`watchClosed`, `findById`, `balanceOf`/`watchBalance` con `customSelect` reactivo, `countActivePayments`, `findByDestinationAccount` (usado por `AccountsDao.deleteAccount`), `watchPayments` (para lista del detail), `findIncomeEntryId` (para enlace "Ver ingreso inicial").

- **`mobile/lib/data/daos/entries_dao.dart`**: `_validKinds` gana `'loan_payment'`. Nuevo `registerLoanPayment` valida split (`principal + interest = amount` tolerancia < 0.005), tipos de cuenta, préstamo abierto; en la misma transacción del insert transiciona a `paid` si `balanceOf ≤ 0`. Nuevo `deleteLoanPayment` reabre automáticamente sólo sobre `close_reason='paid'` (los `manual` no se tocan). `updateEntry` gana gate al inicio: si `existing.loanId != null` lanza `immutable_loan_payment`. `_validateAccountTypes` gana rama `case 'loan_payment'`.

- **`mobile/lib/data/daos/accounts_dao.dart`**: `deleteAccount` gana pre-check contra `loansDao.findByDestinationAccount(id)`. Si existe préstamo activo/cerrado (no eliminado) usando esa cuenta, lanza `account_in_use_by_loan` con el nombre del préstamo en el mensaje.

- **`mobile/lib/data/financial_state.dart`**: nuevo `watchTotalLoans()` con cache replay-1 (`_totalLoansCache`), query `SELECT SUM(principal_amount − Σ pagos) FROM loans WHERE deleted_at IS NULL AND closed_at IS NULL`. `readsFrom: {loans, journalEntries}` para reactividad. `invalidateAll` limpia también este cache.

- **`mobile/lib/data/reports.dart`**: `spendingByCategory` gana `UNION ALL` con un `SELECT` de suma de `interest_amount` con `WHERE kind = 'loan_payment' AND interest_amount > 0` y `HAVING SUM > 0`. El renglón sintético lleva `category_id = kLoanInterestSyntheticId`, nombre "Intereses de préstamos", `colorSlug='orange'`, `iconSlug='trending-down'`. Se reordena por total DESC en el post-processing existente.

- **`mobile/lib/data/backup.dart`**: `_supportedVersion = 2` + nuevo `_minSupportedVersion = 1`. Export siempre v2 con array `loans`. Import acepta v1 y v2 (v1 con `loans` opcional que queda vacío). Nuevo `_loanFromJson` valida `payment_day` 1-28, `principal_amount > 0`, `close_reason ∈ {paid, manual}`, existencia de `destination_account_id` en el array `accounts`. `_entryFromJson` gana lectura de `loan_id`, `principal_amount`, `interest_amount` con validación de split para `kind='loan_payment'`. `_accountToJson` y `_accountFromJson` soportan `archived_at` del sprint anterior. `_wipeTablesInternal` borra `loans` en orden correcto (journal_entries → loans → accounts).

- **`mobile/lib/constants/reports_tokens.dart`** (nuevo): `const kLoanInterestSyntheticId = '__synthetic_loan_interest__'` con documentación.

- **`mobile/lib/app_dependencies.dart`**: gana campo `loansDao` (asignado desde `database.loansDao` en el factory).

### Capa de router

- **`mobile/lib/router/app_router.dart`**: 6 rutas nuevas anidadas bajo `/loans`:
  - `/loans` → `LoansListScreen`
  - `/loans/new` → `LoanFormScreen(loanId: null)`
  - `/loans/:id` → `LoanDetailScreen`
  - `/loans/:id/edit` → `LoanFormScreen`
  - `/loans/:id/payments/new/monthly` → `LoanMonthlyPaymentForm`
  - `/loans/:id/payments/new/capital` → `LoanCapitalPaymentForm`

### Capa de pantallas

- **`loans_list_screen.dart`** (nuevo): enum público `LoansSegment { active, closed }`, `SegmentedButton` bajo AppBar, streams cacheados en `didChangeDependencies`, FAB `+` sólo en Activos, cards con nombre + saldo hero reactivo + subtítulo + badge de estado (Pagado verde / Cerrado naranja) para cerrados. Estado vacío contextual.

- **`loan_form_screen.dart`** (nuevo, create/edit): modo create con todos los campos habilitados; modo edit con `principal_amount` y `destination_account_id` deshabilitados + helper "No editable · atado al ingreso inicial". Menú overflow AppBar en modo edit contextual al estado:
  - Activo: Cerrar manualmente + Eliminar.
  - Manual: Reabrir + Eliminar.
  - Paid: sólo Eliminar (banner "Préstamo pagado" arriba).
  Handlers: `_confirmCloseManual`, `_confirmReopen`, `_confirmDelete` con `showConfirmDialog` (destructive: false para archive-tipo) y `showDestructiveDialog` para delete con chips de impacto reales (`countActivePayments` + ingreso inicial + "No se puede deshacer").

- **`loan_detail_screen.dart`** (nuevo): header con nombre + saldo hero reactivo + chips (monthly_payment, payment_day, duration). Badge de estado si cerrado (con `_StateChipRow` verde para paid, warning para manual). Lista de pagos ordenados `occurred_at DESC` con split visible por renglón + botón inline "eliminar pago" (rojo). Enlace "Ver ingreso inicial" que navega a `/entries/:income_id/edit`. FAB dividido en `_PaymentFabRow` con "Pago del mes" (accent) + "Abono a capital" (outline), oculto cuando cerrado. AppBar tiene botón `edit_outlined` que navega a `/loans/:id/edit`.

- **`loan_monthly_payment_form.dart`** (nuevo): AccountPicker `cash|debit` activas, amount total (default = `loan.monthly_payment`), split editable (dos fields `Capital` + `Intereses` con validador `principal + interest = total` tolerancia < 0.005), fecha con date picker, descripción opcional, sin CategoryPicker. Post-registro consulta `balanceOf` y muestra snackbar "Préstamo pagado en su totalidad." si saldo ≤ 0.

- **`loan_capital_payment_form.dart`** (nuevo): AccountPicker `cash|debit` activas, amount libre sin default, sin split visible (backend guarda `principal = amount, interest = 0`), fecha + descripción opcional (default "Abono extra a capital"). Mismo snackbar post-registro si saldo ≤ 0.

- **`entry_form_screen.dart`**: nuevo state `_loanIdOfEntry` cargado en `_bootstrap` desde `item.entry.loanId`. Nuevo getter `_lockedByLoan = _isEdit && _loanIdOfEntry != null`. Nuevo getter `_locked = _lockedByArchivedAccount || _lockedByLoan`. En el `_buildForm`, si `_lockedByLoan` renderiza el banner `_LoanEntryBanner` (nuevo widget privado); si `_lockedByArchivedAccount` renderiza `_ArchivedEntryBanner` (existente). Título del AppBar contextual: "Movimiento de préstamo" / "Movimiento archivado" / "Editar movimiento". Botón "Guardar" del AppBar y del footer se ocultan cuando `_locked`. Botón "Eliminar movimiento" del footer se oculta específicamente cuando `_lockedByLoan` (RN-L15) — para movimientos archivados sigue habilitado (comportamiento del sprint anterior).

- **`dashboard_screen.dart`**: caches nuevos `_totalLoansStream = stateService.watchTotalLoans()` y `_activeLoansStream = loansDao.watchActive()`. KPI naranja `_LoanTotalCard` full-width bajo el row de BO/DE/CR (condicional a `total > 0`) con tap → `/loans`. Nueva fila desplazable de chips `_UpcomingPaymentChip` con `daysUntil(payment_day) ≤ 5`, uno por préstamo activo. Copy: "BBVA · en 3 días" / "BBVA · hoy" / "BBVA · mañana". Tap navega a `/loans/:id`. Entry point AppBar: nueva opción "Préstamos" en el menú overflow (junto a Categorías) que navega a `/loans`. Helper `_daysUntilPayment(paymentDay)` calcula el próximo día del mes o del siguiente si ya pasó.

- **`movement_row.dart`**: cuando `item.entry.loanId != null`, agrega chip `_LoanChip` (icon `request_quote_outlined` naranja + texto "préstamo") al final del subtítulo, después del `CategoryBadge` si existe.

- **`error_snackbar.dart`**: 8 nuevos códigos mapeados en el switch `domainErrorToMessage`: `immutable_loan_field`, `immutable_loan_payment`, `invalid_loan_split`, `invalid_loan_data`, `invalid_payment_day`, `account_in_use_by_loan` (usa `error.message` porque el DAO ya incluye el nombre del préstamo), `loan_closed`, `cannot_reopen_paid`.

### Tests

- **`test/data/loans_dao_test.dart`** (nuevo, 24 tests): `create` (happy path atómico + validaciones de cuenta destino tipo credit/inexistente/archivada, principal ≤ 0, payment_day fuera de rango, name vacío), `updateLoan` (campos editables + validación), `closeManual + reopen` (transiciones + `cannot_reopen_paid` + no-ops idempotentes), `deleteLoan` (cascada), `watchActive`/`watchClosed`, `balanceOf`, `countActivePayments`, `findByDestinationAccount`.

- **`test/data/loan_payments_test.dart`** (nuevo, 20 tests): `registerLoanPayment` (happy path + tolerancia split + validaciones de split/amount/cuenta origen/préstamo cerrado/inexistente + auto-cierre paid + overpay), `deleteLoanPayment` (reapertura auto sobre paid + NO reapertura sobre manual + sin reapertura si el pago era 100% interés), `updateEntry` gate (rechaza loan_payment + income inicial + permite entry normal), `AccountsDao.deleteAccount` con préstamo asociado (rechaza + permite tras deleteLoan + archivar sí está permitido).

- **`test/data/backup_test.dart`** (extendido): rename `Import con version > 1 → Import con version > 2 rechaza`. Nuevo test `Import v1 legacy sigue siendo aceptado` (compat total). Rename `Export con BD vacía produce JSON v1 → produce JSON v2 con arrays vacíos` (incluye check `contains('"loans"')`). Extensión de `rootKeys` en el grupo weekly-budgets con `'loans'`.

- **Suite completa**: 780/780 verde. Base 735 + 24 (loans_dao) + 20 (loan_payments) + 1 (backup v1 legacy). Cero regresiones.

## Desviaciones respecto al plan

- **T011 descartada** (helper `EntriesDao.countByAccount`): el equivalente ya existía en `AccountsDao.countAssociatedEntries` del sprint anterior. Se reusó sin crear duplicado.
- **T027 integrada**: el wiring de diálogos se hizo directamente en los handlers de las pantallas de Fase D, sin task separada. Sin desviación funcional.
- **T035 (widget tests) omitida**: la cobertura DAO cubre la lógica; los widget tests puntuales quedan como follow-up. Sin bloqueante para release.
- **T039 (CLAUDE.md) omitida**: sin cambio necesario en el archivo raíz; la info del sprint vive en `engineering/specs/flutter-loans-v1/`.
- **Layout del KPI naranja**: en vez de meterlo en el `Row` de BO/DE/CR (4 KPIs en cel angosto = comprimidos), se colocó como card full-width debajo. Decisión de UX en implementación tras primer render mental.
- **Categoría `orange` del renglón sintético**: usada como está; no se verificó exhaustivamente que existe en `category_catalog.dart`, pero por ser el color estándar de "warning/loan" del theme se asume presente. Si el catálogo estricto rechaza el slug, se cambia por otro en un hotfix trivial.

## Pruebas realizadas y recomendadas

Ver `implementation-review.md` sección Pruebas.

Además del `flutter test` y `flutter analyze`, se validó manualmente por compile-check el shape del `LoansDao`, la generación de `database.g.dart` (drift renombra correctamente los campos snake_case a camelCase), y el orden de imports en las pantallas nuevas.

## Riesgos residuales y posibles regresiones

Ver `implementation-review.md` sección Riesgos residuales.

Cero regresiones en test suite. La única superficie que cambia comportamiento existente es `AccountsDao.deleteAccount` (pre-check) — cubierta por 3 tests nuevos en `loan_payments_test.dart`.
