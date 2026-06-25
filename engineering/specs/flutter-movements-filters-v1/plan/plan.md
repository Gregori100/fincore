# Plan técnico — flutter-movements-filters-v1

## Enfoque técnico

Sprint mediano, dividido en 7 fases incrementales. Combina refactor preparatorio (extraer helpers reutilizables), extensión del DAO con filtros multi-valor, una pantalla nueva de filtros estilo "panel moderno", chips de filtros activos en la lista, y deep link bidireccional reporte → entries.

División por fases:

- **F1 — Refactor preparatorio**: extraer `ReportRangePreset` → `lib/constants/date_range_presets.dart` (renombrado `DateRangePreset`) y `_DateFieldOutlined` → `lib/widgets/date_field_outlined.dart`. Actualizar imports en el reporte. Correr suite completa para confirmar 0 regresiones.
- **F2 — Capa de datos**: extender `EntriesDao.watchPage` con `kinds: List<String>?` y `categoryIds: List<String>?` (token `kUncategorizedFilterToken = '__null__'` para entries con `categoryId IS NULL` o categoría archivada). Migrar callers que usan `kind: String?` a la nueva firma. Tests data.
- **F3 — Pantalla de filtros**: nueva `EntriesFiltersScreen` (full-screen modal vía `Navigator.push(MaterialPageRoute)`) con 4 secciones inline + footer fijo. Reusa `DateRangePreset` chips. Cuenta como chips inline (no DropdownButtonFormField). Categorías como chips multi-select con badge.
- **F4 — Integración en `EntriesListScreen`**: leer query params del router al montar, abrir `EntriesFiltersScreen` con state actual y aplicar el resultado, mostrar chips de filtros activos arriba de la lista con "X" para quitar individuales, badge numérico en el AppBar action.
- **F5 — Deep link desde reporte**: agregar `onTap` al `_SpendingBucketRow` que navega a `/entries?from=...&to=...&categoryIds=...&kinds=expense,credit_expense`. Validar que la lista filtrada renderiza correcto.
- **F6 — Widget tests**: del panel de filtros + del flujo de deep link + de los chips activos en la lista.
- **F7 — Release**: bump versión `0.5.0+47`, build APK, `verify-apk.sh`.

El cambio del bottom sheet por una pantalla full-screen se justifica por (a) la queja de Diego sobre lentitud (los `DropdownButtonFormField` y la animación de bottom sheet sumaban overhead) y (b) la necesidad de 4 secciones en lugar de 2 — el espacio vertical de un bottom sheet quedaba limitado.

## Requisitos funcionales cubiertos

- **RF-001 a RF-005** (capa de datos): F2 — `EntriesDao.watchPage` con `kinds` + `categoryIds` + `kUncategorizedFilterToken`. Wrapper temporal compatible con `kind: String?` para migración gradual de callers.
- **RF-006 a RF-011** (pantalla de filtros): F3 — `EntriesFiltersScreen` con header + 4 secciones (Fecha / Tipo / Cuenta / Categorías) + footer "Limpiar todo" / "Aplicar".
- **RF-012 a RF-015** (integración en EntriesListScreen): F4 — query params, chips activos con "X", badge numérico en el IconButton del AppBar.
- **RF-016** (deep link reporte → entries): F5 — `onTap` en `_SpendingBucketRow` con construcción de URL.
- **RF-017** (deprecación `kind: String?`): F2 — wrapper en el DAO + migración de callers.
- **RF-018** (extract `DateRangePreset`): F1 — rename + relocate.
- **RF-019** (extract `DateFieldOutlined`): F1 — relocate sin cambios funcionales.
- **RF-020** (tests data del DAO): F2.
- **RF-021** (widget tests del panel): F6.
- **RF-022** (widget test del deep link): F6.
- **RF-023** (release): F7.

## Archivos o módulos probablemente afectados

Nuevos:

