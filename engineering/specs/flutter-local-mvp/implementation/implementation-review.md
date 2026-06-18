# Implementation Review: flutter-local-mvp

## Resumen de lo implementado

Pivote de FinCore de cliente Flutter online sobre backend Laravel + Vue + Tailscale a **app Flutter Android local-first single-user**. Mismo modelo que dogear: SQLite con drift como única fuente de verdad, sin red en runtime, sin login, schema compatible con sync futuro (UUIDs v7, soft delete, timestamps). Pantalla "Primer arranque" con dos puertas (Importar respaldo / Arrancar limpio). Respaldo JSON v1 compatible bit a bit con `/api/finance/backup/export` del backend legacy. APK release 19.5 MB instalado en Redmi de Diego y validado en smoke completo.

## Archivos principales modificados

- **Capa de datos**: `mobile/lib/data/database.dart`, `lib/data/uuid.dart`, `lib/data/daos/{accounts,categories,entries}_dao.dart`, `lib/data/financial_state.dart`, `lib/data/seed.dart`, `lib/data/bootstrap.dart`, `lib/data/backup.dart`.
- **Pantallas**: `lib/screens/{splash,first_run,dashboard,accounts_list,account_form,categories_list,category_form,entries_list,entry_form,settings}_screen.dart`.
- **Widgets**: `lib/widgets/{fincore_logo,account_picker,category_picker,account_balance_hint,skeleton,error_snackbar,kind_picker,confirm_dialog,base_card,amount_formatter,category_badge,...}.dart`.
- **Infra**: `lib/main.dart`, `lib/app_dependencies.dart`, `lib/router/app_router.dart`.
- **Android**: `android/app/build.gradle.kts`, `android/app/src/main/AndroidManifest.xml`, `android/app/src/main/res/mipmap-*/ic_launcher*`, `android/app/src/main/res/drawable-*/ic_launcher_foreground.png`.
- **Config**: `pubspec.yaml`, `build.yaml`, `analysis_options.yaml`, `assets/icon/`.
- **Tests**: `test/data/{database,financial_state,backup,invariants}_test.dart`, `test/helpers/sqlite_override.dart`.
- **Repo root**: `CLAUDE.md`, `README.md`, `.gitignore`.
- **Specs**: `engineering/specs/flutter-local-mvp/implementation/{progreso,desviaciones-plan,resumen-ejecutivo,resumen-extenso,pendientes,implementation-review}.md`.

## Tareas completadas

T002-T012 (preserve legacy + destrucción + fundación), T013-T015 (portado), T016-T025 (capa de datos), T026-T036 (router + pantallas), T037-T042 + T046-T047 (tests + analyze), T048-T051 (build + smoke Diego), T052-T054 (docs), T055 (branch-quality-review).

## Tareas pendientes

- **T043-T045 widget tests**: aplazados deliberadamente. Justificación en `desviaciones-plan.md`. Quedan en `pendientes.md` como ítem de próximo sprint.

## Riesgos residuales

- **UI sin red de seguridad automática**: 3 bugs críticos detectados solo en smoke real (DateFormat, navegación, snackbar dismiss). Una regresión futura requeriría smoke completo.
- **`schemaVersion = 1`** sin `onUpgrade` implementado. Cuando se agreguen tablas/columnas, hay que implementarlo y validar import de respaldos JSON v1 anteriores.
- **APK firmado con clave debug**: suficiente para sideload, no para Play Store.
- **Reset de cuenta no exporta backup automáticamente**: si Diego borra todo sin haber exportado antes, perdió los datos. La UI advierte pero no fuerza.

## Pruebas realizadas

- `flutter test`: **56 tests verdes** (29 database + 12 financial_state + 7 backup + 8 invariants).
- `flutter analyze`: 0 errores, 0 warnings (1 hint cosmético no bloqueante).
- Smoke manual Diego en Redmi (Android 14): primer arranque, los 5 kinds, edición, cancelación, modo avión, export/import round-trip, reset de cuenta. 17 ajustes UX iterativos aplicados durante el smoke.
- Branch-quality-review (`engineering/quality-review/flutter-local-mvp/`).

## Pruebas recomendadas

- Widget tests para `entry_form_screen` bootstrap (DateFormat + pickers).
- Widget test para back nativo desde sub-pantallas (PopScope).
- Widget test del filter sheet (scroll + safe area + botones visibles).
- Integration test del flujo end-to-end first-run → alta → export → import.

## Posibles regresiones

- **Drift cache invalidation**: si se modifica el SQL crudo de `financial_state.dart` sin actualizar `readsFrom: {accounts, journalEntries}`, drift no invalidará cache y saldos quedarán stale.
- **`store_date_time_values_as_text: true`**: cambiar este flag rompe round-trip de respaldos exportados antes.
- **Aporta del `kind` inmutable**: si en un futuro se habilita edición del `kind` sin revalidar origen/destino/categoría, el contrato del DAO se rompe.
- **Navegación con `go_router`**: el sweep `go → push/pop` no cubre rutas que se agreguen en el futuro. Convención: `push` para abrir sub-pantallas, `pop` para volver, `go` solo para resets de stack intencionales (first-run completo, alta de movimiento → dashboard).

## Recomendaciones para code review humano

1. **Verificar el flujo del icono adaptive en Android 13+**: el `monochrome_1024.png` debería pintarse con el color del wallpaper cuando el usuario activa "Iconos temáticos" en Settings de Android. Confirmar visualmente.
2. **Auditar la lógica de `FirstRunState`**: hoy `value` es `bool?` con tres estados (null = chequeando, true = hay Bolsa, false = no). El reset de cuenta hace `value = false` para disparar el redirect. Confirmar que no haya race entre el `wipeAll()` y el redirect.
3. **Validar `BackupService.importFromJson` contra payloads del backend real**: los tests usan payloads sintéticos. Diego debería intentar importar un JSON exportado del backend legacy de su instancia productiva (que sigue arriba en `legacy/web-and-online-flutter`) para confirmar round-trip real.
4. **Revisar `useSafeArea: true` en el filter sheet**: en cels con gestos en lugar de botones, el comportamiento puede variar. Validar en otro device si se distribuye más allá del Redmi.
5. **Validar el reset de cuenta como flujo end-to-end**: tras reset, ¿la BD queda en estado idéntico a primera instalación? El test cubre la lógica del DAO pero no el handoff con el router.
6. **Confirmar que `kAppVersion` en `settings_screen.dart` matchea con `pubspec.yaml`**: hoy es manual (`'0.2.0+7'` hardcoded, debería ser `'0.2.0+27'`). Refactor a `package_info_plus` pendiente.
