# Presupuestos semanales (planeador anticipado)

## Resumen

Nuevo módulo standalone de planificación semanal. Diego arma con
anticipación qué va a hacer con la plata de una semana concreta:
renglones de ingreso esperado (ej: "Sueldo del viernes") + renglones
de gasto planeado ("Deuda A", "Gasolina"), cada uno con nombre libre,
monto y categoría opcional. La UI muestra el balance del presupuesto
(ingresos − gastos = sobrante) para responder "cuánto me sobra" o
"cuánto me falta" **antes** de que la semana arranque.

Se pueden armar **varios planes por la misma semana** ("Conservador",
"Optimista") para comparar escenarios. Se pueden guardar **plantillas**
derivadas de un presupuesto existente para reutilizarlas semana a
semana sin re-tipear todo.

En esta primera parte NO se vincula a los movimientos reales del
ledger. Es planificación pura: la BD nueva no se toca con
`EntriesDao`. La comparativa "planeado vs ejecutado" queda para un
sprint futuro (`flutter-weekly-budgets-vs-actuals-v1` o similar).

Distinto y complementario del sprint `flutter-budgets-v1`
(presupuestos mensuales por categoría, tab dentro de `/reports`).
Ambos coexisten sin superponerse: el mensual mide "no gastar más de
$X en Comida al mes"; el semanal responde "esta semana con mis
$6500 alcanza para todo".

## Problema a resolver

A Diego le pagan cada viernes. Quiere planificar de antemano cómo
distribuir el ingreso semanal (deuda A, deuda B, gasolina, comida,
etc.) para no hacer mental math cuando llega el momento y saber
desde antes si le va a sobrar o faltar plata. También quiere poder
armar escenarios ("y si gasto menos en X, cuánto me sobra") sin
perder los planes anteriores.

