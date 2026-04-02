# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project vision

**FinCore** is a personal finance tracker for multiple users, with web (Vue) and mobile (Flutter) clients. The API is the single contract for all clients. A future feature is multiple wallets (bolsas) per user — keep this in mind when making data-layer decisions.

## Monorepo structure

```
fincore/
├── backend/    # Laravel 12 API
├── frontend/   # Vue 3 (web client)
└── compose.yaml
```

## Commands

```bash
# Backend — run from backend/
cd backend
composer install          # Install PHP dependencies
php artisan migrate       # Run migrations
php artisan test          # Run all tests (SQLite in-memory)
php artisan test tests/Feature/Finance/IncomeTest.php                        # Single file
php artisan test --filter=test_income_increases_bo                           # Single test
./vendor/bin/pint                                                             # Lint

# Frontend — run from frontend/
cd frontend
npm install       # Install JS dependencies
npm run dev       # Dev server (http://localhost:5173)
npm run build     # Production build

# Docker — run from repo root
docker compose up --build   # Starts backend, frontend, pgsql, redis
```

## Backend architecture (`backend/`)

Three core metrics per user (multi-user scope pending auth implementation):
- **BO (Bolsa)**: Cash on hand = incomes − expenses − debt payments
- **DE (Deudas)**: Total outstanding debt = sum of `current_amount` per debt
- **CR (Crédito)**: Available credit = sum of `(credit_limit − current_amount)` per debt

### Layer structure

```
app/
├── Http/Controllers/FinanceController.php   # API entry point, delegates to Actions
├── Domain/Finance/
│   ├── Actions/          # One class per use case (stateless, transactional)
│   │   ├── RegisterIncome.php
│   │   ├── RegisterExpense.php
│   │   ├── RegisterCreditExpense.php
│   │   ├── PayDebt.php
│   │   └── CreateDebt.php
│   ├── Services/
│   │   └── FinancialStateService.php  # Read-only; computes BO, DE, CR, burn rate
│   └── Exceptions/
│       ├── InsufficientFunds.php
│       ├── OverpayDebt.php
│       └── CreditLimitExceeded.php
├── Models/
│   ├── Movement.php  # type: income | expense | credit_expense | debt_payment | adjustment
│   └── Debt.php      # hasMany Movement; tracks current_amount and credit_limit
└── Console/Commands/  # fin:* artisan commands — CLI wrappers around Actions
```

### API routes (`routes/api.php`, prefix `/api/finance`)

| Method | Path | Action |
|--------|------|--------|
| POST | `/income` | RegisterIncome |
| POST | `/expense` | RegisterExpense |
| POST | `/pay-debt` | PayDebt |
| GET | `/state` | FinancialStateService |

`CreateDebt` and `RegisterCreditExpense` have no API endpoint yet — CLI only.

### CLI commands (`fin:*`)

| Command | Signature | Description |
|---------|-----------|-------------|
| `fin:income` | `{amount} {description?}` | Register income |
| `fin:expense` | `{amount} {description?}` | Register expense (checks BO) |
| `fin:pay` | `{debtId} {amount} {description?}` | Pay down a debt |
| `fin:credit:create` | `{name} {limit}` | Create a new credit facility |
| `fin:credit-expense` | `{debtId} {amount} {description?}` | Charge to a credit facility |
| `fin:state` | — | Print BO, DE, CR, burn rate, debts, last 10 movements |

### Movement types and metric impact

| Type | BO | DE | CR |
|------|----|----|-----|
| `income` | +amount | — | — |
| `expense` | −amount | — | — |
| `debt_payment` | −amount | −amount | +amount |
| `credit_expense` | — | +amount | −amount |
| `adjustment` | (manual) | — | — |

### Key design rules

- All business logic lives in `Actions/`. Controllers only validate and delegate.
- `FinancialStateService` is the single source of truth for BO/DE/CR calculations — used both for validation inside Actions and for the state API endpoint.
- Actions use `DB::transaction()` and throw domain exceptions (`InsufficientFunds`, `OverpayDebt`, `CreditLimitExceeded`) on invalid state.
- Tests use `RefreshDatabase` + SQLite in-memory (`phpunit.xml`). Production uses PostgreSQL.

## Frontend architecture (`frontend/`)

Vue 3 + Vite + Pinia + Vue Router + Axios.

- `src/api/client.js` — Axios instance with `baseURL: '/api'`
- `src/stores/finance.js` — Pinia store for financial state (bo, de, debts)
- `src/router/index.js` — Vue Router
- Vite proxy: `/api` → `http://laravel.test` (backend Docker service)

## Docker services (`compose.yaml`)

| Service | Image | Port |
|---------|-------|------|
| `laravel.test` | Sail PHP 8.4 | 80 |
| `frontend` | node:22-alpine | 5173 |
| `pgsql` | postgres:17-alpine | 5432 |
| `redis` | redis:alpine | 6379 |

Backend runs `php artisan migrate --force` automatically on startup.
