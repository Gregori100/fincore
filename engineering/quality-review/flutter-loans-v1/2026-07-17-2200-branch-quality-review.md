# Branch Quality Review: flutter-loans-v1 (cierre post-smoke completo)

## Metadata

- Fecha: 2026-07-17 22:00
- Rama revisada: `main`
- Rama base: `main~4` (5c12a52 — cierre de `flutter-accounts-archive-v1`)
- Rango: `9e44121..HEAD` (4 commits del sprint)
- Commit HEAD: `f450f41`
- Autor de revisión: Claude Opus 4.7 (5 subagentes en paralelo + integración)
- Carpeta de reporte: `engineering/quality-review/flutter-loans-v1/`

## Resumen ejecutivo

- El sprint ship a `0.27.3+113` con **818 tests verdes** y APK validado en cel. Los 40 smokes (base + hotfixes v2-v5) fueron completados por Diego.
- La entrega es **funcionalmente correcta** para uso single-user local. Sin embargo, el review encontró **3 hallazgos bloqueantes** que afectan integridad del backup y confianza en la ruta de edición de pagos:
  - **B1**: `is_monthly_payment` no se preserva en el round-trip de backup v2 (regresión silenciosa al restaurar).
  - **B2**: `updateLoanPayment` (~160 líneas con 7 códigos de error y auto-close/reopen) **no tiene ningún test**.
  - **B3**: El test de round-trip existente no assertea `is_monthly_payment` — la brecha que ocultó B1.
- Los hallazgos no bloqueantes son mayoritariamente **deuda de tokens de diseño** (~30 literales de `fontSize`/`SizedBox`/`BorderRadius` sin `token-exception:` en la superficie nueva), **duplicación de menu de acciones** entre `loan_form_screen` y `loan_detail_screen`, y **docs desactualizadas** en `CLAUDE.md` + resúmenes del sprint (no reflejan hotfixes v2-v5 ni schema v11).
- **Sin secretos, sin cambios de signing, sin archivos raros**. Config release (pubspec ↔ gradle) consistente. Generados por `build_runner` limpios.
- Rama entregable **tras corregir B1-B3**. El resto puede quedar como plan de mejora incremental o boy-scout del próximo sprint que toque los archivos.

## Alcance revisado

- **Commits**: `9e44121` (datos + tests), `ecbcffe` (UI + DI), `90bdb79` (release 0.27.3+113), `f450f41` (docs).
- **Archivos principales**: 49 archivos, ~12.9k LOC (~5.2k en `database.g.dart` generado).
  - Data: `database.dart`, `daos/{loans,entries,accounts}_dao.dart`, `backup.dart`, `reports.dart`, `financial_state.dart`, `entries_filters.dart`.
  - UI: `screens/loan_*.dart` (5 nuevas), `screens/dashboard_screen.dart`, `screens/entry_form_screen.dart`, `screens/reports/spending_by_category_tab.dart`, `screens/reports/top_movements_tab.dart`.
  - Widgets: `movement_row`, `kind_picker`, `error_snackbar`, `entry_account_label`.
  - Config: `pubspec.yaml`, `build.gradle.kts`, `app_dependencies.dart`, `app_router.dart`.
  - Tests: `test/data/loans_dao_test.dart`, `test/data/loan_payments_test.dart`, expansiones en `backup_test`, `financial_state_test`, `reports_test`.
  - Docs: `engineering/specs/flutter-loans-v1/` (spec + plan + implementation), 2 quality-reviews previos.
- **Áreas**: SQL (schema + migraciones + queries reactivas), DAO (validaciones de dominio + transacciones), UI (5 pantallas nuevas + chips dashboard), reportes (renglones sintéticos), backup (v2 con loans).
- **Comandos usados**:
  - `git log --oneline main~4..HEAD`, `git diff --stat`, `git diff --name-status`.
  - `git show --stat` por commit.
  - Lecturas dirigidas de `mobile/lib/data/**`, `mobile/lib/screens/loan_*.dart`, `mobile/lib/screens/dashboard_screen.dart`, `mobile/test/data/loan_*.dart`.
  - `grep` sobre tokens (`fontSize:`, `SizedBox`, `BorderRadius.circular`, `token-exception`), sobre `is_monthly_payment` en backup, sobre `updateLoanPayment` en tests.
  - Revisión de `CLAUDE.md`, `pubspec.yaml`, `build.gradle.kts`.

