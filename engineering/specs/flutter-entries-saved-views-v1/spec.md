# Vistas guardadas de filtros en `/entries`

## Resumen

Agregar **vistas guardadas** al panel de filtros de `/entries`. Diego
puede tomar la combinación actual de filtros (fecha + tipo + cuenta +
categoría + monto) y persistirla con un nombre custom. Después aplica
una vista guardada con un tap para repetir el filtro sin reconfigurar.

CRUD completo: crear, listar, aplicar, renombrar, eliminar. **Schema
bump** con tabla nueva `saved_views` (UUID v7, name, filters JSON
serializado, created_at). Sin tocar la lógica de filtros existente —
solo agrega capa de persistencia.

## Problema a resolver

Cada vez que Diego quiere ver "gastos > $500 del mes pasado en
categoría Comida", tiene que abrir filtros, configurar las 4
dimensiones y aplicar. Si lo hace varias veces por mes, la fricción
es alta.

Las vistas guardadas convierten una combinación frecuente en un tap.

## Objetivo

Que Diego pueda:

1. Configurar filtros en el panel.
2. Tap "Guardar vista" → ingresar nombre custom → vista persistida.
3. Después abrir el panel de filtros → ver dropdown "Mis vistas" →
   tap en una vista → filtros aplicados.
4. Renombrar o eliminar vistas guardadas.

## Alcance

- Schema bump (versión 2 → 3) con tabla nueva `saved_views`.
- Migración aditiva en `MigrationStrategy.onUpgrade` (no destructiva).
- Nuevo DAO `SavedViewsDao` con CRUD.
- Nuevo modelo `SavedView` (id, name, filters serializados, createdAt).
- Serialización/deserialización de `EntriesFilters` a JSON.
- UI: dropdown "Mis vistas" + botón "Guardar vista" (decisión P-002).
- Dialog para nombre custom al guardar.
- Long-press en una vista del dropdown → opciones renombrar / eliminar
  (o menú contextual via icono ⋮).
- Confirmación al eliminar.
- Tests data del DAO + tests del modelo + widget tests.

## Fuera de alcance

- Compartir vistas entre usuarios (single-user).
- Vistas predefinidas del sistema (ej. "Gastos del mes" preconfigurada).
- Reordenar vistas manualmente (orden = `created_at DESC` fijo).
- Iconos/colores custom por vista.
- Export/import de vistas en el backup JSON (sprint dedicado si se
  pide).
- Limitar la cantidad de vistas guardadas (sin tope; single-user).
- Indicador "última vez aplicada" en cada vista.
- Vista activa "marcada" en la UI (no hay estado "vista actualmente
  aplicada"; aplicar = setear filtros, después Diego puede modificarlos
  y la vista no se actualiza automáticamente).

## Reglas de negocio

- **RN-V01**: tabla `saved_views` con columnas:
  - `id` TEXT PK (UUID v7).
  - `name` TEXT NOT NULL (max 50 chars).
  - `filters_json` TEXT NOT NULL (JSON serializado del
    `EntriesFilters`).
  - `created_at` DATETIME NOT NULL.
  - **Sin** `deleted_at` (las vistas se borran físicamente, no soft —
    no son datos críticos).
- **RN-V02**: `name` debe tener entre 1 y 50 caracteres trimmed. Vacío
  o solo espacios → rechazado con error `invalid_name`.
- **RN-V03**: `name` duplicado (case-insensitive, trimmed) → rechazado
  con error `duplicate_name`. Como single-user, es seguro asumir que
  Diego no quiere "Comida" y "comida" como vistas distintas.
- **RN-V04**: serialización híbrida (decisión P-001):
  - Si el preset al guardar era semántico (`thisMonth`/`lastMonth`/
    `thisYear`): JSON guarda `{datePreset: 'this_month'}` SIN from/to.
    Al aplicar, se recalcula con `dateRangeForPreset(preset,
    DateTime.now())` → rolling.
  - Si el preset era `custom`: JSON guarda
    `{datePreset: 'custom', from: ISO8601, to: ISO8601}` → fijo.
- **RN-V05**: cuando Diego aplica una vista, los filtros se setean
  exactamente como estaban al guardar (con la salvedad del preset
  rolling — P-001).
- **RN-V06**: si una vista referencia un `accountId` o `categoryId`
  que ya no existe (cuenta archivada o categoría archivada), la vista
  se aplica con el ID huérfano. El panel ya soporta esto mostrando
  "(archivada)" en el chip de filtros activos (sprint anterior).
- **RN-V07**: orden de las vistas en el dropdown = `created_at DESC`
  (las más recientes arriba).
- **RN-V08**: no hay vista "activa" en el sentido de estado
  persistente. Aplicar = setear filtros. Si Diego modifica los
  filtros después, la vista no cambia.
- **RN-V09**: eliminar una vista requiere confirmación (`showConfirmDialog`
  existente).