- `mobile/lib/constants/date_range_presets.dart` (~80 líneas, extracted de `lib/screens/reports/range_presets.dart`).
- `mobile/lib/widgets/date_field_outlined.dart` (~50 líneas, extracted de `spending_by_category_tab.dart`).
- `mobile/lib/screens/entries_filters_screen.dart` (~400 líneas estimadas).
- `mobile/test/data/entries_dao_filters_test.dart` (~250 líneas, ≥8 tests).
- `mobile/test/screens/entries_filters_screen_test.dart` (~200 líneas, ≥6 tests).
- `mobile/test/screens/reports_deeplink_test.dart` (~80 líneas, ≥2 tests).
- `mobile/test/constants/date_range_presets_test.dart` (~60 líneas, copia/move de los existentes `range_presets_test.dart`).

Modificados:

- `mobile/lib/data/daos/entries_dao.dart`: nuevos parámetros `kinds` + `categoryIds`, mantener `kind` compatible.
- `mobile/lib/screens/entries_list_screen.dart`: lectura de query params, chips de filtros activos, badge en AppBar, navegación al nuevo panel via `Navigator.push`. Eliminar `_FiltersSheet` interno y el helper `_Chip` (queda en el panel nuevo).
- `mobile/lib/screens/reports/spending_by_category_tab.dart`: agregar `InkWell + onTap` en `_SpendingBucketRow` + construcción de URL para `/entries`.
- `mobile/lib/screens/reports/range_presets.dart`: **eliminar** tras el extract.
- `mobile/lib/router/app_router.dart`: el `/entries` ya acepta query params nativamente con `GoRouter.uri.queryParameters`; verificar que el builder los lea. Sin agregar rutas nuevas (la pantalla de filtros se monta via `Navigator.push`).
- `mobile/pubspec.yaml`: bump `0.5.0+47`.
- `mobile/android/app/build.gradle.kts`: `versionCode=47`, `versionName="0.5.0"`.

Tests existentes que requieren migración (uso de `kind: String?`):

- `mobile/test/screens/entries_list_screen_test.dart`: 2 tests con `_kindFilter`.
- `mobile/test/data/database_test.dart` (posible): si algún test usa `watchPage` con `kind`.
- `mobile/test/screens/reports/range_presets_test.dart`: mover/renombrar a `test/constants/date_range_presets_test.dart` con import nuevo.

Posiblemente no afectados (validar):

- `mobile/lib/data/database.dart`: sin schema bump. `schemaVersion=2` se mantiene.
- DAOs `accounts_dao.dart` y `categories_dao.dart`: sin cambios.
- `mobile/lib/data/financial_state.dart`, `reports.dart`, `backup.dart`: sin cambios.

## Entidades y estados afectados

Sin cambios en entidades de dominio ni en schema. Solo se extiende el comportamiento de lectura sobre `journal_entries`.

Nuevos tipos de presentación / DTO:

- `EntriesFilters`: clase inmutable con `{ from?, to?, kinds, accountId?, categoryIds }`. Usada como argumento del Navigator.push hacia `EntriesFiltersScreen` y como resultado del pop. También sirve para parsear y serializar a/desde query params del router.
- Constante exportada `kUncategorizedFilterToken = '__null__'` para uso en la UI + DAO.

Estados de UI:

- `EntriesListScreen`: amplía su state con un `EntriesFilters _filters` (default = `EntriesFilters.thisMonth()`). El stream se rearma cuando `_filters` cambia.
- `EntriesFiltersScreen`: state local con el `EntriesFilters _editing` que se mutará. Al "Aplicar" hace `Navigator.pop(_editing)`. Al "Limpiar todo" resetea al default. Al "X" en el header descarta y pop sin cambios.

Invariantes:

- `kinds.isEmpty` o `kinds == null` → sin filtro de tipo en el SQL (no es lo mismo que `kinds = [todos los valores]`).
- `categoryIds.contains('__null__')` → SQL incluye `OR category_id IS NULL OR category_id IN (SELECT id FROM categories WHERE deleted_at IS NOT NULL)`.
- Default al abrir `/entries` sin query params: `_filters = EntriesFilters.thisMonth()` (mes calendario completo).
- Compatibilidad con tests previos que pasaban `_filters = sin filtro de fecha`: revisar y migrar si es necesario.

