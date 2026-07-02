# Reporte de tarjetas + endurecimiento del modelo credit

## Resumen

Sexto tab en `/reports` que muestra el estado de cada tarjeta de crédito activa: deuda actual, % usado del límite, disponible, próximo corte, próximo pago y pago mínimo estimado. Aprovecha el sprint para (a) endurecer el schema haciendo `accounts.credit_limit` `NOT NULL DEFAULT 0` (hoy es nullable y no debería serlo) y (b) exponer en `AccountFormScreen` los inputs de `minimumPaymentPct` e `interestRate` que hoy están declarados como controllers pero nunca se conectaron a un `TextField` — quedaron huérfanos desde el pivote a Flutter local.

## Problema a resolver

Diego y los testers no tienen un solo vistazo del estado de sus tarjetas: cuánto deben, qué porcentaje del límite consumieron, cuándo es el próximo corte, cuánto es el pago mínimo. Para saberlo tienen que abrir cada cuenta en `/accounts/:id/edit` y hacer cálculos mentales. Además, los campos `minimumPaymentPct` e `interestRate` existen en la BD y en el modelo `Account`, pero como no hay UI para editarlos, están siempre null. El campo `credit_limit` es nullable en el schema pero conceptualmente nunca debería serlo — una tarjeta siempre tiene límite (aunque sea 0).

## Objetivo

1. Nuevo tab "Tarjetas" en `/reports` con estado reactivo por tarjeta.
2. Inputs UI para `minimumPaymentPct` e `interestRate` en `AccountFormScreen` (visibles solo cuando `type=credit`).
3. Schema bump v4→v5: `credit_limit` cambia a `NOT NULL DEFAULT 0`. Rellena existentes null a 0. DAO obligatorio para `type=credit`.

## Alcance

- Schema bump `schemaVersion` 4 → 5 con migración aditiva `credit_limit NOT NULL DEFAULT 0` + backfill de NULLs a 0.
- Ramas defensivas 3→5 y 2→5 en `MigrationStrategy.onUpgrade` con el guardrail `UnimplementedError` intacto.
- Validación en `AccountsDao.create` y `updateAccount`: rechazar `credit_limit == null` para `type=credit` con código `invalid_credit_limit`.
- `AccountFormScreen`: dos `TextField` nuevos visibles solo cuando `_type == AccountType.credit`:
  - "Pago mínimo (% del saldo)" con sufijo `%`, keyboard numeric.
  - "Tasa de interés anual" con sufijo `% anual`, keyboard numeric.
- Servicio nuevo: `ReportsService.watchCreditCards()` que devuelve `Stream<List<CreditCardStatus>>` reactivo.
- Widget nuevo: `CreditCardsTab` en `mobile/lib/screens/reports/credit_cards_tab.dart`.
- Integrar el tab al `TabBar` de `ReportsScreen` (pasa de 5 a 6 tabs).
- Actualizar `SM-*` / smokes en el test-plan del sprint.
- Actualizar `HelpScreen` FAQ para mencionar el sexto reporte.
- Actualizar slide 3 del `OnboardingScreen` para listar 6 reportes en lugar de 5.
- Actualizar `BackupService.importFromJson`: si un JSON v1 legacy trae `credit_limit=null`, lo carga como 0 (compat forward).
- Tests: DAO + servicio + widget + migración.

## Fuera de alcance

- Auto-cálculo de interés compuesto o proyección de saldo con capitalización.
- Notificaciones push de proximidad al corte/pago.
- Historial de pagos por tarjeta como sub-vista (ya está disponible filtrando `/entries` por cuenta).
- Presupuesto por tarjeta (`budgets` del backlog legacy — sprint aparte).
- Estimación del "próximo estado de cuenta" con cargos post-corte.
- Reportes `by-account`, `month-comparison`, `budgets` del backlog legacy — sprints aparte.
- Retroactividad: no se calcula el saldo de la tarjeta a la fecha de corte pasado. El % usado y pago mínimo se calculan sobre la **deuda actual**, no sobre el "saldo del último corte".

