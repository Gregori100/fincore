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
flutter test                            # 56 tests
flutter analyze                         # 0 errores

# Build release para sideload
flutter build apk --release --split-per-abi
~/Android/Sdk/platform-tools/adb install -r build/app/outputs/flutter-apk/app-arm64-v8a-release.apk

# Regenerar icono adaptive + monochrome
dart run flutter_launcher_icons
```

## Dominio

### Modelo: Cuentas + Categorías + Journal Entries

- **Account** (`lib/data/database.dart` tabla `accounts`): UUID v7 PK. `type ∈ { cash, debit, credit }`. La **Bolsa** es singleton: `type=cash`, `is_protected=true`, creada por `seedDefaults` al "Arrancar limpio". Los credit guardan `credit_limit`, `closing_day`, `payment_day`, `interest_rate`, `minimum_payment_pct`. Acepta `description` (texto libre, máx 200).
- **Category** (tabla `categories`): UUID v7 PK. `name`, `applies_to ∈ { income, expense, both }`, `color_slug` (1 de 10 colores curados), `icon_slug` (1 de ~30 iconos curados). Slugs en `lib/constants/category_catalog.dart`. SoftDelete: archived es terminal sin reactivación.
- **JournalEntry** (tabla `journal_entries`): UUID v7 PK. `kind ∈ { income, expense, credit_expense, debt_payment, transfer }`. `account_origin_id` y `account_destination_id` opcionales según kind. Soft delete para cancelación.

### Kinds y reglas tipo↔cuenta (RN-011)

| kind | origin | destination | uso |
|---|---|---|---|
| `income` | null | cash/debit | dinero entra |
| `expense` | cash/debit | null | dinero sale |
| `credit_expense` | credit | null | cargo a tarjeta |
| `debt_payment` | cash/debit | credit | pago de tarjeta |
| `transfer` | cash/debit | cash/debit | mover entre cuentas |

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
├── database.dart           # Tablas drift + 6 índices + schemaVersion=1 + PRAGMA foreign_keys=ON
├── database.g.dart         # Generado por build_runner (no editar)
├── uuid.dart               # UuidV7 compatible con backend Laravel HasUuids
├── daos/
│   ├── accounts_dao.dart   # CRUD + validaciones (Bolsa singleton, duplicate name, ...)
│   ├── categories_dao.dart # CRUD + slugs válidos
│   └── entries_dao.dart    # registerIncome/Expense/CreditExpense/DebtPayment/Transfer + updateEntry + cancel
├── financial_state.dart    # Streams reactivos cacheados BO/DE/CR + balance por cuenta
├── seed.dart               # Bolsa + 10 categorías default (idempotente)
├── bootstrap.dart          # hasBolsa(db) para decidir redirect inicial
└── backup.dart             # Export + Import + wipeAll (JSON v1 idéntico al backend legacy)
```

### Reglas clave de los DAOs

- Toda mutación corre dentro de `db.transaction(...)`.
- `accountsDao.update` se llama `updateAccount` para no chocar con `DatabaseConnectionUser.update`. Idem `updateCategory`, `updateEntry`.
- `EntriesDao` valida tipos de cuenta por kind (RN-011) antes de cualquier otra cosa.
- `accountBalanceNow(id)` sincrónico para Action que necesita el balance dentro de una transacción.
- `watchAccountBalance(id, type)` para UI reactiva.

### Backup JSON v1

Mismo formato que el `/api/finance/backup/export` del backend legacy. Bit a bit compatible:

```json
{
  "version": 1,
  "exported_at": "ISO 8601",
  "accounts": [...],
  "categories": [...],
  "journal_entries": [...]
}
```

Export: serializa solo activos (`deleted_at IS NULL`). Import: reemplazo total (`wipeAll()` + insert) dentro de transacción. Errores tipados: `invalid_json`, `unsupported_version`, `missing_bolsa`, `invalid_reference`.

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

`lib/widgets/error_snackbar.dart` mapea cada código a un mensaje amigable en español.

## Tests

```bash
cd mobile
flutter test
```

Cobertura: **56 tests verdes** en 4 suites:

- `test/data/database_test.dart` (29): schema, PRAGMA FK, AccountsDao, CategoriesDao, EntriesDao por los 5 kinds, seed.
- `test/data/financial_state_test.dart` (12): BO/DE/CR, stream reactivo, archive, balance sincrónico vs stream.
- `test/data/backup_test.dart` (7): round-trip, JSON inválido, version > 1, missing Bolsa, FK rota, idempotencia, BD vacía.
- `test/data/invariants_test.dart` (8): libreta libre, RN-011, OverpayDebt, archivadas, categorías incompatibles.

**Tests usan SQLite in-memory** (`NativeDatabase.memory()`). En Linux desktop el override de `libsqlite3.so.0` está en `test/helpers/sqlite_override.dart` (patrón dogear).

**Widget tests (T043-T045) aplazados**: documentado en `engineering/specs/flutter-local-mvp/implementation/desviaciones-plan.md`. Para próximos sprints, agregar al menos `entry_form_screen` bootstrap test.

## Convenciones del repo

- Lenguaje: **español** para comentarios de dominio, mensajes de UI, commits y documentación. Identificadores en inglés.
- `flutter analyze` debe quedar en 0 errores antes de commit. Un hint cosmético en `widgets/skeleton.dart:75` (`prefer_const_constructors`) es tolerable.
- Bump de version en 3 lugares por release:
  1. `pubspec.yaml`: `version: X.Y.Z+N`
  2. `android/app/build.gradle.kts`: `versionCode = N` + `versionName = "X.Y.Z"`
  3. `lib/screens/settings_screen.dart`: `const String kAppVersion = 'X.Y.Z+N'`
- Las preguntas/desviaciones/decisiones de cada sprint viven en `engineering/specs/<slug>/`.
- Skills `spec-*` se usan para definir/planear/implementar/clarificar specs. `branch-quality-review` se invoca al cierre de cada sprint.

## Decisiones de pivote (2026-06-12 → 2026-06-17)

1. Cliente online → app local-first por fricción de red en uso real (Tailscale + cert TLS).
2. `mobile/` se mantiene como nombre del proyecto (mismo `applicationId = io.github.gregori100.fincore`).
3. Diego arrancó la BD desde cero, sin migrar movimientos del backend.
4. Schema preparado para sync futuro: UUIDs v7 + soft delete + timestamps en todas las tablas, sin features SQLite-only.
5. Backup JSON v1 idéntico al backend legacy para poder importar respaldos antiguos si hace falta.
