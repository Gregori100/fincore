# Plan técnico — flutter-reports-credit-cards-v1

## Enfoque tecnico

El sprint mezcla tres capas: **schema (data)**, **formulario (UI de edición)** y **reporte (UI de consulta)**. Se atacan en ese orden porque el reporte depende de datos válidos y el formulario depende del schema estrecho.

1. **Data layer primero**: bump de `schemaVersion` 4→5, `credit_limit` pasa a `NOT NULL DEFAULT 0`. Migración recrea la tabla `accounts` (SQLite no soporta `ALTER COLUMN`). Backfill de NULLs a 0 antes del recreate. Validación en `AccountsDao.create` y `updateAccount` para rechazar null explícito en `type=credit`. Relajar la validación de import de backup: `credit_limit >= 0` (antes era `> 0`; ahora 0 es válido). Se agrega compat forward: si el JSON legacy trae `credit_limit=null`, cargar como 0 con log en `ImportReport`.

2. **UI de edición**: conectar los dos `TextField` huérfanos (`_minPaymentPctCtrl`, `_interestRateCtrl`) al `AccountFormScreen`. Visibles solo cuando `_type == AccountType.credit`. Agrupar visualmente los 5 campos credit-only para no saturar el form.

3. **Reporte**: nuevo modelo inmutable `CreditCardStatus`, nuevo método `ReportsService.watchCreditCards()` con stream reactivo basado en `customSelect(sql, readsFrom: {accounts, journalEntries}).watch()`. Nuevo widget `CreditCardsTab` bajo `mobile/lib/screens/reports/credit_cards_tab.dart`. Integración al `TabBar` de `ReportsScreen` como sexto tab.

4. **Documentación en app**: actualizar slide 3 del `OnboardingScreen` (5 → 6 reportes) y el FAQ de `HelpScreen` para mencionar el nuevo tab.

5. **Versión + build**: `pubspec.yaml` + `build.gradle.kts` a `0.13.0+71`.

Fechas y cálculos de próxima corte/pago corren en Dart puro (helper `nextOccurrenceOfDay`) — no en SQL. El SQL solo devuelve deuda + snapshot de metadatos de la tarjeta; el service en Dart arma las fechas y ordena.

## Requisitos funcionales cubiertos

- **RF-001** (migración v4→v5): rama nueva `if (from == 4 && to == 5)` en `MigrationStrategy.onUpgrade`. Implementación:
  1. `UPDATE accounts SET credit_limit = 0 WHERE credit_limit IS NULL`.
  2. Recrear tabla con drift: usar `Migrator.alterTable` con `TableMigration` que redefine la columna. Alternativa segura: `CREATE TABLE accounts_new`, `INSERT INTO accounts_new SELECT ...`, `DROP TABLE accounts`, `ALTER TABLE accounts_new RENAME TO accounts`, más recrear los índices de la tabla. Se elige la vía que drift 2.31 soporta nativamente sin `customStatement` crudo si es viable; si no, `customStatement` explícito dentro de la transacción.
