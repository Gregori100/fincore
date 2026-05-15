# API: Journal entries (movimientos)

Endpoint paginado para auditar el historial de movimientos del usuario autenticado.

## GET `/api/finance/entries`

Lista pólizas (`journal_entries`) del usuario, ordenadas por `occurred_at` descendente. Soporta filtros opcionales y paginación.

### Query parameters

| Parámetro | Tipo | Default | Descripción |
|-----------|------|---------|-------------|
| `account_id` | UUID | — | Filtra entries donde la cuenta sea origen O destino |
| `category_id` | UUID | — | Filtra por categoría asignada |
| `kind` | enum | — | `income` \| `expense` \| `credit_expense` \| `debt_payment` \| `transfer` \| `adjustment` |
| `from` | date | — | Solo entries con `occurred_at >= from` (formato ISO 8601) |
| `to` | date | — | Solo entries con `occurred_at <= to` |
| `per_page` | int | 25 | Tamaño de página (1..200) |
| `page` | int | 1 | Página de Laravel paginator |

> Las entries **canceladas** (`deleted_at != null`) NO aparecen en este listado. El scope global de SoftDeletes las oculta. Para auditarlas haría falta un endpoint específico con `withTrashed()` (no expuesto hoy).

### Response 200

Estándar de Laravel paginator:
```json
{
  "data": [
    {
      "id": 13,
      "user_id": 1,
      "kind": "income",
      "amount": "5000.00",
      "account_origin_id": null,
      "account_destination_id": 1,
      "description": "sueldo",
      "occurred_at": "2026-05-13T20:15:00.000000Z",
      "origin": null,
      "destination": { "id": 1, "name": "Bolsa", "type": "cash", ... }
    }
  ],
  "current_page": 1,
  "last_page": 3,
  "per_page": 25,
  "total": 67,
  "from": 1,
  "to": 25,
  "first_page_url": ".../entries?page=1",
  "last_page_url": ".../entries?page=3",
  "next_page_url": ".../entries?page=2",
  "prev_page_url": null,
  "path": ".../entries",
  "links": [ /* objetos de navegación */ ]
}
```

### Ejemplos

**Toda la historia paginada:**
```bash
curl http://localhost/api/finance/entries -H "Authorization: Bearer $TOKEN" | jq
```

**Solo gastos del mes en curso:**
```bash
curl "http://localhost/api/finance/entries?kind=expense&from=2026-05-01" \
  -H "Authorization: Bearer $TOKEN" | jq
```

**Movimientos de una tarjeta específica (id=3):**
```bash
curl "http://localhost/api/finance/entries?account_id=3" \
  -H "Authorization: Bearer $TOKEN" | jq
```

**Todo lo del mes anterior:**
```bash
curl "http://localhost/api/finance/entries?from=2026-04-01&to=2026-04-30" \
  -H "Authorization: Bearer $TOKEN" | jq
```

## Aislamiento

El endpoint solo retorna entries del usuario autenticado (`WHERE user_id = auth()->id()`). No hay forma de ver entries de otros usuarios.

## Eager loading

Las relaciones `origin`, `destination` y `category` vienen cargadas automáticamente para evitar N+1. Si la entry no tiene categoría o si la cuenta correspondiente es `null` (caso de `income`/`expense` puro), el campo respectivo es `null` en el JSON. `origin` y `destination` usan `withTrashed()` para mantener el nombre histórico aunque la cuenta haya sido archivada; `category` NO lo usa (si la categoría está archivada, el campo es `null`).

## PATCH `/api/finance/entries/{id}`

Edita **sólo** `category_id` y `description`. Cualquier otro campo devuelve `422 immutable_journal_field`. Ver [categories.md](./categories.md) para detalles.

## DELETE `/api/finance/entries/{id}`

Cancela un movimiento existente vía soft delete. El balance de las cuentas afectadas se recalcula automáticamente porque las queries de `FinancialStateService` respetan el scope global de `SoftDeletes`.

### Comportamiento

- **No reactivable**: una vez cancelado, el entry no se puede restaurar vía API.
- **No bloquea saldos negativos**: cancelar un ingreso ya gastado puede dejar la cuenta en saldo virtual negativo. El frontend lo refleja con número rojo + badge "saldo negativo"; el backend no lanza error.
- **Cancelar uno ya cancelado**: 404 `ModelNotFoundException` (el scope global lo oculta).
- **Editar uno cancelado**: el `PATCH` también devuelve 404.

### Response 200

```json
{ "message": "Movimiento cancelado" }
```

### Ejemplos

**Cancelar un movimiento agregado por error:**
```bash
curl -X DELETE "http://localhost/api/finance/entries/019e2899-..." \
  -H "Authorization: Bearer $TOKEN" | jq
```
