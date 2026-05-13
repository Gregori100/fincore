# API: Operaciones financieras + estado

Todos los endpoints requieren `Authorization: Bearer <token>` + email verificado.

## GET `/api/finance/state` <a name="state"></a>

Vista de pájaro del estado del usuario. Combina los agregados BO/DE/CR + lista de cuentas + últimos 10 movimientos.

### Response 200
```json
{
  "bo": 15200.00,
  "de": 2500.00,
  "cr": 22500.00,
  "burn_rate": 5300.00,
  "credit_usage_pct": 10.00,
  "accounts": [ /* mismas que GET /accounts, con balance */ ],
  "recent_entries": [
    {
      "id": 12,
      "user_id": 1,
      "kind": "debt_payment",
      "amount": "2000.00",
      "account_origin_id": 1,
      "account_destination_id": 3,
      "description": "abono visa",
      "occurred_at": "2026-05-13T20:15:00.000000Z",
      "origin": { "id": 1, "name": "Bolsa", ... },
      "destination": { "id": 3, "name": "Costco Visa", ... }
    }
  ]
}
```

| Campo | Significado |
|-------|-------------|
| `bo` | Suma de balances de cuentas `cash` + `debit` |
| `de` | Suma de balances de cuentas `credit` (deuda total) |
| `cr` | `Σ (límite − balance)` de cuentas `credit` (crédito disponible) |
| `burn_rate` | `expense` + `credit_expense` últimos 30 días |
| `credit_usage_pct` | `DE / Σlímites × 100` |

## POST `/api/finance/income`

Registra un ingreso a una cuenta cash/debit. Sube BO.

### Request
```json
{
  "account_id": 1,
  "amount": 5000,
  "description": "sueldo"
}
```

### Response 201
```json
{
  "message": "Ingreso registrado",
  "entry": {
    "id": 13, "kind": "income", "amount": "5000.00",
    "account_origin_id": null, "account_destination_id": 1,
    ...
  }
}
```

### Errores
- `422 invalid_account_type` si `account_id` apunta a una cuenta `credit`.
- `404` si la cuenta no existe o pertenece a otro usuario.

## POST `/api/finance/expense`

Registra un gasto desde una cuenta cash/debit. Baja BO.

### Request
```json
{
  "account_id": 1,
  "amount": 800,
  "description": "supermercado"
}
```

### Errores
- `422 insufficient_funds` si `amount > balance`.
- `422 invalid_account_type` si la cuenta es de crédito.

## POST `/api/finance/credit-expense`

Compra con tarjeta de crédito. Sube DE y baja CR (no toca BO).

### Request
```json
{
  "account_id": 3,
  "amount": 4500,
  "description": "laptop"
}
```

### Errores
- `422 credit_limit_exceeded` si `balance + amount > credit_limit`.
- `422 invalid_account_type` si la cuenta no es `credit`.

## POST `/api/finance/pay-credit`

Paga una tarjeta desde una cuenta cash/debit. Baja BO, baja DE, sube CR.

### Request
```json
{
  "origin_id": 1,
  "credit_account_id": 3,
  "amount": 2000,
  "description": "abono visa"
}
```

### Errores
- `422 insufficient_funds` si origen no alcanza.
- `422 overpay_debt` si `amount > deuda de la tarjeta`.
- `422 invalid_account_type` si origen no es cash/debit o destino no es credit.

## POST `/api/finance/transfer`

Transferencia entre dos cuentas cash/debit del mismo usuario.

### Request
```json
{
  "origin_id": 1,
  "destination_id": 2,
  "amount": 1500,
  "description": "depósito a Banamex"
}
```

### Errores
- `422 insufficient_funds` si origen no alcanza.
- `422 invalid_account_type` si origen == destino, o alguna no es cash/debit.

## Impacto de cada operación en las métricas

| Operación (`kind`) | BO | DE | CR | Burn rate |
|---------------------|----|----|----|-----------|
| `income` | +amount | — | — | — |
| `expense` | −amount | — | — | +amount |
| `credit_expense` | — | +amount | −amount | +amount |
| `debt_payment` | −amount | −amount | +amount | — |
| `transfer` | — (suma cero entre cash) | — | — | — |