## Hallazgos bloqueantes

### B1. `is_monthly_payment` NO se preserva en el round-trip del backup v2

- Severidad: **Alta**
- Área: Seguridad de datos / Backup
- Evidencia: `mobile/lib/data/backup.dart:408-423` (export), `mobile/lib/data/backup.dart:559-666` (import). `_entryToJson` no emite `is_monthly_payment`; `_entryFromJson` no lo lee; el `JournalEntriesCompanion.insert` no lo setea. La columna aplica `DEFAULT 0` en el schema, así que TODOS los `loan_payment` reimportados quedan `is_monthly_payment=false`. `grep -n is_monthly_payment mobile/lib/data/backup.dart` → 0 coincidencias.
- Impacto: Tras export → wipe → import v2, cada préstamo pierde la marca "Pago del mes" y todos los pagos aparecen como capital. Rompe:
  - `LoansDao.watchHasMonthlyPaymentIn` (chip Próximo pago del Dashboard queda encendido eternamente).
  - `LoansDao.watchMonthsOverdue` (todos los meses aparecen atrasados).
  - Regla `capital_before_monthly` en cualquier edit posterior (violación silenciosa: la BD queda en un estado que ninguna escritura nueva podría producir).
- Recomendación: Emitir `is_monthly_payment` en `_entryToJson` cuando `kind == 'loan_payment'`. Leerlo en `_entryFromJson` con default `false` para v1 y validación cruzada v2. Complementa con **B3** (test).
- Depende de: nada.

### B2. `updateLoanPayment` sin ningún test

- Severidad: **Alta**
- Área: Tests / regresión lógica
- Evidencia: Método en `mobile/lib/data/daos/entries_dao.dart:500-661` (~160 líneas, 7 ramas de error, auto-close/reopen dentro de tx). Callers: `loan_monthly_payment_form.dart:271`, `loan_capital_payment_form.dart:137`. `grep updateLoanPayment mobile/test/` → 0 coincidencias.
- Impacto: Editar un pago puede: (a) corromper balance si el nuevo split desconoce el overpay; (b) dejar préstamo con `close_reason='paid'` pero saldo>0; (c) violar unicidad monthly al mover fecha entre meses; (d) fallar `capital_before_monthly` al mover un capital fuera de su mes con monthly. Ninguna regresión encendería tests actuales.
- Recomendación: Grupo `group('updateLoanPayment', ...)` en `test/data/loan_payments_test.dart` con al menos: happy path (cambio de monto/split), rechazo `overpay_loan` (nuevo principal > saldo + oldPrincipal), `duplicate_monthly_payment` (mover a mes con monthly ya existente), `capital_before_monthly` (mover capital a mes sin monthly), `payment_before_contract`, auto-close paid, auto-reopen paid, preservación de `isMonthlyPayment` (no editable desde edit).
- Depende de: nada.

### B3. Test de round-trip de backup v2 no verifica `is_monthly_payment`

- Severidad: **Alta**
- Área: Tests / cobertura
- Evidencia: `mobile/test/data/backup_test.dart:884-928`. Registra `loan_payment` con `isMonthlyPayment: true`, hace export→wipe→import y assertea `amount`, `principalAmount`, `interestAmount` — pero no `payments.first.isMonthlyPayment`.
- Impacto: Es la razón por la que **B1** llegó a producción sin detectarse. Aunque se corrija B1, sin este test la regresión puede reintroducirse.
- Recomendación: Agregar `expect(payments.first.isMonthlyPayment, isTrue)` al test existente. Añadir un caso mixto: exportar 1 monthly + 1 capital del mismo mes, importar y verificar ambos flags. Corregir en el mismo PR que corrija B1.
- Depende de: B1.

