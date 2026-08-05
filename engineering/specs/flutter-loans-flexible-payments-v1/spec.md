# Préstamos flexibles: sin candados de calendario + ajuste de saldo (flutter-loans-flexible-payments-v1)

## Resumen

El modelo de préstamos de FinCore asumió que todo préstamo se paga **una vez al mes**. Esa suposición se materializó en dos candados de dominio (`duplicate_monthly_payment`, `capital_before_monthly`), en una cascada de borrado que los sostiene, y en un chip rojo de "meses atrasados" en el Dashboard. El préstamo real de Diego resultó ser **quincenal**, así que la app lo bloquea al registrar su segundo pago del mes, le impide abonar a capital cuando no hay "pago del mes" previo, y lo acusa de atrasos que no existen.

En paralelo, el banco de Diego **subió el saldo pendiente** del préstamo sin que mediara un movimiento de dinero (el capital había bajado a ~$34,900 y reapareció en ~$35,000). Hoy el saldo es puramente derivado (`principal_amount − Σ pagos.principal_amount`), así que la única forma de corregirlo sería reescribir `principal_amount`, que es dato histórico ("lo que me prestaron") y no debe tocarse.

Este sprint hace tres cosas: **quita las reglas de calendario** conservando el día de pago como información, **agrega un tercer término al saldo** vía una tabla de ajustes con historial, y aprovecha para **eliminar el MRU de categorías** del picker (estado invisible que produce UI impredecible) y **la basura de tolerancias `0.005`** que sobrevivió al sprint `flutter-integer-cents-v1`.

Schema sube a **v15**. Backup sube a **v4**.

## Problema a resolver

### 1. El candado de pago único mensual bloquea préstamos no mensuales

`EntriesDao.registerLoanPayment` (`lib/data/daos/entries_dao.dart:432-448`) cuenta los `loan_payment` con `is_monthly_payment = 1` del mes calendario y lanza `duplicate_monthly_payment` si ya existe uno. El préstamo de Diego se paga cada quincena: dos pagos con intereses en el mismo mes son el caso **normal**, no una anomalía. La regla replicada en `updateLoanPayment` (`entries_dao.dart:594`) produce el mismo bloqueo al editar.

### 2. El candado de orden impide abonar a capital fuera del mes pagado

El mismo bloque (`entries_dao.dart:449-454`, replicado en `entries_dao.dart:600`) lanza `capital_before_monthly` cuando se intenta registrar un abono a capital en un mes calendario sin pago del mes. Diego quiso abonar a capital en un mes en que no había registrado el pago con intereses y quedó bloqueado.

La regla contradice además la filosofía "libreta libre" declarada en `CLAUDE.md`: los gastos, transferencias y cargos se permiten siempre aunque dejen saldo negativo; el préstamo es la única entidad que impone un orden de captura al usuario.

### 3. El Dashboard reporta atrasos falsos

`_LoanStatusChip._buildChip` (`lib/screens/dashboard_screen.dart:520-528`) pinta un chip rojo `"N meses atrasados"` alimentado por `LoansDao.watchMonthsOverdue` (`lib/data/daos/loans_dao.dart:507-536`), que cuenta **meses calendario sin pago del mes**. En un préstamo quincenal ese conteo no significa nada: el usuario puede estar perfectamente al corriente y ver una alerta roja permanente.

### 4. No existe forma de ajustar el saldo sin falsear el monto original

`LoansDao.balanceOf` / `watchBalance` (`loans_dao.dart:74-96`):

```sql
saldo = loans.principal_amount − COALESCE(Σ journal_entries.principal_amount, 0)
```

Con solo dos términos, subir el saldo obliga a subir `principal_amount` (falsea el préstamo original) o a inventar un pago con capital negativo (rompe invariantes y ensucia el historial). Diego necesita reflejar el ajuste del banco manteniendo el préstamo cuadrado con la app bancaria, **sin perder** el monto que le prestaron.