## Reglas de negocio

- **RN-CC01**: `credit_limit` es obligatorio para `type=credit`. El DAO rechaza `null` con código `invalid_credit_limit`. Default 0 es válido para tarjetas conceptuales (ej: tarjeta departamental sin límite formal declarado).
- **RN-CC02**: `minimumPaymentPct` e `interestRate` son opcionales. Si `minimumPaymentPct` es null, la línea "pago mínimo" no se muestra en la card del reporte. `interestRate` se guarda pero no se usa aún en el reporte (queda para features futuras — forecast, projections).
- **RN-CC03**: `closingDay` y `paymentDay` son opcionales. Si están null, se muestra "—" en lugar de la fecha próxima y no hay badge de "en X días".
- **RN-CC04**: cálculo del próximo corte — sea `hoy = fecha actual`, `Y = closingDay`. Si `hoy.day < Y`, próximo corte = `Y del mes actual`. Si `hoy.day >= Y`, próximo corte = `Y del mes siguiente`. Si `Y > días del mes destino`, clamp al último día del mes (mismo patrón que dogear y el legacy). Ej: `closingDay=31`, próximo corte en febrero → 28 o 29 según año bisiesto.
- **RN-CC05**: cálculo del próximo pago — mismo patrón que RN-CC04 pero con `paymentDay`.
- **RN-CC06**: `pago_mínimo_estimado = deuda_actual × (minimumPaymentPct / 100)`. Redondeado a 2 decimales. Si `deuda_actual <= 0`, `pago_mínimo = 0` y se muestra badge "sin deuda" en lugar de la línea de pago mínimo.
- **RN-CC07**: `% usado = min(deuda / credit_limit, 1.0) × 100`. Si `credit_limit == 0`, el porcentaje no se calcula (mostrar "—") y disponible se muestra como `0`. Si `deuda > credit_limit`, mostrar 100% + badge warning "Excedido por $X" con color negativo.
- **RN-CC08**: `disponible = max(credit_limit - deuda, 0)`. Nunca negativo en la UI.
- **RN-CC09**: orden de tarjetas en el reporte:
  1. Con deuda > 0, ordenadas por `nextPaymentDate` ascendente (más urgente primero); tarjetas sin `paymentDay` van después con orden por deuda desc.
  2. Con deuda = 0 al final, ordenadas alfabéticamente por nombre.
- **RN-CC10**: tarjetas archivadas (`deletedAt IS NOT NULL`) no aparecen en el reporte.
- **RN-CC11**: el reporte es reactivo. Usa `customSelect(sql, readsFrom: {accounts, journalEntries}).watch()` para que se actualice cuando se registra un cargo/pago o se edita una tarjeta.
- **RN-CC12**: badge de proximidad — si `daysTo <= 0` muestra "Hoy"; si `daysTo == 1` muestra "Mañana"; si `daysTo <= 7` muestra en warning color; si `daysTo > 7` muestra en subtle color.

## Requisitos funcionales

- **RF-001**: `schemaVersion` sube de 4 a 5. `MigrationStrategy.onUpgrade` agrega rama `if (from == 4 && to == 5)` que ejecuta:
  1. `UPDATE accounts SET credit_limit = 0 WHERE credit_limit IS NULL` (backfill).
  2. Recrear la tabla `accounts` con `credit_limit REAL NOT NULL DEFAULT 0` (SQLite no soporta `ALTER COLUMN`; patrón `CREATE TABLE new`, `INSERT SELECT`, `DROP old`, `RENAME` dentro de una transacción).
