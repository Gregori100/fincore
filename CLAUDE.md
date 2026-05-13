# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project vision

**FinCore** is a personal finance tracker for multiple users, with web (Vue) and mobile (Flutter) clients. The API is the single contract for all clients. The backend models accounting concepts directly: any number of **accounts** per user (cash, debit, credit) and **journal entries** that move money between them.

## Monorepo structure

```
fincore/
├── backend/    # Laravel 12 API
├── frontend/   # Vue 3 (currently out of sync with backend — to be reworked after MVP)
├── scripts/    # install.sh + fincore CLI (Docker stack management)
├── docs/       # Project docs — see docs/cli/ and docs/scripts/
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

## Backend architecture (`backend/`)

### Domain model: Accounts + JournalEntries

Everything financial is modeled as an **Account** (`app/Models/Account.php`) of one of three types:

- `cash` — physical money/wallet. **Singleton** named "Bolsa", `is_protected=true`, created by `DatabaseSeeder`. Cannot be deleted or renamed.
- `debit` — bank checking/debit accounts (N per user).
- `credit` — credit cards with `credit_limit`, `closing_day`, `payment_day`, `interest_rate`, `minimum_payment_pct`. The metadata is stored but no alert/interest engine exists yet (Phase 2).

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
├── Http/Controllers/FinanceController.php   # Validates requests, delegates to Actions
├── Domain/Finance/
│   ├── Actions/                             # One class per use case (stateless, transactional)
│   │   ├── CreateAccount.php
│   │   ├── UpdateAccount.php                # Rejects if is_protected
│   │   ├── DeleteAccount.php                # Rejects if is_protected or has entries
│   │   ├── RegisterIncome.php
│   │   ├── RegisterExpense.php              # Insufficient funds against the account's own balance
│   │   ├── RegisterCreditExpense.php
│   │   ├── PayCreditAccount.php             # Validates funds at origin AND not overpaying credit
│   │   └── RegisterTransfer.php             # cash/debit ↔ cash/debit only
│   ├── Services/FinancialStateService.php   # Read-only; balances + BO/DE/CR aggregates
│   └── Exceptions/
│       ├── DomainException.php          # Base — renders to JSON {error, code} with HTTP status
│       ├── InsufficientFunds.php        # 422
│       ├── OverpayDebt.php              # 422
│       ├── CreditLimitExceeded.php      # 422
│       ├── InvalidAccountType.php       # 422
│       └── ProtectedAccount.php         # 409
├── Models/
│   ├── Account.php          # constants TYPE_CASH/TYPE_DEBIT/TYPE_CREDIT + isCredit()/isCashLike()
│   └── JournalEntry.php     # KIND_* constants
└── Console/Commands/        # fin:* Artisan commands wrapping Actions
```

### API routes (`routes/api.php`, prefix `/api/finance`)

| Method | Path | Action |
|--------|------|--------|
| GET | `/state` | Aggregated BO/DE/CR + accounts with balance + recent entries |
| GET | `/entries` | Paginated journal entries with optional filters (`account_id`, `kind`, `from`, `to`, `per_page`) |
| GET | `/accounts` | List accounts with balances |
| POST | `/accounts` | CreateAccount (debit or credit; cash forbidden) |
| PATCH | `/accounts/{id}` | UpdateAccount |
| DELETE | `/accounts/{id}` | DeleteAccount |
| POST | `/income` | RegisterIncome (`account_id`, `amount`, `description?`) |
| POST | `/expense` | RegisterExpense (same payload) |
| POST | `/credit-expense` | RegisterCreditExpense (same payload, requires credit type) |
| POST | `/pay-credit` | PayCreditAccount (`origin_id`, `credit_account_id`, `amount`, ...) |
| POST | `/transfer` | RegisterTransfer (`origin_id`, `destination_id`, ...) |

### Domain error contract

Domain exceptions extend `Domain\Finance\Exceptions\DomainException`, which provides a `render()` method that returns a JSON payload `{ "error": "...", "code": "..." }`:

| Exception | HTTP status | `code` |
|-----------|-------------|--------|
| `InsufficientFunds` | 422 | `insufficient_funds` |
| `OverpayDebt` | 422 | `overpay_debt` |
| `CreditLimitExceeded` | 422 | `credit_limit_exceeded` |
| `InvalidAccountType` | 422 | `invalid_account_type` |
| `ProtectedAccount` | 409 | `protected_account` |

Validation errors from `$request->validate()` still produce the standard Laravel 422 payload with `errors` keyed by field.

### CLI commands (`fin:*`)

| Command | Signature | Description |
|---------|-----------|-------------|
| `fin:account:create` | `{name} {type} [--limit] [--closingDay] [--paymentDay] [--interest] [--minPct]` | Create debit or credit account |
| `fin:income` | `{accountId} {amount} {description?}` | Income into a cash/debit account |
| `fin:expense` | `{accountId} {amount} {description?}` | Expense from a cash/debit account |
| `fin:credit-expense` | `{accountId} {amount} {description?}` | Charge to a credit account |
| `fin:pay` | `{originId} {creditAccountId} {amount} {description?}` | Pay a credit account from a cash/debit one |
| `fin:state` | — | Print BO/DE/CR, accounts table, last 10 entries |

### Key design rules

- All business logic lives in `Actions/`. Controllers only validate and delegate.
- `FinancialStateService` is the single source of truth for balances and aggregates — both Actions (for validation) and the API consume it.
- Actions use `DB::transaction()` and throw domain exceptions on invalid state.
- The Bolsa account is created by `DatabaseSeeder`. `tests/TestCase.php` sets `$seed = true` so every test starts with Bolsa available.
- `user_id` is nullable on both tables — auth (Sanctum or similar) is intentionally deferred to Phase 2.
- Frontend is currently out of sync with this backend shape (legacy expected `bo`, `de`, `debts`). It will be reworked after the backend is fully polished.

## Frontend architecture (`frontend/`)

Vue 3 + Vite + Pinia + Vue Router + Axios. Currently consumes a legacy `/api/finance/state` shape that no longer matches — **expected to break** until the frontend rewrite.

- `src/api/client.js` — Axios instance with `baseURL: '/api'`
- `src/stores/finance.js` — Pinia store
- `src/router/index.js` — Vue Router
- Vite proxy: `/api` → `http://api`

## Docker services (`compose.yaml`)

| Service | Image | Port |
|---------|-------|------|
| `api` | Sail PHP 8.4 runtime (code requires PHP 8.2+) | 80 |
| `frontend` | node:22-alpine | 5173 |
| `pgsql` | postgres:17-alpine | 5432 |
| `redis` | redis:alpine | 6379 |

Backend uses Sail's default entrypoint (`start-container` → `supervisord` as root). Migrations are **not** run automatically on container startup — they are executed once by `scripts/install.sh` after `pgsql` is healthy, and on demand via `./scripts/fincore migrate` afterwards. Two `.env` files are needed, with separate templates:

- `.env` at repo root — config of the Docker stack (host ports, `WWWUSER`/`WWWGROUP`, Postgres credentials, xdebug). Template: `.env.example` at repo root.
- `backend/.env` — Laravel runtime config inside the container (APP_KEY, mail, cache, etc.). Template: `backend/.env.example`.

`scripts/install.sh` bootstraps both files and autodetects free host ports — if `APP_PORT=80`, `FORWARD_DB_PORT=5432`, etc., are already in use, it writes the next free port instead. `DB_DATABASE` / `DB_USERNAME` / `DB_PASSWORD` are duplicated on purpose between the two `.env` files: the root one is used by the Postgres container at init time, the backend one is what Laravel uses to connect — they must match.
