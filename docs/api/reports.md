# API: Reports

Endpoints de agregación para vistas de análisis. Todos requieren `Authorization: Bearer <token>` + email verificado.

La idea es que esta sección crezca: hoy hay **un solo reporte** (gasto/ingreso por categoría). Los reportes futuros (cashflow mensual, tarjetas, proyecciones) entrarán bajo el mismo prefijo `/finance/reports/*` con su propio servicio en `backend/app/Domain/Finance/Reports/`.

## GET `/api/finance/reports/by-category`

Agrupa los movimientos del usuario por categoría dentro de un rango de fechas. Devuelve buckets ordenados por monto total descendente.

### Query parameters

| Parámetro | Tipo | Required | Notas |
|-----------|------|----------|-------|
| `kind` | `expense` \| `income` | sí | `expense` incluye tanto `expense` como `credit_expense` (semánticamente egresos). `income` solo `income`. |
| `from` | date `YYYY-MM-DD` | sí | Inclusivo. |
| `to` | date `YYYY-MM-DD` | sí | Inclusivo (compara hasta `to 23:59:59`). Debe ser `>= from`. |
| `account_id` | UUID | no | Si se pasa, sólo se cuentan los entries donde esa cuenta es **origen** (para `expense`) o **destino** (para `income`). |

### Response 200

```json
{
  "total": 1500.00,
  "count": 5,
  "buckets": [
    {
      "category_id": "019e2899-aa11-7000-...",
      "name": "Comida",
      "color_slug": "orange",
      "icon_slug": "shopping-bag",
      "total": 800.00,
      "count": 3
    },
    {
      "category_id": "019e2899-bb22-7000-...",
      "name": "Transporte",
      "color_slug": "blue",
      "icon_slug": "truck",
      "total": 500.00,
      "count": 1
    },
    {
      "category_id": null,
      "name": "Sin categorizar",
      "color_slug": null,
      "icon_slug": null,
      "total": 200.00,
      "count": 1
    }
  ]
}
```

### Comportamiento

- **"Sin categorizar"** aparece como un bucket más (`category_id: null`) si hay entries sin categoría en el rango. El total general incluye este bucket.
- **Categorías archivadas**: conservan su nombre, color e icono en reportes históricos (el JOIN usa `withTrashed()`).
- **Entries cancelados**: excluidos automáticamente (scope global de `SoftDeletes` en `JournalEntry`).
- **Scope**: sólo entries del usuario autenticado. No hay forma de ver datos cross-user.

### Errores

| Status | Cuándo |
|--------|--------|
| 422 | `kind` inválido, fechas mal formadas, `to < from`, o `account_id` inexistente |

### Ejemplo

```bash
curl "http://localhost/api/finance/reports/by-category?kind=expense&from=2026-05-01&to=2026-05-31" \
  -H "Authorization: Bearer $TOKEN" | jq
```

---

## GET `/api/finance/reports/cashflow-monthly`

Agrega ingresos vs egresos del usuario por mes dentro de un rango. Pensado para alimentar un gráfico de barras pareadas + línea de ahorro neto.

### Query parameters

| Parámetro | Tipo | Required | Notas |
|-----------|------|----------|-------|
| `from` | date `YYYY-MM-DD` | sí | Inclusivo. |
| `to` | date `YYYY-MM-DD` | sí | Inclusivo (compara hasta `to 23:59:59`). Debe ser `>= from`. |
| `account_id` | UUID | no | Filtra entries donde la cuenta sea origen O destino (cubre ambos lados del flujo). |

### Response 200

```json
{
  "months": [
    { "year_month": "2026-03", "income": 5000.00, "expense": 2100.00, "net": 2900.00 },
    { "year_month": "2026-04", "income": 5200.00, "expense": 1850.00, "net": 3350.00 },
    { "year_month": "2026-05", "income": 4000.00, "expense": 1500.00, "net": 2500.00 }
  ],
  "total_income": 14200.00,
  "total_expense": 5450.00,
  "total_net": 8750.00
}
```

### Comportamiento

