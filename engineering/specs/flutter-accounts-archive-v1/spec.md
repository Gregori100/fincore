# Archivar, desarchivar y eliminar cuentas (flutter-accounts-archive-v1)

## Resumen

Separar en tres acciones distintas lo que hoy la UI de cuentas expone como una sola "Archivar cuenta". Actualmente ese botón dispara un soft delete cascada que borra la cuenta y todos sus movimientos, aunque semánticamente el usuario espera preservar el histórico. El sprint introduce una columna `archived_at` independiente de `deleted_at`, tres métodos discretos en `AccountsDao` (`archive`, `unarchive`, `delete`), y separa los flujos de UI, diálogos y pickers para reflejar la nueva semántica. Prerrequisito de `flutter-loans-v1`, donde el cierre limpio de un préstamo depende de poder archivar sin destruir el histórico contable.

## Problema a resolver

- El botón "Archivar cuenta" de `mobile/lib/screens/accounts_list_screen.dart` y `mobile/lib/screens/account_form_screen.dart` invoca `AccountsDao.archive`, que hoy hace soft-delete cascada: setea `deleted_at` en la cuenta y en todos los `journal_entries` donde aparece como origen o destino.
- Efecto observable: la cuenta desaparece de listas, pickers, reportes y del histórico. Todos los movimientos donde figuraba se pierden de vista sin posibilidad de recuperación (sólo via import de un respaldo previo).
- Diego confirmó durante uso real que este comportamiento nunca fue el esperado: "archivar" debería preservar el histórico, no borrarlo. Falta además una acción explícita de eliminación con confirmación destructiva, y no existe forma reversible de sacar una cuenta del picker de nuevos movimientos.
- Sin este split, el módulo de préstamos (`flutter-loans-v1`) no puede cerrar limpio un préstamo saldado sin borrar sus pagos históricos.

## Objetivo

Habilitar tres acciones distintas sobre cuentas no protegidas, cada una con su semántica clara, diálogo apropiado y trazabilidad en la BD:

1. **Archivar** — reversible, oculta la cuenta de flujos de alta pero preserva todo el histórico.
2. **Desarchivar** — reversible, devuelve la cuenta a estado activo.
3. **Eliminar** — destructivo con cascada de movimientos, requiere `DestructiveDialog` con impacto contable.

La Bolsa (cuenta `type=cash`, `is_protected=true`) sigue sin poder archivarse ni eliminarse.

## Alcance

- Nueva columna `archived_at TEXT NULLABLE` en `accounts` (compat con `store_date_time_values_as_text: true`).
- Bump `schemaVersion` 8 → 9 con rama nueva en `MigrationStrategy.onUpgrade` para todas las paths existentes (`from ∈ {1..8}, to == 9`) o al menos `from == 8 && to == 9`, más una rama por cada `from < 8` combinada con `to == 9` si la política actual de `onUpgrade` cubre saltos multi-versión. La rama corre `ALTER TABLE accounts ADD COLUMN archived_at TEXT`. Se conserva el guardrail final que lanza `UnimplementedError` para transiciones no cubiertas.
- Refactor de `AccountsDao` (`mobile/lib/data/daos/accounts_dao.dart`):
  - Renombra el método actual `archive(id, [stateService])` → `delete(id, [stateService])`, sin cambiar su lógica (sigue haciendo soft-delete cascada usando `deleted_at`).
  - Nuevo `archive(id)`: setea `archived_at = DateTime.now()`. Sin cascada. Valida Bolsa protegida.
  - Nuevo `unarchive(id)`: setea `archived_at = null`.
  - Modifica `listAll({includeArchived})` para que el flag ya no confunda con `deleted_at` (renombrar sema: `deleted_at IS NULL` sigue siendo condición base — hard-eliminadas nunca aparecen; `archived_at IS NULL` se agrega cuando `!includeArchived`).
  - Ajusta `watchActive()` a `deleted_at IS NULL AND archived_at IS NULL`.
  - Nuevo `watchArchived()`: `deleted_at IS NULL AND archived_at IS NOT NULL`, mismo ordering que `watchActive`.
  - Nuevo helper `findActiveOrArchivedById(id)` para lecturas de UI que necesitan mostrar aunque esté archivada (formularios read-only, movement_row).
