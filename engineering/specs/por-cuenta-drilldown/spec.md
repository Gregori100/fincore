# Reporte "por cuenta" + drill-down transversal en todos los reportes

## Resumen

Dos mejoras al módulo de reportes que se entregan juntas. La primera es un sexto reporte llamado **Por cuenta**, que para cada cuenta del usuario muestra ingresos totales, gastos totales y neto en el rango elegido. La segunda es un comportamiento **drill-down transversal**: cualquier "bucket" mostrado en cualquier reporte (una categoría, un mes, una tarjeta, un presupuesto, una celda de cuenta) es clickeable y abre un modal compacto con la lista de movimientos que lo componen, con un botón para saltar a `/entries` con los mismos filtros aplicados. Un único endpoint genérico sirve la lista de movimientos del bucket para todos los reportes.

## Problema a resolver

Hoy los reportes responden "¿cuánto?" pero no "¿qué movimientos exactos componen ese número?". Para auditar o entender un bucket grande, el usuario tiene que ir a `/entries` y aplicar manualmente los filtros — frágil y propenso a errores de scope. Además falta la perspectiva "por cuenta": el usuario no puede ver en una pantalla cuál cuenta concentra ingresos, gastos y movimiento neto en un periodo.

## Objetivo

1. Entregar un reporte nuevo `/reports/by-account` con tabla **Cuenta | Ingresos | Gastos | Neto** sobre el rango seleccionado, alineado al patrón de los reportes existentes.
2. Permitir que cualquier valor numérico clave de cualquier reporte (incluido el nuevo) se "abra" en un modal con los movimientos exactos que lo componen, sin perder el contexto del reporte.
3. Centralizar la consulta de movimientos por bucket en un único endpoint genérico con filtros estandarizados, evitando duplicar lógica por reporte.
4. Ofrecer una puerta de salida natural desde el drill-down a `/entries` cuando el usuario necesita la potencia completa (paginación, edición, cancelación, exportación futura).

## Alcance

- **Backend**: nuevo Service `Domain/Finance/Reports/ByAccountReport` que arma la matriz Cuenta × {Ingresos, Gastos, Neto} para un rango `from`/`to`; endpoint `GET /api/finance/reports/by-account` análogo al patrón existente; nuevo endpoint genérico de drill-down `GET /api/finance/reports/entries-by-bucket` que reusa la query de `listEntries` sin paginación; ambos con scope estricto por `user_id`.
- **Frontend**:
  - Vista nueva `ReportsByAccountView.vue` lazy-loaded en `/reports/by-account`.
  - Componente reusable `EntriesDrilldownModal.vue` que cualquier reporte invoca pasando filtros estandarizados.
  - Modificación de los 5 reportes existentes para que cada bucket sea clickeable y abra el modal.
  - Subnav (`ReportsSubnav`) gana un sexto tab "Por cuenta".
- **Tests**: backend (Service nuevo + endpoint by-account + endpoint genérico drill-down) y mínimo unit del modal en frontend.

## Fuera de alcance

- Gráfica para el reporte "por cuenta" (dona, barras). La tabla alcanza para v1; agregar visual queda para iteración posterior.
- Paginación dentro del modal de drill-down. Se muestran hasta 100 movimientos por bucket; si supera ese tope, la UI invita a usar `/entries` para ver todo.
- Edición o cancelación de movimientos dentro del modal. Las acciones destructivas viven en `/entries`.
- Drill-down a segundo nivel desde dentro del modal (ej. desde un movimiento abrir otro modal). El modal es terminal: se cierra o se va a `/entries`.
- Exportación de la lista del drill-down a CSV. Queda para el sprint "Export CSV/PDF" del backlog.
- Reporte cruzado cuenta × categoría. v1 mantiene cada reporte independiente.
- Cambios en la UX de `/entries`. Solo se garantiza que acepta los query params estándar para precargar filtros.

## Reglas de negocio

