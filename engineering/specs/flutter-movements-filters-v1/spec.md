# flutter-movements-filters-v1 — Filtros avanzados de movimientos + deep link desde reportes

## Resumen

Rediseñar la experiencia de filtros de la pantalla `/entries` para que sea rápida, rica y consistente con `/reports`. Reemplazar el modal de bottom sheet actual (lento al abrir por prerendering de Material 3 `DropdownMenu`) por un panel a pantalla casi completa estilo apps modernas (Mercado Libre, Booking) con secciones inline + footer fijo. Agregar **3 filtros nuevos** (fecha por presets, categorías multi-select, "Gastos" como tipo combinado) y habilitar **deep link desde el reporte**: tap en un bucket del reporte de gasto por categoría navega a `/entries` con filtros pre-cargados (categoría + fecha del reporte + tipo "Gastos").

## Problema a resolver

Diego registra movimientos a diario. La pantalla `/entries` hoy permite filtrar solo por **kind individual** (5 opciones) y **cuenta individual**. Cuando quiere responder preguntas concretas — *"¿cuánto gasté en Comida el mes pasado?"*, *"¿qué transferencias hice de Bolsa a Banamex en junio?"* — debe buscar a ojo en la lista paginada de 200 entries.

Hay además dos problemas operativos:

1. **El modal de filtros tarda en abrir** (>500ms) porque el `AccountPicker` interno usa `DropdownMenu<String>` de Material 3, que **prerenderea TODOS los items con sus íconos** antes de mostrar el menú. Con 5+ cuentas más posibles categorías en el futuro, la lentitud crecerá.
2. **El reporte `/reports` es solo lectura**: si Diego ve que "Comida" lidera el gasto del mes, no puede tappear para revisar qué movimientos componen ese total. Tiene que ir a `/entries`, abrir el modal de filtros, configurar manualmente cada filtro. Fricción innecesaria.

## Objetivo

Entregar un panel de filtros rápido (<200ms al abrir), con 4 dimensiones de filtrado (fecha, tipo, cuenta, categorías), reusando los chips de presets del sprint anterior (`flutter-reports-v1`) para fecha. Habilitar un nuevo flujo de drill-down desde el reporte: tap en un bucket pre-carga los filtros equivalentes en `/entries` y abre la lista filtrada lista para revisar.

## Alcance

- **UI del filtro**: pantalla casi completa (full-screen modal) en lugar del bottom sheet actual. Header fijo + body scrollable con secciones inline + footer fijo con "Limpiar todo" y "Aplicar".
- **4 dimensiones de filtro**:
  - **Fecha**: chips de presets reusados de `/reports` (Este mes / Mes pasado / Año / Custom). Default: "Este mes" (mes calendario completo).
  - **Tipo**: chips. Opciones: Todos / Ingreso / **Gastos** (combinado expense + credit_expense) / Pago de tarjeta / Transferencia. Reemplaza el modelo de kind único actual.
  - **Cuenta**: chips inline scrollables con icono + nombre + tipo (cash/debit/credit). Single-select. Reemplaza el `AccountPicker` dropdown actual.
  - **Categorías**: chips multi-select con badge (color slug + icon slug). Incluye opción especial **"Sin categoría"** para entries con `categoryId IS NULL` o categoría archivada.
- **DAO**: extender `EntriesDao.watchPage` para aceptar `kinds: List<String>?` (multi-kind), `categoryIds: List<String>?` (multi-cat, NULL como token especial para "Sin categoría"). Mantener `from`/`to` ya existentes.
- **Deep link desde reporte**: tap en un bucket de `SpendingByCategoryTab` navega a `/entries` con query params (`?from=...&to=...&categoryIds=...&kinds=expense,credit_expense`). La pantalla `/entries` lee los query params al montar y pre-carga los filtros.
- **Filtros activos visibles en `/entries`**: mostrar arriba de la lista los filtros aplicados como chips con "X" para quitar individualmente. Tap en "X" del último filtro deja todo limpio.
- **Contador de filtros activos en el botón de abrir filtros** (badge numérico).
- **Persistencia de filtros** durante la sesión: al cerrar/reabrir el panel, los filtros se mantienen. Reset solo al pop de `/entries` + nueva entrada o tap en "Limpiar".
- Tests data + widget tests + smoke manual.
- Release `0.5.0+47` (minor por feature visible nuevo + cambio de UX significativo).

