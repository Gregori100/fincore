# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project vision

**FinCore** is a personal finance tracker for multiple users, with web (Vue) and mobile (Flutter) clients. The API is the single contract for all clients. The backend models accounting concepts directly: any number of **accounts** per user (cash, debit, credit) and **journal entries** that move money between them.

## Monorepo structure

```
fincore/
├── backend/    # Laravel 12 API
├── frontend/   # Vue 3 SPA (Tailwind + Headless UI)
├── scripts/    # install.sh + fincore CLI (Docker stack management)
├── docs/       # Project docs — see docs/cli/, docs/scripts/, docs/api/, docs/frontend/
└── compose.yaml
```

## Commands

### Docker stack (recommended — run from repo root)

Full reference for both scripts lives in [`docs/scripts/`](./docs/scripts/README.md):
- [`install.md`](./docs/scripts/install.md) — `install.sh` step-by-step, port autodetect rules.
- [`fincore.md`](./docs/scripts/fincore.md) — every subcommand of the `fincore` manager.
- [`reset.md`](./docs/scripts/reset.md) — 4 reset levels, from DB-only to full nuke.

Quick reference:

```bash
./scripts/install.sh         # First-time setup (idempotent):
                             #   creates .env files, runs composer install via composer:2 image,
                             #   generates APP_KEY, builds sail image, starts pgsql+redis,
                             #   runs migrations + seeder (which creates the Bolsa account).

./scripts/fincore start      # Start all services in background
./scripts/fincore stop       # Stop services (containers preserved)
./scripts/fincore restart [svc]
./scripts/fincore down       # Stop and remove containers (confirms first)
./scripts/fincore status     # Table with state, health, ports per service
./scripts/fincore health     # curl /up on backend, port check on frontend
./scripts/fincore logs <svc> # Follow logs (tail 100)
./scripts/fincore migrate    # Run php artisan migrate inside api (accepts args, eg. --fresh --seed --force)
./scripts/fincore shell <svc>
./scripts/fincore rebuild    # Rebuild sail image and relaunch
./scripts/fincore            # Default: status
```

For the `fin:*` Artisan commands that run **inside** the `api` container, see [`docs/cli/`](./docs/cli/README.md).

### Backend — run from backend/ (requires PHP 8.2+, only for native dev without Docker)

```bash
cd backend
composer install
php artisan migrate --seed                 # seed creates the Bolsa account
composer dev                               # server + queue + pail + vite concurrently
php artisan test                           # SQLite in-memory; TestCase seeds Bolsa for every test
php artisan test tests/Feature/Finance/IncomeTest.php
php artisan test --filter=test_income_increases_bo
./vendor/bin/pint                          # Lint
```

### Frontend — run from frontend/

```bash
cd frontend
npm install
npm run dev       # http://localhost:5173
npm run build
```

### E2E tests (Playwright) — run from repo root

Los tests E2E viven en `tests-e2e/` como tercer workspace npm. Apuntan al stack Docker en `localhost:5173` (frontend) + `localhost:83` (api) + `localhost:8025` (Mailpit) — **el stack tiene que estar arriba**.

```bash
npm install                           # instala Playwright vía workspaces
cd tests-e2e && npx playwright install chromium   # solo la primera vez
npm run test:e2e                      # corre toda la suite (workers=1)
cd tests-e2e && npx playwright test --grep "logout"   # filtrar por nombre
cd tests-e2e && npm run test:ui       # modo interactivo
cd tests-e2e && npm run report        # abrir último reporte HTML
```

El `globalSetup` y un `beforeEach` por spec limpian el cache de Laravel (`php artisan cache:clear` vía `docker compose exec`) para evitar que `throttle:6,1` en `/auth/*` haga flaky a la suite. Cada test crea un usuario único con email `e2e-*@fincore.test` para no chocar con datos previos.

## Backend architecture (`backend/`)

Full REST API reference in [`docs/api/`](./docs/api/README.md). This section gives the architectural overview.

### Domain model: Users → Accounts → JournalEntries

