# Plan técnico — flutter-loans-flexible-payments-v1

## Enfoque tecnico

El sprint tiene dos naturalezas opuestas que conviene no mezclar en el mismo commit:

1. **Sustracción** (RF-001 a RF-004, RF-011, RF-012): quitar candados, cascada, cálculo de vencimientos, MRU y tolerancias. Son borrados con inversión de tests. Bajo riesgo, alto volumen de diff.
2. **Adición** (RF-005 a RF-010): tabla `loan_adjustments`, migración v15, término nuevo en el saldo, DAO, UI y backup v4. Es donde vive el riesgo real.

La estrategia es **construir primero la fórmula del saldo y su tabla**, porque `overpay_loan` y `applyPaymentSideEffects` ya leen `balanceOf` y heredan el cambio sin tocarlos. Una vez que el saldo es correcto, quitar candados es mecánico. La UI va al final, sobre una capa de datos ya probada.

Principio de mínimo blast radius: la migración v15 es puramente aditiva (`createTable` + `CREATE INDEX IF NOT EXISTS`), sin `alterTable` ni transformación de datos. A diferencia de la v14 del sprint anterior, no puede corromper información existente — en el peor caso la tabla queda vacía.

`applyPaymentSideEffects` conserva su nombre aunque pase a invocarse también desde mutaciones de ajuste. Renombrarlo a `recalculateLoanState` sería más honesto, pero toca 6 llamadores y ensucia el diff funcional; se anota como deuda menor en vez de arrastrarlo aquí.

## Requisitos funcionales cubiertos

- **RF-001, RF-002** — se elimina el bloque `entries_dao.dart:432-454` completo (query `monthlyCount` + los dos `throw`) y su réplica en `updateLoanPayment` (~`594`, `600`). El `monthKey` local de `registerLoanPayment` queda sin uso y también sale.
- **RF-003** — se elimina el parámetro `cascadeCapitalInMonth` de `deleteLoanPayment`, su bloque `customStatement`, el helper `countCapitalPaymentsInSameMonth` y la rama `if (payment.isMonthlyPayment)` de `loan_detail_screen.dart:69-120`. `_confirmDeletePayment` queda con un único camino: `ConfirmDialog` simple.
- **RF-004** — se elimina la rama `overdue >= 1` de `_LoanStatusChip._buildChip` y con ella el `StreamBuilder<int>` de `watchMonthsOverdue` en `dashboard_screen.dart:486-492`. El chip pasa a construirse directo desde `_daysUntilPayment`. En `loans_dao.dart` salen `watchMonthsOverdue`, `expectedPaymentMonths`, `_expectedPaymentMonths` y `_maxOverdueMonthsWindow`.
- **RF-005** — tabla `LoanAdjustments` en `database.dart`, registrada en `@DriftDatabase(tables: [...])`, `schemaVersion => 15`, rama `from == 14 && to == 15` + ramas defensivas X→15 replicando el patrón existente de X→14, helper `_createLoanAdjustmentsSchema()` idempotente.
- **RF-006** — `balanceOf` y `watchBalance` en `loans_dao.dart:74-96` ganan el término `+ COALESCE((SELECT SUM(amount) FROM loan_adjustments WHERE loan_id = ?1 AND deleted_at IS NULL), 0)`. Ambas comparten la misma cadena SQL para no divergir.
- **RF-007** — cinco métodos nuevos en `LoansDao`, con `LoansDaoError('invalid_adjustment', ...)`.
- **RF-008, RF-009** — `loan_detail_screen.dart` + un formulario nuevo `loan_adjustment_form.dart` siguiendo el patrón de `loan_capital_payment_form.dart`.
- **RF-010** — `backup.dart`: `_supportedVersion = 4`, `_adjustmentToJson` / `_adjustmentFromJson`, validación de referencia y export/import de la lista.
- **RF-011** — `category_picker.dart:129-182`.
- **RF-012** — 8 sitios de comparación + 2 comentarios.
- **RF-013, RF-014** — `CLAUDE.md`, `pubspec.yaml`, `android/app/build.gradle.kts`.

## Archivos o modulos probablemente afectados

Capa de datos:

