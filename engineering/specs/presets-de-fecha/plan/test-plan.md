# Test plan — Presets de fecha

## Casos borde detectados

- **Hoy es lunes**: `'this_week'` devuelve `from = to = hoy`.
- **Hoy es 1 del mes**: `'this_month'` devuelve `from = to = hoy`. `'last_month'` devuelve rango completo del mes anterior.
- **Hoy es 31 de marzo**: `'last_month'` devuelve `2026-02-01` a `2026-02-28` (o 29 en bisiesto), NO `2026-03-00` ni `2026-02-31`.
- **Año bisiesto**: con `today = 2024-03-15`, `'last_month'` devuelve `2024-02-01` a `2024-02-29`.
- **Semana ISO cruzando año**: con `today = 2026-01-01` (miércoles), `'this_week'` devuelve `from = 2025-12-29` (lunes), `to = 2026-01-01`.
- **"Últimos 30 días" cruzando año**: con `today = 2026-01-01`, `from = 2025-12-03`.
- **"Últimos 30 días" cruzando DST**: con `today` justo después del cambio de horario (ej. 2 nov 2026 si zona aplica DST), el rango sigue siendo exactamente 30 días (el cálculo debe usar `setDate(-29)` no aritmética de milisegundos).
- **Clave inválida**: `rangeForPreset('invalid')` lanza `Error` con mensaje que incluye la clave.
- **`detectPreset` con strings vacíos**: `detectPreset('', '')` devuelve `'custom'`.
- **`detectPreset` con valores que no parsean**: `detectPreset('not-a-date', 'whatever')` devuelve `'custom'` sin throw.
- **`detectPreset` con rango que matchea un preset**: con `today = 2026-06-10`, `detectPreset('2026-06-01', '2026-06-10')` devuelve `'this_month'`.
- **`detectPreset` con rango que coincide con DOS presets** (improbable pero posible): devuelve el primero en orden de `DATE_PRESETS`. Test confirma orden.
- **Componente con `modelValue` cambiando externamente a un preset**: el dropdown se actualiza, los inputs se ocultan.
- **Componente con `modelValue` cambiando externamente a un rango custom**: el dropdown muestra "Personalizado", los inputs aparecen con los valores nuevos.
- **Edición de input en personalizado**: emite `update:modelValue` con un objeto nuevo `{ ...modelValue, [campo]: valor }`. El dropdown sigue en personalizado porque el rango editado no matchea.
- **Edición de input en personalizado que casualmente matchea un preset**: el componente salta al preset y oculta los inputs (comportamiento esperado por RF-004, documentado en spec).
- **`modelValue` con `from > to`**: el componente cae a `'custom'` y muestra los inputs con esos valores. La validación queda en el padre.
- **Watcher reactivo con mutación de propiedad** (`filters.value.from = X` en lugar de reemplazar el objeto): el watcher con `deep: true` lo capta. Test del componente cubre esto con un `Ref<{from, to}>` y mutación parcial.
- **Recarga de `/entries` con query params `?from=…&to=…`**: `EntriesTable` precarga esos valores; el componente debe detectar el preset correcto desde mount (cubierto por watcher `immediate: true`).
- **Recarga de `/entries` sin query params**: cae al default `'this_month'`; from = primer día del mes, to = hoy.

## Pruebas unitarias necesarias

En `frontend/tests/utils/dates.spec.js` (crear o ampliar):

- `rangeForPreset` para cada una de las 7 claves con un `today` fijo (`new Date(2026, 5, 10)`, mié 10 jun 2026):
  - `today` → `{ from: '2026-06-10', to: '2026-06-10' }`.
  - `this_week` → `{ from: '2026-06-08', to: '2026-06-10' }` (lunes 8).
  - `this_month` → `{ from: '2026-06-01', to: '2026-06-10' }`.
  - `last_month` → `{ from: '2026-05-01', to: '2026-05-31' }`.
  - `last_30_days` → `{ from: '2026-05-12', to: '2026-06-10' }`.
  - `last_90_days` → `{ from: '2026-03-12', to: '2026-06-10' }`.
  - `this_year` → `{ from: '2026-01-01', to: '2026-06-10' }`.
