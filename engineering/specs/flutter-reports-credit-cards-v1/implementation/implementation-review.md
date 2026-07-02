# Implementation Review: flutter-reports-credit-cards-v1

## Resumen de lo implementado

Sexto tab "Tarjetas" en `/reports` con estado por tarjeta (deuda, % usado, disponible, próximo corte/pago, pago mínimo estimado). Schema bump v4→v5 endureciendo `accounts.credit_limit` a `NOT NULL DEFAULT 0`. Inputs UI conectados en `AccountFormScreen` para `minimumPaymentPct` e `interestRate` (huérfanos post-pivote). Import de backup v1 legacy con `credit_limit=null` ahora se auto-ajusta a 0 con contador en `ImportReport`. Documentación en app (onboarding slide 3 y FAQ) actualizada al nuevo total de 6 reportes.

## Archivos principales modificados

- `mobile/lib/data/database.dart` — schemaVersion 4→5, credit_limit NOT NULL DEFAULT 0, 4 ramas de migración (4→5, 3→5, 2→5, 1→5).
- `mobile/lib/data/database.g.dart` — regenerado por build_runner.
- `mobile/lib/data/daos/accounts_dao.dart` — rechaza null explícito para type=credit; acepta 0 como válido (era `<= 0`).
- `mobile/lib/data/reports.dart` — modelo `CreditCardStatus` + `ReportsService.watchCreditCards()`; ajuste en `balanceAtDate` para lectura no-nullable de `credit_limit`.
- `mobile/lib/data/date_helpers.dart` — nuevo, helper `nextOccurrenceOfDay` con clamp/skip.
- `mobile/lib/data/backup.dart` — `_accountFromJson` retorna record `(companion, adjusted)`; `ImportReport.adjustedAccountsCount` nuevo campo.
- `mobile/lib/screens/account_form_screen.dart` — 2 inputs TextFormField (pago mínimo + tasa interés) visibles cuando type=credit; conversión UI 0-100 ↔ BD 0-1; validador de creditLimit relajado a `< 0`.
- `mobile/lib/screens/accounts_list_screen.dart` — limpia `creditLimit != null` (dead code post-schema).
- `mobile/lib/widgets/account_balance_hint.dart` — limpia `creditLimit ?? 0` (dead code).
- `mobile/lib/screens/reports/credit_cards_tab.dart` — nuevo widget del tab.
- `mobile/lib/screens/reports_screen.dart` — sexto tab integrado.
- `mobile/lib/screens/onboarding_screen.dart` — slide 3 con 6 filas + párrafo "6 reportes".
- `mobile/lib/screens/help_screen.dart` — FAQ actualizado a 6 tabs.
- `mobile/lib/screens/settings_screen.dart` — snackbar de import muestra `adjustedAccountsCount` si > 0.
- `mobile/pubspec.yaml` + `mobile/android/app/build.gradle.kts` — 0.13.0+71.
- `CLAUDE.md` — nota sobre schema v5 y convención decimal 0-1 vs UI 0-100.

Tests nuevos:
- `mobile/test/data/date_helpers_test.dart` (nuevo, 15 sub-casos UT-13).
- `mobile/test/data/database_test.dart` — grupo nuevo "credit_limit (sprint credit-cards)" con UT-01..04, UT-19.
- `mobile/test/data/reports_test.dart` — grupo nuevo "watchCreditCards (sprint credit-cards)" con UT-05..12 + minimumPayment y CB-D18.
- `mobile/test/data/backup_test.dart` — grupo nuevo "Import — credit_limit (sprint credit-cards)" con DT-01, DT-03, DT-04, DT-05.
- `mobile/test/screens/reports/credit_cards_tab_test.dart` (nuevo, 5 widget tests WT-01..05).

## Tareas completadas

- T001..T005 (BD): schema + migración + DAO reforzado.
- T006..T010 (Backend): CreditCardStatus, `nextOccurrenceOfDay`, `watchCreditCards`, backup relajado, `ImportReport` extendido.
- T011..T019 (Frontend): inputs UI, CreditCardsTab, sexto tab en ReportsScreen, actualizaciones de onboarding/help/settings.
- T020..T028 (Pruebas): DAO, servicio, helper, backup, widget; suite completa 406/406 verdes.
- T029..T033 (Documentación / Validación): version bump, gradle, CLAUDE.md, analyze limpio, APK release + verify OK.

## Tareas pendientes

- **T034 (smokes con Diego SM-01..09)**: pendientes. Requieren el APK ya generado (`build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`) instalado en el cel real. Especialmente críticos SM-01 (migración sobre BD real) y SM-03 (deuda coincide con dashboard).
- **T035 (`branch-quality-review`)**: pendiente por invocar. Se recomienda antes del commit final.
- **T036 (commit)**: pendiente hasta smokes + quality review confirmados.