- **RF-002** (ramas defensivas): agregar `if (from == 3 && to == 5)`, `if (from == 2 && to == 5)`, `if (from == 1 && to == 5)` que combinan todas las migraciones intermedias. Guardrail `UnimplementedError` al final permanece intacto.
- **RF-003** (validación DAO): `AccountsDao.create` y `AccountsDao.updateAccount` — si `type=='credit'` y `creditLimit==null`, lanzar `AccountsDaoError('invalid_credit_limit', 'El límite de crédito es obligatorio.')`. Reutilizar el código existente `invalid_credit_limit`.
- **RF-004** (input pago mínimo): `TextField` en `AccountFormScreen` con `controller: _minPaymentPctCtrl`, label "Pago mínimo (% del saldo)", `suffixText: '%'`, `keyboardType: TextInputType.numberWithOptions(decimal: true)`. Visible en el `if (_type == AccountType.credit)` que ya envuelve `_creditLimitCtrl`, `_closingDayCtrl`, `_paymentDayCtrl`. Validación `validator`: si no vacío, debe parsear y estar en 0-100.
- **RF-005** (input tasa de interés): idéntico patrón, controller `_interestRateCtrl`, label "Tasa de interés anual", `suffixText: '% anual'`, rango 0-200.
- **RF-006** (tab en ReportsScreen): agregar `Tab(text: 'Tarjetas')` al `TabBar` de `mobile/lib/screens/reports_screen.dart` y `CreditCardsTab()` al `TabBarView`.
- **RF-007** (servicio + modelo): agregar `class CreditCardStatus` inmutable en `mobile/lib/data/reports.dart` (o archivo separado si crece — decisión: mismo archivo, consistencia con `BalanceAtDateReport`). Método `Stream<List<CreditCardStatus>> watchCreditCards()` en `ReportsService`. La query SQL agrega deuda por cuenta credit activa; el ordenamiento y las fechas próximas se computan en Dart post-fetch.
- **RF-008** (widget CreditCardsTab): `StreamBuilder<List<CreditCardStatus>>`. Loading = 2 `SkeletonCard`. Empty = ícono + texto + `FilledButton` con `context.push('/accounts/new')`. Data = `ListView.builder` de `_CreditCardTile`.
- **RF-009** (onboarding slide 3): editar `mobile/lib/screens/onboarding_screen.dart` — agregar `_KindRow` para "Estado de tarjetas" con `Icons.credit_card_outlined` color `warning`. Actualizar párrafo "6 reportes".
- **RF-010** (FAQ ayuda): actualizar el bloque del `HelpScreen` "¿Cómo se calculan los reportes?" para listar los 6 tabs.
- **RF-011** (backup compat): en `BackupService.importFromJson`, relajar validación de `credit_limit`:
  - Si `credit_limit == null` y `type == 'credit'`, cargar como 0 e incrementar contador `adjustedAccountsCount` en `ImportReport`.
  - Si `credit_limit < 0`, seguir rechazando con `invalid_credit_limit`.
  - Si `credit_limit >= 0` (incluye 0), aceptar.
  - Actualizar `ImportReport` para exponer `adjustedAccountsCount` y renderizar en el snackbar de éxito de `SettingsScreen._import`.
- **RF-012** (versión): `pubspec.yaml` y `android/app/build.gradle.kts`. Bump minor por schema + feature visible.

## Archivos o modulos probablemente afectados

- `mobile/lib/data/database.dart` — subir `schemaVersion`, agregar ramas de migración, cambiar declaración de `creditLimit` de `real().nullable()()` a `real().withDefault(const Constant(0))()`.
- `mobile/lib/data/database.g.dart` — regenerar con `dart run build_runner build --delete-conflicting-outputs`.
- `mobile/lib/data/daos/accounts_dao.dart` — reforzar validación `invalid_credit_limit` para rechazar null explícito en `type=credit`.
- `mobile/lib/data/reports.dart` — nuevo `CreditCardStatus` + `watchCreditCards()` en `ReportsService`.
- `mobile/lib/data/backup.dart` — relajar validación de `credit_limit`, agregar contador de ajustes al `ImportReport`.
- `mobile/lib/models/account.dart` — verificar si `creditLimit` sigue siendo `num?` en el modelo público o pasa a `num` no nullable. Decisión: mantener `num?` en el modelo público para no romper el JSON serializado que usa el legacy; documentar como "en runtime la BD garantiza no-null pero el modelo público acepta null para compat".
- `mobile/lib/screens/account_form_screen.dart` — conectar `_minPaymentPctCtrl` e `_interestRateCtrl` a `TextField`s. Agregar validadores.
- `mobile/lib/screens/reports_screen.dart` — sexto tab.
- `mobile/lib/screens/reports/credit_cards_tab.dart` — archivo nuevo.
- `mobile/lib/screens/onboarding_screen.dart` — slide 3 con 6 filas.
- `mobile/lib/screens/help_screen.dart` — FAQ actualizado.
- `mobile/lib/screens/settings_screen.dart` — snackbar de import muestra `adjustedAccountsCount` si > 0.
- `mobile/pubspec.yaml` — version bump + comentario del sprint.
- `mobile/android/app/build.gradle.kts` — versionCode/versionName.
- Tests nuevos en `mobile/test/data/database_test.dart`, `mobile/test/data/reports_test.dart`, `mobile/test/data/backup_test.dart`, `mobile/test/screens/reports/credit_cards_tab_test.dart` (nuevo).

## Entidades y estados afectados

- **Entidad `Account`** — específicamente registros con `type='credit'`.
  - Invariante nueva: `credit_limit` es no-null en runtime post-migración.
  - Estados válidos: activo (con `deletedAt IS NULL`) o archivado. Solo activos entran al reporte.
  - Metadata opcional: `closingDay`, `paymentDay`, `minimumPaymentPct`, `interestRate`. Cada campo optionalmente presente ajusta qué se muestra en la card.