## Hallazgos no bloqueantes

### M1. Checks de overpay y unicidad mensual corren fuera de la transacción

- Severidad: Media
- Área: Concurrencia / integridad transaccional
- Evidencia: `entries_dao.dart:393-430` (register), `:583-621` (update). `monthlyCount`, `currentBalance` y validaciones `overpay_loan`/`duplicate_monthly_payment`/`capital_before_monthly` ocurren ANTES del `await transaction(...)` de la línea 441. La tx re-lee `freshLoan` (para `closedAt`) pero no reevalúa balance ni monthlyCount.
- Impacto: Doble-tap del botón Guardar (o un slow-emit del stream) puede pasar ambos checks con foto stale e insertar dos monthlies en el mismo mes o dejar saldo negativo. Bajo en single-user local pero rompe la promesa de invariantes.
- Recomendación: Mover los tres checks DENTRO de la transacción re-computando balance y monthlyCount. Defensa complementaria: deshabilitar el botón Guardar durante el submit.
- Depende de: nada (ortogonal a B1-B3).

### M2. Auto-close/reopen del préstamo mutando `loans` desde `EntriesDao` (duplicado ×3)

- Severidad: Media
- Área: Arquitectura / DDD
- Evidencia: `entries_dao.dart:474-484` (register), `:635-660` (update), `:746-761` (delete). Tres copias del protocolo "re-leer préstamo → llamar `balanceOf` → decidir close/reopen → escribir LoansCompanion". `EntriesDao` no es dueño de la tabla `loans` pero la muta. Ya hay drift: el error tras `freshLoan == null` no es idéntico entre las 3 rutas.
- Impacto: Cualquier cambio en la regla de transición requiere tocar 3 sitios coordinadamente. Superficie de bug futuro.
- Recomendación: Extraer `LoansDao.applyPaymentSideEffects({loanId, now})` que reciba el `db.transaction` reenlazable y decida close/reopen. Los 3 métodos de `EntriesDao` bajan a una llamada.
- Depende de: nada.

### M3. Duplicación total del menú de acciones entre `loan_form_screen` y `loan_detail_screen`

- Severidad: Media
- Área: UI / DRY
- Evidencia: `loan_form_screen.dart:152-353` vs `loan_detail_screen.dart:143-350`. `_confirmCloseManual`, `_confirmReopen`, `_confirmDelete`, `_buildMenuItems`, `_handleMenuAction`, enum `_LoanXAction` y los arreglos de `DestructiveImpact` son idénticos módulo un `Navigator.maybePop` vs `context.go('/dashboard')` en el confirmDelete.
- Impacto: ~200 líneas duplicadas; risk drift al editar strings o agregar acciones.
- Recomendación: Extraer `LoanActionsMenu` en `widgets/` que reciba `Loan loan`, `List<Account> accounts` y un callback `onDeletedNavigate`. Ambos screens lo consumen.
- Depende de: nada.

### M4. Migraciones directas `5→11`, `6→11`, `7→11` faltantes

- Severidad: Media
- Área: SQL / migraciones
- Evidencia: `database.dart:855-955`. Existen ramas 8→11, 9→11, 10→11 pero no desde v5, v6 ni v7. El guardrail final (RN-H02) crashea con `UnimplementedError`.
- Impacto: Testeador quedado en v5/6/7 (existen 5→6, 6→7, 6→8, 6→9, 7→8, 7→9) que actualice al APK del sprint verá crash al abrir la app. En la realidad Diego probablemente está en v10/v11, pero rompe la convención.
- Recomendación: Añadir ramas defensivas componiendo las existentes. Mejor: refactorizar `onUpgrade` a stepper (`for (v = from; v < to; v++) applyStep(v, v+1)`).
- Depende de: nada.

### M5. Reglas de dominio filtrándose a la UI: `_daysUntilPayment` en dashboard

