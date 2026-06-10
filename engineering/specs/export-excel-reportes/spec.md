# Export a Excel (.xlsx) de los 6 reportes

## Resumen

Cada uno de los 6 reportes existentes en `/reports/*` gana un botón "Exportar a Excel" en la barra de filtros. El botón descarga un archivo `.xlsx` que refleja exactamente la data del reporte con el rango y filtros activos al momento del click. El archivo se genera en el backend con PhpSpreadsheet, una hoja por reporte, con headers en bold, formato moneda MXN y fila de totales donde aplique.

## Problema a resolver

Hoy los 6 reportes son sólo visuales: el usuario puede ver agregados en pantalla pero no puede llevarse la data fuera de la app para archivarla, compararla con su Excel personal histórico o compartirla con su contador. El drill-down (sprint por-cuenta-drilldown) sirve para inspeccionar detrás de un bucket, pero no resuelve "quiero el reporte completo en un archivo".

## Objetivo

Permitir que cualquiera de los 6 reportes se descargue como `.xlsx` con la misma data que está viendo en pantalla, con un formato lo bastante limpio como para imprimir o compartir sin re-editar en Excel.

## Alcance

- 6 reportes existentes:
  - `/reports/by-category` — Por categoría
  - `/reports/cashflow` — Cashflow mensual
  - `/reports/month-comparison` — Comparativo mes vs mes
  - `/reports/credit-cards` — Tarjetas de crédito
  - `/reports/budgets` — Presupuestos
  - `/reports/by-account` — Por cuenta
- Endpoint nuevo por reporte (6 endpoints), namespace `/api/finance/reports/*/export.xlsx` o equivalente.
- Botón "Exportar a Excel" en cada vista, junto a los filtros existentes.
- Generación 100% en backend con PhpSpreadsheet (dependencia composer nueva).
- Reusar `Domain/Finance/Reports/*` sin duplicar lógica de agregación.

## Fuera de alcance

- Export de movimientos crudos en `/entries` (se evaluará en un sprint aparte).
- Export a PDF (descartado por baja prioridad; se podría agregar después).
- Export a CSV (innecesario si ya hay xlsx; Excel y Google Sheets abren xlsx nativamente).
- Programación de exports automáticos (cron, email mensual).
- Plantillas personalizables o branding configurable.
- Drill-down de entries dentro del xlsx (el xlsx muestra agregados, no movimientos crudos).
- Internacionalización del archivo: se usa MXN y español de México hardcodeado.

## Reglas de negocio

- El export respeta el scope del usuario autenticado (`user_id` de Sanctum).
- El export respeta el filtro `account_id`/`category_id`/`kind`/`from`/`to` activo en la vista — usa los mismos query params que el endpoint de lectura del reporte.
- El export NO incluye entries cancelados (SoftDelete global de `JournalEntry`).
- El export NO incluye cuentas archivadas en las tablas que listan cuentas activas (Por cuenta, Tarjetas), pero sí conserva nombres históricos de categorías archivadas (igual que el reporte en pantalla, vía `withTrashed` en el JOIN del Report Service).
- Los buckets de "Sin categorizar" se mantienen como una fila con ese label en los reportes que lo tengan (Por categoría, Comparativo).
- Filosofía libreta libre: los exports son fotos del momento, no auditables. No se persiste registro de exports.

## Requisitos funcionales

