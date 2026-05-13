# `fin:state`

Imprime el **estado financiero completo**: agregados BO/DE/CR, burn rate, uso de crédito, tabla con todas las cuentas y sus balances, y los últimos 10 movimientos. Es el comando de "vista de pájaro".

## Sintaxis

```bash
fin:state
```

No toma argumentos ni opciones.

## Ejemplo

```bash
docker compose exec api php artisan fin:state
```

## Salida

```
=== FINCORE STATE ===

BO: 15,200.00
DE: 2,500.00
CR: 22,500.00

Burn rate mensual: 5,300.00
Uso de crédito: 10%

--- Cuentas ---
+----+----------------+--------+----------+-----------+-----------+
| ID | Nombre         | Tipo   | Balance  | Límite    | Disp.     |
+----+----------------+--------+----------+-----------+-----------+
| 1  | Bolsa          | cash   | 15200.00 | -         | -         |
| 2  | Banamex Débito | debit  | 0.00     | -         | -         |
| 3  | Costco Visa    | credit | 2500.00  | 25000.00  | 22500.00  |
+----+----------------+--------+----------+-----------+-----------+

--- Últimos movimientos ---
[debt_payment] 2000.00  Bolsa → Costco Visa  abono visa
[credit_expense] 4500.00  Costco Visa → —  laptop
[expense] 800.00  Bolsa → —  supermercado
[income] 18000.00  — → Bolsa  sueldo quincena

=== END FINCORE STATE ===
```

## Significado de cada campo

| Campo | Qué representa |
|-------|---------------|
| **BO** | Efectivo total disponible (suma de cuentas `cash` + `debit`). |
| **DE** | Deuda total (suma de balances de cuentas `credit`). |
| **CR** | Crédito disponible (suma de `límite − deuda` por cuenta `credit`). |
| **Burn rate mensual** | Total de `expense` + `credit_expense` en los últimos 30 días. |
| **Uso de crédito** | `DE / Σlímites × 100`. Porcentaje de tu crédito total que estás usando. |

### Tabla de cuentas

| Columna | Significado |
|---------|-------------|
| `ID` | ID de la cuenta — úsalo en los demás comandos `fin:*` |
| `Nombre` | Nombre que le pusiste al crearla |
| `Tipo` | `cash`, `debit` o `credit` |
| `Balance` | Para `cash/debit`: efectivo en la cuenta. Para `credit`: deuda actual (positiva). |
| `Límite` | Solo para `credit`: tope máximo del crédito. |
| `Disp.` | Solo para `credit`: `Límite − Balance` = lo que aún puedes cargar. |

### Últimos movimientos

Cada línea muestra: `[kind] monto  origen → destino  descripción`. El símbolo `—` indica que ese lado de la operación es `null` (mundo externo).

Ejemplos de interpretación:
- `[income] 18000.00 — → Bolsa sueldo quincena` → entró dinero a Bolsa desde fuera.
- `[expense] 800.00 Bolsa → — supermercado` → salió dinero de Bolsa hacia fuera.
- `[debt_payment] 2000.00 Bolsa → Costco Visa abono visa` → moviste $2000 de Bolsa a Visa (abono).

## Cuándo usarlo

- **Inicio de sesión interactiva**: para recordar los IDs de tus cuentas antes de registrar movimientos.
- **Después de varios movimientos**: para verificar que los números cuadren con tu intuición.
- **Como salud check**: si BO o DE se ven raros, probablemente algo se registró mal y conviene investigar con [`GET /api/finance/entries`](../api/) (cuando exista) o `tinker`.

## Sin errores posibles

Este comando es solo de lectura. No puede fallar excepto si la base de datos está caída.
