# Branch Quality Review: flutter-loans-flexible-payments-v1

## Metadata

- Fecha: 2026-08-05 16:09
- Rama revisada: `main` (18 commits locales sin push)
- Rama base: `8a7b92a` (`docs: convención de montos en centavos + backup v3 en CLAUDE.md`)
- Rango: `8a7b92a..5411bc8` — 9 commits
- Commit HEAD: `5411bc8`
- Autor de revisión: Claude Opus 5
- Carpeta de reporte: `engineering/quality-review/flutter-loans-flexible-payments-v1/`

## Resumen ejecutivo

- **La rama NO es entregable tal cual**: hay un hallazgo bloqueante que produce respaldos irrecuperables.
- **B1** — `LoansDao.deleteLoan` no cascadea a `loan_adjustments`. Al eliminar un préstamo que tenía ajustes, el export deja un ajuste huérfano y **el JSON resultante no se puede importar** (`invalid_reference`). Verificado empíricamente, no inferido. El usuario produciría un respaldo que cree válido y descubriría que no sirve justo cuando lo necesita.
- El resto del sprint está sólido: la migración v15 es aditiva y no puede corromper datos existentes, las tres mutaciones de ajuste corren dentro de transacción recomputando el saldo, y `overpay_loan` —única regla contable del préstamo— quedó explícitamente blindada tras quitar los candados de calendario.
- La decisión de quitar `duplicate_monthly_payment` y `capital_before_monthly` es correcta para el caso de uso real y está bien documentada, pero **cambia la app de "valida por ti" a "confía en ti"** en un módulo con dinero. Es una decisión de producto explícita de Diego, no un descuido.
- Cobertura: 945 tests. Tres widget tests del plan quedaron sin implementar; uno de ellos (WT-LF-09) cubre precisamente el comportamiento que **sí** se conserva, así que no hay red que detecte si el chip naranja desaparece por accidente.
- La historia de commits es limpia y trazable: nueve commits separados por concepto, sin mezclas ni fix-ups internos. Revertir una pieza suelta es viable.
- Cuatro inconsistencias menores de validación y documentación, ninguna con riesgo de datos.

## Alcance revisado

- **Commits**: `8a47366`, `81de336`, `13c6523`, `6515579`, `fca9a58`, `2163235`, `98d3118`, `c0ae4ad`, `5411bc8`.
- **Archivos principales**: 38 archivos, +5408 / −1137.
  - Datos: `database.dart`, `daos/loans_dao.dart`, `daos/entries_dao.dart`, `backup.dart`, `financial_state.dart`.
  - UI: `loan_adjustment_form.dart` (nuevo), `loan_detail_screen.dart`, `dashboard_screen.dart`, `category_picker.dart`, `app_router.dart`, 6 formularios con corrección de prefills.
  - Tests: `loan_adjustments_test.dart` (nuevo), `loan_adjustments_ui_test.dart` (nuevo), `database_migration_test.dart`, `backup_test.dart`, `loan_payments_test.dart`, `loans_dao_test.dart`, `widget_test_harness.dart`.
- **Áreas**: migración de schema, dominio financiero, serialización de respaldo, UI de captura, pruebas.
- **Comandos usados**: `git diff --stat/--name-status 8a7b92a..HEAD`, `git log`, `flutter analyze lib`, `flutter test`, y un test temporal de verificación de B1 (creado, ejecutado y eliminado; no versionado).

## Hallazgos bloqueantes

### B1. `deleteLoan` no cascadea a `loan_adjustments` — produce respaldos no importables

- **Severidad**: Alta
- **Área**: Datos / integridad de respaldo
- **Evidencia**:
  - `mobile/lib/data/daos/loans_dao.dart:416-438` — `deleteLoan` cascadea `journal_entries` (income + pagos) y marca el préstamo, pero **no toca `loan_adjustments`**.
  - `mobile/lib/data/backup.dart:145-147` — el export selecciona ajustes con `deletedAt.isNull()`, sin verificar el estado de su préstamo.
  - `mobile/lib/data/backup.dart` (validación de referencia añadida en este sprint) — rechaza todo ajuste cuyo `loan_id` no esté en la lista `loans` del payload.
  - Verificado con test temporal:
    ```
    ajustes tras deleteLoan: 1, deleted_at=null
    export: loans vacío = true, trae loan_adjustments = true
    IMPORT FALLA con code=invalid_reference
    ```
- **Impacto**: secuencia realista de tres pasos — el usuario registra un ajuste, más tarde elimina el préstamo, y a partir de ese momento **todos sus respaldos quedan corruptos**. El export no falla ni avisa; el error aparece sólo al intentar restaurar, que es el peor momento posible. Para un producto cuyo valor central es "el archivo local es el producto", es el fallo más caro posible.
- **Recomendación**: cascadear en `deleteLoan`, dentro de la misma transacción y con el mismo `now`:
  ```dart
  await (update(attachedDatabase.loanAdjustments)
        ..where((a) => a.loanId.equals(id) & a.deletedAt.isNull()))
      .write(LoanAdjustmentsCompanion(
    deletedAt: Value(now), updatedAt: Value(now),
  ));
  ```
  Añadir dos tests: (a) los ajustes quedan con `deleted_at` tras `deleteLoan`; (b) el round-trip de respaldo sobrevive a un préstamo eliminado que tenía ajustes.

  Considerar además un **guardrail defensivo en el export**: filtrar ajustes cuyo `loan_id` no esté entre los préstamos exportados. Cubre respaldos generados por versiones con este bug ya instaladas y cualquier huérfano futuro por otra vía. Sin ese guardrail, un usuario que ya produjo un respaldo corrupto no tiene forma de recuperarlo.
