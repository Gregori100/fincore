# Branch Quality Review: flutter-loans-v1

## Metadata

- Fecha: 2026-07-16 14:15
- Rama revisada: `main` (working directory, sin commitear)
- Rama base: `main@5c12a52` (HEAD antes de este sprint)
- Rango: working tree vs `5c12a52`
- Commit HEAD: sin commit (todo staged/unstaged)
- Autor de revisión: Claude Opus 4.7 (branch-quality-review skill)
- Carpeta de reporte: `engineering/quality-review/flutter-loans-v1/`

## Resumen ejecutivo

- **Sprint mediano-grande**: nueva entidad `Loan` (13 campos) + kind `loan_payment` + 5 pantallas nuevas + Backup v2 + KPI naranja Dashboard + hotfix del enum + slider bidireccional. 22 archivos productivos, +4658/-1632, 780 tests verde.
- **1 finding CRÍTICO**: NaN/Infinity pasan todas las validaciones numéricas (DAO + backup). Un pago con `principal_amount = NaN` corrompe permanentemente `balanceOf` y el KPI naranja.
- **5 findings ALTOS**: (1) drill-down del renglón sintético "Intereses de préstamos" navega a `/entries?categoryIds=__synthetic__` que retorna 0 resultados; (2) 5 pantallas nuevas sin migrar a design tokens (viola política CLAUDE.md); (3-5) tres áreas críticas de test sin cobertura (renglón sintético RN-L17, `watchTotalLoans` RN-L20, backup v2 round-trip RN-L18).
- **8 findings MEDIOS**: chip `loan_payment` no round-trippea en `entries_filters` (regresión del bug M1 anterior), migración 9→10 no idempotente ante crash mid-migration, race con read stale en `registerLoanPayment`, `cancel()` sin gate para entries con `loan_id`, doble pop mentiroso, slider sin semantics.
- **11 findings BAJOS/INFO**: trivial polish + mejoras de mensaje.
- **Cobertura por RN**: 15/20 ✅, 3 ⚠️ parciales, 2 ❌ sin cobertura. Los DAOs de `Loans` y `loan_payments` están muy bien testeados (44 tests entre `loans_dao_test.dart` y `loan_payments_test.dart`). Los gaps están en reportes/UI, streams del state service y backup v2 round-trip real.
- **Estado**: la rama **NO es entregable tal cual**. El finding crítico (F-SEC-01) puede corromper la BD silenciosamente. Los ALTAS de test (F-TEST-01, F-TEST-02, F-TEST-04) exponen paths sin protección de regresión sobre la funcionalidad más nueva del sprint. Los ALTAS de UX (F-ARCH-01, F-UX-01) son de calidad-de-producto.

## Alcance revisado

- Commits: 0 (working tree). Base: `5c12a52` (sprint anterior).
- Archivos principales:
  - `mobile/lib/data/daos/loans_dao.dart` (nuevo, ~380 líneas)
  - `mobile/lib/data/daos/entries_dao.dart` (+registerLoanPayment, +deleteLoanPayment, +updateEntry gate, +loan_payment kind case en _validateAccountTypes)
  - `mobile/lib/data/daos/accounts_dao.dart` (+deleteAccount pre-check)
  - `mobile/lib/data/database.dart` (nueva tabla `Loans` + 3 columnas nuevas en `JournalEntries` + schemaVersion 10 + rama 9→10 + rama defensiva 8→10)
  - `mobile/lib/data/backup.dart` (bump v2 + `_loanFromJson/_loanToJson` + validación referencias)
  - `mobile/lib/data/reports.dart` (UNION ALL renglón sintético)
  - `mobile/lib/data/financial_state.dart` (`watchTotalLoans` + cache invalidation)
  - `mobile/lib/constants/kinds.dart` + `account_types.dart` + `reports_tokens.dart` (kind loanPayment + token sintético)
  - `mobile/lib/router/app_router.dart` (6 rutas nuevas)
  - `mobile/lib/screens/loans_list_screen.dart`, `loan_form_screen.dart`, `loan_detail_screen.dart`, `loan_monthly_payment_form.dart`, `loan_capital_payment_form.dart` (nuevos)
  - `mobile/lib/screens/entry_form_screen.dart` (+`_lockedByLoan` gate + `_LoanEntryBanner`)
  - `mobile/lib/screens/dashboard_screen.dart` (+KPI naranja + chips PRÓXIMO PAGO + entry point overflow menu)
  - `mobile/lib/screens/reports/top_movements_tab.dart` (+case loanPayment en switches)
  - `mobile/lib/widgets/movement_row.dart` (+`_LoanChip`)
  - `mobile/lib/widgets/error_snackbar.dart` (+`_daoCodeToMessage` compartido + 3 DaoError cases)
  - `mobile/lib/widgets/kind_picker.dart` + `entry_account_label.dart` (+ case loanPayment)
  - `mobile/lib/app_dependencies.dart` (+`loansDao`)
  - Tests nuevos: `test/data/loans_dao_test.dart` (24) + `test/data/loan_payments_test.dart` (20). Extensiones en `backup_test.dart` + hotfix en `saved_views_flow_test.dart` + `top_movements_tab_test.dart`.