- **Reporte por cuenta**:
  - Las "entradas" de una cuenta son la suma de `journal_entries.amount` donde `account_destination_id = cuenta.id` y la entry no está soft-deleted.
  - Las "salidas" son la suma donde `account_origin_id = cuenta.id`.
  - El **neto** = entradas − salidas. Es positivo cuando la cuenta recibió más de lo que salió.
  - Para cuentas tipo `cash` y `debit` la semántica es directa: entradas = ingresos recibidos + transfers entrantes, salidas = gastos + transfers salientes + pagos a tarjeta.
  - Para cuentas tipo `credit` la semántica se preserva en términos de movimiento contable: entradas = `debt_payment` recibidos (la deuda baja); salidas = `credit_expense` (la deuda sube). Documentado en el copy del reporte para evitar confusión visual ("entradas" en una tarjeta significa "te abonaron a la deuda").
  - Cuentas archivadas no aparecen en la tabla aunque tengan movimientos históricos.
  - El rango por defecto es el mes en curso (primer día del mes hasta hoy), consistente con `/entries`.
- **Drill-down**:
  - El endpoint devuelve los `journal_entries` activos del usuario que cumplen los filtros pasados. No incluye soft-deleted por defecto.
  - El modal incluye en su header el resumen del bucket: descripción humana ("Gastos de Comida en mayo 2026") y total monetario.
  - La query reusa la lógica de filtros de `listEntries` (kind, account_id, category_id, from, to). Se agrega soporte para `year_month` como atajo (se traduce a from = primer día del mes / to = último día del mes).
  - Cap suave: máximo 100 entries devueltos por request; si la query natural matchea más, el endpoint responde igual con los primeros 100 ordenados por `occurred_at DESC` y un campo `truncated: true` + `total_count`. El frontend muestra el aviso y el botón "Ir a /entries".
  - El botón "Ir a /entries" navega a `/entries` con los filtros como query string. La vista `/entries` ya soporta filtros por account_id, category_id, kind, from, to; si no soporta alguno (ej. `year_month`), se traduce a from/to.
  - Cada reporte conoce qué filtros aplica al hacer click en un bucket. Ver mapeo en RF-007.

## Requisitos funcionales

- RF-001: El sistema debe exponer `GET /api/finance/reports/by-account?from=YYYY-MM-DD&to=YYYY-MM-DD` que devuelve, por cada cuenta no archivada del usuario, `{ account_id, name, type, income, expense, net }`.
- RF-002: El reporte por cuenta debe respetar scope por `user_id` y excluir registros soft-deleted (entries y cuentas).
- RF-003: El sistema debe exponer `GET /api/finance/reports/entries-by-bucket` con filtros `kind`, `account_id`, `category_id`, `from`, `to`, `year_month` (todos opcionales); responde `{ entries: [...], truncated: bool, total_count: int, bucket_label: string }`.
- RF-004: El endpoint de drill-down debe devolver máximo 100 entries por request, ordenados por `occurred_at DESC`, con datos relacionados eager-loaded (origin, destination, category) para que el modal no haga N+1.
- RF-005: La UI debe exponer `/reports/by-account` con tabla **Cuenta | Ingresos | Gastos | Neto**; cada cuenta y cada celda numérica son clickeables para abrir el modal de drill-down con los filtros correspondientes.
- RF-006: `ReportsSubnav` debe incluir un sexto tab "Por cuenta" apuntando a `/reports/by-account`.
- RF-007: Cada reporte existente debe invocar el modal con los filtros correctos según el bucket clickeado:
  - **Por categoría**: `{ kind, category_id, from, to }`.
  - **Cashflow mensual**: `{ kind: 'income' | 'expense', year_month }`.
  - **Comparativo mes vs mes**: `{ kind, category_id, year_month }` para el bucket del mes actual o `year_month` previo según la celda.
  - **Tarjetas de crédito**: `{ account_id, kind: 'credit_expense', from, to }` (rango del mes en curso o el que el reporte muestre).
  - **Presupuestos**: `{ category_id, kind: 'expense', from: primer día del mes, to: hoy }`.
  - **Por cuenta (nuevo)**: `{ account_id }` para ver todo el movimiento de la cuenta en el rango; `{ account_id, kind }` para la celda específica de Ingresos o Gastos.
- RF-008: El modal de drill-down (`EntriesDrilldownModal`) muestra: header con `bucket_label` y total; tabla compacta con fecha, monto (con signo según kind), descripción, cuentas (origen → destino) y badge de categoría cuando existe; footer con "Cerrar" y "Ir a /entries".
- RF-009: El botón "Ir a /entries" navega a la ruta con los filtros del bucket como query params. La vista `/entries` debe leer esos query params en `onMounted` y aplicarlos a sus filtros locales si no estaban seteados ya.
- RF-010: Cuando el endpoint reporta `truncated: true`, el modal muestra un aviso "Mostrando los 100 más recientes de N — para ver todo abre en Movimientos" antes del footer.
- RF-011: El modal debe respetar la accesibilidad estándar de los modales del proyecto (cierre con Escape, click-fuera, foco trampado) sin agregar `persistent: true` (es modal informativo, no destructivo).
- RF-012: Los nuevos endpoints deben respetar el middleware `['auth:sanctum', 'verified']` igual que el resto del módulo.

