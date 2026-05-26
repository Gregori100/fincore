# Tasks — Respaldos (export / import)

Orden: export (sin riesgo) → exception → import (núcleo) → endpoints → tests → frontend → docs.

## Backend

- [ ] T001 Backend: Action `ExportUserData::execute(string $userId): array` que arma `{ version: 1, exported_at, accounts, categories, entries }` con registros activos (sin withTrashed) del usuario. Cada entry referencia local ids de origin/destination/category.
  RF: RF-001, RF-002
  Depende de: ninguna
  Paralelizable: si
  Criterio de terminado: el array tiene la estructura esperada, excluye soft-deleted y no incluye plan; cubierto por tests de export.

- [ ] T002 Backend: exception `App\Domain\Finance\Exceptions\InvalidBackupFile` (extiende DomainException, código `invalid_backup_file`, 422).
  RF: RF-010
  Depende de: ninguna
  Paralelizable: si
  Criterio de terminado: render JSON estándar `{error, code}`.

- [ ] T003 Backend: Action `ImportUserData::execute(string $userId, array $backup): array`. Valida `version` y estructura (lanza InvalidBackupFile). Dentro de una transacción: ejecuta el borrado del hard reset full, crea cuentas no-cash nuevas, reconcilia la Bolsa y las categorías por nombre, crea entries remapeando FKs, omite filas inválidas. Retorna resumen.
  RF: RF-004, RF-005, RF-006, RF-007, RF-008
  Depende de: T002
  Paralelizable: no
  Criterio de terminado: cubre los casos de `ImportUserDataTest`; el reset y el restore son atómicos (rollback total ante error).

- [ ] T004 Backend: resolver el anidamiento de transacción reset+restore. Si `HardResetUserData` abre su propia transacción, validar que el rollback externo de `ImportUserData` revierte también el reset (savepoints). Si no, extraer el borrado a un método invocable sin transacción propia.
  RF: RF-007
  Depende de: T003
  Paralelizable: no
  Criterio de terminado: test de rollback (excepción tras reset) deja los datos previos intactos.

- [ ] T005 Backend: métodos `exportData` e `importData` en `SettingsController`. `importData` valida `password` (Hash::check, mismo patrón que hardReset) y `backup` (array) antes de delegar.
  RF: RF-003, RF-004
  Depende de: T001, T003
  Paralelizable: no
  Criterio de terminado: endpoints responden con los shapes y códigos esperados.

- [ ] T006 Backend: 2 rutas en `routes/api.php` dentro del grupo finance: `GET /backup/export`, `POST /backup/import`.
  RF: RF-001, RF-003
  Depende de: T005
  Paralelizable: no
  Criterio de terminado: `php artisan route:list --path=finance/backup` muestra las 2 rutas.

## Frontend

- [ ] T007 Frontend: en `api/settings.js`, agregar `exportBackup()` (GET) e `importBackup(password, backup)` (POST).
  RF: RF-009
  Depende de: T006
  Paralelizable: si
  Criterio de terminado: funciones exportadas y consumibles.

- [ ] T008 Frontend: sección "Respaldos" en `SettingsView.vue` (separada de la Zona de peligro). Botón "Descargar respaldo" que genera Blob y dispara descarga `fincore-backup-YYYY-MM-DD.json`. Botón "Aplicar respaldo" que abre modal: input file (parseo en cliente con try/catch), input password, confirmación. Copy que advierte que reemplaza el estado actual.
  RF: RF-009, RF-011
  Depende de: T007
  Paralelizable: no
  Criterio de terminado: descarga funciona; al aplicar muestra resumen, refresca `finance.fetchState()`, `plan.reset()` y redirige a dashboard.

- [ ] T009 Frontend: manejo de errores de archivo en el modal (JSON inválido en cliente → mensaje sin llamar al backend; 422 del backend → toast con el mensaje del error).
  RF: RF-010
  Depende de: T008
  Paralelizable: no
  Criterio de terminado: archivo corrupto y password incorrecto muestran mensajes claros sin romper la vista.

## Pruebas

- [ ] T010 Pruebas: `backend/tests/Feature/Finance/ImportUserDataTest.php` con los casos unit del test-plan (remapeo, reconciliación Bolsa/categorías, omisión de inválidos, regeneración de UUID, rollback).
  RF: RF-004..RF-008
  Depende de: T003, T004
  Paralelizable: si
  Criterio de terminado: todos verdes; cobertura ≥ 90% de `ImportUserData`.

- [ ] T011 Pruebas: `backend/tests/Feature/Http/BackupTest.php` con export (shape, excluye soft-deleted/plan, scope), import (password, version, estructura), ciclo completo con delta 0.00, regeneración de ids, no-duplicar Bolsa, import cross-account.
  RF: RF-001..RF-011
  Depende de: T006
  Paralelizable: si
  Criterio de terminado: incluye `test_full_cycle_preserves_balances` verde (criterio central).

- [ ] T012 Pruebas: correr suite backend completa y confirmar sin regresión (≥ 287, antes 275 + ~12).
  RF: todos
  Depende de: T010, T011
  Paralelizable: no
  Criterio de terminado: `php artisan test` exit 0; `HardResetTest` intacto.

- [ ] T013 Pruebas: correr suite frontend completa (49 verde, sin regresión).
  RF: todos
  Depende de: T008, T009
  Paralelizable: no
  Criterio de terminado: `npm run test` exit 0.

- [ ] T014 Pruebas: recorrido manual de 6 pasos del test-plan (descargar, reset, aplicar, verificar balances, archivo corrupto).
  RF: todos
  Depende de: T012, T013
  Paralelizable: no
  Criterio de terminado: los 6 pasos pasan en localhost.

## Validacion de calidad

- [ ] T015 Validación: `/branch-quality-review slug=respaldos` (seguridad del import destructivo, transacción anidada, remapeo de FKs, scope por usuario).
  RF: todos
  Depende de: T014
  Paralelizable: no
  Criterio de terminado: reporte en `engineering/quality-review/respaldos/` sin hallazgos bloqueantes pendientes.

## Documentacion

- [ ] T016 Documentación: actualizar `CLAUDE.md` con los 2 endpoints de backup y una nota breve del flujo (export/import-replace reusa hard reset). Actualizar memoria del proyecto marcando Respaldos v1 cerrado y el merge como v2 pendiente.
  RF: todos
  Depende de: T006
  Paralelizable: si
  Criterio de terminado: docs consistentes con lo implementado.