- Áreas: dominio (préstamos + pagos), datos (tabla + migración), backup, reportes, dashboard, forms, error mapping, tests.
- Comandos usados: `git status --short`, `git log --oneline main -5`, `git diff --stat main -- 'mobile/lib/' 'mobile/test/'`, `grep -rn`, `flutter analyze --no-pub`, `flutter test`.

## Hallazgos bloqueantes

### B1. NaN/Infinity pasan todas las validaciones numéricas (críptico total en balanceOf)

- **Severidad**: Crítica
- **Área**: Seguridad + validaciones frontera (Lane 1 F-SEC-01, Lane 6 F-TEST-07)
- **Evidencia**:
  - `mobile/lib/data/daos/entries_dao.dart:321-338` (registerLoanPayment): `if (amount <= 0)`, `if (principalAmount < 0 || interestAmount < 0)`, `if ((principalAmount + interestAmount - amount).abs() >= 0.005)` — ninguna llama `.isFinite`.
  - `mobile/lib/data/daos/loans_dao.dart:124-141` (create), `:229-246` (updateLoan): mismo patrón.
  - `mobile/lib/data/backup.dart:557-604` (`_entryFromJson`), `:638-653` (`_loanFromJson`): mismos.
  - `NaN <= 0` → `false`, `NaN + NaN - amount → NaN`, `NaN.abs() >= 0.005 → false`. Pasa toda la cadena.
- **Impacto**: un `loan_payment` con `principalAmount = NaN` o `Infinity` corrompe `balanceOf` (retorna `NaN`), auto-cierre paid nunca dispara, KPI naranja `watchTotalLoans` retorna `NaN`, reactividad rota. Vector directo: `{"principal_amount": 1e400}` en un JSON importado (JSON válido → `Infinity` en Dart). Vector indirecto: `double.parse('NaN')` desde un TextField patchado.
- **Recomendación**: helper `_requireFinitePositive(double v, String field)` invocado antes de cada guarda `<= 0`. Aplicar en `LoansDao.create/updateLoan`, `EntriesDao.registerLoanPayment`, `_loanFromJson`, `_entryFromJson` (y por defensa en profundidad F-SEC-05 en accounts.interestRate/minimumPaymentPct).
- **Depende de**: ninguna.

### B2. Drill-down del renglón sintético "Intereses de préstamos" navega a URL vacía

- **Severidad**: Alta
- **Área**: Arquitectura + UX (Lane 4 F-ARCH-01)
- **Evidencia**: `mobile/lib/screens/reports/spending_by_category_tab.dart:319-337`. El `onTap` del `_SpendingBucketRow` no chequea `bucket.categoryId == kLoanInterestSyntheticId`. Al tap sobre "Intereses de préstamos", el deep link resultante es `/entries?...&categoryIds=__synthetic_loan_interest__` — ningún entry en BD tiene esa `category_id`, lista siempre vacía. El comentario en `constants/reports_tokens.dart:11-12` es explícito: *"drill-down no-op, opcionalmente rutear a /loans"* — no se implementó ninguna.
- **Impacto**: usuario tapea "Intereses de préstamos", ve lista vacía, asume que el reporte miente. Erosiona confianza.
- **Recomendación**: en `_SpendingBucketRow.build`:
  ```dart
  onTap: bucket.categoryId == kLoanInterestSyntheticId
      ? () => context.push('/loans')
      : () => context.push(_buildDeepLink()),
  ```
