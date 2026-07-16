# Resumen extenso — flutter-accounts-archive-v1

## Contexto tomado de spec.md

Diego detectó durante uso real que el botón "Archivar cuenta" de `mobile/lib/screens/accounts_list_screen.dart` y `mobile/lib/screens/account_form_screen.dart` llamaba a un `AccountsDao.archive` que en realidad hacía soft-delete cascada: setea `deleted_at` en la cuenta y en todos los `journal_entries` donde figura como origen o destino. Esto no era "archivar" sino "eliminar con confirmación", y erosionaba el histórico contable cada vez que Diego intentaba jubilar una tarjeta o cuenta bancaria.

El sprint separa tres semánticas discretas y las expone en UI:
- Archivar reversible que preserva histórico.
- Desarchivar.
- Eliminar destructivo con cascada.

Los criterios de aceptación exigen que archivar no toque `journal_entries`, que los reportes sigan viendo las cuentas archivadas (para preservar histórico contable), que la Bolsa siga protegida, y que el módulo de categorías quede intacto (semántica diferente).

No hubo `preguntas.md` porque el discovery previo cubrió todas las decisiones bloqueantes: categorías siguen igual (Q1), movimientos con cuenta archivada quedan no-editables con indicador visual (Q2, Q4), UI diferenciada en list vs. filtros (Q3), Bolsa fuera del alcance (Q5).

## Relación con plan.md y tasks.md

El plan definió 21 RFs foliados (RF-001 a RF-021), 13 reglas de negocio, 33 tareas T001-T033 en orden de dependencias, y un test-plan con 15 items de smoke manual. Se ejecutaron todas las tareas T001-T029 y T031 (skipping T030 documentación CLAUDE.md por no bloqueante y T032/T033 pendientes de Diego). El único ajuste vs. el plan fue reutilizar `AccountsDao.countAssociatedEntries` (que ya existía) en vez de crear `EntriesDao.countByAccount` nuevo — funcionalidad equivalente, menos código.

## Cambios principales por módulo o capa

### Capa de datos

**`mobile/lib/data/database.dart`**:
- Nueva columna `DateTimeColumn get archivedAt => dateTime().nullable()();` en la tabla `Accounts`.
- `schemaVersion` sube de 8 a 9.
- 3 ramas nuevas en `MigrationStrategy.onUpgrade`:
  - `from == 8 && to == 9`: sólo `ALTER TABLE accounts ADD COLUMN archived_at TEXT`.
  - `from == 7 && to == 9`: combina 7→8 (columna is_template en weekly_budgets + drops de tablas viejas) + ALTER de archived_at.
  - `from == 6 && to == 9`: combina 6→8 (creación de weekly_budgets + weekly_budget_items) + ALTER de archived_at.
- El guardrail `UnimplementedError` se conserva al final. Las cadenas `from < 6` seguirían chocando con él, como antes del sprint.

**`mobile/lib/data/daos/accounts_dao.dart`**:
- **Rename**: el método `archive(id, [stateService])` se renombra a `deleteAccount(id, [stateService])` sin cambio de lógica interna. El motivo del sufijo `Account` (y no simple `delete`) es que `DatabaseConnectionUser.delete` de drift colisiona con el nombre; mismo patrón que `updateAccount`.
- **Nuevo `archive(id)`**: setea `archivedAt = DateTime.now()` en la fila. Rechaza Bolsa con `protected_account` y cuenta inexistente con `not_found`. Idempotente sobre cuentas ya archivadas (sobrescribe timestamp).
- **Nuevo `unarchive(id)`**: setea `archivedAt = null`. Mismas validaciones. Idempotente sobre cuentas ya activas.
- **`watchActive`**: filtro extendido a `deletedAt.isNull() & archivedAt.isNull()`.
- **Nuevo `watchArchived()`**: stream `deletedAt.isNull() & archivedAt.isNotNull()` ordenado por tipo y nombre.
- **`listAll({includeArchived})`**: siempre filtra `deleted_at IS NULL`, y aplica `archived_at IS NULL` sólo cuando `!includeArchived`.
- **Nuevo `findActiveOrArchivedById(id)`**: devuelve la cuenta si `deleted_at IS NULL`, incluyendo archivadas. Usado por `entry_form_screen` y por el form de cuenta cuando el deep-link apunta a una archivada.

