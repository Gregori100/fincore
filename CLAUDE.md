# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project vision

**FinCore** es una app **Flutter Android local-first single-user** para llevar una libreta digital de cuentas. SQLite con drift es la única fuente de verdad. Sin red en runtime, sin login, sin servidor. Inspirada en el modelo de dogear: el archivo local es el producto.

El backend Laravel y el frontend Vue original siguen vivos en la rama `legacy/web-and-online-flutter` pero **están fuera del scope actual**. Si Diego en el futuro decide agregar sync con backend, será una spec aparte.

## Estructura del repo

```
fincore/
├── mobile/                                # App Flutter (único producto activo en main)
├── engineering/specs/flutter-local-mvp/   # Spec, plan, implementation del sprint actual
├── CLAUDE.md                              # Este archivo
└── README.md                              # Pitch breve + setup
```

Ramas:

- `main`: solo `mobile/` + `engineering/` + docs root.
- `legacy/web-and-online-flutter`: backend Laravel + frontend Vue + cliente Flutter online + Docker stack + scripts CLI + tests E2E. Preservado por si Diego necesita exportar JSON antiguo o consultar la arquitectura previa.

## Stack y comandos clave

Toda la app vive en `mobile/`. Detalles completos en `mobile/README.md`.

```bash
cd mobile

# Setup inicial
flutter pub get
dart run build_runner build --delete-conflicting-outputs

# Desarrollo
flutter run -d linux                    # iterar UI en desktop
flutter run -d android                  # cel conectado por USB
flutter test                            # 112 tests
flutter analyze                         # 0 errores

# Build release para sideload
flutter build apk --release --split-per-abi
~/Android/Sdk/platform-tools/adb install -r build/app/outputs/flutter-apk/app-arm64-v8a-release.apk

# Regenerar icono adaptive + monochrome
dart run flutter_launcher_icons
```

## Dominio

### Modelo: Cuentas + Categorías + Journal Entries

- **Account** (`lib/data/database.dart` tabla `accounts`): UUID v7 PK. `type ∈ { cash, debit, credit }`. La **Bolsa** es singleton: `type=cash`, `is_protected=true`, creada por `seedDefaults` al "Arrancar limpio". Los credit guardan `credit_limit` (NOT NULL DEFAULT 0 desde schema v5), `closing_day`, `payment_day`, `interest_rate`, `minimum_payment_pct`. Las tasas se guardan como decimal 0-1 (compat backup legacy: `0.05` = 5%); `interest_rate` y `minimum_payment_pct` quedan en schema por compat backup pero la UI ya no los expone. Acepta `description` (texto libre, máx 200).
- **Category** (tabla `categories`): UUID v7 PK. `name`, `applies_to ∈ { income, expense, both }`, `color_slug` (1 de 10 colores curados), `icon_slug` (1 de ~30 iconos curados). Slugs en `lib/constants/category_catalog.dart`. SoftDelete: archived es terminal sin reactivación.
- **JournalEntry** (tabla `journal_entries`): UUID v7 PK. `kind ∈ { income, expense, credit_expense, debt_payment, transfer, loan_payment }`. `account_origin_id` y `account_destination_id` opcionales según kind. Los `loan_payment` guardan además `loan_id`, `principal_amount`, `interest_amount` e `is_monthly_payment`. Soft delete para cancelación.
- **LoanAdjustment** (tabla `loan_adjustments`, sprint `flutter-loans-flexible-payments-v1`): UUID v7 PK. `loan_id`, `amount` (centavos **con signo**: `+` sube la deuda, `−` la baja, nunca `0`), `reason` opcional (máx 200), `occurred_at`. Corrige el saldo pendiente **sin tocar `principal_amount`**. No es un movimiento de dinero: no genera `journal_entry` ni altera BO/DE/CR. Soft delete.
- **Loan** (tabla `loans`, sprint `flutter-loans-v1`): UUID v7 PK. `name`, `principal_amount`, `monthly_payment`, `initial_duration_months`, `current_duration_months`, `payment_day` (1-28), `contract_date`, `destination_account_id` (cash/debit — inmutable). Estados: activo (`closed_at IS NULL`), `paid` (auto tras saldo ≤ 0), `manual` (cerrado por usuario). Soft delete cascada income + pagos.

### Kinds y reglas tipo↔cuenta (RN-011)

| kind | origin | destination | uso |
|---|---|---|---|
| `income` | null | cash/debit | dinero entra |
| `expense` | cash/debit | null | dinero sale |
| `credit_expense` | credit | null | cargo a tarjeta |
| `debt_payment` | cash/debit | credit | pago de tarjeta |
| `transfer` | cash/debit | cash/debit | mover entre cuentas |
| `loan_payment` | cash/debit | null | pago mensual / abono a capital de un préstamo (`loan_id` obligatorio, `principal + interest = amount`, sólo desde `/loans/:id`) |

