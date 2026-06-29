# Branch Quality Review: flutter-entries-saved-views-v1

## Metadata

- Fecha: 2026-06-29
- Rama revisada: `main`
- Rama base: `main` (review post-merge del último commit funcional)
- Rango: `a06845b^..a06845b` (1 commit)
- Commit HEAD: `a06845b`
- Autor de revisión: Claude Code (carriles paralelos: SQL/concurrencia, frontend/UX, tests, schema/migración)
- Carpeta de reporte: `engineering/quality-review/flutter-entries-saved-views-v1/`

## Resumen ejecutivo

- Sprint introduce el **primer schema bump del MVP** (v2 → v3) con tabla `SavedViews`. RN-H02 (migración aditiva + guardrail) se respeta correctamente.
- Estado funcional: **entregable**. No hay hallazgos críticos de corrupción de datos ni de seguridad. La app es local-first single-user, lo que acota el blast radius.
- **Un hallazgo Alta** (H1: mutaciones del DAO sin `db.transaction(...)`) viola la convención del repo y deja una ventana minúscula de race-on-rapid-tap. Recomendado corregir.
- Cuatro hallazgos Medios accionables: (a) test de migración con tipo de columna divergente del codegen (silent skew), (b) UNIQUE constraint case-insensitive faltante, (c) backup export/import pierde silenciosamente las vistas, (d) loading state no usa Skeleton.
- Hay **falsos verdes** detectados en `saved_views_flow_test.dart` que merecen limpieza (assert tautológico + assert de texto sin scope).
- Mejoras de UX recomendadas: CTA en empty state, disabled state del botón "Guardar como vista" cuando no hay filtros activos, acceso desde Settings → Organización.
- Cobertura total del día: **299 tests verdes**. El sprint añade ~20 tests nuevos (DAO + filters + migración + widget).

## Alcance revisado

- Commits: `a06845b feat(mobile): sprint flutter-entries-saved-views-v1 — vistas guardadas + primer schema bump`
- Archivos principales:
  - `mobile/lib/data/database.dart` (schemaVersion 2→3, tabla SavedViews, ramas onUpgrade)
  - `mobile/lib/data/daos/saved_views_dao.dart` (CRUD + validaciones)
  - `mobile/lib/data/entries_filters.dart` (serialize/deserialize JSON)
  - `mobile/lib/data/backup.dart` (wipeAll extendido)
  - `mobile/lib/screens/saved_views_list_screen.dart` (pantalla full-screen patch UX v4)
  - `mobile/lib/widgets/save_view_dialog.dart` (Modal Bottom Sheet patch UX v2)
  - `mobile/lib/screens/entries_filters_screen.dart` (botón "Guardar como vista")
  - `mobile/lib/screens/entries_list_screen.dart` (icono bookmark)
  - `mobile/lib/widgets/error_snackbar.dart` (mapeo SavedViewsDaoError)
  - 4 archivos de tests nuevos
- Áreas: SQL/DAO, concurrencia, schema bump, migración, UX, design system, tests.
- Comandos usados: `git log`, `git diff --stat`, `git diff --name-status`, `git rev-parse`, lecturas directas con `Read`.

## Hallazgos bloqueantes

Ninguno. La rama es entregable. El hallazgo H1 (Alta) se reporta abajo como no-bloqueante porque para single-user en SQLite local el riesgo de race real es muy bajo, pero corresponde corregir antes del siguiente release estable.

## Hallazgos no bloqueantes

### H1. Mutaciones del DAO sin `db.transaction(...)`

- Severidad: **Alta**
- Área: SQL / concurrencia / convención
- Evidencia: `mobile/lib/data/daos/saved_views_dao.dart:48-64` (`create`), `:101-116` (`rename`), `:122-129` (`removeById`). Las tres hacen SELECT (chequeo duplicado / chequeo existencia) seguido de INSERT/UPDATE/DELETE sin envolver en `db.transaction(...)`. CLAUDE.md es explícito: *"Toda mutación corre dentro de `db.transaction(...)`"*.
- Impacto: En single-user es race teórico (rapid tap del botón Guardar antes de que el primer await termine puede colar dos inserts porque el SELECT ve BD vacía en ambos). Convención del repo violada → riesgo de copy-paste pattern erróneo en sprints futuros.
- Recomendación: envolver `create`, `rename` y `removeById` en `_db.transaction(() async { ... })`.
- Depende de: nada.

### H2. UNIQUE constraint case-insensitive faltante en `saved_views.name`