- RF-001: existe un endpoint `GET /api/finance/reports/by-category/export.xlsx` que devuelve un archivo `.xlsx` con la misma data que `GET /api/finance/reports/by-category` para los mismos query params (`kind`, `account_id`, `from`, `to`).
- RF-002: existe un endpoint análogo para los otros 5 reportes con los query params que cada uno usa hoy.
- RF-003: el archivo `.xlsx` se devuelve con `Content-Type: application/vnd.openxmlformats-officedocument.spreadsheetml.sheet` y `Content-Disposition: attachment; filename="fincore-<reporte>-<rango>.xlsx"`.
- RF-004: cada vista de reporte muestra un botón "Exportar a Excel" visible junto a los filtros, deshabilitado mientras está cargando data o si el reporte está vacío (sin filas que exportar).
- RF-005: el click en el botón dispara la descarga del archivo con los filtros activos al momento del click (no captura un estado obsoleto).
- RF-006: cada archivo tiene una hoja única (no múltiples worksheets). El nombre de la hoja coincide con el nombre del reporte (ej. "Por categoría", máximo 31 caracteres por límite de Excel).
- RF-007: cada archivo arranca con un encabezado de 2 filas antes de la tabla:
  - Fila 1: nombre del reporte en bold + tamaño 14.
  - Fila 2: rango de fechas + fecha de generación en cursiva + tamaño 10.
- RF-008: la tabla incluye una fila de headers en bold con fondo gris claro, columnas auto-ajustadas a contenido.
- RF-009: columnas monetarias usan formato `"$"#,##0.00` y columnas porcentuales `0.0%`.
- RF-010: cada reporte donde tenga sentido (todos menos Tarjetas de crédito) incluye una fila final "TOTAL" en bold con SUMA de las columnas numéricas relevantes.
- RF-011: estructura por reporte:
  - **Por categoría**: columnas `Categoría | Movimientos | Total`. Footer: total general.
  - **Cashflow mensual**: columnas `Año-Mes | Ingresos | Gastos | Neto`. Footer: totales de columnas. Sólo los meses presentes en el rango filtrado (la serie densa la rellena el frontend; el export usa la serie cruda del backend).
  - **Comparativo mes vs mes**: columnas `Categoría | Mes anterior | Mes actual | Δ | Δ %`. Footer: totales de las 3 columnas numéricas; Δ % calculado vs total anterior.
  - **Tarjetas de crédito**: columnas `Tarjeta | Deuda | Límite | Disponible | Utilización % | Día corte | Día pago | Pago mín. estimado`. Sin footer de totales (cada fila es una tarjeta independiente).
  - **Presupuestos**: columnas `Categoría | Límite mensual | Gastado | Restante | Consumido %`. Footer: totales de las 3 columnas monetarias; % consumido calculado vs total limit.
  - **Por cuenta**: columnas `Cuenta | Tipo | Ingresos | Gastos | Neto`. Footer: totales de las 3 columnas monetarias.
- RF-012: el nombre del archivo sigue el patrón `fincore-<reporte-kebab>-<rango>.xlsx`:
  - rango por fechas: `YYYY-MM-DD_YYYY-MM-DD` (Por categoría, Cashflow, Por cuenta).
  - rango por mes: `YYYY-MM` (Comparativo mes vs mes — mes actual).
  - sin rango: solo `fincore-<reporte>.xlsx` (Tarjetas, Presupuestos — son fotos puntuales).

## Casos principales

- Usuario en `/reports/by-category` con `kind=expense`, mes en curso seleccionado → click "Exportar a Excel" → descarga `fincore-por-categoria-2026-06-01_2026-06-30.xlsx` con todas sus categorías de gasto del mes y total.
- Usuario en `/reports/cashflow` con rango Jan-Jun 2026 → descarga `fincore-cashflow-mensual-2026-01-01_2026-06-30.xlsx` con 6 filas (meses con actividad) más totales.
- Usuario en `/reports/credit-cards` sin filtros → descarga `fincore-tarjetas-credito.xlsx` con una fila por tarjeta activa.
- Usuario en `/reports/by-account` filtrando por mes actual → descarga `fincore-por-cuenta-2026-06-01_2026-06-30.xlsx` con todas sus cuentas no archivadas.

## Casos borde