- **RF-002**: Ramas defensivas `from == 3 && to == 5` y `from == 2 && to == 5` en `onUpgrade` que ejecutan las migraciones intermedias en orden. Guardrail `UnimplementedError` conservado al final.
- **RF-003**: `AccountsDao.create` y `AccountsDao.updateAccount` para `type=credit` rechazan `creditLimit == null` con `AccountsDaoError('invalid_credit_limit', 'El límite de crédito es obligatorio.')`.
- **RF-004**: `AccountFormScreen` muestra `TextField` "Pago mínimo (% del saldo)" cuando `_type == AccountType.credit`. Sufijo `%`. `keyboardType: TextInputType.numberWithOptions(decimal: true)`. Validación: si `text.isNotEmpty`, debe parsear a double 0-100.
- **RF-005**: `AccountFormScreen` muestra `TextField` "Tasa de interés anual" cuando `_type == AccountType.credit`. Sufijo `% anual`. Keyboard numeric. Validación: si `text.isNotEmpty`, debe parsear a double 0-200 (para acomodar TDCs mexicanas con TAE altas).
- **RF-006**: `ReportsScreen` (`mobile/lib/screens/reports_screen.dart`) agrega un sexto `Tab(text: 'Tarjetas')` y un sexto slot en `TabBarView` con `CreditCardsTab()`. Mantener `isScrollable: true` en el `TabBar` para acomodar los 6 labels.
- **RF-007**: `ReportsService.watchCreditCards()` devuelve `Stream<List<CreditCardStatus>>`. `CreditCardStatus` es un modelo inmutable con: `accountId`, `name`, `description`, `creditLimit`, `debt`, `availableCredit`, `usedPct` (nullable), `closingDay`, `paymentDay`, `nextClosingDate` (nullable), `nextPaymentDate` (nullable), `daysToClosing` (nullable), `daysToPayment` (nullable), `minimumPayment` (nullable), `interestRate` (nullable), `isOverdue` (bool: debt > creditLimit), `isDebtFree` (bool: debt <= 0).
- **RF-008**: `CreditCardsTab` renderea:
  - Loading state: 2 `SkeletonCard` mientras el primer evento del stream no llega.
  - Empty state: si `snapshot.data.isEmpty`, texto "Aún no tenés tarjetas de crédito" + botón `FilledButton` "Agregar tarjeta" que hace `context.push('/accounts/new')`.
  - Con datos: `ListView` de `_CreditCardTile` por tarjeta. Cada tile es un `BaseCard` sin `onTap` (informativo, no navegable). Incluye nombre + descripción, ring circular del `% usado` (o barra si es más simple), fila de deuda vs límite, fila de disponible, filas de próximo corte y próximo pago con badges de proximidad, línea de pago mínimo si aplica.
- **RF-009**: Actualizar `OnboardingScreen` slide 3 para listar 6 reportes en lugar de 5. Agregar fila "Estado de tarjetas" con icono `Icons.credit_card_outlined` y color `warning`.
- **RF-010**: Actualizar `HelpScreen` — el FAQ "¿Cómo se calculan los reportes?" pasa a listar los 6 tabs con la explicación del nuevo tab.
- **RF-011**: `BackupService.importFromJson` — si un JSON v1 legacy trae `credit_limit == null` para una cuenta con `type == 'credit'`, lo carga como `0`. Log del incidente en el `ImportReport` como "N cuentas ajustadas a límite 0".
- **RF-012**: Bump versión `pubspec.yaml` + `android/app/build.gradle.kts` a `0.13.0+71`.

## Casos principales

1. Diego con 2 tarjetas activas, ambas con datos completos, entra a `/reports/Tarjetas` → ve 2 cards con toda la info (deuda, %, corte, pago, mínimo).
2. Diego edita el límite de una tarjeta en `/accounts/:id/edit` → al volver al reporte, la card refleja el nuevo % usado sin refrescar manualmente (RN-CC11).
3. Diego registra un `credit_expense` desde el FAB → la card correspondiente actualiza deuda + % usado en tiempo real.
4. Diego registra un `debt_payment` → la card actualiza deuda a la baja + pago mínimo estimado a la baja.
5. Tester nuevo abre `/reports/Tarjetas` sin haber creado tarjetas → empty state con CTA "Agregar tarjeta".
6. Diego crea una tarjeta nueva desde el form sin llenar `minimumPaymentPct` → la card la muestra sin la línea de pago mínimo (RN-CC02), el resto de la info sí.
7. Diego intenta crear una tarjeta sin `credit_limit` → error tipado `invalid_credit_limit` en el snackbar (RN-CC01).