Hoy la app solo cubre lo **ya ocurrido** (`journal_entries`) y el
gasto mensual por categoría (`monthly_limit`). No hay lugar para
**planificar** una semana concreta con renglones ad-hoc ("$1000 para
Deuda Juan" — que ni siquiera es una categoría — o "$500 gasolina
del sábado").

Sin esta funcionalidad Diego usa papel o memoria. El objetivo del
sprint es que la app absorba ese paso de planificación con la
mínima fricción y quede como la única fuente de verdad de "qué
pensaba hacer esta semana".

## Objetivo

1. Modelo de datos nuevo (`weekly_budgets` + `weekly_budget_items` +
   `budget_templates` + `budget_template_items`) independiente del
   ledger. UUID v7, hard delete, timestamps.
2. Preferencia global `week_start_dow` (día de inicio de la semana,
   ej: viernes) en `AppPreferences`. Solo es un default sugerido
   para el picker; no impone restricción dura al crear un
   presupuesto.
3. Pantalla nueva `/budgets` con listado de presupuestos por semana
   (actual, próximas, pasadas) + entrada al form del presupuesto
   activo/seleccionado.
4. Form de presupuesto: header con la semana ("Viernes 17 → Jueves
   23") + label obligatorio + lista editable de renglones (nombre,
   categoría opcional, monto, kind income/expense) reordenable por
   drag&drop con handle + balance en vivo al final ("Sobra $X" /
   "Faltan $Y" / "En equilibrio").
5. Sección de plantillas: crear plantilla derivada de un presupuesto
   existente + aplicar plantilla al crear un presupuesto nuevo +
   CRUD de plantillas.
6. Entrada de configuración en `/settings` para el día de inicio.
7. Suite de tests (DAO, servicio si hay, widgets clave).
8. Sin regresión en el resto de la app (ledger, reportes, backup).

## Alcance

- **Nuevas tablas drift**:
  - `weekly_budgets`: `id` (uuid v7 PK), `week_start_date` (DATE
    tipada — el viernes o el día que sea), `label` (TEXT NOT NULL,
    1..60 chars), `created_at`, `updated_at`. **Sin** `deleted_at`
    (hard delete).
  - `weekly_budget_items`: `id` (uuid v7 PK), `budget_id` (FK a
    `weekly_budgets.id`, ON DELETE CASCADE), `name` (TEXT NOT NULL,
    1..60 chars), `category_id` (FK a `categories.id`, nullable),
    `amount` (REAL NOT NULL, > 0), `kind` (TEXT NOT NULL,
    `income`/`expense`), `sort_order` (INT NOT NULL, para orden
    manual), `created_at`, `updated_at`. **Sin** `deleted_at`.
  - `budget_templates`: `id` (uuid v7 PK), `name` (TEXT NOT NULL,
    1..60 chars, único activo), `created_at`, `updated_at`. **Sin**
    `deleted_at`.
  - `budget_template_items`: `id` (uuid v7 PK), `template_id` (FK a
    `budget_templates.id`, ON DELETE CASCADE), `name` (TEXT NOT NULL,
    1..60 chars), `category_id` (FK a `categories.id`, nullable),
    `amount` (REAL NOT NULL, > 0), `kind` (TEXT NOT NULL,
    `income`/`expense`), `sort_order` (INT NOT NULL), `created_at`,
    `updated_at`. **Sin** `deleted_at`.
- **Setting nuevo**: clave `week_start_dow` en `AppPreferences`
  (valor string `'1'`..`'7'` — 1=Lunes, 7=Domingo, ISO 8601).
  Default = `'5'` (viernes).
- **Schema bump**: v6 → v7. Rama de migración aditiva
  (`CREATE TABLE` × 4 + índices por `week_start_date` y por
  `budget_id`/`template_id`). Preservar el guardrail
  `UnimplementedError` post-if-chain.
- **DAO nuevo `WeeklyBudgetsDao`**:
  - `createBudget({DateTime weekStartDate, required String label})`.
  - `updateBudget(id, {label})` — no permite mover `week_start_date`
    (`immutable_field` para preservar la semántica del rango).
  - `deleteBudget(id)` — **hard delete**. Los items se borran vía
    ON DELETE CASCADE. Requiere confirmación en la UI.
  - `watchAll()`, `findById(id)`, `watchBudget(id)` (con items
    joinados).
  - `addItem({budgetId, name, categoryId?, amount, kind})`.
  - `updateItem(itemId, {name?, categoryId?, amount?, kind?,
    sortOrder?})`.
  - `deleteItem(itemId)` — **hard delete** con confirmación.
  - `reorderItems(budgetId, List<String> orderedItemIds)` —
    renumera `sort_order` en transacción.
  - `watchBudgetBalance(id)` con `readsFrom: {weeklyBudgetItems}`
    para balance reactivo.
  - `createBudgetFromTemplate({DateTime weekStartDate, required
    String label, required String templateId})` — copia snapshot
    de los items de la plantilla al presupuesto nuevo.
- **DAO nuevo `BudgetTemplatesDao`**:
  - `createTemplateFromBudget({String budgetId, required String
    name})` — copia snapshot de los items del presupuesto al
    template. NO comparte referencia; ediciones futuras del
    presupuesto no tocan la plantilla.
  - `updateTemplate(id, {name})`.
  - `deleteTemplate(id)` — **hard delete** con confirmación.
  - `watchAll()`, `findById(id)`, `watchTemplate(id)`.
  - `addTemplateItem`, `updateTemplateItem`, `deleteTemplateItem`,
    `reorderTemplateItems` — mismos patrones que en budgets, para
    permitir editar la plantilla después de creada.
- **Preference DAO**: agregar helpers `weekStartDow()` (default:
  `5` = viernes) y `setWeekStartDow(int)` en `AppPreferencesDao`.
- **Pantalla nueva `WeeklyBudgetsListScreen`**
  (`mobile/lib/screens/weekly_budgets/list_screen.dart`):
  - AppBar "Presupuestos semanales" + IconButton "Plantillas" +
    FAB "+ Presupuesto".
  - Al tap FAB: bottom sheet con 2 opciones: "En blanco" o
    "Desde plantilla" (con selector de plantilla si hay alguna).
  - Lista agrupada por sección: "Esta semana", "Próximas",
    "Pasadas". Card por presupuesto: rango de fechas ("Vie 17 -
    Jue 23"), label (obligatorio), balance ("Sobra $500" /
    "Faltan $200"), cantidad de renglones (`3 ingresos · 5 gastos`).
  - Empty state: "Aún no tenés presupuestos. Armá el primero para
    la semana del viernes 17."
  - Tap en card → `/budgets/:id`.
- **Pantalla del presupuesto `WeeklyBudgetScreen`**
  (`mobile/lib/screens/weekly_budgets/detail_screen.dart`):
  - AppBar con label editable inline + rango de fechas fijo (no
    editable, RN-B09).
  - Sección "Ingresos esperados" (renglones kind=income) con FAB
    contextual "+ ingreso".
  - Sección "Gastos planeados" (renglones kind=expense) con
    "+ gasto".
  - Cada renglón: `[⋮⋮ handle] [nombre] [badge categoría opcional]
    [monto]` + tap → edita, swipe/long-press → borra.
  - **Drag & drop con handle**: mantener presionado el icono
    ⋮⋮ (2 columnas de 6 puntitos) reordena. NO drag desde el row
    completo. Widget: `ReorderableListView` con `buildDefaultDragHandles:
    false` + `ReorderableDragStartListener` alrededor del handle.
  - Footer sticky con balance en tiempo real ("Sobra $500" verde
    / "Faltan $200" rojo / "En equilibrio" gris).
  - Menú del AppBar con:
    - "Crear plantilla desde este presupuesto" → dialog pide nombre
      → crea plantilla → snackbar success.
    - "Eliminar presupuesto" → dialog confirmación destructivo →
      hard delete.
- **Pantalla `BudgetTemplatesScreen`**
  (`mobile/lib/screens/weekly_budgets/templates_screen.dart`):
  - Listado de plantillas activas + card con preview colapsado (los
    primeros N renglones + balance).
  - Tap → detalle editable de la plantilla (misma UI que un
    presupuesto pero sin rango de fechas).
  - Menú del AppBar: "Eliminar plantilla" → confirmación destructiva.
- **Form modal/screen de renglón** `BudgetItemFormSheet`:
  - Reutilizable para renglones de presupuesto y de plantilla.
  - Campo nombre (TextField, 1..60 chars).
  - Selector kind (KindPicker simplificado: income/expense).
  - Campo monto (currency input, > 0).
  - CategoryPicker opcional (sin filtro por `applies_to` — P-003
    laxa).
  - Botón Guardar / Cancelar.
- **Nuevas rutas** en `app_router.dart`:
  - `/budgets` → `WeeklyBudgetsListScreen`.
  - `/budgets/:id` → `WeeklyBudgetScreen`.
  - `/budget-templates` → `BudgetTemplatesScreen`.
  - `/budget-templates/:id` → detalle de plantilla.
  - No colisionan con el tab "Presupuestos" del `/reports`.
- **Entrada desde Dashboard**: nuevo `IconButton` en el AppBar
  (icono `Icons.calendar_month` o similar) que navega a `/budgets`.
- **Entrada desde Settings**: sección nueva "Preferencias" con
  DropdownButton "Día de inicio de la semana" (7 opciones, default
  viernes). Guarda en `AppPreferences` vía `AppPreferencesDao`.
- **Backup JSON**: NO se incluyen las tablas nuevas en esta
  primera parte. Backup queda en `v1` con el shape actual. Los
  presupuestos y plantillas se pierden en cada restore — decisión
  consciente (P-001).
- **Tests**:
  - DAO: schema tables, PRAGMA FK cascade (borrar budget borra
    items; borrar template borra sus items), CRUD, hard delete,
    `immutable_field` en `week_start_date`, invariantes (monto > 0,
    kind válido, name no vacío, label no vacío), `duplicate_template_name`.
  - Servicio/balance: `watchBudgetBalance` reactivo, semántica
    Σ income − Σ expense, empty budget = 0, con solo income = +Σ,
    con solo expense = −Σ.
  - Plantillas: crear plantilla desde presupuesto copia snapshot
    (los items no comparten id ni FK); editar el presupuesto
    original no altera la plantilla; aplicar plantilla al crear
    presupuesto copia snapshot inverso; eliminar plantilla no
    afecta a presupuestos creados desde ella.
  - Backup: round-trip regression (BD con presupuestos y plantillas
    exporta → import → los presupuestos NO reaparecen; accounts +
    categories + entries sí).
  - Widgets: harness monta list_screen con seed, muestra empty
    state, muestra sección "Esta semana", tap crea navegación,
    form valida monto > 0, label obligatorio, drag&drop reordena,
    eliminar dispara dialog.
- **Bump versión**: `0.19.0+93` → `0.20.0+94`. Actualizar
  `pubspec.yaml` + `android/app/build.gradle.kts`.
- **Docs / help**: nuevo bullet en `HelpScreen` explicando (a) la
  diferencia entre presupuestos mensuales por categoría y
  semanales; (b) cómo funcionan las plantillas; (c) que los
  presupuestos NO están en el backup (aceptado como trade-off).

## Fuera de alcance

- Vincular los renglones del presupuesto a movimientos reales del
  ledger. Sin `JournalEntry.budgetItemId`, sin autopoblado.
- Comparativa "planeado vs ejecutado" contra `EntriesDao`. Sprint
  posterior.
- **Exportar/importar presupuestos y plantillas en el backup JSON**
  (P-001 cerrada como NO).
- Notificaciones "arranca la semana el viernes" (no tenemos permisos
  ni motor de notificaciones nativas en Flutter local; requeriría
  otro sprint dedicado).
- Widget de home screen del cel con el balance de la semana actual.
- Card del budget de "esta semana" en el Dashboard (P-006 cerrada
  como NO).
- Compartir presupuesto o plantilla (share sheet).
- Ajustar `week_start_dow` como configuración **por presupuesto**
  individual (decisión ya cerrada: es global).
- Cuenta origen/destino por renglón (decisión ya cerrada: sin
  cuenta).
- Recurrencia automática (crear presupuesto cada viernes sin acción
  del usuario). Las plantillas cubren la mayor parte del pain.
- Multi-currency, tipo de cambio, etc.
- Tab "Presupuestos semanales" dentro de `/reports`. La entrada
  primaria es la ruta top-level `/budgets`, no un reporte.
- Categorías filtradas por `applies_to` como validación **dura** en
  el DAO (P-003 cerrada como laxa).
- Restricción de que `week_start_date` deba caer en el día del
  `week_start_dow` (P-009 cerrada como sugerido, no forzado).

## Reglas de negocio

- **RN-B01 (formato del día de la semana)**: `week_start_dow` usa
  el estándar ISO 8601: `1=Lunes`, `2=Martes`, ..., `7=Domingo`.
  Default = `5` (viernes). Consistente con `DateTime.weekday` de
  Dart.
- **RN-B02 (default del picker de semana en curso)**: dado un `now`
  local, la sugerencia inicial del date picker para "arranque de la
  semana en curso" es el día más reciente cuyo `weekday ==
  week_start_dow`, retrocediendo hasta 6 días. Ej: hoy martes con
  `week_start_dow=5` → el viernes previo. El usuario puede
  cambiar la fecha en el picker; no es forzoso.
- **RN-B03 (rango de la semana)**: cada presupuesto cubre
  `[week_start_date, week_start_date + 7 días)` — 7 días exactos,
  inclusivo del arranque, exclusivo del siguiente. El rango se
  calcula desde la fecha elegida al crear el presupuesto,
  independiente del `week_start_dow` actual.
- **RN-B04 (multi-plan por semana)**: se permiten múltiples
  presupuestos activos con la misma `week_start_date`, cada uno
  con su `label` distinto. Sirven como escenarios comparativos
  ("Conservador", "Optimista"). NO hay error de duplicado por
  fecha.
- **RN-B05 (hard delete)**: `deleteBudget(id)` borra la fila y
  cascade-borra sus `weekly_budget_items` vía FK. Igual
  `deleteTemplate(id)`. Requiere confirmación en la UI ("esto
  borrará el presupuesto y sus N renglones. Esta acción no se
  puede deshacer"). No hay soft delete ni papelera.
- **RN-B06 (renglón del presupuesto)**: `name` obligatorio, 1..60
  chars, no permite whitespace-only. `amount > 0` estricto.
  `kind ∈ {income, expense}`.
- **RN-B07 (categoría en el renglón)**: `category_id` es opcional.
  Si está presente debe apuntar a una categoría activa (no
  archivada, chequeo vía `categoriesDao.findActiveById`). Si la
  categoría se archiva después de crear el renglón, el renglón NO
  se rompe — el badge desaparece del render (mismo patrón que
  `JournalEntry`). La compatibilidad `kind`/`applies_to` NO se
  enforcea (P-003 laxa).
- **RN-B08 (balance de un presupuesto)**: `balance = Σ items(kind=
  income).amount − Σ items(kind=expense).amount`. Positivo = sobra;
  negativo = falta; cero = equilibrio.
- **RN-B09 (immutable `week_start_date`)**: una vez creado el
  budget, `week_start_date` no se puede editar. Cambiar el rango =
  eliminar el actual + crear uno nuevo. Error `immutable_field`
  al intentar update. Aplica también a plantillas: el `name` de
  la plantilla sí es editable pero al aplicarla a un presupuesto
  nuevo la fecha se elige aparte.
- **RN-B10 (cambio de `week_start_dow` NO afecta datos
  existentes)**: si el usuario cambia el día de inicio en Settings,
  los presupuestos existentes conservan su `week_start_date`
  original. Solo cambia el default del picker en el siguiente
  create. Sin dialog de warning ni recalculo. Se acepta que un
  presupuesto viejo del viernes puede quedar visualmente en la
  sección "Pasadas" con el rango original.
- **RN-B11 (sort order)**: `sort_order` es entero, se asigna en
  bloques de 100 al crear (10, 110, 210, ...) para permitir
  reorder intermedio sin renumerar toda la tabla. `reorderItems`
  renumera todos los ids provistos en transacción.
- **RN-B12 (aislamiento del ledger)**: `weekly_budgets`,
  `weekly_budget_items`, `budget_templates` y `budget_template_items`
  son **totalmente independientes** de `journal_entries`. Ningún
  DAO del ledger los toca. `BackupService.wipeAll()` sí los borra
  (formateo total, borra las 4 tablas nuevas también).
- **RN-B13 (backup NO incluye estas tablas)**: el export de
  `BackupService.exportToJson` NO agrega arrays de
  presupuestos/plantillas. El import ignora arrays si estuvieran
  presentes (defensivo). Los presupuestos se pierden en cada
  restore — trade-off aceptado (P-001).
- **RN-B14 (label obligatorio en presupuesto)**: `weekly_budgets.label`
  es NOT NULL con 1..60 chars, no whitespace-only. Sin auto-generación
  ("Presupuesto 1"); el usuario debe elegir un label significativo
  al crear.
- **RN-B15 (plantillas derivadas)**: las plantillas NO se crean
  desde cero. Se derivan de un presupuesto existente vía botón
  "Crear plantilla desde este presupuesto" en el detalle. Al crear,
  se copia snapshot de los items (nuevos `id` en `budget_template_items`).
  El presupuesto original queda intacto y no comparte referencias.
- **RN-B16 (aplicar plantilla)**: al crear un presupuesto "desde
  plantilla", se copia snapshot inverso de los items de la plantilla
  al presupuesto nuevo (nuevos `id` en `weekly_budget_items`). El
  presupuesto y la plantilla NO comparten referencias posteriores.
  Editar la plantilla luego no afecta a presupuestos ya creados
  desde ella, y viceversa.
- **RN-B17 (nombre único de plantilla)**: `budget_templates.name`
  es único entre plantillas activas. Segundo intento con el mismo
  nombre → error `duplicate_template_name`.
- **RN-B18 (edición de plantilla)**: las plantillas son editables
  post-creación (agregar/eliminar/editar sus items, cambiar el
  name). Se accede desde `/budget-templates/:id`.

## Requisitos funcionales

- RF-001: crear un presupuesto para una `week_start_date` con
  `label` obligatorio.
- RF-002: listar presupuestos agrupados por sección ("Esta semana",
  "Próximas", "Pasadas") ordenados por fecha ascendente dentro de
  cada sección (excepto Pasadas: descendente).
- RF-003: ver el detalle de un presupuesto con sus renglones
  separados en "Ingresos esperados" y "Gastos planeados".
- RF-004: agregar un renglón al presupuesto con nombre libre,
  categoría opcional, monto > 0 y kind income/expense.
- RF-005: editar un renglón existente (nombre, categoría, monto,
  kind, sort_order).
- RF-006: eliminar un renglón (hard delete con confirmación).
- RF-007: reordenar renglones dentro de una sección vía drag & drop
  con handle visual (⋮⋮). Solo el handle inicia el gesto de reorder;
  el resto del row abre el edit.
- RF-008: mostrar en el detalle el balance reactivo (Σ income −
  Σ expense) con color y label ("Sobra $X" / "Faltan $Y" / "En
  equilibrio").
- RF-009: configurar el día de inicio de semana global desde
  `/settings` (1..7, ISO). Default = viernes (5).
- RF-010: calcular la sugerencia inicial de `week_start_date` para
  "esta semana" en el picker a partir de `now` local +
  `week_start_dow` (RN-B02).
- RF-011: eliminar (hard delete) un presupuesto completo con dialog
  de confirmación. Cascade a sus renglones.
- RF-012: editar el `label` de un presupuesto sin poder editar el
  `week_start_date` (RN-B09).
- RF-013: soportar múltiples presupuestos activos con la misma
  `week_start_date` (RN-B04) — cada uno con su label distinto.
- RF-014: crear una plantilla desde un presupuesto existente,
  copiando snapshot de sus items (RN-B15).
- RF-015: listar plantillas activas en `/budget-templates` con
  preview de items y balance.
- RF-016: editar una plantilla existente (name + agregar/editar/
  eliminar/reordenar sus items). Aplica RN-B18.
- RF-017: eliminar una plantilla (hard delete con confirmación) sin
  afectar presupuestos ya creados desde ella (RN-B16).
- RF-018: crear un presupuesto nuevo aplicando una plantilla —
  copia snapshot inverso de los items al presupuesto (RN-B16).
- RF-019: FAB del listado con 2 opciones: "En blanco" o "Desde
  plantilla" (esta última deshabilitada si no hay plantillas).
- RF-020: entrada al módulo desde el Dashboard (IconButton en el
  AppBar) y a plantillas desde el listado de presupuestos
  (IconButton en el AppBar del listado).
- RF-021: FAQ del `HelpScreen` con diferencia entre presupuestos
  mensuales por categoría y semanales + cómo funcionan las
  plantillas + advertencia de que los presupuestos no se respaldan.
- RF-022: sección nueva "Preferencias" en `/settings` con
  DropdownButton para el día de inicio.

## Casos principales

- **CP-01 — Crear presupuesto de la próxima semana en blanco**:
  Diego el miércoles arma el presupuesto del viernes que viene. Tap
  FAB → "En blanco" → picker de fecha (sugerido: viernes próximo,
  editable) → escribir label "Sueldo 17" → guardar → navegar al
  detalle vacío.
- **CP-02 — Agregar renglones y ver el balance**: en el detalle,
  agregar "Sueldo del viernes $6500" (income) + "Deuda Juan $1000"
  + "Deuda Camila $2000" + "Gasolina $500" + "Comida $800"
  (expense). Footer sticky muestra "Sobra $2200" en verde reactivo
  tras cada agregado.
- **CP-03 — Reordenar renglones**: arrastrar el handle ⋮⋮ de
  "Gasolina" para ponerlo antes de "Deuda Juan". El orden persiste
  después de cerrar y reabrir la pantalla.
- **CP-04 — Cambiar el día de inicio en Settings**: Diego entra a
  `/settings` → "Preferencias" → cambia de viernes a domingo. Al
  volver a `/budgets`, el picker por default sugiere el próximo
  domingo. Los presupuestos existentes conservan su fecha y su
  rango original.
- **CP-05 — Editar un renglón planeado**: la deuda que era $1000
  ahora es $1200. Tap renglón → editar monto → guardar → balance
  recalcula. Sin tocar journal_entries.
- **CP-06 — Multi-plan por semana**: Diego crea "Sueldo 17 ·
  Conservador" con $4000 en gastos y "Sueldo 17 · Optimista" con
  $6000. Ambos activos, listado los muestra bajo la misma sección
  "Esta semana" con labels distintos.
- **CP-07 — Semana pasada como registro**: Diego revisa la semana
  del viernes 3 → ve que había planeado $6500 ingreso y $5800
  gastos, sobrante planeado $700. Sirve como recordatorio.
- **CP-08 — Eliminar un presupuesto**: menú del AppBar → Eliminar
  → dialog "Esto borrará el presupuesto y sus 5 renglones. Esta
  acción no se puede deshacer." → confirmar → back al listado. Fila
  y renglones desaparecen de la BD (cascade).
- **CP-09 — Crear plantilla desde presupuesto**: en el detalle de
  "Sueldo 17 · Optimista" → menú → "Crear plantilla desde este
  presupuesto" → dialog pide nombre "Sueldo semanal base" → crea
  plantilla con los mismos renglones copiados. Snackbar success.
- **CP-10 — Aplicar plantilla al crear presupuesto**: FAB → "Desde
  plantilla" → seleccionar "Sueldo semanal base" → preview de sus
  renglones → picker de fecha → label "Sueldo 24" → guardar. El
  presupuesto nuevo arranca con los renglones copiados de la
  plantilla, editables sin afectar la plantilla original.
- **CP-11 — Editar plantilla**: entrar a `/budget-templates`,
  seleccionar "Sueldo semanal base", agregar renglón "Ahorro $500".
  Los presupuestos ya creados desde esa plantilla NO se ven
  afectados (snapshot en el momento de aplicar).
- **CP-12 — Eliminar plantilla**: menú del detalle de plantilla →
  Eliminar → dialog confirmación → hard delete. Los presupuestos
  creados desde ella siguen intactos.
- **CP-13 — Restore de backup borra presupuestos**: exportar backup
  → borrar app → reinstalar → import → los presupuestos y
  plantillas NO se recuperan (aceptado como trade-off). Cuentas,
  categorías y movimientos sí. Snackbar en el FAQ / help explica.

## Casos borde

- **CB-01 — Presupuesto sin renglones**: balance = 0. Footer muestra
  "En equilibrio" en gris. Empty state dentro de las 2 secciones
  ("Sin ingresos planeados" / "Sin gastos planeados") con CTA de
  agregar.
- **CB-02 — Presupuesto con solo income**: balance positivo. Label
  "Sobra $X" verde. Realista: Diego arma el presupuesto empezando
  por el ingreso antes de listar gastos.
- **CB-03 — Presupuesto con solo expense**: balance negativo. Label
  "Faltan $Y" rojo.
- **CB-04 — Categoría archivada tras crearse el renglón**: el
  renglón sigue mostrando su `name` libre pero sin badge de
  categoría. No se rompe.
- **CB-05 — Cambio de `week_start_dow` con presupuestos futuros
  existentes**: presupuesto planificado para viernes 24 mientras
  el nuevo día es domingo → el presupuesto conserva su fecha
  original (viernes 24), aparece bajo "Próximas" con rango "Vie
  24 - Jue 30". El picker para uno nuevo por default sugiere
  domingo.
- **CB-06 — Dos presupuestos con misma `week_start_date` y mismo
  label**: RN-B14 no restringe unicidad de label entre presupuestos
  (solo por presupuesto individual). No hay error; la UI muestra
  dos cards idénticos. Documentado como comportamiento aceptado.
  Alternativa (no implementada): validar único por fecha.
- **CB-07 — Renglón con nombre vacío o whitespace-only**: RN-B06
  rechaza con `invalid_item_name`. Form UI valida antes.
- **CB-08 — Renglón con monto 0 o negativo**: RN-B06 rechaza con
  `invalid_item_amount`. Form UI valida antes.
- **CB-09 — Import de backup v1 con presupuestos existentes en la
  BD actual**: el import wipea la BD (contrato "reemplazo total"),
  incluidas las 4 tablas nuevas. Los presupuestos desaparecen sin
  reemplazo (backup no los trae). CP-13.
- **CB-10 — Cambio de zona horaria del dispositivo**: DATE del
  `week_start_date` es local, tipo drift `DateTimeColumn` con la
  config text. Cambiar zona horaria del dispositivo no debería
  recalcular fechas guardadas. Verificar con test o dejar como
  riesgo residual.
- **CB-11 — Categorías con `applies_to = 'both'`**: aceptable en
  renglones de ambos kinds. No bloqueado (P-003 laxa).
- **CB-12 — Categorías con `applies_to = 'income'` en un renglón
  `kind=expense`**: aceptado por el DAO (RN-B07); la UI muestra
  el badge normal, sin advertencia.
- **CB-13 — Presupuesto con >100 renglones**: performance del
  render con `ReorderableListView`. Aceptable en single-user;
  sin paginación por ahora.
- **CB-14 — Renglón con `name` duplicado en el mismo presupuesto**:
  permitido. Diego puede tener "Comida" 3 veces si armó
  presupuesto por día. Sin bloqueo.
- **CB-15 — Aplicar plantilla vacía (0 items)**: se crea un
  presupuesto vacío. Comportamiento equivalente a "en blanco".
- **CB-16 — Plantilla con categoría archivada al momento de
  aplicarla**: el renglón copiado al presupuesto conserva
  `category_id`, pero el badge no se muestra si esa categoría está
  archivada. Sin bloqueo.
- **CB-17 — Eliminar plantilla usada por N presupuestos ya
  creados**: hard delete de la plantilla no toca los presupuestos
  (snapshot copiado, no comparten referencia). CP-11/CP-12
  demuestran.
- **CB-18 — Dos plantillas con mismo `name`**: RN-B17 bloquea con
  `duplicate_template_name`. UI muestra warning.
- **CB-19 — Editar plantilla mientras hay un presupuesto abierto
  creado desde ella**: el presupuesto no se ve afectado
  (RN-B16). El stream del presupuesto tampoco re-emite por cambios
  en `budget_template_items`.
- **CB-20 — Drag & drop desde un row sin usar el handle**: el
  `ReorderableListView` NO inicia reorder (buildDefaultDragHandles:
  false). El tap normal abre el edit del renglón, sin ambigüedad
  con el gesto.

## Criterios de aceptacion

- Crear un presupuesto "en blanco" para `week_start_date =
  <viernes>` con `label = 'Sueldo 17'` guarda 1 fila en
  `weekly_budgets` y navega al detalle vacío.
- Agregar 3 renglones (2 income + 1 expense) con montos 1000, 500,
  300 arroja balance = 1200 renderizado en el footer del detalle
  reactivamente (sin recargar la pantalla).
- Cambiar el día de inicio de semana a domingo desde Settings
  persiste `AppPreferences[key='week_start_dow']='7'`. Al abrir
  `/budgets` y tap FAB → picker por default sugiere el próximo
  domingo. Los presupuestos previos conservan su fecha original.
- Crear presupuesto A y presupuesto B con la misma
  `week_start_date` y labels distintos ("Conservador", "Optimista")
  no arroja error; el listado muestra ambos cards.
- Eliminar un presupuesto con 5 renglones vía dialog de
  confirmación remueve 1 fila de `weekly_budgets` y 5 de
  `weekly_budget_items` (cascade), sin dejar huérfanos.
- Crear plantilla desde un presupuesto con 5 renglones genera 1
  fila en `budget_templates` y 5 en `budget_template_items`. Los
  `id` son distintos a los del presupuesto (snapshot copiado).
- Aplicar plantilla al crear presupuesto genera 1 fila en
  `weekly_budgets` y N filas en `weekly_budget_items` con nuevos
  `id`. Editar la plantilla después NO altera al presupuesto.
- Eliminar plantilla usada por N presupuestos NO afecta a los
  presupuestos ni a sus renglones.
- Reordenar renglones vía drag & drop del handle persiste el nuevo
  `sort_order`. Al cerrar y reabrir el presupuesto se ve el mismo
  orden.
- Intentar crear renglón con `amount = 0` produce
  `invalid_item_amount` bloqueando el submit del form.
- Intentar editar `week_start_date` de un presupuesto existente
  produce `immutable_field` y no persiste el cambio.
- Intentar crear plantilla con nombre ya usado produce
  `duplicate_template_name`.
- Intentar crear presupuesto con `label` vacío produce
  `invalid_budget_label`.
- Exportar backup con 2 presupuestos + 1 plantilla activos y
  luego importar el mismo JSON produce una BD con CERO
  presupuestos y CERO plantillas (accounts + categories +
  entries sí se preservan del backup).
- `flutter analyze` sigue en 0 errores.
- `flutter test` sigue verde: la suite existente pasa sin cambios
  + los tests nuevos.
- Sin regresión en `EntriesDao`, `AccountsDao`,
  `FinancialStateService`, reportes existentes, form de
  movimiento, calendar, heatmap, dashboard.

## Criterios medibles de exito

- Se puede armar un presupuesto de 5 renglones en < 30 segundos
  desde tap en FAB hasta ver el balance.
- Aplicar una plantilla a un presupuesto nuevo con 5 items toma
  < 2 segundos desde tap "Desde plantilla" hasta ver el detalle.
- El balance del footer se actualiza en < 100 ms tras editar el
  monto de un renglón (stream reactivo con `readsFrom`).
- Cambiar el día de inicio de semana en Settings NO afecta las
  fechas ni la data de presupuestos ya guardados; solo cambia el
  default del picker.
- Reordenar 10 renglones vía drag & drop del handle persiste el
  nuevo orden sin renumerar manualmente ni perder datos.
- Diego usa la funcionalidad al menos 1 vez por semana durante 3
  semanas después del release, y crea al menos 1 plantilla
  reutilizable. Métrica cualitativa; medible por follow-up.

## Riesgos

- **R-01 — Confusión terminológica**: coexisten "Presupuestos"
  (mensuales por categoría, tab en `/reports`) y "Presupuestos
  semanales" (nueva ruta `/budgets`). Diego puede confundirlos.
  Mitigar: nomenclatura diferenciada en UI, FAQ actualizado, icono
  distinto.
- **R-02 — Pérdida de presupuestos en restore**: al no ir al
  backup, un usuario que dependa fuertemente del módulo puede
  perderlo todo al restaurar. Aceptado como trade-off (Diego
  confirma que no es vital tenerlo). Mitigar: FAQ + copy del
  export explícito.
- **R-03 — Schema bump v6 → v7 con 4 tablas nuevas**: es aditivo
  pero el guardrail `UnimplementedError` en `onUpgrade` debe
  extenderse. Riesgo de crash post-install si no se agrega la
  rama v6→v7.
- **R-04 — Tipo drift para `week_start_date`**: drift maneja
  fechas como DateTime con la config text. `week_start_date` es
  "date only" sin hora, pero drift persiste ISO string. Debe
  normalizarse a medianoche local antes de guardar para evitar
  desalineación por hora.
- **R-05 — Vinculación futura con movimientos**: el modelo actual
  no reserva ninguna FK ni campo para conectar renglones con
  `journal_entries`. Cuando venga el sprint de "planeado vs
  ejecutado" habrá que agregar `weekly_budget_items.entry_id` (o
  al revés) — schema bump adicional. Aceptable.
- **R-06 — Snapshot vs referencia en plantillas**: RN-B15/RN-B16
  fuerzan snapshot (nuevos `id` al copiar). Un bug de
  implementación que compartiera referencia por accidente
  produciría cambios inesperados. Cubierto con test explícito
  (editar plantilla NO cambia presupuesto derivado y viceversa).
- **R-07 — Hard delete sin papelera**: si Diego borra un
  presupuesto por accidente, no hay undo. Mitigar con dialog
  destructivo + copy claro. Sin snackbar con "deshacer" en el MVP.
- **R-08 — Multi-plan por semana genera ruido visual**: si Diego
  arma 5 planes para la misma semana, el listado se sobrepobla.
  Sin límite duro; en la práctica single-user tiende a 1-2.
- **R-09 — Ausencia de recurrencia automática**: aunque las
  plantillas mitigan el pain, sigue siendo un tap manual por
  semana. Puede generar abandono a las 3-4 semanas. Se acepta
  como trade-off del MVP.
- **R-10 — DragHandle no es affordance obvia**: usuarios que no
  conocen el patrón ⋮⋮ pueden no descubrir que reordena. Mitigar
  con onboarding tooltip (fuera de alcance) o FAQ.

## Supuestos

- Existe `AppPreferencesDao` con esquema key-value activo. Ver
  `mobile/lib/data/daos/app_preferences_dao.dart`.
- El picker de fecha usa `showDatePicker` estándar; no filtra días
  no válidos por `week_start_dow` — es solo un sugerido inicial
  del picker (RN-B02).
- La UI seguirá los patrones existentes: `KindPicker`,
  `CategoryPicker`, `BaseCard`, `ConfirmDialog`, `AmountFormatter`,
  `error_snackbar.dart`.
- `Icons.calendar_month` (o similar disponible en Material Icons)
  es la mejor iconografía para el entry point del Dashboard.
- La UI del listado usa secciones "Esta semana", "Próximas",
  "Pasadas" con headers tipo `SliverPersistentHeader` o similares.
- La navegación se hace con `context.push('/budgets')` y
  `context.push('/budgets/:id')` respetando la convención del
  proyecto.
- El drag handle usa `Icons.drag_indicator` (2 columnas de 3
  puntos = 6 puntitos) — el patrón Material estándar.
- Los timestamps `created_at` / `updated_at` usan la config
  `store_date_time_values_as_text: true` (mismo patrón del
  ledger).
- No hay soporte offline extra ni sync — es local, single-user,
  la BD del cel es la única fuente de verdad.
- `flutter analyze` como gate previo al commit se mantiene.
- Se acepta que un backup omite los presupuestos y plantillas —
  documentado en FAQ (Diego confirma).

## Impacto esperado

- Diego reemplaza el paso mental / papel de planificar la semana
  con un flujo de 3-5 pantallas dentro de la app.
- Las plantillas cortan tiempo de setup semanal en > 70% después
  de la primera semana.
- Multi-plan por semana habilita simulaciones y planeación
  comparativa desde la app.
- Sin regresión en el ledger existente ni en los reportes. El
  módulo vive aislado.
- Base para features futuros: comparativa planeado vs ejecutado,
  notificaciones semanales, dashboard con card "balance de esta
  semana", exportar como PDF, recurrencia automática.
- Continúa el patrón spec-driven del proyecto: nuevo módulo con
  todo su ciclo (DAO, tests, docs, help) sin atajos.