- **Reporte vacío** (sin movimientos en el rango): el botón está deshabilitado en frontend; si se llama directo al endpoint, devuelve un xlsx con headers + 0 filas + un footer "TOTAL: $0.00". No 404 ni 422.
- **Rango grande** (ej. 5 años): el reporte agregado sigue siendo chico (decenas de filas, no miles). No hay riesgo de timeout ni memoria. Si la ejecución de PhpSpreadsheet excede 10 segundos, queda como riesgo a vigilar — no se implementa cache.
- **Categorías archivadas que aparecen en el rango**: se exportan con su nombre histórico (igual que el reporte en pantalla), sin marca visual de "archivada" en el xlsx.
- **Bucket "Sin categorizar"**: aparece como una fila normal con esa etiqueta en Por categoría y Comparativo.
- **Tarjetas sin `closing_day` o `minimum_payment_pct` configurado**: las columnas correspondientes salen vacías (`""`), no como 0.
- **Año-Mes en Comparativo donde una categoría sólo tuvo actividad en uno de los dos meses**: la fila aparece con `0` en el mes sin actividad; `Δ %` queda vacío si previous=0.
- **Tarjeta de crédito con `credit_limit=0`** (caso degenerado): utilización % sale como 0% en el xlsx, no NaN.
- **Reportes que no aceptan filtros** (Tarjetas, Presupuestos): el botón siempre habilitado si hay al menos una fila.
- **Usuario sin verificar email**: el middleware `verified` bloquea con 403 igual que el endpoint de lectura. El frontend no debería mostrar la opción en ese estado (no es navegable).
- **Filtros inválidos** (ej. `from > to`, `kind` desconocido): se aplican las mismas validaciones del endpoint de lectura. Devuelve 422.
- **Caracteres especiales en nombres de categoría/cuenta** (emojis, acentos): PhpSpreadsheet maneja UTF-8 nativo; debe quedar limpio en el xlsx.
- **Nombre de hoja > 31 caracteres**: imposible por diseño (los nombres de reporte son cortos), pero el código debe truncar por seguridad para evitar excepción de PhpSpreadsheet.

## Criterios de aceptacion

- Existe el endpoint para cada uno de los 6 reportes con la firma definida en RF-001/RF-002.
- Un test HTTP por endpoint verifica:
  - `Content-Type` == `application/vnd.openxmlformats-officedocument.spreadsheetml.sheet`.
  - `Content-Disposition` contiene `attachment` y `filename=` con el patrón esperado.
  - El cuerpo de la respuesta es un binario xlsx válido (PK header — primeros bytes `PK\x03\x04`).
  - El workbook tiene exactamente 1 hoja con el nombre esperado.
  - La hoja contiene los headers esperados en la fila 3 (después del encabezado de 2 filas).
  - Al cargar el xlsx con PhpSpreadsheet en el test, los valores numéricos coinciden con la respuesta del endpoint JSON del mismo reporte (con los mismos params).
- Un test verifica el caso "reporte vacío": devuelve xlsx con 0 filas de data + footer "TOTAL: $0.00", no 404.
- Un test verifica scope: el user A no puede descargar datos del user B (los entries del otro no aparecen en su xlsx).
- En el frontend, un test del componente del botón verifica:
  - Está deshabilitado mientras carga.
  - Hace `GET` al endpoint correcto con los filtros activos.
  - Dispara la descarga con el filename del header `Content-Disposition`.
- Smoke manual en navegador: descarga cada uno de los 6 reportes, abre el archivo en LibreOffice o Excel, verifica que la data se vea como en pantalla y los totales cuadren.
- Suite verde: backend + frontend sin regresiones; tests nuevos suben el conteo total esperado.

## Criterios medibles de exito

- Tiempo de respuesta del endpoint < 2s para rangos típicos (mes en curso, cientos de entries).
- Tamaño del archivo < 50 KB para reportes típicos.
- Los 6 endpoints cubiertos por al menos 1 test HTTP que valide content-type + nombre de archivo + contenido.
- Cobertura de tests >= 90% en la nueva clase `ReportExporter` o equivalente que centraliza el formateo común (headers, footer, estilos).
- Dependencia `phpoffice/phpspreadsheet` agregada a `composer.json` sin warnings ni conflicts.