Restricción crítica: **el ajuste no es un movimiento de dinero**. No salió ni entró efectivo de ninguna cuenta, así que no puede generar un `journal_entry` ni alterar BO/DE/CR ni aparecer en `/entries`.

### 5. El MRU de categorías aparece y desaparece sin patrón

`_CategoryPickerSheetState._sessionMRU` (`lib/widgets/category_picker.dart:129-182`) mantiene los últimos 5 IDs elegidos **en memoria de proceso**, y solo renderiza la sección "recientes" si quedan **≥2** visibles tras filtrar por `validAppliesTo` y por la query.

Consecuencia observada por Diego: la sección aparecía al capturar un gasto con tarjeta y no al capturar un gasto común. La causa no es el tipo de movimiento (ambos usan categorías de gasto) sino que la lista se llena conforme se usa el picker en esa sesión y se vacía al reiniciar la app. Es estado invisible que hace la UI impredecible.

### 6. Tolerancias residuales del sprint de centavos

`flutter-integer-cents-v1` declaró en `CLAUDE.md` la regla **RN-IC-05**: *"las comparaciones de montos son estrictas; cualquier tolerancia tipo `+ 0.005` que aparezca es un bug"*. Quedaron 7 comparaciones de `int` contra `0.005` sin migrar. Son funcionalmente inocuas (para un entero, `x <= 0.005` equivale a `x <= 0`) pero contradicen la regla recién escrita y confunden a quien lea el código.

## Objetivo

1. Registrar **N pagos con intereses** en el mismo mes calendario sobre el mismo préstamo, sin error.
2. Registrar un **abono a capital** en cualquier fecha, exista o no un pago del mes previo.
3. Que el Dashboard **deje de reportar atrasos** por mes calendario, conservando el recordatorio de próximo pago.
4. **Subir o bajar el saldo pendiente** de un préstamo dejando `principal_amount` intacto, con historial de cuándo y cuánto, sin generar movimiento de dinero.
5. Que el selector de categorías se comporte **igual siempre**, sin sección de recientes.
6. Que no quede ninguna comparación de montos `int` contra una tolerancia decimal.

## Alcance

### Schema (v15)

Tabla nueva `loan_adjustments`:

| columna | tipo | notas |
|---|---|---|
| `id` | TEXT PK | UUID v7 |
| `loan_id` | TEXT NOT NULL | FK → `loans.id` |
| `amount` | INTEGER NOT NULL | centavos **con signo**: `+` sube deuda, `−` la baja. Nunca `0` |
| `reason` | TEXT NULL | texto libre, máx 200 |
| `occurred_at` | TEXT NOT NULL | fecha del ajuste (`store_date_time_values_as_text`) |
| `created_at` / `updated_at` | TEXT NOT NULL | |
| `deleted_at` | TEXT NULL | soft delete, consistente con el resto del schema |

Índice `idx_loan_adjustments_loan` sobre `(loan_id, deleted_at)`.

Migración: rama `if (from == 14 && to == 15)` en `MigrationStrategy.onUpgrade` de `lib/data/database.dart`, con `m.createTable(loanAdjustments)` + `CREATE INDEX`, conservando el guardrail `UnimplementedError` al final (RN-H02). Aditiva pura: no toca datos existentes.

### Capa de datos

- `LoansDao.balanceOf` y `watchBalance`: nuevo término (ver RN-LF-05).
- `LoansDao`: métodos `registerAdjustment`, `updateAdjustment`, `deleteAdjustment`, `watchAdjustments(loanId)`, `watchAdjustmentsTotal(loanId)`. No se crea un DAO aparte: son 4 operaciones fuertemente acopladas al préstamo.
- `EntriesDao.registerLoanPayment` / `updateLoanPayment`: se elimina el query `monthlyCount` y sus dos `throw`.
- `EntriesDao.deleteLoanPayment`: se elimina el parámetro `cascadeCapitalInMonth` y su bloque `customStatement`.
- `EntriesDao.countCapitalPaymentsInSameMonth`: queda sin llamador → se elimina.
- `LoansDao.watchMonthsOverdue`, `expectedPaymentMonths`, `_expectedPaymentMonths`, `_maxOverdueMonthsWindow`: quedan sin llamador → se eliminan.
- `LoansDao.applyPaymentSideEffects`: se invoca también desde las tres mutaciones de ajuste.

