# Test plan — flutter-movements-filters-v1

## Casos borde detectados

Más allá de los CB-01 a CB-11 del spec, la planeación detectó:

- **CB-T01**: BD sin entries pero con filtros activos → estado vacío específico ("No hay movimientos con esos filtros. Probá ajustarlos.").
- **CB-T02**: BD con entries pero todos fuera del rango temporal del filtro → estado vacío específico.
- **CB-T03**: filtro `kinds = []` (lista vacía) → equivalente a `kinds = null` → sin restricción de tipo.
- **CB-T04**: filtro `categoryIds = ['__null__']` (solo Sin categoría) → matchea entries con `category_id IS NULL` + entries con categoría archivada.
- **CB-T05**: filtro `categoryIds = ['cat1', 'cat2', '__null__']` (mix) → matchea entries de esas 2 categorías + sin categoría + archivadas.
- **CB-T06**: filtro de `accountId` apunta a una cuenta que se archivó después → query no rompe (la cuenta sigue existiendo en BD con `deleted_at != null`, no se elimina físicamente). El WHERE `account_origin_id = X OR account_destination_id = X` matchea históricos.
- **CB-T07**: filtro `kinds = ['expense', 'credit_expense']` con entries `transfer` o `debt_payment` en la BD → los kinds no listados no aparecen (excluyente correcto).
- **CB-T08**: deep link con `categoryIds=archived_cat_id` (categoría archivada como UUID): el filtro `WHERE category_id IN (X)` matchea porque la categoría existe en BD aunque `deleted_at != null`. Coherente: si Diego deep-linkea desde un bucket de categoría archivada (que en el reporte cae como "Sin categoría"), el URL real usa `__null__`, no el UUID. Validar en el `onTap` del bucket.
- **CB-T09**: deep link con URL malformado o param no esperado → la pantalla cae al default sin crash.
- **CB-T10**: tap rápido en chips del panel (≥10 toggles seguidos) → state interno sin freeze. Solo "Aplicar" rearma el stream del DAO.
- **CB-T11**: panel abierto con cuenta seleccionada que se archiva en otra sesión → al reabrir, el accountId apunta a archivada. Decisión: filtrar silenciosamente al renderizar chips, mostrar chip "warning" solo si está en `_filters` pero no en el stream de cuentas activas.
- **CB-T12**: cambio de fecha en el panel via Custom: rango `from > to` → mismo manejo que en `/reports` (SnackBar warning, preservar rango anterior).
- **CB-T13**: `EntriesFilters.serialize` con `kinds=['expense', 'credit_expense']` → URL `?kinds=expense,credit_expense`. Orden estable (alfabético o el ingresado, decidir y testear).
- **CB-T14**: `EntriesFilters.parse` con `kinds=` vacío → `kinds = null` (no `[]`). Diferencia importante para el DAO.
- **CB-T15**: `EntriesFilters.parse` con valores duplicados (`kinds=expense,expense`) → deduplicar a `['expense']`. Sin lanzar.
- **CB-T16**: tap en bucket del reporte y back del navegador → vuelve al reporte, NO al estado previo de `/entries`. Comportamiento estándar.
- **CB-T17**: filtros activos arriba de la lista, tap en "X" del único chip activo → quita filtro y el chip desaparece (la fila completa puede ocultarse si no quedan chips).
- **CB-T18**: archivar categoría mientras un filtro `categoryIds = [cat_archivada]` está activo → el Stream del DAO re-emite, la lista pasa a vacía (la categoría dejó de matchear). El chip del filtro queda en UI con el nombre histórico hasta que el usuario lo cambie. Decisión: mantener chip, no auto-limpiar (el usuario decide).

## Pruebas unitarias necesarias

Archivo: `mobile/test/data/entries_dao_filters_test.dart` — BD in-memory.

- **UT-01**: `kinds = ['income']` retorna solo income.
- **UT-02**: `kinds = ['expense', 'credit_expense']` retorna ambos kinds combinados; excluye otros.
- **UT-03**: `kinds = []` o `null` → sin filtro.
- **UT-04**: `categoryIds = [cat1]` retorna solo entries con esa categoría.
- **UT-05**: `categoryIds = [cat1, cat2]` retorna entries de ambas, no de otras.
- **UT-06**: `categoryIds = ['__null__']` retorna entries con `category_id IS NULL` Y entries con categoría archivada.
- **UT-07**: `categoryIds = [cat1, '__null__']` retorna entries de cat1 + null + archivadas.
- **UT-08**: combinación `kinds + categoryIds + from + to + accountId` aplica AND entre todas. Validar resultado exacto con seed conocido.
- **UT-09**: filtro de fecha inclusivo (límites exactos `from 00:00` y `to 23:59:59.999`).
- **UT-10**: soft-delete de entry no aparece independientemente de filtros.
- **UT-11**: orden `occurred_at DESC` preservado tras filtros.
- **UT-12**: regresión — `kind: String?` deprecado sigue funcionando (`watchPage(kind: 'income')` retorna solo income).