Everything is scoped by `User`. Each user has:
- One **Bolsa** (`Account` with `type=cash`, `is_protected=true`), created automatically at registration by the `CreateUserBolsaAccount` listener.
- N additional `Account`s of type `debit` or `credit`.
- N `Category`s (10 default creadas al registrarse por `CreateUserDefaultCategories`).
- M `JournalEntry`s connecting them, opcionalmente categorizados.

> **IDs**: `users.id`, `accounts.id` y `journal_entries.id` son **UUID v7** generados por `HasUuids` (Laravel 12), no seriales. La columna polimórfica `tokenable_id` de Sanctum también es UUID (via `uuidMorphs`). Las Actions, el `FinancialStateService` y `FinanceController` reciben `string $id`. El frontend trata los IDs como opacos.

An **Account** (`app/Models/Account.php`) has one of three types:

- `cash` — physical money/wallet. **Singleton per user** named "Bolsa", `is_protected=true`. Cannot be deleted or renamed.
- `debit` — bank checking/debit accounts (N per user).
- `credit` — credit cards with `credit_limit`, `closing_day`, `payment_day`, `interest_rate`, `minimum_payment_pct`. The metadata is stored but no alert/interest engine exists yet (Phase 2).

Account también acepta un campo opcional `description` (texto libre, máx 200 caracteres). Es una anotación tipo "tarjeta principal · alias 1234"; se valida en `CreateAccount` / `UpdateAccount` (trim + max 200, cadena vacía → null) y se muestra en `/accounts/:uuid` del frontend.

Una **Category** (`app/Models/Category.php`) tiene `name`, `applies_to` (`income` | `expense` | `both`), `color_slug` (1 de 10 colores curados) e `icon_slug` (1 de ~30 iconos curados). Usa `SoftDeletes` (archivable, sin reactivación). El catálogo de slugs vive en `app/Domain/Finance/Catalog/CategoryDefaults.php` — esos slugs son contrato compartido con el frontend (`frontend/src/constants/categoryCatalog.js`). Al archivar (soft delete) una categoría, los `JournalEntry` que la referencian conservan `category_id` en BD pero la relación `category()` devuelve null (no usa `withTrashed`), así el badge desaparece de la UI. Sólo `income`, `expense` y `credit_expense` aceptan categoría; `transfer` y `debt_payment` no.

Each financial operation is a **JournalEntry** (`app/Models/JournalEntry.php`) with `account_origin_id` (where money leaves) and `account_destination_id` (where money lands). Either can be null:

| `kind` | origin | destination | Use case |
|--------|--------|-------------|----------|
| `income` | `null` | cash/debit | Money arrives from outside |
| `expense` | cash/debit | `null` | Money leaves to outside |
| `credit_expense` | credit | `null` | Charge on credit card (debt rises) |
| `debt_payment` | cash/debit | credit | Pay down a credit card |
| `transfer` | cash/debit | cash/debit | Move money between cash-like accounts |
| `adjustment` | — | — | Reserved, not yet implemented |

### Balance calculation

No persisted balances. Every balance is derived on demand by `FinancialStateService::getAccountBalance($id)`:

- **cash/debit**: `Σ destination.amount − Σ origin.amount` (intuitive — income raises, expense lowers).
- **credit**: `Σ origin.amount − Σ destination.amount` (**inverted** — charges raise debt, payments lower it). The returned balance represents *outstanding debt*.

The three aggregated metrics:
- **BO** = `Σ balance(account)` where type ∈ `(cash, debit)`.
- **DE** = `Σ balance(account)` where type = `credit`.
- **CR** = `Σ (credit_limit − balance(account))` where type = `credit`.

### Layer structure

