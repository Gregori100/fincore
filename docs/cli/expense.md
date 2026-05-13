# `fin:expense`

Registra un **gasto** desde una cuenta de efectivo o débito. El dinero sale al mundo externo (sin cuenta destino). Baja el balance de la cuenta origen y por extensión BO.

Para gastos con tarjeta de crédito usa [`fin:credit-expense`](./credit-expense.md) — son conceptualmente distintos.

## Sintaxis

```bash
fin:expense {accountId} {amount} {description?}
```

## Argumentos

| Arg | Tipo | Requerido | Descripción |
|-----|------|-----------|-------------|
| `accountId` | int | sí | ID de una cuenta `cash` o `debit`. |
| `amount` | decimal | sí | Monto positivo. **Debe ser ≤ balance de la cuenta.** |
| `description` | string | no | Texto libre (ej. "supermercado", "Uber"). |

## Ejemplos

**Gasto desde Bolsa:**
```bash
docker compose exec api php artisan fin:expense 1 800 "supermercado"
```

**Gasto desde cuenta de débito:**
```bash
docker compose exec api php artisan fin:expense 2 1200 "renta"
```

## Salida

```
Gasto registrado: 800
```

## Errores posibles

| Mensaje | Causa | Cómo arreglar |
|---------|-------|---------------|
| `Fondos insuficientes en la cuenta de origen.` | `amount` > balance de la cuenta | Reduce el monto o registra un ingreso primero |
| `Un gasto en efectivo/débito solo puede salir de una cuenta cash o debit. Usa credit_expense para tarjetas de crédito.` | Pasaste el id de una cuenta `credit` | Usa `fin:credit-expense` |
| `No query results for model [App\Models\Account] N` | El `accountId` no existe | Verifica con `fin:state` |

## Lo que pasa por dentro

1. Carga la cuenta y verifica que sea `cash` o `debit`.
2. Calcula el balance actual con `FinancialStateService::getAccountBalance($id)`.
3. Si `amount > balance` → lanza `InsufficientFunds`.
4. Crea `JournalEntry` con:
    ```
    kind:                   expense
    amount:                 $amount
    account_origin_id:      $accountId
    account_destination_id: null
    description:            $description
    ```

## Por qué no se permite "sobregiro"

Es una decisión de producto: en contabilidad personal, gastar más de lo que tienes en efectivo es un error o un préstamo no documentado. El sistema te obliga a registrar el préstamo explícitamente (como una cuenta de crédito) antes de poder gastarlo. Eso mantiene los números honestos.