- UI `mobile/lib/screens/accounts_list_screen.dart`:
  - Segmented control `Activas | Archivadas` bajo el AppBar. La lista cambia de stream según el segmento.
  - Card activa: tap abre form de edición. Menú overflow (3 puntos) con `Editar`, `Archivar`, `Eliminar` (rojo).
  - Card archivada: tap abre form en modo read-only. Menú overflow con `Desarchivar`, `Eliminar` (rojo). Icono/color del tipo se pinta con opacidad reducida (`alphaTint` o similar) para señal visual.
- UI `mobile/lib/screens/account_form_screen.dart`:
  - Cuenta activa: reemplaza el `OutlinedButton "Archivar cuenta"` actual por menú overflow en el AppBar con `Archivar` y `Eliminar` (con separador y rojo para Eliminar).
  - Cuenta archivada: form read-only (campos deshabilitados, sin botón Guardar), header visual "Cuenta archivada" con chip o banner. Menú overflow con `Desarchivar` y `Eliminar`.
- UI `mobile/lib/screens/entry_form_screen.dart`:
  - Cuando el `JournalEntry` en edición tiene `account_origin_id` o `account_destination_id` apuntando a una cuenta con `archived_at != null`, el form entero pasa a read-only. Banner superior "Movimiento con cuenta archivada" y explicación breve. Solo se mantiene habilitado el botón `Eliminar movimiento` del footer.
  - AccountPicker de ese form muestra la cuenta archivada seleccionada con badge ` · archivada` en el label, en estado disabled.
- UI `mobile/lib/widgets/account_picker.dart`:
  - Por default filtra `deletedAt == null && archivedAt == null` (activas puras).
  - Nueva prop opcional `bool includeArchived = false`. Cuando true, muestra archivadas al final del listado con sufijo ` · archivada` en el label y color/icono en `textSubtle` para diferenciar.
- UI `mobile/lib/widgets/movement_row.dart`:
  - Si el entry apunta a una cuenta archivada, el helper `entryAccountLabel` (o equivalente) agrega sufijo ` (archivada)` al nombre, con estilo `textSubtle` italic.
- Reportes (`mobile/lib/screens/reports/*.dart` y `mobile/lib/data/reports_service.dart`):
  - Todas las queries siguen incluyendo cuentas archivadas para preservar histórico (filtran solo por `deleted_at IS NULL`, ignoran `archived_at`).
  - Cualquier picker de filtro por cuenta en tabs de reportes (top movements, calendar, etc.) incluye archivadas con badge.
- Diálogos:
  - `Archivar`: `showConfirmDialog` — título "Archivar cuenta", cuerpo "Ya no aparecerá al registrar movimientos, pero sigue en tu histórico y en reportes.", botón "Archivar".
  - `Desarchivar`: `showConfirmDialog` — título "Desarchivar cuenta", cuerpo "Vuelve a estar disponible para registrar movimientos.", botón "Desarchivar".
  - `Eliminar`: `showDestructiveDialog` — `objectName: account.name`, chips de impacto contando movimientos afectados (via helper nuevo `EntriesDao.countByAccount(id)` que suma origen y destino donde `deleted_at IS NULL`), `confirmLabel: 'Eliminar cuenta y movimientos'`, cuerpo "Se borrarán N movimientos donde esta cuenta figura como origen o destino. Esta acción no se puede deshacer.".
- Copy: español neutral (tú, no vos). Guardrail `no_voseo_test.dart` cubre `lib/`.
- Tests:
  - Renombrar tests existentes de `archive` cascada → `delete` para preservar cobertura.
  - Nuevos tests: `archive` no toca movimientos, cuenta desaparece de `watchActive`, aparece en `watchArchived`, movimientos siguen intactos con `deleted_at IS NULL`. `unarchive` la devuelve a `watchActive`. `archive` sobre Bolsa lanza `protected_account`. `delete` sobre Bolsa lanza `protected_account`. Movimiento cuyo origen/destino está archivado se detecta correctamente en `entry_form_screen` (widget test o helper de detección).
