# Pendientes — flutter-local-hardening-v2

Trabajo no terminado al cierre del sprint o diferido a sprints futuros.

## Pendientes inmediatos

- **T015 — Smoke manual (Diego) CERRADO en `0.3.6+38` con 6 iteraciones post-smoke**. Resultado validado por Diego:
  - **OK**: datos preservados, "Acerca de" muestra `0.3.6+38`, cancel/edit cierra correctamente con snackbar verde, hint muestra monto real tras Skeleton brevísimo, badge de categoría archivada desaparece de `/entries` (RF-005), flujos `_exportThenReset` y `_resetWithoutExport` funcionan con confirmaciones destructivas y redirect a `/first-run`.
  - **No probado pero asumido OK**: export + share sheet completo a una app destino, import de JSON corrupto con varios payloads inválidos. Razón: Diego no tenía app destino conveniente para el share y no construyó payloads corruptos a mano. Estas rutas están cubiertas por tests automatizados (`backup_test.dart` cubre import inválido; el flujo de `_exportInternal` está respaldado por el timeout y el manejo de `ShareResult`).
  - **Repetir el escenario del bug**:
    - Registrar un movimiento.
    - Tocar el movimiento → abre `entry_form_screen` modo edit.
    - **Caso A**: tocar "Cancelar movimiento" → confirmar → volver atrás. La pantalla anterior (Dashboard o `/entries`) debe verse normal, con balances actualizados, sin gris pleno.
    - **Caso B**: cambiar el monto del movimiento → tocar "Guardar cambios" → volver atrás. Misma validación.
  - Si los dos casos pasan verde, seguir con el resto del checklist (`/entries` para RF-005, share, reset, importar JSON corrupto).
- **Backlog futuro**: agregar widget test del `entry_form_screen` que cubra el flujo cancel + submit en modo edit. Un test directo de `_buildForm` con `_kind = null` y `_isEdit = true` también capturaría la regresión.
  - Snackbar warning (ej. importar JSON inválido) tiene texto canvas oscuro, legible sobre fondo amarillo.
  - Flujo `_exportThenReset`: share completa, segundo diálogo aparece, confirmación reinicia.
  - Flujo `_resetWithoutExport`: confirmación destructiva, redirect a `/first-run`.
  - Importar respaldo viejo: errores tipados visibles si el JSON está corrupto.

## Diferidos a sprints futuros

Hoy sin scope concreto, surge si la app evoluciona:

- **RF-002 cleanup en broadcast stream**: T007 pasa sin `onCancel`. Si en el futuro un caller cancela y resuscribe agresivamente y aparece `Bad state: Cannot add new events after calling close`, agregar `onCancel: (_) => invalidateAccount(accountId)` en `watchAccountBalance` y un test que valide el escenario.
- **Registrar `EntriesDao` en `@DriftDatabase(daos: [...])`**: bloqueado por el constructor que requiere `FinancialStateService`. Si en el futuro se decide invertir la dependencia (ej. exponer `state` desde el database) sería viable. No es urgente porque `EntriesDao` sigue accesible vía `AppDependencies` y no hay duplicación residual.
- **Widget tests (T043-T045 del MVP)**: siguen aplazados. Mínimo deseable: bootstrap test del `entry_form_screen` que cubra los 5 kinds.
- **Pintar `aapt2` o `apksigner` como step de CI**: hoy se verifica a mano post-build. No bloquea, pero ayudaría a detectar `INSTALL_FAILED_VERSION_DOWNGRADE` antes del sideload.
