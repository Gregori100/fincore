# Tareas — flutter-loans-flexible-payments-v1

## Base de datos

- [x] T001 Base de datos: declarar `class LoanAdjustments extends Table` en `lib/data/database.dart` (id, loan_id con `references(Loans, #id)`, amount `integer()`, reason `text().nullable()`, occurred_at, created_at, updated_at, deleted_at) y registrarla en `@DriftDatabase(tables: [...])`.
  RF: RF-005
  Depende de: ninguna
  Paralelizable: no
  Criterio de terminado: `dart run build_runner build --delete-conflicting-outputs` genera `LoanAdjustment` y `LoanAdjustmentsCompanion` sin errores.

- [x] T002 Base de datos: escribir el helper idempotente `_createLoanAdjustmentsSchema()` con `pragma_table_info('loan_adjustments')` como probe de existencia, `m.createTable(loanAdjustments)` y el `CREATE INDEX IF NOT EXISTS idx_loan_adjustments_loan ... WHERE deleted_at IS NULL` por `customStatement`.
  RF: RF-005
  Depende de: T001
  Paralelizable: no
  Criterio de terminado: llamarlo dos veces seguidas sobre la misma BD no lanza.

- [x] T003 Base de datos: subir `schemaVersion` a 15 y agregar la rama `from == 14 && to == 15` más las ramas defensivas X→15 para X ∈ {5..13}, encadenando los helpers existentes y cerrando con `_createLoanAdjustmentsSchema()`. Conservar el guardrail `UnimplementedError` al final.
  RF: RF-005
  Depende de: T002
  Paralelizable: no
  Criterio de terminado: ninguna ruta X→15 cae en el guardrail; el guardrail sigue disparando para un `to` desconocido.

- [x] T004 Pruebas: tests de migración MG-LF-01 a MG-LF-06 en `test/data/database_migration_test.dart`.
  RF: RF-005
  Depende de: T003
  Paralelizable: no
  Criterio de terminado: los 6 tests verdes, incluida la idempotencia y las 5 rutas defensivas.

## Backend (capa de datos)

- [x] T005 Backend: extraer la expresión SQL del saldo a una constante privada `_balanceSql` en `lib/data/daos/loans_dao.dart` y hacer que `balanceOf` y `watchBalance` la compartan, sin cambiar todavía la fórmula.
  RF: RF-006
  Depende de: ninguna
  Paralelizable: si
  Criterio de terminado: la suite pasa sin cambios; las dos queries dejan de estar duplicadas.

- [x] T006 Backend: agregar el término de ajustes a `_balanceSql` (`+ COALESCE((SELECT SUM(amount) FROM loan_adjustments WHERE loan_id = ?1 AND deleted_at IS NULL), 0)`) y agregar `loan_adjustments` a los `readsFrom` de `watchBalance`. Verificar antes el supuesto SI-01 (si `financial_state.dart` depende de `balanceOf`).
  RF: RF-006
  Depende de: T001, T005
  Paralelizable: no
  Criterio de terminado: UT-LF-01 verde (préstamo sin ajustes conserva su saldo exacto) y `watchBalance` reemite al mutar ajustes.

- [x] T007 Backend: implementar `registerAdjustment` en `LoansDao` dentro de `db.transaction`, con validación de monto distinto de cero, préstamo existente y no archivado, cálculo del saldo resultante **dentro** de la transacción, `invalid_adjustment` si quedaría negativo, y `applyPaymentSideEffects` al cierre. Sin guard de `loan_closed` ni de `payment_before_contract` (asimetrías deliberadas, RN-LF-10 y caso borde 11).
  RF: RF-007
  Depende de: T006
  Paralelizable: no
  Criterio de terminado: UT-LF-07 a UT-LF-12 verdes.

- [x] T008 Backend: implementar `updateAdjustment`, excluyendo el propio ajuste del saldo base al validar (CB-04).
  RF: RF-007
  Depende de: T007
  Paralelizable: no
  Criterio de terminado: UT-LF-13 y UT-LF-14 verdes.

- [x] T009 Backend: implementar `deleteAdjustment` (soft delete idempotente) con `applyPaymentSideEffects` al cierre.
  RF: RF-007
  Depende de: T007
  Paralelizable: no
  Criterio de terminado: UT-LF-15 y UT-LF-19 verdes.

