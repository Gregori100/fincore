# Post-Hotfix Status: flutter-loans-v1

## Metadata

- Fecha: 2026-07-16 15:30
- Reporte base: `2026-07-16-1415-branch-quality-review.md`
- Autor: Claude Opus 4.7 (branch-quality-review skill, fase de cierre)

## Brechas cerradas en este ciclo

### Bloqueantes cerrados

- **B1** (Crítico — NaN/Infinity): guard `isFinite` en `LoansDao.create/updateLoan`, `EntriesDao.registerLoanPayment`, `_loanFromJson`, `_entryFromJson` (`amount`, `principalAmount`, `interestAmount`, `monthlyPayment`).
- **B2** (Alta — drill-down sintético): `_SpendingBucketRow.onTap` detecta `kLoanInterestSyntheticId` y navega a `/loans` en vez del deep link vacío.
- **B4** (Alta — tests renglón sintético): 5 tests nuevos en `spendingByCategory` (presente/ausente + count=0 + soft-delete ignorado + rango temporal).
- **B5** (Alta — tests `watchTotalLoans`): 7 tests nuevos en `financial_state_test.dart` (BD vacía, sube al crear, baja al pagar, auto-cierre paid, cerrado manual, eliminado, múltiples préstamos).
- **B6** (Alta — tests backup v2): 5 tests nuevos en `backup_test.dart` (round-trip real con loans + splits + validación de refs + shape del loan_payment).

### Medios cerrados

- **M2** (concurrencia — read stale): `registerLoanPayment` re-lee el préstamo DENTRO de la transacción y valida `closedAt` con el read fresco.
- **M3** (defensa `cancel`): `EntriesDao.cancel(id)` bloquea entries con `loan_id != null` con `immutable_loan_payment`.
- **M4** (chip filters no round-trippea): extraído `kAllJournalKinds` en `constants/kinds.dart` como fuente única. `entries_filters.dart` consume esa constante.
- **M5** (TypeError sin traducir): try/catch top-level en `importFromJson` remapea `TypeError` a `BackupError('invalid_json', ...)` con mensaje amigable.
- **M6** (shape loan_payment en backup): validación de `originId != null && destId == null` para `loan_payment` en `_entryFromJson`.
- **M7** (loanId! bang): `deleteLoanPayment` reemplaza `existing.loanId!` por check explícito con `EntriesDaoError('invalid_kind', ...)`.
- **M8** (count sintético contamina): SELECT sintético emite `0 AS count` en vez de `COUNT(*)`.
- **M9** (doble pop mentiroso): `_confirmDelete` de `loan_form_screen` usa `context.go('/loans')` para resetear stack en vez de `maybePop()`.

### Bajos cerrados

- **L1** — `readsFrom` dead en `balanceOf().getSingle()` eliminado.
- **L2** — mensaje `invalid_kind` en backup derivado de `_validKinds.join(', ')`.
- **L4** — KPI naranja "PRÉSTAMO" alinea tipografía con BO/DE/CR (fontSize 10, letterSpacing 1.2, w700).
- **L5** — `_SplitSlider` muestra `'Capital —' / 'Intereses —'` cuando `total <= 0` (no leyenda 50/50 mentirosa).
- **L7** — `LoanCapitalPaymentForm` mueve "Abono extra a capital" de `TextEditingController(text:)` a `hintText`.

## Brechas deferidas (documentadas, no cerradas en este ciclo)

### Sprint dedicado recomendado

- **B3** (Alta — 5 pantallas sin design tokens): grande, > 40 sitios entre las 5 pantallas + widgets nuevos. Requiere sprint `flutter-loans-tokens-polish-v1`. NO bloquea funcionalidad — es política de calidad.
- **M1** (Media — migración 9→10 no idempotente): probabilidad baja (kill mid-migration), riesgo alto si ocurre. Sprint `flutter-migration-hardening-v1` que aplica el fix a las 4 ramas del `onUpgrade` (5→6, 6→7, 7→8, 8→9, 9→10 y las defensivas).
- **M11** (Media-Alta — tests migración 9→10): patrón MG-01/MG-02 del sprint 6→7. Va con M1 en el mismo sprint de hardening.

