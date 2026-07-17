# Módulo de préstamos personales (flutter-loans-v1)

## Resumen

Introduce el manejo de préstamos personales (bancarios, de amigos, hipoteca, auto, etc.) en FinCore. El préstamo se modela como entidad autónoma `Loan` (no una `Account` virtual) con capital original, monthly_payment referencial, duración, día de pago y cuenta destino. Los pagos son `journal_entries` con nuevo `kind = 'loan_payment'` que llevan split declarado por el usuario: `principal_amount` reduce el saldo del préstamo, `interest_amount` cuenta como gasto real. Se agregan al Dashboard un KPI naranja "PRÉSTAMO" (suma de saldos activos, condicional) y un chip "PRÓXIMO PAGO" cuando falta ≤5 días al `payment_day`. Los reportes existentes ganan un renglón sintético "Intereses de préstamos" en `spending_by_category`. Backup JSON bumpa a v2 preservando compatibilidad hacia atrás con v1.

El módulo se diseña como libreta pasiva: no lleva calendario obligatorio, no calcula intereses, no maneja moratorios ni tabla de amortización dinámica. Diego declara cada pago con el split que el banco le muestra en su estado de cuenta.

## Problema a resolver

Diego actualmente no tiene forma de reflejar un préstamo en FinCore. Cuando recibe el capital ($37,300 de BBVA para consolidar deudas de Mercado Pago y otras tarjetas), lo modela como un `income` normal en la Bolsa. Cuando paga $1,758 mensuales, lo modela como `expense` — pero esos $1,758 no son 100% gasto: hay una parte que reduce capital y una parte que es interés real. La app no tiene manera de separar esas dos cosas, lo que rompe:

- El reporte de spending: los $1,758 mensuales inflan el gasto reportado cuando en realidad sólo ~$558 son gasto genuino (interés).
- La visibilidad del saldo pendiente: Diego debería poder ver "me quedan $X del préstamo" en el Dashboard sin abrir la app del banco.
- El histórico de intereses pagados: dato útil para decidir "¿me conviene liquidar anticipado?" o "¿cuánto llevo pagado de puros intereses?".
- El calendario de pagos: sin recordatorio del payment_day Diego se atrasa y el banco le cobra moratorios.

Adicionalmente, este sprint es un prerrequisito de futuros módulos (préstamos de casa/carro, adelantos, financiamientos) que operan bajo la misma mecánica.

## Objetivo

Habilitar el registro y seguimiento de préstamos personales con las siguientes capacidades verificables:

1. Crear un préstamo con capital + monthly_payment + duration + payment_day + cuenta destino, en una sola transacción que genera el `income` inicial ligado al préstamo.
2. Registrar dos tipos de pago: **Pago del mes** (con split manual editable principal + interest) y **Abono a capital** (100% capital, monto libre).
3. Mostrar en Dashboard un KPI naranja "PRÉSTAMO" con la suma de saldos pendientes (sólo cuando ≥1 préstamo activo) y chips "PRÓXIMO PAGO" (uno por préstamo activo a ≤5 días de su payment_day).
4. Exponer una pantalla dedicada `/loans` con segmentado `Activos | Cerrados` y un detalle `/loans/:id` con lista de pagos y acciones.
5. Manejar cierre en dos sabores: **auto (paid)** cuando saldo=0 y **manual** cuando Diego lo fuerza (condonación, error). Los `paid` son terminales; los `manual` se reabren.
6. Registrar la parte `interest_amount` de cada pago como un gasto sintético "Intereses de préstamos" en el reporte `spending_by_category`, sin ensuciar la tabla de categorías reales.
7. Bumpar el backup JSON a v2 sin romper la importación de exports v1.

## Alcance

### Schema

- Nueva tabla `loans` con estos campos:
  - `id TEXT PRIMARY KEY` (UUID v7).
  - `name TEXT NOT NULL` — nombre libre (ej: "BBVA Personal", "Casa CDMX", "Auto Nissan").
  - `principal_amount REAL NOT NULL` — capital original al firmar. **Inmutable post-create** (está atado al `income` inicial).
  - `monthly_payment REAL NOT NULL` — pago mensual referencial. **Editable** (Diego lo ajusta si el banco se lo cambia por abono a capital o refinanciamiento).
  - `initial_duration_months INTEGER NOT NULL` — meses del contrato al firmar. No cambia.
  - `current_duration_months INTEGER NOT NULL` — meses actuales previstos. **Editable** (Diego lo actualiza si el banco bajó el plazo tras un abono).
  - `payment_day INTEGER NOT NULL` — día del mes (1-28) del vencimiento.
  - `contract_date TEXT NOT NULL` — fecha de firma. **Editable**.
  - `destination_account_id TEXT NOT NULL REFERENCES accounts(id)` — cuenta cash/debit donde llegó el dinero. **Inmutable post-create**.
  - `closed_at TEXT NULLABLE` — fecha de cierre. Null cuando activo.
  - `close_reason TEXT NULLABLE` — enum `'paid' | 'manual'`. Null cuando activo.
  - `created_at TEXT NOT NULL`, `updated_at TEXT NOT NULL`, `deleted_at TEXT NULLABLE` — timestamps + soft delete cascada.
- Nuevas columnas en `journal_entries`:
  - `loan_id TEXT NULLABLE REFERENCES loans(id)` — ligado sólo cuando el entry participa de un préstamo (ingreso inicial + `loan_payment`s).
  - `principal_amount REAL NULLABLE` — sólo poblado para `kind = 'loan_payment'`.
  - `interest_amount REAL NULLABLE` — sólo poblado para `kind = 'loan_payment'`.
- Nuevo kind aceptado en `journal_entries.kind`: `'loan_payment'`.
- `schemaVersion` bumpa `9 → 10`. Rama en `MigrationStrategy.onUpgrade` para `from == 9 && to == 10` que ejecuta `CREATE TABLE loans` + `ALTER TABLE journal_entries ADD COLUMN loan_id TEXT REFERENCES loans(id)` + dos `ALTER TABLE ... ADD COLUMN` para los splits. Ramas defensivas para saltos multi-versión desde `from ∈ {6, 7, 8} && to == 10` reutilizando el bloque de la 9 anterior + este delta. El guardrail `UnimplementedError` se conserva.
- Índice opcional: `CREATE INDEX idx_entries_loan ON journal_entries(loan_id) WHERE loan_id IS NOT NULL` para acelerar la agregación del saldo.