- `lib/data/database.dart` — tabla nueva, `schemaVersion`, ramas de migración, helper de creación.
- `lib/data/database.g.dart` — regenerado con `build_runner`, no se edita.
- `lib/data/daos/loans_dao.dart` — fórmula de saldo, 5 métodos nuevos, 4 borrados, higiene de tolerancias.
- `lib/data/daos/entries_dao.dart` — 2 candados fuera, cascada fuera, helper de conteo fuera.
- `lib/data/backup.dart` — v4.

UI:

- `lib/screens/dashboard_screen.dart` — chip de atraso fuera.
- `lib/screens/loan_detail_screen.dart` — diálogo de cascada fuera, acciones y sección de ajustes dentro.
- `lib/screens/loan_adjustment_form.dart` — **archivo nuevo**.
- `lib/screens/loan_capital_payment_form.dart`, `lib/screens/loan_monthly_payment_form.dart` — solo higiene de tolerancias.
- `lib/screens/reports/balance_at_date_tab.dart` — solo higiene.
- `lib/widgets/category_picker.dart` — MRU fuera.
- `lib/widgets/error_snackbar.dart` — 2 códigos fuera, 1 dentro.
- `lib/router/app_router.dart` — por confirmar si el formulario de ajuste se abre por ruta (`/loans/:id/adjustments/new`) o por sheet local. Ver decisión en "Cambios de UI".

Tests:

- `test/data/loans_dao_test.dart` (13 refs), `test/data/loan_payments_test.dart` (7 refs) — inversión.
- `test/data/database_migration_test.dart` — migración v15.
- `test/data/backup_test.dart` — v4.
- Archivos nuevos para ajustes.

Documentación: `CLAUDE.md`.

## Entidades y estados afectados

**`Loan`** — sin cambios estructurales. Su ciclo de vida gana un disparador:

- Activo (`closed_at IS NULL`) → `paid` cuando el saldo cae a ≤ 0, ahora también por un ajuste negativo o por el borrado de un ajuste positivo.
- `paid` → Activo cuando el saldo sube por encima de 0, ahora también por un ajuste positivo (RN-LF-10).
- `manual` → terminal frente a recálculos automáticos (RN-L13 preexistente). Un ajuste recalcula el saldo pero **no** reabre.

Invariante que se conserva: `close_reason = 'manual'` bloquea toda transición automática.
Invariante que se elimina: "todo abono a capital tiene un pago del mes previo en su mes calendario".

**`LoanAdjustment`** — entidad nueva. Estados: activo (`deleted_at IS NULL`) y archivado (terminal, sin reactivación, consistente con el resto del modelo).

**`JournalEntry` de kind `loan_payment`** — `is_monthly_payment` deja de ser un discriminante con poder de validación y pasa a ser metadato de presentación. La columna, sus índices y su serialización en backup no cambian.

Efecto secundario obligatorio: toda mutación de ajuste corre dentro de `db.transaction(...)` y termina llamando `applyPaymentSideEffects`, igual que las mutaciones de pago.

## Compatibilidad con datos y procesos existentes

- **Datos históricos**: los préstamos y pagos existentes no se tocan. Un préstamo sin ajustes evalúa `SUM(amount) → NULL → COALESCE → 0`, así que la fórmula nueva devuelve exactamente lo mismo que la vieja. Esto es lo que hace segura la migración.
- **Registros que hoy violarían las reglas eliminadas**: ninguno, porque las reglas se aplicaban en escritura. No hay datos a sanear.
- **Backup hacia atrás**: import de v1, v2 y v3 sigue funcionando; la lista de ajustes se trata como vacía.
- **Backup hacia adelante**: un export v4 **no** es legible por 0.33.0 ni anteriores (`unsupported_version`). Es la ruptura del sprint. Ver Estrategia de rollback.
- **Reportes**: `ReportsService` no consulta `loans` ni `loan_adjustments`; los ajustes no entran en ningún agregado de flujo (RN-LF-08). Sin impacto.
- **`FinancialStateService`**: lee solo `accounts` y `journal_entries`. Sin impacto — es justamente la garantía de que un ajuste no mueve BO/DE/CR.
- **Total de préstamos en Dashboard**: por confirmar si `financial_state.dart` expone un total de deuda de préstamos; si lo hace vía `balanceOf`, hereda los ajustes correctamente y debe cubrirse con test.

## Cambios de datos

Schema v14 → v15. Migración aditiva:

```sql
CREATE TABLE IF NOT EXISTS loan_adjustments (
  id TEXT NOT NULL PRIMARY KEY,
  loan_id TEXT NOT NULL REFERENCES loans (id),
  amount INTEGER NOT NULL,
  reason TEXT NULL,
  occurred_at TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  deleted_at TEXT NULL
);
CREATE INDEX IF NOT EXISTS idx_loan_adjustments_loan
  ON loan_adjustments(loan_id) WHERE deleted_at IS NULL;
```

La declaración real se escribe en Dart (`class LoanAdjustments extends Table`) y el helper de migración usa `m.createTable(loanAdjustments)`; el SQL de arriba documenta la forma resultante. El índice va por `customStatement` porque es parcial, igual que `idx_loans_dest_account`.

Ramas de migración a agregar en `onUpgrade`, antes del guardrail:

- `from == 14 && to == 15` → `_createLoanAdjustmentsSchema()`.
- Ramas defensivas `X → 15` para X ∈ {5..13}, encadenando los helpers existentes y cerrando con el nuevo. Replica el patrón de las ramas X→14 ya presentes.

Idempotencia: `_createLoanAdjustmentsSchema()` prueba existencia con `pragma_table_info('loan_adjustments')` antes de crear, siguiendo el patrón de `_maybeAddColumn` y `_convertMoneyColumnsToInteger`.

`PRAGMA foreign_keys=ON` está activo, así que la FK a `loans` se valida en runtime. Como los préstamos usan soft delete, no hay borrado físico que dispare violación.

## Cambios de API

No aplica — la app es local-first sin red en runtime. La única superficie con contrato externo es el archivo de backup, cubierto abajo.

## Cambios de integraciones

**Backup JSON v3 → v4.**

- `_supportedVersion` pasa de 3 a 4. `_minSupportedVersion` sigue en 1.
- Export agrega la clave `loan_adjustments` con los ajustes activos.
- Import: si la clave falta o el payload es < v4, lista vacía.
- Los montos siguen la regla v3 en adelante: `int` obligatorio; un `double` se rechaza con `invalid_amount_format` vía el `_moneyFromJson` existente pasando `version`.
- Validación de referencia: todo `loan_id` de un ajuste debe existir en la lista `loans` del propio payload, o `invalid_reference`. Reutiliza el patrón ya usado para `journal_entries.loan_id`.
- El orden de inserción en import debe respetar la FK: `loans` antes de `loan_adjustments`.

`weekly_budgets`, `saved_views` y `app_preferences` siguen fuera del backup por decisión de diseño; `loan_adjustments` **sí** entra porque es dato financiero irrecuperable.

## Cambios de UI

**Dashboard** — se elimina el chip rojo. El naranja conserva su lógica, incluido ocultarse cuando ya existe pago del mes (`watchHasMonthlyPaymentIn`). Nota: con préstamos quincenales ese ocultamiento pierde parte de su sentido, pero Diego pidió explícitamente conservar el comportamiento del chip naranja (P-002), así que no se toca.

**`/loans/:id`** — tres cambios:

1. Acción "Ajustar saldo" en el menú de acciones del préstamo, disponible también con el préstamo cerrado (RN-LF-10).
2. Historial unificado: pagos y ajustes en una sola lista ordenada por `occurred_at`, con tratamiento visual distinto para el ajuste (icono `tune_outlined`, y el monto con signo explícito — un ajuste positivo **sube** deuda, así que usar `negative` para `+` y `positive` para `−`, coherente con la semántica de color de `CLAUDE.md`: el color señala el efecto sobre el usuario, no el signo aritmético).
3. Header: cuando existan ajustes, desglosar `principal_amount` original y el neto de ajustes, para que quede visible que el monto prestado no cambió.

**Formulario de ajuste** — archivo nuevo `loan_adjustment_form.dart`. Campos: monto (con selector de signo o toggle "Aumenta / Disminuye el saldo" — más legible que pedir un número negativo), fecha, motivo opcional. Muestra el saldo resultante antes de confirmar.

Decisión pendiente de confirmar en implementación: si se registra como ruta (`/loans/:id/adjustments/new` + `/loans/:id/adjustments/:adjId/edit`) o como bottom sheet local. **Recomendación**: rutas, por consistencia con `loan_capital_payment_form.dart` y `loan_monthly_payment_form.dart`, que ya son pantallas con ruta propia. Confirmar leyendo `app_router.dart` antes de decidir.