- Version bump: `pubspec.yaml` `0.25.6+108` → `0.26.0+109` y `android/app/build.gradle.kts` `versionCode = 109` + `versionName = "0.26.0"`.

## Fuera de alcance

- Categorías: mantienen su comportamiento actual (`deleted_at` como terminal sin cascada de movimientos, solo desasocia FK). Diego rechazó unificar el modelo por diferencia semántica real.
- Bulk archive / bulk delete de cuentas.
- Auditoría / historial de acciones de archivado.
- Reactivación automática de movimientos "cancelados" al desarchivar (los movimientos borrados por un `delete` previo no vuelven jamás; el respaldo JSON es la única vía).
- Toasts, banners o animaciones especiales al desarchivar más allá del `SnackBar` estándar de éxito.
- Cambios en el backup JSON v1. La columna nueva se omite en export; imports v1 asumen `archived_at = null`.
- Módulo de préstamos (sprint siguiente `flutter-loans-v1`).
- Icono/decoración visual de "cuenta archivada" en el listado de cuentas archivadas más allá de la opacidad reducida sobre el tipo (chip badge queda si sobra tiempo).

## Reglas de negocio

- RN-A01: La Bolsa (`type=cash`, `is_protected=true`) no puede archivarse ni eliminarse. Ambos métodos del DAO lanzan `protected_account`.
- RN-A02: Archivar es reversible, no toca movimientos, no requiere que la cuenta esté "vacía".
- RN-A03: Desarchivar es reversible, no tiene precondiciones más allá de que la cuenta exista y esté archivada (`archived_at != null` y `deleted_at == null`).
- RN-A04: Eliminar es destructivo con cascada: setea `deleted_at = now()` en la cuenta y en todos los `journal_entries` donde figura como `account_origin_id` o `account_destination_id`. Idéntico al comportamiento actual de `archive`.
- RN-A05: Una cuenta archivada NO aparece en los pickers de alta de movimientos (`entry_form_screen` en modo new).
- RN-A06: Una cuenta archivada SÍ aparece en pickers de filtro de `/entries` y de reportes con badge `(archivada)`.
- RN-A07: Una cuenta archivada SÍ aparece en todos los reportes (`ReportsService.*`) para preservar histórico. Los reportes filtran únicamente por `deleted_at IS NULL`.
- RN-A08: Un `JournalEntry` con `account_origin_id` o `account_destination_id` apuntando a una cuenta archivada no puede editarse. `entry_form_screen` en modo edición detecta esto y pinta todo read-only. Sólo se permite eliminar el movimiento (sin cascada porque los movimientos no tienen dependientes downstream).
- RN-A09: Archivar y desarchivar dependen sólo del ID; no requieren refrescos externos del `FinancialStateService` porque los balances derivan de `journal_entries` que no cambian.
- RN-A10: El comportamiento actual del método `AccountsDao.archive` se preserva 1:1 bajo el nuevo nombre `AccountsDao.delete`, incluyendo la invocación opcional de `stateService?.invalidateAll()`.
- RN-A11: `watchActive()` sigue devolviendo `deleted_at IS NULL AND archived_at IS NULL` (cuentas totalmente activas). `watchArchived()` devuelve `deleted_at IS NULL AND archived_at IS NOT NULL`.
- RN-A12: Backup JSON v1 no incluye `archived_at`; el import de un backup v1 asume que todas las cuentas quedan como activas (`archived_at = null`). No hay bump de versión de backup en este sprint.
- RN-A13: El guardrail `UnimplementedError` de `onUpgrade` se conserva tras agregar la rama nueva para `schemaVersion 9`.

## Requisitos funcionales