```
app/
├── Http/Controllers/
│   ├── FinanceController.php                # Finance endpoints; scopes by request->user()->id
│   └── Auth/                                # Sanctum-backed auth endpoints
│       ├── RegisterController.php           # Fires Registered event (creates Bolsa + sends email)
│       ├── LoginController.php              # Returns bearer token
│       ├── LogoutController.php             # current() + all()
│       ├── MeController.php                 # Current user
│       ├── EmailVerificationController.php  # Signed URL verify + resend
│       └── PasswordResetController.php      # forgot() + reset()
├── Domain/Finance/
│   ├── Actions/                             # All take int $userId as first param
│   │   ├── CreateAccount.php                # Refuses TYPE_CASH (Bolsa is auto-created)
│   │   ├── UpdateAccount.php                # Rejects if is_protected; scoped by user
│   │   ├── DeleteAccount.php                # Rejects if is_protected or has entries; scoped
│   │   ├── RegisterIncome.php
│   │   ├── RegisterExpense.php              # Insufficient funds against the account's own balance
│   │   ├── RegisterCreditExpense.php
│   │   ├── PayCreditAccount.php             # Validates funds at origin AND not overpaying credit
│   │   └── RegisterTransfer.php             # cash/debit ↔ cash/debit only
│   ├── Services/FinancialStateService.php   # Takes int $userId in constructor
│   ├── Catalog/
│   │   └── CategoryDefaults.php             # Slugs permitidos de COLORS/ICONS + lista DEFAULTS (10)
│   ├── Reports/
│   │   ├── CategoryBreakdownReport.php      # Agrupa entries por category_id (con bucket "Sin categorizar")
│   │   ├── CashflowMonthlyReport.php        # Ingresos vs egresos por mes (excluye transfer + debt_payment)
│   │   ├── MonthlyComparisonReport.php      # Compara mes actual vs anterior por categoría (reusa CategoryBreakdownReport)
│   │   ├── CreditCardsReport.php            # Estado actual por tarjeta: deuda, % usado, ciclos, pago mínimo estimado
│   │   └── BudgetsReport.php                # Progreso del mes en curso contra `monthly_limit` por categoría
│   └── Exceptions/
│       ├── DomainException.php              # Base — renders to JSON {error, code}
│       ├── InsufficientFunds.php            # 422 — ya no se lanza (libreta libre)
│       ├── OverpayDebt.php                  # 422 — único bloqueo que se mantiene en pagos a tarjeta
│       ├── CreditLimitExceeded.php          # 422 — ya no se lanza (libreta libre)
│       ├── InvalidAccountType.php           # 422
│       ├── InvalidCreditLimit.php           # 422: nuevo limit < deuda o null
│       ├── InvalidCreditMetadata.php        # 422: closing_day == payment_day
│       ├── DuplicateAccountName.php         # 422: nombre duplicado por user
│       ├── AccountNotEmpty.php              # 422: archivar con saldo != 0
│       ├── ProtectedAccount.php             # 409
│       ├── DuplicateCategoryName.php        # 422: nombre duplicado de categoría
│       ├── InvalidCategoryAppliesTo.php     # 422: applies_to inválido o incompatible con kind
│       ├── InvalidColorSlug.php             # 422: color fuera del catálogo
│       ├── InvalidIconSlug.php              # 422: icono fuera del catálogo
│       └── ImmutableJournalField.php        # 422: campo no editable en PATCH /entries/{id}
├── Listeners/
│   ├── CreateUserBolsaAccount.php           # On Registered: creates the user's Bolsa
│   └── CreateUserDefaultCategories.php      # On Registered: crea las 10 categorías default
├── Providers/AppServiceProvider.php          # Registers listener + custom reset URL
├── Models/
│   ├── User.php             # HasApiTokens, MustVerifyEmail, Notifiable; hasMany(Account)
│   ├── Account.php          # constants TYPE_CASH/TYPE_DEBIT/TYPE_CREDIT + isCredit()/isCashLike()
│   ├── Category.php         # APPLIES_INCOME/EXPENSE/BOTH; scopeForKind() + appliesToKind()
│   └── JournalEntry.php     # KIND_* constants + SoftDeletes + relation category() (sin withTrashed)
└── Console/Commands/
    ├── Concerns/ResolvesUser.php            # Trait: resolves --user= flag for fin:* commands
    └── Fin*.php                             # All fin:* commands use the trait
```

