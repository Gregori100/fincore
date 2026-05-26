# Test plan — Respaldos (export / import)

## Casos borde detectados

- Archivo no-JSON / corrupto: rechazo en validación, BD intacta.
- `version` ausente o distinta de 1: 422 `invalid_backup_file`, BD intacta.
- Estructura incompleta (falta `accounts`, `categories` o `entries`): rechazo.
- Backup vacío (`accounts: []`, `entries: []`): reset ejecuta, no crea nada, Bolsa queda vacía, resumen en cero.
- Backup sin la cuenta cash (Bolsa): la Bolsa destino se conserva; entries que la referencien se omiten si no hay local id de cash.
- Backup con dos cuentas cash (manipulado): se toma la protegida; las demás se ignoran y se cuentan como omitidas o se reportan.
- Categoría del archivo con nombre ya existente en destino: se reusa, no se duplica (`categories_reused` ++).
- Categoría del archivo con nombre nuevo: se crea (`categories_created` ++).
- Entry con `amount` ≤ 0: se omite (`entries_skipped` ++).
- Entry con `occurred_at` no parseable: se omite.
- Entry que referencia un local id de cuenta/categoría inexistente: se omite.
- Entry `transfer` entre dos cuentas del archivo: ambas se crean, el movimiento se remapea a las nuevas.
- Entry `income` a la Bolsa: se remapea a la Bolsa existente del destino.
- Password incorrecto en import: 422, no se ejecuta reset ni restore.
- Password ausente: 422 validación.
- Excepción forzada a mitad del restore (después del reset): rollback total, BD queda como antes del import (datos viejos presentes).
- Import de un respaldo de OTRO usuario (UUIDs ajenos): todo se asigna al user actual; ningún id ajeno persiste.
- Export con cuentas/categorías/entries soft-deleted: no aparecen en el archivo.
- Export sin datos (usuario recién creado): JSON válido con solo la Bolsa y las categorías default, entries vacío.
- Doble submit del import: idempotente en resultado (resetea y restaura igual); el botón se deshabilita en loading.
- Soft-deleted en destino antes del import: el reset los fuerza a borrar (forceDelete), no interfieren.
- Concurrencia: dos imports simultáneos del mismo usuario — poco probable en uso personal; la transacción serializa, el segundo resetea lo del primero. Aceptable.

## Pruebas unitarias necesarias

`ImportUserDataTest` (Action, con `RefreshDatabase`):

- Crea cuentas no-cash nuevas con UUID regenerado y user actual.
- Mapea la cash del archivo a la Bolsa existente (no crea segunda Bolsa).
- Reconcilia categoría existente por nombre (case-insensitive + trim); no duplica.
- Crea categoría nueva cuando el nombre no existe.
- Remapea FKs de entries (origin, destination, category) a las entidades resultantes.
- Omite entry con amount ≤ 0 y lo cuenta en `entries_skipped`.
- Omite entry con fecha inválida.
- Omite entry con referencia a local id inexistente.
- Asigna todas las entidades al `user_id` autenticado, ignorando ids del archivo.
- Retorna el resumen con los conteos correctos.
- Rollback: forzar excepción tras el reset y verificar que los datos previos siguen presentes (transacción anidada cubierta).

## Pruebas de integracion o API necesarias

`BackupTest` (HTTP, `RefreshDatabase`, Sanctum):

- `test_export_returns_expected_shape`: GET export devuelve `{version:1, exported_at, accounts, categories, entries}`.
- `test_export_excludes_soft_deleted`: una cuenta y un entry archivados no aparecen.
- `test_export_excludes_plan`: el JSON no contiene planned_events.
- `test_export_scoped_to_user`: no incluye datos de otro usuario.
- `test_import_requires_password`: sin password → 422.
- `test_import_rejects_wrong_password`: password incorrecto → 422, BD intacta.
- `test_import_rejects_invalid_version`: version 99 → 422 `invalid_backup_file`.
- `test_import_rejects_malformed_structure`: falta `entries` → 422.
- `test_full_cycle_preserves_balances`: dataset (3 cuentas, 1 tarjeta, 20 entries variados) → export → reset → import → BO, DE, CR con delta 0.00 vs originales. **Criterio de aceptación central.**
- `test_import_regenerates_ids_and_assigns_user`: ningún id del archivo persiste; todo es del user actual.
- `test_import_does_not_duplicate_bolsa`: tras import sigue habiendo exactamente una cuenta cash protegida.
- `test_import_returns_summary`: el JSON de respuesta trae los conteos.
- `test_import_into_other_account`: exportar desde user A, importar como user B → user B queda con los datos, user A intacto.

