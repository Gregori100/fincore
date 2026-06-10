# Test plan — Export Excel de reportes

## Casos borde detectados

- **Reporte vacío** (sin filas que exportar): el endpoint devuelve 200 con xlsx que tiene headers + footer "TOTAL: $0.00". El botón en frontend está disabled.
- **User A intenta descargar del user B**: el scope por `user_id` impide cualquier filtración. Tests dedicados de aislamiento.
- **Email no verificado**: middleware `verified` corta con 403. Test que confirma el comportamiento.
- **Token inválido o ausente**: middleware `auth:sanctum` corta con 401.
- **Filtros inválidos** (`from > to`, `kind` desconocido, `month` mal formateado, `account_id` que no existe o pertenece a otro user): 422.
- **Filtros con valores nulos/vacíos**: omitir el param y el endpoint funciona con default (igual que el endpoint de lectura).
- **Rango grande** (5 años): debe responder en <2s para volúmenes típicos. Test con 500 entries por mes durante 12 meses para validar.
- **Categorías archivadas en el rango**: aparecen con nombre histórico en la columna Categoría.
- **Bucket "Sin categorizar"**: aparece como fila normal con esa etiqueta.
- **Tarjetas sin `closing_day` o `minimum_payment_pct`**: celdas correspondientes vacías (`''`), no `0`.
- **Tarjeta con `credit_limit=0`**: utilización 0%, no NaN o división por cero.
- **Categoría con `monthly_limit=0`** y gasto > 0: `pct_consumed` muestra el valor especial 999% (replicado tal cual del Report Service) — verificar que el xlsx lo escribe como `9990%` (formato 0.0%).
- **Comparativo con categoría sólo en mes anterior**: aparece con `current=0`, `Δ%` vacío.
- **Caracteres especiales** (emoji, acentos, comillas en nombres): UTF-8 nativo, sin corrupción.
- **Nombre de hoja > 31 chars**: el helper trunca; nunca lanza excepción de PhpSpreadsheet.
- **Cabecera `Content-Disposition` con RFC 5987**: el frontend debe parsearlo bien (regex tolerante).
- **Respuesta de error con `responseType: 'blob'`**: el frontend debe detectar Content-Type JSON y mostrar el mensaje de error.
- **Doble click rápido en el botón**: el composable bloquea el segundo click mientras el primero está en vuelo (`loading` flag).
- **Cambio de filtros durante la descarga**: el call en vuelo usa los params del momento del click; cambiar filtros no aborta ni redirige la descarga.
- **Filename con caracteres ASCII puros**: por diseño no hay riesgo; el patrón solo usa kebab-case + fechas + extensión.
- **Cancelación del request**: si el usuario cierra la pestaña a media descarga, el server termina su respuesta normalmente. No hay estado a limpiar.
- **`composer require` falla** (sin internet o repos rotos): cubierto fuera del test plan, en el orden de implementación.

## Pruebas unitarias necesarias

- `ReportExporterTest::test_genera_xlsx_con_header_table_footer` — instancia helper, llama métodos, genera xlsx, parsea con `IOFactory::load`, valida celdas A1, A2, A4 headers, fila final TOTAL.
- `ReportExporterTest::test_trunca_nombre_de_hoja_a_31_chars` — pasa nombre largo, valida que `getActiveSheet()->getTitle()` retorna 31 chars o menos.
- `ReportExporterTest::test_aplica_formato_moneda_a_columnas_marcadas_como_money` — escribe 1 fila, verifica `getStyle('B5')->getNumberFormat()->getFormatCode()` == `"$"#,##0.00`.
- `ReportExporterTest::test_aplica_formato_porcentaje_a_columnas_pct` — verifica formato `0.0%`.
- `ReportExporterTest::test_tabla_vacia_solo_escribe_total_cero` — sin filas, verifica que la fila TOTAL existe con valor 0 formateado en moneda.
- `ReportExporterTest::test_footer_recibe_array_vacio_no_escribe_footer` — caso Tarjetas.

## Pruebas de integracion o API necesarias

Un test por endpoint (6 mínimo), más variantes:

- `ReportExportTest::test_by_category_returns_xlsx_with_correct_headers` — 200, Content-Type, filename regex, primeros bytes `PK`.
- `ReportExportTest::test_by_category_xlsx_matches_json_endpoint` — hace GET al `/export.xlsx` y al `/by-category` con mismos params, parsea xlsx, compara montos celda a celda con el JSON.
- `ReportExportTest::test_cashflow_monthly_returns_xlsx` — análogo.
- `ReportExportTest::test_cashflow_monthly_xlsx_matches_json` — análogo.
- `ReportExportTest::test_month_comparison_returns_xlsx` — análogo, valida filename con patrón `YYYY-MM`.
- `ReportExportTest::test_month_comparison_xlsx_matches_json` — análogo.
- `ReportExportTest::test_credit_cards_returns_xlsx` — análogo, valida filename sin rango (`fincore-tarjetas-credito.xlsx`).
- `ReportExportTest::test_credit_cards_xlsx_no_footer_row` — verifica que después de la última tarjeta no hay fila TOTAL.
- `ReportExportTest::test_credit_cards_empty_metadata_renders_blank_cells` — tarjeta sin `closing_day`, valida celda vacía.
- `ReportExportTest::test_budgets_returns_xlsx` — análogo.
- `ReportExportTest::test_budgets_xlsx_includes_pct_consumed_format` — verifica formato `0.0%`.
- `ReportExportTest::test_by_account_returns_xlsx` — análogo.
- `ReportExportTest::test_by_account_xlsx_includes_archived_accounts_excluded` — validar que cuentas archivadas no aparecen.
- `ReportExportTest::test_empty_report_returns_xlsx_with_zero_total` — caso vacío.
- `ReportExportTest::test_validates_query_params_returns_422` — params malformados.

## Pruebas de UI o flujo necesarias si aplica

- `useExcelDownload.spec.js::test_descarga_blob_con_anchor_y_revoke_url` — mock axios.get devolviendo blob, mock `URL.createObjectURL` y `URL.revokeObjectURL`, spy en `document.createElement('a').click`, verifica orden y revoke al final.
- `useExcelDownload.spec.js::test_lee_filename_del_header_content_disposition` — header tipo `attachment; filename="fincore-test.xlsx"`, verifica que el anchor.download es ese filename.
- `useExcelDownload.spec.js::test_lee_filename_rfc_5987_encoding` — header con `filename*=UTF-8''...`, verifica parseo.
- `useExcelDownload.spec.js::test_loading_flag_true_during_request` — verifica `loading.value` antes/durante/después.
- `useExcelDownload.spec.js::test_segundo_click_durante_loading_se_ignora` — mock setup, dos llamadas rápidas, verifica que axios.get fue llamado 1 vez.
- `useExcelDownload.spec.js::test_error_json_es_parseado_y_lanzado` — mock blob con Content-Type JSON + mensaje de error, verifica que el composable rechaza con ese mensaje.
- `ExcelExportButton.spec.js::test_render_disabled_no_dispara_click` — `disabled=true`, click no llama composable.
- `ExcelExportButton.spec.js::test_render_loading_muestra_spinner` — durante `loading`, el botón muestra el spinner y está disabled.
- `ExcelExportButton.spec.js::test_click_invoca_composable_con_url_y_params` — verifica que el `download(url, params)` se llama con los props pasados.

## Pruebas de permisos y seguridad si aplica

- `ReportExportTest::test_unauthenticated_returns_401` — sin token.
- `ReportExportTest::test_unverified_email_returns_403` — user creado sin `markEmailAsVerified()`.
- `ReportExportTest::test_user_a_cannot_see_user_b_data` — para los 6 endpoints, crear data de B y descargar como A, parsear xlsx, verificar 0 filas de la data del otro user.
- `ReportExportTest::test_account_id_de_otro_user_returns_422_o_filtra_vacio` — depende del Report Service; replicar el comportamiento del endpoint de lectura.

## Pruebas de datos, migracion o compatibilidad si aplica

- No hay migraciones.
- `ReportExportTest::test_categorias_archivadas_aparecen_con_nombre_historico` — para Por categoría: archivar una categoría con actividad en el rango, verificar que su nombre histórico aparece.
- `ReportExportTest::test_entries_cancelados_no_aparecen` — soft delete un entry, verificar que su monto no se suma.
- `ReportExportTest::test_cuentas_archivadas_no_aparecen_en_by_account` — archivar una cuenta con balance 0, verificar que no está en el xlsx.

## Pruebas de regresion sobre flujos existentes

