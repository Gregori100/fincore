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