- **Depende de**: ninguna.

### B3. 5 pantallas nuevas del sprint sin migrar a design tokens

- **Severidad**: Alta (política del repo)
- **Área**: Frontend + design system (Lane 5 F-UX-01)
- **Evidencia**: los 5 archivos nuevos (`loans_list_screen`, `loan_form_screen`, `loan_detail_screen`, `loan_monthly_payment_form`, `loan_capital_payment_form`) + `_LoanEntryBanner` en `entry_form_screen.dart` usan `fontSize: 10/11/12/13/15/16/18/32`, `Skeleton(width: 160, height: 32)`, `trackHeight: 6`, `enabledThumbRadius: 10`, `Container(width: 10, height: 10)` — todos literales fuera de `fincore_typography`/`fincore_spacing`/`fincore_radii`. `grep token-exception` en los 5 archivos: **0** ocurrencias. `BorderRadius.circular(8)` y `BorderRadius.circular(999)` con literal en `dashboard_screen.dart:405,464,470` (Lane 5 F-UX-06).
- **Impacto**: viola la política declarada en `CLAUDE.md` sección "Sistema de tokens de diseño". Como son archivos nuevos, la regla "boy scout" aplica aún más fuerte: el sprint debió estrenar los archivos ya con tokens. Cambios futuros de tokens no propagan.
- **Recomendación**: pase de limpieza migrando a `bodyM/bodyS/label/overline` + `kSpaceX` + `kRadiusMd/kRadiusPill`. Para los pocos casos legítimos fuera de escala (thumbRadius del slider, dots de leyenda 10x10), agregar `// token-exception: <razón>`.
- **Depende de**: ninguna. Recomendable en un sprint dedicado tipo `flutter-loans-tokens-polish-v1` — es grande.

### B4. Renglón sintético "Intereses de préstamos" (RN-L17) sin cobertura de test

- **Severidad**: Alta
- **Área**: Pruebas (Lane 6 F-TEST-01)
- **Evidencia**: `mobile/lib/data/reports.dart:312-347` implementa el UNION ALL. `grep -n "loan\|prést\|Interes" mobile/test/data/reports_test.dart` = 0 hits. La spec RF-011 y línea 193 del plan pedían explícitamente ≥ 3 tests: presente con 2 pagos + ausente con `interest_amount == 0` + ignora `deleted_at != null` + total correcto + orden DESC.
- **Impacto**: cualquier regresión en el SQL (typo en `WHERE deleted_at IS NULL`, cambio del token, filtro de rango mal) pasa desapercibida. Es el data path que justifica todo el sprint contable.
- **Recomendación**: agregar mínimo 3 tests en `test/data/reports_test.dart`.
- **Depende de**: ninguna.

### B5. `FinancialStateService.watchTotalLoans()` sin cobertura de test

- **Severidad**: Alta
- **Área**: Pruebas (Lane 6 F-TEST-02)
- **Evidencia**: `mobile/lib/data/financial_state.dart:198-223` implementa el stream cacheado (patrón `_ReplayBalanceStream`). `grep -rn watchTotalLoans mobile/test/` = vacío. El KPI naranja Dashboard depende 100% de este stream.
- **Impacto**: no hay red frente a regresiones en reactividad tras crear pagos, invalidación del cache, réplica al re-suscribirse, comportamiento `> 0` que decide render u ocultar el KPI, exclusión de préstamos con `deleted_at != null` o `closed_at != null`.
- **Recomendación**: agregar 4 tests replicando patrón de `watchBo/watchDe/watchCr` en `test/data/financial_state_test.dart` — total inicial 0, sube al crear préstamo, baja al pagar principal, vuelve a 0 al cerrar/eliminar + no cuenta soft-deleted.
- **Depende de**: ninguna.

### B6. Backup v2 sin round-trip real de loans ni validación de referencias

