# CLI de FinCore

FinCore expone su lógica de dominio a través de comandos `fin:*` de Artisan. Son una **puerta de entrada paralela a la API REST** que llama exactamente a las mismas Actions de dominio, así que cualquier validación y regla de negocio aplica igual desde CLI que desde HTTP.

## Cuándo usar el CLI vs la API REST

- **CLI**: pruebas rápidas, scripts de migración de datos, sesiones interactivas para registrar movimientos a mano sin abrir un cliente HTTP.
- **API REST**: para clientes (web Vue, móvil Flutter futuro). Documentada en `../api/` (pendiente).

> Si lo que buscas es documentación de `./scripts/install.sh` o `./scripts/fincore` (los scripts shell del proyecto, fuera del contenedor), ve a [../scripts/](../scripts/).

## No confundir con `./scripts/fincore`

| Cosa | Vive en | Sirve para |
|------|---------|-----------|
| **`./scripts/fincore`** | host, fuera del contenedor | Gestionar Docker (start/stop/status/logs) |
| **`php artisan fin:*`** | dentro del contenedor `api` | Lógica de negocio de la app |

El primero NO es el CLI de FinCore. El segundo sí.

## Cómo invocarlo

**Opción A — entrar al shell del contenedor (mejor para sesiones interactivas):**

```bash
./scripts/fincore shell api
# Ya dentro del contenedor:
php artisan fin:state
php artisan fin:income 1 5000
```

**Opción B — desde fuera, comando a comando (mejor para scripts):**

```bash
docker compose exec api php artisan fin:state
```

A lo largo de la documentación usamos la **Opción B** por brevedad. Si tienes una sesión interactiva abierta, omite el prefijo `docker compose exec api`.

## Listado de comandos

| Comando | Propósito | Doc |
|---------|-----------|-----|
| `fin:account:create` | Crear una cuenta de débito o crédito | [account.md](./account.md) |
| `fin:income` | Registrar un ingreso a una cuenta cash/debit | [income.md](./income.md) |
| `fin:expense` | Registrar un gasto desde una cuenta cash/debit | [expense.md](./expense.md) |
| `fin:credit-expense` | Registrar un cargo a una tarjeta de crédito | [credit-expense.md](./credit-expense.md) |
| `fin:pay` | Pagar una tarjeta de crédito | [pay.md](./pay.md) |
| `fin:state` | Imprimir el estado financiero completo | [state.md](./state.md) |

Para ver el listado en vivo:

```bash
docker compose exec api php artisan list fin
```

## Autenticación en el CLI

Cada comando `fin:*` necesita saber **sobre qué usuario** operar. Lo decide así, en orden:

1. Si pasas `--user=email`, busca ese usuario.
2. Si no lo pasas y solo existe **un** usuario, lo usa por conveniencia.
3. Si no lo pasas y hay varios, falla con mensaje pidiendo el flag.

```bash
# Con un solo user en BD: el flag es opcional
docker compose exec api php artisan fin:state

# Con varios users: especifica
docker compose exec api php artisan fin:state --user=diego@example.com
```

Los usuarios se crean vía API (`POST /api/auth/register`), no por CLI.

## Conceptos clave

- **Bolsa**: cuenta `cash` singleton **por usuario**, creada automáticamente al registrarse (`is_protected=true`). No se puede eliminar ni renombrar.
- **BO** (Bolsa): efectivo disponible. Suma de balances de cuentas `cash` + `debit`.
- **DE** (Deudas): deuda total. Suma de balances de cuentas `credit`.
- **CR** (Crédito): crédito disponible. `Σ (límite − deuda)` por cuenta de crédito.
- **Burn rate mensual**: gasto total (`expense` + `credit_expense`) en los últimos 30 días.

## Flujo típico de prueba

```bash
# 1. Ver estado inicial (solo Bolsa)
docker compose exec api php artisan fin:state

# 2. Crear una cuenta de débito
docker compose exec api php artisan fin:account:create "Banamex Débito" debit

# 3. Crear una tarjeta de crédito con metadata completa
docker compose exec api php artisan fin:account:create "Costco Visa" credit \
  --limit=25000 --closingDay=15 --paymentDay=5 --interest=0.0367 --minPct=0.05

# 4. Registrar tu sueldo en la Bolsa (id=1)
docker compose exec api php artisan fin:income 1 18000 "sueldo quincena"

# 5. Gasto en efectivo
docker compose exec api php artisan fin:expense 1 800 "supermercado"

# 6. Compra con tarjeta (id=3, la Costco Visa)
docker compose exec api php artisan fin:credit-expense 3 4500 "laptop"

# 7. Pagar a la tarjeta desde la Bolsa
docker compose exec api php artisan fin:pay 1 3 2000 "abono visa"

# 8. Ver estado final
docker compose exec api php artisan fin:state
```

## Cómo manejan errores los comandos

Todos los comandos `fin:*` envuelven la Action en `try/catch`. Si la Action lanza una excepción de dominio (`InsufficientFunds`, `OverpayDebt`, `CreditLimitExceeded`, `InvalidAccountType`, `ProtectedAccount`):

- Se imprime el mensaje de la excepción en `stderr`.
- El comando retorna **exit code 1** (`Command::FAILURE`).

Esto permite encadenarlos en scripts con `&&` con confianza.
