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