Decisión clave sobre el default: el sprint cambia el default histórico de `/entries` ("sin filtro de fecha, todos los entries") a "Este mes". Esto es coherente con el reporte y con el feedback del usuario, pero rompe expectativa de "ver TODOS los movimientos cargando la pantalla". Documentado como cambio de UX en `desviaciones-plan.md` cuando se implemente.

## Compatibilidad con datos y procesos existentes

- **Backup JSON v1**: sin cambios. El sprint no toca `BackupService`.
- **Datos históricos**: `EntriesDao.watchPage` con `kinds = ['expense', 'credit_expense']` y `from = primer día mes` rinde sobre el journal histórico igual. Entries de meses anteriores siguen visibles cuando se ajusta el filtro de fecha o se quita.
- **Dashboard**: no afectado. Sigue usando `watchPage(limit: 10)` sin filtros para "Últimos movimientos". El cambio de firma del DAO debe mantenerse compatible (`kind: String?` deprecado pero funcional).
- **`/reports`**: sin cambios funcionales en el reporte mismo. Sí se agrega un `onTap` al bucket (interacción nueva).
- **`MigrationStrategy.onUpgrade`**: no se toca. `schemaVersion=2` queda igual.
- **Soft delete de categorías (RN-H03)**: el bucket "Sin categoría" del reporte ya incluye archivadas; el deep link respeta eso. Si la categoría se archiva mientras el filtro está activo con esa categoría, los entries dejan de aparecer (porque su `category_id` ya no matchea — la categoría está soft-deleted, y el filtro `WHERE category_id IN (X)` ya no la considera). Esto es **consistente con la regla**: archivar categoría → entries van a "Sin categoría". Documentado como caso borde.

## Cambios de datos

No aplica. Sin schema bump, sin migraciones, sin tablas nuevas, sin índices nuevos.

Nota de riesgo: el `WHERE kind IN (?,?,...)` y `WHERE category_id IN (?,?,...)` con muchas opciones puede degradar sin índice. Con el `idx_entries_kind` existente, la query rinde bien hasta ~50k entries. Si degrada, sprint futuro evalúa índice compuesto (M7 del quality review anterior ya lo documenta).

## Cambios de API

No aplica. App local-first sin endpoints HTTP.

## Cambios de integraciones

- **go_router query params**: se aprovecha la capacidad nativa de `GoRouter` de leer `state.uri.queryParameters` en el builder del `GoRoute('/entries')`. Sin agregar deps.
- **Sin nuevas deps externas**.

## Cambios de UI

- **EntriesListScreen**:
  - Reemplazar `_FiltersSheet` (bottom sheet) por navegación a `EntriesFiltersScreen` vía `Navigator.push(MaterialPageRoute)`.
  - Cambiar el `IconButton` del AppBar: `Icons.filter_list` → `Icons.tune` con badge numérico de filtros activos.
  - Agregar fila de chips de "Filtros activos" arriba de la lista, scrollable horizontal, cada chip con "X".
  - Default de `_filters` cambia: de "sin filtro" a "`DateRangePreset.thisMonth`". Esto cambia el comportamiento por defecto.

- **EntriesFiltersScreen** (nueva):
  - `Scaffold` con `AppBar("Filtros", leading: IconButton(close))`.
  - Body `ListView` con 4 secciones (cada una con `Text(label)` + Wrap o Row de chips).
  - Footer fijo en `bottomNavigationBar` o `Persistent footer button` con `Row(OutlinedButton "Limpiar todo" + FilledButton "Aplicar")`.
  - Wrap responsivo de chips de cuentas y categorías (si hay 10+, hace wrap a múltiples líneas).
  - Cuando se elige `DateRangePreset.custom`, aparece debajo el `DateFieldOutlined` para from + to.

- **SpendingByCategoryTab**:
  - `_SpendingBucketRow` se convierte en `InkWell` tappeable. `onTap` construye URL con query params y navega via `context.push(...)`.

- **Theme**: sin cambios.

## Cambios de permisos

No aplica.

## Riesgos técnicos