- **Solo meses con actividad** se devuelven en `months`. El frontend rellena los meses vacíos con `{ income: 0, expense: 0, net: 0 }` para mantener una serie continua de N elementos.
- **`income`** = `SUM(amount)` donde `kind = 'income'`.
- **`expense`** = `SUM(amount)` donde `kind IN ('expense', 'credit_expense')`. El cargo a tarjeta cuenta como egreso aunque sea diferido.
- **`transfer` y `debt_payment` se excluyen**: son flujos internos entre cuentas propias y no afectan el patrimonio neto del usuario.
- **Entries cancelados** quedan fuera (scope global de `SoftDeletes`).
- **Scope**: sólo entries del usuario autenticado.

### Errores

| Status | Cuándo |
|--------|--------|
| 422 | Fechas mal formadas, `to < from`, o `account_id` inexistente |

### Ejemplo

```bash
curl "http://localhost/api/finance/reports/cashflow-monthly?from=2025-06-01&to=2026-05-31" \
  -H "Authorization: Bearer $TOKEN" | jq
```

---

## GET `/api/finance/reports/month-comparison`

Compara totales y categorías del mes pedido contra el mes inmediato anterior. Devuelve para cada categoría que tuvo actividad en cualquiera de los dos meses los montos `current`, `previous`, y los deltas absoluto y porcentual.

Se monta sobre `CategoryBreakdownReport`: hereda el comportamiento de `kind=expense` (incluye `expense + credit_expense`), bucket "Sin categorizar", scope per user, exclusión de cancelados, y nombres preservados de categorías archivadas.

### Query parameters

| Parámetro | Tipo | Required | Notas |
|-----------|------|----------|-------|
| `kind` | `expense` \| `income` | sí | Igual que en `/by-category`. |
| `month` | string `YYYY-MM` | sí | Mes "actual" del comparativo. El backend calcula el anterior. |
| `account_id` | UUID | no | Filtra al lado relevante según el kind (igual que `/by-category`). |

### Response 200

```json
{
  "current_month": "2026-05",
  "previous_month": "2026-04",
  "current_total": 2000.00,
  "previous_total": 1600.00,
  "delta": 400.00,
  "delta_pct": 25.0,
  "buckets": [
    {
      "category_id": "019e2899-aa11-...",
      "name": "Comida",
      "color_slug": "orange",
      "icon_slug": "shopping-bag",
      "current": 1200.00,
      "previous": 1000.00,
      "delta": 200.00,
      "delta_pct": 20.0
    },
    {
      "category_id": "019e2899-bb22-...",
      "name": "Entretenimiento",
      "color_slug": "purple",
      "icon_slug": "film",
      "current": 500.00,
      "previous": 0,
      "delta": 500.00,
      "delta_pct": null
    },
    {
      "category_id": "019e2899-cc33-...",
      "name": "Salud",
      "color_slug": "red",
      "icon_slug": "heart",
      "current": 0,
      "previous": 200.00,
      "delta": -200.00,
      "delta_pct": -100.0
    }
  ]
}
```

### Comportamiento clave

- **`delta_pct = null`** cuando `previous = 0`. Matemáticamente indefinido; el frontend lo muestra como badge "nueva".
- **`current = 0`** y `previous > 0`: la categoría "desapareció" este mes. El frontend muestra badge "sin actividad este mes".
- Los buckets vienen ordenados por **|delta|** descendente: la categoría que más cambió aparece primero.
- Si ambos meses están vacíos, `buckets` queda en `[]` y todos los totales en 0.

### Errores

| Status | Cuándo |
|--------|--------|
| 422 | `kind` inválido, `month` no cumple regex `YYYY-MM`, `account_id` inexistente |

### Ejemplo

```bash
curl "http://localhost/api/finance/reports/month-comparison?kind=expense&month=2026-05" \
  -H "Authorization: Bearer $TOKEN" | jq
```

---

## GET `/api/finance/reports/credit-cards`

Devuelve el estado actual de cada tarjeta de crédito activa del usuario: deuda, % de utilización, próximas fechas de corte/pago y totales del ciclo en curso y del último ciclo cerrado.

Pensado como **stepping stone hacia la Fase 2** (motor real de intereses y notificaciones). Los cálculos centrales viven aquí; el motor completo de saldo arrastrado e intereses moratorios queda para esa fase.

