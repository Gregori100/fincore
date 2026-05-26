# Resumen extenso — Respaldos

## Contexto tomado de la spec

Feature de export/import del dominio financiero. El usuario simplificó el alcance durante la definición: **solo export + import en modo reemplazo total** (reusa `HardResetUserData` modo full); el **merge aditivo** quedó fuera de alcance como v2 por su complejidad (regla de elegibilidad de movimientos que cruzan cuentas existentes vs nuevas). El respaldo incluye cuentas, categorías y movimientos activos; excluye el plan y los registros soft-deleted. Todo es manual.

## Relación con el plan

Se siguieron las tareas T001–T016 del plan. Orden ejecutado: export (T001) → exception (T002) → import núcleo con resolución del anidamiento de transacción (T003/T004) → controller + rutas (T005/T006) → tests unit y de ciclo (T010/T011) → suites (T012/T013) → frontend (T007/T008/T009) → docs (T016). T014 (manual) y T015 (branch-quality-review) quedan pendientes.

## Cambios principales por módulo o capa

### Dominio (backend)

- **`ExportUserData::execute(userId): array`**: lee cuentas/categorías/entries activos (sin `withTrashed`) y arma `{ version:1, exported_at, accounts, categories, entries }`. Cada entry referencia `account_origin_local`, `account_destination_local`, `category_local` (los UUID originales como identificadores locales del archivo).
- **`ImportUserData::execute(userId, backup): array`**: valida `version` y estructura (lanza `InvalidBackupFile`); dentro de un `DB::transaction` ejecuta `HardResetUserData::execute(userId, 'full')` y restaura:
  - Cuentas: las cash/protegidas del archivo se mapean a la Bolsa existente (que el reset conserva); las demás se crean nuevas con UUID regenerado. Mapa `local_id → id real`.
  - Categorías: reconciliación por nombre (case-insensitive + trim); reusa o crea. Dedup intra-archivo.
  - Entries: resuelve FKs vía los mapas; omite filas con kind inválido, amount ≤ 0, fecha no parseable o referencia de cuenta que no resuelve. La categoría que no resuelve deja el movimiento sin categoría (no lo omite).
  - Retorna resumen de conteos.
- **`InvalidBackupFile`**: exception de dominio, código `invalid_backup_file`, 422.

### HTTP (backend)

- `SettingsController::exportData` (GET) y `importData` (POST). `importData` valida `password` (Hash::check) + `backup` (array) antes de delegar.
- Dos rutas en el grupo `finance` con `auth:sanctum` + `verified`.

### Frontend

- `api/settings.js`: `exportBackup()`, `importBackup(password, backup)`.
- `SettingsView.vue`: sección "Respaldos" (descargar genera un Blob y dispara descarga `fincore-backup-YYYY-MM-DD.json`; aplicar abre modal con `<input type=file>`, parseo en cliente con validación de `version`, input de contraseña, confirmación). Tras éxito: toast con resumen, `plan.reset()`, `finance.fetchState()`, redirect a dashboard.

## Desviaciones respecto al plan

- **Merge fuera de alcance**: ya estaba decidido en la spec; el plan reflejaba solo replace. Sin desviación real.
- **Transporte**: se confirmó JSON en el body (no multipart), como anticipaba el plan.
- Ninguna otra desviación. No se agregaron tests vitest nuevos (la lógica pesada está en backend; el plan ya lo preveía).

## Pruebas realizadas y recomendadas

Realizadas:
- `ImportUserDataTest` 9/9, `BackupTest` 11/11. Suite backend 295/295, frontend 49/49.
- El test central `test_full_cycle_preserves_balances` confirma delta 0.00 en BO/DE/CR tras export→reset→import.
- `test_rollback_on_failure_keeps_previous_data` confirma atomicidad de la transacción anidada.

Recomendadas:
- Recorrido manual de 6 pasos (T014).
- `branch-quality-review` (T015).
- Test de performance informal con ~200 movimientos (no ejecutado; el rango de uso personal no lo amerita aún).

## Riesgos residuales y posibles regresiones

- Categorías acumuladas en replace (unión, no fidelidad estricta) — documentado, ajustable.
- Archivo de texto plano sin cifrar — resguardo del usuario.
- `HardResetUserData` intacto → `HardResetTest` sin regresión. Sin cambios de schema. `/settings` extiende sin romper los resets existentes.