- Severidad: Media
- Área: Arquitectura / DDD
- Evidencia: `dashboard_screen.dart:380-387` (definición) + `:494` (consumo). Cálculo de "días hasta el próximo `paymentDay`" con roll al mes siguiente vive en el screen. Simétrico conceptualmente a `LoansDao._expectedPaymentMonths` que ya está en el DAO con test.
- Impacto: Cálculo de calendario de pago duplicado entre dos capas; el de UI queda huérfano en `flutter test`.
- Recomendación: Mover a `LoansDao.daysUntilNextPaymentDay(paymentDay, {now})` static público y cubrir con test unitario junto al de `expectedPaymentMonths`.
- Depende de: nada.

### M6. Boy-scout de tokens de diseño incumplido en toda la superficie nueva

- Severidad: Media
- Área: Frontend / design system
- Evidencia: ~30 literales sin `// token-exception:`:
  - `loan_detail_screen.dart` (16: fontSize 10/11/12/13/15/16/32, `BorderRadius.circular(3)`).
  - `loan_monthly_payment_form.dart` (8: fontSize 11/12/16/20).
  - `loan_capital_payment_form.dart` (4).
  - `loans_list_screen.dart` (3).
  - `loan_form_screen.dart` (1).
  - `dashboard_screen.dart:399-449, :534-556` (`BorderRadius.circular(999)` en vez de `kRadiusPill`, `fontSize: 10/12/18`, `SizedBox(width: 6/8/12)`, `EdgeInsets(horizontal: 14)` fuera de escala).
  - `widgets/movement_row.dart:213` (`fontSize: 10` en `_LoanChip`, rompe migración previa del widget compartido).
- Impacto: CLAUDE.md exige ≤10 excepciones en toda la app; este sprint las multiplica por 3. Rompe la promesa del sistema de tokens.
- Recomendación: Sweep dedicado usando `bodyS`/`label`/`overline`/`kSpaceX`/`kRadiusX`. Donde el diseño exige un valor puntual (ej. `fontSize: 32` del hero del header), marcar con `// token-exception:` y razón.
- Depende de: nada.

### M7. `principalAmount.toStringAsFixed(0)` en DestructiveDialog rompe formato de moneda

- Severidad: Media
- Área: UI / consistencia
- Evidencia: `loan_form_screen.dart:235`, `loan_detail_screen.dart:209`. Pinta "150000" en vez de "$150,000.00" (que es lo que usa `formatAmount` en el resto de la app).
- Impacto: En el dialog más crítico del flujo (delete cascade) el número aparece sin identidad de moneda ni miles.
- Recomendación: Reemplazar por `formatAmount(loan.principalAmount)`.
- Depende de: nada.

### M8. `_ChipShell` del dashboard por debajo del mínimo táctil de 44dp

- Severidad: Media
- Área: UX / accesibilidad
- Evidencia: `dashboard_screen.dart:534-556`. `padding vertical: 8` + icon 14 + text 12 = ~30dp de altura. `InkWell` navega a `/loans/:id`.
- Impacto: Los chips "Atrasado" / "Próximo pago" son el CTA principal del fold del dashboard hacia el detalle; fallan touch en uso mobile real.
- Recomendación: `ConstrainedBox(minHeight: 44)` + `Center` interno, o subir `vertical` a `kSpaceMd` (12).
- Depende de: nada.

### M9. `_PaymentRow` en cerrado manual sin affordance visual de read-only

- Severidad: Media
- Área: UX
- Evidencia: `loan_detail_screen.dart:761-865`. Con `readOnly: true` solo se pierde `onTap` y el `IconButton` de delete; el resto (colores, badge, split pill) idéntico a un row editable.
- Impacto: Diego descubre el read-only al hacer tap y ver que no pasa nada. Banner superior lo dice pero cada row no lo comunica.
- Recomendación: `Opacity(0.6)` + `Icon(Icons.lock_outline)` en el header del row, o desaturar los pills a `textSubtle` cuando el préstamo esté cerrado manualmente.
- Depende de: nada.

### M10. StreamBuilder de préstamo con `snap.data == null` muestra spinner permanente