### Auth flow (Sanctum + Bearer tokens)

Full API docs in [`docs/api/auth.md`](./docs/api/auth.md). Short version:

1. `POST /api/auth/register { name, email, password, password_confirmation }` → `201 { user, token }`. The `Registered` event fires and triggers:
   - `SendEmailVerificationNotification` (email goes through Mailpit in dev).
   - `CreateUserBolsaAccount` listener creates the user's Bolsa singleton.
2. `POST /api/auth/login { email, password }` → `200 { user, token }`.
3. Cliente envía `Authorization: Bearer <token>` en cada request a `/api/finance/*`.
4. Hasta que el usuario verifique su email, `/api/finance/*` devuelve `403` (middleware `verified`).
5. `POST /api/auth/logout` revoca el token actual; `POST /api/auth/logout-all` revoca todos.
6. Password reset: `POST /api/auth/password/forgot { email }` → email; `POST /api/auth/password/reset { token, email, password, password_confirmation }`.

### API routes (`routes/api.php`)

| Method | Path | Auth | Action |
|--------|------|------|--------|
| POST | `/auth/register` | public | Register + auto-create Bolsa + send verification email |
| POST | `/auth/login` | public | Returns bearer token |
| POST | `/auth/password/forgot` | public | Sends reset email |
| POST | `/auth/password/reset` | public | Performs password reset |
| GET | `/auth/email/verify/{id}/{hash}` | signed URL | Marks email as verified, redirects to FRONTEND_URL |
| GET | `/auth/me` | sanctum | Current user |
| POST | `/auth/logout` | sanctum | Revoke current token |
| POST | `/auth/logout-all` | sanctum | Revoke all user tokens |
| POST | `/auth/email/verification-notification` | sanctum | Resend verification email |
| GET | `/finance/state` | sanctum + verified | BO/DE/CR + accounts + recent entries + categories |
| GET | `/finance/entries` | sanctum + verified | Paginated entries (filtros `account_id`, `category_id`, `kind`, `from`, `to`) |
| PATCH | `/finance/entries/{id}` | sanctum + verified | UpdateJournalEntry. Editables: `category_id`, `description`, `occurred_at`, `account_origin_id`, `account_destination_id`, `amount` (>0). Sólo el `kind` queda inmutable; las cuentas nuevas deben respetar el tipo según el kind (validado por `validateAccountsForKind`). |
| DELETE | `/finance/entries/{id}` | sanctum + verified | CancelJournalEntry (soft delete; sin reactivación; sin validación de negativos) |
| GET | `/finance/accounts` | sanctum + verified | List accounts (acepta `?include_archived=1` para incluir soft-deleted) |
| POST | `/finance/accounts` | sanctum + verified | CreateAccount (debit/credit, cash forbidden) |
| PATCH | `/finance/accounts/{id}` | sanctum + verified | UpdateAccount |
| DELETE | `/finance/accounts/{id}` | sanctum + verified | DeleteAccount |
| GET | `/finance/categories` | sanctum + verified | List categories (acepta `?include_archived=1` y `?applies_to=income\|expense`) |
| POST | `/finance/categories` | sanctum + verified | CreateCategory |
| PATCH | `/finance/categories/{id}` | sanctum + verified | UpdateCategory |
| DELETE | `/finance/categories/{id}` | sanctum + verified | ArchiveCategory (soft delete) |
| GET | `/finance/reports/by-category` | sanctum + verified | CategoryBreakdownReport (kind, from, to, account_id opcional) |
| GET | `/finance/reports/cashflow-monthly` | sanctum + verified | CashflowMonthlyReport (from, to, account_id opcional). Sólo meses con actividad; el frontend rellena el resto. |
| GET | `/finance/reports/month-comparison` | sanctum + verified | MonthlyComparisonReport (kind, month=YYYY-MM, account_id opcional). Devuelve buckets por categoría con delta y delta_pct (null si previous=0). |
| GET | `/finance/reports/credit-cards` | sanctum + verified | CreditCardsReport. Sin parámetros. Devuelve por tarjeta: deuda, % usado, próximas fechas, ciclos y pago mínimo estimado. |
| GET | `/finance/reports/budgets` | sanctum + verified | BudgetsReport. Sin parámetros. Devuelve por categoría con `monthly_limit` (sólo `applies_to ∈ {expense, both}`): limit, spent, remaining, pct_consumed del mes en curso. |
| POST | `/finance/income` | sanctum + verified | RegisterIncome (acepta `category_id` opcional) |
| POST | `/finance/expense` | sanctum + verified | RegisterExpense (acepta `category_id` opcional) |
| POST | `/finance/credit-expense` | sanctum + verified | RegisterCreditExpense (acepta `category_id` opcional) |
| POST | `/finance/pay-credit` | sanctum + verified | PayCreditAccount |
| POST | `/finance/transfer` | sanctum + verified | RegisterTransfer |
| GET | `/finance/plan/events` | sanctum + verified | Lista eventos planeados del usuario |
| DELETE | `/finance/plan/events` | sanctum + verified | ClearPlannedEvents — borra todos los eventos del usuario en cascada con sus overrides |
| POST | `/finance/plan/events` | sanctum + verified | CreatePlannedEvent |
| PATCH | `/finance/plan/events/{id}` | sanctum + verified | UpdatePlannedEvent (borra overrides huérfanos al cambiar recurrencia y devuelve `removed_overrides`) |
| DELETE | `/finance/plan/events/{id}` | sanctum + verified | DeletePlannedEvent (cascada de overrides via FK) |
| POST | `/finance/plan/events/{eventId}/overrides` | sanctum + verified | CreatePlannedEventOverride |
| PATCH | `/finance/plan/overrides/{id}` | sanctum + verified | UpdatePlannedEventOverride |
| DELETE | `/finance/plan/overrides/{id}` | sanctum + verified | DeletePlannedEventOverride |
| GET | `/finance/plan/projection` | sanctum + verified | PlanProjectionService (horizonte HOY + 6 meses, sin caché) |

