# Plan de pruebas — flutter-loans-flexible-payments-v1

## Casos borde detectados

Además de los 15 de `spec.md`, la planeación detectó estos huecos:

**Concurrencia y transaccionalidad**

- CB-01: dos submits simultáneos de ajuste negativo, cada uno válido contra una foto stale del saldo, dejando el saldo negativo. El cálculo debe correr dentro de la transacción.
- CB-02: registrar un pago y un ajuste en paralelo sobre el mismo préstamo; ambos disparan `applyPaymentSideEffects` y podrían pelearse por el estado `closed_at`.
- CB-03: doble tap en el botón de confirmar del formulario de ajuste (doble submit desde UI).

**Edición y auto-exclusión**

- CB-04: editar un ajuste de `+50000` a `+60000`. Si la validación no excluye el propio ajuste del saldo base, el cálculo parte de un saldo que ya lo incluye y el resultado es incorrecto.
- CB-05: editar un ajuste positivo a negativo (cruce de signo) manteniendo el saldo válido.
- CB-06: editar un ajuste hasta monto cero → debe rechazarse igual que un alta con cero.

**Estados terminales**

- CB-07: ajuste sobre préstamo con `deleted_at` no nulo (préstamo archivado) → debe rechazarse con `not_found`.
- CB-08: eliminar un ajuste ya eliminado → idempotente, silencioso, como `deleteLoanPayment`.
- CB-09: préstamo cerrado `manual` con saldo que sube por ajuste → recalcula pero no reabre; el Dashboard sigue sin mostrarlo.
- CB-10: préstamo cerrado `paid` que se reabre por ajuste y vuelve a cerrarse al borrar ese ajuste (ciclo completo).

**Datos históricos y migración**

- CB-11: BD real de Diego (v14, 1 préstamo, 3 pagos) migrada a v15 → saldo idéntico al previo.
- CB-12: migración corrida dos veces sobre la misma BD → sin error, sin tabla duplicada.
- CB-13: rutas defensivas X→15 para X ∈ {5, 8, 11, 13, 14}.
- CB-14: préstamo preexistente sin ajustes → `SUM` sobre conjunto vacío devuelve `NULL`; el `COALESCE` debe absorberlo o el saldo se vuelve `NULL` y rompe `read<int>`.

**Backup**

- CB-15: export v4 de una BD sin ajustes → clave `loan_adjustments` presente y vacía, no ausente.
- CB-16: import v4 donde `loan_adjustments` viene ausente (payload manipulado) → tratar como vacío, no crashear.
- CB-17: import v4 con ajuste cuyo `loan_id` apunta a un préstamo que sí existe pero está en la lista como eliminado.
- CB-18: import v4 con `amount: 0` en un ajuste → el import es reemplazo total y no pasa por el DAO; decidir si valida o acepta. **Recomendación: validar y rechazar con `invalid_amount_format`**, para que no entre por la puerta trasera un estado que el DAO prohíbe.
- CB-19: orden de inserción en import — `loan_adjustments` antes que `loans` violaría la FK con `PRAGMA foreign_keys=ON`.
- CB-20: round-trip completo v4 con ajustes de ambos signos.

**Regresión de los candados eliminados**

- CB-21: dos pagos del mes en el mismo mes con capital que **sumado** excede el saldo → el segundo debe fallar con `overpay_loan`. Quitar el candado de unicidad no debe abrir la puerta a sobrepagar.
- CB-22: abono a capital en un mes sin pago del mes, cuyo capital excede el saldo → `overpay_loan` sigue vigente.
- CB-23: borrar un pago del mes con abonos del mismo mes → los abonos sobreviven (inversión de la cascada).
- CB-24: el préstamo se cierra como `paid` correctamente cuando el último pago que lo liquida es un abono a capital sin pago del mes previo.

**UI**

- CB-25: `CategoryPicker` tras elegir 3 categorías distintas en la misma sesión → estructura idéntica a la primera apertura.
- CB-26: formulario de ajuste con monto que excede el saldo en modo "disminuye" → error inline antes de submit, no snackbar tras fallo del DAO.
- CB-27: Dashboard con préstamo que antes mostraba chip rojo → no muestra ningún chip rojo en ningún estado.