### Balance derivado

`FinancialStateService` calcula todo on-the-fly con `customSelect(sql, readsFrom: {accounts, journalEntries}).watchSingle()` (drift cachea hasta que cambia alguna tabla):

- **cash/debit**: `Σ destination.amount − Σ origin.amount`.
- **credit**: `Σ origin.amount − Σ destination.amount` (invertido: cargos suben deuda, pagos la bajan).
- **BO** = Σ balance(cash + debit). **DE** = Σ balance(credit). **CR** = Σ (credit_limit − balance(credit)).

### Filosofía "libreta libre"

Los gastos, transfers y cargos a tarjeta se permiten **siempre**, incluso si dejan saldo negativo o exceden `credit_limit`. La UI marca en rojo/warning pero no bloquea. Única excepción contable: `OverpayDebt` en `PayCreditAccount` (no podés pagar más de lo que debés a una tarjeta).

## Capa de datos (`mobile/lib/data/`)

```
data/
├── database.dart           # Tablas drift + índices + schemaVersion=15 + PRAGMA foreign_keys=ON
├── database.g.dart         # Generado por build_runner (no editar)
├── uuid.dart               # UuidV7 compatible con backend Laravel HasUuids
├── daos/
│   ├── accounts_dao.dart   # CRUD + validaciones (Bolsa singleton, duplicate name, ...)
│   ├── categories_dao.dart # CRUD + slugs válidos
│   ├── entries_dao.dart    # registerIncome/Expense/CreditExpense/DebtPayment/Transfer + register/update/deleteLoanPayment + updateEntry + cancel
│   └── loans_dao.dart      # CRUD préstamos + balanceOf reactivo + closeManual/reopen + applyPaymentSideEffects + watchMonthsOverdue
├── financial_state.dart    # Streams reactivos cacheados BO/DE/CR + balance por cuenta + total loans
├── seed.dart               # Bolsa + 10 categorías default (idempotente)
├── bootstrap.dart          # hasBolsa(db) para decidir redirect inicial
└── backup.dart             # Export + Import + wipeAll (emite JSON v3 en centavos; import acepta v1/v2/v3)
```

### Reglas clave de los DAOs

- Toda mutación corre dentro de `db.transaction(...)`.
- `accountsDao.update` se llama `updateAccount` para no chocar con `DatabaseConnectionUser.update`. Idem `updateCategory`, `updateEntry`.
- `EntriesDao` valida tipos de cuenta por kind (RN-011) antes de cualquier otra cosa.
- `accountBalanceNow(id)` sincrónico para Action que necesita el balance dentro de una transacción.
- `watchAccountBalance(id, type)` para UI reactiva.
- **Token `kUncategorizedFilterToken` en `EntriesDao.watchPage`** (sprint `flutter-reports-drilldown-parity-v1`): la definición operativa de "Sin categoría" en el DAO se amplía cuando el filtro `kinds` está restringido a un único tipo de flujo, para alinear el drill-down con los reportes por categoría:
  - `kinds == ['income']` → agrupa `category_id IS NULL` + categoría archivada + categoría con `applies_to = 'expense'` (edge legacy: una categoría income que fue editada a expense post-facto sin quitarle sus entries).
  - `kinds ⊆ {'expense', 'credit_expense'}` (no vacío) → agrupa `category_id IS NULL` + archivada + `applies_to = 'income'` (edge simétrico).
  - `kinds` `null`, vacío, mixto ingreso+gasto, o con `transfer`/`debt_payment` → solo `category_id IS NULL` + archivada (comportamiento clásico). No hay "opuesto" único.
  - La expansión aplica al filtro programático desde reportes (drill-down) y al filtro manual desde el sheet de `/entries`. Los reportes `ReportsService.incomeByCategory` y `spendingByCategory` usan el filtro simétrico en el `ON` del LEFT JOIN (`applies_to != 'expense'` / `applies_to != 'income'`) para blindar el mismo edge.

### Migraciones de schema (RN-H02 del sprint flutter-local-hardening)