### DAO

- Nuevo `LoansDao` (`mobile/lib/data/daos/loans_dao.dart`):
  - `Future<String> create({name, principalAmount, monthlyPayment, initialDurationMonths, paymentDay, contractDate, destinationAccountId})`. Valida cuenta destino existente + cash|debit + no archivada. Crea el `Loan` y el `income` inicial (ligado por `loan_id`) en una transacción. `current_duration_months` se inicializa igual a `initial_duration_months`.
  - `Future<void> updateLoan({id, name?, monthlyPayment?, currentDurationMonths?, paymentDay?, contractDate?})`. Rechaza modificar `principalAmount` o `destinationAccountId` con `immutable_loan_field`.
  - `Future<void> closeManual(id)` — setea `closed_at = now, close_reason = 'manual'`. Valida que el préstamo esté abierto.
  - `Future<void> reopen(id)` — sólo permitido si `close_reason == 'manual'`. Limpia `closed_at + close_reason`. Un préstamo con `close_reason == 'paid'` no puede reabrirse manualmente (mensaje: "Un préstamo pagado no puede reabrirse. Elimina un pago para reactivarlo, o elimina el préstamo entero.").
  - `Future<void> deleteLoan(id, [FinancialStateService?])` — soft delete cascada: setea `deleted_at` en el préstamo, en el `income` inicial (`loan_id == id && kind == 'income'`) y en todos los `loan_payment` del préstamo. Todo en una transacción.
  - `Stream<List<Loan>> watchActive()` — `deleted_at IS NULL AND closed_at IS NULL`.
  - `Stream<List<Loan>> watchClosed()` — `deleted_at IS NULL AND closed_at IS NOT NULL`. Ordenado por `closed_at DESC`.
  - `Future<Loan?> findById(id)` — retorna incluso cerrados; excluye eliminados.
  - `Future<double> balanceOf(id)` — `principal_amount − Σ(je.principal_amount WHERE loan_id = id AND deleted_at IS NULL AND kind = 'loan_payment')`.
  - `Stream<double> watchBalance(id)` — reactivo sobre `journal_entries` y `loans`.
  - `Future<int> countActivePayments(id)` — cuenta `loan_payment`s activos, para el chip de impacto del `DestructiveDialog`.
- Extensión de `EntriesDao`:
  - Nuevo método `registerLoanPayment({loanId, accountOriginId, amount, principalAmount, interestAmount, occurredAt, description?})`. Valida:
    - `loanId` existe, préstamo abierto (`closed_at IS NULL`), no eliminado.
    - `accountOriginId` existe, tipo cash|debit, no archivada, no eliminada.
    - `principalAmount ≥ 0`, `interestAmount ≥ 0`.
    - `principalAmount + interestAmount == amount` (tolerancia `< 0.005`).
    - `amount > 0`.
  - Después de insertar el `loan_payment`, si `balanceOf(loanId) ≤ 0` **y** el préstamo estaba abierto → setea `closed_at = now, close_reason = 'paid'` en la misma transacción.
  - Nuevo método `deleteLoanPayment(entryId)`:
    - Soft delete del entry.
    - Después del delete: si el préstamo asociado estaba con `close_reason = 'paid'` y ahora `balanceOf > 0` → **reabre automático** (limpia `closed_at + close_reason`). Los cerrados manualmente no se tocan.
  - `EntriesDao.watchPage`, `EntriesDao.findById` y demás lecturas cargan los nuevos campos sin cambio en la superficie pública.
  - `_validKinds` gana `'loan_payment'`.
  - Validaciones cross-kind: `updateEntry` sobre un `loan_payment` lanza `immutable_loan_payment` con mensaje "Los pagos de préstamo no se editan. Elimínalo y crea uno nuevo.". Sólo `cancel` (via `deleteLoanPayment`) está permitido.
- `AccountsDao.deleteAccount` (existente) recibe extensión menor: si la cuenta a eliminar es `destination_account_id` de algún préstamo activo, se lanza `account_in_use_by_loan` con mensaje "Esta cuenta está atada al préstamo <name>. Elimina el préstamo primero.". Es una restricción explícita para preservar la relación préstamo↔cuenta destino.

### `FinancialStateService`

- Nuevo `Stream<double> watchTotalLoans()` — suma de `balanceOf` de todos los préstamos activos (no cerrados, no eliminados). Reactivo sobre `loans` y `journal_entries`.
- Sin cambios en BO/DE/CR (los préstamos no contribuyen a esos KPIs — son un cuarto totalizador separado).

### Reportes (`mobile/lib/data/reports.dart`)

- `spendingByCategory` gana un post-processing: al finalizar la query normal, agrega un renglón sintético `{name: 'Intereses de préstamos', colorSlug: 'orange', iconSlug: 'trending-down', total: Σ interest_amount}` donde suma todos los `loan_payment`s del periodo con `deleted_at IS NULL`. Sólo aparece si el total > 0. Se ordena por total DESC como cualquier renglón real.
- `cashflow` no requiere cambios: la salida del `loan_payment` ya sale de la cuenta origen y aparece en `outflow` normal.
- `topMovements` y `movementsCalendar` no requieren cambios funcionales.
- Ningún reporte consulta `closed_at` de los préstamos — todos ignoran ese estado y sólo miran `deleted_at IS NULL` en los entries.

### Router

- Nuevas rutas:
  - `/loans` — lista con segmentado.
  - `/loans/new` — form de creación.
  - `/loans/:id` — detalle + lista de pagos.
  - `/loans/:id/edit` — form de edición del contrato.
  - `/loans/:id/payments/new/monthly` — form del "Pago del mes".
  - `/loans/:id/payments/new/capital` — form del "Abono a capital".