### Backup (v4)

- Export emite `loan_adjustments` y `"version": 4`.
- Import acepta v1, v2, v3 y v4. En v1-v3 la lista se trata como vacía.
- Validación de `invalid_reference` extendida: todo `loan_id` de un ajuste debe existir en el payload.
- Los montos de ajuste siguen la regla v3 (RN-IC): `int` obligatorio, un `double` se rechaza con `invalid_amount_format`.

### UI

- `/loans/:id` (`lib/screens/loan_detail_screen.dart`): acción "Ajustar saldo", formulario de alta/edición de ajuste, ajustes intercalados en el historial con tratamiento visual propio, y desglose en el header cuando existan ajustes.
- `lib/screens/dashboard_screen.dart`: se elimina la rama `overdue >= 1` de `_LoanStatusChip._buildChip`; el chip naranja de próximo pago se conserva sin cambios.
- `lib/screens/loan_detail_screen.dart:69-120`: se elimina el `DestructiveDialog` de cascada.
- `lib/widgets/category_picker.dart`: se elimina la sección MRU completa.
- `lib/widgets/error_snackbar.dart`: fuera `duplicate_monthly_payment` y `capital_before_monthly`; entra `invalid_adjustment`.

### Higiene

Comparaciones de `int` contra tolerancia decimal, a igualdad/comparación exacta:

- `lib/data/daos/loans_dao.dart:299,300` (doc), `311`, `319`
- `lib/screens/loan_capital_payment_form.dart:171`
- `lib/screens/loan_monthly_payment_form.dart:286`, `326`
- `lib/screens/reports/balance_at_date_tab.dart:184`, `314`
- `lib/data/backup.dart:315`
- `lib/data/reports.dart:713`, `2282` (solo comentarios obsoletos; el código ya está migrado)

### Documentación

`CLAUDE.md`: tabla de errores tipados, sección de préstamos, política de migraciones (v15), sección de backup (v4).

## Fuera de alcance

- **Soporte nativo de periodicidad** (quincenal, semanal, bimestral). El préstamo sigue teniendo un único `payment_day` mensual como referencia informativa. Modelar frecuencias reales es un sprint aparte; este solo quita los bloqueos.
- **Recalcular `current_duration_months`** a partir de los ajustes o del ritmo real de pago.
- **Eliminar `is_monthly_payment`** del schema. La columna se conserva: deja de ser regla y pasa a ser etiqueta descriptiva ("Pago del mes" vs "Abono a capital") en el historial.
- **Intereses moratorios o cálculo de intereses automático.** El ajuste es manual y el usuario decide el monto.
- **Exponer ajustes en `/entries` o en reportes de flujo.** Un ajuste no es un movimiento de dinero (RN-LF-08).
- **Sugerencia de categorías por otro mecanismo.** Se elimina el MRU sin reemplazo (decisión de Diego).
- **Migrar el backup legacy del backend Laravel** a v4.

## Reglas de negocio