- Re-correr `php artisan test` completo. Específicamente:
  - `tests/Feature/Reports/*` — los 5 reports existentes no deben fallar.
  - `tests/Feature/Http/FinanceApiTest.php` — endpoints de lectura JSON intactos.
  - `tests/Feature/Http/EntriesByBucketTest.php` — el endpoint de drill-down no debe ser tocado.
- Verificar que `composer.lock` actualizado no rompe otros packages (`composer validate` + `composer install`).
- Frontend: `npm run test` completo debe pasar; sin warnings nuevos por imports rotos en las 6 vistas.
- Build de prod: `npm run build` debe pasar en local (al menos en una máquina sin el bug de permisos en `dist/` documentado en el backlog).

## Pruebas manuales o smoke tests necesarios

- Levantar stack con `./scripts/fincore start`.
- Login con un user de prueba con data variada (categorías, cuentas, tarjetas, presupuestos).
- En cada una de las 6 vistas:
  1. Verificar que el botón "Exportar a Excel" se ve y está bien posicionado.
  2. Click → la descarga arranca (toast "Exportando..." o equivalente).
  3. Abrir el archivo en LibreOffice o Excel.
  4. Verificar nombre de hoja, encabezado (nombre + rango + fecha de gen), headers en bold, columnas alineadas, formato moneda visible, footer TOTAL correcto.
  5. Sumar manualmente algunas filas y cuadrar con el footer.
- Cambiar filtros y re-exportar: el archivo nuevo refleja los filtros nuevos.
- Probar con reporte vacío: descargar y verificar el xlsx con 0 filas + TOTAL $0.00.
- Probar en navegador con sesión sin verify email: el botón no debería estar accesible (vista bloqueada por router guard) — confirmación del comportamiento existente.

## Datos de prueba recomendados

- 1 user con email verificado.
- Bolsa + 2 cuentas débito + 2 tarjetas crédito (una con metadata completa, una sin metadata).
- 6 categorías default + 1 categoría custom con `monthly_limit` + 1 categoría archivada con histórico.
- 50-100 entries distribuidos a lo largo de 3-6 meses (mix de income, expense, credit_expense, debt_payment, transfer).
- Al menos 1 entry sin categoría (para bucket "Sin categorizar").
- Al menos 1 entry de cada kind en el mes en curso para que Presupuestos tenga data.
- 1 cuenta archivada con balance 0 y entries históricos (para validar que no aparece en `by-account` pero sus entries siguen en `by-category` con histórico).

## Comandos o validaciones locales sugeridas

```bash
# Backend
./scripts/fincore shell api
composer require phpoffice/phpspreadsheet
exit
./scripts/fincore migrate                       # no aplica, sin migración
./scripts/fincore shell api
php artisan test --filter=ReportExport          # tests nuevos
php artisan test                                # suite completa
./vendor/bin/pint                               # lint
exit

# Frontend
cd frontend
npm run test                                    # vitest
npm run build                                   # confirmar que compila
cd ..

# Suite end-to-end
# (sin E2E nuevos en este sprint)
```

## Criterios minimos para aprobar la implementacion

- Suite backend verde (327 actuales + ~20 nuevos esperados).
- Suite frontend verde (58 actuales + ~6-10 nuevos esperados).
- `composer validate` sin warnings.
- `./vendor/bin/pint --test` sin diffs.
- Los 6 endpoints respondiendo 200 con xlsx descargable y abriéndose limpio en LibreOffice.
- Smoke manual cubierto por el desarrollador: cada uno de los 6 reportes descargado y validado.
- Sin regresiones en los endpoints existentes ni en las vistas existentes.
- `CLAUDE.md` actualizado con las 6 rutas nuevas.

## Validacion final recomendada

Ejecutar `branch-quality-review` con `slug=export-excel-reportes` antes de mergear. El reporte queda en `engineering/quality-review/export-excel-reportes/<timestamp>-branch-quality-review.md`. Foco recomendado:

1. **Aislamiento por user**: scope `user_id` en los 6 endpoints, sin filtraciones.
2. **Memoria / performance**: rangos grandes no degradan respuesta más allá de 2s.
3. **Manejo de errores en el frontend**: response JSON con `responseType: 'blob'` parseado correctamente.
4. **Consistencia de formato entre los 6 xlsx**: mismos estilos, mismo patrón de header/footer, sin discrepancias visuales.
5. **Validación de query params**: idéntica a la del endpoint de lectura — sin permitir más relax.
6. **Filename y `Content-Disposition`**: regex en frontend tolerante a variaciones.
