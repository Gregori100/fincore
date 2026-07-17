# Plan de pruebas — flutter-loans-v1

## Casos borde detectados

- **Préstamo con `principal_amount = 0`**: rechazar con `invalid_loan_data` (forma sin sentido).
- **`initial_duration_months = 0` o negativo**: rechazar. Valor mínimo 1.
- **`monthly_payment = 0` o negativo**: rechazar. Valor mínimo > 0.
- **`payment_day` fuera de 1-28**: rechazar con `invalid_payment_day`. Copy explica meses cortos.
- **`payment_day = 31` sobre año bisiesto en febrero**: no aplica porque rango es 1-28. Documentado.
- **`contract_date` en el futuro**: se acepta (Diego puede pre-cargar préstamos futuros). Sin validación.
- **`name` vacío**: rechazar con `invalid_loan_data`. Min 1 char, trim.
- **`name` con 500+ chars**: aceptar hasta 100, cortar o rechazar. Preferencia: max 100 chars con validador cliente.
- **Cuenta destino tipo credit**: rechazar con `invalid_account_type` en `LoansDao.create`.
- **Cuenta destino inexistente / eliminada**: rechazar con `invalid_reference` o `not_found`.
- **Cuenta destino archivada**: rechazar en `create` (no ofrecerla en picker + validar en DAO). Un préstamo ya creado con esa cuenta como destino sigue vivo si la cuenta se archiva después.
- **Overpay accidental**: `registerLoanPayment` con `principal_amount > balance actual` deja saldo negativo. Auto-cierre paid dispara igual. Snackbar informa.
- **Split `principal = 0, interest = amount`**: se acepta (mes de gracia). Saldo no cambia.
- **Split `principal = amount, interest = 0`**: se acepta (abono directo a capital).
- **Split `principal + interest ≠ amount`**: rechazar con `invalid_loan_split` (tolerancia `< 0.005`).
- **Split con valores negativos**: rechazar. `principal ≥ 0`, `interest ≥ 0`.
- **`amount = 0`**: rechazar con `invalid_amount`. Sólo pagos positivos.
- **Cuenta origen archivada**: rechazar en `registerLoanPayment` con `invalid_account_type`. UI no la ofrece.
- **Cuenta origen credit**: rechazar con `invalid_account_type`. UI no la ofrece.
- **Cuenta origen inexistente / eliminada**: rechazar.
- **Préstamo cerrado (paid o manual) al momento de registrar pago**: rechazar con `loan_closed`. UI no muestra FAB de pagos.
- **Préstamo eliminado**: `registerLoanPayment` sobre él es imposible (el préstamo no existe en la lista de watchers). Si por deep-link llega, DAO valida `deleted_at IS NULL`.
- **Deletar pago sobre préstamo `paid`**: reabre automático si saldo vuelve a >0. Si el pago era interés puro (`principal = 0`), el saldo no cambia y el préstamo sigue `paid`.
- **Deletar pago sobre préstamo `manual`**: no reabre (manual es acción explícita). El saldo cambia pero el estado se mantiene.
- **Deletar pago sobre préstamo eliminado**: no debería ocurrir (los pagos también están eliminados por cascada). Si por bug llega, `deleteLoanPayment` retorna sin efecto.
- **`updateEntry` sobre income inicial de préstamo**: rechazar con `immutable_loan_payment`.
- **`updateEntry` sobre `loan_payment`**: rechazar con `immutable_loan_payment`.
- **`updateEntry` sobre entry normal con `loan_id = null`**: sigue funcionando como hoy.
- **`AccountsDao.archive` sobre cuenta destino de préstamo activo**: se permite (archivar no rompe el préstamo).
- **`AccountsDao.deleteAccount` sobre cuenta destino de préstamo activo**: rechazar con `account_in_use_by_loan`.
- **`AccountsDao.deleteAccount` sobre cuenta destino de préstamo cerrado (no eliminado)**: rechazar igual.
- **`AccountsDao.deleteAccount` sobre cuenta destino de préstamo eliminado**: permitir (el préstamo está soft-deleted, no bloquea).
- **`AccountsDao.deleteAccount` cascada normal (sin préstamo asociado)**: sin cambio, funciona como hoy.
- **Backup export sin préstamos**: JSON v2 con `loans: []`.
- **Backup import v1 vacío**: funciona, `loans = []` en la BD.
- **Backup import v2 con `loans = []`**: funciona.
- **Backup import v2 con `loan_id` en entry pero `loans` no contiene ese id**: `invalid_reference`.
- **Backup import v2 con `close_reason` inválido**: `invalid_loan_data`.
- **Backup import v0 / v3 / string / null**: `unsupported_version`.
- **Backup import sobre app v1 (rollback tras exportar v2)**: `unsupported_version` (versión > `_supportedVersion` de la app previa). Documentado.
- **`spendingByCategory` sin `loan_payment`s en el periodo**: no renderiza fila sintética.
- **`spendingByCategory` con `loan_payment`s pero todos con `interest = 0`**: total sintético = 0, no renderiza fila.
- **`spendingByCategory` con múltiples préstamos**: fila sintética suma intereses de todos.
- **Fila sintética con `total > totales de categorías reales`**: se ordena primera (DESC por total).
- **Fila sintética drilldown**: tap no navega (no-op) o navega a `/loans` — decisión de UX en implementación (default no-op).
- **KPI naranja con 0 préstamos activos**: no se renderiza.
- **KPI naranja con préstamo activo pero saldo=0** (transitorio antes del auto-cierre): teóricamente no existe (auto-cierre ocurre en la misma transacción). Si aparece por bug, KPI muestra $0.
- **Chip PRÓXIMO PAGO con `daysUntil = 0`**: aparece con copy "hoy".
- **Chip PRÓXIMO PAGO con `daysUntil < 0`**: no aparece (se calcula para el próximo mes automáticamente).
- **Chip PRÓXIMO PAGO con múltiples préstamos vencidos el mismo día**: uno por cada uno.
- **`entry_form_screen` con entry cuya loan_id apunta a préstamo eliminado (edge case por bug)**: banner igual aparece pero el enlace "Ver préstamo" navega a una pantalla vacía. Documentar como no-crítico.
- **Cambio de `monthly_payment` post-abono**: sólo altera default de próximo pago; pagos históricos no se recalculan.
- **`current_duration_months < initial_duration_months`**: aceptado (Diego pagó anticipado).
- **`current_duration_months = 0`**: aceptado (interpretación: "en curso hasta que saldo=0").
- **Concurrencia**: no aplica (single-user).
- **Timezone**: `payment_day` es int, `daysUntil` local. `occurredAt` guarda con `store_date_time_values_as_text: true` (patrón repo).