- `schemaVersion` se incrementa **solo cuando** existe una implementación correspondiente en `MigrationStrategy.onUpgrade` de `mobile/lib/data/database.dart`.
- La función `onUpgrade` arranca con un guardrail: tras agotar las ramas `if (from == X && to == Y) { ... return; }` conocidas, lanza `UnimplementedError('Schema upgrade $from → $to no implementado...')`. Esto convierte cualquier bump accidental en crash visible en QA en lugar de corrupción silenciosa de datos.
- Cualquier PR que toque las definiciones de tablas o el valor de `schemaVersion` **está obligado** a agregar la rama correspondiente antes del throw final, escribir el `CREATE INDEX`/`ALTER TABLE`/`customStatement` adecuado y conservar el guardrail.
- Las migraciones son aditivas siempre que se pueda: nunca `DROP TABLE` ni `DROP COLUMN` con datos del usuario. Si la operación es destructiva, exigir un export JSON previo desde Settings y documentar el flujo en `pendientes.md` del sprint.

### Joins con categorías archivadas

- `Category` usa soft delete (`deletedAt`). Las archivadas son terminales: ni se reactivan ni se borran físicamente. La relación de drift desde `JournalEntry` devuelve `null` cuando la categoría apunta a un registro archivado.
- **Convención**: cualquier lectura desde la UI o desde un DAO que joinee `categories` debe filtrar por `deletedAt.isNull()` o llamar a `categoriesDao.findActiveById(id)` para evitar mostrar categorías fantasma. `findActiveById` retorna `null` si la categoría no existe **o** está archivada; es el helper canónico para validar antes de un write.
- En `EntriesDao.updateEntry`, si la `categoryId` heredada apunta a una categoría archivada, el write fuerza `categoryId = null` sin lanzar error (RN-H03). El badge desaparece y el FK colgante se limpia. Comportamiento consistente con la libreta libre.

### Montos en centavos enteros (sprint `flutter-integer-cents-v1`, schema v14)

**Todos los montos monetarios son `int` en centavos.** `$173.77` se guarda y se maneja como `17377`. Esto elimina de raíz la clase de bugs de precisión IEEE 754 que antes se mitigaba con tolerancias `+ 0.005` parcheadas caso por caso.

- **RN-IC-01**: `int` es el tipo canónico de moneda. Cero `double` para montos en schema, DAOs, `ReportsService` o UI.
- **RN-IC-02**: `double` queda reservado para ratios `0-1` (`interest_rate`, `minimum_payment_pct`, `minimum_capital_pct`), porcentajes de UI (`usedPct`, `percent`) y umbrales interpolados (cuartiles `p25/p50/p75` de los heatmaps). Ninguno es un monto.
- **RN-IC-03**: toda entrada de usuario se parsea con `parseCents` (vía `parseFormattedAmount`). Rechaza más de 2 decimales en vez de truncar en silencio.
- **RN-IC-04**: todo display pasa por `formatCents`. Nunca `.toString()` sobre un int de centavos ni `/ 100` ad-hoc.
- **RN-IC-05**: las comparaciones de montos son estrictas (`>`, `<`, `==`). **Cualquier tolerancia tipo `+ 0.005` que aparezca es un bug**, no una defensa.

Helpers en `mobile/lib/utils/money.dart`: `parseCents`, `formatCents`, `formatCentsCompact`, `centsFromDouble` (sólo para backup legacy y migración; usa `round`, nunca `toInt`), `centsToDouble` (sólo para compat externa).

Consecuencia lateral: un `int` de Dart no puede ser NaN ni Infinity, así que los guards `isFinite` del dominio desaparecieron. Sólo sobreviven donde validan un `double` crudo de entrada externa (payload de backup v1/v2).

**Migrar una columna monetaria nueva**: declararla `IntColumn` y, si tiene default, expresarlo en centavos (`minimum_floor` pasó de `150` a `15000`). La conversión de una columna REAL existente va por `m.alterTable` con `columnTransformer`, nunca por `UPDATE` — SQLite tiene *type affinity* y un `UPDATE` sobre una columna declarada REAL vuelve a guardar el valor como REAL.

### Préstamos flexibles (sprint `flutter-loans-flexible-payments-v1`, schema v15)

El modelo original asumía que todo préstamo se paga **una vez al mes**. El préstamo real de Diego es quincenal, así que esa suposición se retiró:

- **RN-LF-01**: se admiten **N** pagos con `is_monthly_payment = 1` en el mismo mes calendario. El error `duplicate_monthly_payment` ya no existe.
- **RN-LF-02**: un abono a capital se registra en cualquier fecha, con o sin pago del mes previo. El error `capital_before_monthly` ya no existe.
- **RN-LF-03**: `is_monthly_payment` sobrevive como **etiqueta descriptiva** en el historial ("Pago del mes" vs "Abono a capital"), sin poder de validación.
- **RN-LF-04**: eliminar un pago nunca arrastra otros. La cascada `cascadeCapitalInMonth` se retiró junto con el candado que la justificaba.
- **RN-LF-12**: el Dashboard no calcula atraso por mes calendario. El chip rojo "N meses atrasados" y todo `watchMonthsOverdue` desaparecieron; sobrevive el chip naranja de próximo pago basado en `payment_day`.
- **RN-LF-13**: el `CategoryPicker` no tiene sección de "recientes". Era un MRU en memoria de proceso que aparecía y desaparecía sin patrón visible.

