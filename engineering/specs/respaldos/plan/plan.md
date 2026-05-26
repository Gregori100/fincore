# Plan técnico — Respaldos (export / import)

## Enfoque tecnico

Dos Actions nuevas en `backend/app/Domain/Finance/Actions/`: `ExportUserData` arma un array serializable del estado financiero activo del usuario; `ImportUserData` valida el payload, ejecuta el hard reset (`full`) y restaura, todo dentro de una sola transacción. `SettingsController` gana dos métodos (`exportData`, `importData`) que delegan en las Actions. El reset destructivo reusa `HardResetUserData::execute(userId, 'full')` sin cambios.

La identidad se regenera al importar: cada entidad creada toma UUID v7 nuevo vía `HasUuids` y `user_id` del autenticado. Se mantiene una tabla local en memoria `localId → modeloNuevo` para remapear las FKs de los movimientos (origin, destination, category). La Bolsa y las categorías se reconcilian contra lo que el reset conserva (Bolsa singleton + categorías actuales) buscando por nombre.

El transporte: el frontend parsea el archivo en el cliente y envía el JSON ya parseado en el body del POST de import (no multipart). El export se entrega como respuesta JSON que el frontend convierte en descarga (`Blob`). Esto evita manejo de archivos en disco en el backend y mantiene todo en memoria/transacción.

## Requisitos funcionales cubiertos

- RF-001 (export JSON activo sin plan): `ExportUserData` lee cuentas/categorías/entries activos vía Eloquent (sin `withTrashed`), arma `{ version, exported_at, accounts, categories, entries }`. Endpoint `GET /finance/backup/export`.
- RF-002 (referencias resolubles): cada entry exporta `account_origin_local`, `account_destination_local`, `category_local` apuntando al identificador local (el UUID original sirve como local id en el archivo).
- RF-003 (endpoint import con validación): `POST /finance/backup/import`; valida `version`, estructura y password antes de tocar BD.
- RF-004 (reset + restore + password): `ImportUserData` invoca `HardResetUserData::execute(userId,'full')` y restaura; el controller valida password con `Hash::check`.
- RF-005 (regenerar UUID + remapeo FK): mapa local en memoria; los entries se crean con los ids nuevos resueltos.
- RF-006 (reconciliación Bolsa + categorías): la cuenta `cash` del archivo se mapea a la Bolsa existente; categorías por nombre (case-insensitive, trim) reusando o creando.
- RF-007 (transacción): toda la lógica de `ImportUserData` dentro de `DB::transaction`.
- RF-008 (resumen): la Action retorna `{ accounts_created, categories_created, categories_reused, entries_imported, entries_skipped }`.
- RF-009 (UI descargar + aplicar): sección "Respaldos" en `SettingsView.vue` con descarga y modal de aplicar (archivo + password).
- RF-010 (rechazo de archivos inválidos): validación en la Action/controller → 422 con código de dominio.
- RF-011 (refrescar estado): tras import, el front llama `finance.fetchState()` + `plan.reset()` y redirige/recarga la vista.

## Archivos o modulos probablemente afectados

### Backend (nuevo)

- `backend/app/Domain/Finance/Actions/ExportUserData.php`
- `backend/app/Domain/Finance/Actions/ImportUserData.php`
- `backend/app/Domain/Finance/Exceptions/InvalidBackupFile.php` (422, código `invalid_backup_file`)

### Backend (modificado)

- `backend/app/Http/Controllers/SettingsController.php` (métodos `exportData`, `importData`)
- `backend/routes/api.php` (2 rutas nuevas bajo el grupo finance)

### Frontend (modificado)

- `frontend/src/api/settings.js` (`exportBackup`, `importBackup`)
- `frontend/src/views/app/SettingsView.vue` (sección "Respaldos" + modal de import)

### Tests (nuevo)

- `backend/tests/Feature/Http/BackupTest.php` (export + import end-to-end, ciclo, validaciones)
- `backend/tests/Feature/Finance/ImportUserDataTest.php` (unit de la Action: remapeo, reconciliación, casos borde)

## Entidades y estados afectados

