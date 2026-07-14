# Branch quality review — flutter-weekly-budgets-v1

**Fecha:** 2026-07-13
**Slug:** `flutter-weekly-budgets-v1`
**Rama:** `main` (sin commit sobre HEAD `942e510`, cambios locales)

## Alcance

Sprint mediano-grande: nuevo módulo standalone "Presupuestos
semanales" con 4 tablas drift nuevas (schema v6→v7), 2 DAOs, 4
pantallas, 4 widgets base, 4 rutas nuevas, 1 preferencia global,
entradas desde Dashboard/Settings/Help. ~62 tests nuevos + fixes de
regresión en tests preexistentes de Settings. Bump `0.20.0+94`.

Revisión con 4 dimensiones en paralelo (4 subagentes Sonnet):
correctness/data, snapshot semantics + validation, UX/A11Y/consistency,
test coverage + code smells. 21 hallazgos verificados, 10 resueltos
antes del cierre (5 altas + 5 medias), 11 restantes documentados como
"aceptados" o "diferidos".

## Hallazgos por severidad

### Altas — resueltas

#### A1 — Migración v6→v7 no idempotente ante interrupción

**Archivo:** `mobile/lib/data/database.dart` (rama `if (from == 6 && to == 7)` en `onUpgrade`)

`m.createTable(...)` no soporta `IF NOT EXISTS`. Si Android mata la
app durante la migración, el próximo `open()` re-ejecuta `onUpgrade(6,7)`
y crashea con "table already exists" — crash-loop persistente hasta
que se borre el archivo SQLite. Precedente en migración 4→5 usa
`CREATE INDEX IF NOT EXISTS` por la misma razón (`onUpgrade` no corre
en transacción de usuario).

**Estado: RESUELTO** — reemplazados los 4 `m.createTable` por
`customStatement('CREATE TABLE IF NOT EXISTS ...')` con el DDL exacto
del schema generado. Los 3 `CREATE INDEX` cambiaron a `IF NOT EXISTS`.
Verificado con test MG-02/MG-03 preexistentes (drop + re-run
`onUpgrade` sobre BD misma sesión).

---

#### A2 — Unicidad `template.name` case-insensitive falla con acentos/ñ

**Archivo:** `mobile/lib/data/daos/budget_templates_dao.dart`
(`_validateNameUnique`)

SQLite `LOWER()` solo hace case-fold ASCII; "Comida Íntima" y "comida
íntima" no colisionaban. Dart `.toLowerCase()` es Unicode-aware.
Verificado con reproducción directa en `sqlite3`.

**Estado: RESUELTO** — validación migrada a Dart: `select(all).get()`
+ `all.any((t) => t.name.trim().toLowerCase() == normalized)`. En
single-user <100 plantillas, cost negligible.

---

#### A3 — `_validateItemAmount` no rechaza NaN/Infinity

**Archivo:** `mobile/lib/data/daos/weekly_budgets_dao.dart` +
`budget_templates_dao.dart`

`amount <= 0` retorna `false` para `double.nan`, `+Infinity`,
`-Infinity` (semántica IEEE 754). Un cliente malicioso o buggy podía
persistir montos que corrompen `watchBudgetBalance` y `calculateBalance`
downstream.

**Estado: RESUELTO** — condición cambiada a
`if (!amount.isFinite || amount <= 0) throw ...`. `isFinite` es
`false` para NaN e infinitos. Cubre 3 casos con una guarda.

---

#### A4 — Drag handle touch target real ~24px, no 44px prometidos

**Archivo:** `mobile/lib/screens/weekly_budgets/widgets/items_section.dart`
(handle del `ReorderableDragStartListener`)

`SizedBox(44,44)` no fuerza `hitTestSelf`. El `RenderBox` interno
delega al hijo (`Icon` de 24px) cuyo único renderer con
`hitTestSelf == true` es el `RenderParagraph` del glyph. Área real
tapable ≈ 24×24, no 44×44 como afirmaba el comment.

**Estado: RESUELTO** — envuelto el `Icon` en
`GestureDetector(behavior: HitTestBehavior.opaque)` dentro del
`SizedBox(44,44)`. Ahora sí toda el área responde al drag. Comment
actualizado con la razón técnica.

---

#### A5 — Wordmark "FinCore" se parte a 360dp por el 4º IconButton

**Archivo:** `mobile/lib/screens/dashboard_screen.dart` (AppBar)

Con 4 IconButtons (192px) + título ~136px, un cel Android de 360dp
(mayoría del parque) forzaba el wrap del wordmark en 2 líneas.
Verificado con widget test `tester.view.physicalSize`.

**Estado: RESUELTO** — "Categorías" movido a `PopupMenuButton` con
icono `Icons.more_vert`. Los 3 accesos directos remanentes (Reportes,
Presupuestos semanales, Configuración) + popup dejan espacio
suficiente para el wordmark en una línea.

### Medias — resueltas

#### M1 — `updateItem` valida categoría antes de aplicar `clearCategory`

**Archivo:** `mobile/lib/data/daos/weekly_budgets_dao.dart` +
`budget_templates_dao.dart` (`updateItem`, `updateTemplateItem`)

`clearCategory: true` + `categoryId: <cat_archivada>` por accidente
disparaba `invalid_category_reference` cuando el intent era limpiar.
Contrato público del flag roto.

**Estado: RESUELTO** — reordenada la lógica: `if (clearCategory)`
short-circuit; `else if (categoryId != null)` valida. No alcanzado
por las screens actuales (siempre pasan `categoryId: null` con el
flag) pero blindado para futuros callers.

