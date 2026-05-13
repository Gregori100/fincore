# `fin:income`

Registra un **ingreso** en una cuenta de efectivo o débito. El dinero entra desde el "mundo externo" (sin cuenta de origen). Sube el balance de la cuenta destino, y por extensión el agregado BO.

## Sintaxis

```bash
fin:income {accountId} {amount} {description?}
```

## Argumentos

| Arg | Tipo | Requerido | Descripción |
|-----|------|-----------|-------------|
| `accountId` | int | sí | ID de una cuenta `cash` o `debit`. Bolsa suele ser `id=1`. |
| `amount` | decimal | sí | Monto positivo. |
| `description` | string | no | Texto libre (ej. "sueldo", "freelance MGT"). |

## Ejemplos

**Ingreso a la Bolsa:**
```bash
docker compose exec api php artisan fin:income 1 18000 "sueldo quincena"
```

**Ingreso a una cuenta de débito (Banamex con id=2):**
```bash
docker compose exec api php artisan fin:income 2 5000 "transferencia recibida"
```

**Sin descripción:**
```bash
docker compose exec api php artisan fin:income 1 1000
```

## Salida

```
Ingreso registrado: 18000
```

## Errores posibles

| Mensaje | Causa | Cómo arreglar |
|---------|-------|---------------|
| `No query results for model [App\Models\Account] N` | El `accountId` no existe | Verifica con `fin:state` |
| `Un ingreso solo puede recibirse en una cuenta de efectivo o débito.` | Pasaste un id de cuenta `credit` | Usa una cuenta `cash` o `debit` |

## Lo que pasa por dentro

Crea una `JournalEntry` con:

```
kind:                   income
amount:                 $amount
account_origin_id:      null
account_destination_id: $accountId
description:            $description
occurred_at:            now()
```

La operación va dentro de `DB::transaction()` para asegurar atomicidad (en este caso la transacción es trivial, pero mantiene consistencia con el resto de Actions).

## Reglas de negocio relacionadas

- **No hay tope superior**: los ingresos son siempre válidos por definición. La app no cuestiona "¿de dónde vino este dinero?".
- **No afecta deudas ni crédito**: un ingreso solo mueve BO. Si quieres mover saldo entre tu Bolsa y una cuenta de débito, usa `fin:transfer` (vía API por ahora; comando CLI pendiente).
