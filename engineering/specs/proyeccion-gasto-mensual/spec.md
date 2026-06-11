# Proyección de gasto mensual por categoría

## Resumen

Séptimo reporte en `/reports/forecast`: para el mes en curso, por cada categoría de gasto con historial reciente, proyecta cuánto va a gastar el usuario al cierre del mes usando la fórmula **lineal por ritmo** (`gastado_actual × dias_totales_del_mes / dias_transcurridos`) y la compara contra el promedio de los 3 meses calendario inmediatamente anteriores. Marca con color (verde / amarillo / rojo) la magnitud del Δ% respecto al promedio. Incluye drill-down, export Excel y tab en el subnav siguiendo el patrón establecido por los 6 reportes existentes.

## Problema a resolver

Hoy el usuario ve sólo lo gastado, no lo que probablemente va a gastar. Los 6 reportes existentes responden "¿cuánto llevo gastado?" y el módulo Plan responde "¿qué eventos declaré para el futuro?". Falta una respuesta a "¿cuánto voy a terminar gastando si sigo con este ritmo?" — derivada del comportamiento real, sin necesidad de declarar eventos del Plan. Esta proyección es clave para anticipar excesos antes de que ocurran.

## Objetivo

Entregar un reporte que, sobre el mes en curso y por cada categoría con historial relevante, exponga 4 métricas comparables (gastado, promedio histórico, proyección, Δ% vs promedio) en una tabla ordenable y clickeable, sin agregar carga cognitiva ni introducir conceptos nuevos (filtros, ventanas configurables, alertas).

## Alcance

- 1 endpoint nuevo: `GET /api/finance/reports/forecast`.
- 1 endpoint nuevo de export Excel: `GET /api/finance/reports/forecast/export.xlsx`.
- 1 Report Service nuevo: `App\Domain\Finance\Reports\SpendingForecastReport`.
- 1 vista nueva lazy-loaded: `frontend/src/views/app/ReportsForecastView.vue`.
- 1 tab nuevo en `frontend/src/components/finance/ReportsSubnav.vue` ("Proyección").
- 1 ruta nueva en `frontend/src/router/index.js`: `/reports/forecast`.
- Integración con `EntriesDrilldownModal` (click en categoría abre los movimientos del mes en curso filtrados por esa `category_id`).
- Integración con `ExcelExportButton` (séptimo endpoint, mismo patrón establecido).
- Tests backend (Service + HTTP) y frontend (vista + smoke).

## Fuera de alcance

- Proyecciones de **income** (sólo gastos).
- Filtro por cuenta (`account_id`).
- Selector de mes (sólo mes en curso; no permite "proyectar diciembre desde noviembre" todavía).
- Selector de ventana histórica (siempre 3 meses).
- Proyecciones semanales o intra-mes.
- Alertas, notificaciones push o emails al exceder umbrales.
- Integración con Plan: las proyecciones del Plan son distintas (basadas en eventos declarados); este reporte se basa sólo en histórico real.
- Modificar el comportamiento de `BudgetsReport`. Si existe `monthly_limit` en la categoría, NO se compara contra él en v1 (queda para evolución futura).
- Cambios en categorías existentes (datos, schema, migraciones).
- Persistencia del orden de columnas o filtros por usuario.

## Reglas de negocio

- **Método de proyección**: lineal por ritmo. Fórmula:
  - `dias_totales_del_mes` = número total de días del mes en curso (28, 29, 30 o 31 según corresponda).
  - `dias_transcurridos` = día del mes de hoy (1..dias_totales_del_mes), inclusivo. Si hoy es día 1, `dias_transcurridos = 1`, no 0.
  - `proyeccion = gastado_actual × (dias_totales_del_mes / dias_transcurridos)`.
  - Si `gastado_actual = 0`, `proyeccion = 0` (sin inflado artificial).
