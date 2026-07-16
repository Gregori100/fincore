# Plan técnico — flutter-accounts-archive-v1

## Enfoque tecnico

Cambio incremental y aditivo sobre el modelo actual de cuentas. Se agrega una columna nueva `archived_at TEXT NULLABLE` a `accounts` sin tocar `deleted_at`, se bump `schemaVersion` de 8 a 9 con una migración aditiva, y se refactoriza `AccountsDao` para exponer tres métodos discretos: `archive`, `unarchive`, `delete`. `delete` recibe el cuerpo actual de `archive` (soft-delete cascada usando `deleted_at`) sin cambios de comportamiento. `archive` y `unarchive` sólo tocan la fila de `accounts`.

La UI se separa por segmentos (`Activas` / `Archivadas`) en `accounts_list_screen` y por menú overflow del AppBar en `account_form_screen`. `entry_form_screen` gana detección de "movimiento con cuenta archivada" que bloquea toda edición y sólo permite eliminar. `AccountPicker` gana prop `includeArchived` para filtros y pantallas de sólo lectura. `movement_row` marca visualmente el sufijo `(archivada)`.

Los diálogos usan las abstracciones existentes: `showConfirmDialog` para archivar/desarchivar (reversibles) y `showDestructiveDialog` para eliminar (con chips de impacto que muestran conteo real de movimientos afectados).

Backup JSON v1 queda compatible: export omite `archived_at` (no lo agrega al payload) y los imports asumen `archived_at = null` para cada cuenta insertada. No se bump el backup en este sprint.

Los reportes filtran únicamente por `deleted_at IS NULL` y siguen incluyendo cuentas archivadas para preservar el histórico contable. La columna `archived_at` sólo se consulta desde el DAO de cuentas y desde los helpers de detección en `entry_form_screen` y `movement_row`.

## Requisitos funcionales cubiertos

- RF-001: Cubierto por T004 (schema + migración). Rama nueva `schemaVersion 9` en `MigrationStrategy.onUpgrade` con `ALTER TABLE accounts ADD COLUMN archived_at TEXT`. Guardrail `UnimplementedError` preservado tras la rama nueva.
- RF-002: Cubierto por T005 (rename `archive` → `delete` en `AccountsDao`). Sin cambios de lógica; el callsite existente en `account_form_screen.dart:198` se actualiza en T010.
- RF-003: Cubierto por T006 (nuevo `archive(id)` seteando `archived_at = DateTime.now()`).
- RF-004: Cubierto por T007 (nuevo `unarchive(id)` seteando `archived_at = null`).
- RF-005: Cubierto por T008 (ajuste `watchActive` a `deletedAt.isNull() & archivedAt.isNull()`).
- RF-006: Cubierto por T008 (nuevo `watchArchived`).
- RF-007: Cubierto por T008 (`listAll({includeArchived})` filtra siempre `deleted_at IS NULL` y aplica `archived_at IS NULL` cuando `!includeArchived`).
- RF-008: Cubierto por T009 (nuevo helper `findActiveOrArchivedById`).
- RF-009: Cubierto por T011 (nuevo helper `EntriesDao.countByAccount(id)`).
- RF-010: Cubierto por T014 (nuevo prop `includeArchived` en `AccountPicker` con badge visual y estilo `textSubtle`).
- RF-011: Cubierto por T012 (segmented `SegmentedButton<AccountsSegment>` en `accounts_list_screen`; stream conmuta según selección).
- RF-012: Cubierto por T012 (menú overflow por card activa con opciones Editar / Archivar / Eliminar).
- RF-013: Cubierto por T012 (menú overflow por card archivada con Desarchivar / Eliminar).
- RF-014: Cubierto por T013 (`account_form_screen` reemplaza el `OutlinedButton` destructivo por menú overflow en AppBar con Archivar y Eliminar).
- RF-015: Cubierto por T013 (modo read-only cuando `archived_at != null` + banner "Cuenta archivada").
- RF-016: Cubierto por T015 (`entry_form_screen` detecta cuenta archivada en origen o destino y renderiza en modo read-only con banner + sólo Eliminar movimiento habilitado).
- RF-017: Cubierto por T014 + T015 (el picker recibe `includeArchived = true` desde el form en modo edit).
- RF-018: Cubierto por T016 (`movement_row` agrega sufijo `(archivada)` con estilo `textSubtle` italic).
- RF-019: Cubierto por T017 (auditoría de `ReportsService` y tabs de reports para confirmar que ninguna query se filtra por `archived_at`).
- RF-020: Cubierto por T012 + T013 (strings inline en español neutral en los tres diálogos).
- RF-021: Cubierto por T018 (bump `pubspec.yaml` a `0.26.0+109` y `android/app/build.gradle.kts` a `versionCode = 109`, `versionName = "0.26.0"`).