- Entry point en el Dashboard AppBar: nuevo icono `Icons.request_quote_outlined` que abre `/loans`. Aparece siempre (aunque no haya préstamos), consistente con `/accounts` y `/categories`.

### UI

- **`loans_list_screen`** (`mobile/lib/screens/loans_list_screen.dart`):
  - `SegmentedButton<LoansSegment>` con `Activos | Cerrados`. Default: Activos.
  - FAB `+` que navega a `/loans/new` — sólo visible en el segmento Activos.
  - Card de préstamo (activo): nombre + tipo (icono `Icons.request_quote_outlined` naranja) + saldo pendiente destacado + `monthly_payment · payment_day` como subtítulo + progreso lineal `principal_amount − balance / principal_amount` opcional.
  - Card de préstamo (cerrado): mismo layout con opacidad reducida + badge `Pagado` (verde) o `Cerrado manual` (naranja) según `close_reason`.
  - Tap en card → `/loans/:id`.
  - Sin menú overflow por card (todas las acciones viven en el detalle).
- **`loan_form_screen`** (create/edit):
  - Campos: `name`, `principal_amount`, `monthly_payment`, `initial_duration_months`, `payment_day`, `contract_date`, `destination_account_id` (AccountPicker filtrado a cash|debit).
  - En modo edit: `principal_amount` y `destination_account_id` **deshabilitados** con helper text "No editable · atado al ingreso inicial".
  - Botón principal: "Crear préstamo" o "Guardar cambios".
  - Menú overflow del AppBar en modo edit:
    - Préstamo activo: `Cerrar manualmente`, divider, `Eliminar` (rojo).
    - Préstamo cerrado manualmente: `Reabrir`, divider, `Eliminar` (rojo).
    - Préstamo pagado: sólo `Eliminar` (rojo). Banner "Préstamo pagado" superior.
- **`loan_detail_screen`** (`/loans/:id`):
  - Header: nombre, saldo pendiente hero, chips laterales `monthly_payment` + `payment_day` + `initial_duration_months / current_duration_months`.
  - Badge de estado si cerrado.
  - Lista de pagos (todos los `loan_payment` del préstamo, ordenados por `occurred_at DESC`). Cada renglón: fecha, total, split `principal | interest`, cuenta origen. Tap → dialogo con opción `Eliminar` (los pagos no se editan).
  - FAB extended con 2 opciones desplegables o botón dividido: "Pago del mes" (accent) + "Abono a capital" (outline). En préstamos cerrados el FAB no aparece.
  - Enlace "Ver ingreso inicial" en el header abre el journal_entry del `income` ligado (modo read-only si el préstamo está cerrado o pagado).
- **`loan_monthly_payment_form`** (`/loans/:id/payments/new/monthly`):
  - AccountPicker (origen, filtrado cash|debit, activas).
  - Amount total (default = `loan.monthly_payment`).
  - Split: dos fields `Capital` y `Intereses` que se validan sumando al total (helper text: "Suma debe ser igual al monto"). Al cambiar el total, la app propone un split proporcional a la última proporción usada o al `monthly_payment` original (heurística menor). Diego siempre puede sobrescribir.
  - Fecha (default hoy).
  - Descripción opcional.
  - Sin CategoryPicker.
  - Botón "Registrar pago".
- **`loan_capital_payment_form`** (`/loans/:id/payments/new/capital`):
  - AccountPicker (origen, filtrado cash|debit, activas).
  - Amount libre (sin default).
  - Sin split visible: 100% capital. Backend guarda `principal_amount = amount, interest_amount = 0`.
  - Fecha (default hoy).
  - Descripción opcional (sugerencia: "Abono extra").
  - Botón "Registrar abono".
- **`entry_form_screen`** existente:
  - Cuando el entry en edición tiene `loan_id != null` (ingreso inicial de un préstamo, o `loan_payment`), el form entra en modo **read-only** con banner "Movimiento ligado a préstamo · Se administra desde /loans". Sólo se habilita el enlace "Ver préstamo" que navega a `/loans/:id`. El botón "Eliminar movimiento" queda deshabilitado; la eliminación del pago se hace desde `loan_detail_screen`.
- **`dashboard_screen`**:
  - Nuevo KPI naranja "PRÉSTAMO" al lado de BO/DE/CR. Sólo se renderiza si `watchTotalLoans() > 0` (equivalente a "hay ≥1 préstamo activo con saldo pendiente"). Muestra el total y al tap navega a `/loans`.
  - Nuevo chip "PRÓXIMO PAGO" por cada préstamo activo con `daysUntil(payment_day) ≤ 5`. Aparece en una fila horizontal desplazable bajo los KPIs. Tap navega al detalle del préstamo. Copy: "BBVA · en 3 días".
  - Nuevo botón/entry al AppBar: icono `Icons.request_quote_outlined`. Tap → `/loans`.
- **`movement_row`** existente:
  - Si el entry tiene `loan_id != null`, el subtítulo agrega chip pequeño `· préstamo` (color naranja) tras el nombre de cuenta. Diego identifica visualmente que ese movimiento es especial.
- **`AccountPicker`**: sin cambios.
- **`AccountsDao.deleteAccount`**: pre-check contra `loans.destination_account_id`. Si aparece, lanza `account_in_use_by_loan` (nuevo código).

### Diálogos

- **Cerrar manualmente**: `showConfirmDialog` con copy "Cerrar el préstamo <name> manualmente. Úsalo si el banco lo condonó o si es un registro de prueba. Puedes reabrirlo después." Botón "Cerrar préstamo".
- **Reabrir**: `showConfirmDialog` con copy "Reabrir el préstamo <name>. Vuelve a estado activo y se aceptan nuevos pagos." Botón "Reabrir".
- **Eliminar**: `showDestructiveDialog` con `objectName = loan.name`, hero icon `Icons.delete_forever_outlined`, impacts:
  - "N pagos se cancelarán" (via `countActivePayments`).
  - "El ingreso inicial de $X en <cuenta destino> se cancela" (impacto sobre el balance de la cuenta).
  - "No se puede deshacer".
  - Copy: "Se borra el contrato, el ingreso inicial y todos los pagos registrados. El balance de la cuenta destino se ajusta."
