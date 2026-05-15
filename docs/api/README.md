# API REST de FinCore

La API es el contrato único para todos los clientes (web Vue, móvil Flutter futuro, scripts). Toda interacción va por `/api/*` y devuelve JSON.

## Autenticación

FinCore usa **Sanctum con Bearer tokens**. Todos los endpoints de `/api/finance/*` requieren:
1. Header `Authorization: Bearer <token>` válido.
2. Email del usuario verificado.

Flujo de auth detallado en [auth.md](./auth.md).

## Estructura de la API

| Sección | Path | Doc |
|---------|------|-----|
| **Auth** | `/api/auth/*` | [auth.md](./auth.md) |
| **Accounts** | `/api/finance/accounts/*` | [accounts.md](./accounts.md) |
| **Categories** | `/api/finance/categories/*` | [categories.md](./categories.md) |
| **Reports** | `/api/finance/reports/*` | [reports.md](./reports.md) |
| **Finance operations** | `/api/finance/{income,expense,credit-expense,pay-credit,transfer}` | [finance.md](./finance.md) |
| **Journal entries** | `/api/finance/entries` (+ `PATCH /entries/{id}`) | [entries.md](./entries.md) |
| **Estado financiero** | `/api/finance/state` | [finance.md](./finance.md#state) |

## Convenciones generales

### Respuestas exitosas

```json
{
  "user": { ... },
  "token": "..."
}
```

Codes:
- `200 OK` para lecturas y mutaciones que no crean recursos.
- `201 Created` para POST que crea un nuevo recurso (account, entry, user).

### Errores de validación (HTTP)

Cuando un body no cumple las reglas:
```json
{
  "message": "The given data was invalid.",
  "errors": {
    "email": ["The email field is required."]
  }
}
```
Status: `422 Unprocessable Entity`.

### Errores de dominio

Cuando una regla de negocio se viola (saldo insuficiente, sobre-pago, etc.):
```json
{
  "error": "Fondos insuficientes en la cuenta de origen.",
  "code": "insufficient_funds"
}
```

| Code | HTTP status | Significado |
|------|-------------|-------------|
| `insufficient_funds` | 422 | Saldo insuficiente en la cuenta origen |
| `overpay_debt` | 422 | El pago excede la deuda actual |
| `credit_limit_exceeded` | 422 | El cargo excede el límite de crédito |
| `invalid_account_type` | 422 | Operación inválida para el tipo de cuenta |
| `invalid_credit_limit` | 422 | Límite de crédito inválido (null en credit, o menor a la deuda actual) |
| `invalid_credit_metadata` | 422 | `closing_day` y `payment_day` no pueden ser iguales |
| `duplicate_account_name` | 422 | Ya tienes otra cuenta con ese nombre (case-insensitive, incluye archivadas) |
| `account_not_empty` | 422 | No puedes archivar una cuenta con saldo o deuda pendiente |
| `protected_account` | 409 | Cuenta protegida (la Bolsa no se puede modificar) |
| `duplicate_category_name` | 422 | Ya tienes otra categoría con ese nombre |
| `invalid_category_applies_to` | 422 | `applies_to` inválido, vacío, o incompatible con el `kind` del movimiento |
| `invalid_color_slug` | 422 | Color fuera del catálogo permitido |
| `invalid_icon_slug` | 422 | Icono fuera del catálogo permitido |
| `immutable_journal_field` | 422 | Se intentó editar un campo no permitido en `PATCH /entries/{id}` |

### Autenticación faltante

- Sin token → `401 Unauthorized`.
- Con token pero email no verificado → `403 Forbidden`.

### Rate limiting

Los endpoints sensibles (login, register, forgot password, verification-notification) están limitados a **6 requests / minuto / IP**. Después devuelven `429 Too Many Requests` con header `Retry-After`.

## Modelo de datos resumido

| Recurso | Forma básica |
|---------|--------------|
| **User** | `{ id, name, email, email_verified_at, created_at }` (sin password) |
| **Account** | `{ id, user_id, name, type, is_protected, credit_limit?, closing_day?, payment_day?, interest_rate?, minimum_payment_pct?, balance, available_credit? }` |
| **JournalEntry** | `{ id, user_id, kind, amount, account_origin_id?, account_destination_id?, description?, occurred_at }` |

Cada usuario tiene **una cuenta Bolsa** (`type=cash`, `is_protected=true`) creada automáticamente al registrarse. Sus pólizas siempre pertenecen a un usuario; no hay cross-user data.

## Cómo invocar la API

### Desde el navegador (curl)
```bash
TOKEN=$(curl -s -X POST http://localhost/api/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"email":"diego@example.com","password":"secret1234"}' | jq -r .token)

curl http://localhost/api/finance/state -H "Authorization: Bearer $TOKEN" | jq
```

### Desde el frontend Vue (Axios)
```js
import axios from 'axios'

const api = axios.create({ baseURL: '/api' })
api.interceptors.request.use(config => {
  const token = useAuthStore().token
  if (token) config.headers.Authorization = `Bearer ${token}`
  return config
})
```

### Desde CLI
Para uso desde la línea de comandos sin pasar por HTTP, ver [docs/cli/](../cli/). Los comandos `fin:*` operan directamente sobre el dominio con un flag `--user=email`.