## Archivos o modulos probablemente afectados

- `mobile/lib/data/database.dart` — nueva columna `archivedAt`, `schemaVersion = 9`, rama nueva en `onUpgrade`.
- `mobile/lib/data/database.g.dart` — regenerado por `build_runner`.
- `mobile/lib/data/daos/accounts_dao.dart` — rename `archive` → `delete`, nuevos `archive`, `unarchive`, `watchArchived`, `findActiveOrArchivedById`, ajuste de `watchActive`, `listAll`.
- `mobile/lib/data/daos/entries_dao.dart` — nuevo helper `countByAccount(id)`.
- `mobile/lib/data/financial_state.dart` — actualizar el docstring que menciona `AccountsDao.archive` para reflejar el rename (línea ~85).
- `mobile/lib/screens/accounts_list_screen.dart` — segmented + menú overflow + `_ArchivedAccountRow` (o refactor de `_AccountRow` para modo archivada).
- `mobile/lib/screens/account_form_screen.dart` — menú overflow AppBar + modo read-only + banner + reemplazo del `OutlinedButton "Archivar cuenta"` en línea 198 y aledaños.
- `mobile/lib/screens/entry_form_screen.dart` — helper `_isEntryLockedByArchivedAccount` + banner + widgets deshabilitados + AccountPicker con `includeArchived: true`.
- `mobile/lib/widgets/account_picker.dart` — prop `includeArchived`, badge visual, estilo `textSubtle` para archivadas.
- `mobile/lib/widgets/movement_row.dart` — sufijo `(archivada)` en `entryAccountLabel` o en el widget.
- `mobile/lib/widgets/confirm_dialog.dart` — sin cambios (se reutiliza).
- `mobile/lib/widgets/destructive_dialog.dart` — sin cambios (se reutiliza con `impacts`).
- Reportes (`mobile/lib/screens/reports/*.dart` — 11 tabs) — sin cambios funcionales. Auditoría de queries para confirmar RN-A07/RF-019. Si algún tab tiene picker de filtro por cuenta, se pasa `includeArchived: true`.
- `mobile/lib/data/reports_service.dart` (probable) — auditoría.
- `mobile/lib/data/backup.dart` — auditoría para confirmar que export/import v1 sigue funcionando; posiblemente sin cambios.
- `pubspec.yaml` y `android/app/build.gradle.kts` — bump de versión.
- Tests: `test/data/database_test.dart`, `test/data/invariants_test.dart`, `test/data/financial_state_test.dart`, `test/data/backup_test.dart`, `test/screens/list_screens_test.dart`, `test/screens/entry_form_screen_test.dart`, `test/screens/entry_form_kinds_test.dart`.
- Nuevo test file probable: `test/data/accounts_archive_dao_test.dart` para agrupar los tests nuevos del DAO.

## Entidades y estados afectados