- **Eliminar pago individual** (desde loan_detail_screen): `showConfirmDialog` (no destructivo pesado — es un solo entry). Copy: "Eliminar el pago del <fecha> por $X. Si el préstamo estaba pagado se reabrirá automáticamente." Botón rojo "Eliminar pago".

### Backup JSON v2

- Bump `version: 1 → 2`.
- Nuevo campo `loans: []` — array con contratos (activos + cerrados manual + cerrados paid, todos con `deleted_at IS NULL`). Cada objeto tiene todos los campos de la tabla `loans`.
- `journal_entries[].loan_id`, `journal_entries[].principal_amount`, `journal_entries[].interest_amount` — campos nuevos, sólo poblados cuando aplican.
- `BackupService.exportToJson` siempre exporta v2 desde este sprint en adelante.
- `BackupService.importFromJson` acepta **v1 y v2**:
  - v1: importa como hoy, sin loans. Los `journal_entries` importados quedan con `loan_id = null`.
  - v2: importa loans + entries con sus splits y `loan_id`s.
  - Cualquier otra `version` (0, 3+, negativa, string no numérica): lanza `unsupported_version` con mensaje: "Backup v<X>. Actualiza la app para importarlo."
- Validación de referencias en import v2: cada `loan.destination_account_id` debe existir en el array `accounts`. Cada `journal_entries[].loan_id` debe existir en el array `loans`. Si no, `invalid_reference`.

### Bump de versión

- `pubspec.yaml`: `0.26.0+109 → 0.27.0+110`.
- `android/app/build.gradle.kts`: `versionCode = 110`, `versionName = "0.27.0"`.

### Tests

- `test/data/loans_dao_test.dart` nuevo: cobertura CRUD del `LoansDao` (create + ingreso inicial atómico, updateLoan con campos inmutables, closeManual + reopen, deleteLoan cascada, watchActive/watchClosed, balanceOf, cierre paid automático al llegar saldo=0, reabrir automático al eliminar pago sobre paid, no reabrir cuando close_reason=manual).
- `test/data/loan_payments_test.dart` nuevo: `EntriesDao.registerLoanPayment` (valida tipos, split = amount, préstamo abierto), `deleteLoanPayment` (reapertura auto sólo sobre paid, no sobre manual), `updateEntry` sobre loan_payment → `immutable_loan_payment`.
- `test/data/invariants_test.dart` gana tests: `AccountsDao.deleteAccount` sobre cuenta atada a préstamo → `account_in_use_by_loan`. `registerLoanPayment` sobre cuenta origen archivada → error. Sobre cuenta origen credit → error.
- `test/data/backup_test.dart` gana tests: round-trip export v2 → import v2 preserva loans + splits. Import v1 sobre app v2 funciona (loans queda vacío). Import de v2 con `loan.destination_account_id` inexistente → `invalid_reference`.
- `test/data/reports_test.dart` gana tests: `spendingByCategory` agrega renglón "Intereses de préstamos" cuando hay `loan_payment`s con `interest_amount > 0`. No aparece si todos son 0. Su total coincide con la suma esperada.
- Widget tests puntuales para `loan_form_screen` (campos inmutables deshabilitados en edit), `loan_detail_screen` (renderizado de saldo y lista de pagos), `dashboard_screen` (KPI naranja aparece/desaparece según total).

## Fuera de alcance

- Tabla de amortización precomputada y dinámica. Cada pago es un registro suelto.
- Cálculo de intereses moratorios, cargos por atraso, comisiones automáticas. Diego los declara implícitos en el `interest_amount` de cada pago según lo que le cobró el banco.
- Recordatorios push o notificaciones locales de payment_day. El sprint sólo incluye el chip visual del Dashboard.
- Refinanciamiento automático (cambio de plazo/tasa/monto). Diego edita `monthly_payment` y `current_duration_months` a mano si el banco le cambia el contrato.
- Cierre automático de la cuenta destino cuando se cierra el préstamo. La cuenta destino sigue viva independiente del estado del préstamo.
- Múltiples cuentas destino por préstamo. Un préstamo va a una sola cuenta.
- Préstamos que Diego DA (a alguien más). El sprint sólo cubre préstamos que Diego RECIBE. Los prestamistas se modelarían al revés (Diego como acreedor) y son otro sprint.
- Comisión inicial ("$1000 de seguro de vida" del ejemplo): NO se guarda en el schema del préstamo. Diego la registra como `expense` manual desde `/entries/new` si quiere reflejarla. Documentado en el copy del form de creación como sugerencia.
- Categorización de la parte `principal_amount` en reportes. Sólo `interest_amount` aparece bajo el renglón sintético "Intereses de préstamos" en `spending_by_category`. La parte capital no cuenta como gasto (es reducción de deuda).
- Historial de estados del préstamo (auditoría de aperturas/cierres). Sólo se guarda el último `closed_at + close_reason`.
- Edición de pagos individuales. Los `loan_payment` son inmutables; para corregir hay que eliminar y crear uno nuevo.
- Deep-linking desde una notificación externa. Toda navegación es intra-app.
- KPI naranja "PRÉSTAMO" en Onboarding o en la pantalla de First-Run. Sólo aparece en Dashboard.

## Reglas de negocio