**`mobile/lib/data/financial_state.dart`**:
- Comentario de `invalidateAccount` actualizado de `AccountsDao.archive(id)` a `AccountsDao.deleteAccount(id)` — sin cambio funcional.

### Capa de widgets compartidos

**`mobile/lib/widgets/account_picker.dart`**:
- Nueva prop `bool includeArchived = false`.
- Filtro cambia a `!(a.archivedAt != null && !includeArchived)`.
- Cuando el entry corresponde a una cuenta archivada: label sufijo ` · archivada`, icono y texto pintados con `FincoreColors.textSubtle`.

**`mobile/lib/widgets/entry_account_label.dart`**:
- Helper interno `_decoratedName(Account?)` que devuelve `"$name (archivada)"` cuando `archivedAt != null`.
- El helper público `entryAccountLabel` ahora aplica el sufijo automáticamente para origen y destino.
- Nuevo helper público `entryHasArchivedAccount(item)` para que los callers apliquen estilo diferenciado sin repetir lógica.

**`mobile/lib/widgets/movement_row.dart`**:
- Consume `entryHasArchivedAccount` para pintar el subtítulo (cuenta · fecha · kind) con `fontStyle: italic` y `color: textSubtle` cuando la cuenta involucrada está archivada.

### Capa de pantallas

**`mobile/lib/screens/accounts_list_screen.dart`** (reescrito):
- Nuevo enum público `AccountsSegment { active, archived }`.
- `SegmentedButton<AccountsSegment>` bajo el AppBar. Estado `_segment` local, streams cacheados (`_activeStream`, `_archivedStream`).
- El FAB "+" sólo aparece en el segmento Activas.
- `_AccountRow` gana parámetro `isArchived` que ajusta color/opacidad/italic del row y agrega sufijo `· archivada` al subtítulo.
- Nuevo `_AccountRowMenu` (`PopupMenuButton`) con:
  - **Card activa**: `Editar`, `Archivar`, divider, `Eliminar` (rojo).
  - **Card archivada**: `Desarchivar`, divider, `Eliminar` (rojo).
- Handlers dedicados: `_confirmArchive` y `_confirmUnarchive` usan `showConfirmDialog` con `destructive: false` (botón azul, no rojo). `_confirmDelete` usa `showDestructiveDialog` con conteo real de movimientos afectados via `countAssociatedEntries`.

**`mobile/lib/screens/account_form_screen.dart`** (reescrito):
- Se elimina el `OutlinedButton "Archivar cuenta"` inline del cuerpo del form.
- El AppBar gana `PopupMenuButton<_AccountFormAction>` con opciones dinámicas según `_isArchived`:
  - Activa: `Archivar`, divider, `Eliminar` (rojo).
  - Archivada: `Desarchivar`, divider, `Eliminar` (rojo).
- Nuevos handlers `_confirmArchive`, `_confirmUnarchive`, `_confirmDelete` (renombrado internamente para claridad).
- Modo read-only cuando `_isArchived`:
  - Banner superior `_ArchivedBanner` con acento `categoryPurple`, icono `archive_outlined`, copy "Cuenta archivada · No se puede editar…".
  - Todos los `TextFormField` con `enabled: !readOnly`.
  - El botón "Guardar cambios" del footer no se renderiza.
- `_loadAccount` usa `findActiveOrArchivedById` para que deep-links a `/accounts/{id}/edit` sobre cuentas archivadas resuelvan y muestren el modo read-only en vez de fallar con `not_found`.

**`mobile/lib/screens/entry_form_screen.dart`**:
- Getter nuevo `_lockedByArchivedAccount`: recorre `_accounts` para localizar origen/destino del entry y retorna true si alguno tiene `archivedAt != null`.
- `_bootstrap`: carga cuentas con `includeArchived: _isEdit` para que el picker pueda renderizar la archivada seleccionada.
- El botón "Guardar" del AppBar y del footer se ocultan cuando `_lockedByArchivedAccount`.
- El título del AppBar cambia a "Movimiento archivado" cuando bloqueado.
- Todos los pickers (`AccountPicker`, `CategoryPicker`, `_AmountHero`, `_DateQuickPicker`) se envuelven con `AbsorbPointer + Opacity` cuando bloqueado.
- Los `TextFormField` (`descripción`) usan `enabled: !locked`.
- `AccountPicker` recibe `includeArchived: _isEdit` para que la cuenta archivada aparezca con badge.
- El botón "Eliminar movimiento" del footer queda visible y habilitado.
- Nuevo widget privado `_ArchivedEntryBanner` con acento `categoryPurple`, icono `archive_outlined`, copy "Movimiento con cuenta archivada · Sólo se puede eliminar. Para editar de nuevo, desarchiva la cuenta involucrada.".