Archivo: `mobile/test/data/entries_filters_test.dart` — clase `EntriesFilters` pura.

- **UT-13**: `EntriesFilters.thisMonth()` retorna preset thisMonth + rango correcto.
- **UT-14**: `EntriesFilters.serialize` round-trip con `EntriesFilters.parse` para varios estados.
- **UT-15**: `serialize` omite campos default (URL corta).
- **UT-16**: `parse` con URL malformado retorna `EntriesFilters.thisMonth()` (default).
- **UT-17**: `parse` deduplica valores repetidos en `kinds` y `categoryIds`.

Archivo: `mobile/test/constants/date_range_presets_test.dart` — copia de `range_presets_test.dart` con imports nuevos. 14 tests preservados.

## Pruebas de integración o API necesarias

App local-first sin API. Integración real es `EntriesDao.watchPage` + UI consumidora.

- **IT-01**: registrar 5 entries con `EntriesDao`, abrir el panel desde `EntriesListScreen`, aplicar filtro, validar lista filtrada. End-to-end.
- **IT-02**: archivar una categoría con `CategoriesDao` mientras el panel tiene esa categoría seleccionada, validar comportamiento documentado en CB-T18.

Estos pueden incluirse en `entries_filters_screen_test.dart` o un grupo "integración".

## Pruebas de UI o flujo necesarias

Archivo: `mobile/test/screens/entries_filters_screen_test.dart`.

- **WT-01**: panel monta con default `thisMonth` + Tipo "Todos" + Cuenta "Todas" + 0 categorías seleccionadas.
- **WT-02**: tap en chip "Gastos" lo marca selected; los otros chips de tipo se desmarcan.
- **WT-03**: tap en chip de categoría toggle la selección (multi-select). Tap en 2 categorías marca ambos.
- **WT-04**: tap en "Limpiar todo" resetea al default visualmente (sin pop).
- **WT-05**: tap en "Aplicar" hace `Navigator.pop` con el `EntriesFilters` armado. Validar el valor del pop.
- **WT-06**: tap en X del header (close) hace pop sin propagar cambios (resultado del pop es null).
- **WT-07**: chip "Sin categoría" multi-select con otras categorías. El token `__null__` aparece en el resultado del pop.
- **WT-08**: tap en chip "Custom" del preset de fecha muestra los 2 `DateFieldOutlined` debajo.

Archivo: `mobile/test/screens/reports_deeplink_test.dart`.

- **WT-09**: en `/reports`, seed con entries de 2 categorías + tap en bucket de "Comida". Validar navegación a `/entries` y que la lista solo muestra los entries de Comida.
- **WT-10**: tap en bucket "Sin categoría" del reporte. Validar `/entries` muestra solo entries con `category_id` null y archivadas.

Archivo: `mobile/test/screens/entries_list_screen_test.dart` (extensión).

- **WT-11**: AppBar tiene `IconButton(Icons.tune)` con badge numérico cuando hay filtros activos. Sin badge cuando todos los filtros están en default. **Validar** que el default conta como 1 filtro o no (decisión del DT-P-06: dimensiones activas, default thisMonth cuenta como dimensión activa fecha → badge ≥ 1).
- **WT-12**: chips de filtros activos arriba de la lista. Tap en "X" de uno remueve solo esa dimensión y rearma el stream.
- **WT-13**: deep link con query params pre-carga el panel con los filtros correctos. Tap inmediato en "Aplicar" sin tocar nada produce un EntriesFilters equivalente al de la URL.
- **WT-14**: lista con filtros activos + 0 resultados muestra estado vacío específico ("No hay movimientos con esos filtros").

## Pruebas de permisos y seguridad

No aplica. Single-user, sin auth, sin permisos. URLs locales sin riesgo de IDOR.

## Pruebas de datos, migración o compatibilidad

- **MG-01**: BD con `schemaVersion=2` (estado actual) → sin migración disparada. Verificable manualmente.
- **MG-02**: importar respaldo JSON v1 → las queries con filtros nuevos siguen rindiendo correcto sobre los datos importados.
- **MG-03**: callers existentes con `kind: String?` siguen funcionando tras la migración a `kinds: List<String>?` (compatibilidad backward via wrapper deprecado).

## Pruebas de regresión sobre flujos existentes

- **RG-01**: `Dashboard` sigue mostrando los últimos 10 movimientos sin filtrar (no afectado).
- **RG-02**: `Backup export/import` round-trip sigue funcionando (no afectado).
- **RG-03**: tests de `FinancialStateService` (BO/DE/CR) — no afectados.
- **RG-04**: tests de `ReportsService.spendingByCategory` — no afectados.
- **RG-05**: tests del entry form (5 kinds) — no afectados.
- **RG-06**: tests del category/account form — no afectados.
- **RG-07**: tests existentes de `entries_list_screen_test.dart`: 2 tests del filtro kind viejo — migrar a la nueva API.
- **RG-08**: tests del `_RangePreset` (14) — migrar a `DateRangePreset` en nuevo path.