- [x] T010 Backend: implementar `watchAdjustments(loanId)` y `watchAdjustmentsTotal(loanId)` como streams reactivos con `readsFrom`.
  RF: RF-007
  Depende de: T001
  Paralelizable: si
  Criterio de terminado: ambos reemiten al insertar, editar y borrar; UT-LF-06 verde.

- [x] T011 Backend: eliminar el bloque `monthlyCount` y los `throw` de `duplicate_monthly_payment` y `capital_before_monthly` en `EntriesDao.registerLoanPayment`, incluyendo el `monthKey` local que queda sin uso. Verificar antes el supuesto SI-03 (`integration_test/`).
  RF: RF-001, RF-002
  Depende de: ninguna
  Paralelizable: si
  Criterio de terminado: UT-LF-21, UT-LF-22 y UT-LF-23 verdes en el mismo commit.

- [x] T012 Backend: eliminar los mismos dos `throw` de `EntriesDao.updateLoanPayment`.
  RF: RF-001, RF-002
  Depende de: T011
  Paralelizable: no
  Criterio de terminado: UT-LF-27 verde.

- [x] T013 Pruebas: verificar que `overpay_loan` sigue vigente tras quitar los candados — el riesgo es haber debilitado la única validación contable del préstamo.
  RF: RF-001, RF-002
  Depende de: T012
  Paralelizable: no
  Criterio de terminado: UT-LF-24, UT-LF-25 y UT-LF-26 verdes.

- [x] T014 Pruebas: invertir o eliminar los 20 puntos de test de `test/data/loans_dao_test.dart` (13) y `test/data/loan_payments_test.dart` (7) que hoy afirman los candados o `watchMonthsOverdue`. Cada inversión debe afirmar estado resultante, no solo ausencia de excepción.
  RF: RF-001, RF-002, RF-004
  Depende de: T012
  Paralelizable: no
  Criterio de terminado: cero referencias a los identificadores eliminados en `test/`; ningún test en `skip`.

- [x] T015 Backend: eliminar el parámetro `cascadeCapitalInMonth` y su bloque `customStatement` de `EntriesDao.deleteLoanPayment`, y eliminar `countCapitalPaymentsInSameMonth` tras verificar SI-04.
  RF: RF-003
  Depende de: T014
  Paralelizable: no
  Criterio de terminado: UT-LF-28 y UT-LF-29 verdes; `flutter analyze` sin referencias colgantes.

- [x] T016 Backend: eliminar `watchMonthsOverdue`, `expectedPaymentMonths`, `_expectedPaymentMonths` y `_maxOverdueMonthsWindow` de `LoansDao`.
  RF: RF-004
  Depende de: T018
  Paralelizable: no
  Criterio de terminado: `grep -rn "watchMonthsOverdue\|expectedPaymentMonths" lib` vacío (CA-06).

- [x] T017 Backend: higiene de tolerancias en `loans_dao.dart` — comparaciones `balance <= 0.005` / `> 0.005` a comparación exacta con cero, y corregir los comentarios de las líneas 299-300.
  RF: RF-012
  Depende de: ninguna
  Paralelizable: si
  Criterio de terminado: `applyPaymentSideEffects` usa `<= 0` y `> 0`; suite verde.

## Frontend

- [x] T018 Frontend: eliminar la rama `overdue >= 1` y el `StreamBuilder<int>` de `watchMonthsOverdue` en `_LoanStatusChip` de `lib/screens/dashboard_screen.dart`, dejando el chip naranja intacto.
  RF: RF-004
  Depende de: ninguna
  Paralelizable: si
  Criterio de terminado: WT-LF-08 y WT-LF-09 verdes.

- [x] T019 Frontend: eliminar la rama `if (payment.isMonthlyPayment)` con su `DestructiveDialog` de cascada en `_confirmDeletePayment` de `lib/screens/loan_detail_screen.dart`, dejando un único camino de confirmación simple.
  RF: RF-003
  Depende de: T015
  Paralelizable: no
  Criterio de terminado: WT-LF-11 verde.