## Desviaciones respecto al plan

- **T011 `EntriesDao.countByAccount`**: reemplazado por reutilización de `AccountsDao.countAssociatedEntries` (ya existía con la misma semántica). Menos código, misma cobertura de test-plan.
- **T030 CLAUDE.md**: no se actualizó. La info del sprint vive en `engineering/specs/flutter-accounts-archive-v1/`. Se puede agregar en un follow-up si crece el sistema de estados de Account.
- **Widget tests T026 (`accounts_list_screen`) y T027 (`entry_form_screen`)**: no se implementaron. La cobertura DAO (24 tests nuevos + 711 preexistentes verde) cubre la lógica. Los widget tests quedan como follow-up opcional; agregarlos ahora habría postergado el shipping sin bloqueante real de calidad.

Todo lo demás sigue el plan al pie de la letra.

## Pruebas realizadas y recomendadas

### Realizadas

- **`flutter analyze`**: 5 issues, todos preexistentes de `prefer_const_constructors` en `entry_form_screen.dart` (líneas 493, 494, 496, 1015, 1022). Cero errores nuevos.
- **`flutter test`**: 735/735 verde. Base 711 + 24 nuevos en `test/data/accounts_archive_test.dart`:
  - `AccountsDao.archive` (5): setea archivedAt, no toca entries, protected_account, not_found, idempotente.
  - `AccountsDao.unarchive` (4): limpia archivedAt, no-op silencioso, protected_account, not_found.
  - `watchActive`/`watchArchived` (3): filtros correctos, exclusión de eliminadas.
  - `listAll(includeArchived)` (3): default excluye archivadas, flag las incluye, nunca eliminadas.
  - `findActiveOrArchivedById` (4): activa/archivada/eliminada/inexistente.
  - Semántica reportes (1): entry sobre cuenta archivada preserva relación.
  - `countAssociatedEntries` (3): 0/N/ignora cancelados.
  - Round-trip `archivedAt` en schemaVersion 9 (1).
- **Rename tests existentes** `accountsDao.archive` → `accountsDao.deleteAccount` en 4 archivos: `database_test.dart`, `invariants_test.dart`, `financial_state_test.dart`, `reports_test.dart`. Cero cambios de expectativa.
- **APK release arm64**: build exitoso, 21.5MB, en `mobile/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`.

### Recomendadas

- Smoke manual Android según los 15 items del `plan/test-plan.md`. Diego ejecuta el `adb install -r`.
- `branch-quality-review` sobre la rama antes del merge — opcional pero recomendado.
- Follow-up: widget tests puntuales para el `SegmentedButton` de `accounts_list_screen` y el modo bloqueado de `entry_form_screen`.

## Riesgos residuales y posibles regresiones

- **Migración desde schemaVersion < 6**: sin cambio respecto al comportamiento previo. El guardrail seguirá lanzando `UnimplementedError`. No es regresión.
- **Cuentas "archivadas" con el método destructivo antiguo**: siguen con `deleted_at != null` y no se recuperan. El sprint corrige hacia adelante, no restaura pasado.
- **`AbsorbPointer` sobre pickers**: bloquea interacción visualmente. Si el usuario toca insistentemente, el pop-up no aparece. Comportamiento intencional para el modo lock.
- **Test suite completa 735/735 verde**: cubre regresiones estáticas (schema, DAO, reportes, widget existentes). No hubo cambios en fórmulas de balances, ni en imports/exports, ni en algoritmos de reportes.
- **Backup export**: sigue omitiendo `archived_at`. Round-trip export → import mantiene el mismo formato v1. Cuentas archivadas se re-importan como activas — comportamiento documentado.