## Pruebas unitarias necesarias

### `test/data/loans_dao_test.dart`:

- `create({name, principal, monthly, duration, paymentDay, contractDate, destAccountId})` genera Loan + income inicial en la misma transacción con `loan_id = loan.id`.
- `create` con cuenta destino tipo credit → `invalid_account_type`.
- `create` con cuenta destino archivada → `invalid_account_type` o `account_archived`.
- `create` con cuenta destino inexistente → `not_found`.
- `create` con `payment_day = 0`, `29`, `31`, `-5` → `invalid_payment_day`.
- `create` con `principal = 0` o negativo → `invalid_loan_data`.
- `create` con `monthly_payment = 0` o negativo → `invalid_loan_data`.
- `create` con `initial_duration_months = 0` o negativo → `invalid_loan_data`.
- `create` con `name` vacío o solo espacios → `invalid_loan_data`.
- `updateLoan` con name/monthly_payment/current_duration/payment_day/contract_date → OK.
- `updateLoan` con `principal_amount != null` → `immutable_loan_field`.
- `updateLoan` con `destination_account_id != null` → `immutable_loan_field`.
- `closeManual(id)` sobre préstamo abierto → `closed_at + close_reason = 'manual'`.
- `closeManual` sobre préstamo ya cerrado → no-op silencioso o `loan_already_closed` (decisión: no-op).
- `reopen(id)` sobre préstamo `manual` → limpia campos, préstamo activo.
- `reopen` sobre préstamo `paid` → `cannot_reopen_paid`.
- `reopen` sobre préstamo abierto → no-op silencioso.
- `deleteLoan(id)` cascada sobre income + pagos, todos con `deleted_at != null` tras la operación.
- `deleteLoan` recomputa balance de cuenta destino (income cancelado sube el saldo pendiente que estaba).
- `watchActive()` excluye cerrados y eliminados.
- `watchClosed()` incluye paid y manual, excluye activos y eliminados.
- `findById()` devuelve cerrados; retorna null para eliminados.
- `balanceOf` con 0 pagos = `principal_amount`.
- `balanceOf` con N pagos = `principal - Σ principal_amount`.
- `balanceOf` ignora pagos con `deleted_at != null`.
- `countActivePayments` retorna N.

### `test/data/loan_payments_test.dart`:

- `registerLoanPayment` happy path: crea entry con kind=loan_payment, campos correctos, saldo baja.
- `registerLoanPayment` valida split (`principal + interest = amount` tolerancia).
- `registerLoanPayment` con `principal < 0` o `interest < 0` → `invalid_loan_split`.
- `registerLoanPayment` con `amount = 0` o negativo → `invalid_amount`.
- `registerLoanPayment` con `principal + interest != amount` (fuera de tolerancia) → `invalid_loan_split`.
- `registerLoanPayment` con cuenta origen credit → `invalid_account_type`.
- `registerLoanPayment` con cuenta origen archivada → `invalid_account_type`.
- `registerLoanPayment` con cuenta origen eliminada → `not_found` o `invalid_account_type`.
- `registerLoanPayment` sobre préstamo cerrado (paid o manual) → `loan_closed`.
- `registerLoanPayment` sobre préstamo eliminado → `not_found`.
- `registerLoanPayment` que deja saldo=0 → auto-cierre paid, `close_reason='paid'`.
- `registerLoanPayment` que deja saldo negativo (overpay) → auto-cierre paid.
- `registerLoanPayment` que deja saldo>0 → préstamo sigue abierto.
- `deleteLoanPayment` sobre pago normal (préstamo abierto) → saldo sube, préstamo sigue abierto.
- `deleteLoanPayment` sobre pago cuyo delete deja saldo>0 sobre préstamo paid → reapertura auto (limpia closed_at + close_reason).
- `deleteLoanPayment` sobre pago cuyo delete deja saldo=0 (sigue paid) → sin reapertura.
- `deleteLoanPayment` sobre pago cuyo delete deja saldo>0 sobre préstamo manual → NO reapertura.
- `deleteLoanPayment` con pago de sólo interés (principal=0) → saldo no cambia, sin reapertura.
- `deleteLoanPayment` sobre entry inexistente → no-op o `not_found`.
- `updateEntry` sobre `loan_payment` → `immutable_loan_payment`.
- `updateEntry` sobre income inicial (`loan_id != null && kind='income'`) → `immutable_loan_payment`.
- `updateEntry` sobre entry normal → sigue funcionando.

### `test/data/invariants_test.dart` (extensión):

- `AccountsDao.deleteAccount` sobre cuenta destino de préstamo activo → `account_in_use_by_loan`.
- `AccountsDao.deleteAccount` sobre cuenta destino de préstamo cerrado (paid/manual) → mismo error.
- `AccountsDao.deleteAccount` sobre cuenta destino de préstamo eliminado → OK (permite).
- `AccountsDao.archive` sobre cuenta destino de préstamo activo → OK (archivar permitido).
- `AccountsDao.deleteAccount` sobre cuenta sin préstamos asociados → OK.

## Pruebas de integracion o API necesarias

No aplica (app local sin API HTTP).

## Pruebas de UI o flujo necesarias si aplica

### `test/screens/loan_form_screen_test.dart`:

- Modo create: llena todos los campos, tap "Crear préstamo" → loan + income aparecen en BD.
- Modo edit sobre préstamo activo: campos `principal_amount` y `destination_account_id` renderizan con `enabled: false`.
- Menú overflow AppBar en préstamo activo: `Cerrar manualmente`, `Eliminar`.
- Menú overflow en préstamo cerrado manual: `Reabrir`, `Eliminar`.
- Menú overflow en préstamo paid: sólo `Eliminar`; banner "Préstamo pagado" visible.
- Validador `payment_day = 31` bloquea submit.

### `test/screens/loan_detail_screen_test.dart`:

- Header muestra saldo actualizado en tiempo real cuando se agrega un pago.
- FAB dividido tiene "Pago del mes" y "Abono a capital"; ambos navegan a las rutas correctas.
- FAB oculto cuando préstamo cerrado.
- Lista de pagos muestra split visible por renglón.
- Enlace "Ver ingreso inicial" navega a entry_form_screen del income.
- Tap en un pago abre confirmDialog con Eliminar.

### `test/screens/dashboard_screen_test.dart` (extensión):

- Sin préstamos: KPI naranja no aparece.
- Con ≥1 préstamo activo: KPI naranja aparece con total correcto.
- Chip PRÓXIMO PAGO aparece cuando `daysUntil ≤ 5`.
- Chip no aparece cuando `daysUntil > 5` o `daysUntil < 0`.
- AppBar tiene nuevo icono `Icons.request_quote_outlined`.

### `test/screens/entry_form_screen_test.dart` (extensión):

- Editar un entry con `loan_id != null` renderiza banner naranja + enlace "Ver préstamo".
- Campos deshabilitados.
- Botón "Eliminar movimiento" deshabilitado.