- Casos borde de `rangeForPreset`:
  - Hoy es lunes (`today = new Date(2026, 5, 8)`): `this_week` devuelve `{ from: to = 2026-06-08 }`.
  - Hoy es 1 del mes (`today = new Date(2026, 5, 1)`): `this_month` devuelve `{ from: to = 2026-06-01 }`; `last_month` devuelve `{ from: '2026-05-01', to: '2026-05-31' }`.
  - Hoy es 1 de marzo bisiesto (`today = new Date(2024, 2, 1)`): `last_month` devuelve `{ from: '2024-02-01', to: '2024-02-29' }`.
  - Hoy es 1 de marzo no bisiesto (`today = new Date(2026, 2, 1)`): `last_month` devuelve `{ from: '2026-02-01', to: '2026-02-28' }`.
  - Hoy es miércoles 1 de enero (`today = new Date(2026, 0, 1)`): `this_week` devuelve `from = 2025-12-29` (lunes anterior).
  - Hoy es 1 de enero: `last_30_days` devuelve `from = 2025-12-03`.
  - Clave inválida → throw con mensaje que cita la clave.
- `detectPreset` con `today = new Date(2026, 5, 10)`:
  - Para cada uno de los 7 presets, pasarle el `{ from, to }` que devuelve `rangeForPreset` y esperar la clave.
  - `detectPreset('2026-03-15', '2026-04-15')` → `'custom'`.
  - `detectPreset('', '')` → `'custom'`.
  - `detectPreset(null, null)` → `'custom'`.
  - `detectPreset('not-a-date', 'whatever')` → `'custom'` sin lanzar.
  - Orden: si dos presets coincidieran por casualidad (escenario sintético), devuelve el primero en orden de `DATE_PRESETS`.

En `frontend/tests/components/DateRangePreset.spec.js` (nuevo):

- Render inicial con `modelValue` matcheando un preset → dropdown muestra ese preset, inputs ocultos. Validar con `wrapper.find('input[type="date"]').exists() === false`.
- Render con `modelValue` que no matchea → dropdown en "Personalizado", 2 inputs visibles.
- Cambio del dropdown a un preset → emite `update:modelValue` con el rango correcto.
- Cambio del dropdown a "Personalizado" → muestra los inputs con los valores actuales sin emitir cambio (el modelValue no cambia, sólo la visibilidad).
- Edición de un input → emite `update:modelValue` con `{ ...modelValue, from/to: nuevo }`. Dropdown sigue en "Personalizado".
- Watch externo: `wrapper.setProps({ modelValue: rangeForPreset('last_month') })` → dropdown se actualiza al preset.
- Watch externo a rango custom: → dropdown salta a "Personalizado" y los inputs aparecen.
- Label opcional: pasar `label="Rango"` → se renderiza en el dropdown.
- Disabled: pasar `disabled=true` → BaseSelect y inputs reciben disabled.

## Pruebas de integracion o API necesarias

No aplica. Cambio puramente UI, sin endpoints nuevos ni modificados.

## Pruebas de UI o flujo necesarias si aplica

- **No hay tests por vista** en el repo (las vistas no tienen specs dedicados). Las modificaciones de las 3 vistas se validan por:
  - Lectura visual del diff de cada vista (re-layout simple).
  - Smoke manual en navegador (ver "Pruebas manuales").
  - Suite frontend completa sin regresiones.

## Pruebas de permisos y seguridad si aplica

No aplica. Cero impacto en auth, scope, validaciones del backend.

## Pruebas de datos, migracion o compatibilidad si aplica

No aplica. Sin migraciones.

## Pruebas de regresion sobre flujos existentes