- **Severidad**: Alta
- **Área**: Pruebas + datos (Lane 6 F-TEST-04)
- **Evidencia**: `test/data/backup_test.dart` agregó tests para `version > 2` rechaza + v1 legacy acepta + export contiene `"loans"`. Faltan: (a) round-trip export v2 → import v2 con ≥1 loan + ≥1 loan_payment con splits preservando bit-a-bit; (b) v2 con `loan.destination_account_id` inexistente → `invalid_reference`; (c) v2 con `journal_entries[].loan_id` inexistente → `invalid_reference`; (d) `close_reason` inválido → `invalid_loan_data`. Spec línea 192 los pide explícitamente.
- **Impacto**: la validación de referencias del import v2 puede estar rota. Usuario importa backup corrupto y le hace `wipeAll` seguido de FK violation o crash silencioso.
- **Recomendación**: agregar los 4 tests. Round-trip es prioridad 1.
- **Depende de**: ninguna.

## Hallazgos no bloqueantes

### M1. Migración 9→10 no idempotente ante crash mid-migration

- Severidad: Media
- Archivo: `mobile/lib/data/database.dart:754-788` (9→10) y `:790-827` (8→10)
- Evidencia: `CREATE TABLE IF NOT EXISTS loans (...)` idempotente + tres `ALTER TABLE journal_entries ADD COLUMN` **sin** `IF NOT EXISTS`. Cada `customStatement` autocommittea. Si la app se mata post-`CREATE TABLE loans + ADD COLUMN loan_id` pero antes de `ADD COLUMN principal_amount`, `user_version` sigue en 9. Siguiente `open()` re-ejecuta rama 9→10 y falla en `ADD COLUMN loan_id` con "duplicate column". BD inaccesible.
- Impacto: usuario con instalación live pierde acceso en el edge del kill.
- Recomendación: envolver cada `ADD COLUMN` con probe `SELECT count(*) FROM pragma_table_info('journal_entries') WHERE name = 'loan_id'` y skip si != 0.

### M2. `registerLoanPayment` usa `loan.closedAt` stale dentro de la transacción

- Severidad: Media
- Archivo: `mobile/lib/data/daos/entries_dao.dart:341-388`
- Evidencia: validación de `loan.closedAt` (línea 347) y variable `loan` se leen **fuera** de `transaction(...)` (línea 341). El guard auto-close usa la variable stale: `if (balance <= 0.005 && loan.closedAt == null)`. Con dos taps rápidos del "Guardar" (UI no bloquea futures simultáneas), race concurrente puede bypasear `loan_closed` o sobreescribir `close_reason='manual'` con `'paid'`.
- Impacto: pagos duplicados sobre préstamo cerrado, o pérdida silenciosa de `close_reason='manual'`.
- Recomendación: re-leer el préstamo **dentro** de la transacción (mismo patrón que `deleteLoanPayment:422-424`).

### M3. `EntriesDao.cancel(id)` sin gate para entries con `loan_id`

- Severidad: Media
- Archivo: `mobile/lib/data/daos/entries_dao.dart:604-620`
- Evidencia: `updateEntry` bloquea correctamente `loanId != null` con `immutable_loan_payment`. `cancel(id)` sólo revisa `deletedAt`. Único freno es la UI (`entry_form_screen.dart:781` renderiza botón "Eliminar" sólo cuando `!_lockedByLoan`). Cualquier caller alternativo (bulk actions, deep-link, script mantenimiento) bypassea la lógica de reapertura auto.
- Impacto: préstamo `paid` con balance > 0 queda inconsistente si se cancela un pago desde otra vía.
- Recomendación: replicar guard `if (existing.loanId != null) throw 'immutable_loan_payment'` en `cancel(id)`. Los pagos van por `deleteLoanPayment`; el income inicial por `deleteLoan`.

### M4. Chip "Pago de préstamo" en filtros de /entries no round-trippea