- RN-L01: `Loan.principal_amount` es inmutable post-create. Cualquier `updateLoan` que intente cambiarlo lanza `immutable_loan_field`.
- RN-L02: `Loan.destination_account_id` es inmutable post-create. Mismo error si se intenta cambiar.
- RN-L03: `Loan.monthly_payment` es editable en cualquier momento. Es referencia visual, no altera saldos.
- RN-L04: `Loan.current_duration_months` es editable. `initial_duration_months` no. Ambos se preservan para trazabilidad histórica y para calcular "meses restantes" aproximados.
- RN-L05: `Loan.payment_day` acepta valores 1-28 (para evitar problemas de meses con 29/30/31). Si el banco cobra los días 29+, Diego pone 28 y el sistema muestra el chip un poco antes.
- RN-L06: Al crear un préstamo se genera atómicamente un `income` en `destination_account_id` con `amount = principal_amount`, `occurredAt = contract_date`, `loan_id = loan.id`, `categoryId = null`. Si el insert del `income` falla, el `Loan` no se persiste (transacción).
- RN-L07: `kind = 'loan_payment'` requiere `accountOriginId ∈ cash|debit` no archivada + `accountDestinationId = null` + `loan_id != null` + préstamo abierto (`closed_at IS NULL`). Cualquier violación lanza `invalid_account_type` o `loan_closed` según corresponda.
- RN-L08: `principal_amount + interest_amount = amount` en cada `loan_payment`, con tolerancia `< 0.005` para redondeos. Ambos ≥ 0. Total > 0.
- RN-L09: `AccountsDao.deleteAccount` sobre una cuenta que es `destination_account_id` de algún préstamo con `deleted_at IS NULL` (activo o cerrado) lanza `account_in_use_by_loan`. La cuenta puede archivarse (no bloquea) pero no eliminarse.
- RN-L10: El saldo de un préstamo se computa on-the-fly: `principal_amount − Σ(loan_payment.principal_amount con deleted_at IS NULL)`. Nunca se persiste.
- RN-L11: Cuando `saldo ≤ 0` tras un `registerLoanPayment` (o al recomputar), y el préstamo estaba abierto, se transiciona automáticamente a `closed_at = now, close_reason = 'paid'` en la misma transacción del insert.
- RN-L12: Cuando se elimina un `loan_payment` y el préstamo estaba con `close_reason = 'paid'` y ahora `saldo > 0`, el préstamo se reabre automáticamente (limpia `closed_at + close_reason`) en la misma transacción del delete.
- RN-L13: Un préstamo con `close_reason = 'paid'` no puede reabrirse manualmente. Sólo por la ruta RN-L12 (eliminar un pago). Ni por acción de UI ni por método público del DAO.
- RN-L14: Un préstamo con `close_reason = 'manual'` **sí** puede reabrirse manualmente via `LoansDao.reopen`. Al reabrirse acepta nuevos pagos.
- RN-L15: `updateEntry` sobre un `loan_payment` (o sobre el `income` inicial ligado a un préstamo) lanza `immutable_loan_payment`. La corrección es siempre eliminar + recrear (para los pagos) o eliminar el préstamo entero (para el ingreso inicial).
- RN-L16: `deleteLoan` cascada afecta: el `Loan`, el `income` inicial (via `loan_id` y `kind = 'income'`), y todos los `loan_payment` del préstamo. Todo con `deleted_at = now` en una transacción. Los balances de las cuentas involucradas (destino del income, origen de los pagos) se recomputan on-the-fly y reflejan el ajuste automáticamente.
- RN-L17: El renglón sintético "Intereses de préstamos" en `spending_by_category` aparece sólo si `Σ interest_amount del periodo > 0`. Ordena junto con las categorías reales por total DESC. Su `id` es un token especial `kLoanInterestSyntheticId` documentado en `lib/constants/reports_tokens.dart`; los filtros de drilldown del reporte pueden tratar este token como "no hay drilldown" o navegar a `/loans` (decisión de UX menor: primer paso es no-op y opción explícita al tap).
- RN-L18: El backup JSON v2 exporta loans + splits. Import de v1 acepta sin fallar (loans queda vacío). Import de v2 valida referencias (`destination_account_id`, `loan_id`) con `invalid_reference` si están rotas.
- RN-L19: La Bolsa (`type = cash, is_protected = true`) puede ser `destination_account_id` de un préstamo. No hay restricción especial contra ella. Es común: préstamos personales se depositan en efectivo o transferencia a cuenta principal.
- RN-L20: El chip "PRÓXIMO PAGO" del Dashboard se computa con `daysUntil = (proximo_payment_day − DateTime.now())`. `proximo_payment_day` es el próximo día del mes que coincide con `loan.payment_day` (si hoy es 25 y payment_day = 5, es el 5 del mes siguiente). Aparece cuando `0 ≤ daysUntil ≤ 5`. Se oculta cuando `daysUntil < 0` (ya pasó — la app no le da seguimiento a atrasos).

## Requisitos funcionales

- RF-001: Crear tabla `loans` con los campos descritos y bumpear `schemaVersion` a 10. Agregar rama `from == 9 && to == 10` en `MigrationStrategy.onUpgrade` con `CREATE TABLE loans` + `ALTER TABLE journal_entries ADD COLUMN loan_id`, `principal_amount`, `interest_amount`. Ramas defensivas para `from ∈ {6, 7, 8} && to == 10` combinando las migraciones intermedias. Guardrail preservado.
- RF-002: Regenerar `mobile/lib/data/database.g.dart` con `dart run build_runner build`.
- RF-003: Nuevo `LoansDao` con `create`, `updateLoan`, `closeManual`, `reopen`, `deleteLoan`, `watchActive`, `watchClosed`, `findById`, `balanceOf`, `watchBalance`, `countActivePayments`.
- RF-004: `LoansDao.create` genera atómicamente el `income` inicial ligado por `loan_id` (RN-L06).
- RF-005: `LoansDao.updateLoan` rechaza cambios en `principal_amount` y `destination_account_id` con `immutable_loan_field`.
- RF-006: `LoansDao.closeManual` setea `close_reason = 'manual'`. `LoansDao.reopen` lo revierte. `reopen` sobre `close_reason = 'paid'` lanza `cannot_reopen_paid` (RN-L13).
- RF-007: `LoansDao.deleteLoan` cascada sobre `income` inicial + `loan_payment`s del préstamo (RN-L16).
- RF-008: Extensión de `EntriesDao`:
  - `_validKinds` gana `'loan_payment'`.
  - Nuevo `registerLoanPayment` valida RN-L07 y RN-L08.
  - Transiciona automáticamente el préstamo a `paid` si el saldo cae a ≤ 0 (RN-L11).
  - Nuevo `deleteLoanPayment` reabre automáticamente si el préstamo estaba `paid` y ahora saldo > 0 (RN-L12).
  - `updateEntry` sobre `loan_payment` o sobre el `income` con `loan_id != null` lanza `immutable_loan_payment` (RN-L15).
