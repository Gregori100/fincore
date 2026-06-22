# Pendientes — flutter-local-hardening-v3

Trabajo no terminado al cierre del sprint o diferido a sprints futuros.

## Pendientes inmediatos

- **Smoke manual del 0.3.7+39 en el Redmi** (T020): Diego confirma que el APK arm64 instala limpio, abre, Settings → "Acerca de" muestra `0.3.7+39` y que los flujos críticos cubiertos por los nuevos widget tests (cancel + submit en edit, listas, dashboard) siguen verdes en la app real. Si aparece algún glitch, documentar como desviación post-smoke.

## Diferidos del quality review v3 (2026-06-22)

Hallazgos del `branch-quality-review` que no se aplicaron in-sprint. Detalle completo en `engineering/quality-review/flutter-local-hardening-v3/2026-06-22-1233-branch-quality-review.md`. Severidad y nomenclatura van con el ID del reporte.

- **L2-H1 (Media) — `watchBo/De/Cr` sin replay-1**: las tres cards superiores del Dashboard (`watchBo`, `watchDe`, `watchCr`) NO usan `_ReplayBalanceStream`. El mismo bug latente "Skeleton eterno" aplica si el stack se resetea con `context.go('/dashboard')`. Mitigación recomendada: envolver cada `customSelect.watchSingle()` en un `_ReplayBalanceStream` (sin cache de cuenta — pueden ser standalone). Atacar como primera tarea del sprint de reportes o como sprint dedicado `flutter-local-hardening-v4`. Riesgo hoy: bajo, porque el `pop` desde `entry_form` no desmonta el Dashboard (la regresión gray screen del v2 era `_BalanceLabel`, no las cards de totales).
- **L1-H1 (Media) — `_localeInitialized` no concurrency-safe**: la variable global se setea tras `await`. Riesgo solo si en el futuro se habilita scheduler multi-isolate paralelo dentro del mismo proceso. Atacar cuando aparezca el escenario.
- **L1-H2 (Media) — rama `/first-run` + `seedBolsa=true` ambigua**: ningún test la ejercita. Documentar o `assert` cuando se necesite.
- **L1-H3 (Media) — gap de cobertura RN-011 en kinds**: los 5 tests del `entry_form_kinds_test.dart` validan labels pero NO el contenido del Dropdown del `AccountPicker`. Si alguien rompe `allowedTypes` y deja Visa visible en un Ingreso, los tests no lo detectan. Agregar `tester.tap(label) → verificar items del dropdown` por kind. ~30 min por test.
- **L1-H4 (Baja) — matcher `find.widgetWithText(TextFormField, '150.0')` frágil**: depende del formato textual del monto. Reemplazar por `Key` o `tester.getEditableText` cuando se agreguen más tests del entry_form.
- **L1-H5 (Baja) — `dynamic router` en harness**: desactiva análisis estático del campo. Importar `go_router` con `show GoRouter` para tipar.
- **L1-H6 (Baja) — `Future.delayed` en `financial_state_test`**: patrón heredado del v2. Migrar a `expectLater(stream, emits(...))` cuando se ataque la suite por completo.
- **L1-H7 (Baja) — `harness.dispose()` race**: solo cierra DB sin desmontar tree. Si un test falla, cleanup queda frágil.
- **L2-H3 (Baja) — `addSync` sobre controller cerrado**: teórico. Agregar guard `if (!controller.hasListener) continue;` cuando se reescriba el dispatch.
- **L2-H4 (Baja) — documentar inmutabilidad de `account.type`**: comentario 1-línea en `_balanceCache`. Va junto con L2-H1.
- **L3-H2 (Baja) — paths con espacios en `verify-apk.sh`**: Linux desktop no aplica. Atacar si se portea a macOS.
- **L3-H4 / L3-H5 (Baja) — edge cases improbables**: comillas en `pubspec.yaml`, comillas dobles en aapt2 pre-30. No aplica al setup actual.

## Diferidos a sprints futuros (no urgentes)

- **Registrar `EntriesDao` en `@DriftDatabase(daos: [...])`**: queda explícitamente fuera del scope del v3, según se acordó con Diego al planear el sprint. Bloqueado por el constructor de `EntriesDao` que requiere `FinancialStateService` (drift codegen solo sabe inyectar el database). Implica invertir la dependencia (`FinancialStateService` como campo del database, lazy-resolver, o moverlo a service locator) y tocar mucho código por ganancia cosmética. Se evaluará en un sprint dedicado si surge necesidad real (ej. duplicación residual de queries, o que `EntriesDao` necesite ser instanciado por drift por otro motivo).

- **Widget tests más profundos del CRUD**: los tests del v3 cubren el bootstrap (render + un tap al form de edición) según el alcance original del MVP (T043-T045). Quedan sin cobertura:
  - El flujo `accounts_list → new account → CRUD completo` con validaciones del DAO.
  - El flujo `entries_list → bottom sheet de filtros → aplica filtro → resultado` (el bottom sheet usa safe area y tiene comportamiento de tap-outside que merece su propio test).
  - El form de category con preview live del badge.
  - Confirmación destructiva en Settings → reset (Export then reset).

  Si en el futuro un sprint de features de UI introduce regresiones en esos flujos, agregar widget tests específicos. El harness `pumpFincoreApp` ya está disponible y son ~30 min cada test marginal.

- **Validación end-to-end del `verify-apk.sh` en CI**: hoy se ejecuta manualmente post-build. Si se monta CI con GitHub Actions (cuando se decida publicar a Play Store), agregar como step pre-release.

- **Test del `verify-apk.sh` con `aapt2` ausente**: el script tira exit 2 en ese caso. No tiene cobertura automatizada porque requeriría un mock del PATH y de `~/Android/Sdk/build-tools/`. Validado manualmente durante implementación.

- **Loader de progreso en el `pumpAndSettle` del harness para tests lentos**: algunos tests con `pumpAndSettle()` toman >1s. Si la suite crece a 200+ widget tests y el wallclock se vuelve incómodo, considerar `tester.runAsync` con timeouts específicos o paralelización con `flutter test --concurrency=N`.

- **Reconciliar `_typeLabel('cash')` duplicando "Bolsa" como hint del tipo**: cosmético, pero los tests tuvieron que usar `findsNWidgets(2)`. Si en un futuro la pantalla cambia a un layout más limpio (ej. icono del tipo en lugar de texto), revisar y ajustar los matchers a `findsOneWidget`.