- Severidad: Media
- Archivo: `mobile/lib/screens/entries_filters_screen.dart:327` + `mobile/lib/data/entries_filters.dart:413-419`
- Evidencia: el chip aparece (via `for (final k in JournalKind.values)`) y se puede seleccionar, filtrando entries correctamente en runtime. Pero `EntriesFilters.parse` y `fromSavedJson` filtran contra `_kValidKinds` que NO incluye `'loan_payment'` — al re-hidratar la pantalla el chip se destilda solo y el filtro desaparece silenciosamente. Regresión de la misma clase de bug del M1 del quality review anterior (categorías archivadas en filtros).
- Impacto: filtro se pierde tras reload o al aplicar una vista guardada. Divergencia entre 3 tablas de kinds válidos (DAO `_validKinds`, backup `_validKinds`, entries_filters `_kValidKinds`).
- Recomendación: agregar `'loan_payment'` a `_kValidKinds`. Idealmente extraer `const kAllJournalKinds = { for (final k in JournalKind.values) k.apiValue }` en `constants/kinds.dart` y consumirlo desde los 3 sitios para eliminar la triplicación permanentemente.

### M5. `_loanFromJson` y `_entryFromJson` lanzan `TypeError` (no `BackupError`) ante tipos inválidos

- Severidad: Media
- Archivo: `mobile/lib/data/backup.dart:625-673` (`_loanFromJson`), `:540-621` (`_entryFromJson`)
- Evidencia: casteos duros sin null-check (`json['id'] as String`, `json['payment_day'] as int`). Un backup malicioso con `"id": null` o `"payment_day": "1"` lanza `_CastError` no tipado en vez de `BackupError`. El snackbar muestra mensaje Dart no traducible.
- Impacto: UX rota en import. La transacción no ha corrido (parseo previo a `_db.transaction`), pero el usuario ve stack trace.
- Recomendación: helper `_requireField<T>(json, key)` que lance `BackupError('invalid_json', 'El campo $key es requerido y debe ser $T')`. O al menos try/catch top-level en `importFromJson` que remapea `TypeError` a `BackupError('invalid_json')`.

### M6. Import backup no aplica `_validateAccountTypes` a `loan_payment`

- Severidad: Media
- Archivo: `mobile/lib/data/backup.dart:540-621` (`_entryFromJson`)
- Evidencia: el parser valida `loan_id`, `principal_amount`, `interest_amount` y split para `kind == 'loan_payment'`, pero NO valida que `account_origin_id` esté presente ni que `account_destination_id` sea null. Un backup con `{"kind":"loan_payment","account_origin_id":null,"account_destination_id":"<credit-uuid>",...}` pasa el parseo. Simétrico para los 5 kinds pre-hotfix.
- Impacto: BD queda con entries inconsistentes con RN-011 tras un import. `FinancialStateService` calcula balances usando accounts referenciadas — un `loan_payment` con destino credit baja la deuda "gratis". Vector: exportar → editar manualmente → importar.
- Recomendación: `_validateEntryShape(kind, originId, destId, loanId)` en `backup.dart` con las mismas reglas que `EntriesDao._validateAccountTypes` (sin tocar accounts). Alternativa mínima: para `loan_payment` requerir `originId != null && destId == null`.

### M7. `deleteLoanPayment` usa `existing.loanId!` sin guard

- Severidad: Media
- Archivo: `mobile/lib/data/daos/entries_dao.dart:412`
- Evidencia: `final loanId = existing.loanId!` — crash si `loanId == null` (posible tras backup manipulado con `kind='loan_payment' AND loan_id IS NULL`). Lanza `NoSuchMethodError` no tipado.
- Impacto: UX rota — usuario ve stack trace en vez de error amigable. Transacción hace rollback pero la experiencia es fea.
- Recomendación: reemplazar por check explícito con `EntriesDaoError('invalid_kind', 'Este pago no está ligado a un préstamo.')`.

### M8. `spendingByCategory` synthetic bucket contamina `SpendingReport.count`

- Severidad: Media
- Archivo: `mobile/lib/data/reports.dart:337-353` + `:995-996`
- Evidencia: UNION ALL emite `COUNT(*) AS count` sobre `loan_payment`s con interés > 0. En `_buildReport`, `count += bucketCount` mezcla conteo de gastos + loan_payments — dos poblaciones distintas.
- Impacto: header "N movimientos" cuenta loan_payments que no aparecen en drill-down. Discrepancia UI.
- Recomendación: emitir `0 AS count` en el SELECT sintético (los intereses NO son "entries de gasto") o documentar el contrato.