## Casos principales

- Auditar gastos de Comida: en `/reports/by-category`, click en la barra/dona "Comida" → modal con los gastos del mes en esa categoría → revisa los 12 movimientos → cierra. Si quiere editar uno, "Ir a /entries".
- Ver mes peor: en cashflow mensual, click en la barra de "Mayo" para gastos → modal con los gastos del mes → entiende qué disparó el pico.
- Foco en una cuenta: abrir `/reports/by-account`, ver que Banamex tuvo $4,200 de salida → click en la celda Gastos de Banamex → modal con todos los gastos hechos desde Banamex en el rango.
- Revisar uso de una tarjeta: en `/reports/credit-cards`, click en el monto de "Cargos del mes" de Visa → modal con esos cargos → cierra y sigue revisando otras tarjetas.
- Saltar a edición: desde cualquier drill-down, "Ir a /entries" → la vista de entries abre filtrada y permite cancelar/editar.

## Casos borde

- Bucket con 0 movimientos (categoría sin uso en el mes): el modal abre con tabla vacía y mensaje "Sin movimientos en este bucket". Footer presente.
- Bucket con más de 100 movimientos: `truncated: true`, aviso visible, botón "Ir a /entries" destacado.
- Cuenta archivada después de generar el reporte: en `/reports/by-account` no aparece; si el usuario llegó al modal con un `account_id` archivado, el endpoint devuelve los entries históricos igual (el filtro es por id, no por activo), porque cancelar el drill-down rompería casos legítimos de auditar histórico. Documentar.
- Categoría archivada: similar. El modal muestra los entries; el badge de categoría usa nombre actual (Eloquent default sin `withTrashed` devolverá null → mostrar guion).
- Rango futuro (from > hoy): tabla vacía sin error. Endpoint válido devuelve `entries: []`.
- `year_month` malformado (ej. "2026-13"): 422 con mensaje claro.
- Tarjeta de crédito sin movimientos en el rango: aparece en la tabla con ceros, neto cero, sin link clickeable (deshabilitado o ausente).
- Movimientos `transfer` en el reporte por cuenta: cuenta una entrada en la cuenta destination y una salida en la cuenta origin. El neto agregado por usuario suma cero (lo que entra de un lado sale del otro), lo cual es correcto contablemente.
- Movimientos `debt_payment` y `credit_expense`: aportan a entradas/salidas según destino/origen, mismo patrón. El copy del reporte aclara la semántica para tarjetas.
- Filtros incompatibles (ej. kind=transfer + category_id): la query devuelve vacío porque `transfer` no se categoriza. Sin error.
- Drill-down de comparativo cuando un mes no tuvo movimientos en la categoría: tabla vacía.
- Usuario sin cuentas activas: la tabla del reporte queda vacía con copy "Aún no tienes cuentas activas".

## Criterios de aceptacion

- `GET /api/finance/reports/by-account` responde con array de cuentas (cash + débito + crédito no archivadas), cada una con `income`, `expense` y `net` exactos vs cálculo manual sobre `journal_entries` activos.
- `GET /api/finance/reports/entries-by-bucket` con filtros válidos devuelve la lista esperada, max 100, ordenada por `occurred_at DESC`, con `truncated` correcto.
- `/reports/by-account` renderiza la tabla, respeta el rango del filtro (default mes en curso) y el subnav tiene el sexto tab.
- Click en cualquier celda numérica abre el modal con el bucket correcto. Click en el nombre de la cuenta abre el modal sin filtro de kind (todos los movimientos).
- En los 5 reportes existentes, los buckets son clickeables y abren el modal con los filtros mapeados en RF-007. Ningún reporte queda sin la funcionalidad.
- "Ir a /entries" desde el modal carga `/entries` con los filtros precargados: el campo de cuenta, categoría, kind y rango quedan seteados al valor del bucket.
- Aviso de truncado aparece si y solo si la query natural tiene >100 entries.
- El badge de categoría dentro del modal coincide con el de la tabla de entries; cuando la categoría está archivada o nula, se muestra guion.
- Cero regresiones: la suite backend (actual 300+) queda verde; los 5 reportes existentes siguen funcionando y los tests vigentes pasan.