## Fuera de alcance

- **Paginación / scroll infinito**: hoy con `limit: 200` fijo es suficiente. La arquitectura de filtros queda diseñada para sumar `offset` futuro sin refactor (ver Riesgos / Supuestos).
- **Filtros por monto** (rango "$X a $Y"). Posible sprint futuro.
- **Filtros por descripción** (búsqueda textual). Posible sprint futuro con FTS5 de SQLite.
- **Guardar filtros como "vistas guardadas"** (ej. "Comida del mes"). Sprint futuro si se vuelve recurrente.
- **Exportar movimientos filtrados** (CSV/PDF). Sprint futuro.
- **Multi-account**: cuenta queda single-select por simplicidad. Si surge necesidad, sprint futuro.
- **Filtros por tag** (no hay modelo de tags todavía).
- **Filtros aplicables a otras pantallas** (Dashboard, Settings). Solo `/entries`.
- **Reordenar resultados** (sort por monto, fecha asc/desc): orden actual `occurred_at DESC` se mantiene.
- **Optimizar el render del `DropdownMenu` global**: el fix es local — eliminamos el `DropdownMenu` del filtro de cuenta y usamos chips. Si otras pantallas siguen lentas por el mismo `DropdownMenu`, sprint aparte.

## Reglas de negocio

- **RN-M01**: el filtro de tipo "Gastos" agrupa los kinds `expense` + `credit_expense`. Cuando se aplica, la query SQL usa `WHERE kind IN ('expense', 'credit_expense')`. Coincide con el filtro del reporte de gasto por categoría (RN-R01 del sprint `flutter-reports-v1`).
- **RN-M02**: el filtro de categorías acepta múltiples ids simultáneos. SQL: `WHERE category_id IN (?, ?, ...) OR (category_id IS NULL AND ... )` cuando se incluye el token "Sin categoría".
- **RN-M03**: el token "Sin categoría" en el filtro matchea entries con `category_id IS NULL` **o** entries cuya categoría está archivada (`deleted_at IS NOT NULL`). Consistente con RN-R03/R04 del reporte.
- **RN-M04**: el rango de fecha es **inclusivo en ambos extremos** (mismo cierre `23:59:59.999` que el reporte). Consistente con RN-R05.
- **RN-M05**: el orden de los entries en la lista filtrada es `occurred_at DESC` (más reciente primero). Sin cambio respecto al comportamiento actual.
- **RN-M06**: filtros se combinan con AND. Ningún filtro vacío genera resultados vacíos (filtro vacío = sin restricción).
- **RN-M07**: entries soft-deleted (`journal_entries.deleted_at IS NOT NULL`) NO aparecen en la lista filtrada. Igual al comportamiento actual.
- **RN-M08**: el deep link desde el reporte pre-carga estos filtros exactos:
  - `from` y `to` del reporte.
  - `categoryIds` = [bucket.categoryId] si el bucket es real, o ["__null__"] (token Sin categoría) si el bucket es "Sin categoría".
  - `kinds` = `['expense', 'credit_expense']` (tipo "Gastos").
  - `accountId` = null (sin filtrar por cuenta).
- **RN-M09**: el contador de filtros activos en el badge cuenta cada dimensión que tenga al menos un valor seleccionado (max 4: fecha + tipo + cuenta + categorías). "Tipo = Todos" cuenta como sin filtro.

## Requisitos funcionales

