# Branch Quality Review — export-excel-reportes

- **Rama**: `main` (cambios en working tree, no commiteados; sumándose a 14 commits previos pendientes de push).
- **Base**: `main` (último commit `824248b fix(plan): validar rango de fecha…`).
- **Rango revisado**: working tree diff completo del sprint.
- **Fecha**: 2026-06-10 16:43.
- **Reviewers** (paralelos, vía Explore): Seguridad, Performance, Frontend/UX.
- **Tests al momento del review**: backend 360/360, frontend 72/72, Pint sin diffs en archivos del sprint, smoke por curl 6/6 con `Microsoft Excel 2007+`.

## Resumen ejecutivo

Sprint en buen estado para merge tras atender 1 hallazgo medio en el composable de descarga. No hay bloqueantes de seguridad ni datos. Los hallazgos de performance son N+1 **preexistentes** en CreditCardsReport y BudgetsReport (no introducidos en este sprint); se documentan para que queden visibles, no para corregir aquí. Los hallazgos restantes son mejoras de UX/defensa en profundidad.

**Bloqueantes**: 0.  
**Altos**: 0.  
**Medios**: 4 (1 nuevo, 3 preexistentes documentados).  
**Bajos**: 3.

## Hallazgos

### M1 — Posible leak de blob URL si `triggerDownload` lanza (nuevo, atribuible al sprint)

- **Archivo**: `frontend/src/composables/useExcelDownload.js:91-102`.
- **Detalle**: `triggerDownload(blob, filename)` crea `URL.createObjectURL(url)` y al final llama `URL.revokeObjectURL(url)`. Si entre medio cualquiera de `appendChild` / `anchor.click()` / `removeChild` lanza, el `revoke` no se ejecuta y la URL queda viva hasta el page reload.
- **Riesgo real**: bajo en operación normal (estos métodos rara vez lanzan en jsdom o navegadores modernos), pero defensa en profundidad sí justifica un `try/finally`.
- **Severidad**: Medio.
- **Acción recomendada**: envolver el bloque entre `URL.createObjectURL` y `URL.revokeObjectURL` con `try/finally` para garantizar el revoke. Mover el `removeChild` y el `revoke` al `finally`.

### M2 — Blob de error con `Content-Type: text/html` no detectado como error (nuevo)

- **Archivo**: `frontend/src/composables/useExcelDownload.js:32`.
- **Detalle**: el composable detecta sólo `application/json` para parsear errores del backend. Si Laravel está en modo debug y emite un HTML de error (response 500 con `text/html`), el composable lo trata como blob xlsx válido y lo descarga como `.xlsx`. El usuario abre un archivo corrupto.
- **Riesgo real**: bajo en producción (`APP_DEBUG=false`); molestia en dev. La librería de Laravel además respeta `Accept: application/json` que el cliente sí envía por interceptor.
- **Severidad**: Medio.
- **Acción recomendada**: además de `application/json`, considerar también `text/html` como Content-Type de error y mostrar un toast genérico ("Error al exportar — código HTTP X"). Opcionalmente validar que el blob comienza con la firma ZIP `PK\x03\x04` antes de descargar.

### M3 — `CreditCardsReport::cycleSummary` con N+1 (PREEXISTENTE — no introducido en este sprint)

- **Archivo**: `backend/app/Domain/Finance/Reports/CreditCardsReport.php:42-96`.
- **Detalle**: por cada tarjeta de crédito ejecuta 2 queries (ciclo actual + ciclo anterior). Con 5 tarjetas → 10+ queries.
- **Origen**: pre-existente desde la implementación inicial del reporte de tarjetas, NO introducido por este sprint.
- **Severidad**: Medio (sólo si el usuario tiene muchas tarjetas y abre el reporte/export muy seguido).
- **Acción recomendada**: dejar como nota en el backlog de optimización. No bloquea este merge.

### M4 — `BudgetsReport` con N+1 por categoría (PREEXISTENTE)

- **Archivo**: `backend/app/Domain/Finance/Reports/BudgetsReport.php:52-81`.
- **Detalle**: invoca `.sum('amount')` dentro del `.map()` de categorías. Una query por cada categoría con `monthly_limit`.
- **Origen**: pre-existente.
- **Severidad**: Medio.
- **Acción recomendada**: backlog, junto con M3.

### B1 — Falta `aria-label` en `ExcelExportButton`

- **Archivo**: `frontend/src/components/finance/ExcelExportButton.vue:33-41`.
- **Detalle**: el botón visible tiene texto "Exportar a Excel" pero no `aria-label` explícito ni `role` distinto. Para screen readers funciona porque el texto está dentro del `<button>`, pero el icono no tiene `aria-hidden`.
- **Severidad**: Bajo.
- **Acción recomendada**: agregar `aria-hidden="true"` al icono y un `aria-label="Exportar a Excel"` redundante por accesibilidad.

### B2 — Disabled state redundante en `ReportsCreditCardsView` y `ReportsBudgetsView`