- Severidad: Media
- Área: UX / manejo de errores
- Evidencia: `loan_detail_screen.dart:360-374`. No distingue "cargando" (`!snap.hasData`) de "no existe" (`snap.hasData && snap.data == null`). No maneja `snap.hasError`. Mismo patrón en `loans_list_screen.dart` y los StreamBuilder de dashboard.
- Impacto: Deep-link viejo o race con `deleteLoan` deja spinner infinito sin salida útil.
- Recomendación: Tres ramas: cargando / no encontrado / error. Empty state "Préstamo no encontrado" con botón Volver.
- Depende de: nada.

### M11. Commit body del release miente sobre el `versionCode` de origen

- Severidad: Media
- Área: Historia / trazabilidad
- Evidencia: Commit `90bdb79` body dice *"versionCode 110 → 113 acumulando hotfixes v1 base (110), v2 (111), v3 (112), v4 (113)"*. Diff real: `109 → 113`, no existen commits intermedios `+110`, `+111`, `+112` en la historia (los builds intermedios solo existieron localmente durante el smoke).
- Impacto: Rompe bisect. Buscar "commit que corrigió `is_monthly_payment`" no lleva a nada — todo está aplastado en `9e44121`/`ecbcffe`.
- Recomendación: Nota en `checklist.md` o addenda al mensaje del commit (git notes) aclarando la genealogía real. `implementation/resumen-ejecutivo.md:40` también quedó promising `0.26.0+109 → 0.27.0+110`, sincronizar.
- Depende de: nada.

### B4. Import de backup no valida invariante loan → income inicial

- Severidad: Baja
- Área: Backup / integridad de datos
- Evidencia: `backup.dart:270-310`. Valida `entry.loan_id → loan` presente, pero no la existencia de un `income` con `loan_id=X, account_destination_id=loan.destination_account_id, amount=loan.principal_amount`.
- Impacto: JSON manipulado con Loan sin income inicial pasa el import; después BO/DE reflejan saldos inconsistentes sin mensaje tipado.
- Recomendación: Añadir validación post-parseo antes de la tx, lanzando `BackupError('invalid_reference')`.
- Depende de: nada.

### B5. `watchMonthsOverdue` sin cap superior de placeholders (`IN (?,?,?,...)`)

- Severidad: Baja
- Área: SQL / robustez
- Evidencia: `loans_dao.dart:481-494`. `_expectedPaymentMonths` enumera mes-a-mes desde `contract_date` hasta hoy sin cap.
- Impacto: Backup con `contract_date` remoto (ej. 1900-01-01) genera >1500 placeholders y crashea con `too many SQL variables` (SQLite max 999 <3.32 / 32766 desde 3.32).
- Recomendación: Cap a últimos ~60 meses, o validar `contract_date >= 2000-01-01` al import.
- Depende de: nada.

### B6. `LoansDao.deleteLoan` recibe `stateService?` opcional que rompe convención de streams reactivos

- Severidad: Baja
- Área: Arquitectura / consistencia
- Evidencia: `loans_dao.dart:342-367`. Callers: `loan_form_screen.dart:257`, `loan_detail_screen.dart:230`. Sprint `flutter-local-hardening-v4` estableció que streams cacheados invalidan solos con `readsFrom` — este DAO reintroduce la invalidación manual.
- Impacto: Un caller que olvide pasar `deps.stateService` deja KPIs con saldo viejo. Rompe promesa.
- Recomendación: Verificar si `_ReplayBalanceStream` re-emite al soft-delete del income; si sí, borrar el parámetro. Si no, mover al listener interno de `FinancialStateService`.
- Depende de: nada.

### B7. Boundary de tolerancia 0.005 en `overpay_loan` / `invalid_loan_split` sin test

- Severidad: Baja
- Área: Tests / cobertura de bordes
- Evidencia: `loan_payments_test.dart:105-117, 235-250`. Tests usan diferencias obvias (10001 vs 5000, diff 0.001). No golpean 0.004/0.006 alrededor del umbral 0.005.
- Impacto: Cambios en tolerancia pasarían silenciosamente.
- Recomendación: Un test por umbral (acepta 0.004, rechaza 0.006).
- Depende de: nada.