- RF-001: Agregar columna `archived_at TEXT NULLABLE` a la tabla `accounts` y bumpear `schemaVersion` a 9. Añadir la rama correspondiente en `MigrationStrategy.onUpgrade` que ejecuta `ALTER TABLE accounts ADD COLUMN archived_at TEXT`. Preservar el guardrail final `UnimplementedError`.
- RF-002: En `AccountsDao`, renombrar el método `archive(id, [stateService])` a `delete(id, [stateService])` sin cambiar su lógica interna. Actualizar todas las referencias en la app y en tests.
- RF-003: Nuevo método `AccountsDao.archive(id)`: valida que la cuenta exista, no esté ya archivada, no sea la Bolsa. Setea `archived_at = DateTime.now()`. No toca `journal_entries`.
- RF-004: Nuevo método `AccountsDao.unarchive(id)`: valida que la cuenta exista y esté archivada. Setea `archived_at = null`.
- RF-005: Modificar `AccountsDao.watchActive()` para filtrar `deleted_at IS NULL AND archived_at IS NULL`.
- RF-006: Nuevo `AccountsDao.watchArchived()` que devuelve stream de cuentas con `deleted_at IS NULL AND archived_at IS NOT NULL` ordenadas por tipo y nombre.
- RF-007: Modificar `AccountsDao.listAll({includeArchived: false})` para que el flag agregue o no las archivadas, manteniendo siempre `deleted_at IS NULL`.
- RF-008: Nuevo helper `AccountsDao.findActiveOrArchivedById(id)` que devuelve la cuenta si `deleted_at IS NULL` (incluye archivadas), usado por `entry_form_screen` y `movement_row`.
- RF-009: Nuevo helper `EntriesDao.countByAccount(id)` que cuenta `journal_entries` activas (`deleted_at IS NULL`) donde la cuenta figura como origen o destino. Usado por el `DestructiveDialog` para poblar el chip de impacto.
- RF-010: `AccountPicker` gana prop `bool includeArchived = false`. Por default filtra activas. Cuando true, incluye archivadas con badge ` · archivada` en el label y estilo `textSubtle`.
- RF-011: `accounts_list_screen` presenta segmented control `Activas | Archivadas`. Cada segmento tiene su propio stream (`watchActive` / `watchArchived`) y su propio menú overflow por card.
- RF-012: Menú overflow de card activa: `Editar` (default tap), `Archivar` (dispara `showConfirmDialog`), `Eliminar` (dispara `showDestructiveDialog`).
- RF-013: Menú overflow de card archivada: `Desarchivar` (dispara `showConfirmDialog`), `Eliminar` (dispara `showDestructiveDialog`).
- RF-014: `account_form_screen` en modo edición reemplaza el `OutlinedButton "Archivar cuenta"` por menú overflow del AppBar con `Archivar` y `Eliminar`.
- RF-015: `account_form_screen` detecta si la cuenta cargada tiene `archived_at != null` y renderiza en modo read-only: campos deshabilitados, banner superior "Cuenta archivada", sin botón Guardar. Menú overflow con `Desarchivar` y `Eliminar`.
- RF-016: `entry_form_screen` en modo edición detecta si `account_origin` o `account_destination` está archivada (via `findActiveOrArchivedById`). Si es así, renderiza el form completamente read-only con banner "Movimiento con cuenta archivada". Sólo se habilita el botón `Eliminar movimiento` del footer.
- RF-017: `AccountPicker` dentro de `entry_form_screen` en modo edición pasa `includeArchived = true` para poder mostrar la cuenta archivada seleccionada con badge.
- RF-018: `movement_row.dart` detecta cuenta archivada en el entry y agrega sufijo ` (archivada)` al label con estilo `textSubtle` italic.
- RF-019: Los `ReportsService` y todos los tabs de reportes preservan comportamiento actual: filtran por `deleted_at IS NULL` sin considerar `archived_at`.
- RF-020: Los diálogos usan copy en español neutral: Archivar ("Ya no aparecerá al registrar movimientos, pero sigue en tu histórico y en reportes."), Desarchivar ("Vuelve a estar disponible para registrar movimientos."), Eliminar (impact chips + "Se borrarán N movimientos donde esta cuenta figura como origen o destino. Esta acción no se puede deshacer.").
- RF-021: Bumps de versión: `pubspec.yaml` a `0.26.0+109` y `android/app/build.gradle.kts` a `versionCode = 109`, `versionName = "0.26.0"`.