- `Account` gana un tercer estado combinando `deleted_at` y `archived_at`:
  - Activa: `deleted_at IS NULL AND archived_at IS NULL` (todo hoy).
  - Archivada: `deleted_at IS NULL AND archived_at IS NOT NULL` (nuevo).
  - Eliminada (cascada): `deleted_at IS NOT NULL` (equivalente al "archivada" anterior; se mantiene la misma columna y semántica).
- Transiciones válidas:
  - Activa → Archivada (via `archive`).
  - Archivada → Activa (via `unarchive`).
  - Activa → Eliminada (via `delete`).
  - Archivada → Eliminada (via `delete`).
  - Eliminada → cualquier estado: no permitido (soft delete terminal; recuperación solo via import de respaldo previo).
- Invariante: la Bolsa (`is_protected=true`) sólo puede estar Activa. Todas las transiciones desde/hacia Archivada o Eliminada lanzan `protected_account`.
- Invariante: al ejecutar `delete`, todos los `journal_entries` donde la cuenta figura como origen o destino y con `deleted_at IS NULL` reciben `deleted_at = now()` en la misma transacción.
- Invariante: `archive`/`unarchive` no modifican ningún `journal_entry`.
- `JournalEntry` no gana columnas nuevas. Su estado depende de `deleted_at` como hoy. En la UI, se computa un flag derivado `entry.hasArchivedAccount` a partir de la cuenta cargada (via `findActiveOrArchivedById`) para decidir read-only en `entry_form_screen`.
- `FinancialStateService` no cambia su algoritmo: sigue calculando BO/DE/CR sobre `accounts` con `deleted_at IS NULL` y `journal_entries` con `deleted_at IS NULL`. Las cuentas archivadas contribuyen a los agregados igual que las activas.

## Compatibilidad con datos y procesos existentes

- **Migración de schema**: aditiva pura. `ALTER TABLE accounts ADD COLUMN archived_at TEXT` no requiere backfill (default NULL). Corre en `onUpgrade` sin transacción usuario (limitación conocida de drift); si la app se cierra en medio, el siguiente open reintenta desde la versión anterior porque `schemaVersion=9` sólo persiste al final de `onUpgrade`.
- **Datos históricos**: las cuentas que Diego "archivó" con el método antiguo tienen `deleted_at != null`. El sprint no las recupera; siguen ocultas de listas y reportes. Documentado como comportamiento esperado en Riesgos.
- **Backup JSON v1**: export sigue omitiendo `archived_at`. Import v1 asume `archived_at = null`. Sin bump de versión de backup. Round-trip idéntico.
- **Reportes**: filtran únicamente por `deleted_at IS NULL`. Cuentas archivadas aparecen en spending/income/cashflow/calendar/heatmap. Sin cambios de lectura.
- **`FinancialStateService`**: sin cambios en algoritmo. Los KPIs BO/DE/CR incluyen cuentas archivadas mientras no estén eliminadas.
- **Widget tests actuales**: `test/screens/list_screens_test.dart` monta `accounts_list_screen` y espera cierta jerarquía. Se ajustan localizadores si el segmented control cambia el árbol.
- **Callsites externos**: `mobile/lib/screens/account_form_screen.dart:198` (`deps.accountsDao.archive(...)`) se actualiza al nombre nuevo del método (`delete` o similar según UI decide). `mobile/lib/data/financial_state.dart:85` tiene un comentario que menciona `AccountsDao.archive(id)` que se actualiza.
- **Callsites en `category_form_screen.dart:197`** (`categoriesDao.archive(...)`) no se tocan. El módulo de categorías queda fuera de alcance por decisión explícita.

## Cambios de datos si aplica

- Columna nueva: `accounts.archived_at TEXT NULLABLE`.
- Sin nuevos índices. La lectura `archived_at IS NULL` no es hot path (la lista de cuentas activas es pequeña, típicamente <10 en single-user).
- Sin migración de datos históricos: todas las cuentas existentes arrancan con `archived_at = null` (activas).
- Sin cambios en las tablas `categories`, `journal_entries`, `saved_views`, `onboarding_state`.