### B8. `isMonthlyPayment=true` con `interest_amount=0` no tiene test

- Severidad: Baja
- Área: Tests
- Evidencia: Todos los tests monthly usan `interestAmount >= 1`. El caso monthly sin intereses (motivo declarado del cambio de proxy legacy a columna persistida) no se ejercita.
- Impacto: Refactor futuro que vuelva al proxy `interest > 0` rompe la unicidad silenciosamente.
- Recomendación: Test que registre `{principal:500, interest:0, isMonthlyPayment:true}` y verifique `hasMonthlyPaymentIn` + rechazo de segundo monthly + aceptación de capital posterior.
- Depende de: nada.

### B9. `deleteLoanPayment` default (sin cascade) sin test que documente el contrato

- Severidad: Baja
- Área: Tests
- Evidencia: `entries_dao.dart:718-762`. Default `cascadeCapitalInMonth: false` puede dejar capitales huérfanos. Los tests solo cubren `= true`.
- Impacto: Refactor que cambie el default pasaría sin ser detectado.
- Recomendación: Test explícito del contrato actual: sin cascade deja capitales activos.
- Depende de: nada.

### B10. Gate `immutable_loan_payment` en `EntriesDao.cancel` sin cobertura

- Severidad: Baja
- Área: Tests
- Evidencia: `entries_dao.dart:945-950` (defensa en profundidad F-TX-03). Ningún test invoca `cancel(loan_payment_id)`.
- Impacto: Refactor que remueva el guard hace `cancel()` sobre loan_payment silenciosamente, sin disparar reapertura auto → préstamo `paid` con saldo>0.
- Recomendación: Tests `cancel(loan_payment)` y `cancel(loan_income)` deben lanzar `immutable_loan_payment`.
- Depende de: nada.

### B11. `watchMonthsOverdue` con edición post-hoc de `paymentDay` no cubierta

- Severidad: Baja
- Área: Tests
- Evidencia: `loans_dao_test.dart:484-631`. Falta caso "hoy dentro del mes de contrato, contract_day > paymentDay, today < paymentDay" → esperado vacío. Y "cambio de `paymentDay` de 5 a 20 post pago del día 10" → verificar match por `%Y-%m`.
- Impacto: Solo UX (chip incorrecto), sin corromper datos.
- Recomendación: 2 tests adicionales.
- Depende de: nada.

### B12. Botón "Saldar" desaparece cuando `balance == 0` en vez de deshabilitarse

- Severidad: Baja
- Área: UX / discoverability
- Evidencia: `loan_monthly_payment_form.dart:718-730`, `loan_capital_payment_form.dart:367-378`.
- Impacto: Aprender el atajo depende de encontrarlo cuando aún hay saldo. En un préstamo pagado que se edita, usuario no sabe si es bug o intencional.
- Recomendación: Mostrar siempre con `onPressed: null` + tooltip "Ya está saldado", o chip pasivo "✓ Saldado".
- Depende de: nada.

### B13. Post-delete `context.go('/dashboard')` pierde stack de `/entries → /entries/:id → /loans/:id`

- Severidad: Baja
- Área: UX / navegación
- Evidencia: `loan_detail_screen.dart:236`, `loan_form_screen.dart:263`. El hotfix v3 optó por reset simétrico.
- Impacto: Quien entró vía Movimientos pierde su lugar. Rompe convención CLAUDE.md ("`context.go` solo para resets intencionales").
- Recomendación: `pop-hasta-que-salgo-de-/loans` loop, o redirect del router a `/loans` cuando el préstamo desapareció.
- Depende de: nada.

### B14. `LoanFormScreen._submit` no marca picker de destino como inválido cuando falta

- Severidad: Baja
- Área: UX / validación visible
- Evidencia: `loan_form_screen.dart:110-113`. Snackbar sin marcar el campo con `errorText`.
- Impacto: Fricción explícita al primer alta.
- Recomendación: Wrapper `FormField<String>` con validator, o `errorText:` en el picker.
- Depende de: nada.