- **Suite frontend completa**: `npx vitest run` debe pasar 72/72 actuales + tests nuevos.
- **Suite backend completa**: `php artisan test` debe pasar 360/360 sin cambios.
- **EntriesTable en `/entries`** sigue funcionando con sus filtros completos (account_id, category_id, kind, from, to). El componente nuevo sólo reemplaza los dos inputs from/to.
- **EntriesTable en `/accounts/:uuid`**: la prop `accountId` sigue ocultando el selector de cuenta; los presets funcionan igual.
- **Drill-down**: click en bucket de ByCategory abre el modal con `from/to` actuales; "Ir a Movimientos" navega a `/entries?from=…&to=…&kind=…`; en `/entries` el componente detecta el preset correcto.
- **Exportar a Excel**: el botón sigue usando `filters.value.from / to`; descarga el rango exacto independiente de si vino de preset o de "Personalizado".

## Pruebas manuales o smoke tests necesarios

Levantar el stack y validar en navegador:

1. `/reports/by-category` → cambiar dropdown a "Mes pasado" → el reporte refetchea y muestra data del mes anterior. Cambiar a "Personalizado" → aparecen los inputs precargados. Editar `from` → dropdown queda en "Personalizado" y refetchea.
2. `/reports/by-category` → seleccionar un preset, click "Exportar a Excel" → descarga xlsx con el rango del preset.
3. `/reports/by-category` → seleccionar un preset, click en un bucket → modal abre con entries del rango. Click "Ir a Movimientos" → navega a `/entries?from=…&to=…` y el dropdown de `/entries` detecta el preset correcto.
4. `/reports/by-account` → cambiar entre 3 presets → la tabla refetchea cada vez.
5. `/entries` → seleccionar "Últimos 30 días" → la lista refetchea con los movimientos del último mes.
6. `/entries` recargar con query params `?from=2026-06-01&to=2026-06-10` (rango matchea "Este mes" si hoy es jun 10) → dropdown muestra "Este mes" al cargar.
7. `/accounts/<uuid>` → cambiar el preset → la tabla refetchea, el filtro de cuenta sigue fijo.
8. `/reports/cashflow` → confirmar que NO se tocó: rango fijo en últimos 12 meses, sin dropdown nuevo.

## Datos de prueba recomendados

- 1 usuario con email verificado.
- Bolsa + 1 cuenta débito + 1 tarjeta crédito.
- 20-30 entries distribuidos entre hace 90 días y hoy, con mix de income/expense/credit_expense.
- Al menos 5 entries por mes para que los presets tengan data visible al cambiar.

## Comandos o validaciones locales sugeridas

```bash
# Frontend
cd /home/developer/Escritorio/proyectos/fincore/frontend
npx vitest run tests/utils/dates.spec.js
npx vitest run tests/components/DateRangePreset.spec.js
npx vitest run                              # suite completa

# Backend (smoke de no regresión)
docker compose exec -T -w /var/www/html api php artisan test
```

## Criterios minimos para aprobar la implementacion

- Suite frontend verde: 72 actuales + ~20 nuevos esperados (10+ del helper, 8+ del componente).
- Suite backend verde: 360/360 (sin cambios).
- Smoke manual: 7/7 escenarios listados en navegador OK.
- `ReportsCashflowView` sigue funcionando idéntico (sin tocar).
- El botón "Exportar a Excel" y el drill-down funcionan en todas las vistas modificadas.

## Validacion final recomendada

Ejecutar `branch-quality-review` con `slug=presets-de-fecha` antes de mergear. Foco recomendado:

1. **Cobertura de casos borde** en `rangeForPreset` y `detectPreset` (especialmente DST, año bisiesto, semana cruzando año).
2. **Reactividad del componente** con `deep: true` watcher: confirmar que captura mutaciones parciales (`filters.value.from = X`).
3. **Consistencia visual** entre las 3 vistas: mismo dropdown, mismo layout para los inputs en "Personalizado", misma altura/spacing.
4. **Regresión en EntriesTable** con query params del drill-down: validar que el preset se detecta correctamente al recargar.
5. **No regresión en exports**: los 6 endpoints xlsx siguen recibiendo el rango correcto.
