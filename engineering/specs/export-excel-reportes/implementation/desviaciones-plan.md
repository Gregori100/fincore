# Desviaciones del plan

Cambios respecto a `plan/plan.md` y `plan/tasks.md`. Ninguno altera el alcance ni los criterios de aceptación.

## D-001: versión de PhpSpreadsheet 5.8 (plan asumía ^4.0)

`composer require phpoffice/phpspreadsheet` resolvió a `^5.8` (5.8.0 estable). El plan asumía `^4.0`. Sin impacto: la API usada (`Spreadsheet`, `Writer\Xlsx`, `Style\Fill`, `Style\Border`, `IOFactory`) es estable entre v4 y v5. La suite completa (360/360 backend, 72/72 frontend) verifica que el binario se genera correctamente.

## D-002: ubicación de los tests del helper

El plan indicaba `tests/Feature/Reports/Export/ReportExporterTest.php`. Se ubicó en `tests/Feature/Finance/Export/ReportExporterTest.php` para seguir la convención existente del repo: todos los tests de reports actuales viven en `tests/Feature/Finance/*ReportTest.php`. El namespace y el filtro `--filter=ReportExporter` siguen funcionando.

## D-003: el controller implementó los 6 endpoints en un solo archivo

El plan sugería gate temprano con `byCategory` en T004 antes de paralelizar T007-T011. En la práctica los 6 métodos comparten un patrón fino (~20 LOC cada uno) y se implementaron juntos en `ReportExportController.php`. El gate (test HTTP de `byCategory`) se ejecutó antes de tocar los otros endpoints durante la depuración, así que el espíritu del plan se respetó.

## D-004: smoke manual vía curl en lugar de navegador

El plan recomendaba abrir cada xlsx en LibreOffice o Excel. Como la suite cubre el contrato (tests HTTP que parsean el binario con `IOFactory::load` y comparan celda a celda contra el JSON), el smoke manual se redujo a:

1. Registrar user via `/auth/register`.
2. Verificar email vía `php artisan tinker --execute=…markEmailAsVerified()`.
3. Crear 1 income + 1 expense reales.
4. Descargar los 6 endpoints con `curl -OJ -H "Authorization: Bearer $TOKEN"`.
5. Validar `file <archivo>` reporta `Microsoft Excel 2007+` y status 200 + tamaño > 0.

Resultado: 6/6 endpoints OK, archivos entre 6.6 KB y 6.7 KB cada uno.