- **Depende de**: ninguna.

## Hallazgos no bloqueantes

### M1. `reason` sin validación de longitud en el DAO, con tres límites distintos

- **Severidad**: Media
- **Área**: Validación de dominio
- **Evidencia**: `loan_adjustment_form.dart` limita a 200 (`maxLength: 200`); `backup.dart:916` valida contra `_kMaxDescriptionLength` = **1000**; `spec.md` y `CLAUDE.md` documentan **200**; `LoansDao.registerAdjustment` / `updateAdjustment` **no validan nada**.
- **Impacto**: la única barrera real es la UI. Un respaldo manipulado, o cualquier caller futuro que no pase por el formulario, puede persistir un motivo de 1000 caracteres que la UI no está diseñada para mostrar. No corrompe datos, pero rompe la invariante documentada.
- **Recomendación**: validar en el DAO —que es donde `CLAUDE.md` declara que vive el dominio— con el mismo límite de 200, y alinear el import a esa constante.
- **Depende de**: ninguna.

### M2. El diálogo de eliminar préstamo no informa del impacto sobre los ajustes

- **Severidad**: Media
- **Área**: UX de acción destructiva
- **Evidencia**: `mobile/lib/widgets/loan_actions_menu.dart:94` — el `DestructiveDialog` se puebla con `countActivePayments`, que sólo cuenta `journal_entries`.
- **Impacto**: una vez corregido B1, eliminar un préstamo se llevará también sus ajustes sin anunciarlo. El patrón del repo para acciones irreversibles es declarar el impacto completo antes de confirmar; aquí quedaría a medias.
- **Recomendación**: añadir un `countActiveAdjustments(loanId)` y sumarlo a los `DestructiveImpact` del diálogo.
- **Depende de**: B1.

### M3. Brecha de cobertura: el chip que se conserva no tiene test de regresión

- **Severidad**: Media
- **Área**: Pruebas
- **Evidencia**: `test-plan.md` listaba once widget tests; se implementaron ocho (documentado en D-08 del resumen). Falta **WT-LF-09**, que verifica que el chip naranja de próximo pago **sigue apareciendo**.
- **Impacto**: `WT-LF-08` sólo verifica que el chip rojo desapareció. Si un cambio futuro rompiera también el naranja, ningún test lo detectaría — y es el único indicador temporal que le queda al préstamo en el Dashboard. Los otros dos faltantes (WT-LF-07 doble submit, WT-LF-11 ausencia de diálogo de cascada) tienen menor riesgo: el primero está guardado por `if (_saving) return`, el segundo está cubierto a nivel de datos por UT-LF-28.
- **Recomendación**: implementar al menos WT-LF-09.
- **Depende de**: ninguna.

### M4. `applyPaymentSideEffects` conserva un nombre que ya no describe sus disparadores

- **Severidad**: Baja
- **Área**: Arquitectura / legibilidad
- **Evidencia**: `mobile/lib/data/daos/loans_dao.dart:309-350`. El método es ahora la reevaluación de estado del préstamo ante **cualquier** cambio de saldo — lo llaman seis sitios, tres de ellos mutaciones de ajuste que no son pagos.
- **Impacto**: quien lea `registerAdjustment` y vea `applyPaymentSideEffects` puede concluir que hay un pago de por medio. El punto es crítico (decide cierre y reapertura automáticos), así que la ambigüedad tiene costo real de comprensión. La deuda está reconocida en el propio docstring y en el resumen de implementación.
- **Recomendación**: renombrar a `recalculateLoanState` en un commit mecánico aparte, para no mezclarlo con cambios funcionales.
- **Depende de**: ninguna.

### M5. Desborde de layout preexistente en `kind_picker.dart`

- **Severidad**: Baja
- **Área**: Frontend
- **Evidencia**: `mobile/lib/widgets/kind_picker.dart:159` — `Column` desborda 4px verticalmente con viewport de 360dp. Expuesto por los widget tests nuevos, que usan un viewport de teléfono real en vez del 800×600 por defecto. `WT-LF-10` usa el viewport por defecto precisamente para esquivarlo.
- **Impacto**: franjas amarillas y negras en el formulario de movimiento en pantallas angostas. No afecta datos. Es preexistente al sprint; el sprint sí corrigió los dos equivalentes de `loan_detail_screen.dart` por ser archivo que ya tocaba.
- **Recomendación**: corregir en el sprint que toque el formulario de movimiento.
- **Depende de**: ninguna.