- **Account**: en import se crean nuevas (no-cash) o se reconcilia la `cash` (Bolsa) existente. Invariante: una sola Bolsa por usuario (`is_protected`, type cash). El import nunca crea una segunda.
- **Category**: reconciliación por nombre; se crean las que no existan. `applies_to`, `color_slug`, `icon_slug`, `monthly_limit` se restauran al crear.
- **JournalEntry**: se crean nuevas con FKs remapeadas. `occurred_at` se parsea con Carbon. `amount` debe ser > 0 (regla de dominio); filas inválidas se omiten.
- **PlannedEvent / Override**: no participan (el export los excluye; el reset full los borra). Tras un import, el usuario queda sin plan.
- **Efecto secundario clave**: el import borra físicamente el estado previo (vía hard reset). Es destructivo e irreversible salvo por otro respaldo.

## Compatibilidad con datos y procesos existentes

- **Sin cambios de schema**: ninguna migración. Solo lectura (export) e inserción (import).
- **Reusa `HardResetUserData`** sin modificarlo: el comportamiento del reset (conserva Bolsa + categorías) define cómo se reconcilian esas entidades en el import. Documentado en la spec.
- **Balances derivados**: como el balance se calcula on-demand (`FinancialStateService`), tras importar los movimientos el BO/DE/CR se recomputan solos. El criterio de aceptación (delta 0.00 en el ciclo) depende de que el remapeo de cuentas sea correcto.
- **Soft deletes**: el export ignora archivados; no se restauran. Coherente con "estado activo".
- **Categorías acumuladas**: el reset full conserva las categorías actuales; el import reconcilia por nombre. Si el destino tenía categorías extra no presentes en el archivo, sobreviven (unión). Documentado como supuesto revisable.
- **Reportes y Plan**: no leen estas Actions; sin impacto. El Plan queda vacío tras import (el reset lo borró).

## Cambios de datos

Ninguno estructural. En runtime:
- Export: solo SELECT.
- Import: DELETE físico (vía reset) + INSERT masivo, todo en una transacción.

## Cambios de API

Nuevas rutas dentro de `Route::middleware(['auth:sanctum','verified'])->prefix('finance')`:

- `GET /finance/backup/export` → devuelve el JSON del respaldo (el front lo descarga como archivo). Sin parámetros.
- `POST /finance/backup/import` → body `{ password, backup: {...} }`. Valida password + estructura; ejecuta reset+restore; devuelve resumen `{ accounts_created, categories_created, categories_reused, entries_imported, entries_skipped }`.

Errores: `invalid_backup_file` (422) para archivo corrupto/estructura/versión; validación Laravel 422 para password faltante; `{password: ...}` 422 si la contraseña es incorrecta (igual que hard reset).

## Cambios de integraciones

No aplica.

## Cambios de UI

- `SettingsView.vue`: nueva sección "Respaldos" (separada de la "Zona de peligro", arriba de ella por ser menos peligrosa).
  - Botón "Descargar respaldo": llama al export, genera un `Blob` y dispara descarga con nombre `fincore-backup-YYYY-MM-DD.json`.
  - Botón "Aplicar respaldo": abre modal → `<input type="file" accept="application/json,.json">` → al elegir, parsea en cliente (try/catch de JSON.parse) → pide contraseña → confirma. Tras éxito: toast con resumen, `finance.fetchState()`, `plan.reset()`, redirect a dashboard.
- Copy claro de que aplicar un respaldo **borra el estado actual** antes de restaurar (es replace).
- Reusa `BaseModal`, `BaseButton`, `BaseInput`. La lectura del archivo usa `FileReader` o `file.text()`.

## Cambios de permisos

Ninguno nuevo. Ambos endpoints bajo `auth:sanctum` + `verified`, scoped por `request->user()->id`. El import (destructivo) exige contraseña adicional, igual que el hard reset.

## Riesgos tecnicos

- **Remapeo incorrecto de FKs**: si el mapa local falla, los movimientos quedarían con cuentas equivocadas y los balances no cuadrarían. Mitigación: test de ciclo con assert de delta 0.00 en BO/DE/CR.
- **Reconciliación de la Bolsa**: identificar cuál entidad del archivo es la Bolsa. Se hace por `type === cash` + `is_protected`. Si el archivo trae varias cash (manipulado), tomar la protegida o la primera; las demás se ignoran. Documentar.
- **Payload grande en el body**: import de miles de movimientos en un POST JSON. Para uso personal es aceptable; vigilar `post_max_size`/`upload_max_filesize` de PHP si crece. No es problema en el rango esperado.
- **Atomicidad reset+restore**: ambos deben ir en la misma transacción. `HardResetUserData` ya usa `DB::transaction` internamente; al llamarlo dentro de otra transacción, Laravel usa savepoints anidados — verificar que el rollback externo revierte también el reset. Alternativa: extraer la lógica de borrado a un método sin transacción propia y envolver todo en `ImportUserData`. **Punto de atención en implementación.**
- **Doble import / doble submit**: si el usuario hace click dos veces, el segundo import resetea lo recién importado y restaura igual → idempotente en resultado, pero conviene deshabilitar el botón durante la operación (loading).
- **Filas inválidas**: montos ≤ 0 o fechas no parseables se omiten e informan; no abortan. Riesgo de pérdida silenciosa mitigado por el resumen.

