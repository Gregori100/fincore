# Implementation Review: flutter-accounts-archive-v1

## Resumen de lo implementado

Se separó el botón antiguo "Archivar cuenta" (que hacía soft-delete cascada) en tres acciones distintas: `archive` (reversible, preserva histórico), `unarchive` (revierte archive) y `deleteAccount` (destructivo cascada — comportamiento heredado). El schema ganó una columna `archived_at` en `accounts` con bump `schemaVersion 8 → 9`. La UI de `accounts_list_screen` gana un segmented `Activas | Archivadas`, cada card gana menú overflow, y `account_form_screen` reemplaza el `OutlinedButton` inline por menú overflow en el AppBar más un modo read-only para cuentas archivadas. `entry_form_screen` detecta movimientos con cuenta archivada y bloquea la edición dejando solo el botón Eliminar activo. Se agregaron badges `(archivada)` en `movement_row` y prop `includeArchived` en `AccountPicker`. Los reportes no cambian (siguen filtrando sólo por `deleted_at IS NULL`). Version bump `0.25.6+108 → 0.26.0+109`.

## Archivos principales modificados

- `mobile/lib/data/database.dart` — columna `archivedAt`, schema 9, 3 ramas nuevas en `onUpgrade` (6→9, 7→9, 8→9).
- `mobile/lib/data/database.g.dart` — regenerado.
- `mobile/lib/data/daos/accounts_dao.dart` — rename `archive` → `deleteAccount`, nuevos `archive`, `unarchive`, `watchArchived`, `findActiveOrArchivedById`. `watchActive` y `listAll` filtran `archivedAt`.
- `mobile/lib/data/financial_state.dart` — comentario actualizado al nombre nuevo `deleteAccount`.
- `mobile/lib/widgets/account_picker.dart` — prop `includeArchived`, badge visual `· archivada`, estilo `textSubtle`.
- `mobile/lib/widgets/entry_account_label.dart` — sufijo `(archivada)` + nuevo helper `entryHasArchivedAccount`.
- `mobile/lib/widgets/movement_row.dart` — estilo italic + `textSubtle` cuando `entryHasArchivedAccount`.
- `mobile/lib/screens/accounts_list_screen.dart` — reescrito con `SegmentedButton`, `_AccountRowMenu`, handlers de archivar/desarchivar/eliminar.
- `mobile/lib/screens/account_form_screen.dart` — reescrito: menú overflow AppBar, `_ArchivedBanner`, modo read-only, 3 handlers separados.
- `mobile/lib/screens/entry_form_screen.dart` — getter `_lockedByArchivedAccount`, banner `_ArchivedEntryBanner`, `AbsorbPointer` en pickers + `enabled: !locked` en fields.
- `mobile/pubspec.yaml` — `0.26.0+109`.
- `mobile/android/app/build.gradle.kts` — `versionCode = 109`, `versionName = "0.26.0"`.
- Tests: `test/data/accounts_archive_test.dart` nuevo (24 tests). Rename `archive` → `deleteAccount` en `test/data/{database,invariants,financial_state,reports}_test.dart`.

## Tareas completadas

- T001-T003 Base de datos: columna, `schemaVersion=9`, migración multi-salto, regen.
- T004-T012 Backend: rename + nuevos métodos + streams + helpers + comentario `financial_state`.
- T013-T014 Widgets: `AccountPicker.includeArchived` + `movement_row` con sufijo.
- T015-T016 `accounts_list_screen` con segmented + overflow.
- T017-T018 `account_form_screen` con overflow AppBar + modo read-only.
- T019 `entry_form_screen` con detección + banner + read-only.
- T020 Auditoría reportes: cero cambios necesarios (todos filtran sólo `deleted_at`).
- T021-T028 Tests: rename + 24 tests nuevos + suite completa 735/735 verde.
- T029, T031 Bump versión + build APK arm64 exitoso (21.5MB).
- T030 Doc CLAUDE.md: se omitió para mantener el commit chico. La info equivalente vive en la spec del sprint (`engineering/specs/flutter-accounts-archive-v1/spec.md`) y basta de referencia.

## Tareas pendientes

- T030 CLAUDE.md update: opcional, no bloqueante. La documentación del sprint está en `engineering/specs/`.
- T032 Smoke manual Android: pendiente para Diego. Instalar el APK arm64 con `adb install -r build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` y correr los 15 items del checklist en `plan/test-plan.md`.
- T033 `branch-quality-review`: pendiente si Diego quiere invocarlo antes del merge.

## Riesgos residuales