## Cambios de UI si aplica

- `accounts_list_screen`:
  - Añadir `SegmentedButton<AccountsSegment>` bajo el AppBar (o inline como header del `ListView`). Dos opciones: `Activas`, `Archivadas`.
  - Estado local `_segment` de tipo enum `AccountsSegment { active, archived }`.
  - Dos streams cacheados en `didChangeDependencies`: `_streamActive = watchActive()`, `_streamArchived = watchArchived()`.
  - `_AccountRow` gana parámetro `isArchived` (o se crea `_ArchivedAccountRow` liviano). Menú overflow con 3 opciones (activas) o 2 opciones (archivadas). Confirmación mediante `showConfirmDialog` / `showDestructiveDialog`.
- `account_form_screen`:
  - AppBar gana `IconButton(Icons.more_vert_outlined)` con `PopupMenuButton` de 2 opciones (Archivar / Eliminar) cuando la cuenta está activa. Cuando está archivada, opciones son Desarchivar / Eliminar. El `PopupMenuDivider` separa Eliminar y se pinta con `FincoreColors.negative`.
  - Se elimina el bloque `OutlinedButton "Archivar cuenta"` actual de la parte inferior del form.
  - Cuando `account.archivedAt != null`: banner superior con `Container` `alphaTint` sobre `categoryPurple` (u otro semántico neutro), copy "Cuenta archivada · No se puede editar". Campos deshabilitados (`enabled: false`) sin botón Guardar en el footer.
- `entry_form_screen`:
  - Nuevo helper `bool _isEntryLockedByArchivedAccount(JournalEntry entry, List<Account> accounts)` en `_EntryFormScreenState`.
  - Cuando true: banner superior "Movimiento con cuenta archivada · Sólo se puede eliminar". Todos los campos (`monto`, `descripción`, `fecha`, `categoryPicker`, `accountPicker`) deshabilitados. El botón Guardar del footer no se renderiza; el botón "Eliminar movimiento" queda visible.
  - `AccountPicker` recibe `includeArchived: true` en modo edit para poder mostrar la cuenta archivada seleccionada.
- `AccountPicker`:
  - Prop nueva `bool includeArchived = false`.
  - Filtro cambia a `!(a.archivedAt != null && !includeArchived)` combinado con lo existente.
  - Cuando la entrada corresponde a una cuenta archivada, el label agrega ` · archivada` y el icono se pinta con opacidad reducida (`textSubtle` como `foregroundColor`).
- `movement_row`:
  - Helper existente `entryAccountLabel(item)` se extiende con parámetro opcional o se refactoriza el widget para consultar la cuenta y agregar sufijo `(archivada)` con estilo `TextStyle(fontStyle: FontStyle.italic, color: FincoreColors.textSubtle)`.

## Cambios de permisos si aplica

No aplica. La app es single-user sin roles.

## Riesgos tecnicos