- **Entidad `JournalEntry`** — no cambia. La deuda de una tarjeta sigue derivándose como `Σ origin.amount − Σ destination.amount` para `account_id = tarjeta`.
- **Modelo nuevo `CreditCardStatus`** — no persistido. Es DTO derivado en Dart, computado en cada evento del stream.

Transiciones:
- Crear/editar tarjeta → dispara re-cálculo del reporte reactivamente.
- Registrar `credit_expense` / `debt_payment` → dispara re-cálculo (deuda + pago mínimo + % usado cambian).
- Archivar tarjeta → desaparece de la lista.

## Compatibilidad con datos y procesos existentes

- **Datos existentes**: Diego y testers ya pueden tener tarjetas con `credit_limit=null`. La migración los rellena a 0 con el `UPDATE` previo al recreate.
- **Cuentas `cash`/`debit` con `credit_limit=null`**: la columna post-migración pasa a `NOT NULL DEFAULT 0`. Estas cuentas quedan con `credit_limit=0` sin efecto funcional (no se lee para non-credit).
- **Backup JSON v1 legacy**: la validación actual (`credit_limit == null || credit_limit <= 0`) es más estricta de lo que necesitamos post-sprint. Se relaja a `credit_limit == null` (auto-ajuste a 0) y `credit_limit < 0` (rechazo). El JSON exportado post-sprint siempre trae `credit_limit` presente y ≥ 0.
- **Sync/multi-dispositivo**: fuera de alcance de la app (single-user local), no aplica.
- **Otros reportes**: no se tocan. Los 5 tabs existentes siguen funcionando idénticos.
- **Formulario existente**: al agregar los 2 inputs, el orden visual del `AccountFormScreen` cambia. Los usuarios existentes verán 2 campos más al editar una tarjeta creada antes del sprint. Ambos campos son opcionales y no tienen default requerido.

## Cambios de datos si aplica

- `accounts.credit_limit` — de `REAL NULL` a `REAL NOT NULL DEFAULT 0`.
- Backfill: `UPDATE accounts SET credit_limit = 0 WHERE credit_limit IS NULL` corre antes de la recreación de tabla.
- Recreación de tabla: patrón estándar SQLite para cambiar constraints de una columna. Se preservan todas las demás columnas + índices + FKs.
- `ImportReport` — agregar campo `adjustedAccountsCount` (`int`, default 0).

## Cambios de API si aplica

No aplica. La app es local single-user, no expone API HTTP.

## Cambios de integraciones si aplica

No aplica.

## Cambios de UI si aplica

- **AccountFormScreen**: 2 `TextField`s nuevos, visibles solo cuando `_type == AccountType.credit`. Se integran al bloque condicional que ya muestra `_creditLimitCtrl`, `_closingDayCtrl`, `_paymentDayCtrl`. Considerar `SectionTitle` interno "Detalles de tarjeta" para agrupar los 5 campos y no saturar el form.
- **ReportsScreen**: sexto tab. El `TabBar` ya usa `isScrollable: true` — no cambia.
- **CreditCardsTab (nuevo)**: card por tarjeta con:
  - Header: nombre + descripción (si hay) + badge de estado si aplica ("Sin deuda", "Excedido").
  - Progress ring circular del % usado (custom paint o `CircularProgressIndicator` con valor). Ring en color `accent` si <80%, `warning` si 80-100%, `negative` si excedido.
  - Fila deuda: `Deuda actual: $X` con `AmountFormatter`.
  - Fila límite: `Límite: $Y` con `AmountFormatter`.
  - Fila disponible: `Disponible: $Z`.
  - Fila próximo corte: fecha + badge "en X días" / "hoy" / "mañana".
  - Fila próximo pago: idem.
  - Fila pago mínimo estimado: solo si `minimumPaymentPct != null` y `debt > 0`.
- **OnboardingScreen slide 3**: 6 filas en lugar de 5. Icono `credit_card_outlined`.
- **HelpScreen FAQ**: bloque actualizado.
- **SettingsScreen**: snackbar de import muestra "N cuentas ajustadas a límite 0" si `adjustedAccountsCount > 0`.

## Cambios de permisos si aplica

No aplica. Single-user local sin sistema de permisos.

## Riesgos tecnicos