## Riesgos

- **PhpSpreadsheet pesa ~6 MB en vendor y tiene una superficie de API grande**. Mitigación: centralizar el uso en una clase `ReportExporter` con métodos `addHeader`, `addTable`, `addFooter`, `download` para no esparcir su API por todo el código.
- **Memoria al exportar rangos grandes**: PhpSpreadsheet carga todo en memoria. Para los volúmenes típicos de FinCore (cientos de filas en el peor caso), no debería ser un problema. Vigilar si crece a miles.
- **Cache opcode/route cuando se agrega dependencia**: si el deploy usa `config:cache`/`route:cache`, recordar limpiarlos tras agregar el package. Documentado en `docs/deploy.md` ya, no requiere cambio.
- **Sanctum + descarga binaria**: el frontend usa `axios` con bearer token. La descarga vía link directo `<a href="/api/...">` no incluye el header `Authorization`. Mitigación: hacer el GET por axios con `responseType: 'blob'` y crear el link de descarga con `URL.createObjectURL` (patrón estándar).
- **Filename con caracteres especiales del rango**: improbable, las fechas son ASCII. Pero si en el futuro el filename incluyera nombres de cuenta/categoría con acentos, hay que escapar vía RFC 5987 (`filename*=UTF-8''...`).
- **Test de contenido binario en CI**: PHP en CI debe tener la extensión `zip` habilitada para que PhpSpreadsheet lea xlsx en assertions. En `serversideup/php:8.4-fpm-nginx-alpine` ya viene; en local también. Verificar antes de cerrar.
- **Locale del formato moneda**: PhpSpreadsheet aplica el formato `"$"#,##0.00` correctamente independiente del locale del sistema; el `$` se interpreta como texto literal en el formato de Excel. Sin riesgo de cambiar a € o similar.

## Supuestos

- El usuario quiere los exports con moneda MXN (`$`) hardcoded; no hay multi-currency en FinCore hoy.
- El usuario quiere los headers y labels en español (mismas etiquetas que la UI).
- El botón "Exportar a Excel" se posiciona en cada vista junto a los controles de filtro existentes (no en el subnav común). Cada vista decide su layout exacto.
- Los reportes vacíos no son un error: el usuario puede querer descargar un xlsx en blanco para confirmar que no tiene actividad en un período.
- La descarga es sincrónica (responde con el binario directamente). No se usa job + email para deferir, porque los volúmenes son chicos.
- No se loguea/audita la generación de exports: la libreta es personal y los exports no afectan el modelo de datos.
- El composer install corre dentro del Sail image en dev y dentro de la build multi-stage del Dockerfile en prod. No requiere cambios de infraestructura.
- Los 5 reportes que ya existen no cambian de comportamiento ni de contrato JSON.
- Si el usuario actualiza filtros mientras se está descargando, la descarga en vuelo refleja los filtros del click, no los nuevos.

## Impacto esperado

- 6 endpoints nuevos en `routes/api.php`.
- 1 clase nueva `App\Domain\Finance\Reports\Export\ReportExporter` (o equivalente) que centraliza la construcción de hojas + formato.
- 1 controller method por endpoint o 1 controller dedicado `ReportExportController` (decisión de plan).
- 6 vistas Vue modificadas para agregar el botón "Exportar a Excel".
- 1 composable nuevo en frontend `useExcelDownload` (o equivalente) para encapsular el patrón axios+blob+anchor.
- 1 dependencia composer nueva: `phpoffice/phpspreadsheet`.
- `composer.json` y `composer.lock` actualizados.
- `CLAUDE.md` actualizado con los 6 endpoints en la tabla de rutas.
- `docs/api/README.md` actualizado si lista endpoints por reporte (verificar al implementar).
- Sin migraciones, sin cambios en schema, sin cambios en seeders.
- Sin cambios en el contrato de los endpoints existentes.