- **Ventana histórica**: 3 meses calendario inmediatamente anteriores al mes en curso. Si hoy es 10 de junio de 2026, la ventana son los meses de marzo, abril y mayo de 2026 completos (incluyendo el último día). El promedio es `(gasto_mes_1 + gasto_mes_2 + gasto_mes_3) / 3`, **siempre dividido entre 3** (no entre la cantidad de meses con actividad). Esto refleja correctamente promedios reducidos cuando una categoría tiene actividad esporádica.
- **Cobertura**: la categoría aparece en el reporte si tiene al menos 1 entry de tipo `expense` o `credit_expense` (no cancelado) con `occurred_at` dentro de la ventana de 3 meses. Categorías sin ningún entry en la ventana se omiten.
- **Categorías archivadas** que tienen actividad en la ventana **sí aparecen** con su nombre/color/icono histórico (mismo patrón que `CategoryBreakdownReport` con `leftJoin` que no respeta el global scope de `SoftDeletes` para `categories`).
- **Bucket "Sin categorizar"**: entries con `category_id = NULL` se agrupan como un bucket adicional con label "Sin categorizar" (consistente con `CategoryBreakdownReport`).
- **Δ % vs promedio**:
  - Si `promedio > 0`: `delta_pct = ((proyeccion - promedio) / promedio) × 100`, redondeado a 1 decimal.
  - Si `promedio == 0` (caso degenerado que no debería pasar dada la regla de cobertura, salvo categorías con `entries` de monto 0): `delta_pct = null`. El frontend lo muestra como "—" sin color.
- **Color del Δ %** (mostrado por el frontend):
  - Verde: `delta_pct <= 0` (proyección igual o menor al promedio).
  - Amarillo: `0 < delta_pct <= 20`.
  - Rojo: `delta_pct > 20`.
  - Sin color (gris/neutral) si `delta_pct == null`.
- **Mes en curso**: definido por la fecha del servidor (`now()`), no por parámetro. El usuario no puede cambiar el mes.
- **Soft delete**: entries cancelados (`deleted_at`) se excluyen del cálculo (scope global de `JournalEntry`). El reporte es siempre "estado actual" — si el usuario cancela un entry, el reporte cambia inmediatamente.
- **Filosofía libreta libre**: el reporte es informativo. No genera advertencias bloqueantes ni eventos en el dominio.

## Requisitos funcionales

- RF-001: existe `GET /api/finance/reports/forecast` bajo el grupo `auth:sanctum + verified` que devuelve la proyección del mes en curso para el usuario autenticado.
- RF-002: el endpoint no acepta parámetros (`account_id`, `from`, `to`, `month` etc.). Cualquier parámetro extra se ignora o se rechaza con 422 según convenciones del controller.
- RF-003: la respuesta JSON tiene la siguiente estructura:
  ```json
  {
    "month": "2026-06",
    "today": "2026-06-10",
    "days_in_month": 30,
    "days_elapsed": 10,
    "window_from": "2026-03-01",
    "window_to": "2026-05-31",
    "categories": [
      {
        "category_id": "uuid-o-null",
        "name": "Comida",
        "color_slug": "orange",
        "icon_slug": "shopping-bag",
        "current_spent": 2500.00,
        "historical_average": 6000.00,
        "projection": 7500.00,
        "delta_pct": 25.0
      },
      ...
    ],
    "totals": {
      "current_spent": 8000.00,
      "historical_average": 12000.00,
      "projection": 24000.00,
      "delta_pct": 100.0
    }
  }
  ```
