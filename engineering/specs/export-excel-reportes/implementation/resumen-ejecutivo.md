# Resumen ejecutivo — Export a Excel de los 6 reportes

## Qué se implementó

Cada uno de los 6 reportes existentes en `/reports/*` gana un botón "Exportar a Excel" que descarga el reporte como archivo `.xlsx` listo para abrir en Excel, LibreOffice o Google Sheets. La data del archivo es exactamente la que está en pantalla, con los filtros activos al momento del click.

Estructura común de cada archivo:

- Una hoja por archivo, nombre del reporte como título.
- Encabezado con nombre + rango + fecha de generación.
- Tabla con headers en bold, fondo gris claro, formato moneda MXN y porcentajes con `0.0%`.
- Fila final TOTAL en bold (los 5 reportes que aplica; Tarjetas no lleva total).

Naming consistente: `fincore-<reporte>-<rango>.xlsx`.

## Impacto esperado

- El usuario puede llevar sus reportes a Excel/Sheets para análisis personal, comparación histórica o compartir con su contador, sin tener que copiar a mano.
- Los 6 reportes quedan cubiertos: Por categoría, Cashflow mensual, Comparativo mes vs mes, Tarjetas de crédito, Presupuestos, Por cuenta.
- Cambio aditivo: cero impacto en flujos existentes, cero migraciones.

## Riesgos o pendientes relevantes

- 1 dependencia composer nueva: `phpoffice/phpspreadsheet ^5.8` (vendor ~6.7 MB). Aceptable.
- 2 hallazgos preexistentes (N+1 en CreditCardsReport y BudgetsReport) documentados en el quality review; no se atendieron en este sprint porque están fuera de alcance.
- Mejoras menores opcionales identificadas en el review (aria-label, disabled redundante, toast on success); pueden hacerse en este mismo PR o diferirse.

## Estado de pruebas

- **Backend**: 360/360 (eran 327; +33 nuevos).
- **Frontend**: 72/72 (eran 58; +14 nuevos).
- **Pint**: aplicado a los archivos nuevos.
- **Smoke**: 6/6 endpoints validados con curl + `file` reportando `Microsoft Excel 2007+`.
- **Quality review**: 0 bloqueantes, 0 altos, 2 medios atendidos durante el sprint (M1 leak fix + M2 detect HTML errors), 2 medios preexistentes documentados, 3 bajos opcionales.

Listo para merge.