## Pruebas unitarias necesarias

**Saldo con ajustes** (`test/data/loans_dao_test.dart` o archivo nuevo `loan_adjustments_test.dart`)

- UT-LF-01: préstamo sin ajustes → `balanceOf` idéntico a la fórmula de dos términos (blinda CB-14).
- UT-LF-02: ajuste `+X` → saldo previo `+ X`; `loans.principal_amount` sin cambio (CA-07).
- UT-LF-03: ajuste `−X` → saldo previo `− X`.
- UT-LF-04: dos ajustes de signos opuestos → saldo refleja el neto.
- UT-LF-05: ajuste con `deleted_at` no nulo → excluido del saldo.
- UT-LF-06: `watchBalance` reemite al insertar, editar y borrar un ajuste.

**Validaciones de ajuste**

- UT-LF-07: monto cero → `invalid_adjustment`, sin fila insertada (CA-10, CB-06).
- UT-LF-08: ajuste negativo que deja saldo < 0 → `invalid_adjustment`, sin fila.
- UT-LF-09: ajuste negativo que deja saldo exactamente 0 → aceptado.
- UT-LF-10: ajuste sobre préstamo inexistente o archivado → `not_found` (CB-07).
- UT-LF-11: ajuste sobre préstamo cerrado `paid` → aceptado (asimetría deliberada vs `loan_closed`).
- UT-LF-12: ajuste con `occurred_at` anterior a `contract_date` → aceptado (asimetría vs `payment_before_contract`).
- UT-LF-13: edición que excluye correctamente el propio ajuste del saldo base (CB-04).
- UT-LF-14: edición con cruce de signo (CB-05).
- UT-LF-15: borrado idempotente (CB-08).

**Transiciones de estado**

- UT-LF-16: ajuste positivo sobre préstamo `paid` → reabre (`closed_at IS NULL`, `close_reason IS NULL`) (CA-08).
- UT-LF-17: ajuste positivo sobre préstamo `manual` → no reabre (CA-09, CB-09).
- UT-LF-18: ajuste negativo que liquida → cierra como `paid`.
- UT-LF-19: borrar un ajuste positivo que sostenía el préstamo abierto → cierra como `paid`.
- UT-LF-20: ciclo completo reabrir → cerrar por borrado del ajuste (CB-10).

**Ausencia de candados** (inversión en `test/data/loan_payments_test.dart`)

- UT-LF-21: dos `loan_payment` con `is_monthly_payment = 1` en el mismo mes → ambos activos, saldo = suma de capitales (CA-01). Afirma **estado resultante**, no solo ausencia de excepción (RT-05).
- UT-LF-22: abono a capital sin pago del mes previo → insertado, saldo reducido (CA-02).
- UT-LF-23: tres pagos del mes en el mismo mes → los tres activos.
- UT-LF-24: `overpay_loan` sigue vigente con dos pagos que sumados exceden el saldo (CB-21).
- UT-LF-25: `overpay_loan` vigente en abono sin pago del mes (CB-22).
- UT-LF-26: cierre como `paid` cuando quien liquida es un abono a capital suelto (CB-24).
- UT-LF-27: `updateLoanPayment` que mueve un pago a un mes que ya tiene pago del mes → aceptado.

**Borrado sin cascada**

- UT-LF-28: borrar pago del mes con 2 abonos del mismo mes → los 2 abonos con `deleted_at IS NULL` (CA-04, CB-23).
- UT-LF-29: el saldo tras ese borrado refleja solo el pago borrado.

## Pruebas de integracion o API necesarias

No aplica en el sentido clásico (app local sin red). El equivalente es el backup:

- IT-LF-01: export v4 de BD con ajustes → `"version": 4` y clave `loan_adjustments` poblada.
- IT-LF-02: export v4 de BD sin ajustes → clave presente y vacía (CB-15).
- IT-LF-03: round-trip export → `wipeAll` → import → saldo y número de ajustes idénticos (CA-11, CB-20).
- IT-LF-04: import v3 en app v4 → sin error, cero ajustes, saldo por fórmula de dos términos (CA-12).
- IT-LF-05: import v2 y v1 → siguen funcionando (regresión).
- IT-LF-06: import v4 sin la clave `loan_adjustments` → tratado como vacío (CB-16).
- IT-LF-07: import v4 con `loan_id` inexistente → `invalid_reference`.
- IT-LF-08: import v4 con `amount` como `double` → `invalid_amount_format`.
- IT-LF-09: import v4 con `amount: 0` → `invalid_amount_format` (CB-18).
- IT-LF-10: import v4 con ajustes y préstamos, verificando que el orden de inserción respeta la FK (CB-19).

## Pruebas de UI o flujo necesarias

Sobre el harness `pumpFincoreApp` de `test/helpers/widget_test_harness.dart`:

- WT-LF-01: `/loans/:id` con ajustes → el historial los renderiza junto a los pagos.
- WT-LF-02: header muestra el desglose cuando hay ajustes y no lo muestra cuando no los hay.
- WT-LF-03: formulario de ajuste — alta feliz en modo "aumenta".
- WT-LF-04: formulario de ajuste — alta feliz en modo "disminuye".
- WT-LF-05: monto que excede el saldo en modo "disminuye" → error inline, submit bloqueado (CB-26).
- WT-LF-06: confirmación de reapertura al ajustar un préstamo cerrado `paid` (R-05).
- WT-LF-07: doble tap en confirmar → un solo ajuste insertado (CB-03).
- WT-LF-08: Dashboard con préstamo atrasado por calendario → sin chip rojo (CA-05, CB-27).
- WT-LF-09: Dashboard con pago próximo → chip naranja presente (regresión).
- WT-LF-10: `CategoryPicker` no renderiza sección de recientes tras varios usos (CA-13, CB-25).
- WT-LF-11: borrar un pago del mes con abonos → sin `DestructiveDialog` de cascada.

## Pruebas de permisos y seguridad

No aplica: app single-user, sin autenticación, sin roles, sin `userId` en el modelo.

Lo más cercano es la defensa contra payloads manipulados, cubierta en IT-LF-07 a IT-LF-09.

## Pruebas de datos, migracion o compatibilidad

En `test/data/database_migration_test.dart`:

- MG-LF-01: tras migrar v14 → v15, `pragma_table_info('loan_adjustments')` devuelve las 8 columnas con los tipos esperados (`amount` INTEGER).
- MG-LF-02: el índice `idx_loan_adjustments_loan` existe (`pragma_index_list`).
- MG-LF-03: migración idempotente — correrla dos veces no falla ni duplica (CB-12).
- MG-LF-04: rutas defensivas X→15 para X ∈ {5, 8, 11, 13, 14} (CB-13).
- MG-LF-05: un préstamo con pagos preexistente conserva exactamente su saldo tras migrar (CB-11).
- MG-LF-06: el guardrail `UnimplementedError` sigue disparando para un `to` desconocido.

## Pruebas de regresion sobre flujos existentes

- RG-LF-01: la suite completa de `loans_dao_test.dart` y `loan_payments_test.dart` pasa tras la inversión, sin `skip`.
- RG-LF-02: `financial_state_test.dart` sin cambios — un ajuste no toca BO/DE/CR (verifica RN-LF-08 desde el lado del estado financiero).
- RG-LF-03: `backup_test.dart` — todos los casos v1/v2/v3 previos siguen verdes.
- RG-LF-04: `reports` — ningún reporte cambia por la existencia de ajustes.
- RG-LF-05: `no_voseo_test.dart` sobre los strings nuevos del formulario de ajuste.
- RG-LF-06: `flutter analyze` sin errores nuevos.
- RG-LF-07: los tests de `entry_form` y del picker de categorías siguen verdes tras quitar el MRU.

## Pruebas manuales o smoke tests necesarios

En el teléfono de Diego, tras instalar 0.34.0+122:

- SM-01: abrir la app → la migración v15 corre sin crash; los saldos del Dashboard son idénticos a los previos.
- SM-02: registrar dos pagos con intereses en el mismo mes calendario sobre su préstamo quincenal (**el caso que originó el sprint**).
- SM-03: registrar un abono a capital en un mes sin pago del mes.
- SM-04: registrar el ajuste real del banco (`+$100`) y verificar que el saldo cuadra con la app bancaria (CM-05).
- SM-05: verificar que el préstamo ya no muestra chip rojo de atraso en el Dashboard.
- SM-06: abrir el selector de categorías en varios movimientos seguidos → estructura siempre igual.
- SM-07: Settings → Exportar → el JSON declara `"version": 4` y contiene `loan_adjustments`.
- SM-08: borrar un pago del mes que tenga abonos → los abonos siguen ahí.

## Datos de prueba recomendados

- Préstamo base: `principal_amount = 3700000` (=$37,000), `monthly_payment = 250000`, `payment_day = 5`, `contract_date` a 3 meses atrás.
- Pagos: 3 pagos del mes con split capital/intereses + 1 abono a capital, dejando el saldo cerca de `3490000`.
- Ajustes: uno `+10000` (el caso de Diego) y uno `−5000` para cubrir ambos signos.
- Préstamo secundario cerrado como `paid` con saldo 0, para las pruebas de reapertura.
- Préstamo terciario cerrado como `manual`, para verificar que no reabre.
- Respaldo real de Diego en `~/fincore-respaldos/fincore-backup-2026-08-05-v3.json` para la validación final. **No versionar** (P-006 del sprint anterior).

## Comandos o validaciones locales sugeridas

```bash
cd mobile
dart run build_runner build --delete-conflicting-outputs   # tras tocar database.dart
flutter test
flutter analyze
flutter test test/data/loan_adjustments_test.dart          # iteración rápida
grep -rn "duplicate_monthly_payment\|capital_before_monthly" lib   # debe salir vacío (CA-03)
grep -rn "watchMonthsOverdue\|expectedPaymentMonths" lib           # debe salir vacío (CA-06)
grep -rn "_sessionMRU" lib                                         # debe salir vacío (CA-13)
grep -rn "0\.005" lib --include="*.dart"                           # solo fincore_colors.dart y money.dart (CA-14)
flutter build apk --release --split-per-abi
scripts/verify-apk.sh                                              # versionCode 2122 / 0.34.0
```

## Criterios minimos para aprobar la implementacion

1. Los 16 criterios de aceptación de `spec.md` (CA-01 a CA-16) verificados.
2. Suite completa en verde, ≥ 910 tests (CM-01), sin ningún test en `skip`.
3. Los 20 puntos de test de los candados invertidos o eliminados, cada inversión afirmando estado resultante y no solo ausencia de excepción (CM-02, RT-05).
4. `flutter analyze` con como máximo los 3 hints preexistentes de `entry_form_screen.dart:510-513` (CM-03).
5. Migración validada contra una copia de la BD real de Diego, con saldo idéntico pre y post (CB-11).
6. Round-trip de backup v4 verificado sobre el respaldo real, sin versionar el test (IT-LF-03).
7. `scripts/verify-apk.sh` confirmando `versionCode 2122 / versionName 0.34.0` (CM-04).
8. Kit de rollback preparado en `~/fincore-respaldos/` **antes** de entregar el APK a Diego: export v3 fresco + APK 0.33.0+121 + APK nuevo (R-01).

## Validacion final recomendada

Ejecutar la skill `branch-quality-review` sobre la rama al cerrar la implementación. Genera su propio reporte en `engineering/quality-review/flutter-loans-flexible-payments-v1/`; no duplicar ese contenido dentro de `implementation/`.

Puntos a los que dirigir esa revisión, por ser donde este sprint concentra el riesgo:

- Transaccionalidad de las tres mutaciones de ajuste y su interacción con `applyPaymentSideEffects`.
- Que la eliminación de los candados no haya debilitado `overpay_loan` (CB-21, CB-22).
- Cobertura real de las ramas defensivas de migración X→15.
- Que ningún reporte ni `FinancialStateService` haya quedado acoplado a `loan_adjustments`.
- Semántica de color del signo del ajuste en la UI (RT-06), por ser un error silencioso con consecuencia financiera.