### Query parameters

Sin parámetros. La respuesta cubre siempre todas las tarjetas activas del usuario autenticado.

### Response 200

```json
{
  "cards": [
    {
      "id": "019e2899-...",
      "name": "Visa Oro",
      "balance": 4000.00,
      "credit_limit": 30000.00,
      "available": 26000.00,
      "utilization_pct": 13.33,
      "closing_day": 15,
      "payment_day": 5,
      "interest_rate": 0.0367,
      "minimum_payment_pct": 0.05,
      "next_closing_date": "2026-06-15",
      "days_to_closing": 24,
      "next_payment_date": "2026-06-05",
      "days_to_payment": 14,
      "current_cycle": {
        "from": "2026-05-16",
        "to": "2026-05-22",
        "charges_total": 500.00,
        "charges_count": 1
      },
      "last_cycle": {
        "from": "2026-04-16",
        "to": "2026-05-15",
        "charges_total": 1000.00,
        "charges_count": 2
      },
      "minimum_payment_estimated": 50.00
    }
  ]
}
```

### Comportamiento clave

- **Orden**: cards ordenadas por `utilization_pct` descendente (las más comprometidas arriba). Empate por nombre.
- **Tarjetas archivadas** quedan fuera.
- **Cargos cancelados** quedan fuera (scope global de `SoftDeletes`).
- **Definición del ciclo**: si hoy ya pasó el `closing_day` del mes, el ciclo en curso empieza al día siguiente del corte de este mes; si aún no llega, empieza al día siguiente del corte del mes anterior. El último ciclo cerrado termina justo en el `closing_day` previo al inicio del ciclo en curso.
- **Pago mínimo estimado** = total de cargos del **último ciclo cerrado** × `minimum_payment_pct`. Aproximación; no incluye saldo arrastrado ni intereses.

### Edge cases — metadatos incompletos

- `closing_day = null` → `next_closing_date`, `days_to_closing`, `current_cycle`, `last_cycle` y `minimum_payment_estimated` son `null`.
- `payment_day = null` → `next_payment_date` y `days_to_payment` son `null`.
- `minimum_payment_pct = null` → `minimum_payment_estimated` es `null`.

El frontend renderiza estos campos como "no configurado" con CTA al detalle de la cuenta para editar.

### Ejemplo

```bash
curl "http://localhost/api/finance/reports/credit-cards" \
  -H "Authorization: Bearer $TOKEN" | jq
```

---

## GET `/api/finance/reports/budgets`

Devuelve el progreso del mes en curso contra los presupuestos (`monthly_limit`) configurados por el usuario. Sólo considera categorías con `monthly_limit IS NOT NULL` y `applies_to ∈ {expense, both}`. El campo se persiste en `categories` cuando `applies_to=income`, pero **no se expone aquí** — se reserva para una fase futura donde "meta de ingreso" tenga su propia semántica visual.

### Query parameters

Sin parámetros. La respuesta cubre todas las categorías activas con presupuesto.

### Response 200

```json
{
  "month": "2026-05",
  "total_limit": 4500.00,
  "total_spent": 3100.00,
  "total_pct": 68.89,
  "buckets": [
    {
      "category_id": "019e2899-...",
      "name": "Comida",
      "color_slug": "orange",
      "icon_slug": "shopping-bag",
      "monthly_limit": 2000.00,
      "spent": 1700.00,
      "remaining": 300.00,
      "pct_consumed": 85.00
    },
    {
      "category_id": "019e2899-...",
      "name": "Transporte",
      "color_slug": "blue",
      "icon_slug": "truck",
      "monthly_limit": 1500.00,
      "spent": 800.00,
      "remaining": 700.00,
      "pct_consumed": 53.33
    },
    {
      "category_id": "019e2899-...",
      "name": "Salud",
      "color_slug": "red",
      "icon_slug": "heart",
      "monthly_limit": 1000.00,
      "spent": 600.00,
      "remaining": 400.00,
      "pct_consumed": 60.0
    }
  ]
}
```

### Comportamiento clave