### M9. `_confirmDelete` de `loan_form_screen` no hace el doble pop que promete

- Severidad: Media
- Archivo: `mobile/lib/screens/loan_form_screen.dart:258-261`
- Evidencia: comentario dice "Doble pop: cerrar form + volver a /loans desde detail si aplica" pero sólo hace un `Navigator.of(context).maybePop()`. Si el usuario navegó `/loans → /loans/:id → /loans/:id/edit` y elimina, queda en `/loans/:id` con streams reactivos vacíos + nombre del préstamo eliminado hasta hacer back manual.
- Impacto: UX inconsistente. Detail screen muestra "No hay pagos registrados" con nombre del préstamo eliminado.
- Recomendación: `context.go('/loans')` para resetear stack, o encadenar 2 pops.

### M10. `_SplitSlider` sin semantics para lectores de pantalla

- Severidad: Media
- Archivo: `mobile/lib/screens/loan_monthly_payment_form.dart:529-534`
- Evidencia: `Slider` sin `Semantics(label: ...)` ni `semanticFormatterCallback`. Un usuario con TalkBack escucha "0 de 3500" sin contexto.
- Recomendación: `semanticFormatterCallback: (v) => 'Capital \$${v.toStringAsFixed(0)}, intereses \$${(total - v).toStringAsFixed(0)}'`.

### M11. Migración schema 9→10 no ejercitada (ni saltos 6/7/8→10)

- Severidad: Media-Alta
- Archivo: `mobile/test/data/database_migration_test.dart` (existe hasta 6→7, sin 9→10)
- Evidencia: `loans_dao_test.dart` abre BD fresca con `NativeDatabase.memory()` — corre `onCreate`, no `onUpgrade`. Nada verifica que un upgrade desde v9 (o saltos defensivos desde v6/v7/v8) resulte en el schema esperado sin corrupción. Spec línea 327 lo pide como criterio.
- Impacto: usuario con datos en v9 hace `flutter run` post-update, `onUpgrade` puede fallar silenciosamente o dejar schema a medias.
- Recomendación: patrón MG-01 del sprint 6→7: crear BD virgen v9, correr `migrator.onUpgrade(migrator, 9, 10)`, verificar `loans` + 3 columnas + `idx_entries_loan` + preservación de datos v9. Replicar para 6/7/8→10.

### M12. `_daoCodeToMessage` sin test de mapeo para los 7 códigos nuevos del sprint

- Severidad: Media
- Archivo: `mobile/test/widgets/` (no existe test para `error_snackbar.dart`)
- Evidencia: `error_snackbar.dart:62,142-158` cablea 7 códigos nuevos. Sin test que verifique que retornen mensaje amigable no genérico.
- Impacto: cualquier code lanzado por el DAO pero no mapeado cae al fallback genérico — exactamente la regresión que el helper compartido intentó resolver.
- Recomendación: exponer `_daoCodeToMessage` o crear wrapper `messageForError(Object)`, testear los 7 códigos → mensaje no-null, no genérico, en español.

### L1. `readsFrom` en `balanceOf().getSingle()` es dead metadata

- Severidad: Baja
- Archivo: `mobile/lib/data/daos/loans_dao.dart:60-67`
- Evidencia: `customSelect(sql, readsFrom: {...}).getSingle()` — el `readsFrom` sólo participa en `.watch()`. En un one-shot es ruido.
- Recomendación: eliminar `readsFrom` del `.getSingle()`. En `watchBalance` sí es necesario.

### L2. Mensaje `invalid_kind` en backup + top_movements no menciona `loan_payment`

- Severidad: Baja (cosmético)
- Archivo: `mobile/lib/data/backup.dart:549-555`
- Evidencia: el mensaje enumera *"esperado: income, expense, credit_expense, debt_payment o transfer"* pero el set `_validKinds` ya incluye `loan_payment`. Confuso si el usuario edita JSON manual.
- Recomendación: agregar `"o loan_payment"` o derivar de `_validKinds.join(', ')`.

### L3. `_LoanChip` en `movement_row` usa `fontSize: 10` fuera del sistema