- **R1** — Migración destructiva de tabla `accounts`: SQLite requiere recrear la tabla para cambiar `NULL → NOT NULL`. Cualquier fallo a mitad deja BD inconsistente. Mitigación: correr todo dentro de la transacción implícita de `onUpgrade` (drift la crea automáticamente), y tests de migración con datos reales.
- **R2** — Regeneración de `database.g.dart`: al bajar el nullable, el tipo generado de `creditLimit` en la row/companion cambia de `double?` a `double`. Podría romper llamadas existentes que hacen `.creditLimit ?? 0`. Mitigación: buscar todos los usos con `grep` post-cambio y ajustar. Especialmente en `AccountsDao`, `BackupService.exportToJson`, `AccountFormScreen`.
- **R3** — Modelo público `Account.creditLimit`: si el modelo se mantiene `num?` (por compat con JSON legacy), hay que documentar la asimetría "BD no-null pero modelo público nullable". Alternativa: subir el modelo también a `num` no-null y ajustar el legado. Recomiendo mantener el modelo `num?` y documentar; menos superficie de cambio.
- **R4** — Cálculo de fechas próximas con edge cases de calendario: `closingDay=31` en febrero, año bisiesto, cambio de mes. Riesgo de off-by-one en 29 de febrero de 2024/2028. Mitigación: tests unitarios exhaustivos del helper `nextOccurrenceOfDay(today, targetDay)`.
- **R5** — Idempotencia de la migración: si la migración corre dos veces (por reset de BD, retest), la segunda vez ya no hay NULLs para backfill y la recreación de tabla debe ser no-op. Mitigación: verificar en el test que `onUpgrade(m, 4, 5)` seguido de otro `onUpgrade(m, 4, 5)` no rompa (aunque en la vida real esto no ocurre porque schemaVersion sube y no baja).
- **R6** — Snapshot de datos vs stream reactivo: el reporte usa `watch()` para actualizarse al cambiar deuda o metadata. Si el usuario edita 10 tarjetas seguidas, el stream emitirá 10 veces. Mitigación: performance suficiente porque el volumen de tarjetas por usuario es bajo (<10 típico) y drift ya trae debounce interno vía `distinct()`. No optimización prematura.
- **R7** — Naming del tab: "Tarjetas" es corto pero puede confundirse con debit cards. Mitigación: label es "Tarjetas" pero el subtítulo del empty state y el FAQ dicen "tarjetas de crédito". Iterar post-smoke si Diego prefiere "Crédito".
- **R8** — Rounding del pago mínimo: `deuda × pct/100` puede dar decimales de banco (ej: 12345.67 × 0.05 = 617.2835). Redondeo a 2 decimales con `.toStringAsFixed(2)` para display. El valor almacenado del pct sigue siendo el double original.

## Estrategia de pruebas

- Unitarias de la data layer: DAO valida null, servicio computa `CreditCardStatus` correcto, helper `nextOccurrenceOfDay` cubre edge cases de calendario.
- Tests de migración: correr `onUpgrade(m, 4, 5)` sobre BD con cuentas credit con y sin `credit_limit`; verificar backfill + no-pérdida de datos + índices preservados. Repetir para 3→5, 2→5, 1→5.
- Tests de backup: import de JSON legacy con `credit_limit=null` carga 0 e incrementa `adjustedAccountsCount`; import con `credit_limit<0` rechaza.
- Tests de widget del `CreditCardsTab`: empty state con CTA, con datos completos, con datos parciales (sin `minimumPaymentPct`, sin `closingDay`).
- Tests de widget del `AccountFormScreen`: form con `type=credit` muestra los 2 inputs nuevos; crear tarjeta sin `credit_limit` da error tipado.
- Reactividad: crear un test que registra un `credit_expense` mientras el `CreditCardsTab` está montado y verifica que el `StreamBuilder` re-buildea con nueva deuda.

## Estrategia de rollback

- **Nivel BD**: la migración es destructiva de tabla (recrea `accounts`). No hay downgrade automático. Si post-deploy Diego descubre un bug crítico:
  1. Restaurar backup JSON exportado antes de instalar la nueva APK.
  2. Instalar APK anterior (0.12.2+70).
  3. Import del backup, que carga con `credit_limit=null` donde correspondía.
  El sprint no bloquea este flujo porque el JSON exportado post-sprint mantiene el campo `credit_limit` y el importer de v0.12.2 acepta valores > 0. Si algún registro había quedado en 0 exacto, el import legacy lo rechazaría — riesgo aceptado (Diego decide qué campo cambiar antes de importar).
- **Nivel código**: revertir commits del sprint es limpio (aditivos casi todos, salvo la modificación de `database.dart` y `backup.dart`).
- **APK previo**: `0.12.2+70` sigue disponible en `build/app/outputs/flutter-apk/` si no se sobrescribió y en el commit `89c2bda` del branch main.
- **Pre-flight**: antes de instalar la APK del sprint sobre BD real, Diego exporta backup manual desde Settings.