- **RF-001**: extender `EntriesDao.watchPage` con parámetros `kinds: List<String>?` (lista, en vez de `kind: String?` que queda deprecado o eliminado) y `categoryIds: List<String>?`. Mantener `from`, `to`, `accountId`, `limit`.
- **RF-002**: en el query SQL, traducir `kinds` a `WHERE kind IN (?, ?, ...)` cuando la lista tiene ≥1 elemento. Si lista vacía o null → sin filtro de kind.
- **RF-003**: traducir `categoryIds` a SQL: si incluye el token `__null__`, generar `WHERE (category_id IN (...) OR category_id IS NULL OR category_id IN (SELECT id FROM categories WHERE deleted_at IS NOT NULL))`. Si no incluye `__null__`, solo `WHERE category_id IN (...)`. Si lista vacía o null → sin filtro de categoría.
- **RF-004**: definir constante `kUncategorizedFilterToken = '__null__'` accesible desde DAO + UI.
- **RF-005**: agregar campos opcionales `kinds: List<String>?` y `categoryIds: List<String>?` al método `EntriesDao.watchPage`. Mantener compatibilidad con tests existentes que pasan `kind: String?` (deprecar gradualmente o adaptar).
- **RF-006**: crear `lib/screens/entries_filters_screen.dart` con `Scaffold` + `AppBar` ("Filtros" + botón X cerrar) + body scrollable con 4 secciones + footer fijo ("Limpiar todo" + "Aplicar").
- **RF-007**: sección "Fecha" del panel: reusar `ReportRangePreset` chips del helper `lib/screens/reports/range_presets.dart`. Si el preset es Custom, mostrar dos `_DateFieldOutlined` (también extraídos de `spending_by_category_tab.dart` o reusados). Default al abrir: `ReportRangePreset.thisMonth`.
- **RF-008**: sección "Tipo" del panel: chips. Opciones (en orden): Todos / Ingreso / Gastos / Pago de tarjeta / Transferencia. Selección única (radio-like). "Gastos" mapea a `kinds = ['expense', 'credit_expense']`; los otros a single kind. "Todos" desactiva el filtro.
- **RF-009**: sección "Cuenta" del panel: chips inline scrollables horizontalmente. Cada chip muestra icono + nombre. Single-select. "Todas" como chip al inicio para desactivar.
- **RF-010**: sección "Categorías" del panel: chips multi-select con badge (color slug + icon slug). Primer chip especial "Sin categoría" (icono `label_off_outlined`, color gris). Resto son las categorías activas ordenadas alfabético. Tap toggle del chip.
- **RF-011**: footer del panel: dos botones lado a lado. "Limpiar todo" (outlined, secundario) resetea TODOS los filtros al default (Este mes + Todos + Todas las cuentas + ninguna categoría) sin cerrar el panel. "Aplicar" (filled, accent) cierra el panel con los filtros activos.
- **RF-012**: extender `EntriesListScreen` para aceptar query params del router: `from`, `to`, `kinds` (csv), `categoryIds` (csv), `accountId`. Al montar, si hay query params, pre-cargar el estado del filtro.
- **RF-013**: registrar la ruta `/entries` para que acepte query params nativamente con `go_router`. Hoy ya soporta `/entries` sin params; solo verificar que el `GoRoute` permita query strings.
- **RF-014**: mostrar chips de "Filtros activos" arriba de la lista de movimientos. Cada chip tiene "X" tappeable. Tap remueve solo ese filtro (no abre el panel completo). Lista de chips: 1 por dimensión activa (fecha, tipo, cuenta, categorías → categorías muestra 1 chip por categoría seleccionada hasta max 3 visible + "+N más").
- **RF-015**: cambiar el botón actual de "Filtros" en el AppBar de `EntriesListScreen` por un `IconButton` con `Icons.tune` + badge numérico con el conteo de dimensiones activas.
- **RF-016**: agregar `onTap` al `_SpendingBucketRow` en `spending_by_category_tab.dart`. El tap navega a `/entries` con query params construidos según RN-M08.
- **RF-017**: deprecar (o eliminar) el parámetro `kind: String?` de `watchPage` reemplazándolo por `kinds: List<String>?`. Actualizar todos los callers (Dashboard, EntriesListScreen, BackupService si aplica, tests existentes).
- **RF-018**: extraer `ReportRangePreset` + `reportRangeForPreset` de `lib/screens/reports/range_presets.dart` a `lib/constants/date_range_presets.dart` (carpeta neutral). Renombrar a `DateRangePreset` y `dateRangeForPreset` para reflejar que ya no es exclusivo de reportes. Actualizar imports en `spending_by_category_tab.dart` y nuevo panel de filtros. Mantener tests existentes verdes.
- **RF-019**: extraer `_DateFieldOutlined` de `spending_by_category_tab.dart` a `lib/widgets/date_field_outlined.dart` (M8 del quality review v1 de `flutter-reports-v1`).
- **RF-020**: tests data del DAO con los nuevos filtros (`kinds`, `categoryIds`, `categoryIds con __null__`, combinaciones).
- **RF-021**: widget tests del nuevo panel: render de las 4 secciones, tap en chip aplica filtro, "Limpiar todo" resetea, "Aplicar" cierra con filtros, deep link pre-carga estado.
- **RF-022**: widget test del flujo end-to-end del deep link desde el reporte: render `/reports`, tap en bucket, validar navegación a `/entries` con la lista filtrada correctamente.
- **RF-023**: bump versión a `0.5.0+47`. Build APK + verify-apk.sh.

