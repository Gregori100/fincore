# Plan técnico — Export a Excel de los 6 reportes

## Enfoque tecnico

Pieza única de generación de xlsx en backend, sin tocar los Report Services existentes ni los endpoints de lectura JSON. Patrón en 3 capas:

1. **Capa de dependencia**: agregar `phpoffice/phpspreadsheet` a `composer.json` como dependencia productiva. No usar `maatwebsite/excel` (wrapper opinionated, suma magia innecesaria para este uso).
2. **Capa de formateo común**: una clase única `App\Domain\Finance\Reports\Export\ReportExporter` con métodos finos:
   - `sheetTitle(string $title): self` — setea el nombre de la hoja truncando a 31 chars.
   - `header(string $reportName, string $rangeLabel): self` — escribe filas 1-2 (nombre en bold size=14, rango + "Generado el ..." en cursiva size=10).
   - `table(array $headers, array $rows, array $columnFormats): self` — desde la fila 4: headers en bold con fondo gris claro, filas con `$columnFormats` por columna (`money` → `"$"#,##0.00`, `pct` → `0.0%`, `int` → `0`, `text` → general). Auto-ancho por columna al final.
   - `footer(array $cells): self` — última fila en bold con `SUMA` calculada o valor literal por celda. Si la tabla está vacía, escribe sólo `TOTAL: $0.00` y termina.
   - `download(string $filename): \Symfony\Component\HttpFoundation\StreamedResponse` — emite el binario con `Content-Type` y `Content-Disposition: attachment` correctos.
   - Internamente usa `PhpOffice\PhpSpreadsheet\Spreadsheet` + `Writer\Xlsx`. Centralizar aquí los detalles de estilo evita esparcir su API por 6 lugares.
3. **Capa de orquestación**: un controller nuevo dedicado `App\Http\Controllers\ReportExportController` con 6 acciones (`byCategory`, `cashflowMonthly`, `monthComparison`, `creditCards`, `budgets`, `byAccount`). Cada acción:
   - Valida los query params (idénticos al endpoint de lectura).
   - Invoca el Report Service correspondiente y obtiene el array agregado.
   - Construye un `ReportExporter`, le pasa los datos formateados, devuelve `download(filename)`.

Controller dedicado en vez de añadir 6 métodos a `FinanceController` para mantener el área de export aislada (es un cambio aditivo: si en el futuro hay que sacar exports, se quita un archivo).

Frontend:
- Un **composable** `useExcelDownload` en `frontend/src/composables/` encapsula el patrón: GET con axios `responseType: 'blob'`, leer `filename` del header `Content-Disposition`, crear `URL.createObjectURL`, click programático en `<a>` invisible, revoke. Devuelve `{ download, loading, error }`.
- Un **componente** `ExcelExportButton.vue` en `frontend/src/components/finance/` con props `{ url, params, disabled, label }` que consume el composable. Renderiza un `BaseButton` secundario con icono. Emite `done`/`error` para que la vista pueda toastear.
- Cada vista `ReportsXxxView.vue` instancia el componente junto a sus filtros, pasándole su URL y los params reactivos actuales.

## Requisitos funcionales cubiertos

- **RF-001 a RF-002**: 6 endpoints `GET /api/finance/reports/<reporte>/export.xlsx` en `routes/api.php` mapeados al nuevo `ReportExportController`. Cada uno valida los mismos query params que el endpoint de lectura del mismo reporte.
- **RF-003**: `ReportExporter::download($filename)` setea ambos headers exactos.
- **RF-004**: `ExcelExportButton.vue` recibe `disabled` desde la vista padre (la vista calcula `loading || empty`).
- **RF-005**: el composable lee `props.params` en el momento del click, no en mount; los filtros activos se reflejan correctamente.
- **RF-006**: `ReportExporter::sheetTitle()` trunca a 31 chars; las acciones del controller pasan los títulos cortos por diseño.
- **RF-007**: `ReportExporter::header($name, $rangeLabel)` escribe filas 1-2 con formato y tamaño definidos.
- **RF-008**: `ReportExporter::table()` aplica bold + fondo gris claro (`FFEFEFEF`) a la primera fila de la tabla y autosize a las columnas tras escribir todas las filas.
- **RF-009**: el array `$columnFormats` del método `table()` mapea índice de columna → `'money' | 'pct' | 'int' | 'text'`. El método aplica formato cell por cell.
- **RF-010**: `ReportExporter::footer()` recibe el array de celdas a escribir; las 5 acciones que llevan total lo pasan, la de Tarjetas pasa array vacío (no escribe footer).
- **RF-011**: cada acción del controller arma su array `headers/rows/columnFormats` con la estructura exacta del RF-011 (verificable celda a celda en tests).
- **RF-012**: cada acción calcula su `filename` con el patrón correspondiente al tipo de rango (fechas, mes, sin rango).