- RF-004: el campo `categories` está ordenado por `delta_pct` **descendente** (las que más se desvían arriba), con `null` al final.
- RF-005: el campo `totals` agrega las 4 métricas a través de todas las categorías incluidas. `totals.delta_pct` se calcula con la misma fórmula sobre los totales (no es promedio de delta_pct individuales).
- RF-006: existe `GET /api/finance/reports/forecast/export.xlsx` que devuelve el mismo reporte como archivo Excel `.xlsx`, siguiendo el patrón del sprint `export-excel-reportes` (helper `ReportExporter`, headers `Content-Type` + `Content-Disposition: attachment`, formato moneda MXN, formato porcentaje, fila final TOTAL con los agregados).
- RF-007: la vista `/reports/forecast` muestra:
  - Hero opcional con los 4 totales agregados.
  - Tabla con columnas: Categoría (badge color/icono + nombre) | Gastado este mes ($) | Promedio histórico ($) | Proyección fin de mes ($) | Δ % (con badge color verde/amarillo/rojo o "—").
  - Cada fila de categoría es clickeable y dispara `EntriesDrilldownModal` filtrado por `category_id` + `kind=expense` (que incluye `credit_expense` por convención de `CategoryBreakdownReport`) + rango del mes en curso (`from = día 1 del mes`, `to = hoy`).
  - Botón "Exportar a Excel" en la barra de filtros (no hay filtros configurables, sólo el botón).
- RF-008: la vista usa el componente `DateRangePreset.vue` **no** se aplica aquí (no hay rango configurable; el mes en curso es fijo).
- RF-009: `ReportsSubnav.vue` gana un séptimo tab "Proyección" enlazando a `/reports/forecast`.
- RF-010: la ruta nueva está bajo el guard de autenticación + email verificado del router.
- RF-011: el orden estable de los buckets es por `delta_pct` desc; las categorías con `delta_pct = null` van al final, ordenadas alfabéticamente entre ellas.
- RF-012: si el usuario no tiene **ninguna** categoría con historial en los 3 meses, la respuesta devuelve `categories: []` y `totals` con todos los campos en 0 (excepto `delta_pct = null`). La vista muestra empty state con CTA opcional ("Aún no tienes suficiente historial para proyectar; vuelve después de registrar movimientos por al menos un mes").

## Casos principales

- Usuario abre `/reports/forecast` el 10 de junio de 2026:
  - Su categoría "Comida" tiene 1 gasto de $2,500 este mes y promedio histórico $6,000 → proyección $7,500, Δ +25% (amarillo).
  - "Transporte" $800 actuales / promedio $1,000 → proyección $1,200, Δ +20% (amarillo, en el borde).
  - "Streaming" $450 actuales / promedio $450 → proyección $450, Δ 0% (verde).
  - "Ropa" $0 actuales / promedio $300 → proyección $0, Δ -100% (verde).
  - Tabla ordenada: Comida (+25%), Transporte (+20%), Streaming (0%), Ropa (-100%).
- Usuario hace click en "Comida": abre drill-down con los entries de junio en esa categoría (1 gasto de $2,500). Click en "Ir a Movimientos" → navega a `/entries?category_id=…&from=2026-06-01&to=2026-06-10&kind=expense`.
- Usuario hace click en "Exportar a Excel": descarga `fincore-proyeccion-gasto-2026-06.xlsx` con la misma tabla.

## Casos borde

