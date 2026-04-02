# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
# Install dependencies, generate key, run migrations, build assets
composer setup

# Start dev servers (Laravel + queue + log monitor + Vite) concurrently
composer dev

# Run all tests (clears config cache first)
composer test

# Run a specific test file
php artisan test tests/Feature/Finance/IncomeTest.php

# Run a specific test method
php artisan test tests/Feature/Finance/IncomeTest.php --filter=test_income_increases_bo

# Lint (Laravel Pint)
./vendor/bin/pint

# Frontend build
npm run build
```

## Architecture

**FinCore** is a Laravel 12 financial tracker with three core metrics:
- **BO (Bolsa)**: Cash on hand = sum of incomes − expenses − debt payments
- **DE (Deudas)**: Total outstanding debt across all credit facilities
- **CR (Crédito)**: Available credit = sum of (limit − current_amount) per debt

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
│       └── OverpayDebt.php
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

`CreateDebt` and `RegisterCreditExpense` have no API endpoint — they are only accessible via CLI.

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
- Actions use database transactions and throw domain exceptions (`InsufficientFunds`, `OverpayDebt`) on invalid state.
- Tests use `RefreshDatabase` + SQLite in-memory (configured in `phpunit.xml`). Production uses PostgreSQL.