## Casos principales

- **C-01**: Diego abre `/entries`, tappea el icono `tune` del AppBar, el panel abre **en <200ms** (vs >500ms hoy). Ve las 4 secciones, selecciona "Mes pasado" + "Gastos" + categoría "Comida". Tap "Aplicar". La lista se filtra a los gastos de comida del mes anterior.
- **C-02**: Diego abre `/reports`, ve que "Comida" lidera con $4,200. Tap en el bucket. Navega a `/entries` con filtros pre-cargados (fecha del reporte + categoría Comida + tipo Gastos). Ve la lista de los movimientos que componen ese total.
- **C-03**: Diego tiene filtros activos (chips arriba de la lista). Tap en "X" del chip de fecha. Solo el filtro de fecha se elimina, los otros (categoría, tipo) se mantienen.
- **C-04**: Diego selecciona 3 categorías en el panel (Comida, Transporte, Salud). Aplica. La lista muestra movimientos de las 3 categorías combinadas.
- **C-05**: Diego abre el panel ya con filtros aplicados (vino de una sesión anterior). Ve los chips marcados. Modifica solo la fecha. Aplica. Los demás filtros se mantienen.
- **C-06**: Diego tap en el bucket "Sin categoría" del reporte. Navega a `/entries` con `categoryIds = ['__null__']` + fecha + tipo Gastos. Ve solo los movimientos sin categoría (incluye los con categoría archivada).

## Casos borde

- **CB-01**: filtro vacío en una dimensión = sin restricción (no = resultados vacíos). Ej. `kinds = null` o `kinds = []` → sin filtro de tipo.
- **CB-02**: filtro de categorías con TODAS las categorías seleccionadas + "Sin categoría" → equivalente a sin filtro. UI puede simplificar mostrando "Todas" en lugar de listar 11 chips.
- **CB-03**: deep link con `kinds` inválidos (ej. el usuario manipula la URL): el DAO ignora los inválidos silenciosamente (CHECK constraint a nivel SQL no aplica porque kind es TEXT libre; validamos en Dart con el catálogo de kinds).
- **CB-04**: deep link con `categoryIds` que apuntan a categorías archivadas: la query incluye archivadas vía RN-M03, así que matchea correctamente. Histórico preservado.
- **CB-05**: deep link sin query params → comportamiento default actual (lista sin filtrar más allá del `limit: 200`).
- **CB-06**: tap rápido en múltiples chips de categorías antes de "Aplicar" → el state interno del panel actualiza incremental sin freezar. Solo al "Aplicar" se ejecuta la query nueva.
- **CB-07**: tap en "Limpiar todo" → resetea fecha a "Este mes" (no a "sin filtro"). El default tiene un filtro de fecha. Decisión: "Limpiar" = volver al default, no quitar TODO.
- **CB-08**: cuenta archivada en filtro: si Diego filtró por una cuenta y luego la archivó, al reabrir el panel el chip de esa cuenta no debería aparecer (archivada). Decisión: si el accountId actual del filtro apunta a cuenta archivada, se ignora silenciosamente al reabrir.
- **CB-09**: navegar a `/reports` desde un `/entries` con filtros activos: los filtros de `/entries` NO se propagan al reporte. El reporte tiene su propio rango independiente.
- **CB-10**: rango Custom con `from > to`: la UI ya valida via `showWarningSnackbar` (RF-012 del reporte). Mismo patrón.
- **CB-11**: lista con 0 resultados tras aplicar filtros → estado vacío específico ("No hay movimientos con esos filtros. Probá ajustarlos.") en vez del estado vacío genérico.