- **Mes en curso**: `occurred_at` entre el día 1 del mes y `hoy 23:59:59`. No mira meses anteriores.
- **Gasto**: suma de `expense + credit_expense` con esa `category_id`. Cancelados quedan fuera por scope global de `SoftDeletes`.
- **`remaining` puede ser negativo** si `spent > monthly_limit`. El frontend lo muestra como "Te pasaste".
- **`pct_consumed`**:
  - `monthly_limit > 0` → `(spent / monthly_limit) * 100`.
  - `monthly_limit == 0` Y `spent > 0` → devuelve `999` (sentinel para color rojo en el frontend).
  - `monthly_limit == 0` Y `spent == 0` → `0`.
- **Orden**: buckets ordenados por `pct_consumed` desc.
- **Categorías archivadas** quedan fuera.

### Errores

| Status | Cuándo |
|--------|--------|
| 401 | Sin token o expirado |
| 403 | Email no verificado |

### Ejemplo

```bash
curl "http://localhost/api/finance/reports/budgets" \
  -H "Authorization: Bearer $TOKEN" | jq
```

---

## Export a Excel (.xlsx)

Cada uno de los 6 reportes anteriores tiene un endpoint paralelo que devuelve los mismos datos serializados como archivo Excel (`.xlsx`), generado en backend con PhpSpreadsheet.

### Endpoints

- `GET /api/finance/reports/by-category/export.xlsx`
- `GET /api/finance/reports/cashflow-monthly/export.xlsx`
- `GET /api/finance/reports/month-comparison/export.xlsx`
- `GET /api/finance/reports/credit-cards/export.xlsx`
- `GET /api/finance/reports/budgets/export.xlsx`
- `GET /api/finance/reports/by-account/export.xlsx`

### Query parameters

Cada endpoint xlsx acepta exactamente los mismos query params que su contraparte JSON (ver secciones anteriores). Las validaciones también son idénticas; query params inválidos devuelven 422 con el payload estándar de Laravel.

### Response 200

- `Content-Type: application/vnd.openxmlformats-officedocument.spreadsheetml.sheet`
- `Content-Disposition: attachment; filename="fincore-<reporte>-<rango>.xlsx"`
- Body: binario `.xlsx` (firma ZIP `PK\x03\x04`).

### Patrón de nombre de archivo

| Reporte | Patrón |
|---------|--------|
| Por categoría | `fincore-por-categoria-YYYY-MM-DD_YYYY-MM-DD.xlsx` |
| Cashflow mensual | `fincore-cashflow-mensual-YYYY-MM-DD_YYYY-MM-DD.xlsx` |
| Comparativo mes vs mes | `fincore-comparativo-mes-YYYY-MM.xlsx` |
| Tarjetas de crédito | `fincore-tarjetas-credito.xlsx` |
| Presupuestos | `fincore-presupuestos.xlsx` |
| Por cuenta | `fincore-por-cuenta-YYYY-MM-DD_YYYY-MM-DD.xlsx` |

### Estructura del workbook

- Una hoja por archivo (worksheet count = 1). El título de la hoja coincide con el nombre humano del reporte (truncado a 31 chars por límite de Excel).
- Filas 1-2: encabezado (nombre + rango/contexto + fecha de generación).
- Fila 4: headers en bold con fondo gris claro.
- Filas 5..N: data, con formatos por columna (`$#,##0.00` para moneda, `0.0%` para porcentajes, `0` para enteros).
- Fila N+1: footer `TOTAL` en bold con SUMA por columna. Tarjetas de crédito **no lleva** footer (cada fila es independiente).
- Cuentas archivadas se excluyen; categorías archivadas conservan su nombre histórico en agregados (igual que el endpoint JSON).
- Filtro `account_id` y `category_id` validan que pertenezcan al usuario autenticado (422 si vienen de otro usuario).

### Errores

| Status | Cuándo |
|--------|--------|
| 401 | Sin token o expirado |
| 403 | Email no verificado |
| 422 | Query params inválidos (mismas reglas que el endpoint JSON) |

### Ejemplo

```bash
curl -OJ "http://localhost/api/finance/reports/by-category/export.xlsx?kind=expense&from=2026-05-01&to=2026-05-31" \
  -H "Authorization: Bearer $TOKEN"
# -O guarda con el filename que envía el servidor en Content-Disposition.
```
