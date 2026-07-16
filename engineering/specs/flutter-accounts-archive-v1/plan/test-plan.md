# Plan de pruebas — flutter-accounts-archive-v1

## Casos borde detectados

- Cuenta archivada que se elimina después: `delete` sobre `archived_at != null` funciona; setea `deleted_at = now`, cascada en `journal_entries`. Combinación válida `deleted_at NOT NULL AND archived_at NOT NULL`.
- Cuenta archivada que se re-archiva: llamar `archive` sobre una cuenta ya archivada debe ser no-op silencioso (sin error, sin cambiar `archived_at` original o sobrescribiéndolo con nuevo timestamp — decisión: sobrescribir para simplicidad).
- Cuenta activa que se re-desarchiva: `unarchive` sobre `archived_at == null` es no-op silencioso.
- Bolsa (`is_protected=true`, `type=cash`): las 3 acciones (`archive`, `unarchive`, `delete`) lanzan `protected_account`.
- Cuenta no existente: `archive(id)` con id inexistente lanza `not_found` o retorna sin efecto (decisión: retornar sin efecto siempre que el update no afecte filas, alineado con drift's `update().write()` que retorna 0).
- Import de backup v1 sin campo `archived_at`: todas las cuentas se insertan como activas.
- Movimiento tipo `transfer` con ambas cuentas archivadas: `entry_form_screen` en modo edit muestra banner read-only.
- Movimiento tipo `debt_payment` cuya destino (credit) fue archivada: form read-only. Al eliminar, el balance derivado de la credit archivada cambia (se recomputa on-the-fly).
- Múltiples archivadas simultáneas dentro de la misma sesión: `watchArchived` se re-emite en cada `archive`.
- Cuenta con 0 movimientos que se archiva: la cascada de UI no dispara error; el `DestructiveDialog` para eliminar mostraría "0 movimientos" en el chip de impacto (visual OK).
- Cuenta con muchos movimientos (>1000): `EntriesDao.countByAccount` no debería ser lento en single-user pero verificar que el COUNT usa un índice o al menos escanea eficientemente (`journal_entries` tiene índice en `account_origin_id`, `account_destination_id`, `deleted_at`).
- Deep link a `/accounts/{id}/edit` con id de cuenta archivada: la pantalla carga en modo read-only sin error.
- Deep link a `/entries/new` con default account que fue archivada: el picker no la ofrece; la app no crashea.
- Timezone: `archived_at` se guarda como `DateTime.now()` UTC o local según `store_date_time_values_as_text: true`. Coincide con el patrón de `deleted_at` existente.
- Concurrencia: al ser single-user local, no aplica.
- Rollback in-flight: si la app se cierra durante `archive`, la transacción de drift asegura atomicidad (single-row update).
- Reintentos: no aplica.

## Pruebas unitarias necesarias

- `test/data/database_test.dart` o `test/data/accounts_archive_dao_test.dart`:
  - `archive(id)` setea `archived_at != null` en la cuenta objetivo.
  - `archive(id)` no toca `journal_entries` (verificar count antes y después).
  - `archive(id)` sobre cuenta activa con N movimientos: los N movimientos siguen con `deleted_at IS NULL`.
  - `archive(id)` sobre Bolsa lanza `AccountsDaoError('protected_account', ...)`.
  - `archive(id)` sobre cuenta ya archivada: no-op sin error.
  - `unarchive(id)` sobre cuenta archivada setea `archived_at = null`.
  - `unarchive(id)` sobre cuenta activa: no-op sin error.
  - `unarchive(id)` sobre Bolsa: no-op (Bolsa nunca está archivada) o `protected_account` (decidir; preferencia: no-op porque no toca estado sensible).
  - `watchActive()` excluye archivadas y eliminadas.
  - `watchArchived()` incluye archivadas, excluye activas y eliminadas.
  - `listAll(includeArchived: false)` excluye archivadas.
  - `listAll(includeArchived: true)` incluye archivadas pero excluye eliminadas.
  - `findActiveOrArchivedById(id)` retorna la cuenta si `deleted_at IS NULL`, incluso si `archived_at != null`.
  - `findActiveOrArchivedById(id)` retorna null si `deleted_at != null`.
  - `delete(id)` (renombrado de `archive` anterior): tests existentes de cascada preservados y renombrados. Bolsa protegida sigue verificado.
  - `EntriesDao.countByAccount(id)` retorna 0 para cuenta sin movimientos.
  - `EntriesDao.countByAccount(id)` retorna N para cuenta con N movimientos (origen + destino).
  - `EntriesDao.countByAccount(id)` ignora movimientos con `deleted_at != null`.

## Pruebas de UI o flujo necesarias si aplica

- `test/screens/list_screens_test.dart`:
  - Widget test: `SegmentedButton` presente en `accounts_list_screen` con 2 opciones.
  - Widget test: al seleccionar segmento "Archivadas" con BD que contiene 1 archivada, la lista muestra esa cuenta con badge o estilo diferenciado.
  - Widget test: menú overflow en card activa muestra 3 opciones; en card archivada muestra 2 opciones.
  - Widget test: Bolsa no ofrece menú overflow.
- `test/screens/entry_form_screen_test.dart`:
  - Widget test: al abrir `/entries/{id}/edit` para un entry con `account_origin` archivada, se renderiza banner "Movimiento con cuenta archivada" y los campos están disabled.
  - Widget test: sólo el botón "Eliminar movimiento" funciona en modo bloqueado.
- `test/screens/entry_form_kinds_test.dart`:
  - Sin cambios (los 5 kinds siguen funcionando en modo new). Los tests existentes deben seguir verdes.

## Pruebas de permisos y seguridad si aplica

No aplica. App single-user sin roles.

## Pruebas de datos, migracion o compatibilidad si aplica

- Migración `schemaVersion 8 → 9`:
  - Verificar en test de integración que abrir una BD v8 (via `NativeDatabase.memory()` sembrada manualmente o via migración forzada) corre la rama nueva y la columna `archived_at` queda disponible.
  - Verificar que el guardrail `UnimplementedError` sigue lanzando para `from == 9 && to == 10` (transición futura no cubierta).
- Backup:
  - Round-trip export → import con una cuenta archivada presente: la cuenta se exporta sin `archived_at` (o con `null`) y al reimportar queda como activa. Documentado como comportamiento esperado.
  - Import v1 legacy: sigue funcionando; no requiere campo `archived_at`.

## Pruebas de regresion sobre flujos existentes

- BO/DE/CR en dashboard: sumas idénticas antes y después de archivar una cuenta con movimientos.
- Balance por cuenta: `FinancialStateService.watchAccountBalance(id, type)` retorna el mismo valor para una cuenta activa vs archivada con los mismos movimientos.
- Reportes: `spendingByCategory`, `incomeByCategory`, `cashflow`, `topMovements`, `calendar`, `heatmaps` — todos incluyen movimientos de cuentas archivadas.
- `AccountPicker` en `/entries/new`: no muestra archivadas por default.
- `AccountPicker` en filtros de `/entries`: si se pasa `includeArchived: true`, muestra archivadas con badge.
- Backup round-trip sin cuentas archivadas: idéntico al comportamiento actual.
- `flutter analyze` sin errores nuevos.
- `flutter test` con conteo actualizado (112 → ≥ 120 tests aproximadamente).

## Pruebas manuales o smoke tests necesarios

En APK release arm64 instalado en cel:

1. Abrir la app, ir a `/accounts`. Confirmar que el `SegmentedButton` aparece con `Activas` seleccionado.
2. En una cuenta débito con ≥1 movimiento, tap en menú overflow → `Archivar` → confirmar diálogo. La cuenta desaparece del segmento Activas.
3. Cambiar al segmento Archivadas: la cuenta aparece con estilo diferenciado.
4. Ir a `/entries/new` → seleccionar tipo `income`. El `AccountPicker` NO ofrece la cuenta archivada.
5. Ir a `/entries` sin filtros: los movimientos de la cuenta archivada siguen apareciendo con sufijo `(archivada)`.
6. Aplicar filtro por cuenta en `/entries`: el picker de filtro SÍ muestra la cuenta archivada con badge.
7. Editar un movimiento cuya cuenta origen está archivada. Confirmar que el form aparece read-only con banner y sólo el botón "Eliminar movimiento" funciona.
8. Ir a dashboard: el KPI BO/DE/CR incluye el balance de la cuenta archivada.
9. Ir a `/reports/spending-by-category`: los movimientos de la cuenta archivada están sumados.
10. Volver a `/accounts` segmento Archivadas, tap en menú overflow → `Desarchivar`. La cuenta vuelve a Activas.
11. En una cuenta débito con ≥1 movimiento, tap en menú overflow → `Eliminar`. Confirmar `DestructiveDialog` con chip "N movimientos afectados". Confirmar. La cuenta y los N movimientos desaparecen de todos los lugares (incluyendo reportes).
12. Verificar que la Bolsa no muestra menú overflow en `/accounts`.
13. Editar la Bolsa desde `/accounts/{id}/edit`: el AppBar no tiene menú overflow (o las opciones están deshabilitadas).
14. Exportar backup, verificar JSON. Reimportar el mismo backup, verificar que la BD queda íntegra (las cuentas archivadas antes del export vuelven como activas post-import — documentado).
15. Verificar que `scripts/verify-apk.sh` no falla por desincronía de versión.

## Datos de prueba recomendados

- BD con:
  - 1 Bolsa.
  - 2 cuentas débito, 1 activa y 1 archivada.
  - 1 cuenta crédito activa.
  - 1 cuenta crédito archivada.
  - 5 movimientos en la débito activa, 3 movimientos en la débito archivada, 2 movimientos en la crédito activa, 1 movimiento en la crédito archivada.
- Para tests unitarios: BD in-memory, seed manual con `AccountsCompanion.insert` que incluye `archivedAt: Value(DateTime.now())` para casos archivados.

## Comandos o validaciones locales sugeridas

```bash
cd /home/developer/Escritorio/proyectos/fincore/mobile
dart run build_runner build --delete-conflicting-outputs
flutter analyze
flutter test
flutter build apk --release --split-per-abi
../scripts/verify-apk.sh  # si existe en el repo o en /scripts
```

## Criterios minimos para aprobar la implementacion

- `flutter analyze` en `mobile/` sin errores nuevos.
- `flutter test` verde con ≥ 120 tests (base 112 + los nuevos).
- APK `arm64-v8a-release` compila y `versionCode` sincronizado.
- Smoke manual completo con los 15 items verificados por Diego.
- No hay regresión en BO/DE/CR ni en ningún reporte existente (comparación side-by-side con una BD antes y después de archivar).
- Migración `schemaVersion 8 → 9` corre sin corrupción en al menos un test de integración.

## Validacion final recomendada

Si la skill `branch-quality-review` está disponible, invocarla sobre la rama del sprint antes de merge para revisión exhaustiva. La skill genera su propio reporte en `engineering/quality-review/flutter-accounts-archive-v1/`; no duplicar en `plan/`.

Si no está disponible, checklist manual:
- Cero referencias sueltas a `AccountsDao.archive` fuera del método actual `delete` renombrado y del nuevo método `archive`.
- Cero queries de reportes con filtro por `archived_at` (sólo lecturas UI y DAO).
- Todas las tablas siguen respetando `PRAGMA foreign_keys=ON`.
- Copy consistente en español neutral (guardrail `no_voseo_test.dart` sigue verde).
- Sin comentarios TODO sin resolver en los archivos tocados.