- **RN-V10**: backup JSON v1 NO incluye `saved_views`. Las vistas son
  preferencias de UI, no datos del journal. Si se importa un backup, las
  vistas locales se mantienen. Si se hace wipeAll, las vistas también se
  borran (consistente con el "arrancar limpio").

## Requisitos funcionales

- **RF-001**: tabla `saved_views` agregada a `lib/data/database.dart`
  con `schemaVersion = 3`.
- **RF-002**: migración 2 → 3 en `onUpgrade` que ejecuta
  `m.createTable(savedViews)`.
- **RF-003**: `SavedViewsDao` expone:
  - `Future<String> create({required String name, required
    EntriesFilters filters})` retorna el id v7.
  - `Future<List<SavedView>> listAll()` ordenado por created_at DESC.
  - `Stream<List<SavedView>> watchAll()` para reactividad UI.
  - `Future<void> rename({required String id, required String name})`.
  - `Future<void> delete({required String id})`.
  - `Future<SavedView?> findById(String id)`.
- **RF-004**: errores tipados (`SavedViewsDaoError`):
  - `invalid_name`: name vacío o > 50 chars.
  - `duplicate_name`: name ya existe (case-insensitive).
  - `not_found`: id no existe.
- **RF-005**: `EntriesFilters.toSavedJson()` y
  `EntriesFilters.fromSavedJson(Map)` para serializar/deserializar.
  Diferencia con `serialize()`/`parse()` existentes: estos son para
  query params (formato URL); el nuevo es JSON estructurado para
  almacenar en BD.
- **RF-006**: nuevo modelo `SavedView({id, name, filters, createdAt})`.
- **RF-007**: UI híbrida (decisión P-002):
  - **Guardar**: botón "Guardar vista" dentro del panel de filtros
    (`EntriesFiltersScreen`), debajo de la última sección antes del
    bottom bar.
  - **Aplicar/Renombrar/Eliminar**: icono nuevo de bookmark
    (`Icons.bookmark_outline`) en el AppBar de `EntriesListScreen`,
    al lado del icono de filtros. Tap abre dropdown/menú con la
    lista. Cada item con menú ⋮ para acciones.
- **RF-008**: dialog "Guardar vista" con `TextFormField` para nombre
  + botones Cancelar/Guardar.
- **RF-009**: dialog "Renombrar vista" con `TextFormField` pre-llenado
  + botones Cancelar/Guardar.
- **RF-010**: confirmación al eliminar (`showConfirmDialog` con
  `destructive: true`).
- **RF-011**: error_snackbar mapea los códigos tipados a mensajes
  amigables en español:
  - `invalid_name` → "El nombre no es válido. Probá con 1-50 caracteres."
  - `duplicate_name` → "Ya tenés una vista con ese nombre."
  - `not_found` → "Esa vista ya no existe."
- **RF-012**: si no hay vistas guardadas, el dropdown muestra empty
  state inline ("No tenés vistas guardadas todavía.").

## Casos principales

- **CP-1 — Guardar vista nueva**: Diego configura filtros, tap
  "Guardar vista", ingresa "Gastos comida del mes pasado", tap
  Guardar → vista persistida.
- **CP-2 — Aplicar vista existente**: Diego abre dropdown "Mis
  vistas" → tap en "Gastos comida del mes pasado" → filtros aplicados
  + lista refresca.
- **CP-3 — Renombrar vista**: long-press (o menú) en la vista →
  "Renombrar" → cambiar nombre → guardar.
- **CP-4 — Eliminar vista**: long-press (o menú) en la vista →
  "Eliminar" → confirmar → vista borrada.
- **CP-5 — Combinar con filtros manuales**: aplicar vista, después
  agregar/quitar dimensiones manualmente. La vista NO se actualiza
  automáticamente (es snapshot).

## Casos borde

- **CB-1 — Nombre vacío**: rechazado con `invalid_name`.
- **CB-2 — Nombre > 50 chars**: rechazado.
- **CB-3 — Nombre con espacios externos**: trim antes de validar y
  guardar.
- **CB-4 — Nombre duplicado**: rechazado con `duplicate_name`.
  Case-insensitive ("Comida" == "comida").
- **CB-5 — Vista con cuenta archivada**: se aplica con `accountId`
  huérfano. Panel muestra chip "Cuenta (archivada)" (sprint anterior).
- **CB-6 — Vista con categoría archivada**: idem CB-5 con
  "Categoría (archivada)".
- **CB-7 — Aplicar vista sin filtros (todos default)**: válido. La
  vista guarda el "estado default" y aplicarla resetea filtros.
- **CB-8 — wipeAll (Settings → Reiniciar cuenta)**: borra también las
  vistas guardadas (RN-V10).
- **CB-9 — Import de backup**: las vistas locales NO se modifican
  (no están en el backup v1, RN-V10).