## Criterios de aceptación

- **CA-01**: el panel de filtros abre en <200ms tras tappear el icono `tune` (medido con `Stopwatch` en debug o por observación cualitativa de Diego en el cel).
- **CA-02**: las 4 secciones renderizadas correctamente con sus chips/inputs.
- **CA-03**: aplicar filtros y cerrar el panel actualiza la lista al instante (el Stream del DAO emite el nuevo resultado).
- **CA-04**: tap en bucket del reporte navega a `/entries` con filtros visibles arriba de la lista y la lista ya filtrada.
- **CA-05**: tap en "X" de un chip de filtro activo en `/entries` elimina solo ese filtro.
- **CA-06**: filtro "Gastos" muestra `expense + credit_expense` y ningún otro.
- **CA-07**: filtro de categorías multi-select muestra entries de TODAS las seleccionadas (OR entre categorías, AND con otros filtros).
- **CA-08**: deep link con `categoryIds=__null__` muestra entries sin categoría + con categoría archivada (RN-M03).
- **CA-09**: `flutter test` queda en verde con los tests nuevos sumando al total actual (168 → 180+ esperado).
- **CA-10**: `flutter analyze` queda en 0 errores y 0 warnings.
- **CA-11**: `scripts/verify-apk.sh` exit 0 con `versionCode` consistente con `0.5.0+47`.

## Criterios medibles de éxito

- **CME-01**: cobertura nueva mínima — 8+ tests data del DAO con filtros combinados + 6+ widget tests del nuevo panel + 2+ widget tests del deep link.
- **CME-02**: suite total post-sprint ≥ 184 tests verdes (168 actual + 16 nuevos mínimo).
- **CME-03**: tiempo de respuesta del filtro aplicado ≤ 100ms con 1000 entries en BD in-memory (medido en test ad-hoc).
- **CME-04**: el modal de filtros abre **subjetivamente "rápido"** (sin lag perceptible) en el Redmi, validado por Diego en el smoke.
- **CME-05**: Diego puede responder *"¿cuánto gasté en Comida el mes pasado?"* en ≤ 4 tappeos desde el Dashboard (abrir Reportes → ver bucket Comida del mes pasado → tap → ver lista filtrada).

## Riesgos