Rate-limited (`throttle:6,1`): register, login, password forgot/reset, verification resend.

### Domain error contract

Domain exceptions extend `Domain\Finance\Exceptions\DomainException`, which provides a `render()` method that returns a JSON payload `{ "error": "...", "code": "..." }`:

> **Libreta libre**: FinCore no bloquea movimientos por fondos ni por exceder el `credit_limit`. Los gastos, transfers y cargos a tarjeta se permiten siempre; cuando dejarían saldo negativo (o exceso de límite en una tarjeta) la UI lo marca con badge/warning pero la operación se acepta. **Única excepción**: `PayCreditAccount` sí valida `OverpayDebt` — pagar más de lo que se debe a una tarjeta deja saldo a favor, que no tiene sentido contable para la libreta personal.

| Exception | HTTP status | `code` |
|-----------|-------------|--------|
| `InsufficientFunds` | 422 | `insufficient_funds` (no se lanza hoy) |
| `OverpayDebt` | 422 | `overpay_debt` — única validación bloqueante de creación |
| `CreditLimitExceeded` | 422 | `credit_limit_exceeded` (no se lanza hoy) |
| `InvalidAccountType` | 422 | `invalid_account_type` |
| `InvalidCreditLimit` | 422 | `invalid_credit_limit` |
| `InvalidCreditMetadata` | 422 | `invalid_credit_metadata` |
| `DuplicateAccountName` | 422 | `duplicate_account_name` |
| `AccountNotEmpty` | 422 | `account_not_empty` |
| `ProtectedAccount` | 409 | `protected_account` |
| `DuplicateCategoryName` | 422 | `duplicate_category_name` |
| `InvalidCategoryAppliesTo` | 422 | `invalid_category_applies_to` |
| `InvalidColorSlug` | 422 | `invalid_color_slug` |
| `InvalidIconSlug` | 422 | `invalid_icon_slug` |
| `ImmutableJournalField` | 422 | `immutable_journal_field` |

