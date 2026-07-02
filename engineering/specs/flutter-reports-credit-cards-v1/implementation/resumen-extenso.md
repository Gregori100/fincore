# Resumen extenso — flutter-reports-credit-cards-v1

## Contexto tomado de spec.md, preguntas.md y clarificaciones

`spec.md` definió tres capas de trabajo:
1. **Schema**: `credit_limit` de nullable a NOT NULL DEFAULT 0.
2. **Formulario**: exponer los 2 inputs UI huérfanos (`minimumPaymentPct`, `interestRate`).
3. **Reporte**: sexto tab "Tarjetas" en `/reports` con estado por tarjeta.

Sin `preguntas.md` ni `clarificaciones.md` — las 2 decisiones bloqueantes (schema NOT NULL vs mantener nullable; agregar los 2 inputs UI o solo uno) se resolvieron directamente con Diego en conversación:
- **P-A**: schema NOT NULL con default 0 + validación DAO explícita.
- **P-B**: agregar los 2 inputs (`interestRate` incluido).

Reglas RN-CC01..CC12 y RF-001..RF-012 tomadas 1:1 del `spec.md`.

## Relación con plan/plan.md y plan/tasks.md

Se siguió el orden de implementación del plan (sección "Orden sugerido"):

1. **Data schema + migración** (T001..T004): cambio de declaración drift, schemaVersion, ramas 4→5/3→5/2→5/1→5 con backfill + `Migrator.alterTable`. Guardrail `UnimplementedError` conservado al final.
2. **DAO reforzado** (T005): rechazo de null explícito en `create` para `type=credit`; validación de rango cambia a `< 0` (aceptando 0).
3. **Backup relajado** (T009, T010): `_accountFromJson` retorna record con flag `adjusted`; `ImportReport.adjustedAccountsCount` acumula.
4. **Servicio + modelo** (T006, T007, T008): `CreditCardStatus.compute` + `nextOccurrenceOfDay` + `ReportsService.watchCreditCards` con orden RN-CC09.
5. **UI del reporte** (T014, T015): `CreditCardsTab` con loading/empty/data; `_CreditCardTile` con progress ring, badges de proximidad, badge de sin deuda / excedido.
6. **Tab en ReportsScreen** (T016): 5 → 6 tabs.
7. **Form inputs** (T011..T013): `_minPaymentPctCtrl` e `_interestRateCtrl` conectados a `TextFormField`; conversión decimal ↔ porcentaje humano.
8. **Documentación en app** (T017, T018, T019): onboarding, FAQ, snackbar de import.
9. **Tests** (T020..T028): 5 archivos tocados / creados; 39 tests nuevos.
10. **Version bump + build + verify** (T029, T030, T032, T033): 0.13.0+71, `verify-apk.sh` OK.

Tareas pendientes: T034 (smokes con Diego), T035 (branch-quality-review), T036 (commit final).

## Cambios principales por módulo o capa

### Capa de datos

- `database.dart`: `credit_limit` de `real().nullable()()` a `real().withDefault(const Constant(0))()`. `schemaVersion` 4 → 5. Añadidas 4 ramas en `onUpgrade`:
  - `4→5`: `UPDATE accounts SET credit_limit = 0 WHERE IS NULL` + `alterTable(TableMigration(accounts))` + re-crear `idx_accounts_deleted` (drift lo pierde en alterTable).
  - `3→5`, `2→5`, `1→5`: combinan migraciones intermedias.
- `database.g.dart`: regenerado (contains generated types con `double creditLimit` no-nullable).
- `accounts_dao.dart`:
  - `create` con `type='credit'` y `creditLimit==null` → `invalid_credit_limit`.
  - `_validateCreditMetadata` cambia `<= 0` a `< 0` (0 es válido).
  - `Value(creditLimit!)` para type=credit (validado no-null); `Value.absent()` para cash/debit (default aplica).
- `reports.dart`:
  - Nuevo modelo `CreditCardStatus` (18 campos + `compute` factory + `compareForReport` static).
  - Nuevo `ReportsService.watchCreditCards({DateTime? now})`.
  - `balanceAtDate`: lectura no-nullable de `credit_limit` (era `double?`) y CR siempre suma (era condicional).
- `date_helpers.dart` (nuevo): `nextOccurrenceOfDay` con clamp/skip para calendario edge cases.
- `backup.dart`:
  - `_accountFromJson` cambia firma a `({AccountsCompanion companion, bool adjusted})`.
  - `credit_limit=null` en JSON legacy → `adjusted=true`, companion con `Value.absent()` (default 0).
  - `credit_limit<0` rechaza con `invalid_credit_limit`.
  - `ImportReport.adjustedAccountsCount` agregado (default 0).

### Capa UI

- `account_form_screen.dart`:
  - `_creditLimitCtrl.text = account.creditLimit.toStringAsFixed(2)` (era nullable con `?.toString()`).
  - `_interestRateCtrl.text` e `_minPaymentPctCtrl.text` inicializados con `× 100` (decimal → porcentaje humano).
  - `_parsePercentInput` helper: divide por 100 al persistir (porcentaje humano → decimal).
  - 2 `TextFormField` nuevos con label "Pago mínimo (% del saldo)" y "Tasa de interés anual", suffix "%", validators 0-100.
  - Validator de `_creditLimitCtrl` cambia a `< 0` con mensaje "No puede ser negativo".