**Confirmación de reapertura** — si el ajuste va a reabrir un préstamo cerrado como `paid`, advertirlo en el submit (R-05). Un `ConfirmDialog`, no `DestructiveDialog`: es reversible y no destruye datos ajenos.

**`CategoryPicker`** — desaparece la sección de recientes. La lista queda: buscador (con su umbral de autofocus intacto) + secciones por `applies_to`.

**Tokens de diseño** — `loan_adjustment_form.dart` es archivo nuevo, así que nace migrado a tokens. `loan_detail_screen.dart` y `dashboard_screen.dart` se tocan parcialmente: aplica la regla "boy scout" de `CLAUDE.md` sobre las zonas modificadas, sin migrar el archivo entero.

## Cambios de permisos

No aplica. La app es single-user sin autenticación ni roles. No hay `userId` en el modelo.

## Riesgos tecnicos

- **RT-01 — Explosión combinatoria de ramas de migración.** `onUpgrade` ya tiene ramas para X→13 y X→14; agregar X→15 para 9 valores de X multiplica el bloque. Mitigación: encadenar helpers idempotentes existentes en vez de duplicar SQL, y cubrir con el test parametrizado que ya existe (`MG-IC-03` cubre 4 rutas defensivas; extenderlo).
- **RT-02 — `watchBalance` y `balanceOf` divergiendo.** Son dos strings SQL casi idénticos que hoy ya se repiten. Al agregar un tercer término el riesgo de que uno se actualice y el otro no es real. Mitigación: extraer la expresión a una constante privada `_balanceSql` compartida por ambos.
- **RT-03 — Reapertura automática sorpresiva.** Un ajuste que reabre un préstamo cerrado cambia el Dashboard sin que el usuario lo pida explícitamente. Mitigación: confirmación previa en la UI (R-05) y test dedicado.
- **RT-04 — Borrar código que otro consumidor usa.** `watchMonthsOverdue` y `countCapitalPaymentsInSameMonth` se eliminan por grep. Mitigación: `flutter analyze` + suite completa detectan cualquier referencia perdida; verificar también `integration_test/`.
- **RT-05 — Tests que pasan por la razón equivocada.** Al invertir un test de "lanza `duplicate_monthly_payment`" a "no lanza", un test mal escrito pasa aunque el registro no se haya insertado. Mitigación: cada inversión debe afirmar el **estado resultante** (dos filas activas, saldo esperado), no solo la ausencia de excepción.
- **RT-06 — Signo del ajuste invertido en la UI.** El mayor riesgo de usabilidad: que Diego suba el saldo creyendo que lo baja. Mitigación: toggle con etiquetas explícitas en vez de número con signo, y preview del saldo resultante antes de confirmar.
- **RT-07 — Ruptura de backup sin red de rollback.** Ver Estrategia de rollback; es proceso, no código, y por eso es fácil de omitir.

## Estrategia de pruebas

Detalle completo en `test-plan.md`. Resumen del enfoque:

- La capa de datos se prueba con SQLite in-memory (`NativeDatabase.memory()`) siguiendo el patrón del repo, incluido `initSqliteOverride` en `setUpAll`.
- La migración se prueba abriendo una BD en v14 con datos y verificando que la tabla existe, que es idempotente y que los saldos previos no cambian.
- La inversión de tests existentes se hace en el mismo commit que elimina cada candado (CM-02), nunca al final.
- El formulario de ajuste se cubre con widget test sobre el harness `pumpFincoreApp` existente.
- Validación final contra el respaldo real de Diego, como en el sprint anterior: import v3 → verificar saldo → registrar ajuste → export v4 → round-trip. Ese test es temporal y **no se versiona** (decisión P-006 del sprint `flutter-integer-cents-v1`).

## Estrategia de rollback

Dos niveles, porque el backup rompe compatibilidad hacia atrás:

**Nivel 1 — antes de instalar.** Preparar el kit en `~/fincore-respaldos/` con: APK 0.33.0+121 (ya presente), un export v3 fresco tomado con la 0.33.0 antes de actualizar, y el APK 0.34.0+122 nuevo. Sin el export v3 fresco, volver a 0.33.0 significa perder todo lo capturado entre el último v3 y el rollback.