Validation errors from `$request->validate()` still produce the standard Laravel 422 payload with `errors` keyed by field.

### CLI commands (`fin:*`)

All commands accept `--user=email` (optional if there's exactly one user; required otherwise). Trait `App\Console\Commands\Concerns\ResolvesUser` handles the resolution.

| Command | Signature | Description |
|---------|-----------|-------------|
| `fin:account:create` | `{name} {type} [--limit] [--closingDay] [--paymentDay] [--interest] [--minPct] [--user]` | Create debit or credit account |
| `fin:income` | `{accountId} {amount} {description?} [--user]` | Income into a cash/debit account |
| `fin:expense` | `{accountId} {amount} {description?} [--user]` | Expense from a cash/debit account |
| `fin:credit-expense` | `{accountId} {amount} {description?} [--user]` | Charge to a credit account |
| `fin:pay` | `{originId} {creditAccountId} {amount} {description?} [--user]` | Pay a credit account from a cash/debit one |
| `fin:state` | `[--user]` | Print BO/DE/CR, accounts table, last 10 entries |

### Key design rules

- All business logic lives in `Actions/`. Controllers only validate and delegate.
- Every Action takes `string $userId` (UUID) as its first parameter; all queries scope by `user_id` to enforce isolation.
- `FinancialStateService` takes `string $userId` in its constructor. Both Actions (for validation) and `FinanceController` consume it. `getAccounts(bool $includeArchived = false)` permite cargar también las soft-deleteadas para `/accounts`.
- Actions use `DB::transaction()` and throw domain exceptions on invalid state.
- **Soft delete**: `Account` uses Laravel's `SoftDeletes` trait. `DeleteAccount` Action triggers soft delete (sets `deleted_at`), only allowed when `balance == 0`. Archived accounts don't appear in dashboard listings or BO/DE/CR aggregates, but their `journal_entries` remain visible in `/entries` with origin/destination relations loaded via `withTrashed()` to preserve historical names. **No existe reactivación**; las archivadas son read-only.
- **Cancelación de movimientos**: `JournalEntry` también usa `SoftDeletes`. `CancelJournalEntry` Action marca `deleted_at`; el balance se ajusta automáticamente porque las queries de `FinancialStateService` respetan el scope global. Permite dejar saldos negativos (no se valida); el frontend muestra warning visual. Cancelar es terminal (sin reactivación) y bloquea futuras ediciones del entry (Eloquent lo oculta, `UpdateJournalEntry` lanza 404).
- **Concurrency**: the 5 mutation Actions (`RegisterIncome`/`Expense`/`CreditExpense`/`PayCreditAccount`/`RegisterTransfer`) load their account(s) with `lockForUpdate()` inside `DB::transaction()`. This serializes simultaneous requests on the same account and prevents race conditions that could leave negative balances. Multi-account Actions (`PayCreditAccount`, `RegisterTransfer`) acquire locks in `strcmp`-ascending UUID order to avoid deadlocks.
- The Bolsa account is created automatically by the `CreateUserBolsaAccount` listener when the `Registered` event fires. `DatabaseSeeder` is intentionally empty.
- `tests/TestCase.php` exposes a `createUserWithBolsa()` helper that replicates what the listener does (creates user + Bolsa).

## Frontend architecture (`frontend/`)

Full reference in [`docs/frontend/README.md`](./docs/frontend/README.md).

**Stack**: Vue 3 (Composition API + `<script setup>`) + Pinia + Vue Router + Axios + **Tailwind CSS v4** + **Headless UI** + **@vueuse/core** + **@heroicons/vue**. Tests con Vitest + @vue/test-utils + jsdom.

```
src/
├── api/
│   ├── client.js       # Axios + interceptors (Bearer + 401 handler)
│   ├── auth.js         # endpoints /api/auth/*
│   └── finance.js      # endpoints /api/finance/* (incluye categories + updateEntry)
├── stores/
│   ├── auth.js         # token (useStorage), user, login/logout/register/fetchMe
│   ├── finance.js      # state, accounts, recentEntries, categories + mutaciones + categoriesFor(kind)
│   └── toast.js        # feedback global
├── constants/
│   └── categoryCatalog.js  # COLORS, ICONS (heroicons), iconBySlug, cssVarBySlug
├── router/             # rutas + beforeEach guard (requiresAuth/requiresGuest)
├── components/
│   ├── layout/         # AppLayout (topbar Dashboard/Cuentas/Categorías/Movimientos) + AuthLayout
│   ├── ui/             # BaseButton, BaseInput, BaseTextarea, BaseSelect, BaseModal, ToastList,
│   │                   # BaseColorPicker, BaseIconPicker
│   └── finance/        # StateSummary, AccountCard, AccountList, RecentEntries, EntriesTable,
│                       # CategoryBadge, CategoryCard, EntryEditForm
│                       # + Forms (Account, Income, Expense, CreditExpense, PayCredit, Transfer,
│                       #          Category, CategoryEdit, AccountEdit)
└── views/
    ├── auth/           # LoginView, RegisterView, EmailVerifiedView, ForgotPassword, ResetPassword
    └── app/            # DashboardView, EntriesView, AccountsView, AccountDetailView, CategoriesView,
                        # ReportsByCategoryView, ReportsCashflowView, ReportsMonthComparisonView,
                        # ReportsCreditCardsView, ReportsBudgetsView (todas lazy-loaded)
```

Los reportes viven en sub-rutas de `/reports/*` con un subnav compartido (`ReportsSubnav.vue` con array de tabs — añadir un reporte nuevo es tocar un solo array). La estructura backend en `Domain/Finance/Reports/` permite añadir nuevos reportes replicando el patrón sin refactorizar.

**Patrones clave**:
- Token persistido en `localStorage` vía `useStorage` de `@vueuse/core`.
- Axios request interceptor lee el token del store; response interceptor dispara `auth.clear()` + redirect en 401.
- El binding store ↔ client es **perezoso** (vía `bindAuth`/`bindRouter` en `main.js`) para evitar ciclo de imports.
- Formularios viven en modales (`BaseModal` con Headless UI Dialog) abiertos desde el dashboard o desde `/accounts`.
- Tema oscuro único con CSS variables en `@theme` (Tailwind v4).
- Vite proxy: `/api` → `http://api`.
- `EntriesTable` es el componente reutilizable de tabla paginada de movimientos. `/entries` la usa sin filtro fijo; `/accounts/:uuid` la usa con `accountId` fijo.
- IDs en rutas: `/accounts/:uuid` espera un UUID v7. El parámetro se trata como string opaco.

## Docker services (`compose.yaml`)

| Service | Image | Port |
|---------|-------|------|
| `api` | Sail PHP 8.4 runtime (code requires PHP 8.2+) | 80 |
| `frontend` | node:22-alpine | 5173 |
| `pgsql` | postgres:17-alpine | 5432 |
| `redis` | redis:alpine | 6379 |
| `mailpit` | axllent/mailpit | 1025 (SMTP), 8025 (web UI) |

Backend uses Sail's default entrypoint (`start-container` → `supervisord` as root). Migrations are **not** run automatically on container startup — they are executed once by `scripts/install.sh` after `pgsql` is healthy, and on demand via `./scripts/fincore migrate` afterwards. Two `.env` files are needed, with separate templates:

- `.env` at repo root — config of the Docker stack (host ports, `WWWUSER`/`WWWGROUP`, Postgres credentials, xdebug). Template: `.env.example` at repo root.
- `backend/.env` — Laravel runtime config inside the container (APP_KEY, mail, cache, etc.). Template: `backend/.env.example`.

`scripts/install.sh` bootstraps both files and autodetects free host ports — if `APP_PORT=80`, `FORWARD_DB_PORT=5432`, etc., are already in use, it writes the next free port instead. `DB_DATABASE` / `DB_USERNAME` / `DB_PASSWORD` are duplicated on purpose between the two `.env` files: the root one is used by the Postgres container at init time, the backend one is what Laravel uses to connect — they must match.

## Plan (proyección financiera a 6 meses)

Subdominio nuevo en `backend/app/Domain/Finance/Plan/` paralelo a `Reports/`. Permite declarar eventos financieros futuros y simular cómo evolucionan los saldos por cuenta sin tocar `journal_entries` reales.

- **Dos entidades nuevas**: `PlannedEvent` (regla recurrente o evento one-off) y `PlannedEventOverride` (modificación de monto o "saltada" sobre una ocurrencia específica). Ambas con UUID v7. FKs a `accounts` con `ON DELETE RESTRICT` (cuentas con eventos vivos no se pueden hard-delete; soft delete vía `Account` sí, y el motor marca esas ocurrencias como `archived_account`).
- **Recurrencia**:
  - `weekly` con `recurrence_day` 0..6 (ISO 8601: 0=lunes, 6=domingo).
  - `monthly` con `recurrence_day` 1..31 (clamp al último día si el mes no lo tiene, ej. día 31 en febrero → 28/29).
  - `one_off`: ocurrencia única en `start_date`.
- **Overrides** identificados por `(planned_event_id, occurrence_date)` con unique constraint. Solo aplican a eventos `weekly`/`monthly`. La Action rechaza fechas que no caen en la regla (`override_on_non_occurrence`) y eventos `one_off` (`invalid_recurrence`).
- **Helper compartido** `Domain/Finance/Support/JournalKindContract` que centraliza la validación tipo↔kind reusada por `UpdateJournalEntry` y por las Actions del Plan.
- **Service** `PlanProjectionService` proyecta sobre el snapshot de `FinancialStateService`, sin caché, ventana fija HOY + 6 meses. Devuelve `{ horizon, accounts, series, events }` donde cada evento puede traer `warnings: ['overpay' | 'archived_account']` y flag `skipped`.
- **Filosofía libreta libre en el carril simulado**: los saldos pueden cruzar 0 sin error; sobrepago en `debt_payment` se aplica y se marca `warning = "overpay"` (la única validación dura sigue siendo `OverpayDebt` al crear movimientos reales).
- **Editar `recurrence_day`** en un evento borra los overrides cuyas `occurrence_date` ya no coinciden con la nueva regla; el PATCH devuelve `removed_overrides` y la UI confirma antes con `BaseConfirm`.
- **Frontend**: vista `/plan` con hero (BO proyectado / DE proyectada / primera deuda en 0), lista CRUD de eventos, gráfica de líneas (Chart.js, una serie por cuenta) y tabla cronológica con edición inline de overrides. Store Pinia `plan.js` invalida + refetchea proyección tras cada mutación.

## Deploy a producción (Fly.io)

Guía completa en [`docs/deploy.md`](./docs/deploy.md). Resumen del setup:

- **Una sola app Fly** (`fincore`) sirve SPA + API desde el mismo origen vía `Dockerfile` multi-stage (Node frontend → Composer vendor → `serversideup/php:8.4-fpm-nginx-alpine`). nginx rutea `/api` y `/up` a PHP-FPM; el resto cae al SPA con fallback a `index.html`. Cero CORS.
- **Postgres en otra app Fly** (`fincore-db`) sin puertos públicos; se accede por `fincore-db.internal` desde la red 6PN privada. Config en `db/fly.toml`.
- **Sin Redis en prod**: `SESSION_DRIVER=database` (tabla `sessions`), `CACHE_STORE=file`, `QUEUE_CONNECTION=sync`. Una infra menos que mantener.
- **SMTP**: Resend (`smtp.resend.com:465`). API key en `MAIL_PASSWORD` (secret).
- **TrustProxies** activo en `bootstrap/app.php` para respetar los `X-Forwarded-*` que inyecta el proxy de Fly y generar URLs HTTPS correctas.
- **Build local de la imagen**: `docker build -t fincore:test .` desde la raíz (usa `.dockerignore` para no inflar el contexto).
- **Deploy**: `fly deploy` desde local (~2 min con cache); el `docker/entrypoint.sh` corre `migrate --force` antes de levantar nginx.