### B15. Falta Semantics en KPIs y chips del módulo préstamos

- Severidad: Baja
- Área: Accesibilidad
- Evidencia: `dashboard_screen.dart:379-560`, `loans_list_screen.dart:237-263`, `loan_detail_screen.dart:624-664`.
- Impacto: TalkBack lee cada texto por separado.
- Recomendación: `Semantics(container: true, label: '...')` en cards y chips.
- Depende de: nada.

### B16. Contraste borderline en `_StatusBadge` "Cerrado" (warning sobre warning-tint 15%, 11dp/w600)

- Severidad: Baja
- Área: Accesibilidad / design system
- Evidencia: `loans_list_screen.dart:255-259`, `loan_detail_screen.dart:889-895`. Repite anti-patrón del snackbar warning (RF-019).
- Impacto: Legibilidad borderline AA.
- Recomendación: Foreground `canvas` o `textPrimary` con warning solo en el bg tint (patrón del snackbar).
- Depende de: nada.

### B17. `CLAUDE.md` no documenta `loan_payment` ni schemaVersion 11

- Severidad: Baja
- Área: Docs / convenciones
- Evidencia: `CLAUDE.md:57` (kinds sin `loan_payment`), `:62-67` (tabla RN-011 sin renglón loan), `:75` (dice `schemaVersion=1` — el real es 11). Sin mención de `LoansDao`, tokens sintéticos ni RN-L01..L20 ni de los 10 códigos de error nuevos.
- Impacto: Un agente futuro puede rechazar `loan_payment` como kind válido, permitir `updateEntry` sobre loan_payment (viola RN-L15), o bumpear schemaVersion sin registrar migración.
- Recomendación: Actualizar los 4 puntos + tabla de errores tipados.
- Depende de: nada.

### B18. `test-plan.md` congelado en smoke 1-20 no cubre hotfixes v2-v5

- Severidad: Baja
- Área: Docs / test-plan
- Evidencia: `engineering/specs/flutter-loans-v1/plan/test-plan.md:203-231, :261`. Criterio de aceptación dice `versionCode = 110`. No hay smokes 21+.
- Impacto: Sprints futuros no tienen regresión escrita para Saldar, cascade delete, chip atrasado, contract_day==payment_day.
- Recomendación: Anexar "Smoke post-hotfix v2-v5" con los 40 items reales que Diego probó. Corregir versionCode.
- Depende de: nada.

### B19. Resúmenes ejecutivo/extenso del sprint congelan cifras pre-hotfix

- Severidad: Baja
- Área: Docs
- Evidencia: `implementation/resumen-ejecutivo.md:40`, `implementation-review.md:5`. Todos anuncian `0.26.0+109 → 0.27.0+110` y schema `9 → 10`. Real: `0.27.3+113`, schemaVersion `11`.
- Impacto: Papeleo, pero al inspeccionar el sprint el resumen miente.
- Recomendación: Addenda de cierre apuntando a `+113`, schemaVersion 11 y los 4 hotfixes.
- Depende de: nada.

### B20. Falta índices en la tabla `loans` (`deleted_at`, `destination_account_id`)

- Severidad: Baja
- Área: SQL / performance
- Evidencia: `database.dart:163-182, :764-956`. `journal_entries.loan_id` sí tiene `idx_entries_loan` parcial. `loans` no.
- Impacto: Impacto real nulo en single-user con <100 préstamos. Deuda de consistencia con el resto del schema.
- Recomendación: Migración 11→12 aditiva con `idx_loans_deleted`, `idx_loans_dest_account`. No urgente.
- Depende de: nada.

## Plan de corrección ordenado

**Prioridad 1 — Bloqueantes (mismo PR o hotfix inmediato):**

1. **B1** — Corregir export/import de `is_monthly_payment` en `backup.dart` (`_entryToJson` emite el flag cuando `kind == 'loan_payment'`; `_entryFromJson` lo lee con default `false` para compat v1 y valida en v2).
2. **B3** — Actualizar test round-trip existente para assertear `isMonthlyPayment`. Añadir test mixto monthly+capital.
3. **B2** — Escribir `group('updateLoanPayment', ...)` con 7-8 tests cubriendo las ramas de error y auto-close/reopen.