**Nivel 2 — durante la migración.** La v15 es aditiva: si algo falla, la tabla simplemente no existe y la app no abre, pero **los datos previos están intactos**. No hay transformación destructiva que revertir. Reinstalar 0.33.0 sobre la misma BD funciona porque drift ignora tablas que no conoce — con la salvedad de que `schemaVersion` en la BD queda en 15 y 0.33.0 esperaría 14, lo que dispara un downgrade no soportado. Por eso el camino real de rollback sigue siendo desinstalar e importar el v3.

**Nivel 3 — a nivel de repo.** Cada checkpoint se commitea por separado, así que revertir un bloque (por ejemplo, solo el backup v4) es un `git revert` acotado.

## Orden sugerido de implementacion

1. **Schema y migración** (T001-T004). Tabla, `schemaVersion`, ramas, `build_runner`, tests de migración. Nada más depende de esto y todo lo demás sí.
2. **Fórmula de saldo** (T005-T006). Extraer `_balanceSql`, agregar el término, test de que un préstamo sin ajustes no cambia.
3. **DAO de ajustes** (T007-T010). Los 5 métodos + validaciones + reevaluación de estado + tests.
4. **Quitar candados** (T011-T014). Cada eliminación con su inversión de tests en el mismo commit.
5. **Quitar cascada y chip** (T015-T018). Incluye la limpieza de código muerto en `LoansDao`.
6. **Backup v4** (T019-T021).
7. **UI de ajustes** (T022-T026).
8. **MRU e higiene** (T027-T029). Independientes, pueden ir en cualquier momento.
9. **Documentación, versión y validación** (T030-T034).

Los pasos 1-3 y 4-5 son independientes entre sí una vez que existe la tabla; podrían paralelizarse, pero en un repo single-dev el beneficio no compensa el riesgo de conflicto en `entries_dao.dart` y `loans_dao.dart`, que ambos bloques tocan.

## Casos borde que condicionan la solucion

Los que cambian el diseño, no solo la cobertura:

- **Ajuste sobre préstamo cerrado** (RN-LF-10): obliga a que `registerAdjustment` **no** replique el guard `loan_closed` que sí tiene `registerLoanPayment`. Es una asimetría deliberada entre pagos y ajustes.
- **Ajuste con fecha anterior al contrato** (caso borde 11 de la spec): obliga a **no** replicar `payment_before_contract`. Segunda asimetría deliberada.
- **Ajuste negativo que excede el saldo**: obliga a calcular el saldo **dentro de la transacción** antes de insertar, igual que hace `registerLoanPayment` con `overpay_loan`. Una foto stale permitiría saldo negativo con dos submits concurrentes.
- **Edición de ajuste**: la validación debe excluir el propio ajuste del cálculo del saldo, o un ajuste positivo grande se auto-bloquearía al editarlo. Mismo patrón que `updateLoanPayment` usa para excluirse del conteo mensual.
- **Borrado de ajuste positivo**: puede cerrar el préstamo como `paid`. Obliga a llamar `applyPaymentSideEffects` también en el borrado, no solo en alta y edición.
- **Idempotencia de la migración**: la BD de Diego se migra una vez, pero los tests de rutas defensivas corren la misma rama varias veces.

## Preguntas o supuestos que siguen afectando la implementacion

Ninguna pregunta bloqueante: P-001, P-002 y P-003 están `respondida` en `preguntas.md`.

Supuestos que la implementación debe validar contra el código, no asumir:

- **SI-01**: `financial_state.dart` expone o no un total de deuda de préstamos que dependa de `balanceOf`. Si lo hace, hereda los ajustes y necesita test; si no, no hay nada que cubrir. **Verificar antes de T006.**
- **SI-02**: los formularios de pago existentes son pantallas con ruta propia en `app_router.dart`. De ahí se decide si el formulario de ajuste es ruta o sheet. **Verificar antes de T022.**
- **SI-03**: `integration_test/` no referencia los candados eliminados. El grep inicial cubrió `test/`; falta confirmar `integration_test/`. **Verificar antes de T011.**
- **SI-04**: el `DestructiveDialog` de cascada es el único consumidor de `countCapitalPaymentsInSameMonth`. **Verificar antes de T015.**

Deuda menor aceptada conscientemente:

- `applyPaymentSideEffects` conserva un nombre que ya no describe todos sus disparadores.
- El préstamo sigue modelado como mensual (R-07 de la spec). Este plan no lo corrige.