- **RT-01**: cambio de firma del DAO (`kind: String?` → `kinds: List<String>?`) rompe compatibilidad con tests existentes. Mitigación: mantener `kind` deprecado en F2 con wrapper interno que arma `kinds = [kind]`. Migrar callers en commit aislado dentro del sprint y dejar `kind` marcado `@Deprecated`. Eliminar en sprint posterior.
- **RT-02**: cambio del default de `/entries` ("sin filtro" → "Este mes") puede confundir a Diego si esperaba ver TODO el histórico al entrar. Mitigación: documentar como cambio de UX y validar en smoke. Si molesta, el "Aplicar" del panel con todos los filtros default = "Limpiar y aplicar" cambia el rango.
- **RT-03**: query con `WHERE kind IN (?,?,...) AND category_id IN (?,?,...) AND ...` puede ser lenta sin índice cuando crezca el journal. Mitigación: mantener vigilancia + M7 del quality review previo ya documenta el índice futuro. No bloquea este sprint.
- **RT-04**: query params de URL pueden tener caracteres especiales (espacios, comas, UUIDs). `GoRouter` los URL-encode automáticamente, pero la construcción manual del URL en el bucket onTap debe usar `Uri` constructor para encoding correcto, no string concatenation.
- **RT-05**: el `Navigator.push` del panel pasa el `EntriesFilters` actual como argumento y recibe el nuevo al pop. Riesgo de pasar referencia mutable y mutar desde el panel. Mitigación: `EntriesFilters` debe ser **inmutable** (`final` fields, `copyWith`). No exponer setters.
- **RT-06**: cuenta archivada presente en `_filters.accountId` debe ignorarse al renderizar chips del panel. Mitigación: filtrar la lista de cuentas del stream `watchActive()` (que ya excluye archivadas). Si el `accountId` actual no está en la lista, mostrar "Cuenta archivada" como chip warning con opción a quitar.
- **RT-07**: el `EntriesFilters.serialize` para query params debe ser estable y reversible. Decisión: usar csv simple para `kinds` y `categoryIds`, formato ISO 8601 para fechas. Tests del round-trip.

## Estrategia de pruebas

Tests data en F2 (gate antes de avanzar a UI). Tests UI en F6.

- **Tests unitarios `EntriesDao.watchPage` (≥8)**: cubrir cada nuevo parámetro (`kinds` con 1, 2 elementos; `categoryIds` con 1, 2, `__null__`; combinaciones; soft-delete de entries; categorías archivadas).
- **Tests del `EntriesFilters` (≥3)**: round-trip de query params (parse + serialize), default `thisMonth()`, helper `withPreset(DateRangePreset.lastMonth)`.
- **Widget tests del panel (≥6)**: render de las 4 secciones, tap en chip aplica visual, "Limpiar todo" resetea al default, "Aplicar" cierra con resultado, multi-select de categorías, chip "Sin categoría" toggleable.
- **Widget tests del deep link (≥2)**: tap en bucket navega correcto, `/entries` con query params pre-carga el filtro y renderiza la lista filtrada.
- **Widget test del badge numérico** en `EntriesListScreen` AppBar.
- **Regresión**: la suite previa de 168 tests debe quedar verde tras la migración de los callers de `kind`.
- **Smoke manual**: panel abre en <200ms, deep link funciona, chips "X" remueven filtros individuales.

`flutter analyze` en 0 errores / 0 warnings al final.

## Estrategia de rollback

Aditivo en la mayoría (panel nuevo, DAO con params opcionales nuevos). El único cambio breaking es la firma de `watchPage` y el default de `/entries`.

- **Opción A — revert completo**: `git revert <hash>` del commit del sprint. Sin pérdida de datos.
- **Opción B — patch parcial**: si falla solo el deep link, revertir el `onTap` del bucket (vuelve a comportamiento read-only).
- **Opción C — patch parcial del default**: si Diego siente que el nuevo default "Este mes" molesta, hotfix `0.5.0+48` con default vuelto a "sin filtro" y agregar opción explícita para activar "Este mes" como preset.

## Orden sugerido de implementación