- RF-009: `AccountsDao.deleteAccount` gana pre-check contra `loans.destination_account_id` y lanza `account_in_use_by_loan` (RN-L09).
- RF-010: `FinancialStateService` gana `Stream<double> watchTotalLoans()` reactivo.
- RF-011: `ReportsService.spendingByCategory` agrega el renglón sintético "Intereses de préstamos" con `Σ interest_amount` del periodo, ordenado con las demás categorías por total DESC (RN-L17).
- RF-012: Nuevas rutas: `/loans`, `/loans/new`, `/loans/:id`, `/loans/:id/edit`, `/loans/:id/payments/new/monthly`, `/loans/:id/payments/new/capital`.
- RF-013: Nueva pantalla `loans_list_screen` con `SegmentedButton<LoansSegment>`.
- RF-014: Nueva pantalla `loan_form_screen` (create/edit) con campos inmutables deshabilitados en edit y menú overflow AppBar contextual al estado del préstamo.
- RF-015: Nueva pantalla `loan_detail_screen` con header + lista de pagos + FAB dividido.
- RF-016: Nueva pantalla `loan_monthly_payment_form` con split editable validado.
- RF-017: Nueva pantalla `loan_capital_payment_form` sin split.
- RF-018: `entry_form_screen` gana detección de `loan_id != null` y modo read-only con banner + enlace "Ver préstamo".
- RF-019: `dashboard_screen` gana:
  - Nuevo KPI naranja "PRÉSTAMO" (suma de `watchTotalLoans`), condicional (`> 0`).
  - Chips "PRÓXIMO PAGO" por préstamo activo con `daysUntil ≤ 5` (RN-L20).
  - Entry point AppBar `Icons.request_quote_outlined` → `/loans`.
- RF-020: `movement_row` gana chip pequeño "· préstamo" (naranja) en subtítulo cuando `entry.loan_id != null`.
- RF-021: Diálogos `showConfirmDialog` para closeManual + reopen, `showDestructiveDialog` para deleteLoan con impact chips reales.
- RF-022: `BackupService` bump a v2. Export siempre v2. Import acepta v1 y v2, valida referencias (RN-L18).
- RF-023: Bump `pubspec.yaml` a `0.27.0+110` y `android/app/build.gradle.kts` a `versionCode = 110`, `versionName = "0.27.0"`.

## Casos principales

- Diego contrata BBVA Personal $37,300 a 36 meses de $1,758 con payment_day = 5. Selecciona la Bolsa como cuenta destino. Al confirmar, `Loan` queda creado y aparece un `income` de $37,300 en la Bolsa el mismo día (Bolsa sube $37,300, KPI BO refleja el aumento). En `/loans` aparece el préstamo en Activos con saldo pendiente $37,300.
- Diego registra el primer "Pago del mes" desde la Bolsa: total $1,758, split `principal = 1200, interest = 558`. Bolsa baja $1,758. Saldo del préstamo baja a $36,100. El spending_by_category del mes muestra "Intereses de préstamos: $558".
- Diego registra un "Abono a capital" de $5,000 desde la Bolsa. Bolsa baja $5,000. Saldo baja a $31,100. En reportes el abono no aparece como gasto (todo va a capital).
- Diego habla con BBVA para bajar el plazo tras el abono. Edita el contrato: `current_duration_months = 20` (era 36). El `principal_amount` sigue en $37,300 (inmutable) e `initial_duration_months` sigue en 36.
- Diego olvida pagar febrero. Marzo registra pago normal con `occurredAt = 2027-03-05`. La app no marca "vencido", no genera renglón fantasma. El saldo simplemente no bajó en febrero.
- Diego llega al último pago del préstamo (pago 36). El saldo cae a $0. El préstamo transiciona automáticamente a `closed_at = now, close_reason = 'paid'` y desaparece del segmento Activos. Aparece en Cerrados con badge "Pagado".
- Diego elimina por error un pago intermedio del préstamo pagado. El saldo vuelve a $1,758. El préstamo se reabre automáticamente (limpia `closed_at + close_reason`) y vuelve a Activos. Aparece de nuevo el KPI naranja y el chip "PRÓXIMO PAGO" según corresponda.
- Diego decide cerrar manualmente un préstamo (BBVA se lo condonó tras negociación). Menu overflow del detalle → "Cerrar manualmente" → confirmDialog. `close_reason = 'manual'`. Pasa a Cerrados con badge "Cerrado manual".
- Diego intenta reabrir el préstamo cerrado manual una semana después. Acción "Reabrir" desde el menu overflow. Vuelve a Activos con el saldo que tenía al cerrar.
- Diego intenta eliminar la cuenta débito que era `destination_account_id` de un préstamo activo. La app rechaza con `account_in_use_by_loan` y muestra un mensaje amigable con el nombre del préstamo.
- Diego exporta backup desde Settings. El JSON viene con `version: 2`, `loans: [...]` populated, y `journal_entries` con `loan_id`, `principal_amount`, `interest_amount` en los renglones aplicables.
- Diego importa un backup v1 antiguo. El import funciona: `loans` queda vacío, `journal_entries` con `loan_id = null` en todos. La app sigue funcional (KPI naranja no aparece).

## Casos borde