**Saldo de un préstamo (RN-LF-05)** — tres términos:

```
saldo = principal_amount + Σ(ajustes.amount) − Σ(pagos.principal_amount)
```

`principal_amount` es **inmutable como concepto histórico**: es lo que te prestaron y ningún ajuste lo modifica (RN-LF-06).

**Ojo**: la fórmula vive duplicada en dos sitios y los dos deben cambiar juntos — `LoansDao._balanceSql` (por préstamo) y `FinancialStateService._buildTotalLoansSource` (agregado del Dashboard). El segundo no puede reusar el primero porque agrega sobre todos los préstamos activos.

**Ajustes de saldo**: dos asimetrías deliberadas frente a los pagos. Se puede ajustar un préstamo **cerrado** (RN-LF-10 — es el caso de uso central: el banco corrige algo que la app dio por liquidado, y el ajuste lo reabre si el saldo vuelve a ser positivo), y se acepta `occurred_at` anterior a `contract_date` (un ajuste puede estar corrigiendo la captura del monto original). Un ajuste que dejaría el saldo negativo se rechaza con `invalid_adjustment` (RN-LF-07); el cálculo corre **dentro de la transacción** y la edición se excluye a sí misma del saldo base.

`recalculateLoanState` (antes `applyPaymentSideEffects`) es la reevaluación de estado del préstamo ante cualquier cambio de saldo: la disparan los pagos y también las tres mutaciones de ajuste.

**Cascada al eliminar un préstamo**: `deleteLoan` marca `deleted_at` en el préstamo, sus `journal_entries` (income inicial + pagos) **y sus ajustes**. Omitir los ajustes producía un export con referencias huérfanas que hacía el respaldo entero no importable. El export además filtra defensivamente los ajustes cuyo préstamo no se está exportando.

`reason` está limitado a 200 caracteres en el DAO, en el import y en el formulario. Los tres deben moverse juntos.

### Backup JSON v4

Bumpeado a v3 en `flutter-integer-cents-v1` (montos en centavos) y a **v4** en `flutter-loans-flexible-payments-v1` (clave `loan_adjustments`). Los montos se emiten como `int` en centavos:

```json
{
  "version": 4,
  "exported_at": "ISO 8601",
  "accounts": [...],
  "categories": [...],
  "journal_entries": [{ "amount": 17377, ... }],
  "loans": [...],
  "loan_adjustments": [{ "amount": 10000, "loan_id": "...", ... }]
}
```

Export siempre emite v4. Import acepta v1, v2, v3 y v4:

- **v1/v2**: los montos vienen como `double` en unidades; se validan `isFinite` y se convierten con `centsFromDouble`.
- **v3/v4**: los montos deben ser `int`. Un `double` se rechaza con `invalid_amount_format` — no se convierte en silencio, porque rompería la invariante del formato.
- **v1/v2/v3**: sin `loan_adjustments`; se trata como lista vacía.

El historial: v1 era bit a bit compatible con `/api/finance/backup/export` del backend legacy; v2 agregó `loans` + los campos de split; v3 cambió la unidad; v4 agregó los ajustes de saldo. **v3+ ya no es importable por el backend Laravel** (fuera de scope; necesitaría su propio converter).

**Ruptura hacia atrás en cada bump de formato**: un export v4 no lo lee la 0.33.0. Antes de instalar una versión que suba el formato hay que dejar en `~/fincore-respaldos/` el APK saliente y un export con el formato viejo — bajar de versión obliga a desinstalar, y eso borra la BD.

Export: serializa solo activos (`deleted_at IS NULL`). Import: reemplazo total (`wipeAll()` + insert) dentro de transacción. Errores tipados: `invalid_json`, `unsupported_version`, `invalid_amount_format`, `missing_bolsa`, `invalid_reference`.

`weekly_budgets` / `weekly_budget_items` / `saved_views` / `app_preferences` NO se exportan (decisión de diseño). Las vistas guardadas, al persistir filtros de monto en JSON, discriminan payloads legacy por tipo: un `double` es pre-v14 en unidades, un `int` ya son centavos.