## Casos borde

- **CB-01**: `credit_limit == 0` (tarjeta departamental o límite formal en cero) → `% usado` no calculable, se muestra "—" y disponible = 0. Deuda sí se muestra normal.
- **CB-02**: `debt > credit_limit` (excedido) → `% usado = 100%` + badge warning "Excedido por $X" en color negativo.
- **CB-03**: `closingDay = 31` en mes con 30 días → clamp al 30. En febrero → clamp al 28 o 29 según año bisiesto.
- **CB-04**: hoy es exactamente `closingDay` → próximo corte = **hoy** (badge "Hoy") no el mes siguiente. Mismo patrón para `paymentDay`.
- **CB-05**: `minimumPaymentPct == null` → línea de pago mínimo no se muestra. Sin CTA de "completá tus datos" (feature más chica, no impone acción).
- **CB-06**: `interestRate == null` → sin efecto en este sprint (no se muestra tasa por ahora).
- **CB-07**: `closingDay == null` pero `paymentDay` seteado → próximo corte muestra "—", próximo pago se muestra normal.
- **CB-08**: `paymentDay == null` pero `closingDay` seteado → simétrico a CB-07.
- **CB-09**: Migración v4→v5 sobre BD con múltiples cuentas credit con `credit_limit == null` → todas se rellenan a 0. Cuentas `cash`/`debit` con `credit_limit == null` también se rellenan a 0 (el NOT NULL se aplica a toda la columna), pero como el reporte y las validaciones solo miran `type=credit`, no afecta funcionalmente.
- **CB-10**: Import de backup v1 con múltiples cuentas credit con `credit_limit=null` → todas se cargan como 0, el `ImportReport` reporta "N cuentas ajustadas a límite 0".
- **CB-11**: Tarjeta con `debt == 0` y `minimumPaymentPct == 5` → no se muestra línea de pago mínimo (porque `pago_mínimo = 0`), se muestra badge "Sin deuda" en su lugar (RN-CC06).
- **CB-12**: Todas las tarjetas archivadas → empty state (mismo que tester nuevo, RN-CC10).
- **CB-13**: Tarjeta nueva creada mientras el usuario está en el tab → aparece en la lista sin refrescar (RN-CC11).
- **CB-14**: Migración v4→v5 corre dos veces (idempotencia) → segunda vez no falla; la primera ya dejó la columna NOT NULL, la segunda no encuentra NULLs para backfill y el CREATE TABLE new dentro de la transacción es el mismo estado final.

## Criterios de aceptacion

- Al abrir `/reports`, se ve el nuevo tab **Tarjetas** entre "Promedio mensual" y el final (o donde sea más natural — decidir en implementación).
- Con 0 tarjetas credit activas, el tab muestra empty state con CTA "Agregar tarjeta" que navega a `/accounts/new`.
- Con 1+ tarjetas, cada una se ve como card con: nombre, deuda actual, % usado (ring o barra), disponible, próximo corte con badge, próximo pago con badge, pago mínimo estimado (si `minimumPaymentPct != null` y `debt > 0`).
- Editar el límite, día de corte, día de pago, `minimumPaymentPct` o `interestRate` desde `/accounts/:id/edit` se refleja en el reporte reactivamente sin salir y volver.
- Registrar `credit_expense` o `debt_payment` actualiza la card correspondiente en tiempo real.
- Tarjetas archivadas no aparecen.
- Orden: con deuda por proximidad de pago; sin deuda alfabético al final (RN-CC09).
- `flutter test` pasa 100% con nuevos tests + los existentes (367 → objetivo ~385).
- `flutter analyze` en 0 errores.
- Migración v4→v5 idempotente y sin pérdida de datos.
- Import de backup JSON v1 legacy con `credit_limit=null` funciona (carga como 0) y reporta el ajuste.

## Criterios medibles de exito