## Casos principales

- Diego archiva una cuenta de débito con 12 movimientos → la cuenta desaparece del picker de nuevo movimiento, pero los 12 movimientos siguen en `/entries`, sus balances contribuyen a BO en el dashboard, y aparecen en los reportes de spending/income por cuenta.
- Diego abre el segmento Archivadas y desarchiva → la cuenta vuelve a la lista Activas y al picker de nuevo movimiento sin cambios en los movimientos.
- Diego elige "Eliminar cuenta" desde el menú overflow → aparece `DestructiveDialog` con chip "12 movimientos afectados" + descripción; confirma → cuenta y movimientos quedan con `deleted_at != null`. Reporte de cash flow del mes anterior ya no incluye esos movimientos.
- Diego edita un movimiento existente donde origen apunta a una cuenta archivada previamente → form abre en read-only con banner. Al pulsar "Eliminar movimiento" el entry queda con `deleted_at != null` (soft delete estándar de entries).
- Diego arma un filtro en `/entries` para revisar movimientos históricos de una cuenta que archivó → el `AccountPicker` del filtro muestra la cuenta con badge `(archivada)` y el filtro funciona igual que con cuentas activas.
- Diego consulta un reporte de spending por cuenta del año pasado → todas las cuentas archivadas aparecen con su total; el label incluye ` (archivada)` para dejar claro el estado actual.

## Casos borde

- Cuenta con 0 movimientos que se archiva y luego se desarchiva → el ciclo no genera efectos secundarios; comportamiento idéntico a una cuenta activa nueva.
- Cuenta archivada que se selecciona por bug/manipulación externa como destino en un nuevo movimiento vía deep link o navegación directa → `EntriesDao.registerX` valida `deletedAt IS NULL` (y opcionalmente `archivedAt IS NULL` para writes) y falla con `invalid_account_type` si el picker no la excluyó; el DAO no confía en el filtro del picker.
- Backup import v1 (formato legacy) sin campo `archived_at` → todas las cuentas se insertan como activas (`archived_at = null`).
- Backup export → no incluye `archived_at`; el JSON sigue exactamente el formato v1 documentado. Cuentas archivadas siguen apareciendo en el export como cuentas normales para no perder trazabilidad histórica al importar en otra instalación.
- Cuenta con préstamo asociado (futuro `flutter-loans-v1`) → fuera de alcance de este sprint pero la semántica queda lista para que el módulo de préstamos pueda archivar la cuenta contenedora sin romper.
- Movimiento tipo `transfer` donde una de las dos cuentas está archivada → RF-016 aplica igual: form read-only completo con banner. Sólo se puede eliminar.
- Movimiento tipo `debt_payment` cuya cuenta destino (credit) está archivada → mismo tratamiento read-only. Al eliminar el movimiento, el balance derivado de la cuenta archivada se recalcula (sube la deuda residual, pero como está archivada Diego ya no la ve activa; sigue apareciendo en reportes con su nuevo balance).
- Cuenta archivada aparece en `top_movements_tab` o similar filtrado por cuenta → el picker de filtro debe mostrarla con badge; RF-010 la habilita.
- `stateService.invalidateAll()` no se invoca en `archive`/`unarchive` porque no cambian ningún balance derivado. Sólo `delete` mantiene la invalidación por convención heredada del método actual.
- Múltiples archivadas simultáneas → cada archivar dispara su propio stream update; la lista se actualiza correcto en `watchArchived`.

## Criterios de aceptacion