Decisión de diseño: **subsegundos en `occurred_at` se preservan** gracias a `build.yaml` con `store_date_time_values_as_text: true`. Sin esto el round-trip rompía la igualdad de timestamps.

## Capa de presentación (`mobile/lib/screens/`, `widgets/`)

### Router

`lib/router/app_router.dart` con `go_router` 14.6:

```
/splash      (initialLocation)
/first-run
/dashboard
/accounts
/accounts/new
/accounts/:id/edit
/categories
/categories/new
/categories/:id/edit
/entries
/entries/new
/entries/:id/edit
/settings
```

`FirstRunState` es un `ValueNotifier<bool?>` pasado como `refreshListenable`. Estados:
- `null`: chequeando (`hasBolsa()` corriendo) → redirect a `/splash`.
- `false`: BD vacía → redirect a `/first-run`.
- `true`: hay Bolsa → redirect a `/dashboard`.

**Convención de navegación**:
- `context.push('/X')` para abrir sub-pantallas (apila en el stack, back nativo del cel funciona).
- `Navigator.of(context).maybePop()` para volver al sitio anterior.
- `context.go('/dashboard')` solo para resets de stack intencionales (post-alta de movimiento, `markFirstRunComplete`).

### Estructura visual

- **Splash**: logo `Fin` + `Core` con spinner azul.
- **First-run**: dos cards (Importar respaldo / Arrancar limpio).
- **Dashboard**: 3 cards BO/DE/CR + lista cuentas + lista últimos movimientos. AppBar con wordmark + Categorías + Settings. FAB extended "+ Movimiento".
- **Accounts list / form**: CRUD con DropdownMenu M3. Bolsa es read-only.
- **Categories list / form**: CRUD con preview live del badge (color + icon).
- **Entries list**: paginada con filtros (kind + cuenta) en bottom sheet con safe area.
- **Entry form**: `KindPicker` contextual (no editable en edición) → `AccountPicker` + `AccountBalanceHint` (saldo/deuda reactivo) + monto + fecha + descripción + `CategoryPicker` (si el kind acepta).
- **Settings**: Organización (Categorías), Respaldo (Export/Import), Zona peligrosa (Reiniciar cuenta), Acerca de, Legacy.

### Tema

`lib/theme/fincore_colors.dart`:

- **Accent**: `#4CABDB` (azul cyan, color principal).
- **Canvas**: `#1F242B` (fondo oscuro).
- **Surface**: `#272D35` / surfaceElevated `#333B44`.
- **Positive**: `#50CC8E` (ingresos). **Negative**: `#E05959` (gastos). **Warning**: `#EBBD52`.
- **Catálogo de categorías**: 10 colores curados (blue, green, red, orange, purple, pink, teal, yellow, indigo, gray).

### Widgets reutilizables clave

- `FincoreLogo`: wordmark "Fin" azul + "Core" blanco con tagline opcional.
- `Skeleton` + `SkeletonCard`: placeholders animados con pulse, usados en todas las listas mientras los streams cargan.
- `AccountPicker` + `CategoryPicker`: DropdownMenu M3 con width del field.
- `AccountBalanceHint`: chip reactivo bajo el picker con saldo (cash/debit) o deuda + disponible (credit).
- `error_snackbar.dart`: 3 tipos (success / warning / error) con icono + dismiss on tap. Floating con margin lateral.
- `BaseCard`, `ConfirmDialog`, `AmountFormatter`, `CategoryBadge`, `KindPicker`, `AccountTypePicker`, `AppliesToPicker`, `ColorPicker`, `IconPicker`.

## Reglas de diseño clave

- **Todo el dominio vive en los DAOs**, no en los screens. Los DAOs lanzan `EntriesDaoError` / similares con código tipado.
- **Streams cacheados** en el State de las pantallas: recrear solo cuando cambia el filtro, no en cada `setState`.
- **Soft delete terminal**: archivar/cancelar es definitivo. La única manera de "recuperar" es importar un respaldo anterior.
- **Single-user**: no hay `userId`. La BD entera es del usuario del cel.
- **Sin reactivación, sin tombstones**: simplificación del modelo aprovechando que es single-user. Si en el futuro se agrega sync con backend, se evalúa qué cambia.
- **APK firmado con clave debug**: suficiente para sideload. Para Play Store hay que generar clave de release y agregar `signingConfigs.release` en `android/app/build.gradle.kts`.

## Errores tipados

Los DAOs lanzan errores con código y mensaje. Los mismos códigos del backend legacy para mantener UX consistente:

| code | DAO | bloquea |
|---|---|---|
| `overpay_debt` | `EntriesDao.registerDebtPayment` | sí |
| `invalid_account_type` | `EntriesDao` (todos los registers + updateEntry) | sí |
| `invalid_credit_limit` | `AccountsDao.create/updateAccount` | sí |
| `invalid_credit_metadata` | `AccountsDao.create/updateAccount` | sí |
| `duplicate_account_name` | `AccountsDao.create/updateAccount` | sí |
| `account_not_empty` | `AccountsDao.archive` | sí |
| `protected_account` | `AccountsDao.updateAccount/archive` | sí |
| `duplicate_category_name` | `CategoriesDao.create/updateCategory` | sí |
| `invalid_category_applies_to` | `EntriesDao + CategoriesDao` | sí |
| `invalid_color_slug` / `invalid_icon_slug` | `CategoriesDao` | sí |
| `immutable_journal_field` | `EntriesDao.updateEntry` | sí |
| `not_found` | `EntriesDao.findById` | sí |
| `unsupported_version` / `missing_bolsa` / `invalid_reference` / `invalid_json` | `BackupService.importFromJson` | sí |
| `overpay_loan` | `EntriesDao.registerLoanPayment/updateLoanPayment` | sí |
| `invalid_adjustment` | `LoansDao.registerAdjustment/updateAdjustment` | sí |
| `invalid_loan_split` | `EntriesDao.registerLoanPayment/updateLoanPayment` | sí |
| `payment_before_contract` | `EntriesDao.registerLoanPayment/updateLoanPayment` | sí |
| `loan_closed` | `EntriesDao.registerLoanPayment` | sí |
| `immutable_loan_payment` | `EntriesDao.updateEntry/cancel` sobre `loan_payment`/`loan_income` | sí |
| `immutable_loan_field` | `LoansDao.updateLoan` | sí |
| `account_in_use_by_loan` | `AccountsDao.archive/deleteAccount` | sí |
| `cannot_reopen_paid` | `LoansDao.reopen` | sí |

`lib/widgets/error_snackbar.dart` mapea cada código a un mensaje amigable en español.

## Tests

```bash
cd mobile
flutter test
```

Cobertura: **112 tests verdes** distribuidos entre capa de datos (70) y widget tests (16) más helpers (3).

Capa de datos:

- `test/data/database_test.dart` (30): schema, PRAGMA FK, AccountsDao, CategoriesDao, EntriesDao por los 5 kinds, seed, regresión RF-005 del v2.
- `test/data/financial_state_test.dart` (24): BO/DE/CR (con replay-1 desde v4), stream reactivo, archive, balance sincrónico, cache invalidation, broadcast multi-suscriptor, replay-1 + RF-012 v3 + RF-008/009 v4.
- `test/data/backup_test.dart` (8): round-trip, JSON inválido, version > 1, missing Bolsa, FK rota, idempotencia, BD vacía + M3 v2 (200 chars exactos).
- `test/data/invariants_test.dart` (8): libreta libre, RN-011, OverpayDebt, archivadas, categorías incompatibles.

Capa UI (v3):

- `test/helpers/widget_test_harness_test.dart` (3): smoke del `pumpFincoreApp`.
- `test/screens/entry_form_screen_test.dart` (2): cancel + submit en edit. Blinda regresión gray screen.
- `test/screens/dashboard_screen_test.dart` (2): BD vacía + con datos.
- `test/screens/entry_form_kinds_test.dart` (5): un test por kind, valida labels según RN-011.
- `test/screens/list_screens_test.dart` (4): accounts + categories render + tap → form de edición.

**Tests usan SQLite in-memory** (`NativeDatabase.memory()`). En Linux desktop el override de `libsqlite3.so.0` está en `test/helpers/sqlite_override.dart` (patrón dogear).

**Convención del tearDown** (sprint `flutter-local-hardening-v4`, DV-5): NO llamar `state.invalidateAll()` antes de `db.close()` en tearDowns. El `database.close()` es suficiente: drift cancela las queries upstream y los streams se completan limpio. Llamar `invalidateAll()` mientras un widget tree sigue montado (caso del harness) cierra los `MultiStreamController` con listeners activos y deja microtasks pendientes que cuelgan `pumpAndSettle` del siguiente test del isolate. `invalidateAll()` queda como API runtime (para `BackupService.wipeAll()` etc.), no como protocolo de cleanup en tests.

**Widget tests (sprint `flutter-local-hardening-v3`)**: el harness `mobile/test/helpers/widget_test_harness.dart` (`pumpFincoreApp(tester, {initialRoute, seed, seedBolsa})`) monta la app con BD in-memory para widget tests. Cubre las pantallas core con 16 tests: dashboard, entry_form (cancel/submit en edit + los 5 kinds), accounts list, categories list. Reusable para sprints futuros de UI. Detalles en `engineering/specs/flutter-local-hardening-v3/implementation/`.