Suite total post-sprint: ≥ 184 verdes (168 actual + 16 nuevos mínimo).

## Pruebas manuales o smoke tests necesarios

Tras instalar `0.5.0+47` en el Redmi:

- **SM-01**: Abrir `/entries` desde Dashboard. Confirma que se ve la lista (con el nuevo default "Este mes").
- **SM-02**: Tap en icono `tune` del AppBar. **Confirmar que el panel abre rápido** (subjetivo, sin lag). Sentir vs. el anterior 0.4.3+46.
- **SM-03**: En el panel, seleccionar "Mes pasado" + "Gastos" + categoría "Comida" + cuenta "Bolsa". Aplicar. Validar que la lista muestra solo lo esperado.
- **SM-04**: En `/reports`, tap en bucket de cualquier categoría → navega a `/entries` con filtros visibles arriba y lista filtrada. Confirmar el rango y categoría coinciden con el reporte.
- **SM-05**: En `/entries` con filtros activos, tap en "X" del chip de fecha. Solo la fecha se quita; tipo y categoría permanecen. Lista se rearma.
- **SM-06**: Back nativo desde el panel (sin "Aplicar"). Confirmar que NO se aplican cambios pendientes.
- **SM-07**: Tap en bucket "Sin categoría" del reporte. `/entries` muestra solo entries sin categoría + archivadas. Confirmar contenido.
- **SM-08**: Multi-select de 2 categorías en el panel → aplicar → lista muestra entries de ambas combinadas (OR).
- **SM-09**: Registrar un entry nuevo desde `/entries/new`. Volver a `/entries`. Si está dentro del rango del filtro, aparece. Si no, no aparece (default thisMonth, entry de mes pasado no aparece).

## Datos de prueba recomendados

Para los unitarios (`entries_dao_filters_test.dart`):

- Bolsa por seed + 2 cuentas debit/credit creadas en setUp.
- 4 categorías expense (Comida, Transporte, Salud, Ocio) + 1 archivada (Educación archivada).
- Entries variados con fechas distribuidas en mes corriente y mes anterior.

Para widget tests (`entries_filters_screen_test.dart`):

- Seed con 3-5 cuentas + 5-8 categorías para que el panel tenga datos suficientes para multi-select.

## Comandos o validaciones locales sugeridas

```bash
cd mobile

# Tras F2 (capa de datos):
flutter test test/data/entries_dao_filters_test.dart
flutter test test/data/entries_filters_test.dart

# Tras F2 completo:
flutter test  # confirmar 168 + 17 nuevos = 185 verdes esperado

# Tras F3 (panel):
flutter run -d linux

# Tras F4 (integración):
flutter run -d linux  # navegar /entries → tap tune → aplicar
flutter test

# Tras F6:
flutter test  # ≥ 184 verdes

# Tras F7:
flutter analyze  # 0 errores, 0 warnings
flutter build apk --release --split-per-abi
scripts/verify-apk.sh build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

## Criterios mínimos para aprobar la implementación

- ≥17 tests data nuevos verdes (UT-01 a UT-17).
- ≥10 widget tests del panel + deep link + chips activos verdes (WT-01 a WT-14).
- Suite total ≥184 tests verdes (168 + 16 nuevos mínimo).
- `flutter analyze`: 0 errores, 0 warnings.
- `verify-apk.sh` exit 0 con versionCode 2047.
- APK release instalable sin downgrade error.
- Smoke manual SM-01 a SM-09 pasados (Diego confirma).
- Sin regresión en la suite previa (RG-01 a RG-08).
- **Subjetivo**: Diego siente que el panel abre rápido (CME-04).

## Validación final recomendada

Antes del commit formal del sprint, invocar `/branch-quality-review flutter-movements-filters-v1` para revisión exhaustiva. El reporte se genera en `engineering/quality-review/<slug>/`, no en `implementation/`.

Áreas a vigilar especialmente en el review:

- **SQL del DAO**: el `WHERE category_id IN (?,...) OR category_id IS NULL OR category_id IN (SELECT ...)` con muchos placeholders. ¿Inyección? ¿Performance?
- **`EntriesFilters` serializer**: ¿es estable y reversible? ¿URL-encoding correcto?
- **`Navigator.push` tipado**: ¿correct uso de `MaterialPageRoute<EntriesFilters>`?
- **Estado del panel mutable vs `EntriesFilters` inmutable**: ¿no hay leak de mutación entre pantallas?
- **Cambio del default de `/entries`**: ¿UX correcto o vale agregar un botón "Ver todos" en el estado vacío?

Hallazgos críticos resolver antes del commit. No críticos pueden quedar en `pendientes.md` con justificación.