- `flutter analyze` en `mobile/` sin errores nuevos (hint cosmético existente en `widgets/skeleton.dart:75` sigue tolerable).
- `flutter test` verde: los tests renombrados de `archive → delete` pasan sin cambios de comportamiento; nuevos tests de `archive`/`unarchive` verifican estado de `archived_at` y aislamiento de `journal_entries`.
- `schemaVersion` en `mobile/lib/data/database.dart` == 9 y existe rama nueva en `onUpgrade` para `from < 9 → to == 9` cubriendo la columna nueva. El guardrail final sigue lanzando `UnimplementedError` para transiciones desconocidas.
- Manual smoke Android: archivar una cuenta débito con movimientos → desaparece de picker `/entries/new` pero sigue en `/entries` con filtros y en reportes. Desarchivar → vuelve a picker. Eliminar → dispara `DestructiveDialog` con conteo real de movimientos; al confirmar la cuenta y movimientos desaparecen de todos los lugares.
- Manual smoke: editar un movimiento cuya cuenta origen está archivada → todo read-only con banner; sólo el botón Eliminar del footer funciona.
- Manual smoke: segmented `Activas | Archivadas` en `/accounts` cambia el stream y el menú overflow por card corresponde al segmento.
- Manual smoke: la Bolsa no ofrece ni "Archivar" ni "Eliminar" en su menú overflow (o los ofrece deshabilitados con tooltip explicativo). Intento vía DAO (test) lanza `protected_account`.
- Backup export/import round-trip funciona igual con cuentas archivadas presentes (importa como activas; ese comportamiento queda documentado en el spec y en un test).
- `scripts/verify-apk.sh` compara `versionCode` del APK arm64 contra `+109` esperado por `pubspec.yaml` sin desincronía.
- Los tests widget de `dashboard_screen`, `entry_form_screen`, `list_screens` siguen verdes tras la migración (o se actualizan mínimamente para reflejar los nuevos filtros).

## Criterios medibles de exito

- 3 acciones distintas expuestas en UI (Archivar, Desarchivar, Eliminar), cada una con su diálogo apropiado. Verificable por conteo de handlers y screenshots del sprint.
- 0 pérdida de histórico al archivar: para una cuenta con N movimientos previos, al archivar todos los N movimientos siguen apareciendo en `/entries` sin filtros extra y en reportes de cash flow. Verificable por test de integración + smoke manual.
- ≥ 1 test nuevo por método del DAO (`archive`, `unarchive`, `delete` renombrado). Objetivo: llevar `test/data/database_test.dart` de 30 → ≥ 34 tests en la sección de `AccountsDao`.
- 0 regresiones en reportes: los totales de BO/DE/CR + `spendingByCategory` + `incomeByCategory` calculados antes y después de archivar una cuenta con movimientos coinciden bit a bit.
- ≤ 3 pixels de shift visual en `accounts_list_screen` entre el estado actual y el segmentado. Verificable por comparación de screenshots side-by-side en el smoke.
- Bump exitoso: APK build arm64 con `versionCode == 109` instalable con `adb install -r` sin `INSTALL_FAILED_VERSION_DOWNGRADE`.

## Riesgos