## Convenciones del repo

- Lenguaje: **español neutral** para comentarios de dominio, mensajes de UI, commits y documentación. Identificadores en inglés. Nunca voseo rioplatense (`pagás/podés/tenés/acá`); usar `tienes/puedes/aquí`. El test `mobile/test/language/no_voseo_test.dart` blindea `mobile/lib/` contra regresión.
- `flutter analyze` debe quedar en 0 errores antes de commit. Un hint cosmético en `widgets/skeleton.dart:75` (`prefer_const_constructors`) es tolerable.
- Bump de version en 2 lugares por release (desde el sprint `flutter-local-hardening`):
  1. `pubspec.yaml`: `version: X.Y.Z+N`
  2. `android/app/build.gradle.kts`: `versionCode = N` + `versionName = "X.Y.Z"`
  - `lib/screens/settings_screen.dart` ya no tiene `kAppVersion` hardcoded: lee de `PackageInfo.fromPlatform()` vía `package_info_plus` (RF-016).
  - **Validación local** (sprint `flutter-local-hardening-v3`): `scripts/verify-apk.sh` compara `versionCode` del APK (con prefix 2000 del `--split-per-abi` arm64) contra `+N` esperado por `pubspec.yaml`. Correr antes de `adb install -r` para evitar `INSTALL_FAILED_VERSION_DOWNGRADE` por olvido de sincronía entre pubspec/gradle.
- Las preguntas/desviaciones/decisiones de cada sprint viven en `engineering/specs/<slug>/`.
- Skills `spec-*` se usan para definir/planear/implementar/clarificar specs. `branch-quality-review` se invoca al cierre de cada sprint.

### Política de `ndkVersion` (RF-017)

- `android/app/build.gradle.kts` declara `ndkVersion = "27.0.12077973"` hardcoded porque los plugins nativos del proyecto lo requieren (`sqlite3_flutter_libs`, `file_picker`, `share_plus`, `path_provider_android`, etc.).
- Revisar tras cada `flutter upgrade`: si el `flutter.ndkVersion` default sube a 28+ y todos los plugins lo soportan, bumpear la línea y eliminar el override.
- No volver a `ndkVersion = flutter.ndkVersion` mientras algún plugin del proyecto exija una versión superior al default.

### Política de dependencias `^` flotantes (RF-018)

- `pubspec.yaml` usa `^` en todas las deps clave (`drift`, `go_router`, `sqlite3_flutter_libs`, `package_info_plus`, etc.) para iteración rápida.
- **No ejecutar `flutter pub upgrade`** sin revisar los changelogs de `drift`, `go_router` y `sqlite3_flutter_libs` (los tres con mayor superficie en el código). Cualquier bump de minor de esos paquetes puede romper queries, redirects o el binding nativo.
- Antes de un release "estable" (commit a `main` con APK distribuido) considerar pinear las críticas a versión exacta y validar que `flutter test` + `flutter analyze` siguen verdes.

## Sistema de tokens de diseño (sprint flutter-design-tokens-v1)

FinCore usa un sistema de tokens explícito para tipografía, spacing, radios, alphas y motion. Fuente única en `mobile/lib/theme/`:

- **`fincore_typography.dart`** — 7 `const TextStyle`: `displayXL` (56/800), `headingL` (20/700), `headingM` (16/600), `bodyM` (14/400 default), `bodyS` (13/500 chip/badge), `label` (12/600 muted metadata), `overline` (11/600/1.2 subtle upper).
- **`fincore_spacing.dart`** — 7 `const double`: `kSpace2xs=2`, `kSpaceXs=4`, `kSpaceSm=8`, `kSpaceMd=12`, `kSpaceLg=16`, `kSpaceXl=24`, `kSpace2xl=32`. Semánticos derivados: `kEdgeCard`, `kEdgeListItem`, `kEdgeDialog`, `kEdgeScreen`, `kFabClearance=96`.
- **`fincore_radii.dart`** — 5 `const double`: `kRadiusSm=6`, `kRadiusMd=8`, `kRadiusLg=12`, `kRadiusXl=20` (dialogs/sheets), `kRadiusPill=999`.
- **`fincore_colors.dart`** (extendido) — 4 alphas semánticos: `alphaHover=0.08`, `alphaHairline=0.12`, `alphaTint=0.15`, `alphaSelected=0.20`. Usar como `FincoreColors.accent.withValues(alpha: FincoreColors.alphaTint)`.
- **`fincore_motion.dart`** — 5 `const Duration`: `kMotionInstant=100ms`, `kMotionFast=200ms`, `kMotionMedium=300ms`, `kMotionSlow=500ms`, `kMotionPulse=1100ms`. 4 `const Curve`: `kCurveStandard`, `kCurveExit`, `kCurveEmphasized` (M3), `kCurveLinear`.