- **Día 1 del mes**: `dias_transcurridos = 1`. Si el usuario aún no gastó nada (`current_spent = 0`), `proyeccion = 0` para todas las categorías. `delta_pct` se calcula contra el promedio: las categorías con `promedio > 0` muestran -100% (verde). Las categorías que sí tuvieron gasto temprano (ej. domiciliados) muestran proyecciones gigantes (porque el ritmo es de "1 día = 1/30 del mes"). Esto es **comportamiento aceptado**: el modelo lineal por ritmo da resultados extremos al principio del mes y el usuario debe interpretarlos con ese contexto. No se aplica ningún suavizado en v1.
- **Último día del mes**: `dias_transcurridos = dias_totales_del_mes`. `proyeccion == current_spent` exactamente. El reporte se comporta como un comparativo simple del mes actual vs el promedio.
- **Febrero**: `dias_totales_del_mes = 28` o `29` (bisiesto) según el año. El cálculo es transparente al usar `daysInMonth()` de Carbon.
- **Categoría con actividad en sólo 1 de los 3 meses**: la cobertura se cumple (al menos 1 entry). El promedio será `(gasto_mes_X + 0 + 0) / 3 = gasto_mes_X / 3`. Esto refleja que la categoría es esporádica y el promedio será chico — alineado con el diseño.
- **Categoría con entries pero suma = 0**: si todos los entries en la ventana son por monto 0 (caso muy patológico que no debería ocurrir en producción, pero contemplable), `promedio = 0` → `delta_pct = null`. Renderizado como "—".
- **Categoría archivada con histórico**: aparece en el reporte con su nombre/color/icono originales (igual que `CategoryBreakdownReport`). El usuario no puede crear nuevos entries en ella, pero los entries históricos siguen contando.
- **Bucket "Sin categorizar"**: entries con `category_id = NULL` se tratan como un grupo único llamado "Sin categorizar". Aparecen si tienen actividad tanto en la ventana como (potencialmente) en el mes en curso. Aplica las mismas reglas que cualquier otra categoría.
- **`credit_expense` y `expense`**: ambos cuentan como "gasto" (consistente con `CategoryBreakdownReport`). `debt_payment`, `transfer`, `income` NO cuentan.
- **Usuario sin movimientos en absoluto**: `categories: []`, `totals` en 0/null. Empty state amistoso.
- **Cambio de mes durante una sesión**: como el mes se calcula desde `now()` del servidor, si el usuario carga el reporte el 30 de junio a las 23:55 y refresca el 1 de julio a las 00:05, el reporte cambia: la ventana es ahora abril-junio, mes en curso es julio. Comportamiento esperado, no requiere manejo especial.
- **Zona horaria**: el cálculo del mes en curso usa la zona horaria del servidor (Mailpit/Carbon default — `APP_TIMEZONE` del backend). El usuario en otra zona puede ver "ayer" como "hoy" en casos extremos. No se ajusta a la zona del cliente en v1.
- **Entries cancelados (`deleted_at != null`)**: excluidos por el scope global de `SoftDeletes` en `JournalEntry`. El reporte refleja el "estado actual del libro".

## Criterios de aceptacion

- Existe el endpoint `GET /api/finance/reports/forecast` que responde con la estructura JSON definida en RF-003.
- Existe el endpoint `GET /api/finance/reports/forecast/export.xlsx` con headers correctos (Content-Type + Content-Disposition) y binario xlsx válido.
- Un test HTTP verifica que con un dataset conocido (ej. categoría con $2,500 en el mes actual y promedio $6,000), la respuesta tiene `projection: 7500` y `delta_pct: 25.0` (con tolerancia de redondeo).
- Un test verifica el caso "día 1 del mes con `current_spent = 0`": la proyección es 0, no NaN o error.
- Un test verifica el caso "promedio = 0": `delta_pct` viene `null` y no rompe la respuesta.
- Un test verifica que las categorías sin historial en la ventana **no** aparecen en `categories`.
- Un test verifica que las categorías archivadas con histórico **sí** aparecen con su nombre original.
- Un test verifica que entries cancelados no se incluyen.
- Un test verifica scope: user A no ve datos de user B.
- Un test verifica que el bucket "Sin categorizar" se procesa igual que las categorías normales.
- Un test verifica que las categorías están ordenadas por `delta_pct` desc, con `null` al final.
- En el frontend, un smoke con Playwright valida: `/reports/forecast` carga, muestra la tabla con las columnas esperadas, el badge de color del Δ% se ve según los umbrales, click en categoría abre el drill-down, click en "Exportar a Excel" dispara descarga.
- El tab "Proyección" aparece en el subnav y navega correctamente.
- La suite frontend (110 actuales + ~5-8 nuevos) queda verde.
- La suite backend (360 actuales + ~10-15 nuevos) queda verde.
- Sin regresiones en los 6 reportes existentes ni en sus exports.
- Sin migraciones, sin cambios en CLAUDE.md más allá de las 2 filas nuevas en la tabla de rutas (forecast + export).

## Criterios medibles de exito