## Criterios medibles de exito

- Endpoint by-account responde en menos de 300 ms para usuarios con hasta 5 cuentas y 500 movimientos.
- Endpoint entries-by-bucket responde en menos de 300 ms para 100 entries.
- Cobertura de tests sobre `ByAccountReport` y el método de entries-by-bucket ≥ 90 %.
- Cero N+1 en el drill-down: profiler de Laravel reporta exactamente 1 query principal + eager loads.
- Suite frontend 49+ verde.
- Recorrido manual (6 pasos: por-cuenta, drill-down desde cada reporte, "ir a entries") sin errores.

## Riesgos

- **Inconsistencia semántica en tarjetas**: el copy debe ser muy claro para que "entradas en Visa = pagos a la tarjeta" no se confunda con "ingreso de dinero". Sin copy claro, el usuario malinterpreta. Mitigación: tooltip/leyenda en la columna y un párrafo bajo el subnav cuando aparece una tarjeta en la tabla.
- **Buckets vacíos clickeables**: si una celda dice $0 y el usuario hace click, abre un modal vacío. Costo bajo, pero molesto. Mitigación: deshabilitar el click cuando la celda es 0 (lógica simple en el componente).
- **Cap de 100 en drill-down**: para usuarios con muchos movimientos, el aviso "ver todo en /entries" puede ser frecuente. Mitigación: documentar; si en uso real es molesto, aumentar el cap o paginar el modal.
- **Lecturas duplicadas frente a `/entries`**: el endpoint genérico de drill-down y `listEntries` consultan parcialmente lo mismo. Hay riesgo de divergencia si las reglas de filtrado evolucionan. Mitigación: que ambos compartan un helper privado de armado de query en `FinanceController`, o extraerlo a un service `EntryQueryService` cuando el segundo consumidor lo justifique.
- **Vista `/entries` no soporta query params hoy**: hay que ajustarla para leerlos en mount. Cambio chico pero necesario.

## Supuestos

- El reporte "por cuenta" usa por defecto el mes en curso (primer día → hoy), igual que `/entries`.
- El endpoint de drill-down devuelve los entries con relaciones eager-loaded (`origin`, `destination`, `category`), respetando el patrón existente.
- El cap del modal es 100 entries por bucket. Suficiente para casi todos los buckets reales en uso personal.
- El modal de drill-down NO permite editar/cancelar; redirige a `/entries` para esas acciones.
- `EntriesDrilldownModal` es reusable; cada reporte le pasa un objeto de filtros estandarizado.
- El modal tiene tamaño `lg` (ancho intermedio); usa `BaseModal` con el prop `size` ya existente. No es `persistent` porque es informativo.
- La vista `/entries` ya acepta filtros por account_id, category_id, kind, from, to en su estado local; agregamos lectura de query params al mount sin cambiar la UI ni la lógica interna.
- Subnav: la lista de tabs vive en `ReportsSubnav.vue` como array (verificado en sprint anterior). Agregar un tab es tocar ese array.
- Tipos de cuenta cubiertos por el reporte: cash, debit, credit. Si en el futuro se introducen otros, se evalúa.
- El header del modal usa `bucket_label` que viene del backend (ej. "Gastos de Comida en mayo 2026"); para los reportes existentes que no lo pasan, el frontend arma un fallback con los filtros recibidos.

## Impacto esperado

- **Backend**: un Service nuevo (`ByAccountReport`), dos endpoints nuevos (`by-account` y `entries-by-bucket`), métodos en `FinanceController`, ajustes de rutas. Sin migraciones. Sin cambios de schema.
- **Frontend**: una vista nueva, un componente modal nuevo, modificaciones puntuales en los 5 reportes existentes (handlers de click + emit), update del subnav, ajuste mínimo en `/entries` para leer query params, ajuste en `api/finance.js` para el endpoint nuevo.
- **DX**: el patrón de drill-down queda como pieza reusable. Reportes futuros que se sumen heredan el comportamiento al emitir el evento con los filtros.
- **Usuario**: cada número en cualquier reporte se vuelve auditable en un click. El reporte "por cuenta" cierra una pregunta recurrente ("¿qué cuenta uso más para gastar?").
- **Performance**: lecturas adicionales por reporte solo cuando el usuario abre un drill-down (lazy). El cap de 100 mantiene el costo acotado.