- **RN-LF-01**: un préstamo admite **N** `loan_payment` con `is_monthly_payment = 1` en el mismo mes calendario. No existe restricción de unicidad temporal.
- **RN-LF-02**: un abono a capital (`is_monthly_payment = 0`) se registra en **cualquier fecha**, con o sin pago del mes previo en ese mes calendario.
- **RN-LF-03**: `is_monthly_payment` conserva su significado descriptivo (el pago incluye intereses pactados vs es capital extraordinario) pero **no gobierna ninguna validación**.
- **RN-LF-04**: eliminar un `loan_payment` **nunca** arrastra otros pagos. Cada pago se borra de forma independiente.
- **RN-LF-05**: el saldo de un préstamo es

  ```
  saldo = principal_amount + Σ(ajustes.amount) − Σ(pagos.principal_amount)
  ```

  considerando solo filas con `deleted_at IS NULL`.
- **RN-LF-06**: `loans.principal_amount` es **inmutable como concepto histórico**: representa el monto originalmente prestado y ningún ajuste lo modifica.
- **RN-LF-07**: el monto de un ajuste es distinto de cero y puede ser positivo o negativo. Un ajuste **no puede dejar el saldo resultante por debajo de cero** → `invalid_adjustment`.
- **RN-LF-08**: un ajuste **no genera `journal_entry`**, no referencia cuentas y no altera BO/DE/CR ni ningún reporte de flujo. Es un evento del préstamo.
- **RN-LF-09**: crear, editar o eliminar un ajuste dispara la reevaluación de estado del préstamo (`applyPaymentSideEffects`), con las mismas reglas que un pago: saldo ≤ 0 cierra como `paid`; saldo > 0 reabre un préstamo cerrado como `paid`; un préstamo cerrado como `manual` nunca se reabre solo (RN-L13).
- **RN-LF-10**: los ajustes se pueden registrar sobre un préstamo **cerrado**. Es el caso de uso principal: el banco ajusta el saldo de un préstamo que la app dio por pagado, y el ajuste debe poder reabrirlo.
- **RN-LF-11**: el ajuste usa soft delete, terminal, como el resto del modelo.
- **RN-LF-12**: el Dashboard no calcula ni muestra atraso por mes calendario. El único indicador temporal del préstamo es el chip de próximo pago basado en `payment_day`.
- **RN-LF-13**: el selector de categorías presenta siempre la misma estructura, sin sección de recientes ni orden dependiente del historial de la sesión.
- **RN-LF-14** (hereda RN-IC-05): ninguna comparación de montos `int` usa tolerancia decimal.

## Requisitos funcionales

- **RF-001**: eliminar el error `duplicate_monthly_payment` de `registerLoanPayment` y `updateLoanPayment`, junto con el query `monthlyCount` que lo alimenta.
- **RF-002**: eliminar el error `capital_before_monthly` de `registerLoanPayment` y `updateLoanPayment`.
- **RF-003**: eliminar el parámetro `cascadeCapitalInMonth` de `deleteLoanPayment`, su bloque de borrado en cascada, el helper `countCapitalPaymentsInSameMonth` y el `DestructiveDialog` de cascada en `loan_detail_screen.dart`.
- **RF-004**: eliminar la rama de chip "atrasado" del Dashboard y todo el cálculo de meses vencidos que queda sin llamador en `LoansDao`.
- **RF-005**: crear la tabla `loan_adjustments` con su índice y la migración v14 → v15 conservando el guardrail.
- **RF-006**: extender `balanceOf` y `watchBalance` con el término de ajustes (RN-LF-05).
- **RF-007**: implementar `registerAdjustment`, `updateAdjustment`, `deleteAdjustment`, `watchAdjustments` y `watchAdjustmentsTotal` en `LoansDao`, con validación `invalid_adjustment` (RN-LF-07) y reevaluación de estado (RN-LF-09).
- **RF-008**: exponer en `/loans/:id` el alta, edición y eliminación de ajustes, con el historial mostrando ajustes y pagos en una sola línea de tiempo visualmente diferenciada.
- **RF-009**: mostrar en el header de `/loans/:id` el desglose del saldo cuando existan ajustes, dejando visible el monto original prestado.
- **RF-010**: subir el backup a v4 incluyendo `loan_adjustments` en export, aceptando v1-v4 en import y validando la referencia `loan_id`.
- **RF-011**: eliminar la sección de categorías recientes del `CategoryPicker`, incluyendo `_sessionMRU`, `_mruLimit` y `_touchMRU`.
- **RF-012**: sustituir las comparaciones de `int` contra `0.005` por comparaciones exactas y corregir los comentarios obsoletos con tolerancias.
- **RF-013**: actualizar `CLAUDE.md` (errores tipados, dominio de préstamos, schema v15, backup v4).
- **RF-014**: bump de versión a `0.34.0+122` en `pubspec.yaml` y `android/app/build.gradle.kts`.

