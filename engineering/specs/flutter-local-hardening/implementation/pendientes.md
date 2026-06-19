# Pendientes — flutter-local-hardening

Items fuera de alcance del sprint + descubiertos durante la ejecución que conviene retomar en sprints futuros.

## Fuera de alcance declarados en la spec

- **M6**: firma de release con clave privada para Play Store. APK sigue firmado con la clave debug (válido para sideload).
- **M11**: export en streaming para JSON gigantes. Hoy no hay volumen alto; se difiere hasta evidencia empírica de OOM.
- **M17**: filtro por categoría en `entries_list_screen`. Es feature visible, va al sprint de reportes futuro.
- **M19**: hints `prefer_const_constructors` en `skeleton.dart:75` y `entry_form_screen.dart:260/262`. Cosméticos.
- **M24**: typing fantasma en `DropdownMenu` M3. Comportamiento del widget de Material 3.
- **M25**: loader de progreso en `FirstRunScreen` durante import grande. Aceptable hoy.

## Descubiertos durante la ejecución

- **Downgrade `0.3.0+30` → `0.2.0+29` no soportado**: una vez que la BD migró a `schemaVersion = 2`, instalar el APK viejo `0.2.0+29` puede crashear porque drift espera schema 1 y encuentra 2. La práctica segura es `wipeAll()` antes del downgrade, lo cual borra datos. Documentar en `pendientes.md` del sprint MVP también si Diego querría preservarlo.
- **`@DriftDatabase(tables: ...)` sin `daos: [...]`**: como los DAOs no están registrados en la database, `attachedDatabase.categoriesDao` no se genera. En `EntriesDao.updateEntry` se hizo query inline equivalente a `findActiveById`. Si en un sprint futuro se decide registrar los DAOs en `@DriftDatabase(daos: [AccountsDao, CategoriesDao, EntriesDao])`, regenerar `database.g.dart` y reemplazar la query inline por la delegación.
- **Helper `buildPayload` en `backup_test.dart`** sin underscore por convención de tests (`no_leading_underscores_for_local_identifiers`). Se mantiene público dentro del scope del archivo.
- **`isNull` matcher vs drift**: ambos exportan el símbolo. En este sprint cambié los 2 usos a `equals(null)`. Si futuros tests necesitan el matcher de flutter_test, importar con prefijo (`import 'package:flutter_test/flutter_test.dart' show isNull as nullMatcher;`).
- **Tests de migración de schema**: el plan sugería simular BD con `schemaVersion = 1` y validar el `onUpgrade(1, 2)`. En SQLite in-memory esto es complejo porque drift configura la versión al abrir. Se omitió en este sprint; queda como cobertura en smoke manual de Diego (T023) que instala APK nuevo sobre BD vieja. Para sprint futuro: explorar `_executeMigrationAtVersion(1)` con drift testing tools.
- **`BackupError` y `DomainError` no comparten jerarquía**: por eso T009 agregó `backupErrorToMessage` separado. Refactor a `sealed class FincoreError` queda como mejora estética para sprint futuro.

## Backlog técnico heredado del MVP

Estos siguen vivos del sprint anterior:

- **Widget tests T043-T045**: aplazados en MVP. Aún no se implementaron en este sprint. Conviene atacarlos cuando aparezca regresión UI silenciosa.
- **Reactivación de archivados**: hoy archive es terminal.
- **Edición de `kind` en movimiento**: hoy bloqueado por contrato del DAO.
- **Multi-usuario / multi-cuenta**: la app es single-user por diseño.
- **Sync con backend (spec futura)**: cuando Diego decida agregar login.
- **Reportes y exportes a Excel**: el cliente Vue legacy tenía suite completa.
- **Plan engine** (proyección con eventos recurrentes).
- **Modelos duplicados** entre `lib/models/` y drift.
- **`flutter_launcher_icons.yaml` redundante** con el bloque dentro de `pubspec.yaml`.
- **Pipeline CI**: para distribución a familia/amigos.
- **CHANGELOG formal**.