- Severidad: Baja
- Archivo: `mobile/lib/widgets/movement_row.dart:211`
- Evidencia: token más pequeño es `overline` (11). `fontSize: 10` no calza. Sin `Semantics(label: 'ligado a préstamo')`.
- Recomendación: subir a `overline` o marcar `// token-exception:`.

### L4. `_LoanTotalCard` rompe consistencia tipográfica con BO/DE/CR hermanos

- Severidad: Baja
- Archivo: `mobile/lib/screens/dashboard_screen.dart:418-422` vs `530-537`
- Evidencia: label "PRÉSTAMO" usa `fontSize: 11, letterSpacing: 0.5`. BO/DE/CR usan `fontSize: 10, letterSpacing: 1.2, w700`.
- Recomendación: alinear al mismo tratamiento o extraer helper `_kpiLabelStyle`.

### L5. `_SplitSlider` muestra leyenda 50/50 cuando el monto es 0

- Severidad: Baja
- Archivo: `mobile/lib/screens/loan_monthly_payment_form.dart:465`
- Evidencia: `final ratio = total > 0 ? ... : 0.5`. Si Diego borra el monto total, leyenda dice "Capital 50% / Intereses 50%" pero ambos están en 0 y slider disabled.
- Recomendación: con `total <= 0`, mostrar `'Capital —' / 'Intereses —'`.

### L6. `displayXL.copyWith(fontSize: 32)` erosiona el token tipográfico

- Severidad: Baja
- Archivo: `mobile/lib/screens/loan_detail_screen.dart:240`
- Evidencia: `displayXL` es 56/800. Con `fontSize: 32` sólo se preserva weight.
- Recomendación: usar `headingL` (20) o declarar `headingXL` explícito.

### L7. `LoanCapitalPaymentForm` pre-llena `_descCtrl` con string literal

- Severidad: Baja
- Archivo: `mobile/lib/screens/loan_capital_payment_form.dart:27` vs `loan_monthly_payment_form.dart:29`
- Evidencia: `TextEditingController(text: 'Abono extra a capital')` — todos los abonos salvados sin editar terminan con esa descripción. Asimétrico con el monthly form (vacío).
- Recomendación: mover a `InputDecoration(hintText: 'Ej: Abono extra a capital')`.

### L8. `_buildDayActivityMap` no clasifica `loan_payment` pero cuenta el día

- Severidad: Baja
- Archivo: `mobile/lib/data/reports.dart:1862-1903`
- Evidencia: SQL de `movementsByDay` no filtra por kind. Un día con sólo `loan_payment` tiene `totalCount > 0` pero todos los flags (`hasIncome`, `hasSpending`, `hasInternal`) en `false`.
- Recomendación: decidir si loan_payment es "spending" o "internal", agregar al switch. Alternativa: filtrar en SQL.

### L9. `loans.destination_account_id` sin índice

- Severidad: Baja (info)
- Archivo: `mobile/lib/data/database.dart:749-788`
- Evidencia: `findByDestinationAccount(id)` hace full scan. Nulo en single-user con <20 préstamos.
- Recomendación: TD para próximo bump: `CREATE INDEX IF NOT EXISTS idx_loans_destination ON loans(destination_account_id) WHERE deleted_at IS NULL`.

### L10. `HAVING SUM(interest_amount) > 0` es load-bearing

- Severidad: Info
- Archivo: `mobile/lib/data/reports.dart:352`
- Evidencia: sin HAVING, el SELECT sintético emite fila con `SUM = NULL` cuando no hay loan_payments → `_buildReport` crashea con `row.read<double>('total')` sobre null.
- Recomendación: comentario `// HAVING crítico: previene fila con total=NULL cuando no hay loan_payments` o cambiar a `COALESCE(SUM(...), 0)` + filtrar en Dart.

### L11. Tests hotfix brittle (`saved_views_flow_test.dart`, `top_movements_tab_test.dart`)

- Severidad: Baja
- Evidencia: los hotfixes que actualicé para el chip nuevo son sensibles al orden de renderizado y al layout responsive. `top_movements_tab_test.dart` hace 6 taps sin ensureVisible.
- Recomendación: iterar sobre lista + `ensureVisible` para robustez.

### L12. Cobertura RN parcial