## Archivos o modulos probablemente afectados

Backend (nuevos):

- `backend/app/Domain/Finance/Reports/Export/ReportExporter.php` — clase helper.
- `backend/app/Http/Controllers/ReportExportController.php` — controller con 6 actions.
- `backend/tests/Feature/Reports/Export/ReportExporterTest.php` — unit-ish test de la clase helper (parse del xlsx generado).
- `backend/tests/Feature/Http/ReportExportTest.php` — tests HTTP de los 6 endpoints.

Backend (modificados):

- `backend/composer.json` — agregar `"phpoffice/phpspreadsheet": "^4.0"` en `require`.
- `backend/composer.lock` — actualizado por `composer require`.
- `backend/routes/api.php` — 6 rutas nuevas dentro del grupo `auth:sanctum + verified`.

Frontend (nuevos):

- `frontend/src/composables/useExcelDownload.js` — composable.
- `frontend/src/components/finance/ExcelExportButton.vue` — botón reutilizable.
- `frontend/tests/composables/useExcelDownload.spec.js` — test del composable.
- `frontend/tests/components/ExcelExportButton.spec.js` — test del componente.

Frontend (modificados):

- `frontend/src/api/finance.js` — agregar URL builders o constantes para los 6 endpoints de export (decisión: pasar URLs directas como props desde la vista, el composable usa `client.get(url, { params, responseType: 'blob' })`; no es necesario un wrapper si el patrón es uno solo).
- `frontend/src/views/app/ReportsByCategoryView.vue`
- `frontend/src/views/app/ReportsCashflowView.vue`
- `frontend/src/views/app/ReportsMonthComparisonView.vue`
- `frontend/src/views/app/ReportsCreditCardsView.vue`
- `frontend/src/views/app/ReportsBudgetsView.vue`
- `frontend/src/views/app/ReportsByAccountView.vue`

Documentación:

- `CLAUDE.md` — 6 filas nuevas en la tabla de rutas API.
- `engineering/specs/export-excel-reportes/implementation/` — al implementar, carpeta de implementación (no la creamos aquí).

## Entidades y estados afectados

No se introducen entidades ni se modifica el dominio. Los Report Services existentes son invocados intactos. El export es 100% lectura.

Invariantes a respetar:

- Scope por `user_id`: cada acción debe llamar al Report Service con el `userId` autenticado vía Sanctum. No exponer datos cruzados.
- Soft delete: el global scope de `JournalEntry` y `Account` ya filtra cancelados/archivados en las queries de los Report Services; nada que hacer en la capa export.
- Categorías archivadas en agregados históricos: `CategoryBreakdownReport` ya hace JOIN con `withTrashed`; el export hereda eso. No agregar lógica de "marcar archivada".

## Compatibilidad con datos y procesos existentes

- Sin migraciones, sin cambios de schema.
- Los endpoints de lectura JSON (`/api/finance/reports/*`) no se tocan; sus tests existentes siguen verdes.
- El frontend no cambia el comportamiento de los reportes existentes; sólo agrega un botón en la barra de filtros.
- `composer.lock` cambia: el deploy a producción debe correr `composer install --no-dev` igual que hoy.
- Si el Docker image de prod tiene `composer install` con `--classmap-authoritative` o el optimizador de autoload, sigue funcionando (es lo que hace el `Dockerfile` actual).

## Cambios de datos

No aplica. Lectura pura.

## Cambios de API

Aditivos. 6 endpoints nuevos:

- `GET /api/finance/reports/by-category/export.xlsx?kind=...&account_id=...&from=...&to=...`
- `GET /api/finance/reports/cashflow-monthly/export.xlsx?from=...&to=...&account_id=...`
- `GET /api/finance/reports/month-comparison/export.xlsx?kind=...&account_id=...&month=YYYY-MM`
- `GET /api/finance/reports/credit-cards/export.xlsx`
- `GET /api/finance/reports/budgets/export.xlsx`
- `GET /api/finance/reports/by-account/export.xlsx?from=...&to=...`

Todos bajo middleware `auth:sanctum + verified`. Mismo throttle por defecto del grupo (sin `throttle:6,1` específico — no es endpoint de auth).

Validación de query params: idéntica a la del endpoint de lectura. Reusar las mismas reglas FormRequest si existen o copiar inline si están inline en `FinanceController` (verificar al implementar; el patrón actual en `FinanceController` es validar inline con `$request->validate()`).

## Cambios de integraciones

- Nueva dependencia: `phpoffice/phpspreadsheet ^4.0` en `composer.json`.
- Sin nuevas integraciones externas (no S3, no Resend, no Stripe).

## Cambios de UI

- 6 vistas modifican su layout para incluir `ExcelExportButton` junto a los filtros. Posicionamiento: a la derecha de los selects/date pickers, alineado con el botón principal de "Actualizar" o equivalente que tenga la vista.
- El composable maneja loading: durante el `await client.get(...)`, el botón muestra spinner y queda disabled.
- Toast de éxito al iniciar la descarga (texto: "Exportando..."). Toast de error si el GET devuelve 4xx/5xx (consume el mensaje del backend si viene en JSON; nota: si el backend devuelve error, Content-Type será JSON, no xlsx — el composable debe detectar esto leyendo el header antes de tratar la respuesta como blob).

## Cambios de permisos

- Reusa el middleware `auth:sanctum + verified` ya aplicado al grupo `/api/finance/*`. Sin cambios.

## Riesgos tecnicos

- **Memoria al exportar rangos grandes**: PhpSpreadsheet carga todo en memoria; ~10MB por cada 10k filas. Para FinCore (cientos de filas en el peor caso) es trivial. Vigilar si el patrón cambia.
- **Cache de config/routes**: agregar dependencia y rutas requiere `php artisan config:clear && php artisan route:clear` en dev (Sail hot-reload los toma). En prod el Dockerfile corre `config:cache && route:cache` en build, automático.
- **Error en streaming**: si la generación falla a media respuesta (ej. excepción dentro del Writer), el navegador descargará un archivo corrupto. Mitigación: PhpSpreadsheet escribe a memoria primero, luego se emite el binario completo. Usar `Writer\Xlsx::save('php://output')` con `ob_start`/`ob_get_clean` para tener el binario en variable antes de mandar headers.
- **Filename con espacios o acentos**: por diseño sólo usamos ASCII (`fincore-por-categoria-...`). Sin riesgo.
- **Frontend axios + blob**: al recibir un blob con error JSON, el cliente no sabe parsearlo sin extra trabajo. Solución: cuando `response.headers['content-type'].includes('application/json')` se trata como error y se intenta `await response.data.text()` + `JSON.parse`.
- **`Content-Disposition` con `filename*=UTF-8''...`**: si Laravel agrega encoding RFC 5987 automáticamente, el frontend debe poder leerlo. Usar regex tolerante (`/filename\*?=(?:UTF-8'')?"?([^";]+)"?/`).
- **Test del binario en CI**: requiere extensión `zip` y `xml` en PHP. Sail PHP 8.4 las tiene; el Dockerfile de prod (`serversideup/php:8.4`) también. Verificar al primer `php artisan test`.
- **Tamaño del vendor**: ~6 MB adicionales en `vendor/`. Aceptable. En el Docker image multi-stage el `composer install --no-dev` igual filtra dev deps.
- **Tarjetas de crédito con métricas null** (`closing_day`, `minimum_payment_pct`): el formateo del Excel debe escribir `''` (string vacío) en celdas null, no `0`. Caso clavado en RF, hay que traducirlo en el array de filas que pasa el controller.
- **Throttle**: si el botón se spamea, el endpoint no tiene throttle dedicado. Riesgo mínimo (user autenticado, sólo carga su propia data). No agregar throttle.

## Estrategia de pruebas

