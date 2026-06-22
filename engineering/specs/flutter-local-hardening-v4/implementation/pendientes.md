# Pendientes — flutter-local-hardening-v4

Trabajo no terminado al cierre del sprint o diferido a sprints futuros.

## Pendientes inmediatos

- **Smoke manual del 0.3.8+40 en el Redmi** (T020): Diego confirma que el APK arm64 instala limpio sobre el `0.3.7+39` previamente instalado, abre, Settings → "Acerca de" muestra `0.3.8+40`. Las cards BO/DE/CR del Dashboard se rendean correctamente (RF-007 v4 — no hay regresión visual). Si aparece algún glitch (especialmente en `entry_form_screen` que cambió a EntriesDao codegen), documentar como desviación post-smoke.

## Diferidos del v4 (Fases 4 y 5)

Detalle completo en `desviaciones-plan.md` DV-1 y DV-2. Resumen para tracking:

### Fase 4 — Gap RN-011 en dropdowns

- **RF-019 (Media)**: ampliar los 5 tests del `entry_form_kinds_test.dart` para validar que el `AccountPicker` filtra cuentas por `allowedTypes`. Patrón:
  - `find.ancestor(of: find.text('Cuenta destino'), matching: find.byType(DropdownMenu<String>))` para localizar el field.
  - Tap en el ícono `Icons.arrow_drop_down` dentro del field.
  - `find.descendant(of: find.byType(MenuItemButton), matching: find.text(...))` para validar items.
  - `tester.sendKeyEvent(LogicalKeyboardKey.escape)` para cerrar.
  - Estimado: ~3 horas para los 5 kinds + dropdowns secundarios de pago/transfer.

### Fase 5 — Widget tests CRUD profundos

- **RF-020 (Media)**: `mobile/test/screens/account_form_screen_test.dart`. Casos:
  - Alta de debit nuevo aparece en lista.
  - Alta con nombre vacío bloqueada por validator.
  - Alta con `duplicate_account_name` muestra snackbar.
  - Edición exitosa de debit (name + description).
  - Edición de Bolsa (protected) en modo read-only.
  - **Bloqueador identificado**: `enterText` + `pumpAndSettle` se cuelgan. Hipótesis pendientes de validar: animación del AccountTypePicker, side effect del `didChangeDependencies`, async load no cerrado. Tiempo invertido en v4: ~30 min antes de skip.

- **RF-021 (Media)**: `mobile/test/screens/entries_list_screen_test.dart`. Casos:
  - 5 entries de tipos distintos rendean.
  - Bottom sheet de filtros: tap icon, seleccionar `kind=income`, aplicar → solo 2 entries visibles.
  - Limpiar filtro → vuelven los 5.
  - **Posible problema**: el bottom sheet usa `showModalBottomSheet` que crea un overlay; los `find` deben respetarlo.

- **RF-022 (Media)**: `mobile/test/screens/category_form_screen_test.dart`. Casos:
  - Alta con name + color + icon → preview muestra ambos.
  - Cambiar color → preview cambia.
  - Cambiar icon → preview cambia.
  - Submit persiste.

- **RF-023 (Media)**: `mobile/test/screens/settings_screen_test.dart`. Casos:
  - Tap "Reiniciar sin exportar" → diálogo destructivo → confirmar → redirect a `/first-run`.
  - Tap "Categorías" → navega a `/categories`.

**Total estimado:** ~12-14h de debugging + implementación. **Recomendación:** abrir sprint `flutter-test-coverage-v1` dedicado.

## Diferidos a sprints futuros (no urgentes — heredados del v3 y MVP)

- **L1-H1, L1-H4, L1-H5, L1-H6, L1-H7** (todos Baja del quality review v3): robustez incremental del harness, tests. Atacar como parte del sprint de testing coverage.

- **L2-H3 — `addSync` sobre controller cerrado**: descartado durante v4 (RF-014, DV-4). Si en el futuro aparece `Bad state: Cannot add new events after calling close` en producción, reproducir y aplicar protección alternativa (NO `hasListener` — ese es el patrón fallido).

- **L3-H2, L3-H4, L3-H5 del v3**: aplicados en v4 (RF-016, RF-017, RF-018). Sin pendientes restantes en el script.

- **Widget tests de `entry_form_screen` adicionales**: actualmente cancel + submit en edit. Falta:
  - Submit en alta con todos los kinds (alta de income, expense, credit_expense, debt_payment, transfer).
  - Validación de OverpayDebt en `registerDebtPayment` desde la UI.
  - CategoryPicker filtra correctamente categorías archivadas (RN-H03).

## Tareas de mantenimiento documentadas en CLAUDE.md

Las siguientes convenciones del v4 quedan en CLAUDE.md:

- **Contraconvención DV-5**: NO usar `state.invalidateAll()` en `tearDown` / `dispose` de tests. Solo `db.close()` es suficiente (drift cancela el upstream limpio). `invalidateAll()` queda como API runtime para `BackupService.wipeAll()` u otros callers que controlen el ciclo de vida del widget tree.
- Inmutabilidad de `account.type` como precondición de `invalidateAccount` (RF-015).