1. **F1 — Refactor preparatorio**:
   1.1. Crear `lib/constants/date_range_presets.dart` con copia de `lib/screens/reports/range_presets.dart` renombrando `Report` → `Date`.
   1.2. Crear `lib/widgets/date_field_outlined.dart` con `_DateFieldOutlined` ahora público.
   1.3. Actualizar `spending_by_category_tab.dart` para usar los nuevos imports.
   1.4. Eliminar `lib/screens/reports/range_presets.dart` viejo.
   1.5. Mover/copiar `test/screens/reports/range_presets_test.dart` → `test/constants/date_range_presets_test.dart` con imports nuevos.
   1.6. Correr `flutter test` — 168 verdes esperado.
2. **F2 — Capa de datos**:
   2.1. Definir `kUncategorizedFilterToken` en `lib/data/daos/entries_dao.dart`.
   2.2. Agregar params `kinds: List<String>?` y `categoryIds: List<String>?` a `watchPage`.
   2.3. Implementar la query: `kinds → WHERE kind IN`, `categoryIds → WHERE category_id IN (+OR IS NULL si __null__)`.
   2.4. Mantener `kind: String?` deprecado con wrapper interno.
   2.5. Crear `test/data/entries_dao_filters_test.dart` con ≥8 tests.
   2.6. Migrar callers existentes que usan `kind` a `kinds = [kind]` (`entries_list_screen.dart` previo, tests).
   2.7. Correr suite completa — 168+ verdes (los 8 nuevos + sin regresión).
3. **F3 — Pantalla de filtros**:
   3.1. Crear `lib/screens/entries_filters_screen.dart` con scaffold + 4 secciones placeholders.
   3.2. Definir `EntriesFilters` class inmutable con `copyWith`, `serialize` (a `Map<String,String>` para query params), `parse` (desde `Map<String,String>`).
   3.3. Implementar sección Fecha usando chips de `DateRangePreset` + `DateFieldOutlined` cuando Custom.
   3.4. Implementar sección Tipo: chips Todos / Ingreso / Gastos / Pago de tarjeta / Transferencia. "Gastos" mapea a `kinds = ['expense', 'credit_expense']`.
   3.5. Implementar sección Cuenta: chips inline con `watchActive()` stream.
   3.6. Implementar sección Categorías: chips multi-select con badge. Primer chip "Sin categoría".
   3.7. Footer fijo "Limpiar todo" + "Aplicar".
   3.8. Iterar visualmente con `flutter run -d linux`.
4. **F4 — Integración en EntriesListScreen**:
   4.1. Leer query params del router en `didChangeDependencies` o `initState` y parsear a `EntriesFilters`.
   4.2. Reemplazar `_openFilters` por navegación a `EntriesFiltersScreen` con `Navigator.push<EntriesFilters>(MaterialPageRoute(...))`. Al pop, si llega un filtro nuevo, aplicarlo.
   4.3. Reemplazar el IconButton del AppBar por uno con `Icons.tune` + badge numérico del `_filters.activeCount`.
   4.4. Agregar fila de chips de filtros activos arriba de la lista. Cada chip con "X" remueve solo esa dimensión.
   4.5. Estado vacío específico cuando hay filtros pero 0 resultados ("No hay movimientos con esos filtros. Probá ajustarlos.").
   4.6. Eliminar `_FiltersSheet` viejo y `_Chip` helper local.
5. **F5 — Deep link desde reporte**:
   5.1. Envolver `_SpendingBucketRow` en `InkWell` con `onTap`.
   5.2. Construir URL: `Uri(path: '/entries', queryParameters: {...}).toString()`.
   5.3. Navegar con `context.push(url)`.
   5.4. Validar visualmente con `flutter run -d linux` que `/entries` se abre con la lista filtrada correctamente.
6. **F6 — Widget tests**:
   6.1. Crear `test/screens/entries_filters_screen_test.dart` con ≥6 tests.
   6.2. Crear `test/screens/reports_deeplink_test.dart` con ≥2 tests del flujo end-to-end.
   6.3. Actualizar `test/screens/entries_list_screen_test.dart` con tests del badge + chips de filtros activos.
   6.4. Correr suite completa — 184+ verdes.