- **Tests unitarios** del `ReportExporter`: instanciar, llenar con datos conocidos, llamar `download()`, leer el `StreamedResponse`, parsear con `PhpOffice\PhpSpreadsheet\IOFactory::load()` desde tmpfile, validar celdas y formato.
- **Tests HTTP** del controller (un test por endpoint, 6 mínimo + variantes):
  - Status 200.
  - `Content-Type` header.
  - `Content-Disposition` con filename esperado por regex.
  - Cuerpo arranca con `PK\x03\x04` (firma ZIP).
  - Parsear con IOFactory y comparar valores de celdas vs JSON del endpoint de lectura.
- **Tests de scope**: user B no ve datos de user A.
- **Test de reporte vacío**: 200 + footer "TOTAL: $0.00" sin filas de data.
- **Test de validación**: query params inválidos → 422.
- **Test del composable frontend** (Vitest): mock `axios`, simular respuesta blob, verificar que `URL.createObjectURL` se llama y el anchor se clickea.
- **Test del componente `ExcelExportButton.vue`**: render con `disabled=true` queda inactive; click invoca composable.
- **Smoke manual** en navegador: 6 reportes × abrir xlsx en LibreOffice y verificar.

Reutilizar helpers existentes en `tests/TestCase.php` (`createUserWithBolsa()`).

## Estrategia de rollback

- Cambio aditivo puro. Rollback = revertir el commit del controller + rutas + composer + frontend.
- Si en prod surge un problema (ej. excepción en PhpSpreadsheet con cierta data), el frontend simplemente no descarga; los reportes en pantalla siguen funcionando. No hay corrupción de datos posible.
- Si la dependencia `phpoffice/phpspreadsheet` necesita removerse, `composer remove phpoffice/phpspreadsheet` y revertir.
- Sin migraciones, no hay rollback de schema.

## Orden sugerido de implementacion

1. Backend base: agregar dependencia, crear `ReportExporter`, escribir su test unit con un dataset sintético (validar que un xlsx generado con datos conocidos contiene esos valores en las celdas correctas).
2. Primer endpoint completo: `byCategory`. Crear `ReportExportController` con la primera acción, agregar ruta, escribir test HTTP. Esto valida el patrón end-to-end sin esparcir el riesgo a 6 endpoints.
3. Los otros 5 endpoints en paralelo (cada uno repite el patrón, son tareas independientes).
4. Frontend base: composable `useExcelDownload` + test.
5. Componente `ExcelExportButton.vue` + test.
6. Integrar en las 6 vistas (paralelizable, una por una).
7. CLAUDE.md y docs (al final).
8. Quality review final.

## Casos borde que condicionan la solucion

- Reporte vacío (cubierto en RF y test).
- Categorías archivadas (cubierto, hereda del Report Service).
- Sin categorizar (cubierto, label en RF-011).
- Tarjetas sin metadata configurada (cubierto, celdas vacías).
- Filtros inválidos → 422 (cubierto por validación reusada del endpoint de lectura).
- Email no verificado → 403 por middleware (sin cambio).
- Caracteres especiales en nombres (UTF-8 nativo).
- Mes-año en Comparativo con categoría sólo en uno de los dos meses.
- Filename con rango como `2026-06-01_2026-06-30` (ASCII, sin escape).
- Race entre cambio de filtros y click: el composable captura `props.params` al momento del call; los filtros nuevos no afectan la descarga en vuelo.

## Preguntas o supuestos que siguen afectando la implementacion

- **Versión de `phpoffice/phpspreadsheet`**: se asume `^4.0` (última estable a 2026-06-10). Si en `composer require` la resolución apunta a una mayor incompatible con PHP 8.2, ajustar al primer error.
- **`FormRequest` vs validación inline**: hoy `FinanceController` valida inline; el controller nuevo seguirá el mismo patrón. Si en un sprint futuro se mueve a FormRequests, el export se mueve junto.
- **Posicionamiento exacto del botón en cada vista**: cada vista tiene un layout ligeramente distinto. Se decide en la tarea de cada vista (no requiere decisión central de UX).
- **Tamaño de columna automático**: PhpSpreadsheet calcula auto-width con heurística (no perfecta). Si una columna queda apretada, asumir que el usuario ajusta a mano en Excel. No hardcodear anchos.
- **Locale del Excel**: el formato `"$"#,##0.00` se escribe en notación universal de Excel; al abrir en una máquina con locale en-US o es-MX se ve igual. Sin riesgo.