## Casos principales

1. **Pago quincenal.** Diego registra un pago con intereses el 5 de agosto y otro el 20 de agosto sobre el mismo préstamo. Ambos se guardan; el saldo baja por la suma de los dos capitales.
2. **Abono a capital sin pago del mes.** Diego registra un abono a capital el 12 de septiembre sin haber capturado el pago del mes. Se guarda y el saldo baja.
3. **Ajuste al alza del banco.** El saldo es $34,900. Diego registra un ajuste de `+$100` con motivo "Ajuste del banco, sin explicación". El saldo pasa a $35,000; `principal_amount` sigue en su valor original y el header lo muestra.
4. **Ajuste al alza sobre préstamo cerrado.** Un préstamo cerrado como `paid` recibe un ajuste positivo. Se reabre automáticamente (`closed_at` y `close_reason` a `NULL`) y vuelve a aparecer como activo.
5. **Corrección de un ajuste.** Diego se equivocó de monto y edita el ajuste. El saldo se recalcula y, si corresponde, el préstamo cambia de estado.
6. **Eliminación de un pago.** Diego borra un pago del mes que tiene abonos a capital en el mismo mes. Solo se borra ese pago; los abonos permanecen.
7. **Round-trip de respaldo.** Export v4 con ajustes → wipe → import v4 reconstruye préstamo, pagos y ajustes; el saldo es idéntico.
8. **Selector de categorías.** Al abrir el picker en cualquier tipo de movimiento y tras cualquier cantidad de usos, la estructura de la lista es siempre la misma.

## Casos borde

1. **Ajuste que lleva el saldo exactamente a cero.** Se acepta; el préstamo se cierra como `paid` (RN-LF-09).
2. **Ajuste negativo mayor al saldo.** Se rechaza con `invalid_adjustment` (RN-LF-07).
3. **Ajuste de monto cero.** Se rechaza con `invalid_adjustment`.
4. **Editar un ajuste de forma que el saldo quede negativo.** Se rechaza; el ajuste conserva su valor anterior.
5. **Eliminar un ajuste positivo que mantenía el préstamo abierto.** El saldo cae a ≤ 0 y el préstamo se cierra como `paid`.
6. **Eliminar un ajuste sobre un préstamo cerrado manualmente.** El saldo se recalcula pero el préstamo **no** se reabre (RN-L13).
7. **`overpay_loan` con ajuste vigente.** El guard usa `balanceOf`, así que un ajuste positivo amplía el capital máximo que admite un pago. No requiere cambio de código; requiere test.
8. **Import de backup v3.** El préstamo carga sin ajustes y el saldo coincide con la fórmula de dos términos.
9. **Import de backup v4 con un ajuste que apunta a un `loan_id` inexistente.** Se rechaza con `invalid_reference`.
10. **Import de backup v4 con `amount` de ajuste como `double`.** Se rechaza con `invalid_amount_format`.
11. **Ajuste con `occurred_at` anterior a `contract_date`.** Se permite: a diferencia de los pagos (`payment_before_contract`), un ajuste puede corregir un error de captura del monto original.
12. **Préstamo con muchos ajustes.** El header muestra el neto agregado, no una lista; el detalle vive en el historial.
13. **Migración v14 → v15 corrida dos veces.** Idempotente: la creación de tabla e índice usa la variante condicional.
14. **Backup exportado antes de este sprint (v3) restaurado en 0.34.0.** Funciona; la app queda sin ajustes.
15. **Backup exportado en 0.34.0 (v4) abierto en 0.33.0.** Falla con `unsupported_version`. Esperado y documentado (ver Riesgos).