- Severidad: Media
- Área: SQL / defensa en profundidad
- Evidencia: `mobile/lib/data/database.dart:103-111` define la tabla sin `UNIQUE(name COLLATE NOCASE)`. La deduplicación case-insensitive es 100% application-side vía `LOWER(name)=LOWER(?)` (`saved_views_dao.dart:159`).
- Impacto: Defensa en profundidad faltante. Si un bug futuro en el DAO o un import externo (futuro) deja duplicados, la UI no espera ese estado.
- Recomendación: agregar `customConstraints(['UNIQUE(name COLLATE NOCASE)'])` en la tabla o índice único parcial. Requiere bump 3→4.
- Depende de: H1 (definir patrón transaccional primero).

### H3. Backup export/import pierde silenciosamente las vistas

- Severidad: Media
- Área: backup / UX
- Evidencia: `mobile/lib/data/backup.dart:254-262` borra `savedViews` en `wipeAll` (correcto), pero `exportToJson` no las serializa y `importFromJson` no las restaura. Decisión documentada como "preferencias de UI" (`database.dart:97-98`).
- Impacto: El usuario hace export → import del mismo archivo y pierde todas las vistas sin warning. No es corrupción pero sí pérdida silenciosa.
- Recomendación: opción mínima → warning en la UI de import ("se perderán tus vistas guardadas"). Opción robusta → agregar `saved_views` como campo opcional al JSON v1 (retrocompatible si los lectores ignoran campos desconocidos).
- Depende de: decisión de producto. Si se opta por warning, trivial. Si se opta por extender JSON, considerar coordinación con sync futuro con backend legacy.

### H4. Test de migración usa tipo de columna distinto al codegen

- Severidad: Media
- Área: tests / migración
- Evidencia: `mobile/test/data/database_migration_test.dart:54-61` crea la tabla a mano con `created_at INTEGER NOT NULL`, pero `build.yaml` tiene `store_date_time_values_as_text: true`, así que `m.createTable(savedViews)` real emite `created_at TEXT NOT NULL`. El test se autodescribe como "equivalente al `m.createTable`" pero no lo es.
- Impacto: Riesgo de divergencia silenciosa si en el futuro alguien toca `store_date_time_values_as_text`. El test in-memory ya no ejerce `onUpgrade` real (limitación de drift), entonces este es el último guardrail que tenemos.
- Recomendación: alinear la columna a `TEXT` en el test o, mejor, usar `await m.createTable(db.savedViews)` directamente para evitar drift entre el aserto y el codegen.
- Depende de: nada.

### H5. Loading state no usa Skeleton (rompe identidad visual del repo)

- Severidad: Media
- Área: frontend / design system
- Evidencia: `mobile/lib/screens/saved_views_list_screen.dart:49-62` muestra `Text('Cargando…')` plano. Patrón canónico en el repo (`accounts_list_screen.dart:45-52`, `categories_list_screen.dart`) usa `SkeletonCard` repetido.
- Impacto: Layout shift al pintar la lista real + inconsistencia con resto de listas.
- Recomendación: reemplazar el Text por `ListView.separated` con 4–6 `SkeletonCard`.
- Depende de: nada.

### H6. Empty state sin CTA accionable

- Severidad: Media
- Área: UX / onboarding
- Evidencia: `mobile/lib/screens/saved_views_list_screen.dart:192-232` (`_EmptyState`). Texto correcto pero sin botón. Diego debe cerrar la screen, abrir Filtros, configurar, scrollear al final para encontrar "Guardar como vista". Tres taps mínimos desde el vacío.
- Impacto: fricción en primer uso del feature.
- Recomendación: `FilledButton.icon(Icons.tune, 'Abrir filtros')` que cierre la screen y dispare `_openFilters()`. Mínimamente, un botón "Cerrar y configurar filtros".
- Depende de: nada.

### H7. Botón "Guardar como vista" mal jerarquizado en el panel

- Severidad: Media
- Área: UX / consistencia visual
- Evidencia: `mobile/lib/screens/entries_filters_screen.dart:431-439`. Está al final del `ListView` scrolleable, sin `_SectionTitle` propio. Las demás secciones tienen header (`Fecha`, `Tipo`, `Cuenta`, `Monto`, `Categorías`). Además falta **disabled state** cuando `_editing.activeCount == 0`: hoy se puede guardar "Este mes default".
- Impacto: rompe ritmo visual + permite guardar vistas equivalentes al estado inicial.
- Recomendación: (a) envolver en `_SectionTitle`, (b) `onPressed: _editing.activeCount == 0 ? null : _saveView`.
- Depende de: nada.

### H8. Sin acceso desde Settings → Organización

- Severidad: Media
- Área: UX / arquitectura de información
- Evidencia: `mobile/lib/screens/settings_screen.dart:215` define la sección "Organización" con shortcut a Categorías. Las vistas guardadas también son organización del journal pero solo se acceden desde `/entries` AppBar.
- Impacto: descubribilidad menor; usuario que entra a Settings esperando gestionar todo no las encuentra.
- Recomendación: agregar `ListTile('Mis vistas')` en la sección "Organización" reusando `SavedViewsListScreen`.
- Depende de: nada.

