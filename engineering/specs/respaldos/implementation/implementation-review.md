# Implementation Review: respaldos

## Resumen de lo implementado

Export e import (modo reemplazo total) del dominio financiero. `ExportUserData` arma un JSON `version:1` con cuentas, categorías y movimientos activos (sin soft-deleted, sin plan). `ImportUserData` valida el archivo, ejecuta el hard reset full y restaura dentro de una sola transacción, regenerando UUIDs y remapeando FKs; reconcilia la Bolsa (singleton) y las categorías por nombre. Dos endpoints nuevos en `SettingsController`, sección "Respaldos" en `/settings` (descargar + aplicar con archivo y contraseña). El merge aditivo quedó fuera de alcance (v2) por decisión del usuario.

## Archivos principales modificados

Nuevos backend:
- `backend/app/Domain/Finance/Actions/ExportUserData.php`
- `backend/app/Domain/Finance/Actions/ImportUserData.php`
- `backend/app/Domain/Finance/Exceptions/InvalidBackupFile.php`
- `backend/tests/Feature/Finance/ImportUserDataTest.php` (9)
- `backend/tests/Feature/Http/BackupTest.php` (11)

Modificados backend:
- `backend/app/Http/Controllers/SettingsController.php` (`exportData`, `importData`)
- `backend/routes/api.php` (2 rutas)
- `CLAUDE.md` (endpoints reset + backup documentados)

Frontend:
- `frontend/src/api/settings.js` (`exportBackup`, `importBackup`)
- `frontend/src/views/app/SettingsView.vue` (sección Respaldos + modal de import)

## Tareas completadas

T001–T013 y T016. Detalle en `progreso.md`.

## Tareas pendientes

- T014 (recorrido manual de 6 pasos): requiere el usuario en localhost.
- T015 (`branch-quality-review`): recomendado antes del merge.

## Riesgos residuales

- **Transacción anidada reset+restore**: cubierta por `ImportUserDataTest::test_rollback_on_failure_keeps_previous_data` (fuerza fallo tras el reset y verifica que los datos previos siguen). Funciona porque Laravel anida con savepoints y el rollback externo revierte todo.
- **Categorías acumuladas en replace**: el reset full conserva categorías; el import reconcilia/crea por nombre. Las categorías del destino que no estén en el archivo sobreviven (unión). Documentado como supuesto en la spec; ajustable si se quiere fidelidad estricta.
- **Archivo de texto plano sin cifrar**: contiene el detalle financiero. Riesgo de resguardo del lado del usuario, documentado.
- **Payload JSON en body**: para históricos grandes podría chocar con límites de PHP (`post_max_size`). Sin problema en el rango de uso personal.

## Pruebas realizadas

- `ImportUserDataTest`: 9/9 (remapeo, reconciliación Bolsa/categorías, omisión de inválidos, regeneración UUID, version/estructura, rollback atómico).
- `BackupTest`: 11/11 (export shape/excludes soft-deleted/excludes plan/scope; import password/version; **ciclo completo con delta 0.00 en BO/DE/CR**; regeneración de ids + no duplicar Bolsa; import cross-account; resumen; verified).
- Suite backend completa: 295/295 (antes 275, +20).
- Suite frontend: 49/49 (sin regresión).
- Rutas verificadas con `route:list --path=finance/backup`.

## Pruebas recomendadas

- Recorrido manual (T014): descargar respaldo → reset → aplicar → verificar que dashboard y balances coinciden; probar archivo corrupto y password incorrecto.
- `branch-quality-review` (T015) antes del merge.

## Posibles regresiones

- `HardResetUserData` no se modificó: `HardResetTest` (7) sigue verde.
- `SettingsController` solo se extendió (métodos nuevos); el hard reset existente intacto.
- `/settings` ahora tiene sección Respaldos + Zona de peligro; los dos resets siguen funcionando.
- Sin cambios de schema; ninguna migración.

## Recomendaciones para code review humano

1. Revisar `ImportUserData::execute`: que el `DB::transaction` externo envuelva el reset y que ninguna ruta de error escape sin rollback.
2. Confirmar el remapeo de la Bolsa: una sola cuenta cash protegida tras el import (test lo cubre, pero verificar el criterio `type === cash || is_protected`).
3. Verificar que `importData` valida password ANTES de tocar datos (está antes de llamar la Action).
4. Confirmar que el export no filtra datos de otros usuarios (scope por `user_id`).
5. Lanzar `/branch-quality-review slug=respaldos` antes del merge.