- `reports/credit_cards_tab.dart` (nuevo, ~350 líneas):
  - `StreamBuilder` sobre `watchCreditCards`.
  - `_LoadingState` con 2 `SkeletonCard`.
  - `_EmptyState` con ícono + texto + `FilledButton.icon("Agregar tarjeta")`.
  - `_CreditCardTile` con `_Header` (nombre + badge SinDeuda), `_UsedRing` (progress ring circular), `_MoneyRow` (deuda/límite/disponible), `_DateRow` con `_ProximityBadge`, `_OverdueBadge` si excedido, línea pago mínimo condicional.
- `reports_screen.dart`: sexto `Tab(text: 'Tarjetas')` + `CreditCardsTab()`. `length: 6`.
- `onboarding_screen.dart`: slide 3 con 6 filas (`_KindRow`) + párrafo "6 reportes ... y el estado de tus tarjetas".
- `help_screen.dart`: FAQ "¿Cómo se calculan los reportes?" pasa a "6 tabs" con la línea del nuevo.
- `settings_screen.dart`: snackbar de import extiende con "(N cuenta(s) ajustada(s) a límite 0)" si `adjustedAccountsCount > 0`.
- `accounts_list_screen.dart` + `account_balance_hint.dart`: limpian `!= null` / `?? 0` dead-code post-schema.

### Tests

- `date_helpers_test.dart` (nuevo, 15 tests): calendario edge cases.
- `database_test.dart`: grupo nuevo `AccountsDao — credit_limit (sprint credit-cards)` con UT-01..04 y UT-19.
- `reports_test.dart`: grupo nuevo `watchCreditCards (sprint credit-cards)` con UT-05..12 + fórmula minimumPayment + CB-D18. Test UT-06 previo (`balanceAtDate — credit_limit null contribuye...`) reescrito para reflejar la nueva regla (rechazo de null + 0 como válido).
- `backup_test.dart`: grupo nuevo `Import — credit_limit (sprint credit-cards)` con DT-01/03/04/05.
- `screens/reports/credit_cards_tab_test.dart` (nuevo, 5 tests): empty, data completa, sin minPct, sin closingDay, badge sin deuda.

## Desviaciones respecto al plan

- **Formato de `minimumPaymentPct` e `interestRate`**: la spec asumió porcentaje humano 0-100 (S1, S2). Al implementar descubrí que el backup existente valida rango `[0, 1]` — o sea el legacy los guarda como **decimal**. Alineé la implementación con el formato del backup para preservar round-trip:
  - **BD**: decimal 0-1 (ej: `0.05` = 5%).
  - **UI**: el usuario escribe porcentaje humano 0-100 (ej: `5`); `_parsePercentInput` divide por 100 antes de persistir.
  - **CreditCardStatus.compute**: `debt × minimumPaymentPct` directo (sin `/100`).
  - `CLAUDE.md` actualizado con la convención.
- **RN-CC04 (fechas)**: el plan asumía `clamp al último día del mes destino` para casos como `closingDay=31` en abril. Al implementar UT-13d/h/g, se cambió a **saltar al mes siguiente** cuando el target no existe en el mes actual. Es más útil para el usuario (si el corte no existe este mes, el próximo corte real es el siguiente mes que sí tenga el día). El plan documenta clamp; los tests documentan skip. La diferencia práctica es cosmética: en la vida real un `closingDay=31` en abril debería avanzarse a mayo 31, no colgarse en abril 30.
- **Cambio de comportamiento en `balanceAtDate`**: se limpió el condicional `if (creditLimit != null)`; ahora todas las tarjetas activas contribuyen a CR con `creditLimit - balance`. Cambio esperado por el schema NOT NULL pero no explícito en el plan. Documentado en R2 residual del review.
- **Fix inesperado en `nextOccurrenceOfDay`**: la primera versión del helper hacía clamp al mes actual (rompía UT-13d/h/g). Corregido a saltar al mes siguiente si el target excede los días del mes actual.
- **`_accountFromJson` cambia firma**: pasó de `AccountsCompanion` a `({AccountsCompanion companion, bool adjusted})`. Cambio de superficie para acumular el contador. Impacto en el caller único (`importFromJson`) actualizado.

## Pruebas realizadas y recomendadas

**Realizadas**: `flutter analyze` limpio + `flutter test` 406/406 verdes + build APK release verificado con `verify-apk.sh` (versionCode 2071 / versionName 0.13.0).

**Recomendadas**:
- SM-01: instalar APK sobre BD real, verificar que la migración corre sin error visible y las tarjetas activas siguen presentes con sus balances correctos.
- SM-03: ver que la deuda por tarjeta coincide con lo que muestra el dashboard (BO/DE/CR).
- SM-04: registrar `credit_expense` desde el FAB, volver al reporte y verificar actualización reactiva.
- SM-05: setear `minimumPaymentPct=5%` desde el form, ver que aparece pago mínimo estimado.
- SM-08: importar backup viejo (pre-sprint) con `credit_limit=null`; snackbar debe reportar N ajustadas.
- SM-09: tester en cel limpio: onboarding slide 3 dice "6 reportes"; tab Tarjetas muestra empty state con CTA.
- `branch-quality-review` con slug `flutter-reports-credit-cards-v1` antes del commit final.

## Riesgos residuales y posibles regresiones

Ver `implementation-review.md` secciones "Riesgos residuales" y "Posibles regresiones" para el detalle completo.

Resumen:
- Migración destructiva de `accounts` (in-memory testeada; primera corrida real es la definitiva).
- Cambio de CR total en tarjetas legacy con límite null → 0.
- Modelo público `Account.creditLimit` sigue `num?` por compat JSON — asimetría documentada.
- Orden RN-CC09 (proximidad + alfabético mixto) puede iterarse post-smoke.
- `interestRate` guardado pero no usado en el reporte — feature futura.