- **Migración multi-salto (`from < 8`)**: la política actual en `onUpgrade` tiene cadenas para `from == 1 && to == N`. Si Diego (o cualquier tester) abre la app desde `schemaVersion=1` con el APK nuevo, la migración debe agotar todas las ramas hasta 9. Mitigación: agregar rama única `to == 9` que agrega la columna, más las cadenas correspondientes `from == X && to == 9` para X ∈ {1..8}. Alternativa más simple: rama `if (from < 9) { customStatement("ALTER TABLE accounts ADD COLUMN archived_at TEXT"); }` colocada al final antes del guardrail.
- **`build_runner` regenera `database.g.dart`**: si se olvida correr `dart run build_runner build --delete-conflicting-outputs` tras editar la table, compila roto. Task explícito.
- **Confusión conceptual `deleted_at` vs `archived_at`**: hay 30+ referencias a `deletedAt` en `mobile/lib/`. Riesgo de mezclarlas en el refactor. Mitigación: nunca borrar líneas de `deletedAt`; el sprint sólo agrega `archivedAt` como filtro adicional en 3-4 sitios (`watchActive`, `watchArchived`, `AccountPicker`, `entry_form_screen._isEntryLockedByArchivedAccount`).
- **Widget tests `list_screens_test.dart`**: la introducción del `SegmentedButton` puede romper `find.byType(ListTile)` u otros localizadores si el test los usa. Mitigación: revisar el test antes de tocar UI y ajustar en la misma tarea.
- **Semántica del `_stateService.invalidateAll()` en `unarchive`**: por convención, `delete` sí invoca `invalidateAll` (porque cambian los balances). `unarchive` no cambia balances pero podría no refrescar streams downstream si algún consumer cachea de más. Mitigación: no invocar `invalidateAll` en archive/unarchive; el smoke lo valida.
- **Backup import v1 sobre app v0.26**: el JSON no trae `archived_at`, así que todas las cuentas se insertan como activas. Si Diego importa un respaldo previo a este sprint, las cuentas que él "archivó" (en realidad eliminó) no vuelven porque están con `deleted_at != null` y no en el export. Documentado como comportamiento esperado.
- **Cascada en `delete` cuando la cuenta ya está archivada**: `delete` sobre una cuenta con `archived_at != null` debería funcionar (setea `deleted_at = now`, cascada sobre `journal_entries`). La combinación de las dos columnas es válida (`deleted_at NOT NULL AND archived_at NOT NULL`) pero desde la lectura, cualquier query que filtre `deleted_at IS NULL` la excluye correctamente. Sin riesgo.
- **`entry_form_screen` en modo new con cuenta archivada como default**: si por bug alguna ruta hace `context.push('/entries/new?accountId=X')` con X archivada, el picker no la ofrece porque `includeArchived: false` por default. El form no puede guardar. Comportamiento esperado.
- **Tests widget del harness (`pumpFincoreApp`)**: el harness monta la app con BD in-memory. Si los tests widget de la sección core del sprint requieren cuentas archivadas para probar, el helper `seedBolsa` no basta; hay que sembrar cuentas archivadas manualmente en `setUp`.

## Estrategia de pruebas

Ver `test-plan.md`.

Resumen:
- Unitarias del DAO: `archive`, `unarchive`, `delete` (renombrado), `watchActive`, `watchArchived`, `listAll`, `findActiveOrArchivedById`, `EntriesDao.countByAccount`.
- Invariantes: Bolsa protegida en las 3 acciones.
- Regresión: los tests existentes de "archive cascada" se renombran a `delete cascada` y siguen verdes.
- Widget: `accounts_list_screen` con segmented + menú overflow. `entry_form_screen` con banner read-only cuando cuenta archivada.
- Backup: round-trip con cuentas archivadas presentes.

## Estrategia de rollback

- El commit es único (un feature branch, un commit final o varios commits temáticos según se decida al implementar). Rollback = `git revert` del commit.
- La migración `ALTER TABLE ... ADD COLUMN` no es reversible en drift sin DROP COLUMN (destructivo). Estrategia práctica: si post-release Diego reporta un bug crítico, se hace hotfix con bump de versión (no rollback de schema). La columna `archived_at` queda inerte si no se lee.
- Si Diego decide revertir totalmente el sprint, tendría que exportar respaldo, revertir el commit, borrar la app y reinstalar la anterior, luego importar el backup. Documentado en Riesgos.

## Orden sugerido de implementacion