- **R-01**: el cambio de `kind: String?` a `kinds: List<String>?` en `watchPage` rompe compatibilidad con tests existentes (`entries_list_screen_test.dart` y otros). Mitigación: actualizar callers + dejar wrapper temporal `kind` que internamente arma `kinds = [kind]` durante la migración. Documentar y deprecar en el siguiente sprint.
- **R-02**: el filtro de categorías con multi-select + token `__null__` complica la query SQL. Riesgo de bug en el OR. Mitigación: tests data extensivos (CB-04, RN-M03).
- **R-03**: pantalla casi completa de filtros puede sentirse "pesada" para casos simples (Diego solo quiere filtrar por kind). Mitigación: el panel arranca con el default ya configurado; tap en "Aplicar" cierra inmediatamente sin scroll.
- **R-04**: el deep link con muchos query params puede generar URLs largas que rompan parsers de go_router. Mitigación: usar csv comprimido para `kinds` y `categoryIds`; validar parse en tests.
- **R-05**: paginación queda fuera de scope pero `limit: 200` puede degradar con 5000+ entries. Mitigación: documentado en Supuestos como condición de re-activación.
- **R-06**: extraer `ReportRangePreset` a `lib/constants/` cambia imports en 2 lugares + tests. Riesgo de regresión. Mitigación: hacer el rename en commit aislado dentro del sprint, correr suite tras el cambio.

## Supuestos

- **S-01**: hoy con <500 entries el `limit: 200` es suficiente. Paginación se diferirá hasta que la lista degrade visiblemente. Se activará en sprint dedicado cuando aparezca el caso real.
- **S-02**: Diego usa <10 categorías activas y <5 cuentas en uso típico. El panel con chips inline rinde sin scroll horizontal hasta esos números. Si crece, se evalúa scroll vertical o búsqueda inline.
- **S-03**: single-select de cuenta es suficiente. Si surge necesidad de multi-account, sprint futuro.
- **S-04**: el filtro de tipo "Gastos" combinado es la única combinación predefinida que vale agregar. Otras combinaciones (ej. "Cuentas internas" = transfer + debt_payment) no se piden hoy. Sprint futuro si emerge necesidad.
- **S-05**: el modal a pantalla completa es la solución de UX correcta. Si Diego en el smoke siente que es "demasiado", reevaluamos en sprint patch.
- **S-06**: la firma del query del DAO con `kinds`/`categoryIds` queda preparada para `offset` futuro sin refactor.
- **S-07**: la lentitud actual del modal se debe principalmente al `DropdownMenu<String>` que prerenderea items (descubierto en DV-1 del sprint `flutter-ui-test-coverage-v1`). Eliminarlo del filtro debería resolver el problema. Si no es la causa raíz, el sprint debe diagnosticar más profundo.
- **S-08**: el extract de `ReportRangePreset` a `lib/constants/` es seguro porque solo lo usa hoy `spending_by_category_tab.dart`. Sin riesgos cross-feature.

## Impacto esperado

- **Producto**: nuevos flujos comunes vuelven 4 tappeos (reporte → drill-down) en vez de 7-8 (reporte → ir a entries → abrir filtros → configurar 3 dimensiones manualmente → aplicar). El modal de filtros deja de ser un "candado lento" y se vuelve una herramienta rápida.
- **Código**:
  - Modificado: `lib/data/daos/entries_dao.dart` (~30 líneas extra para multi-kind + multi-cat).
  - Modificado: `lib/screens/entries_list_screen.dart` (~50 líneas: query params del router + chips de filtros activos + nuevo botón AppBar).
  - Nuevo: `lib/screens/entries_filters_screen.dart` (~350 líneas estimadas).
  - Nuevo: `lib/widgets/date_field_outlined.dart` (~50 líneas, extracted).
  - Renombrado: `lib/screens/reports/range_presets.dart` → `lib/constants/date_range_presets.dart` (~80 líneas, sin cambios funcionales).
  - Modificado: `lib/screens/reports/spending_by_category_tab.dart` (~10 líneas: imports actualizados + onTap en bucket).
  - Modificado: `lib/router/app_router.dart` (~5 líneas: declarar la nueva ruta del panel o ajustar query params).
  - Tests nuevos: ≥16 (8 data + 6 widget panel + 2 deep link).
- **Compatibilidad**: aditivo en data layer (DAO acepta nuevos params opcionales). No hay schema bump. Backup JSON v1 sin cambios.
- **Sucesor**: deja el helper `dateRangeForPreset` neutralizado para que cualquier futuro sprint con filtro de fecha (cashflow, saldo a fecha) lo reuse.