## Pruebas de UI o flujo necesarias

- Smoke manual: descargar respaldo genera archivo `fincore-backup-YYYY-MM-DD.json` válido.
- Smoke manual: subir archivo válido + password correcto → toast de resumen, dashboard refleja los datos, sin recarga manual.
- Smoke manual: subir archivo corrupto → mensaje de error claro, nada se borra.
- Smoke manual: subir archivo válido + password incorrecto → error, datos intactos.
- No se agregan tests vitest nuevos salvo que se mueva lógica al store (no previsto).

## Pruebas de permisos y seguridad

- Ambos endpoints requieren `auth:sanctum` + `verified` (401/403 sin ello).
- Export y import scoped por `request->user()->id`: imposible exportar/pisar datos de otro usuario.
- Import exige contraseña correcta del usuario actual (`Hash::check`).
- El archivo no incluye password/tokens/email del usuario.

## Pruebas de datos, migracion o compatibilidad

- Sin migraciones; nada que probar ahí.
- Confirmar que el export no rompe si hay 0 cuentas extra (solo Bolsa) ni si hay 0 entries.
- Confirmar que el import respeta `decimal(12,2)` (montos con 2 decimales) sin pérdida.
- Confirmar que `occurred_at` se preserva con su fecha exacta tras el ciclo.

## Pruebas de regresion sobre flujos existentes

- Suite backend completa (275) verde tras integrar.
- `HardResetTest` (7) intacto: no se modifica `HardResetUserData`.
- Suite frontend (49) verde.
- `/settings` sigue mostrando la "Zona de peligro" y los dos resets funcionando; la sección "Respaldos" se agrega sin romperlos.

## Pruebas manuales o smoke tests necesarios

Recorrido en `localhost:5173`:

1. Crear datos (2 cuentas, 1 tarjeta, varios movimientos, una categoría custom).
2. `/settings` → "Descargar respaldo" → confirmar que baja el JSON y abrirlo para ver la estructura.
3. Hard reset full → verificar cuenta vacía.
4. "Aplicar respaldo" → subir el JSON → password → confirmar.
5. Verificar que dashboard, /accounts, /entries muestran exactamente lo de antes; BO/DE/CR iguales.
6. Probar subir un archivo de texto cualquiera → error claro.

## Datos de prueba recomendados

- Usuario con Bolsa + "Banamex" (débito) + "Visa" (crédito, deuda inicial), una categoría custom "Café".
- ~20 movimientos: ingresos a Bolsa, gastos, un transfer Bolsa→Banamex, un cargo a Visa, un pago a Visa.
- Factory existente de Account + helpers de Register* para sembrar.

## Comandos o validaciones locales sugeridas

```bash
docker compose exec -T api php artisan test --filter "Backup|ImportUserData"
docker compose exec -T api php artisan test
cd frontend && npm run test
docker compose exec -T api ./vendor/bin/pint --test
```

Manual: abrir `http://localhost:5173/settings`.

## Criterios minimos para aprobar la implementacion

1. Export e import responden con los shapes y códigos esperados.
2. `test_full_cycle_preserves_balances` verde (delta 0.00 en BO/DE/CR).
3. Import transaccional: test de rollback verde.
4. La Bolsa nunca se duplica (test verde).
5. Validaciones de archivo y password verdes.
6. Suite backend ≥ 287 (275 + ~12 nuevos), toda verde.
7. Suite frontend 49 verde (sin regresión).
8. Recorrido manual de 6 pasos sin errores.
9. `CLAUDE.md` actualizado con los endpoints de backup.

## Validacion final recomendada

Invocar `/branch-quality-review slug=respaldos` antes del merge para revisión exhaustiva (seguridad del import destructivo, transacción anidada, remapeo de FKs, scope por usuario). Reporte en `engineering/quality-review/respaldos/`.

Si no estuviera disponible, checklist mínima: revisar que el import siempre corre bajo transacción, que ningún id del archivo persiste, que el password se valida antes de cualquier borrado, y que `git diff` no deja `dd()`/`dump()`/`console.log`.