---

#### M2 — `addItem`/`addTemplateItem` no en transacción

**Archivos:** ambos DAOs (`addItem`, `addTemplateItem`)

`_nextSortOrder` (SELECT MAX) + `insert` son round-trips separados.
Race virtual: doble-submit puede generar 2 items con el mismo
`sort_order`. En single-user es improbable pero contraviene el
principio "toda mutación corre en transacción" del proyecto.

**Estado: RESUELTO** — envuelto el bloque `sortOrder = await
_nextSortOrder(...)` + `into().insert(...)` en `transaction(() async
{...})`. Firma pública sin cambios.

---

#### M3 — Pantallas detalle sin AppBar durante loading

**Archivos:** `mobile/lib/screens/weekly_budgets/detail_screen.dart`
+ `template_detail_screen.dart` (rama `!hasData` / loading)

`Scaffold(body: Center(CircularProgressIndicator))` sin AppBar deja
al usuario sin botón back visual durante el load inicial —
inconsistente con `category_form_screen.dart` y `account_form_screen.dart`
que muestran AppBar con título "Cargando…".

**Estado: RESUELTO** — ambas pantallas ahora muestran
`Scaffold(appBar: AppBar(title: Text('Cargando…')), ...)` durante
loading. Back automático.

---

#### M4 — Aviso "no se respaldan" solo en FAQ escondida

**Archivo:** `mobile/lib/screens/weekly_budgets/list_screen.dart`

Los presupuestos NO se incluyen en el backup (RN-B13). Diego puede
armar 5 planes, exportar, reinstalar, importar y perder todo sin
señal previa. El único aviso vive dentro de un `ExpansionTile` de
Help que el usuario probablemente nunca abre.

**Estado: RESUELTO** — banner sutil arriba de la lista con icono
`Icons.info_outline` + texto en `textMuted` "Los presupuestos
semanales y plantillas no se incluyen en el respaldo." Sin acción,
solo informativo.

---

#### M5 — Copy delete renglón template sin nombre

**Archivo:** `mobile/lib/screens/weekly_budgets/template_detail_screen.dart`

Delete del budget muestra `¿Eliminar el renglón 'X'?` (con nombre);
delete del template muestra `¿Eliminar este renglón de la plantilla?`
(genérico). En plantillas con renglones parecidos ("Renta" vs "Renta
compartida") el usuario no puede confirmar cuál se va.

**Estado: RESUELTO** — `_deleteItem(itemId, name)` recibe el nombre
del item; el dialog ahora dice `¿Eliminar el renglón 'X' de la
plantilla?` — consistente con budget detail. Test WT-TS03
actualizado con el copy exacto.

### Medias — diferidas

#### M6 — Multi-salto migraciones (1→7, 2→7, ..., 5→7) no implementadas

**Archivo:** `mobile/lib/data/database.dart`

Patrón establecido: cuando se bumpea `schemaVersion`, se agregan
ramas defensivas para saltar múltiples versiones. Para v7 solo
existe `6→7`. Cualquier instalación con BD ≤5 al abrir la app
disparará el guardrail `UnimplementedError`.

**Estado: DIFERIDO** — el único caso real es Diego (BD en v6). No
hay otros testers activos. Si aparece un caso post-release lo
agregamos ad-hoc con un patch de 5-10 líneas. Documentado en
`decisiones-implementacion.md`.

### Bajas — documentadas

- **B1** — `assert` de rango se descarta en release. Guarda de
  defensa en profundidad ausente. Riesgo bajo dado el clamp de
  `weekStartDow()`. Diferido.
- **B2** — `reorderItems` ignora silenciosamente ids fuera del
  parent. Sin señal de reorder parcial. Diferido (uso interno solo).
- **B3** — Longitud con `String.length` (UTF-16) vs grapheme
  clusters. Patrón preexistente en todo el repo — no se cambia acá.
- **B4** — Helper `_capitalize` duplicado en 4 archivos. Refactor
  a `lib/utils/string_utils.dart` en sprint futuro.
- **B5** — Test UT-WB22 (categoría archivada post-crear item) sin
  cobertura explícita. RN-B07 protege el edge; test futuro.
- **B6** — Comment obsoleto en `detail_screen.dart:386` sobre
  `Expanded`. Diferido.
- **B7** — Cálculo balance duplicado (3 copias entre
  `templates_screen.dart`, `template_detail_screen.dart`,
  `calculateBalance` de helpers). Refactor futuro.
- **B8** — Formateo "Sobra/Faltan/En equilibrio" duplicado entre
  `BalanceFooter` y `_BudgetCard`. Refactor futuro.
- **B9** — Duplicación estructural CRUD de items entre los 2 DAOs.
  Extraer mixin en sprint futuro.
- **B10** — WT-DS08 no ejercita el drag real (solo verifica que tap
  fuera del handle no reordena). Delegado a smoke SM-04.

## Resumen

- 21 hallazgos verificados.
- **5 altas resueltas** (A1, A2, A3, A4, A5).
- **5 medias resueltas** (M1, M2, M3, M4, M5).
- 1 media diferida con justificación (M6).
- 10 bajas documentadas para sprints futuros.
- 0 bloqueantes.
- Suite: **671/671 verdes** (1 skip preexistente en WT-TS04).
- `flutter analyze`: limpio.
- APK release verificado (`versionCode 2094 / versionName 0.20.0`).

Sprint apto para smoke con Diego + commit final tras revisión del
reporte.
