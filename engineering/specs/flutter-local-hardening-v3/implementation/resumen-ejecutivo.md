# Resumen ejecutivo — flutter-local-hardening-v3

**Status:** sprint cerrado, APK `0.3.7+39` validado por `scripts/verify-apk.sh`, suite de tests **110/110 verde** (de 93 iniciales, +17 tests nuevos).

## Qué entregó el sprint

- **Harness de widget tests** reusable (`mobile/test/helpers/widget_test_harness.dart`) para todos los sprints futuros de UI.
- **Widget test del flujo cancel + submit en modo edit** que blinda la regresión del "gray screen" que el smoke del v2 detectó tarde.
- **Widget tests T043-T045 del MVP** (dashboard, entry_form para los 5 kinds, listas de accounts/categories): 11 tests nuevos.
- **Script `scripts/verify-apk.sh`** que detecta `INSTALL_FAILED_VERSION_DOWNGRADE` antes del sideload, comparando `versionCode` del APK (con prefix 2000 del `--split-per-abi` arm64) contra el `+N` esperado por `pubspec.yaml`.
- **Test defensivo del cache de streams** (`RF-012 v3`) que blinda la decisión consciente del v2 de no liberar el cache al perder el último listener.
- **Bump a 0.3.7+39** y APK release listo para sideload.

## Qué se decidió diferir / no implementar

- **`onLastListenerCanceled` en `_ReplayBalanceStream`** (RF-010/RF-011 del plan): NO implementado. Contradecía una decisión razonada del v2 (post-bug "Skeleton eterno"). Ver `desviaciones-plan.md` DV-1. El test RF-012 blinda la decisión.
- **Registrar `EntriesDao` en `@DriftDatabase(daos: [...])`**: fuera de scope desde el inicio (acordado con Diego). Sigue diferido.

## Métricas

| Métrica | Antes | Después | Δ |
|---------|-------|---------|---|
| Tests automatizados | 93 | 110 | +17 (+18.3 %) |
| Cobertura de capa UI | 0 widget tests | 16 widget tests | nuevo |
| `flutter analyze` errores | 0 | 0 | = |
| `flutter analyze` warnings | 1 (preexistente) | 0 | −1 (limpieza oportunista) |
| Hints info preexistentes | 4 | 4 | = |
| Versión APK | 0.3.6+38 | 0.3.7+39 | +1 patch |
| Tiempo de detección de `INSTALL_FAILED_VERSION_DOWNGRADE` | "tras adb install -r fallido" | "antes del adb install" | tooling |

## Riesgos cubiertos

- **Regresión gray screen en `entry_form_screen`**: blindada por widget tests (cancel + submit en edit). Si vuelve a aparecer, falla la suite.
- **Refactor del KindPicker o AccountPicker rompe RN-011**: cubierto por los 5 tests de `entry_form_kinds_test.dart` (uno por kind).
- **Olvido de bumpear `versionCode` antes del build**: detectado automáticamente por `scripts/verify-apk.sh`.
- **Reintroducción accidental de `onLastListenerCanceled`**: falla el test RF-012 con un mensaje explícito.

## Próximo paso natural

Sprint de features. El backlog sugiere **reportes** (cashflow mensual, gasto por categoría). Antes de planear, definir la filosofía del balance derivado: el `FinancialStateService` actual agrega totales sin filtro de fecha; en reportes hay que decidir si los cortes son "hasta hoy" o por rango. Esa decisión va en `spec.md` del sprint siguiente.