## Estrategia de pruebas

- **Unit de `ImportUserData`**: remapeo de FKs, reconciliación Bolsa/categorías, omisión de filas inválidas, regeneración de UUID, asignación a user actual.
- **Feature/API**: export devuelve shape correcto sin soft-deleted ni plan; import valida password y versión; ciclo completo export→reset→import con assert de delta 0.00 en BO/DE/CR; rechazo de archivo inválido; scope por usuario.
- **Regresión**: suite backend completa (275) verde tras integrar; `HardResetTest` intacto (no se toca `HardResetUserData`).
- **Frontend**: no se agregan tests unitarios nuevos críticos (la lógica pesada está en backend). Smoke manual del flujo de descarga/subida. Opcional: test del store si se agrega lógica ahí (no se prevé).

## Estrategia de rollback

- **Rollback de código**: el feature es aditivo (2 Actions, 2 métodos de controller, 2 rutas, 1 sección UI). Revertir el commit lo elimina sin tocar nada más.
- **Rollback de datos en runtime**: el import es transaccional. Si falla, la BD queda como antes. El riesgo real es un import "exitoso" no deseado → mitigado porque el usuario debió descargar un respaldo antes (es justamente el propósito del feature).
- Sin migraciones que revertir.

## Orden sugerido de implementacion

1. **`ExportUserData` + endpoint export + tests de export**. Es la mitad sin riesgo (solo lectura) y produce el insumo para testear el import.
2. **`InvalidBackupFile` exception**.
3. **`ImportUserData`** (núcleo): validación de estructura/version, reset, restore con remapeo y reconciliación, resumen. Resolver aquí el punto de atención de la transacción anidada.
4. **Endpoint import + validación de password en `SettingsController`**.
5. **Tests unit de `ImportUserData` + feature del ciclo completo** (delta 0.00).
6. **Frontend**: `api/settings.js` (export/import), sección "Respaldos" en `SettingsView.vue`, descarga Blob + parseo de archivo + modal.
7. **Suite completa backend + frontend verde**.
8. **Docs**: actualizar `CLAUDE.md` (endpoints de backup) y memoria del proyecto.
9. **`branch-quality-review`** antes del merge.

## Casos borde que condicionan la solucion

- **Transacción anidada reset+restore**: el caso que más condiciona el diseño. Decisión: `ImportUserData` abre la transacción y llama al reset; si `HardResetUserData` abre su propia transacción, Laravel anida con savepoint y el rollback externo cubre todo. Verificar con un test que fuerce excepción tras el reset y confirme que los datos viejos siguen ahí.
- **Archivo sin Bolsa**: la Bolsa destino se conserva (reset no la borra); los entries que apunten a la cash del archivo se remapean a ella igual si existe el local id; si el archivo no trae cash, esos entries (si los hubiera) se omiten.
- **Categoría del archivo con nombre que ya existe**: se reusa la existente (no se duplica).
- **Entry con `amount` ≤ 0 o fecha inválida**: se omite y cuenta en `entries_skipped`.
- **Entry que referencia un local id inexistente en el archivo**: se omite (archivo manipulado).
- **Password incorrecto**: 422, no se ejecuta nada.
- **version != 1**: 422 `invalid_backup_file`.
- **backup vacío** (`accounts: [], entries: []`): reset ejecuta, no se crea nada, Bolsa queda vacía, resumen en cero.
- **Doble Bolsa en el archivo**: se toma la protegida; el resto se ignora.

## Preguntas o supuestos que siguen afectando la implementacion

Sin preguntas bloqueantes. Supuestos heredados de la spec:

- Transporte JSON en body (no multipart). Afina-ble pero decidido así por simplicidad.
- Filas inválidas se omiten e informan; estructura/versión inválida aborta.
- Reset+restore en una sola transacción (resolver anidamiento).
- Categorías: unión (las del destino que no estén en el archivo sobreviven). Revisable si se quiere fidelidad estricta.
- `version: 1` fija; sin migración de esquemas de respaldo en v1.
