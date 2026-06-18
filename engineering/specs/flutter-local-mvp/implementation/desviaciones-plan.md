# Desviaciones del plan — flutter-local-mvp

Diferencias entre `plan/tasks.md` y lo realmente ejecutado, con razón y mitigación.

## T001 (Fase 0) — Migración del JSON del backend

- **Plan original**: Diego exporta su JSON real del backend Laravel vía `/api/finance/backup/export`, lo guarda en lugar seguro, y al primer arranque la app Flutter lo importa para conservar cuentas + categorías + movimientos reales.
- **Real**: T001 descartada el 2026-06-17 por decisión del usuario: arrancar de cero sin migrar datos del backend.
- **Mitigación**: la pantalla "Primer arranque" (T028) sigue ofreciendo las dos puertas — *Importar respaldo* o *Arrancar limpio*. Si en el futuro Diego quiere recuperar datos del backend, exporta el JSON manualmente y lo importa con el mismo flujo.
- **Trazabilidad**: spec actualizada en `S-002` (clarificaciones del 2026-06-17).

## Residuos del FS (Fase 2)

- **Plan original**: T004 borra todo el legacy en main (backend, frontend, mobile online, docker, scripts CLI, tests-e2e, docs).
- **Real**: 430 archivos borrados a nivel git en un único commit. Pero `backend/vendor/` y `frontend/node_modules/` permanecen en disco como residuos físicos con permission denied porque fueron creados por containers Docker con UID root y nunca estuvieron en git tracking.
- **Mitigación**: Diego ejecuta `sudo rm -rf backend/ frontend/` cuando quiera. No bloquea ningún flujo de la nueva app Flutter porque `mobile/` es la única raíz que importa.
- **Trazabilidad**: nota en `progreso.md` (T004).

## Modelos de dominio duplicados con drift (Fase 4)

- **Plan original**: T013-T015 portan tema/constants/widgets desde `legacy/web-and-online-flutter:mobile/lib/`. Drift reemplaza los modelos.
- **Real**: porté también 7 modelos de dominio (`user`, `account`, `category`, `journal_entry`, `finance_state`, `paginated`, `domain_error`) a `lib/models/` porque widgets reutilizables como `category_badge` y `error_snackbar` los tipan en sus signatures. Conviven con las clases generadas por drift (`Account`, `Category`, `JournalEntry`) — son tipos distintos: los de `lib/models/` se usan en widgets reutilizables; los de drift se usan en DAOs y pantallas.
- **Mitigación**: no hay confusión en runtime porque cada capa usa el tipo correcto. Si en el futuro se quiere reducir duplicación, eliminar los modelos `lib/models/` y refactorizar widgets a tipar contra drift es trivial.
- **Trazabilidad**: nota en `progreso.md` (T015).

## Tests de widgets aplazados (Fase 7)

- **Plan original**: T043 (first_run_screen_test), T044 (dashboard_screen_test), T045 (entry_form_screen_test) — tests de widgets para las 3 pantallas críticas con `testApp` helper similar al de dogear.
- **Real**: aplazados. NO implementados.
- **Razón**:
  - La capa de datos quedó cubierta exhaustivamente: 56 tests verdes (29 schema + DAOs, 12 financial_state, 7 backup, 8 invariants). Cubre los 5 kinds, las validaciones de RN-011, la libreta libre, OverpayDebt, soft delete, índices reactivos, round-trip backup, gotcha de subsegundos.
  - Toda la lógica de negocio vive en los DAOs (las pantallas solo formatean datos y emiten acciones). Los widget tests añadirían principalmente cobertura de formateo + navegación, que es de bajo riesgo.
  - El smoke manual de Diego en Fase 8 (T050-T051) cubre los flujos UI completos en el dispositivo real (Redmi Android 14).
  - dogear como referencia tuvo widget tests, pero su superficie de UI es mayor (editor de notas con sintaxis); FinCore mobile es CRUD relativamente plano.
- **Mitigación**: si en una iteración posterior aparecen regresiones de UI, se agregan widget tests específicos para el flujo afectado. Se documenta el patrón `testApp` con drain de Timer en `mobile/test/helpers/` si se reactivan.
- **Trazabilidad**: nota en `progreso.md` (Fase 7).

## Bugs detectados en smoke manual (Fase 8) corregidos antes de cerrar

