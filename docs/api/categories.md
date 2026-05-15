# API: Categories

CRUD de categorías para etiquetar movimientos del usuario autenticado. Todos los endpoints requieren `Authorization: Bearer <token>` + email verificado.

Cada usuario recibe **10 categorías default** al registrarse (creadas por el listener `CreateUserDefaultCategories`). Puede renombrarlas, cambiar color/icono, archivarlas o borrarlas. Las categorías por defecto cubren: Comida, Transporte, Vivienda, Servicios, Salud, Entretenimiento, Otros gastos, Salario, Inversiones, Reembolsos.

> **IDs**: `categories.id` es **UUID v7**, igual que el resto del dominio.

## Modelo

| Campo | Tipo | Notas |
|-------|------|-------|
| `id` | UUID | PK |
| `user_id` | UUID | Scope obligatorio; cada categoría pertenece a un usuario |
| `name` | string (max 80) | Único case-insensitive por usuario |
| `applies_to` | enum: `income` \| `expense` \| `both` | Filtra los formularios donde aparece |
| `color_slug` | string | 1 de 10 colores curados (ver abajo) |
| `icon_slug` | string | 1 de ~30 iconos curados (ver abajo) |
| `deleted_at` | timestamp \| null | Soft delete (sin reactivación) |
| `created_at`, `updated_at` | timestamp | — |

### Slugs de color permitidos

`blue`, `green`, `red`, `orange`, `purple`, `pink`, `teal`, `yellow`, `indigo`, `gray`.

Fuente: `backend/app/Domain/Finance/Catalog/CategoryDefaults::COLORS`. Los slugs mapean a CSS vars (`--color-category-{slug}`) en el frontend.

### Slugs de icono permitidos

`shopping-bag`, `shopping-cart`, `truck`, `home`, `bolt`, `light-bulb`, `film`, `musical-note`, `heart`, `academic-cap`, `book-open`, `globe-alt`, `map`, `gift`, `cake`, `device-phone-mobile`, `computer-desktop`, `fire`, `paint-brush`, `sparkles`, `briefcase`, `arrow-trending-up`, `credit-card`, `banknotes`, `currency-dollar`, `trophy`, `star`, `wrench`, `wrench-screwdriver`, `tag`.

Fuente: `backend/app/Domain/Finance/Catalog/CategoryDefaults::ICONS`. Los slugs mapean a componentes de `@heroicons/vue/24/outline` en el frontend.

## GET `/api/finance/categories`

Lista las categorías del usuario.

### Query params

- `include_archived` *(bool, default false)*: si es truthy (`1`, `true`), incluye soft-deleteadas.
- `applies_to` *(string, optional)*: filtra a `income` o `expense`. Las `both` siempre se incluyen en cualquier filtro. Útil para llenar el select de un formulario.

### Response 200

```json
{
  "categories": [
    {
      "id": "019e2899-aa11-7000-95a3-...",
      "user_id": "019e2899-7859-...",
      "name": "Comida",
      "applies_to": "expense",
      "color_slug": "orange",
      "icon_slug": "shopping-bag",
      "deleted_at": null,
      "created_at": "...",
      "updated_at": "..."
    }
  ]
}
```

## POST `/api/finance/categories`

Crea una categoría.

### Body

```json
{
  "name": "Café",
  "applies_to": "expense",
  "color_slug": "orange",
  "icon_slug": "cake"
}
```

### Response 201

```json
{ "category": { ... } }
```

### Errores

| Status | `code` | Cuándo |
|--------|--------|--------|
| 422 | `duplicate_category_name` | Ya existe otra categoría con el mismo nombre (case-insensitive) |
| 422 | `invalid_category_applies_to` | `applies_to` fuera de `income`/`expense`/`both` o nombre vacío / > 80 chars |
| 422 | `invalid_color_slug` | Color no está en el catálogo |
| 422 | `invalid_icon_slug` | Icono no está en el catálogo |

## PATCH `/api/finance/categories/{id}`

Actualiza una categoría. Campos editables: `name`, `applies_to`, `color_slug`, `icon_slug` (todos opcionales).

```json
{ "name": "Café especialidad", "color_slug": "purple" }
```

Mismos errores que `POST`, más `404` si la categoría no existe o no es del usuario.

## DELETE `/api/finance/categories/{id}`

Archiva (soft delete) la categoría. No requiere que esté "vacía" — los `JournalEntry` que la referencian conservan el `category_id` en BD pero la relación carga como null (el badge desaparece de la UI). **No existe endpoint de reactivación**.

```json
{ "message": "Categoría archivada" }
```

## PATCH `/api/finance/entries/{id}` (relacionado)

Permite editar **sólo** `category_id` y `description` de un `JournalEntry` existente. Cualquier otro campo (`amount`, `kind`, `account_origin_id`, etc.) devuelve `422 immutable_journal_field`.

```json
{
  "category_id": "019e2899-aa11-...",
  "description": "Almuerzo del lunes"
}
```

### Errores

| Status | `code` | Cuándo |
|--------|--------|--------|
| 422 | `immutable_journal_field` | Se intentó editar un campo no permitido |
| 422 | `invalid_category_applies_to` | La categoría no pertenece al usuario, o su `applies_to` no es compatible con el `kind` del entry |
| 404 | — | El entry no existe o no es del usuario |

## Reglas semánticas

- **Sólo `income`, `expense` y `credit_expense` aceptan `category_id`**. `transfer` y `debt_payment` son flujos internos y no se categorizan.
- `credit_expense` usa el mismo set de categorías que `expense` (más las de `both`).
- Una categoría archivada no aparece en los selects de los formularios pero los entries existentes que la referenciaban no se modifican.
- El nombre es único case-insensitive por usuario (también considera las archivadas para evitar reciclaje).