- **Migración de schema en dispositivos con datos reales**: la rama nueva de `onUpgrade` debe cubrir todos los saltos posibles desde versiones previas (1..8 → 9). Riesgo de crash si Diego (o cualquier tester) actualiza desde una versión anterior no cubierta. Mitigación: agregar la rama `from == 8 && to == 9` y validar que las ramas cascadeadas existentes (`from < 8 → to == 8`) sigan corriendo. Alternativa segura: rama única `to == 9` que se aplica siempre tras las ramas previas de la cadena.
- **Confusión conceptual `deleted_at` vs `archived_at`**: el DAO actual usa `deleted_at` como semántica de "archivado". El refactor renombra métodos pero mantiene la columna. Riesgo de que algún callsite quede con lectura inconsistente. Mitigación: audit de todos los `deletedAt` en `mobile/lib/**` durante `spec-implementar` y checklist explícito en el sprint.
- **Tests widget existentes rompen por el nuevo segmented control**: `test/screens/list_screens_test.dart` monta `accounts_list_screen` y espera cierta jerarquía de widgets. Riesgo bajo, pero requiere adaptar los widget tests si el segmented control cambia el árbol.
- **Backup import v1 sin `archived_at`**: si Diego importa un backup viejo, las cuentas archivadas anteriores (que había marcado con el método destructivo) no vuelven — ya fueron soft-deleted. Riesgo: usuario espera "recuperar cuenta archivada al importar" y no funciona. Mitigación: copy claro en la pantalla de import + supuesto documentado.
- **Detección de "cuenta archivada" en `entry_form_screen`**: el form actual carga cuentas via streams. Añadir el check de `archivedAt != null` requiere leer la cuenta directamente (no via picker filtrado). Si el check falla o se olvida, un movimiento con cuenta archivada podría quedar editable y romper la semántica. Mitigación: helper explícito `_isEntryReadOnly(entry, accounts)` con test unitario.
- **Regresión en reportes por filtro inconsistente**: si algún `ReportsService.*` filtra por `archived_at IS NULL` sin querer, se pierden movimientos históricos. Mitigación: audit + checklist explícito.
- **Semántica de menú overflow en cuenta activa vs archivada**: si el AppBar cambia según el estado y el usuario no lo espera, hay fricción. Mitigación: usar el mismo icono (3 puntos) en ambos casos, sólo cambian las opciones. Documentado en la spec.
- **`stateService.invalidateAll()` en `unarchive`**: no debería ser necesario pero puede haber balances cacheados que no refresquen. Mitigación: verificar en smoke que el dashboard refleje la cuenta desarchivada de inmediato; si no, agregar `invalidateAll()`.

## Supuestos

- El actual `AccountsDao.archive` es el único callsite de "archivar cuenta" en la app. El renombre a `delete` no rompe integraciones externas porque no las hay.
- Los tests widget de `accounts_list_screen` toleran un `SegmentedButton` adicional sin cambios profundos; en el peor caso se ajustan localizadores.
- El `DestructiveDialog` existente ya acepta chips de impacto y `objectName`; no requiere features nuevas.
- El helper `entryAccountLabel` en `movement_row.dart` acepta agregar sufijo sin refactor; si no existe se crea inline.
- `store_date_time_values_as_text: true` cubre el round-trip de `archived_at` sin trabajo extra en `build.yaml`.
- Los reportes existentes están escritos como `deletedAt.isNull()` sin filtros implícitos por `archived_at`; el sprint no toca esas queries.
- Diego prefiere NO exigir bump de backup JSON para no romper compatibilidad con exports de la versión anterior; si más adelante decide agregar `archived_at` al backup será en un bump a v2 (posiblemente junto con `flutter-loans-v1`).
- El copy de banners y diálogos usa strings inline (no ARB / i18n): la app es single-locale español.
- No hay flujos de sync remoto pendientes que se afecten; la app sigue local-first según CLAUDE.md.

## Impacto esperado

- Diego puede archivar cuentas ya no operativas (una tarjeta que dejó de usar, una cuenta bancaria que cerró) sin perder el histórico de gastos. Esto hace que la libreta digital sea usable a largo plazo.
- El módulo `flutter-loans-v1` queda desbloqueado: cerrar un préstamo saldado archiva la cuenta contenedora sin borrar los 36 pagos históricos.
- La UI de gestión de cuentas se vuelve más honesta: cada acción hace lo que dice. Elimina la confusión que Diego reportó ("archivar en realidad elimina").
- Reportes históricos ganan integridad: los balances y cash flow del pasado no se distorsionan porque una cuenta ahora inactiva no fue borrada por accidente.
- Base para futuros sprints: la separación `archived_at` / `deleted_at` es un patrón replicable si otras entidades del dominio necesitan tres estados (Activo / Archivado / Eliminado). Por ahora sólo cuentas.