- **CB-10 — Concurrencia**: 2 vistas con el mismo nombre creadas
  desde la app en milisegundos. La transacción del DAO valida la
  unicidad case-insensitive antes del insert. Probabilidad
  prácticamente nula en single-user.
- **CB-11 — Vista con preset `thisMonth` aplicada en otro mes**: si
  P-001 = preset semántico, ajusta al mes corriente. Si P-001 = rango
  fijo, mantiene el rango del momento de guardado.

## Criterios de aceptacion

- En el panel de filtros (o AppBar según P-002) aparece la UI de
  vistas guardadas.
- Botón "Guardar vista" abre dialog → ingresar nombre → vista
  persistida.
- Dropdown muestra todas las vistas ordenadas por created_at DESC.
- Tap en una vista aplica los filtros instantáneamente.
- Renombrar y eliminar funcionan con confirmación.
- Cerrar la app y reabrir → las vistas persisten.
- Empty state visible cuando no hay vistas guardadas.
- Validación de nombre (1-50 chars, no duplicado) con snackbar
  amigable si falla.
- `flutter test` sigue verde tras los tests data + widget tests
  nuevos.

## Criterios medibles de exito

- **CM-01**: 8+ tests data del `SavedViewsDao`:
  - 1 test create + listAll.
  - 1 test create + findById.
  - 1 test rename.
  - 1 test delete.
  - 1 test duplicate_name rechazado (case-insensitive).
  - 1 test invalid_name (vacío y > 50 chars).
  - 1 test orden created_at DESC.
  - 1 test watchAll reactivo (insert → emite).
- **CM-02**: 3+ tests del serializer:
  - round-trip toSavedJson/fromSavedJson preserva todos los campos.
  - parse de JSON corrupto → fallback default (thisMonth).
  - filtros con preset `custom` → preservan from/to exactos.
- **CM-03**: 3+ widget tests del UI:
  - Guardar vista nueva desde el panel.
  - Aplicar vista existente.
  - Empty state cuando no hay vistas.
- **CM-04**: 0 errores `flutter analyze`.
- **CM-05**: APK release `0.10.0+62` validado por `verify-apk.sh`.
- **CM-06**: schema migration 2 → 3 testeada con un test que crea
  BD en versión 2 y verifica que la migración crea la tabla nueva.

## Riesgos

- **R-01** (medio): primer schema bump del proyecto local-first. Si
  la migración falla, riesgo de corrupción de datos. Mitigación:
  test de migración (CM-06) + migración aditiva no destructiva.
- **R-02** (bajo): JSON serializado en BD es más propenso a evolución
  conflictiva. Si el schema de `EntriesFilters` cambia (ej. agregar
  filtro de prioridad), las vistas viejas pueden no deserializar
  bien. Mitigación: `fromSavedJson` tolerante a campos faltantes con
  defaults. Documentar en doc-comment del método.
- **R-03** (bajo): backup JSON v1 NO incluye `saved_views`. Si Diego
  hace export → wipeAll → import, **pierde las vistas**. Documentado
  en RN-V10. Si en el futuro es problema, sprint dedicado para
  incluir vistas en el backup v2.
- **R-04** (bajo): UX del long-press / menú contextual puede no ser
  descubrible. Mitigación: icono ⋮ visible al lado de cada vista en
  el dropdown.

## Supuestos

- **`schemaVersion` bump de 2 a 3** (primer bump del MVP local).
- **Tabla con `created_at` DateTime** estándar drift.
- **Sin `updated_at`** (la única edición es `rename` que actualiza
  `name`; no necesitamos timeline de cambios).
- **Sin `deleted_at`**: las vistas se borran físicamente. No son
  datos críticos.
- **Sin límite de cantidad de vistas**: single-user de baja escala.
- **JSON serialization**: híbrida (decisión P-001) — preset semántico
  se guarda como slug rolling, custom se guarda como rango fijo
  ISO8601.
- **Lugar de la UI**: híbrido (decisión P-002) — guardar dentro del
  panel, aplicar/renombrar/eliminar desde icono bookmark en AppBar.
- **Nombre case-insensitive para duplicate check** pero **case-sensitive
  para mostrar** (Diego escribe "Comida" → se guarda y muestra
  "Comida", pero no puede crear "comida" después).

## Impacto esperado

- **Producto**: convierte combinaciones frecuentes de filtros en un
  tap. Reduce fricción de uso.
- **Schema**: primer bump del MVP. Establece patrón para futuros.
- **Código**: nuevo DAO ~100 líneas + nuevo widget ~150 líneas +
  modificaciones al panel ~50 líneas. Tabla nueva ~10 líneas en
  `database.dart`.
- **Tests**: +8 DAO + 3 serializer + 3 widget = ~293 verdes post.
- **APK size**: cero impacto.
- **Sin regresión** esperada en el panel de filtros existente.