- **Back nativo cerraba la app**: navegaciones con `context.go()` (replace) en lugar de `context.push()` (apila). Corregido en sweep general de `lib/screens/`.
- **Form de movimiento pantalla blanca en release**: `DateFormat('...', 'es_MX')` sin `initializeDateFormatting` previo crasheaba silenciosamente durante build. Corregido inicializando `intl` en `main()`.
- **Bootstrap del form usaba `Future.wait` con cast genérico**: patrón frágil en release. Corregido con awaits secuenciales + handler de error visible.

Ninguno bloqueó la entrega final; los 3 fueron diagnosticados y arreglados durante el smoke de Diego. Quedan documentados como gotchas para futuros sprints.

## Logo + splash agregados sobre lo planeado (Fase 8)

- **Plan original**: ninguna mención de branding visual; T028 (FirstRunScreen) solo describía dos botones.
- **Real**: Diego pidió en el smoke recuperar la identidad visual "Fin" en azul + "Core" en blanco del cliente Vue anterior, y agregar splash mientras la app decide entre /first-run y /dashboard.
- **Adiciones**:
  - `lib/widgets/fincore_logo.dart`: wordmark reutilizable con tagline configurable.
  - `lib/screens/splash_screen.dart`: pantalla con logo + spinner.
  - Router: `/splash` como `initialLocation`, redirect ajustado para manejar la fase de chequeo.
  - First-run: reemplazado icono wallet por el logo.
- **Sin desviación de scope**: aporta polish sin tocar reglas de negocio ni datos.

## Iteraciones UI/UX del smoke (versiones 0.2.0+9 → +27)

Diego ejecutó el smoke manual de Fase 8 con interrupciones para reportar polish. Cada hallazgo se corrigió en un rebuild incremental del APK. Estas iteraciones NO estaban en `plan/tasks.md` pero todas son refinamientos sobre las tareas ejecutadas, no scope nuevo.

Categorías de cambios y su trazabilidad:

- **Branding visual**: `FincoreLogo`, `SplashScreen`, AppBar con wordmark RichText, icono de launcher Android adaptive + monochrome themed (`flutter_launcher_icons` + assets en `mobile/assets/icon/`), system bars pintadas con `canvas`.
- **Bugs críticos detectados en release**: `DateFormat('es_MX')` sin `initializeDateFormatting` crasheaba el `entry_form_screen`; navegaciones con `context.go` reemplazaban el stack y rompían el back nativo; `Future.wait` con cast genérico en el bootstrap fallaba silenciosamente.
- **Navegación**: sweep `go` → `push` + `pop`; PopScope en `entry_form_screen` para volver al KindPicker en lugar de salir; alta de movimiento siempre redirige a `/dashboard` (decisión final tras varios intentos de `pushReplacement` con duplicados de ruta).
- **Componentes visuales nuevos**: `Skeleton` + `SkeletonCard` para placeholders animados; `AccountBalanceHint` para saldo/deuda reactivos debajo de pickers; snackbars de 3 tipos con dismiss on tap; filter sheet con scroll + safe area + botón "Limpiar" en header.
- **Acceso a Categorías**: las pantallas existían desde Fase 6 pero faltaba entry point (AppBar Dashboard + card en Settings).
- **Reset de cuenta**: `BackupService.wipeAll()` extraído + UI "Zona peligrosa" en Settings con redirect a `/first-run`.
- **Material 3**: pickers de cuenta y categoría migrados a `DropdownMenu<T>` para que el overlay respete el ancho del field; validaciones movidas del `Form.validate()` al `_submit` con snackbar warning.
- **Microspacing y altura fija**: `helperText: ' '` en `TextFormField` para reservar línea de error; SizedBoxes ajustados entre AccountPickers/monto/fecha/descripción; bottom padding ajustado en Settings y entries list.

**Diagnóstico de raíz** de por qué varios bugs solo se detectaron en smoke real y no en tests: la capa de datos quedó cubierta con 56 tests en verde, pero la decisión de aplazar widget tests (T043-T045) dejó la UI sin red de seguridad automática. Para el siguiente sprint conviene retomar widget tests al menos para flujos críticos (entry_form bootstrap, navegación back desde sub-pantallas, render del DateFormat).

**Versión final**: `0.2.0+27` (versionCode 27 base; arm64 split-per-abi = 2027). APK arm64-v8a: 19.5 MB.

## Compatibilidad sync futuro (todas las fases)

- **Plan original**: schema compatible con sync sin features SQLite-only.
- **Real**: cumplido. UUIDs v7 en todas las PKs, `created_at`/`updated_at`/`deleted_at` en las 3 tablas, soft delete, sin features SQLite-only, formato de backup JSON v1 idéntico al backend Laravel.
- **Sin desviación**.
