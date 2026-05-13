# `fin:pay`

Paga una **cuenta de crédito** (tarjeta) desde una cuenta de efectivo o débito. Es la única operación que toca tres métricas a la vez: baja BO, baja DE y sube CR.

## Sintaxis

```bash
fin:pay {originId} {creditAccountId} {amount} {description?}
```

## Argumentos

| Arg | Tipo | Requerido | Descripción |
|-----|------|-----------|-------------|
| `originId` | int | sí | ID de la cuenta de **donde sale el dinero** (debe ser `cash` o `debit`). |
| `creditAccountId` | int | sí | ID de la tarjeta a la que se abona (debe ser `credit`). |
| `amount` | decimal | sí | Monto positivo. **Debe respetar dos límites:** ≤ balance del origen Y ≤ deuda actual de la tarjeta. |
| `description` | string | no | Texto libre (ej. "abono visa septiembre"). |

## Ejemplos

**Pagar tarjeta (id=3) desde Bolsa (id=1):**
```bash
docker compose exec api php artisan fin:pay 1 3 2000 "abono visa"
```

**Pagar desde cuenta de débito (id=2) en lugar de Bolsa:**
```bash
docker compose exec api php artisan fin:pay 2 3 5000 "pago total septiembre"
```

## Salida

```
Pago aplicado: 2000
```

## Errores posibles

| Mensaje | Causa | Cómo arreglar |
|---------|-------|---------------|
| `Fondos insuficientes en la cuenta de origen.` | `amount` > balance del origen | Reduce el monto o ingresa dinero a la cuenta origen primero |
| `El pago excede el saldo de la deuda.` | `amount` > deuda actual de la tarjeta | Reduce el monto a lo que realmente debes |
| `El pago debe salir de una cuenta cash o debit.` | Pasaste un id de cuenta `credit` como origen | El origen debe ser efectivo o débito |
| `El destino del pago debe ser una cuenta de crédito.` | El segundo arg no es `type=credit` | Verifica el id |

## Impacto en las métricas

| Métrica | Antes | Después |
|---------|-------|---------|
| BO | A | A − amount |
| DE | B | B − amount |
| CR | C | C + amount |
| Burn rate mensual | — | sin cambio |

> ¿Por qué no afecta el burn rate? Porque pagar una tarjeta no es "gastar" — es liquidar una deuda preexistente. El gasto real ya se contabilizó cuando se hizo el `credit_expense`.

## Lo que pasa por dentro

1. Carga ambas cuentas (origen y destino).
2. Valida tipos: origen debe ser `cash/debit`, destino debe ser `credit`.
3. Calcula balance del origen → si `amount > balance` → `InsufficientFunds`.
4. Calcula balance del destino (= deuda actual) → si `amount > deuda` → `OverpayDebt`.
5. Crea `JournalEntry` con:
    ```
    kind:                   debt_payment
    amount:                 $amount
    account_origin_id:      $originId        ← bolsa/débito sale
    account_destination_id: $creditAccountId ← tarjeta recibe abono
    ```

## Por qué no se permite "sobrepagar" la tarjeta

Pagar de más implicaría crédito a favor, algo que la mayoría de bancos manejan como saldo positivo redimible. FinCore no modela esa figura para no complicar la semántica de cuentas de crédito. Si necesitas registrarlo, primero paga la deuda exacta y guarda el excedente en una cuenta de débito.