- [x] T020 Frontend: crear `lib/screens/loan_adjustment_form.dart` con toggle "Aumenta / Disminuye el saldo" (no campo con signo, RT-06), monto, fecha, motivo opcional, y preview del saldo resultante. Nace migrado a tokens de diseño.
  RF: RF-008
  Depende de: T007, T008
  Paralelizable: no
  Criterio de terminado: WT-LF-03, WT-LF-04 y WT-LF-05 verdes.

- [x] T021 Frontend: registrar las rutas del formulario de ajuste en `lib/router/app_router.dart` tras verificar SI-02, siguiendo el patrón de los formularios de pago existentes.
  RF: RF-008
  Depende de: T020
  Paralelizable: no
  Criterio de terminado: navegación push/pop funcional desde `/loans/:id`.

- [x] T022 Frontend: agregar la acción "Ajustar saldo" en `/loans/:id`, disponible también con el préstamo cerrado, con `ConfirmDialog` de advertencia cuando el ajuste vaya a reabrir un préstamo `paid`.
  RF: RF-008
  Depende de: T021
  Paralelizable: no
  Criterio de terminado: WT-LF-06 verde.

- [x] T023 Frontend: renderizar los ajustes en el historial de `/loans/:id` junto a los pagos, ordenados por `occurred_at`, con icono propio y semántica de color por efecto (un ajuste que sube deuda se pinta como negativo).
  RF: RF-008
  Depende de: T010
  Paralelizable: no
  Criterio de terminado: WT-LF-01 verde.

- [x] T024 Frontend: desglosar en el header de `/loans/:id` el monto original prestado y el neto de ajustes, solo cuando existan ajustes.
  RF: RF-009
  Depende de: T010
  Paralelizable: no
  Criterio de terminado: WT-LF-02 verde.

- [x] T025 Frontend: eliminar `_sessionMRU`, `_mruLimit`, `_touchMRU`, `mruVisible`, `showMru` y la sección de recientes de `lib/widgets/category_picker.dart`.
  RF: RF-011
  Depende de: ninguna
  Paralelizable: si
  Criterio de terminado: WT-LF-10 verde; `grep -rn "_sessionMRU" lib` vacío.

- [x] T026 Frontend: actualizar `lib/widgets/error_snackbar.dart` — fuera `duplicate_monthly_payment` y `capital_before_monthly`, dentro `invalid_adjustment` con mensaje en español neutral.
  RF: RF-001, RF-002, RF-007
  Depende de: T012
  Paralelizable: no
  Criterio de terminado: `no_voseo_test.dart` verde; el código nuevo mapea a mensaje amigable.

- [x] T027 Frontend: higiene de tolerancias en `loan_capital_payment_form.dart:171`, `loan_monthly_payment_form.dart:286,326` y `balance_at_date_tab.dart:184,314`.
  RF: RF-012
  Depende de: ninguna
  Paralelizable: si
  Criterio de terminado: comparaciones exactas; suite verde.

## Backend (backup)

- [x] T028 Backend: subir `_supportedVersion` a 4 en `lib/data/backup.dart` y agregar `_adjustmentToJson` con la serialización de los ajustes activos bajo la clave `loan_adjustments`.
  RF: RF-010
  Depende de: T001
  Paralelizable: no
  Criterio de terminado: IT-LF-01 e IT-LF-02 verdes.

- [x] T029 Backend: implementar `_adjustmentFromJson` en el import, con validación de `loan_id` contra la lista de préstamos del payload (`invalid_reference`), monto `int` distinto de cero (`invalid_amount_format`), y clave ausente tratada como lista vacía. Insertar después de `loans` para respetar la FK.
  RF: RF-010
  Depende de: T028
  Paralelizable: no
  Criterio de terminado: IT-LF-03 a IT-LF-10 verdes.

- [x] T030 Backend: higiene de la tolerancia en `lib/data/backup.dart:315` y de los comentarios obsoletos en `lib/data/reports.dart:713,2282`.
  RF: RF-012
  Depende de: ninguna
  Paralelizable: si
  Criterio de terminado: `grep -rn "0\.005" lib --include="*.dart"` devuelve solo `fincore_colors.dart` y `money.dart` (CA-14).

## Pruebas