- Préstamo con `initial_duration_months = 0` o `principal_amount = 0`: rechazar en el DAO con `invalid_loan_data`. Formularios validan antes de enviar.
- `payment_day = 31` o `payment_day > 28`: rechazar en el DAO con `invalid_payment_day` (rango 1-28). Copy explica por qué en el form.
- `monthly_payment > principal_amount`: se acepta (podría ser un préstamo a 1 pago con intereses).
- Split del pago con `principal_amount + interest_amount ≠ amount`: rechazar con `invalid_loan_split` (tolerancia < 0.005). El form pre-valida antes de enviar.
- Split con `principal_amount = 0` y `interest_amount = amount`: se acepta (pago de sólo intereses, ej. gracia inicial). Saldo del préstamo no cambia.
- Split con `principal_amount = amount` y `interest_amount = 0`: se acepta (abono directo a capital, equivalente al "Abono a capital"). Válido.
- Pagar más del saldo pendiente (`principal_amount > balance actual`): se acepta silenciosamente. Saldo cae a negativo momentáneamente, el préstamo se cierra `paid`. Los reportes muestran el interés real declarado sin importar el overshoot de capital. Es consistente con la filosofía "libreta libre" (RN-L11). El chip de impacto del `DestructiveDialog` de "Eliminar pago" advierte si el préstamo tiene saldo negativo.
- Cuenta origen archivada: `registerLoanPayment` la rechaza con `invalid_account_type`. El form no la ofrece en el picker (default excluye archivadas).
- Cuenta origen credit: rechazada con `invalid_account_type`.
- Cuenta destino archivada: se puede seguir usando para nuevos pagos (el origen puede ser otra cuenta activa) y para el ingreso inicial ya registrado. `AccountsDao.deleteAccount` sigue bloqueando por RN-L09. Archivar la cuenta destino no afecta el préstamo.
- Cuenta destino eliminada (via cascada de otro flujo antes de RN-L09): imposible porque RN-L09 protege. Documentado como invariante.
- Préstamo con saldo = 0 pero `close_reason IS NULL`: no debería ocurrir (RN-L11 lo cierra automáticamente). Si se detecta al abrir la app (por corrupción o migración externa), el próximo `registerLoanPayment` o `deleteLoanPayment` fuerza el chequeo y lo cierra.
- Múltiples préstamos activos: KPI naranja suma todos los saldos. Chips "PRÓXIMO PAGO" aparecen uno por préstamo. `/loans` los lista todos.
- Ningún préstamo activo: KPI naranja no se renderiza. `spending_by_category` no muestra el renglón sintético. `/loans` muestra estado vacío "Aún no tienes préstamos".
- Backup v1 importado sobre app v2 con préstamos preexistentes: `wipeAll` los borra antes del import. Diego pierde los préstamos previos (comportamiento de reemplazo total, consistente con backup import actual).
- Backup v2 con `loan_id` en un entry pero sin ese `loan_id` en el array `loans`: `invalid_reference`.
- Backup v2 con `close_reason` inválido (fuera de 'paid'|'manual'): `invalid_loan_data`.
- Editar el `income` inicial de un préstamo desde `entry_form_screen` (deep link a `/entries/:id/edit`): el form detecta `loan_id != null` y entra en modo read-only. Sólo enlace "Ver préstamo". Botón Eliminar deshabilitado (para eliminar hay que ir al préstamo).
- Eliminar el `income` inicial de un préstamo desde `/entries` directamente: no permitido. Sólo se elimina como parte del `deleteLoan` cascada.
- Reabrir un préstamo cerrado manual que fue creado hace mucho tiempo (contract_date muy vieja): el chip "PRÓXIMO PAGO" reactiva basándose en `payment_day` y el mes actual (RN-L20).
- Concurrencia: single-user, no aplica. Todas las escrituras van en transacción.

## Criterios de aceptacion

- `flutter analyze` en `mobile/` sin errores nuevos (los 5 hints preexistentes de `prefer_const_constructors` en `entry_form_screen.dart` siguen tolerados).
- `flutter test` verde con ≥ 780 tests (base 735 + ≥ 45 nuevos del sprint distribuidos entre DAO, backup, invariantes, reportes y widgets).
- `schemaVersion == 10` en `database.dart`. Rama nueva en `onUpgrade` cubre 9 → 10 y saltos defensivos 6/7/8 → 10. Guardrail `UnimplementedError` sigue lanzando para transiciones no cubiertas.
- Manual smoke Android: crear préstamo → ingreso inicial aparece en Bolsa → registrar pago del mes → saldo baja + spending_by_category incluye "Intereses de préstamos" → registrar abono a capital → saldo baja sin gasto reportado → eliminar cuenta destino intento fallido con mensaje amigable → cerrar manual → reabrir → eliminar en cascada con `DestructiveDialog` con conteo real.
- KPI naranja "PRÉSTAMO" en Dashboard aparece cuando hay ≥1 préstamo activo con saldo pendiente y desaparece cuando se cierra el último.
- Chip "PRÓXIMO PAGO" aparece 5 días antes del payment_day y se oculta al día siguiente.
- `entry_form_screen` en modo edit de un `loan_payment` o `income` con `loan_id != null` renderiza read-only con enlace al detalle del préstamo.
- Backup export → import round-trip preserva loans + splits bit a bit. Backup v1 importado → funciona con `loans = []`.
- `scripts/verify-apk.sh` confirma sincronía de `versionCode = 110`.
- Ningún reporte existente pierde datos ni cambia salida cuando no hay préstamos.

## Criterios medibles de exito

- Cantidad de tests: base 735 → ≥ 780 (mínimo +45 nuevos). Distribución esperada: 15 tests DAO loans + 10 tests loan_payment + 5 tests invariantes cross-DAO + 5 tests backup v2 + 5 tests reportes + 5 tests widget.
- Cobertura de RN: cada regla RN-L01 a RN-L20 tiene al menos 1 test que la ejerce.
- Regresión de balances: BO/DE/CR y `watchAccountBalance` retornan valores idénticos antes y después de crear/pagar/cerrar/eliminar un préstamo en una BD sembrada con el mismo journal. Los préstamos no contaminan esos KPIs.
- Regresión de reportes: `spending_by_category`, `cashflow`, `topMovements`, `movementsCalendar` retornan datos idénticos en una BD sin préstamos antes y después del sprint. Con préstamos, `spending_by_category` gana el renglón "Intereses de préstamos" con total esperado.
- Migración schema 9 → 10 corre sin corrupción en test de integración (BD sembrada con datos v9, `open` la trae a v10, todas las queries siguen funcionando).
- APK arm64 build exitoso, `versionCode` sincronizado, instala con `adb install -r` sin `INSTALL_FAILED_VERSION_DOWNGRADE`.
- Bump exitoso.