### H9. Falsos verdes en widget tests

- Severidad: Media
- Área: tests
- Evidencia:
  - `mobile/test/screens/saved_views_flow_test.dart:102` → `expect(find.byType(SavedViewPickerSheetMarker), findsNothing)`. La clase está definida al final del mismo archivo (líneas 117-121) y nunca se monta en ningún lado. Tautología.
  - `mobile/test/screens/saved_views_flow_test.dart:85` → `expect(find.text('Gasto'), findsOneWidget)`. No valida que ese texto sea el chip del filtro activo. Si el panel o `KindPicker` también lo renderean, el test pasa por la razón equivocada.
- Impacto: regresiones futuras pueden pasar inadvertidas.
- Recomendación: borrar el assert tautológico; atar el segundo al widget concreto (`find.descendant(of: find.byType(FilterChip), matching: find.text('Gasto'))`).
- Depende de: nada.

### H10. Backup test no valida que `saved_views` queda vacío post `wipeAll`

- Severidad: Media
- Área: tests / backup
- Evidencia: `mobile/test/data/backup_test.dart:503` (test "wipeAll vacía las 3 tablas") no asserta que `saved_views` quede vacía. `wipeAll` sí las borra, pero la regresión sería silenciosa.
- Impacto: si alguien quita la línea de `wipeAll` por error, ningún test lo detecta.
- Recomendación: agregar assert sobre count de `saved_views == 0` tras `wipeAll`.
- Depende de: nada.

### H11. FK colgante por archivado no testeado

- Severidad: Media
- Área: tests / dominio
- Evidencia: Aplicar una vista cuyos `accountIds`/`categoryIds` apuntan a entidades archivadas no tiene test (CB-T17 del plan). El comportamiento esperado existe (filtros silenciosos sobre IDs inexistentes) pero no hay regression test.
- Impacto: si el comportamiento cambia (e.g. error en lugar de filtro silencioso), nadie lo nota.
- Recomendación: agregar test integración que archive cuenta + aplique vista que la referencia + verifique que la lista no rompe.
- Depende de: nada.

### H12. Validación trim del `name` no testeada

- Severidad: Baja
- Área: tests / DAO
- Evidencia: La lógica de trim existe en `saved_views_dao.dart:52` pero no hay assert que verifique que `'  Mi vista  '` se guarde como `'Mi vista'`. UT-02 prueba `'   '` que falla por empty.
- Impacto: bajo.
- Recomendación: agregar test `expect(view.name, 'Mi vista')` tras crear con padding.
- Depende de: nada.

### H13. Fallback ante JSON corrupto no testeado en la rama crítica

- Severidad: Baja
- Área: tests / robustez
- Evidencia: El `try/catch` en `saved_views_dao.dart:194` (deserialize con fallback `thisMonth`) queda muerto en tests. UT-14 solo cubre `{}`. No se prueba `datePreset` con slug inválido (`'foo'`).
- Impacto: regresión silenciosa si alguien rompe el fallback.
- Recomendación: agregar test que inserte SQL crudo con `filtersJson = '{invalid'` y verifique que `findById` devuelve filtros default sin crashear.
- Depende de: nada.

### H14. Rama defensiva 1→3 y guardrail UnimplementedError sin test

- Severidad: Baja
- Área: tests / migración
- Evidencia: La rama `1→3` (`database.dart:201-209`) replica los efectos de `1→2` + `2→3` correctamente, pero no hay test. El guardrail `UnimplementedError` (`database.dart:214-218`) tampoco.
- Impacto: si un futuro bump rompe el patrón, no hay red.
- Recomendación: `expect(() => onUpgrade(from: 1, to: 99), throwsA(isA<UnimplementedError>()))`.
- Depende de: nada.

### H15. WTs faltantes para rename / delete / cancel

- Severidad: Baja
- Área: tests / UX
- Evidencia: `saved_views_flow_test.dart` cubre create, apply y empty state. Falta WT para rename, delete y cancelar el dialog. SM-05/SM-06 quedaron como smoke manual.
- Impacto: bajo (los happy paths principales están cubiertos).
- Recomendación: agregar 3 WT cuando se toque el archivo de nuevo.
- Depende de: nada.

### H16. `LOWER()` de SQLite es ASCII-only

- Severidad: Baja
- Área: SQL / i18n
- Evidencia: `saved_views_dao.dart:159` usa `LOWER(name) = LOWER(?)`. SQLite built-in `LOWER` es ASCII-only: `"Café"` y `"CAFÉ"` se considerarían distintos.
- Impacto: bajo para español (acentos en mayúsculas raros). Inconsistencia con la intención de "case-insensitive".
- Recomendación: documentar o normalizar via Dart (`trimmedName.toLowerCase()` antes del SELECT).
- Depende de: nada.