- **Migración desde `schemaVersion < 6`**: la política del repo sólo cubre saltos desde 6, 7 u 8. Instalaciones con `from < 6` seguirían chocando con el guardrail `UnimplementedError` como antes de este sprint. No es regresión, es estado preservado.
- **Backup import v1**: cuentas que Diego "archivó" con el método destructivo antiguo (que en realidad las eliminó) no se recuperan al importar un backup previo — están con `deleted_at != null` y no en el export. Se puede documentar en el Settings > Respaldo si aparece confusión.
- **Widget tests no cubren pantallas nuevas**: no se agregaron tests widget para el `SegmentedButton` de `accounts_list_screen` ni para el banner de `entry_form_screen` en modo bloqueado. Los cambios son mayormente estructurales y el compile+analyze+DAO tests dan cobertura. Widget tests puntuales son buen candidato para un follow-up.
- **`AbsorbPointer` en pickers**: `AccountPicker` y `CategoryPicker` quedan envueltos en `AbsorbPointer + Opacity` cuando el entry está bloqueado. Si Flutter agrega un focus programático al dropdown mientras el AbsorbPointer está activo, podría haber comportamiento inesperado. No es probable pero conviene notarlo.
- **`unarchive` sobre Bolsa**: por consistencia rechaza con `protected_account`, pero la Bolsa nunca puede llegar al estado archivada porque `archive` sobre ella también rechaza. Es "cinturón + tirantes".

## Pruebas realizadas

- `flutter analyze`: 5 issues, todos preexistentes (`prefer_const_constructors` en `entry_form_screen.dart` líneas 493, 494, 496, 1015, 1022) que ya estaban antes del sprint. Cero errores nuevos.
- `flutter test`: **735/735 verde** (base 711 + 24 nuevos del sprint).
- Nuevos tests DAO en `test/data/accounts_archive_test.dart`:
  - 5 tests `archive`: setea archivedAt, no toca entries, Bolsa protegida, not_found, idempotencia.
  - 4 tests `unarchive`: limpia archivedAt, no-op silencioso, Bolsa protegida, not_found.
  - 3 tests streams: `watchActive` excluye archivadas, `watchArchived` sólo devuelve archivadas, excluye eliminadas.
  - 3 tests `listAll`: default excluye archivadas, `includeArchived: true` las incluye, nunca eliminadas.
  - 4 tests `findActiveOrArchivedById`: activa, archivada, eliminada (null), inexistente (null).
  - 1 test semántica reportes: entry sobre cuenta archivada preserva relación.
  - 3 tests `countAssociatedEntries`: 0/N/ignora cancelados.
  - 1 test round-trip schemaVersion 9: `archived_at` persiste en insert directo.
- Rename tests existentes `accountsDao.archive` → `accountsDao.deleteAccount` en 4 archivos, sin cambio de expectativas — todos siguen verdes.
- Build APK release `arm64-v8a` completado sin errores.

## Pruebas recomendadas

Smoke manual en cel según `plan/test-plan.md` sección "Pruebas manuales o smoke tests necesarios" (15 items). Los que más importan:

- Archivar una cuenta débito con movimientos → confirmar que los movimientos siguen en `/entries` y en reportes.
- Desarchivar → cuenta vuelve al picker de alta.
- Eliminar → `DestructiveDialog` con conteo real de movimientos.
- Editar un movimiento con cuenta archivada → banner + form read-only + sólo botón Eliminar habilitado.
- Bolsa: menú overflow no aparece.
- Backup export → import round-trip: cuentas archivadas se re-importan como activas (comportamiento esperado).

## Posibles regresiones

- **Test suite completa 735/735 verde** cubre regresiones estáticas (schema, DAO, reportes, widget existentes). No hubo cambios en fórmulas de balances, ni en imports/exports, ni en algoritmos de reportes.
- **Pickers en modo new**: siguen sin ofrecer archivadas por default (`includeArchived: false`). Sin cambio de UX.
- **Migración `from == 5`** o menor: sin cambio respecto al comportamiento previo del repo (que ya no tenía ramas para esos saltos hacia el schema >5).

## Recomendaciones para code review humano

- Verificar que las ramas `from == {6,7,8} && to == 9` de `onUpgrade` no rompen la lógica ya validada de `from == {6,7} && to == 8`. Se replicó el SQL literal, no se refactorizó.
- Revisar visualmente el `SegmentedButton` en cel — si el tema oscuro no da suficiente contraste al segmento seleccionado, se puede ajustar `style`.
- Confirmar que el sufijo `(archivada)` en `movement_row` no rompe el layout con nombres largos (posible ellipsis prematura). Si molesta, se puede quitar del label del row y dejar sólo el italic + `textSubtle` como señal.
- El `_ArchivedBanner` y `_ArchivedEntryBanner` usan `categoryPurple` como color de acento por consistencia con el `credit` type (hotfix del sprint anterior). Alternativa: `accent` azul.
- Considerar un follow-up para agregar widget tests puntuales (`accounts_list_screen` con segmented, `entry_form_screen` en modo bloqueado). No bloqueante pero da confianza para futuros refactors.