1. Bump de spec/plan (T001-T003): registrar decisiones pendientes en `spec.md` si aparecen.
2. Schema + migración + regen (T004): base para todo lo demás.
3. Refactor DAO: rename + nuevos métodos + streams (T005-T009).
4. Helper `EntriesDao.countByAccount` (T011).
5. Widget `AccountPicker` con `includeArchived` (T014).
6. Widget `movement_row` con sufijo `(archivada)` (T016).
7. Pantalla `account_form_screen` con overflow + read-only (T013).
8. Pantalla `accounts_list_screen` con segmented + overflow (T012).
9. Pantalla `entry_form_screen` con detección + banner + read-only (T015).
10. Auditoría de reportes (T017).
11. Actualización del comentario en `financial_state.dart` (T010b).
12. Actualizar callsite en `account_form_screen.dart:198` al nombre nuevo (T010) — puede estar embebido en T013.
13. Tests unitarios + widget (T019-T024).
14. Bump de versión (T018).
15. Build APK + smoke manual (T025).
16. Commit final (T026) — sólo si Diego lo pide explícitamente.

## Casos borde que condicionan la solucion

- Cuenta archivada que se elimina después: cascada sobre `journal_entries` funciona igual (setea `deleted_at`), sin importar el estado previo de `archived_at`.
- Cuenta desarchivada tras eliminación cascada: no aplica; `deleted_at != null` es terminal.
- Movimiento `transfer` con ambas cuentas archivadas: el form es read-only completo. Sólo Eliminar.
- Movimiento `debt_payment` cuya cuenta destino (credit) fue archivada: form read-only. Al eliminar, el balance de la credit archivada sube (ya no tiene ese pago descontado), pero como está archivada Diego sólo lo verá en reportes.
- Import de backup v1 con una cuenta que en el JSON aparece con `archived_at` (no debería, pero por robustez): el import de v1 ignora el campo. En v2 futuro se contempla explícitamente.
- Múltiples archivadas simultáneas: cada archivar dispara un stream update independiente. `watchArchived` se re-emite; la UI del segmento archivadas se actualiza.
- `AccountsDao.archive` sobre una cuenta ya archivada: idempotente-ish. El método puede sobrescribir `archived_at = now()` sin error, o validar y no-op. Decisión: validar y no-op silencioso (retorna sin error) para simplificar la UI que no tiene que revisar estado antes de llamar.
- `AccountsDao.unarchive` sobre una cuenta activa: idempotente. Retorna sin error.
- `AccountsDao.delete` sobre una cuenta ya eliminada (`deleted_at != null`): no debería llegar por UI, pero por robustez el método puede no-op o lanzar `not_found`. Decisión: preservar el comportamiento actual del método (que ya se llama sobre cuentas activas).
- Bolsa aparece en el menú overflow con opciones deshabilitadas o simplemente no aparece el menú: decisión de UX. Preferencia: no renderizar el menú overflow para la Bolsa. El tap en la card sigue navegando al form (que ya es read-only para Bolsa).

## Preguntas o supuestos que siguen afectando la implementacion

- **Supuesto**: la política de `onUpgrade` cubre saltos multi-versión con cadenas `from == X && to == Y`. Se agrega rama `from == 8 && to == 9` y ramas necesarias para `from < 8 && to == 9`. Si al leer `database.dart` se identifica un patrón más simple (rama única terminal), se usa esa.
- **Supuesto**: `SegmentedButton` de M3 (`flutter/material.dart`) está disponible y no requiere upgrade de Flutter. Se valida al implementar T012.
- **Supuesto**: los tests widget del harness no requieren refactor mayor para introducir cuentas archivadas; basta con `db.into(db.accounts).insert(AccountsCompanion.insert(..., archivedAt: Value(DateTime.now())))` en el `setUp`.
- **Supuesto**: el helper `entryAccountLabel` en `movement_row.dart` es un método privado del State o widget; se extiende sin refactor cross-file.
- **Decisión aplazada**: si el menú overflow de `account_form_screen` en modo read-only debería mostrar también "Editar" deshabilitado (para señal explícita) o directamente omitir la opción. Preferencia por omitir para mantener el menú corto.
- **Decisión aplazada**: si el badge de cuenta archivada en el `AccountPicker` debería ser un `Chip` visual pequeño o sólo texto sufijo. Preferencia por sufijo textual `· archivada` en `textSubtle` para no romper el diseño denso del picker.