### H17. Tooltip faltante en `PopupMenuButton`

- Severidad: Baja
- Área: a11y / consistencia
- Evidencia: `saved_views_list_screen.dart:104-145` sin parámetro `tooltip:`. Default Material en inglés ("Show menu"); el resto del repo usa tooltips en español.
- Impacto: bajo.
- Recomendación: `tooltip: 'Más acciones'`.
- Depende de: nada.

### H18. Rename con nombre idéntico es no-op silencioso

- Severidad: Baja
- Área: UX / feedback
- Evidencia: `saved_views_list_screen.dart:158` → `if (newName == view.name) return;`. Mismo efecto que cancelar, sin feedback al usuario que sí presionó "Guardar".
- Impacto: bajo.
- Recomendación: o dejarlo documentado, o mostrar `showSuccessSnackbar('Sin cambios.')`.
- Depende de: nada.

### H19. Código muerto en `_submit` del dialog

- Severidad: Baja
- Área: limpieza
- Evidencia: `save_view_dialog.dart:75-77` valida `>50` pero `maxLength: 50` del `TextField` (línea 119) ya bloquea entrada. La rama nunca dispara.
- Impacto: ninguno funcional. Confunde al leer.
- Recomendación: quitar la rama o comentar la intención (defensa en profundidad).
- Depende de: nada.

### H20. Downgrade no documentado

- Severidad: Baja
- Área: documentación
- Evidencia: Si Diego sideloadea APK v2 sobre datos v3 por error, drift no degrada y no hay rama. Solo upgrades cubiertos.
- Impacto: caso improbable pero conviene anclar la decisión.
- Recomendación: una línea en `pendientes.md` del sprint o nota corta en CLAUDE.md.
- Depende de: nada.

## Plan de corrección ordenado

1. **H1** — envolver `create` / `rename` / `removeById` del `SavedViewsDao` en `_db.transaction(...)`. Sin schema bump. (~10 min)
2. **H4** — alinear `database_migration_test.dart:54-61` a `TEXT` (o mejor, usar `m.createTable(db.savedViews)`). (~10 min)
3. **H9** — limpiar falsos verdes en `saved_views_flow_test.dart:85,102`. (~5 min)
4. **H10** — agregar assert de `saved_views` vacío post `wipeAll` en `backup_test.dart`. (~5 min)
5. **H12, H13, H14, H15** — backfill de tests baja prioridad. (~30 min total)
6. **H5** — reemplazar loading state por `SkeletonCard`. (~10 min)
7. **H6** — CTA en empty state. (~15 min)
8. **H7** — header `_SectionTitle` + disabled state para botón "Guardar como vista". (~10 min)
9. **H8** — `ListTile` en Settings → Organización. (~10 min)
10. **H17, H18, H19, H16** — pulido. (~20 min total)
11. **H2** — UNIQUE constraint case-insensitive con bump 3→4. Requiere nueva rama en `onUpgrade`. (~30 min)
12. **H3** — extender backup JSON v1 con campo opcional `saved_views` o warning en UI de import. Decisión de producto. (~variable)
13. **H20** — documentar downgrade en CLAUDE.md o pendientes del sprint. (~5 min)
14. Correr `flutter test` + `flutter analyze` al final.

Total estimado (sin H3): ~2.5 hs si se hace todo en un solo sprint de pulido. Si solo Altas + Medias: ~1.5 hs.

## Validaciones recomendadas

```bash
cd mobile
flutter test                          # 299 tests + los nuevos del backfill
flutter analyze                       # 0 errores esperado
flutter test test/data/saved_views_dao_test.dart
flutter test test/data/database_migration_test.dart
flutter test test/screens/saved_views_flow_test.dart
```

Smoke manual recomendado (no automatizable):

- SM-01: APK 0.10.0+62 sobre datos reales con BD pre-existente (validar migración 2→3 en producción).
- SM-05/06: rename y delete con UX real (Diego ya validó en parte el día del sprint).
- SM-X (nuevo): tap-tap-tap rápido en "Guardar" del dialog para validar H1 corregido.

## Limitaciones

- Review post-merge (la rama ya está en `main`). Los hallazgos se aplican como sprint de pulido posterior, no como bloqueo de PR.
- No se ejecutó `flutter test` ni `flutter analyze` durante la review. La confirmación de 299 tests verdes se basa en el commit message + estado declarado.
- El test de migración real (file-backed DB con `user_version` persistido) sigue dependiente de smoke manual SM-01 — limitación reconocida del setup in-memory.
- No se evaluó performance del `watchAll()` con N grande de vistas (asumido bajo, N esperado < 50 en uso real).
- Revisión read-only por convención de la skill: no se modificó código durante el análisis.