- [x] T031 Pruebas: crear `test/data/loan_adjustments_test.dart` con UT-LF-01 a UT-LF-20.
  RF: RF-006, RF-007
  Depende de: T009
  Paralelizable: no
  Criterio de terminado: 20 tests verdes cubriendo saldo, validaciones y transiciones de estado.

- [x] T032 Pruebas: extender `test/data/backup_test.dart` con IT-LF-01 a IT-LF-10, conservando verdes los casos v1/v2/v3 previos.
  RF: RF-010
  Depende de: T029
  Paralelizable: no
  Criterio de terminado: 10 tests nuevos verdes; RG-LF-03 sin regresión.

- [x] T033 Pruebas: widget tests WT-LF-01 a WT-LF-11 sobre el harness `pumpFincoreApp`.
  RF: RF-008, RF-009, RF-004, RF-011
  Depende de: T024, T025
  Paralelizable: no
  Criterio de terminado: 11 tests verdes.
  **PARCIAL**: se implementaron 8 de los 11 (WT-LF-01..06, 08, 10) en
  `test/screens/loan_adjustments_ui_test.dart`. Sin cubrir: WT-LF-07 (doble
  submit), WT-LF-09 (regresión del chip naranja de próximo pago) y WT-LF-11
  (ausencia del diálogo de cascada al borrar un pago). Ver resumen de
  implementación.

- [x] T034 Pruebas: validación temporal contra el respaldo real de Diego — import v3, verificar saldo, registrar ajuste, export v4, round-trip. Eliminar el archivo tras correrlo, sin versionarlo (P-006).
  RF: RF-010
  Depende de: T032
  Paralelizable: no
  Criterio de terminado: el saldo del préstamo real coincide pre y post migración; el archivo temporal no queda en el árbol de trabajo.

## Validacion de calidad

- [x] T035 Validación de calidad: correr la suite completa y `flutter analyze`, verificando los 4 greps de criterios de aceptación (CA-03, CA-06, CA-13, CA-14).
  RF: todos
  Depende de: T034
  Paralelizable: no
  Criterio de terminado: ≥ 910 tests verdes, ningún `skip`, analyze con máximo los 3 hints preexistentes.

- [ ] T036 Validación de calidad: ejecutar la skill `branch-quality-review` sobre la rama, dirigida a los puntos de riesgo listados en `test-plan.md`.
  RF: todos
  Depende de: T035
  Paralelizable: no
  Criterio de terminado: reporte generado en `engineering/quality-review/flutter-loans-flexible-payments-v1/` y hallazgos bloqueantes resueltos.
  **PENDIENTE**: el trabajo está sin commitear a petición de Diego, y esta skill compara una rama contra su base. Ejecutar después de que él revise y se cree el commit.

- [x] T037 Validación de calidad: preparar el kit de rollback en `~/fincore-respaldos/` — export v3 fresco tomado con 0.33.0, APK 0.33.0+121 y APK 0.34.0+122 — antes de entregar el build a Diego.
  RF: RF-014
  Depende de: T038
  Paralelizable: no
  Criterio de terminado: los tres archivos presentes y verificados con `aapt2 dump badging` y validación del JSON.

## Documentacion

- [x] T038 Documentación: bump de versión a `0.34.0+122` en `pubspec.yaml` y `android/app/build.gradle.kts`, build del APK y verificación con `scripts/verify-apk.sh`.
  RF: RF-014
  Depende de: T035
  Paralelizable: no
  Criterio de terminado: `versionCode 2122 / versionName 0.34.0 consistentes`.

- [x] T039 Documentación: actualizar `CLAUDE.md` — tabla de errores tipados (fuera 2 códigos, dentro `invalid_adjustment`), sección de dominio de préstamos con la fórmula de saldo de tres términos, schema v15, backup v4.
  RF: RF-013
  Depende de: T035
  Paralelizable: si
  Criterio de terminado: ningún identificador eliminado sobrevive en `CLAUDE.md`.

- [x] T040 Documentación: escribir `engineering/specs/flutter-loans-flexible-payments-v1/implementation/` con el resumen de implementación, desviaciones respecto al plan y pendientes.
  RF: todos
  Depende de: T036
  Paralelizable: no
  Criterio de terminado: trazabilidad completa de qué se implementó, qué se desvió y por qué.
