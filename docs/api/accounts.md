# API: Accounts

CRUD de cuentas del usuario autenticado. Todos los endpoints requieren `Authorization: Bearer <token>` + email verificado.

La cuenta **Bolsa** (`type=cash`, `is_protected=true`) se crea automáticamente al registrarse el usuario. No se puede crear ni borrar; solo existe una por usuario.

## GET `/api/finance/accounts`

Lista todas las cuentas del usuario con su balance calculado.

### Response 200
```json
{
  "accounts": [
    {
      "id": 1,
      "user_id": 1,
      "name": "Bolsa",
      "type": "cash",
      "is_protected": true,
      "credit_limit": null,
      "closing_day": null,
      "payment_day": null,
      "interest_rate": null,
      "minimum_payment_pct": null,
      "balance": 15200.00,
      "created_at": "...",
      "updated_at": "..."
    },
    {
      "id": 3,
      "user_id": 1,
      "name": "Costco Visa",
      "type": "credit",
      "is_protected": false,
      "credit_limit": "25000.00",
      "closing_day": 15,
      "payment_day": 5,
      "interest_rate": "0.0367",
      "minimum_payment_pct": "0.0500",
      "balance": 2500.00,
      "available_credit": 22500.00
    }
  ]
}
```

Para cuentas `credit`, además del `balance` (= deuda actual), incluye `available_credit` (= límite − balance).

## POST `/api/finance/accounts`

Crea una cuenta de débito o crédito. **Crear `cash` no está permitido** (`422`).

### Request — débito
```json
{
  "name": "Banamex Débito",
  "type": "debit"
}
```

### Request — crédito (con metadata)
```json
{
  "name": "Costco Visa",
  "type": "credit",
  "credit_limit": 25000,
  "closing_day": 15,
  "payment_day": 5,
  "interest_rate": 0.0367,
  "minimum_payment_pct": 0.05
}
```

Para `type=credit`, `credit_limit` es obligatorio.

### Response 201
```json
{
  "account": { "id": 3, "user_id": 1, "name": "Costco Visa", ... }
}
```

### Errores
- `422` con `code: invalid_account_type` si pasaste `type=cash` o un type desconocido.
- `422` con `code: invalid_account_type` si `type=credit` sin `credit_limit`.

## PATCH `/api/finance/accounts/{id}`

Actualiza metadatos de una cuenta. Solo los campos enviados se modifican.

**No se puede actualizar la Bolsa** (`409 protected_account`).

### Request (cualquier subconjunto)
```json
{
  "name": "Nuevo nombre",
  "credit_limit": 30000,
  "closing_day": 20,
  "payment_day": 10,
  "interest_rate": 0.0299,
  "minimum_payment_pct": 0.04
}
```

Los campos de tarjeta (`credit_limit`, etc.) solo aplican a cuentas `credit`; en débito se ignoran.

### Response 200
```json
{ "account": { ... } }
```

### Errores
- `404` si el id no existe **o pertenece a otro usuario** (aislamiento estricto).
- `409` con `code: protected_account` si intentas modificar la Bolsa.

## DELETE `/api/finance/accounts/{id}`

Elimina una cuenta. Solo se permite si:
- No es la Bolsa (`is_protected=false`).
- No tiene pólizas asociadas (origen o destino).

### Response 200
```json
{ "message": "Cuenta eliminada" }
```

### Errores
- `404` si no existe o pertenece a otro usuario.
- `409` con `code: protected_account` si:
    - Es la Bolsa.
    - Tiene pólizas asociadas (en ese caso el mensaje será `"La cuenta tiene pólizas asociadas y no puede eliminarse."`).

## Aislamiento entre usuarios

Todos los endpoints están scopeados por `auth()->id()` a nivel query. **Un usuario nunca puede leer ni modificar las cuentas de otro.** Intentos retornan `404 Not Found` (deliberadamente no `403`, para no filtrar la existencia del recurso).

## Notas

- Los campos de metadata de tarjeta (`closing_day`, `payment_day`, `interest_rate`, `minimum_payment_pct`) se persisten pero **aún no tienen lógica asociada**. Son la semilla para el motor de alertas de Fase 2.
- El `balance` y `available_credit` son **derivados** (calculados desde `journal_entries`), no persistidos. Si quieres ver el detalle de cómo se calculan, ver [docs/cli/state.md](../cli/state.md#balance-calculation).