## Orden sugerido de implementacion

1. **Data schema + migración** — subir schemaVersion, cambiar declaración de columna, agregar 4 ramas de migración (4→5, 3→5, 2→5, 1→5), regenerar `database.g.dart`. Actualizar tests de migración existentes si es necesario.
2. **DAO reforzado** — reforzar `AccountsDao.create/updateAccount` para rechazar `creditLimit=null` en `type=credit`.
3. **Backup relajado** — modificar `BackupService.importFromJson` para aceptar `credit_limit=null` (auto-ajuste a 0) y `credit_limit=0`. Agregar `adjustedAccountsCount` al `ImportReport`. Ajustar `SettingsScreen._import` para mostrar el conteo.
4. **Servicio de reporte** — modelo `CreditCardStatus` + `ReportsService.watchCreditCards()` + helper `nextOccurrenceOfDay` en `lib/data/date_helpers.dart` (o similar).
5. **UI del reporte** — `CreditCardsTab` con loading/empty/data. Card con progress ring + badges.
6. **Tab en ReportsScreen** — integrar el sexto tab.
7. **Form inputs** — conectar `_minPaymentPctCtrl` e `_interestRateCtrl` en `AccountFormScreen`. Considerar `SectionTitle` agrupador.
8. **Documentación en app** — slide 3 del onboarding + FAQ de Help.
9. **Tests unitarios y widget** — cubrir migración, DAO, servicio, helper de fechas, widget del tab, widget del form, backup compat.
10. **Version bump + build APK + verify-apk.sh** — 0.13.0+71.
11. **Smoke tests manuales SM-01..SM-06** en cel real de Diego.

## Casos borde que condicionan la solucion

- `credit_limit=0` para una tarjeta real (no bug): el `%` no se calcula (evitar división por cero) y se muestra "—". No es un caso de error.
- Deuda > límite: `%=100` + badge de warning. No se rechaza el registro del cargo (política "libreta libre").
- `closingDay=31` en febrero: clamp al 28/29. Mismo para meses de 30 días.
- Cargo registrado justo en el día del corte: la deuda registrada figura en el "corte de hoy". Se acepta y el badge muestra "Hoy".
- Migración sobre BD con `credit_limit` de cuentas `cash`/`debit` en null: la columna post-migración pasa a `NOT NULL DEFAULT 0` para todas. Estas cuentas quedan con `credit_limit=0` cosmético (nunca se lee).
- Tarjeta creada con `credit_limit=0` y `minimumPaymentPct=5%`: si deuda es 0, no se muestra pago mínimo. Si deuda es 100 (excedido), se muestra pago mínimo = 5 aunque el límite sea 0.
- Test que corre `onUpgrade(m, 4, 5)` sobre BD ya migrada (idempotencia): la recreación no debe romper. El backfill `WHERE credit_limit IS NULL` es no-op.
- Reactividad al archivar una tarjeta desde `/accounts`: la card debe desaparecer del reporte sin refresh manual (el `deletedAt` cambia y el `watch()` sobre `accounts` re-emite).

## Preguntas o supuestos que siguen afectando la implementacion

- **S1**: Se asume que `minimumPaymentPct` se guarda como número 0-100 representando el porcentaje directo. Si el legacy guardaba como decimal 0-1, el importer ajustaría. Confirmado con Diego: 0-100 (patrón consistente con la UI).
- **S2**: Se asume que la fecha del "próximo corte" cuando `hoy.day == closingDay` es **hoy** (badge "Hoy") y no el mes siguiente. Documentado en RN-CC04 / CB-04.
- **S3**: Se asume que el orden RN-CC09 (proximidad pago asc con deuda; alfabético al final sin deuda) es aceptable. Iterar post-smoke si Diego prefiere otro orden.
- **S4**: Se asume que `interestRate` se guarda pero no se usa aún en el reporte. Helper text del input dice "Se usará en futuros reportes".
- **S5**: Se asume que el modelo público `Account.creditLimit` sigue siendo `num?` (nullable en Dart) aunque la BD sea `NOT NULL`. Documentado en R3. Si prefiere alinear, se ajusta.
- **S6**: Se asume que la migración v4→v5 recrea la tabla `accounts` con el patrón estándar SQLite. Si drift 2.31 expone un helper específico para "cambiar constraint", se usa; si no, `customStatement` explícito.

No hay preguntas bloqueantes abiertas.