### Mejoras acumuladas

- **M10** — `_SplitSlider` sin `Semantics` / `semanticFormatterCallback` (accesibilidad).
- **M12** — `_daoCodeToMessage` sin tests unitarios para los 7 códigos nuevos.
- **L3** — `_LoanChip` en `movement_row` con `fontSize: 10` fuera de escala.
- **L6** — `displayXL.copyWith(fontSize: 32)` erosiona el token (loan_detail_screen).
- **L8** — `_buildDayActivityMap` no clasifica `loan_payment`.
- **L9** — Falta índice `idx_loans_destination` (nulo en single-user con <20 préstamos).
- **L10** — `HAVING SUM(interest_amount) > 0` documentado como load-bearing con comentario en el SQL.
- **L11** — Hotfixes brittle en `saved_views_flow_test.dart` y `top_movements_tab_test.dart`.
- **L12** — Cobertura RN parcial (RN-L01/L02 sin test explícito de inmutabilidad via customStatement).

### Decisiones aplazadas

- **F-TX-04** (LOW — overpay validation): decisión intencional de "libreta libre" alineada con el resto del sprint. NO se agregó `overpay_loan` como en `debt_payment`.
- **F-ARCH-03** (BAJA — clasificación de `loan_payment` en `movementsByDay`): decisión de dominio, requiere clarificación con Diego si el pago cuenta como "spending" o "internal".

## Estado final del sprint

- **APK**: `mobile/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` (21.7MB, versionCode 110, versionName 0.27.0).
- **`flutter analyze`**: 5 issues preexistentes (`prefer_const_constructors` en entry_form_screen). Cero errores nuevos.
- **`flutter test`**: **797/797 verde** (780 pre-hotfix + 17 nuevos: 5 renglón sintético + 7 watchTotalLoans + 5 backup v2).
- **Nuevos archivos de test**: ninguno; se extendieron `reports_test.dart`, `financial_state_test.dart` y `backup_test.dart`.

## Archivos productivos modificados en el hotfix

- `mobile/lib/constants/kinds.dart` — nuevo `kAllJournalKinds`.
- `mobile/lib/data/backup.dart` — try/catch TypeError, shape check loan_payment, mensaje kind derivado, isFinite checks.
- `mobile/lib/data/daos/entries_dao.dart` — isFinite en split + re-read intra-tx en `registerLoanPayment` + guard `loan_id != null` en `deleteLoanPayment` + gate en `cancel(id)`.
- `mobile/lib/data/daos/loans_dao.dart` — isFinite en create/updateLoan + `readsFrom` dead removido de `balanceOf`.
- `mobile/lib/data/entries_filters.dart` — usa `kAllJournalKinds` en vez de `_kValidKinds` hardcoded.
- `mobile/lib/data/reports.dart` — SELECT sintético emite `0 AS count` + comentario `HAVING crítico`.
- `mobile/lib/screens/dashboard_screen.dart` — KPI naranja label alineado con BO/DE/CR.
- `mobile/lib/screens/loan_capital_payment_form.dart` — `hintText` en vez de controller pre-poblado.
- `mobile/lib/screens/loan_form_screen.dart` — `context.go('/loans')` en delete + import go_router.
- `mobile/lib/screens/loan_monthly_payment_form.dart` — leyenda del slider con `noAmount` guard.
- `mobile/lib/screens/reports/spending_by_category_tab.dart` — drill-down sintético navega a `/loans`.

## Archivos de test extendidos en el hotfix

- `mobile/test/data/reports_test.dart` — grupo "renglón sintético" (+5 tests).
- `mobile/test/data/financial_state_test.dart` — grupo "watchTotalLoans()" (+7 tests).
- `mobile/test/data/backup_test.dart` — grupo "loans v2 (hotfix B6)" (+5 tests).

## Recomendación de merge

Sprint **entregable** tras los fixes de este ciclo. Las brechas deferidas (B3 tokens, M1/M11 migración idempotente) son mejoras de calidad y hardening que no impiden funcionalidad ni datos. Correr smoke manual completo antes de merge.