## Criterios de aceptación

- **CA-01**: registrar dos `loan_payment` con `is_monthly_payment = 1` en el mismo mes calendario sobre el mismo préstamo no lanza error y ambos quedan activos.
- **CA-02**: registrar un `loan_payment` con `is_monthly_payment = 0` en un mes sin pago del mes no lanza error.
- **CA-03**: los identificadores `duplicate_monthly_payment` y `capital_before_monthly` no aparecen en `lib/` (verificable con grep).
- **CA-04**: borrar un pago del mes con abonos a capital del mismo mes deja los abonos con `deleted_at IS NULL`.
- **CA-05**: el Dashboard no muestra chip rojo de atraso en ningún estado del préstamo; el chip naranja de próximo pago sigue apareciendo cuando faltan ≤ 5 días.
- **CA-06**: `watchMonthsOverdue` y `expectedPaymentMonths` no existen en `lib/`.
- **CA-07**: tras un ajuste de `+X` centavos, `balanceOf` devuelve el saldo previo `+ X` y `loans.principal_amount` conserva su valor.
- **CA-08**: un ajuste positivo sobre un préstamo con `close_reason = 'paid'` deja `closed_at IS NULL` y `close_reason IS NULL`.
- **CA-09**: un ajuste positivo sobre un préstamo con `close_reason = 'manual'` no cambia `closed_at`.
- **CA-10**: un ajuste que dejaría el saldo negativo lanza `invalid_adjustment` y no inserta fila.
- **CA-11**: export → wipe → import de un préstamo con pagos y ajustes reproduce el mismo saldo y el mismo número de ajustes.
- **CA-12**: importar un backup v3 en la app v4 no lanza error y el préstamo queda con cero ajustes.
- **CA-13**: `_sessionMRU` no existe en `lib/` y el picker no renderiza sección de recientes.
- **CA-14**: `grep -rn "0\.005" lib --include="*.dart"` solo devuelve coincidencias en `fincore_colors.dart` (valores oklch) y en la documentación de `money.dart`.
- **CA-15**: la migración v14 → v15 sobre la BD real de Diego conserva préstamo, pagos y saldo sin cambio.
- **CA-16**: `flutter analyze` sin errores nuevos y suite completa en verde.

## Criterios medibles de éxito

- **CM-01**: la suite pasa de 896 tests a ≥ 910, con al menos 12 tests nuevos cubriendo ajustes (alta, edición, borrado, signo, cierre/reapertura, `invalid_adjustment`) y ≥ 3 cubriendo la ausencia de candados.
- **CM-02**: los 20 puntos de test que hoy afirman `duplicate_monthly_payment` / `capital_before_monthly` / `watchMonthsOverdue` en `test/data/loans_dao_test.dart` (13) y `test/data/loan_payments_test.dart` (7) quedan invertidos o eliminados; ninguno se deja en `skip`.
- **CM-03**: `flutter analyze` reporta como máximo los 3 hints preexistentes de `entry_form_screen.dart:510-513`.
- **CM-04**: `scripts/verify-apk.sh` confirma `versionCode 2122 / versionName 0.34.0`.
- **CM-05**: Diego reproduce en el teléfono su caso real: registra dos pagos con intereses en el mismo mes y un ajuste positivo, y el saldo de la app coincide con el de la app del banco.
- **CM-06**: el conteo de líneas de `lib/` baja (el sprint elimina más código del que agrega en la capa de datos, aun sumando la tabla nueva).

## Riesgos

