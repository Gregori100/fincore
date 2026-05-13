# `fin:credit-expense`

Registra una **compra con tarjeta de crédito**. **No** mueve tu Bolsa (no estás pagando con tu efectivo); en cambio **sube la deuda** de la tarjeta y consume crédito disponible.

Si lo que quieres es pagarle a la tarjeta, usa [`fin:pay`](./pay.md).
Si quieres registrar un gasto pagado con débito/efectivo, usa [`fin:expense`](./expense.md).

## Sintaxis

```bash
fin:credit-expense {accountId} {amount} {description?}
```

## Argumentos

| Arg | Tipo | Requerido | Descripción |
|-----|------|-----------|-------------|
| `accountId` | int | sí | ID de una cuenta `credit`. |
| `amount` | decimal | sí | Monto positivo. **`balance + amount` no puede superar `credit_limit`.** |
| `description` | string | no | Texto libre (ej. "laptop", "vuelo cdmx-mty"). |

## Ejemplos

**Cargo a tarjeta (id=3):**
```bash
docker compose exec api php artisan fin:credit-expense 3 4500 "laptop"
```

**Sin descripción:**
```bash
docker compose exec api php artisan fin:credit-expense 3 250
```

## Salida

```
Cargo a crédito registrado: 4500
```

## Errores posibles

| Mensaje | Causa | Cómo arreglar |
|---------|-------|---------------|
| `Solo se puede cargar a una cuenta de tipo credit.` | Pasaste un id de cuenta `cash` o `debit` | Usa `fin:expense` |
| `Límite de crédito excedido.` | `balance + amount > credit_limit` | Reduce el monto o paga primero |
| `No query results for model [App\Models\Account] N` | El `accountId` no existe | Verifica con `fin:state` |

## Impacto en las métricas

| Métrica | Antes | Después |
|---------|-------|---------|
| BO | — | sin cambio |
| DE | X | X + amount |
| CR | Y | Y − amount |
| Burn rate mensual | Z | Z + amount |

> ¿Por qué cuenta en el burn rate? Porque conceptualmente es dinero que ya gastaste — la pregunta "¿a qué ritmo quemo dinero?" no distingue si lo pagaste con efectivo o lo difieres a la tarjeta.

## Lo que pasa por dentro

1. Carga la cuenta y verifica que sea `credit`.
2. Calcula `newBalance = balance_actual + amount`.
3. Si `newBalance > credit_limit` → lanza `CreditLimitExceeded`.
4. Crea `JournalEntry` con:
    ```
    kind:                   credit_expense
    amount:                 $amount
    account_origin_id:      $accountId   ← la tarjeta es origen
    account_destination_id: null
    ```

> En la convención del modelo, una tarjeta es origen del dinero "prestado" que sale al mundo externo. La fórmula de balance está invertida para `type=credit` para que el balance represente **deuda actual** (positiva), no un saldo bancario.