- 6 tabs en `/reports` (pasa de 5 a 6).
- `AccountFormScreen` con 2 inputs nuevos visibles solo para `type=credit`.
- `schemaVersion == 5` en `database.dart`.
- Ramas nuevas: 4→5, 3→5, 2→5, 1→5 en `onUpgrade` (todas defensivas excepto 4→5 que es la real).
- ≥6 tests nuevos data-layer (migración v4→v5, DAO rechazo null, servicio watchCreditCards, cálculo fecha próxima, empty state, import compat).
- ≥3 widget tests (empty state, card con datos completos, edición de tarjeta refleja en reporte).
- Version `0.13.0+71` visible en Settings → Acerca de.
- `verify-apk.sh` OK.

## Riesgos

- **R1 — migración con BD activa**: la migración recrea la tabla `accounts` (por SQLite `ALTER COLUMN` no soportado). Si algo falla a media migración, la BD podría quedar en estado inconsistente. Mitigación: correr todo dentro de una `transaction` explícita (drift lo hace por default en `onUpgrade`), y probar la migración en tests con datos reales.
- **R2 — backup incompat forward-backward**: un JSON v1 exportado post-sprint tendrá `credit_limit` siempre presente. Si el usuario lo intenta importar en una versión legacy pre-sprint (poco probable, pero pasable si Diego tiene la vieja APK), va a funcionar porque el schema legacy es más permisivo. Sin riesgo real.
- **R3 — `interestRate` sin uso visible**: se pide input pero no se usa aún en el reporte. Riesgo cosmético: el usuario setea el valor y no lo ve reflejado. Mitigación: comentario en la spec (fuera de alcance) + posiblemente helperText en el input "Se usará en futuros reportes".
- **R4 — cambio en `AccountFormScreen`**: 2 inputs nuevos alargan el form. Riesgo UX menor. Mitigación: agrupar los 5 campos credit-only en una sub-sección visual clara.
- **R5 — orden de tarjetas confuso**: RN-CC09 mezcla dos criterios (proximidad pago + alfabético). Si el usuario tiene 5 tarjetas al día, verlas todas alfabéticas puede sorprender. Mitigación: aceptar como default; iterar post-smoke.
- **R6 — nombre del tab**: "Tarjetas" es corto; en el TabBar scrollable convive con "Gasto por categoría", "Cashflow mensual" (largos). Riesgo estético menor.

## Supuestos

- `minimumPaymentPct` se guarda como número 0-100 representando el porcentaje directo (ej: `5` = 5% del saldo). Fórmula: `min = deuda × (pct / 100)`.
- `interestRate` se guarda como número 0-200 representando la TAE (tasa anual efectiva) en porcentaje directo (ej: `45` = 45% anual). No se calcula composición aún.
- Diego valida el estado de sus tarjetas diariamente o casi. El badge "en X días" es prioritario sobre otras métricas.
- Los testers pueden o no tener tarjetas de crédito. El empty state debe ser claro y no bloqueante.
- La app Flutter local nunca va a persistir datos de "estados de cuenta" pasados. El reporte muestra "estado actual" siempre.
- El código del `SplashScreen` widget cambió recientemente a "símbolo centrado" (sprint splash) y no requiere ajuste para este sprint.
- Diego mantiene la política del CLAUDE.md sobre schema (RN-H02): la rama `if (from == 4 && to == 5)` es obligatoria y el guardrail `UnimplementedError` se mantiene.

## Impacto esperado

- Diego reduce el tiempo de ver estado de tarjetas de "abrir cuenta por cuenta y calcular a mano" a "un tap en el tab".
- Testers con tarjetas se sienten cubiertos por FinCore (feature que existía en el legacy y no estaba en el MVP).
- Datos de tarjetas más completos (`interest_rate`, `minimumPaymentPct`) quedan disponibles para sprints futuros de forecast, alertas de pago o proyecciones de saldo.
- Schema más consistente: `credit_limit` deja de ser nullable, se alinea con la intención del dominio.
- Cierra el hueco de los 2 controllers huérfanos post-pivote.