- **R-01 — Backup v4 no es legible por 0.33.0.** Un export hecho con la versión nueva no se puede importar en la versión que Diego tiene instalada hoy. Mitigación: dejar en `~/fincore-respaldos/` el APK 0.33.0+121 y el respaldo v3 vigente **antes** de instalar la 0.34.0, replicando el procedimiento del 2026-08-05. Documentar que el respaldo v3 es el único punto de retorno.
- **R-02 — Pérdida de una red de seguridad real.** `capital_before_monthly` evitaba historiales incoherentes (abonos sueltos sin pago base). Al quitarlo, un error de captura ya no se detecta. Aceptado: es single-user, la app es una libreta y el propio `CLAUDE.md` establece que no se bloquea al usuario salvo imposibilidad contable.
- **R-03 — Cambio de comportamiento silencioso en borrado.** Quien conociera la cascada podría esperar que borrar el pago del mes limpie los abonos. Mitigación: el diálogo destructivo desaparece, así que no queda promesa de cascada en la UI.
- **R-04 — El ajuste puede usarse para maquillar el préstamo.** Nada impide ajustar el saldo hasta cuadrarlo arbitrariamente. Aceptado y mitigado parcialmente con el campo `reason` y el historial visible.
- **R-05 — Reapertura automática inesperada.** Un ajuste positivo sobre un préstamo cerrado lo revive y lo devuelve al Dashboard. Es el comportamiento buscado (RN-LF-10), pero debe comunicarse en la UI al confirmar el ajuste.
- **R-06 — Superficie de migración.** Es la segunda migración de schema en dos sprints consecutivos sobre datos reales en producción. Mitigación: la v15 es puramente aditiva (`createTable`), sin transformación de datos existentes, a diferencia de la v14.
- **R-07 — Deuda conceptual pendiente.** El préstamo sigue modelado como mensual (`payment_day` único, `initial_duration_months`) aunque el préstamo real sea quincenal. Este sprint quita los bloqueos pero no corrige el modelo; el chip de próximo pago seguirá mostrando una fecha mensual. Queda registrado para un sprint futuro de periodicidad.

## Supuestos

- **S-01**: Diego es el único usuario y acepta perder las validaciones de orden a cambio de flexibilidad (consistente con la filosofía "libreta libre" de `CLAUDE.md`).
- **S-02**: un solo `payment_day` mensual sigue siendo suficiente como recordatorio, aun con préstamo quincenal. Diego lo confirmó al pedir explícitamente conservar "la fecha mensual".
- **S-03**: el ajuste manual con motivo libre es suficiente; no se requiere categorizar tipos de ajuste (comisión, seguro, interés moratorio) en este sprint.
- **S-04**: los ajustes son de baja frecuencia (unidades por año), así que el header puede resolverse con un neto agregado sin paginar.
- **S-05**: eliminar el MRU no degrada la captura porque el picker ya tiene búsqueda por texto y agrupación por `applies_to`.
- **S-06**: ningún otro consumidor depende de `watchMonthsOverdue` fuera del Dashboard (verificado por grep sobre `lib/`).

## Impacto esperado

**Para Diego**: puede registrar su préstamo quincenal como realmente lo paga, abonar a capital cuando quiera, y mantener el saldo cuadrado con la app del banco aunque el banco haga movimientos que no explica. Desaparece una alerta roja permanente que no significaba nada. El selector de categorías deja de comportarse de forma distinta según cuánto haya usado la app esa sesión.

**Para el código**: el módulo de préstamos pierde tres reglas de calendario, una cascada de borrado, un cálculo de vencimientos con ventana de 60 meses y un caso de diálogo destructivo. Gana una tabla, cinco métodos de DAO y un término en la fórmula de saldo. El balance neto de complejidad es a la baja, y el modelo queda alineado con la filosofía declarada del proyecto.

**Riesgo asumido**: se cambia validación automática por confianza en el usuario, en un módulo con dinero de por medio. Es una decisión explícita, no un descuido.