7. **F7 — Release**:
   7.1. Bump `pubspec.yaml` a `0.5.0+47`.
   7.2. Bump `android/app/build.gradle.kts` a `versionCode=47, versionName="0.5.0"`.
   7.3. `flutter analyze` limpio.
   7.4. `flutter build apk --release --split-per-abi`.
   7.5. `scripts/verify-apk.sh` exit 0 con versionCode 2047.
8. **Validación de calidad**:
   8.1. Invocar `/branch-quality-review flutter-movements-filters-v1`.
   8.2. Resolver hallazgos críticos antes del commit.

## Casos borde que condicionan la solución

Más allá de los CB-01 a CB-11 del spec:

- **CB-extra-01**: deep link con `kinds=expense,credit_expense` pero la categoría del bucket es activa y no se encuentra en la BD (ej. usuario importó respaldo viejo): el filtro `WHERE category_id IN (X)` no matchea → lista vacía. UI debe mostrar el estado vacío con sugerencia clara. No es bug.
- **CB-extra-02**: rango Custom con `from > to` propagado desde URL (manipulación manual): la pantalla `/entries` debe validar al parsear y, si es inválido, caer al default. Sin crash.
- **CB-extra-03**: orden de los kinds en `kinds = ['credit_expense', 'expense']` (revertido) debe rendir igual que `['expense', 'credit_expense']` — el `WHERE IN` no depende del orden. Los tests deben validar ambos casos para evitar regresión por dependencia accidental.
- **CB-extra-04**: si el panel está abierto y Diego registra un movimiento desde otro flujo (improbable sin background, pero conceptualmente), el `accountsStream` del panel emite la nueva cuenta — los chips se reactualizan. Validar que no crashea.
- **CB-extra-05**: el `Navigator.push` del panel y el `Navigator.pop` con `EntriesFilters` debe ser tipado (`Navigator.push<EntriesFilters>(...)` retorna `Future<EntriesFilters?>`). Si Diego hace back-swipe sin tap en "Aplicar", el future resuelve a `null` y NO se aplican cambios. Validar.
- **CB-extra-06**: los chips de filtros activos arriba de la lista deben truncar el nombre de categoría con `…` si es muy largo (>15 caracteres). Sin overflow visual.
- **CB-extra-07**: el `EntriesFilters.serialize` que genera el URL debe omitir parámetros default (ej. si `kinds` es vacío, no incluirlo en la URL). Mantiene URLs cortas y reversibles.

## Preguntas o supuestos que siguen afectando la implementación

Sin preguntas bloqueantes. Los supuestos del spec (S-01 a S-08) siguen vigentes y se respetan.

Decisiones técnicas tomadas durante el plan (no requieren confirmación adicional):

- **DT-P-01**: el panel se monta vía `Navigator.push(MaterialPageRoute)` en lugar de ser una ruta GoRouter. Razón: simplicidad de pasar/recibir `EntriesFilters`. Sin URL en la barra, lo cual es correcto porque el panel es un overlay UX, no un endpoint linkable.
- **DT-P-02**: `EntriesFilters` es inmutable con `copyWith`. Argumento del Navigator.push es snapshot.
- **DT-P-03**: el default `EntriesFilters.thisMonth()` se aplica al montar `/entries` solo si NO hay query params. Si hay query params, la URL gana.
- **DT-P-04**: el `Navigator.pop` del panel sin tap en "Aplicar" (back nativo, swipe, X del header) descarta cambios. Solo "Aplicar" propaga.
- **DT-P-05**: la sección "Tipo" del panel mapea visualmente "Gastos" a `kinds = ['expense', 'credit_expense']`. No expone los kinds individuales por separado. Si Diego en el futuro quiere ver solo `expense` o solo `credit_expense`, sprint patch agrega chips separados.
- **DT-P-06**: el badge numérico del AppBar cuenta dimensiones (max 4), no items individuales (ej. 3 categorías seleccionadas cuenta como "categorías = 1 dimensión activa", no 3).
- **DT-P-07**: el chip "Sin categoría" en el panel y el bucket "Sin categoría" en el reporte usan el mismo token `'__null__'` internamente. Constante única exportada desde `entries_dao.dart`.