- RN-L01/RN-L02 (inmutabilidad principal + destino): impedido por diseño (updateLoan no expone los campos) pero no hay test que verifique.
- RN-L16 (cascada deleteLoan): verifica soft-delete pero no efecto en balances.
- RN-L18 (backup v2 + refs): parcial — v1 legacy y `version > 2` ✅, round-trip + `invalid_reference` de loans ❌ (ver B6).
- Recomendación: agregar los tests puntuales.

## Plan de correccion ordenado

1. **B1 (crítico)**: agregar `_requireFinite*` helpers en `LoansDao.create/updateLoan`, `EntriesDao.registerLoanPayment`, `_loanFromJson`, `_entryFromJson`, `_accountFromJson` (interestRate + minimumPaymentPct).
2. **M7 (defensa)**: reemplazar `existing.loanId!` en `deleteLoanPayment` por check tipado con `EntriesDaoError`.
3. **M3 (defensa)**: agregar gate `loanId != null` en `EntriesDao.cancel(id)`.
4. **M2 (concurrencia)**: re-leer `loan` dentro de la transacción de `registerLoanPayment`.
5. **M5 + M6 (backup import robusto)**: helper `_requireField<T>` + `_validateEntryShape` para catch de TypeError y validación de shape de `loan_payment`.
6. **B2 (drill-down UX)**: condicional en `_SpendingBucketRow.onTap` — navegar a `/loans` si `kLoanInterestSyntheticId`.
7. **M4 (round-trip filters)**: agregar `'loan_payment'` a `_kValidKinds` en `entries_filters.dart`. Idealmente extraer `kAllJournalKinds` en `constants/kinds.dart` y consumirlo desde los 3 sitios.
8. **M8 (semantics count)**: emitir `0 AS count` en el SELECT sintético del UNION ALL.
9. **M9 (doble pop)**: `context.go('/loans')` en `_confirmDelete` de `loan_form_screen`.
10. **B4 (tests renglón sintético)**: 3 tests en `reports_test.dart`.
11. **B5 (tests watchTotalLoans)**: 4 tests en `financial_state_test.dart`.
12. **B6 (tests backup v2)**: 4 tests round-trip + validación de refs en `backup_test.dart`.
13. **M12 (tests snackbar mapping)**: exponer helper + tests para los 7 códigos.
14. **L2 + L4 (mensajes + tipografía KPI)**: correcciones triviales.
15. **L5 (leyenda slider)**: guard `total <= 0`.
16. **L7 (descripción pre-llenada)**: mover a hintText.
17. **L1 (readsFrom dead)**: eliminar del `.getSingle()`.
18. **B3 (design tokens)**: sprint dedicado `flutter-loans-tokens-polish-v1`. NO en este ciclo — es grande y no bloquea funcionalidad.
19. **M1 (migración idempotente) + M11 (tests migración)**: sprint dedicado `flutter-loans-migration-hardening-v1`. NO en este ciclo — riesgo bajo probabilidad.
20. **M10 + L3 + L6 + L8 + L9 + L10 + L11 + L12**: mejoras acumuladas para futuro sprint de polish.

## Validaciones recomendadas

- `cd mobile && dart run build_runner build --delete-conflicting-outputs` (por si cambian tablas).
- `cd mobile && flutter analyze --no-pub` (esperar 5 hints preexistentes de `prefer_const_constructors` en `entry_form_screen.dart`).
- `cd mobile && flutter test` (esperar ≥ 780 verde; con los nuevos tests ≥ 795).
- `flutter build apk --release --split-per-abi --target-platform android-arm64`.
- Smoke manual del pago del mes con edge cases: monto = 0, monto muy grande, borrar y volver a poner (verificar restart_alt).

## Limitaciones

- No se pudo verificar comportamiento real de la migración 9→10 sobre BD live (requiere test de integración M11).
- El widget test del slider bidireccional no existe (F-TEST comparativo Lane 6). Verificación depende de smoke manual.
- No hay E2E con Diego usando el APK actual — el smoke manual tras los fixes es requerido antes del merge.
- Los `_daoCodeToMessage` casos alternativos (input String directo, DomainError sin código) no cubiertos por tests.
