# Implementation Review: flutter-local-hardening-v2

## Resumen de lo implementado

Sprint técnico de cierre del backlog no bloqueante que quedó en `pendientes.md` del sprint `flutter-local-hardening`. 13 RFs cubiertos, sin features visibles. Resultado: codebase con un broadcast stream defensivo, 4 tests nuevos que defienden contra regresiones detectadas en el smoke anterior, 3 microrefactors de robustez (snackbar foreground inyectado, timeout en share sheet, truncado grapheme-safe en mensajes de error), 1 sección nueva en `README.md` con la tabla de errores tipados del importador, 2 desviaciones menores documentadas y bump a `0.3.1+33`. 87 → 91 tests verdes.

## Archivos principales modificados

- `mobile/lib/data/database.dart` — registro de `daos: [AccountsDao, CategoriesDao]` en `@DriftDatabase`. `EntriesDao` queda fuera por constructor incompatible con codegen (ver desviaciones).
- `mobile/lib/data/database.g.dart` — regenerado.
- `mobile/lib/data/daos/entries_dao.dart` — query inline reemplazada por `attachedDatabase.categoriesDao.findActiveById(...)`.
- `mobile/lib/data/financial_state.dart` — `.asBroadcastStream()` aplicado al stream cacheado.
- `mobile/lib/data/backup.dart` — import de `characters` + truncados con `characters.take(N).toString()`.
- `mobile/lib/widgets/error_snackbar.dart` — `_buildFincoreSnackBar` recibe `foreground` como parámetro.
- `mobile/lib/screens/settings_screen.dart` — `Share.shareXFiles` envuelto con `.timeout(...)`.
- `mobile/pubspec.yaml`, `mobile/android/app/build.gradle.kts` — bump a `0.3.1+33`.
- `mobile/README.md` — nueva sección "Importar respaldos: límites y validaciones".
- `mobile/test/data/backup_test.dart`, `mobile/test/data/financial_state_test.dart`, `mobile/test/data/database_test.dart` — 4 tests defensivos nuevos.
- `engineering/specs/flutter-local-hardening/implementation/desviaciones-plan.md` — 2 desviaciones menores agregadas.
- `engineering/specs/flutter-local-hardening-v2/implementation/*` — artefactos de trazabilidad del sprint.

## Tareas completadas

- T001..T014, T016. Detalle en `progreso.md`.

## Tareas pendientes

- **T015 — Smoke manual (Diego)**. APK arm64 listo en `mobile/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`.

## Post-review

- **T017 — branch-quality-review** ejecutado. Reporte en `engineering/quality-review/flutter-local-hardening-v2/2026-06-19-1234-branch-quality-review.md`.
- 0 bloqueantes. 3 hallazgos `Media` (M1, M2, M3) **aplicados en sesión** (ver `desviaciones-plan.md` sección post-review).
- Hallazgos `Baja` diferidos: comentario defensivo en `@DriftDatabase`, `readsFrom: _db.accounts` opcional, timeout 2 min para evaluar tras smoke, contrastes WCAG de success/error (fuera de scope, levantar en sprint UX), validación de campos credit-only en cuentas no-credit (fuera de scope).

## Riesgos residuales

- `EntriesDao` no registrado en `@DriftDatabase`. Sin impacto funcional, pero deja una pequeña inconsistencia conceptual: dos DAOs accesibles por `attachedDatabase.xxxDao` y uno solo accesible vía `AppDependencies`. Documentado para que un futuro mantenedor no agregue `EntriesDao` y rompa el build.
- Broadcast stream sin `onCancel` (RF-002 quedó como condicional). T007 pasa sin él. Si patrones futuros de UI cancelan + resuscriban agresivamente, podría reaparecer el `Bad state`.
- Timeout en `Share.shareXFiles` está en 2 minutos. En el caso patológico (usuario abre share sheet, pulsa una app destino y la app se cuelga 2+ minutos sin volver), el flujo de export trata el timeout como cancelado: `_working = false` y mensaje "Exportación cancelada". El archivo temporal puede haber quedado en disco (`getTemporaryDirectory()`); el SO lo limpia eventualmente.

## Pruebas realizadas

- `flutter analyze`: 0 errores. 6 hints info preexistentes.
- `flutter test`: 91/91 verdes (4 nuevos: límite 200 chars exacto, wipeAll invalida cache, watchPage filtra archivadas, broadcast doble suscriptor).
- `flutter build apk --release --split-per-abi`: 3 APKs generados.
- `aapt2 dump badging app-arm64-v8a-release.apk`: confirma `versionCode='2033'`, `versionName='0.3.1'`.

## Pruebas recomendadas

- T015 smoke en Redmi (Diego). Checks completos en `pendientes.md`.
- En un sprint futuro, agregar widget test de bootstrap para `entry_form_screen` que cubra los 5 kinds.

## Posibles regresiones

- `attachedDatabase.categoriesDao` en `EntriesDao.updateEntry`: verifica que el código generado por drift respeta el comportamiento de la query previa (filtra por `c.id.equals(...) & c.deletedAt.isNull()`). El test `updateEntry con categoría heredada archivada limpia categoryId silenciosamente` del sprint anterior sigue verde.
- `.asBroadcastStream()` cambia la semántica del stream cacheado de single-listener a broadcast. T007 valida que múltiples StreamBuilders pueden suscribirse. Sin embargo, broadcast streams no replay el último valor a nuevos listeners — drift compensa porque al suscribirse internamente reemite el primer cómputo de `customSelect.watchSingle`. Si en un sprint futuro se agrega una pantalla que asume replay, hay que volver a evaluar.
- Cambio del foreground del snackbar: callers internos siguen pasando los colores estándar; no hay forma de que un caller externo dispare un foreground "incorrecto" porque los helpers públicos siguen siendo `showError/Success/WarningSnackbar`.

## Recomendaciones para code review humano

- Revisar el comentario explicativo en `mobile/lib/data/database.dart` cerca del `@DriftDatabase`: deja en claro por qué `EntriesDao` no se registra. Si en el futuro alguien intenta agregarlo y el build rompe, ese comentario debería evitarle el wild-goose chase.
- Verificar que el `aapt2 dump badging` se ejecuta sobre el APK arm64 correcto antes del sideload (Flutter prepende 2000 al versionCode para `--split-per-abi`).
- Confirmar que el bump a `0.3.1+33` se hizo en los 2 archivos (no solo en `pubspec.yaml`).