- **Archivos**: `frontend/src/views/app/ReportsCreditCardsView.vue:73-79`, `frontend/src/views/app/ReportsBudgetsView.vue:93-99`.
- **Detalle**: el botón se renderiza dentro de un `v-if="cards.length"` / `v-if="hasBudgets"`, y a la vez recibe `:disabled="!cards.length"`. Como nunca está visible con la condición falsa, el disabled es innecesario. No es un bug, sólo redundancia.
- **Severidad**: Bajo.
- **Acción recomendada**: limpiar el disabled redundante o mover el botón fuera del `v-if` (más consistente con las otras 4 vistas que dejan el botón visible en estado disabled).

### B3 — Sin toast/feedback de "Descarga iniciada"

- **Archivo**: `frontend/src/components/finance/ExcelExportButton.vue:24-30`.
- **Detalle**: el componente toastea sólo en error. En éxito, el usuario sólo ve el spinner y luego el browser descarga. Es un comportamiento estándar y no es bug, pero algunos UX prefieren feedback explícito.
- **Severidad**: Bajo.
- **Acción recomendada**: opcional — emitir un toast de éxito tras `await download(...)` resuelto. No bloquea merge.

## Sin hallazgos en

- **Aislamiento de scope `user_id`** en los 3 endpoints xlsx que aceptan `account_id`: byCategory, cashflowMonthly, monthComparison — todos usan `exists:accounts,id,user_id,'.$userId`. Verificación cubierta por test `test_user_a_cannot_use_account_id_from_user_b`.
- **Middleware**: los 6 endpoints viven dentro del grupo `auth:sanctum + verified`. Verificación con tests `test_unauthenticated_returns_401` y `test_unverified_email_returns_403`.
- **Sanitización de filename / inyección de headers**: el regex `[^A-Za-z0-9_.\-]` en `ReportExporter::sanitizeFilename` neutraliza CR/LF, comillas, backslash y path traversal. El filename va entre dobles comillas en el header.
- **PhpSpreadsheet 5.8.0 CVEs**: el uso es solo escritura (`Writer\Xlsx::save('php://output')`). El `loadFromBinary` sólo se usa en tests y no se expone vía HTTP. No hay CVE conocido aplicable.
- **`StreamedResponse` y `streamedContent()` en tests**: API correcta para Laravel 12; el callback se ejecuta dentro de `getContent()`, sin race.
- **Memoria de PhpSpreadsheet**: el patrón `ob_start; save('php://output'); ob_get_clean` duplica el binario en memoria por un microsegundo. Para los volúmenes de FinCore (xlsx de 6-66 KB) es trivial; documentado como posible mejora futura, no riesgo actual.
- **Categorías archivadas en histórico**: el `leftJoin('categories', ...)` raw no respeta el SoftDelete scope de Eloquent, por lo que las categorías archivadas SÍ se traen con su nombre histórico — comportamiento esperado por la spec. El test `test_archived_category_keeps_historical_name_in_by_category` lo verifica y pasa.

## Tareas de corrección sugeridas (en orden de dependencia)

Ninguna bloquea el merge. Listadas como mejoras incrementales que pueden hacerse en este mismo PR si se quiere o diferirse:

1. **M1**: `try/finally` en `triggerDownload` para garantizar `URL.revokeObjectURL`.
2. **M2**: incluir `text/html` en la detección de respuestas de error en `useExcelDownload`.
3. **B1**: `aria-label` + `aria-hidden` en el ícono del `ExcelExportButton`.
4. **B2**: limpiar `:disabled` redundante en `ReportsCreditCardsView` y `ReportsBudgetsView`.
5. **B3**: opcional toast de éxito.
6. **M3 / M4**: agregar al backlog general de optimización de Report Services — NO atender en este sprint (cambios fuera de alcance).

## Limitaciones y validaciones no ejecutadas

- **Smoke en navegador real (Chrome/Firefox)**: no se ejecutó UI smoke en navegador; el smoke fue por curl. La UI está cubierta por vitest (5 tests del componente + 9 del composable). El binario abre OK en LibreOffice (validado al smoke previo del sprint anterior por convención del repo); en esta revisión no se reabrió.
- **Tamaño máximo del archivo bajo carga real**: estimado en ~660 KB para 1000 filas; no probado empíricamente. FinCore no llega a esos volúmenes hoy.
- **No se revisó vulnerabilidad de XLSX en clientes**: los xlsx generados no contienen fórmulas ni macros; el formato es estático. No hay vector razonable de XLSX-driven attack.
- **No se ejecutó `composer audit`**: cubierto al instalar PhpSpreadsheet; reportó "15 security vulnerability advisories affecting 10 packages" — todos preexistentes, no introducidos por el sprint.
- **No se hizo perf bench**: para los volúmenes de FinCore no es relevante.

## Veredicto

**Listo para merge** tras atender M1 + M2 (rápidos, ~5 minutos cada uno). M3/M4 son nota informativa de tech debt preexistente que no introduce este sprint. El resto son mejoras menores.