- Tiempo de respuesta del endpoint `forecast` < 1s para datasets típicos (decenas de categorías × cientos de entries en la ventana).
- Tamaño del archivo `.xlsx` < 30 KB para reportes típicos.
- Cobertura de tests: al menos 10 tests HTTP + 3-5 unit del Service.
- Cero cambios al contrato de los endpoints existentes.
- El reporte se carga en una vista nueva sin afectar las 6 vistas previas ni el módulo Plan.

## Riesgos

- **Promedio dividido entre 3 vs entre meses con actividad**: la decisión documentada es **siempre entre 3**. Esto puede sorprender a usuarios cuya categoría tiene actividad en sólo 1 mes (verán un promedio de `gasto_unico / 3`, no `gasto_unico`). Mitigación: documentar en spec y, opcionalmente, agregar tooltip en la vista explicando el método.
- **Proyecciones extremas al inicio del mes**: día 1 con un gasto de $1,000 proyecta $30,000. Esperable matemáticamente, confuso emocionalmente. Mitigación: aceptado por diseño, sin suavizado. El usuario aprende con uso.
- **Zona horaria del servidor vs cliente**: el mes en curso se define del lado servidor. Si `APP_TIMEZONE` es distinta de la zona del usuario, hay desfase de hasta 24h. Mitigación: documentar como supuesto. Si se vuelve molesto, pasar `today` como parámetro opcional.
- **Performance con muchas categorías**: si el usuario tiene 50+ categorías con historial, el endpoint hace 4 sumas por categoría (1 mes actual + 3 meses ventana). Con índice por `(user_id, category_id, occurred_at)` esto es rápido; sin índice, podría ser lento. Verificar al implementar.
- **Doble contar `credit_expense` y `expense`**: si por error sólo se cuenta uno de los dos kinds, las proyecciones serán incompletas. Mitigación: copiar el patrón de `CategoryBreakdownReport`, que ya maneja esto correctamente.

## Supuestos

- El usuario quiere proyecciones del mes en curso únicamente; no hay UX para "ver junio cerrado desde julio".
- El usuario acepta que las proyecciones al inicio del mes son volátiles.
- Las etiquetas de UI son en español de México hardcodeadas.
- El `APP_TIMEZONE` del backend coincide con la zona del usuario (mismo supuesto que el resto de la app).
- Los buckets de "Sin categorizar" se renderizan con un placeholder neutro (color gris, icono genérico) en la tabla, igual que `CategoryBreakdownReport`.
- El reporte es siempre on-demand (no se persiste, no se cachea). Cada GET recalcula.
- El export Excel sigue exactamente el mismo patrón visual de los 6 anteriores (header de 2 filas + tabla con headers bold + fila TOTAL al final).
- Si en el futuro se quiere integrar con `BudgetsReport` (mostrar "Excede presupuesto" en proyecciones con `monthly_limit`), se hará en un sprint posterior sin tocar este.
- La fórmula `delta_pct = (proyeccion - promedio) / promedio × 100` se calcula en backend (no en frontend) para asegurar consistencia entre JSON y XLSX.

## Impacto esperado

- 2 endpoints nuevos en `routes/api.php` (forecast + export.xlsx).
- 1 Service nuevo `App\Domain\Finance\Reports\SpendingForecastReport`.
- 1 método nuevo en `FinanceController::reportForecast` (siguiendo el patrón de los otros 6 reportes).
- 1 método nuevo en `ReportExportController::forecast` (siguiendo el patrón del sprint export-excel-reportes).
- 1 vista Vue nueva: `ReportsForecastView.vue`.
- 1 tab nuevo en `ReportsSubnav.vue` (modificación trivial del array).
- 1 ruta nueva en `router/index.js`.
- 2 filas nuevas en la tabla de rutas de `CLAUDE.md`.
- Sección nueva en `docs/api/reports.md` para el endpoint.
- Sin migraciones, sin cambios en schema, sin cambios en seeders.
- Tests: ~10-15 backend (Service + HTTP), ~5-8 frontend (smoke + render).
- Estado esperado al cierre: backend ~375/375 verde, frontend ~118/118 verde.