El `textTheme` en `fincore_theme.dart` cablea los 15 slots M3 a los 7 tokens tipográficos con `fontSize` explícito. Consumir vía `Theme.of(context).textTheme.bodyMedium` o vía import directo (`import 'package:fincore/theme/fincore_typography.dart' show bodyM;`) cuando el widget es `const`.

### Reglas vinculantes

- **Prohibido** `TextStyle(fontSize: N)` inline en widgets/screens (salvo `fincore_typography.dart` que define los tokens, y `fincore_logo.dart` que usa `fontSize` proporcional documentado).
- **Prohibido** `SizedBox(height: N)` o `SizedBox(width: N)` con `N` literal fuera de la escala de spacing.
- **Prohibido** `BorderRadius.circular(N)` con `N` literal fuera de la escala de radios.
- **Prohibido** `Color.withValues(alpha: N)` con `N` literal fuera de la escala de alphas.
- **Prohibido** `Duration(milliseconds: N)` en animaciones sin usar `kMotionX`.
- **Contenido de alto fijo**: en celdas de `GridView` con `childAspectRatio`, envolver los textos en `Flexible`. Un ratio ajustado a ojo se rompe con etiquetas largas o con la escala de fuente del sistema; `Flexible` evita el desborde estructuralmente. Ojo: las franjas de desborde sólo se pintan en debug, así que en release el síntoma es un recorte silencioso.

Excepciones puntuales se marcan en el sitio con `// token-exception: <razón>`. Meta: mantenerlas ≤ 10 en toda la app; si un valor no cabe recurrentemente (≥3 usos), evaluar si falta un token en vez de multiplicar excepciones.

Cambiar el valor de un token afecta a toda la app; requiere PR dedicada + comparación visual + smoke Android.

### Convenciones adicionales del sistema de diseño

- **Iconografía**: `Icons.xxx_outlined` por default; `Icons.xxx` (filled) solo para estados "current" (tab activo, item seleccionado en NavBar) o "selected" (chip seleccionado, picker item).
- **Dialogs**: `ConfirmDialog` (`widgets/confirm_dialog.dart`) para acciones reversibles o de bajo impacto ("¿Descartar cambios?"). `DestructiveDialog` (`widgets/destructive_dialog.dart`) para irreversibles con impacto en datos ajenos (archivar cuenta con movimientos, wipe BD, importar respaldo).
- **Colores semánticos reservados**:
  - `FincoreColors.positive/negative` → **dinero** (ingreso verde, gasto rojo, saldo negativo).
  - `FincoreColors.accent` → **affordance/acción** (FAB, links, chips seleccionados, primary buttons).
  - `FincoreColors.warning` → **alertas operativas** (fecha de pago próxima, límite excedido). **NO** usar para tipos de cuenta (credit sigue mapeado a `warning` en `dashboard_screen._typeColor`; migrar a `textMuted` o color propio en el sprint que toque Dashboard).
  - `FincoreColors.categoryX` (10 colores curados) → **taxonomía** de categorías del usuario. Nunca para señalizar estado.

### Alcance del piloto (sprint 1) y siguientes sprints

El sprint 1 (`flutter-design-tokens-v1`) migró **solo los widgets compartidos** de `mobile/lib/widgets/*.dart`. Screens (`mobile/lib/screens/**`) y widgets locales de features (`mobile/lib/screens/weekly_budgets/widgets/`) quedan para sprints por módulo. Cualquier PR nueva sobre esos archivos debe migrar el archivo tocado a tokens en el mismo cambio (regla "boy scout").

## Decisiones de pivote (2026-06-12 → 2026-06-17)

1. Cliente online → app local-first por fricción de red en uso real (Tailscale + cert TLS).
2. `mobile/` se mantiene como nombre del proyecto (mismo `applicationId = io.github.gregori100.fincore`).
3. Diego arrancó la BD desde cero, sin migrar movimientos del backend.
4. Schema preparado para sync futuro: UUIDs v7 + soft delete + timestamps en todas las tablas, sin features SQLite-only.
5. Backup JSON v1 era idéntico al backend legacy; hoy el export es v3 (centavos enteros) y el import sigue aceptando v1/v2 para respaldos antiguos.
