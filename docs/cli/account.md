# `fin:account:create`

Crea una cuenta de **débito** o **crédito**. La cuenta `cash` (Bolsa) es singleton y la crea el seeder, no este comando.

## Sintaxis

```bash
fin:account:create {name} {type}
    [--limit=]
    [--closingDay=]
    [--paymentDay=]
    [--interest=]
    [--minPct=]
```

## Argumentos

| Arg | Tipo | Requerido | Descripción |
|-----|------|-----------|-------------|
| `name` | string | sí | Nombre de la cuenta (ej. "Banamex Débito", "Costco Visa") |
| `type` | `debit` \| `credit` | sí | Tipo de cuenta. `cash` está reservado para la Bolsa singleton. |

## Opciones (solo aplican a `type=credit`)

| Opción | Tipo | Descripción |
|--------|------|-------------|
| `--limit` | decimal | Límite de crédito. **Obligatorio para `credit`.** |
| `--closingDay` | int (1-31) | Día del mes en que cierra el estado de cuenta |
| `--paymentDay` | int (1-31) | Día del mes en que vence el pago |
| `--interest` | decimal (0-1) | Tasa de interés mensual (ej. `0.0367` = 3.67%) |
| `--minPct` | decimal (0-1) | Porcentaje del saldo como pago mínimo (ej. `0.05` = 5%) |

> Si especificas `type=debit`, las opciones `--limit`, `--closingDay`, etc. se ignoran silenciosamente.

## Ejemplos

**Cuenta de débito simple:**
```bash
docker compose exec api php artisan fin:account:create "Banamex Débito" debit
```

**Tarjeta de crédito con metadata completa:**
```bash
docker compose exec api php artisan fin:account:create "Costco Visa" credit \
  --limit=25000 \
  --closingDay=15 \
  --paymentDay=5 \
  --interest=0.0367 \
  --minPct=0.05
```

**Tarjeta de crédito mínima (solo con límite):**
```bash
docker compose exec api php artisan fin:account:create "Tarjeta Básica" credit --limit=10000
```

## Salida

Al crearse exitosamente:
```
Cuenta creada [3] Costco Visa (type=credit)
```

El número entre corchetes es el `id`. Anótalo: lo necesitarás para los demás comandos (`fin:income`, `fin:expense`, `fin:credit-expense`, `fin:pay`).

## Errores posibles

| Mensaje | Causa | Cómo arreglar |
|---------|-------|---------------|
| `Tipo de cuenta desconocido: X` | Pasaste un `type` distinto de `debit` o `credit` | Usa `debit` o `credit` |
| `La cuenta de efectivo (Bolsa) es única y se crea por seeder.` | Intentaste crear `type=cash` | La Bolsa ya existe; no se crea otra |
| `Una cuenta de crédito requiere credit_limit.` | No pasaste `--limit` con `type=credit` | Agrega `--limit=NUMERO` |

## Notas

- Las cuentas creadas tienen `is_protected = false`, así que pueden editarse y eliminarse desde la API.
- La metadata de crédito (`closingDay`, `paymentDay`, etc.) se **persiste pero no tiene lógica aún**. Es la semilla para el motor de alertas de Fase 2.
- No hay un comando `fin:account:list` por ahora — usa `fin:state` o consulta la tabla `accounts` directamente con `php artisan tinker`.
