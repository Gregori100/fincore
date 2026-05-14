# API: Accounts

CRUD de cuentas del usuario autenticado. Todos los endpoints requieren `Authorization: Bearer <token>` + email verificado.

La cuenta **Bolsa** (`type=cash`, `is_protected=true`) se crea automáticamente al registrarse el usuario. No se puede crear ni borrar; solo existe una por usuario.

> **IDs**: tanto `accounts.id` como `users.id` son **UUID v7** generados automáticamente al crear el modelo (trait `HasUuids` de Laravel 12). Esto reemplaza los seriales antiguos para no filtrar cardinalidad en URLs públicas. Los clientes deben tratar el `id` como opaco (string).

## GET `/api/finance/accounts`

Lista las cuentas del usuario con su balance calculado.

### Query params
- `include_archived` *(bool, default false)*: si es truthy (`1`, `true`), incluye también las cuentas con `deleted_at != null`. Usado por la vista `/accounts` del frontend, que muestra activas + archivadas con un badge.

### Response 200
```json
{
  "accounts": [
    {
      "id": "019e2899-7863-7120-95a3-f2e2e16f4f57",
      "user_id": "019e2899-7859-70bb-8d0b-f14a1d957226",
      "name": "Bolsa",
      "description": null,
      "type": "cash",
      "is_protected": true,
      "credit_limit": null,
      "closing_day": null,
      "payment_day": null,
      "interest_rate": null,
      "minimum_payment_pct": null,
      "balance": 15200.00,
      "deleted_at": null,
      "created_at": "...",
      "updated_at": "..."
    },
    {
      "id": "019e2899-8c11-7344-aae3-7d77c1b0a4b1",
      "user_id": "019e2899-7859-70bb-8d0b-f14a1d957226",
      "name": "Costco Visa",
      "description": "Tarjeta principal · alias 1234",
      "type": "credit",
      "is_protected": false,
      "credit_limit": "25000.00",
      "closing_day": 15,
      "payment_day": 5,
      "interest_rate": "0.0367",
      "minimum_payment_pct": "0.0500",
      "balance": 2500.00,
      "available_credit": 22500.00,
      "deleted_at": null
    }
  ]
}
```

Para cuentas `credit`, además del `balance` (= deuda actual), incluye `available_credit` (= límite − balance). Las cuentas archivadas (cuando `include_archived=1`) traen `deleted_at` con timestamp.

## POST `/api/finance/accounts`

Crea una cuenta de débito o crédito. **Crear `cash` no está permitido** (`422`).

### Request — débito
```json
{
  "name": "Banamex Débito",
  "description": "Cuenta de nómina",
  "type": "debit"
}
```

### Request — crédito (con metadata)
```json
{
  "name": "Costco Visa",
  "description": "Tarjeta principal · alias 1234",
  "type": "credit",
  "credit_limit": 25000,
  "closing_day": 15,
  "payment_day": 5,
  "interest_rate": 0.0367,
  "minimum_payment_pct": 0.05
}
```

Para `type=credit`, `credit_limit` es obligatorio. `description` es opcional (texto libre, máximo 200 caracteres tras `trim()`; cadena vacía o solo espacios → `null`).

### Response 201
```json
{
  "account": {
    "id": "019e2899-8c11-7344-aae3-7d77c1b0a4b1",
    "user_id": "019e2899-7859-70bb-8d0b-f14a1d957226",
    "name": "Costco Visa",
    "description": "Tarjeta principal · alias 1234",
    "...": "..."
  }
}
```

### Errores
- `422` con `code: invalid_account_type` si:
    - Pasaste `type=cash` o un type desconocido.
    - El nombre queda vacío tras `trim()` o excede 120 caracteres.
    - La `description` excede 200 caracteres tras `trim()`.
- `422` con `code: invalid_credit_limit` si `type=credit` sin `credit_limit`.
- `422` con `code: invalid_credit_metadata` si `type=credit` con `closing_day === payment_day`.
- `422` con `code: duplicate_account_name` si ya tienes otra cuenta con ese nombre (case-insensitive, incluyendo archivadas).