## Riesgos residuales

- **Migración destructiva de tabla `accounts`**: aunque testeada in-memory con idempotencia, la primera corrida real sobre la BD de Diego es la única prueba definitiva. Recomendado exportar backup manual desde Settings ANTES de instalar el nuevo APK (mitigación documentada en spec Estrategia de rollback).
- **Cambio en cálculo de CR** (`balanceAtDate`): tarjetas legacy con `credit_limit=null` (ahora 0) ANTES no contribuían a CR; ahora sí (con `0 - deuda = -deuda`). Diego verá su CR total bajar si tenía tarjetas sin límite configurado. Esperado y deseado por RN-CC.
- **`interestRate` guardado pero no usado**: el input existe y persiste, pero no se muestra en el reporte. Helper text lo aclara. Feature para sprints futuros (forecast).
- **Orden RN-CC09 (proximidad+alfabético mixto)**: puede sorprender con muchas tarjetas al día. Iterar post-smoke si Diego quiere solo alfabético.

## Pruebas realizadas

- `flutter analyze` → 4 hints info pre-existentes tolerados (0 errores/warnings nuevos).
- `flutter test` → 406/406 verdes.
- Build APK release `--split-per-abi` OK; `verify-apk.sh` confirma versionCode 2071 / versionName 0.13.0.
- Tests unitarios (data layer):
  - Migración v4→v5 idempotente (UT-19).
  - DAO rechaza null para type=credit, acepta 0, no aplica a cash/debit (UT-01..04).
  - `watchCreditCards` cubre empty, sin metadata, archivadas, orden, %, overdue, reactividad, isDebtFree, minimumPayment (UT-05..12 + CB-D18 + fórmula minPayment).
  - `nextOccurrenceOfDay` cubre 15 casos de calendario (bisiesto, cambio año, clamp/skip).
  - Backup import compat con `credit_limit=null`/0/no-credit; round-trip preserva (DT-01/03/04/05).
- Widget tests del CreditCardsTab: empty state, data completa, sin minPct, sin closingDay, badge "Sin deuda" (WT-01..05).

## Pruebas recomendadas

- **Smokes SM-01..09** en cel real (ver `plan/test-plan.md`). Prioritarios: SM-01 (migración), SM-03 (deuda coincide con dashboard), SM-08 (import backup legacy con null).
- **Test de reactividad extendida**: aunque UT-12 cubre reactividad al registrar cargo, un smoke manual navegando entre tabs mientras registra movimientos aseguraría UX suave.
- **Test de widget adicional** para WT-06 (badge "Excedido") y WT-15 (6 tabs renderean): no cubiertos en unit — dependen de smoke visual.

## Posibles regresiones

- **Callers de `Account.creditLimit`**: post-cambio `AccountData.creditLimit` es `double` no-nullable en drift. Se limpiaron los usos con `!= null` / `?? 0` en `accounts_list_screen.dart` y `account_balance_hint.dart`. El modelo público `mobile/lib/models/account.dart` sigue con `num?` para no romper JSON serialization; queda como asimetría documentada (R3 del plan).
- **Test UT-06 de `balanceAtDate`** (`test/data/reports_test.dart`) reescrito. Cambio de semántica: antes credit_limit=null era caso normal; ahora se rechaza. Contexto del test claramente marcado con "sprint credit-cards".
- **`balanceAtDate` cambia CR ligeramente**: tarjetas con `credit_limit=0` post-migración ahora contribuyen a CR con `0 - deuda`. En la BD real de Diego el efecto es mínimo si sus tarjetas ya tienen límite seteado.
- **AccountFormScreen orden visual**: los 5 campos credit-only ahora son 5 en lugar de 3. Sigue dentro del mismo bloque condicional bajo "Metadata de la tarjeta"; sin impacto en tests existentes.

## Recomendaciones para code review humano

1. **Verificar migración manualmente en un cel de prueba** (o via `SchemaVerifier` de drift si se prefiere): cargar una BD con `credit_limit=null` en al menos una cuenta credit, ejecutar la app v0.13.0+71, verificar que la migración corre sin error y el valor queda en 0.
2. **Revisar semántica de decimales 0-1 vs porcentaje 0-100** entre `AccountFormScreen` (UI) y `CreditCardStatus.compute` (data). Consistencia clave: la BD guarda decimal, la UI convierte × 100 / 100. Documentado en spec S1, S4 y CLAUDE.md.
3. **Revisar orden RN-CC09** con dataset mixto (algunas con paymentDay, otras no, algunas sin deuda). El comparador está en `CreditCardStatus.compareForReport`.
4. **Ejecutar `branch-quality-review` con slug `flutter-reports-credit-cards-v1`** antes del commit final. El reporte va a `engineering/quality-review/flutter-reports-credit-cards-v1/`.