### M6. `watchBalance` por préstamo en la lista, ahora con una subconsulta más

- **Severidad**: Baja
- **Área**: Performance
- **Evidencia**: `mobile/lib/screens/loans_list_screen.dart:205` — un `StreamBuilder` con `watchBalance(loan.id)` por fila. Cada query ganó una subconsulta correlacionada contra `loan_adjustments`.
- **Impacto**: irrelevante a la escala real (single-user, un préstamo). Escala linealmente con el número de préstamos y ahora con coeficiente algo mayor. El índice parcial `idx_loan_adjustments_loan` está bien elegido para esta query.
- **Recomendación**: ninguna acción ahora. Si la lista llegara a decenas de préstamos, sustituir por una sola query agregada, como ya hace `_buildTotalLoansSource`.
- **Depende de**: ninguna.

## Lo que se revisó y quedó limpio

Vale la pena dejar constancia de lo verificado que **no** produjo hallazgo:

- **Migración v15**: la delegación `to == 15 → onUpgrade(m, from, 14)` es correcta y conserva el guardrail. Las BD en v1-v4 siguen sin ruta hasta 14 y caen en `UnimplementedError`, igual que antes del sprint — no es regresión. `MG-LF-03` cubre idempotencia; `MG-LF-04` las rutas 5/8/11/13/14.
- **Transaccionalidad**: las tres mutaciones de ajuste abren `db.transaction`, recomputan el saldo **dentro** y llaman a `applyPaymentSideEffects` sin abrir transacción anidada. No hay ventana de foto stale.
- **`overpay_loan`**: sigue vigente tras quitar los candados, con tests dedicados (UT-LF-24/25) que lo verifican en los dos escenarios nuevos que antes eran imposibles.
- **Orden de FK en el respaldo**: `loans` antes de `loan_adjustments` en el import; `loan_adjustments` antes de `loans` en `wipeAll`. Correcto con `PRAGMA foreign_keys=ON`.
- **Aislamiento del estado financiero**: un ajuste no genera `journal_entry` y no altera BO/DE/CR, verificado con test explícito.
- **Duplicación consciente de la fórmula de saldo**: documentada en los dos sitios y con un test que falla si divergen.
- **Historia de commits**: nueve commits separados por concepto, sin fix-ups internos ni mezcla de temas. Los `.g.dart` versionados ya lo estaban por convención del repo. Sin secretos ni artefactos.
- **Corrección de prefills ×100**: seis sitios, todos a `formatAmountForInput`. Es una regresión real de 0.33.0+121 corregida aquí; el commit lo declara.

## Plan de corrección ordenado

1. **B1** — cascadear `loan_adjustments` en `LoansDao.deleteLoan`, dentro de la transacción existente.
2. **B1** — añadir el guardrail defensivo en el export: filtrar ajustes cuyo préstamo no esté siendo exportado. Recupera respaldos ya generados con el bug.
3. **B1** — tests: cascada en `deleteLoan`, y round-trip de respaldo tras eliminar un préstamo con ajustes.
4. **M2** — `countActiveAdjustments` + impacto en el `DestructiveDialog` de eliminar préstamo (requiere 1).
5. **M1** — validar longitud de `reason` en el DAO y alinear el límite del import a 200.
6. **M3** — implementar WT-LF-09.
7. **M4** — renombrar `applyPaymentSideEffects` en commit mecánico aparte.
8. Suite completa + `flutter analyze` + rebuild del APK, porque B1 cambia comportamiento distribuible.
9. Reemplazar el APK de `~/fincore-respaldos/` y avisar a Diego de reinstalar.

## Validaciones recomendadas

```bash
cd mobile
flutter test
flutter analyze lib
flutter test test/data/loan_adjustments_test.dart test/data/backup_test.dart
flutter build apk --release --split-per-abi && ../scripts/verify-apk.sh
```

Smoke manual tras corregir B1, sobre una copia de la BD real:

1. Registrar un ajuste en un préstamo.
2. Eliminar el préstamo.
3. Settings → Exportar.
4. Reiniciar cuenta → Importar ese respaldo. **Debe funcionar.**

## Limitaciones

- Revisión ejecutada **sin subagentes**, en un solo pase secuencial. La instrucción operativa vigente para este asistente prohíbe lanzar agentes salvo petición explícita del usuario, y el skill los sugiere pero no los exige. Una revisión con perfiles paralelos podría encontrar hallazgos adicionales, especialmente en superficies que aquí se recorrieron una sola vez.
- No se ejecutó la app en dispositivo ni emulador. Los hallazgos de UI provienen de lectura de código y de los widget tests.
- No se auditó el rendimiento real de la migración v15 sobre una BD grande; el juicio se apoya en que la operación es un `CREATE TABLE` sin transformación de datos.
- B1 se verificó con un test temporal creado y eliminado durante la revisión; **no quedó versionado**, así que el hallazgo no está cubierto por la suite hasta que se implemente el paso 3 del plan.
- No se revisaron los 9 commits previos al sprint que también están sin push.