## PATCH `/api/finance/accounts/{id}`

`{id}` es un UUID. Actualiza metadatos de una cuenta. Solo los campos enviados se modifican.

**No se puede actualizar la Bolsa** (`409 protected_account`).

### Request (cualquier subconjunto)
```json
{
  "name": "Nuevo nombre",
  "description": "Notas actualizadas",
  "credit_limit": 30000,
  "closing_day": 20,
  "payment_day": 10,
  "interest_rate": 0.0299,
  "minimum_payment_pct": 0.04
}
```

Los campos de tarjeta (`credit_limit`, etc.) solo aplican a cuentas `credit`; en débito se ignoran. Para `description`, enviar `null` o cadena vacía borra el valor actual.

### Response 200
```json
{ "account": { ... } }
```

### Errores
- `404` si el id no existe **o pertenece a otro usuario** (aislamiento estricto).
- `409` con `code: protected_account` si intentas modificar la Bolsa.
- `422` con `code: duplicate_account_name` si el nuevo nombre ya está usado por otra cuenta (case-insensitive, considerando archivadas).
- `422` con `code: invalid_account_type` si el nombre queda vacío o > 120 caracteres tras `trim()`, o si la `description` excede 200 caracteres.
- `422` con `code: invalid_credit_limit` si:
    - En una tarjeta intentas setear `credit_limit = null`.
    - Bajas `credit_limit` por debajo de la deuda actual (dejaría disponible negativo).
- `422` con `code: invalid_credit_metadata` si `closing_day` y `payment_day` quedarían iguales tras el update.

## DELETE `/api/finance/accounts/{id}`

**Archiva** una cuenta (soft delete: setea `deleted_at` en lugar de borrar la fila). Solo se permite si:
- No es la Bolsa (`is_protected=false`).
- Su `balance == 0`:
    - **cash/debit**: sin saldo (transfiere o gasta todo antes).
    - **credit**: sin deuda pendiente (paga todo antes).

Las pólizas históricas que referenciaban a la cuenta **siguen siendo accesibles** en `/api/finance/entries`. Sus relaciones `origin` y `destination` cargan el modelo de cuenta archivado (con `deleted_at` poblado), lo que permite al frontend mostrar el nombre + badge `(archivada)`. **No existe reactivación**: una cuenta archivada permanece como histórica de solo lectura.

### Response 200
```json
{ "message": "Cuenta eliminada" }
```

### Errores
- `404` si no existe o pertenece a otro usuario.
- `409` con `code: protected_account` si es la Bolsa.
- `422` con `code: account_not_empty` si tiene saldo o deuda pendiente. El `error` describe la condición específica:
    - cash/debit: `"Esta cuenta tiene saldo. Transfiérelo o gástalo todo antes de archivar."`
    - credit: `"Esta tarjeta tiene una deuda pendiente. Págala completamente antes de archivar."`

> **Nota**: el "nombre" de una cuenta archivada sigue ocupando su slot de unicidad. Si archivas "Banamex Débito", no podrás crear otra cuenta con el mismo nombre (case-insensitive). Esto evita confusión en `/entries`, donde pólizas históricas y nuevas se mezclarían.

## Aislamiento entre usuarios

Todos los endpoints están scopeados por `auth()->id()` a nivel query. **Un usuario nunca puede leer ni modificar las cuentas de otro.** Intentos retornan `404 Not Found` (deliberadamente no `403`, para no filtrar la existencia del recurso).

## Notas

- Los campos de metadata de tarjeta (`closing_day`, `payment_day`, `interest_rate`, `minimum_payment_pct`) se persisten pero **aún no tienen lógica asociada**. Son la semilla para el motor de alertas de Fase 2.
- El `balance` y `available_credit` son **derivados** (calculados desde `journal_entries`), no persistidos. Si quieres ver el detalle de cómo se calculan, ver [docs/cli/state.md](../cli/state.md#balance-calculation).