### `test/screens/loans_list_screen_test.dart` (nuevo):

- SegmentedButton renderiza Activos | Cerrados.
- Segmento Activos con datos: cards visibles con saldo hero.
- Segmento Cerrados con datos: cards con opacidad + badge Pagado/Cerrado manual.
- FAB `+` sólo en Activos.
- Tap en card navega a /loans/:id.

## Pruebas de permisos y seguridad si aplica

No aplica. Single-user.

## Pruebas de datos, migracion o compatibilidad si aplica

- **Migración schemaVersion 9 → 10**:
  - Test de integración: BD sembrada manualmente con schemaVersion=9, `open()` la trae a v10 sin corrupción. Verificar que `loans` existe y que las 3 columnas nuevas de `journal_entries` están presentes.
  - Guardrail `UnimplementedError` sigue lanzando para transiciones no cubiertas (por ejemplo, `from == 10 && to == 11` futuro).
  - Migración multi-salto `from ∈ {6, 7, 8}` → 10 corre sin corrupción.

- **Backup JSON**:
  - `test/data/backup_test.dart` extensión:
    - Round-trip export v2 → import v2 con préstamos + pagos + splits preserva bit a bit.
    - Import de v1 (formato legacy) sobre app v2 funciona, `loans = []`, `loan_id` de todos los journal_entries queda null.
    - Import de v2 con `destination_account_id` inexistente → `invalid_reference`.
    - Import de v2 con `loan_id` inexistente en un entry → `invalid_reference`.
    - Import de v2 con `close_reason = 'unknown'` → `invalid_loan_data`.
    - Import de v0/v3/string → `unsupported_version`.
    - Import de v2 con `loans = []` y sin campos loan en entries → OK, es v2 sin préstamos.

## Pruebas de regresion sobre flujos existentes

- BO/DE/CR en dashboard: valores idénticos antes y después de crear un préstamo (aunque el income inicial sube BO). Los préstamos no rompen fórmulas.
- `watchAccountBalance` sobre la cuenta destino de un préstamo: sube por el income y baja por cada pago; consistente con el patrón normal.
- Reportes existentes (`cashflow`, `top_movements`, `movements_calendar`, `income_by_category`, `spending_heatmap`, `income_heatmap`, `balance_at_date`, `monthly_average`, `credit_cards`, `budgets`): salen bit a bit iguales cuando NO hay préstamos. Cuando hay, `cashflow` refleja las salidas totales de los pagos, `spending_by_category` gana la fila sintética, el resto sigue igual.
- `movement_row` renderiza correctamente para entries normales (sin chip `· préstamo`).
- `entry_form_screen` en modo edit sobre un entry NORMAL (sin `loan_id`): sigue editable como hoy.
- `AccountsDao.deleteAccount` sobre cuenta sin préstamos: sigue funcionando como hoy (cascada de journal_entries).
- Suite completa: `flutter test` verde con ≥ 780 tests (base 735 + ≥ 45 nuevos).

## Pruebas manuales o smoke tests necesarios

En APK release arm64 instalado en cel (20 items):