## Riesgos

- **Migración schema 9 → 10 con `ALTER TABLE ADD COLUMN` sobre `journal_entries`**: la tabla puede tener muchos renglones. `ALTER TABLE ADD COLUMN` en SQLite es rápido (O(1)) pero la migración corre fuera de transacción usuario (limitación conocida). Idempotencia: si crashea entre los tres ALTER, el siguiente open re-ejecuta desde 9. Mitigar con `PRAGMA journal_mode` estándar y sin cambios de otras tablas.
- **Cascada del `deleteLoan`**: si el `income` inicial o los `loan_payment`s tienen `deleted_at != null` por otro motivo previo (edición extraña), la cascada los deja igual (ya estaban borrados). Documentado como comportamiento esperado.
- **Balance derivado on-the-fly**: si `journal_entries` crece mucho (miles de pagos) sin índice, `balanceOf` puede degradar. Mitigar con índice `idx_entries_loan` propuesto en el schema. Alerta si aparece lag en el Dashboard con muchos préstamos.
- **Auto-cierre `paid` en `registerLoanPayment`**: si el usuario overpaga el saldo por accidente, el préstamo cierra automáticamente. Al eliminar el pago overpaga, se reabre (RN-L12). El ciclo es consistente pero puede sorprender. Mitigar con snackbar al momento del auto-cierre: "Préstamo pagado en su totalidad."
- **UX de `close_reason`**: distinguir "Pagado" vs "Cerrado manual" en la UI es sutil. Diferentes badges + copys en menús + copy explícito en diálogos.
- **Deep link a `entry_form_screen` de un `loan_payment`**: si el usuario llega ahí (por history push desde `/entries`), tiene que ver el modo read-only claro. Riesgo de confusión si el banner no es suficientemente prominente. Mitigar con banner con acento naranja + copy explícito.
- **Backup v2 incompatible con app v1**: si Diego exporta v2 y por alguna razón instala una versión previa de la app, el import falla con `unsupported_version`. Documentar como comportamiento esperado; la app previa nunca supo de préstamos.
- **`AccountsDao.deleteAccount` con nueva pre-check**: los tests existentes de `deleteAccount` pueden romperse si algún test creó una cuenta con préstamo asociado. Revisar en implementación.
- **RN-L05 (`payment_day` limitado a 1-28)**: si algún banco de Diego cobra el 30 del mes, tiene que aproximar. Documentado en el copy del form. Alternativa futura: aceptar 29-31 con lógica de "último día del mes si no existe".
- **Renglón sintético del reporte**: `spending_by_category` retorna una lista mezclada de categorías reales y una sintética. Si algún caller filtra por `id in tabla categorías`, se rompe. Mitigar exportando el token especial `kLoanInterestSyntheticId` y auditando callers en implementación.
- **Cuenta destino tipo `credit`**: hoy la UI del `loan_form_screen` filtra el picker a cash|debit. Si por bug algún deep-link creara un préstamo con destino credit, el income inicial subiría la deuda de la tarjeta (por la lógica invertida de credit balance). El DAO valida el tipo en `create` con `invalid_account_type` como cinturón adicional.

## Supuestos

- `SegmentedButton` de M3 sigue disponible (ya usado en el sprint `flutter-accounts-archive-v1`).
- El helper `AmountFormatter` y el `AmountInputFormatter` existentes soportan el input del split sin cambios.
- El AppBar del Dashboard tiene espacio para un nuevo entry point (`Icons.request_quote_outlined`) junto a los existentes de Categorías y Settings. Si no cabe, se agrupa en un menú overflow — decisión menor de implementación.
- `showDestructiveDialog` acepta chips de impacto con conteos dinámicos (validado en el sprint anterior).
- Los tests del harness `pumpFincoreApp` toleran seed extra de préstamos sin cambios profundos.
- El chip "PRÓXIMO PAGO" acepta layout horizontal desplazable en el Dashboard sin conflicto con el layout actual de KPIs.
- El `income` inicial se muestra en `/entries` como cualquier otro income, con el chip `· préstamo` en `movement_row` como única señal visual.
- Backup v2 no requiere migración de exports v1 en disco (no hay archivos históricos que corregir; export es on-demand).
- El nombre `LoansDao` sigue la convención de los DAOs existentes (`AccountsDao`, `EntriesDao`, `CategoriesDao`).
- `close_reason` como columna string separada es más legible que un enum numérico. Migración futura a enum tipado si el modelo crece.
- No hay conflicto con el módulo de weekly budgets — los préstamos son independientes y no aparecen en el planeador.
- El bump minor (`0.26.0 → 0.27.0`) refleja "feature de dominio grande + schema bump" siguiendo el patrón del sprint anterior.
- La UI de "Ver ingreso inicial" desde `loan_detail_screen` abre el `entry_form_screen` en modo read-only ya definido en RF-018; no requiere pantalla nueva.

## Impacto esperado

- Diego puede reflejar sus préstamos (BBVA, futuros de casa/carro) en FinCore con separación clara entre capital pagado e intereses reales. El spending reportado deja de estar inflado.
- El Dashboard gana visibilidad del saldo pendiente y del próximo pago, reduciendo el olvido y los cargos moratorios reales del banco.
- El módulo queda listo para adaptar a próximos casos (préstamos de casa a 20 años, autofin, líneas de crédito personales) sin cambios estructurales — sólo agregar registros nuevos.
- La libreta local sigue siendo pasiva: no perseguirá al usuario, no cobrará moratorios propios, no complicará la app con lógica bancaria de tabla dinámica. Diego mantiene el control declarativo total.
- Backup JSON v2 sienta las bases para futuros bumps (v3 podría agregar préstamos que Diego DA, plantillas de amortización asistida, etc.) manteniendo forever la compatibilidad hacia atrás.
- El histórico contable gana una entidad nueva de peso equivalente a Account. Prepara el modelo para futuras entidades derivadas (contratos, suscripciones, financiamientos) sin re-arquitectura.