**Prioridad 2 — Deuda estructural (siguiente PR):**

4. **M1** — Mover checks (overpay, duplicate_monthly, capital_before_monthly) dentro de la transacción re-computando estado.
5. **M2** — Extraer `LoansDao.applyPaymentSideEffects` y consumir desde los 3 métodos de `EntriesDao`.
6. **M4** — Añadir ramas de migración `5→11`, `6→11`, `7→11` (o refactor a stepper).
7. **M5** — Mover `_daysUntilPayment` a `LoansDao` con test.

**Prioridad 3 — UX / consistencia (boy-scout del próximo sprint que toque los archivos):**

8. **M7** — `formatAmount()` en DestructiveDialog de loans.
9. **M8** — Chips del dashboard con `minHeight: 44`.
10. **M9** — Read-only visual en `_PaymentRow` cerrado manual.
11. **M10** — StreamBuilder distingue cargando/no-existe/error.
12. **M3** — Extraer `LoanActionsMenu`.
13. **M6** — Sweep de tokens de diseño en los 6 archivos de la superficie nueva.

**Prioridad 4 — Cobertura y docs (paralelo, sin bloquear otros PRs):**

14. **B7, B8, B9, B10, B11** — Tests de boundary, monthly-sin-interés, delete-sin-cascade, cancel-gate, watchMonthsOverdue-edge-cases.
15. **B12–B16** — Ajustes menores UX/accesibilidad.
16. **B4, B5** — Blindaje adicional del import de backup.
17. **B6** — Limpieza del parámetro `stateService?` en `deleteLoan`.
18. **B17, B18, B19** — Actualizar `CLAUDE.md`, `test-plan.md`, `resumen-ejecutivo.md`.
19. **M11** — Addenda al mensaje del commit release + `checklist.md`.
20. **B20** — Migración 11→12 con índices de `loans`.

## Validaciones recomendadas

Antes de mergear los fixes de B1-B3:

```bash
cd mobile
flutter test test/data/backup_test.dart
flutter test test/data/loan_payments_test.dart
flutter test  # suite completa, mantener ≥ 818
flutter analyze  # mantener 5 hints preexistentes tolerados
flutter build apk --release --split-per-abi --target-platform android-arm64
cd .. && ./scripts/verify-apk.sh
```

Smoke manual mínimo tras B1:
- Crear préstamo + 2 pagos del mes + 1 abono capital.
- Export → wipe → import → verificar en `/loans/:id`:
  - Los 2 monthlies aparecen con badge "Pago del mes".
  - El chip del dashboard NO muestra "Próximo pago" si el mes ya se cubrió.
  - `watchMonthsOverdue` reporta 0 atrasados si todos los meses tienen monthly.

## Limitaciones

- No se ejecutó ni observó el APK en cel durante esta revisión (Diego ya validó los 40 smokes previos a este review — ver `post-hotfix-status.md`).
- No se profundizó en `spending_by_category_tab.dart` drill-down del renglón capital (agent de UX marcó como "no cubierto en profundidad"), ni en `top_movements_tab.dart`.
- No se ejecutó `dart run build_runner build` para verificar que los generados están en sync con las tablas declaradas — asumido por confianza en el `flutter test` verde.
- No se probó ejecutar la migración `5→11`, `6→11`, `7→11` en una BD real (verificado sólo por lectura de `database.dart`).
- No se auditó el comportamiento reactivo del chip `_UpcomingPaymentChip` legacy (aún referenciado en dashboard alongside el nuevo `_LoanStatusChip`) — puede haber solapamiento con el chip nuevo si el usuario tiene préstamos en distintos estados.
- El chequeo de historia (M11) se hizo sobre `git log --oneline main~4..HEAD`; no se auditó si algún commit intermedio quedó fuera del rango revisado por confusión sobre la base.