1. Abrir `/loans` desde AppBar del Dashboard. Estado vacío visible ("Aún no tienes préstamos").
2. Tap FAB `+`. Formulario de creación. Rellenar: name="BBVA Personal", principal=37300, monthly=1758, duration=36, payment_day=5, contract_date=hoy, destination=Bolsa.
3. Confirmar. En `/loans` aparece el préstamo activo con saldo pendiente $37,300.
4. Dashboard: KPI naranja "PRÉSTAMO" aparece con $37,300. Bolsa subió $37,300 (BO reflejó el income).
5. Ir a `/entries` y ver el income inicial de $37,300 con chip pequeño "· préstamo" en el subtítulo.
6. Editar ese income: form entra en modo read-only con banner naranja + enlace "Ver préstamo".
7. Volver a `/loans`, tap en el préstamo → detalle. Header muestra saldo. FAB dividido con "Pago del mes" + "Abono a capital".
8. Tap "Pago del mes". Form con amount=1758 default, split editable. Meter `principal=1200, interest=558`. Cuenta origen = Bolsa.
9. Registrar. Bolsa baja $1758. Saldo del préstamo baja a $36,100. Reporte `/reports/spending-by-category` del mes actual muestra renglón "Intereses de préstamos: $558".
10. Tap "Abono a capital" desde el detalle. Meter $5,000 desde Bolsa. Bolsa baja $5,000. Saldo baja a $31,100. El abono aparece en `/entries` con chip `· préstamo` pero NO aparece en `spending_by_category` (es capital).
11. Editar el contrato (menú overflow → "Editar contrato"). Cambiar `current_duration_months` a 20 y `monthly_payment` a $2500. Guardar. Los campos `principal_amount` y `destination_account_id` están deshabilitados con helper visible.
12. Intentar cambiar la cuenta destino del préstamo (deep-link vía dev tools o similar) → rechazado con `immutable_loan_field`.
13. Intentar eliminar la Bolsa: bloqueado con "Esta cuenta está atada al préstamo BBVA Personal".
14. Registrar múltiples pagos hasta que saldo = 0. El préstamo se cierra automáticamente. Snackbar "Préstamo pagado en su totalidad.". Desaparece del segmento Activos, KPI naranja se oculta, aparece en Cerrados con badge "Pagado" verde.
15. En el detalle de préstamo pagado: FAB oculto, menú overflow sólo con "Eliminar" (rojo), banner "Préstamo pagado" arriba.
16. Eliminar un pago desde el detalle: si el saldo vuelve a >0, el préstamo se reabre automáticamente (vuelve al segmento Activos, KPI reaparece).
17. Crear otro préstamo cualquiera. Cerrar manualmente desde el menú overflow. Confirmar con confirmDialog azul. Pasa a Cerrados con badge "Cerrado manual" naranja.
18. Desde el detalle del cerrado manual: menú overflow con "Reabrir". Reabrir → vuelve a Activos.
19. Eliminar préstamo con `DestructiveDialog` premium: hero icon + chip "N pagos se cancelarán" + chip "Ingreso inicial de $X en Bolsa se cancela" + chip "No se puede deshacer". Confirmar. El préstamo, el income y los pagos desaparecen. Bolsa refleja el ajuste (baja el income cancelado).
20. Exportar backup desde Settings. Verificar JSON: `version: 2`, `loans` populated con contratos activos + cerrados. Importar el mismo backup: round-trip funciona sin errores.

Bonus manuales:
- Verificar chip PRÓXIMO PAGO en Dashboard cuando el payment_day está a ≤5 días.
- Verificar que un préstamo con payment_day próximo aparece con "en X días" y al día del vencimiento aparece "hoy".

## Datos de prueba recomendados

- BD con:
  - 1 Bolsa (semilla).
  - 1 cuenta débito activa.
  - 1 cuenta crédito activa.
  - 1 cuenta débito archivada.
  - 2 préstamos activos (BBVA + otro), cada uno con 3 pagos históricos.
  - 1 préstamo cerrado paid (con todos los pagos que dejan saldo=0).
  - 1 préstamo cerrado manual (con saldo pendiente).
  - 1 préstamo eliminado (soft-deleted, no visible en UI pero presente en BD para tests).

Para tests unitarios: BD in-memory, seed manual con `LoansCompanion.insert` + `JournalEntriesCompanion.insert` que incluyen los nuevos campos.

## Comandos o validaciones locales sugeridas

```bash
cd /home/developer/Escritorio/proyectos/fincore/mobile
dart run build_runner build --delete-conflicting-outputs
flutter analyze
flutter test
flutter build apk --release --split-per-abi --target-platform android-arm64
../scripts/verify-apk.sh
```

## Criterios minimos para aprobar la implementacion

- `flutter analyze` sin errores nuevos (5 hints preexistentes de `prefer_const_constructors` en entry_form_screen tolerados).
- `flutter test` verde con ≥ 780 tests.
- APK arm64 build sin errores. versionCode = 110.
- Migración schemaVersion 9 → 10 corre sin corrupción en test de integración.
- Smoke manual: los 20 items verificados por Diego.
- Cero regresión en BO/DE/CR y reportes existentes.
- Backup round-trip funciona.
- KPI naranja aparece/desaparece correctamente.
- `spending_by_category` gana renglón sintético cuando corresponde.

## Validacion final recomendada

Si la skill `branch-quality-review` está disponible, invocarla sobre la rama antes del merge. Genera reporte en `engineering/quality-review/flutter-loans-v1/`.

Si no está disponible, checklist manual:
- Sin referencias sueltas a `EntriesDao.updateEntry` sobre entries con `loan_id`.
- `ReportsService.spendingByCategory` es el único caller con lógica sintética; otros reportes no consultan `interest_amount`.
- `AccountsDao.deleteAccount` respeta la restricción de préstamos.
- Guardrail `UnimplementedError` intacto tras la rama nueva de `onUpgrade`.
- Copy consistente en español neutral (guardrail `no_voseo_test.dart` sigue verde).
- Sin comentarios TODO sin resolver en archivos tocados.
- Backup v2 valida referencias exhaustivamente.
