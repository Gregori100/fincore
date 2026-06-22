# Pruebas — flutter-local-hardening-v4

## Resultado final

```
flutter test     → 112/112 verdes (de 110 iniciales, +2 nuevos de v4)
flutter analyze  → 0 errores, 0 warnings, 4 hints info preexistentes
scripts/verify-apk.sh app-arm64-v8a-release.apk → exit 0 (versionCode=2040)
```

## Matriz de cobertura

| RF | Archivo | Tests nuevos | Estado |
|----|---------|--------------|--------|
| RF-001 a RF-006 | (refactor, sin tests nuevos) | — | ✅ |
| RF-007 a RF-009 | `test/data/financial_state_test.dart` | 2 | ✅ |
| RF-010 a RF-018 | (refactor + tooling, sin tests nuevos) | — | ✅ con descarte RF-014 |
| RF-019 | (diferido) | — | desviación DV-1 |
| RF-020 a RF-023 | (diferido) | — | desviación DV-2 |
| RF-024 a RF-025 | (release) | — | ✅ |

**Tests nuevos automatizados:** **2** (`RF-009 v4` + `RF-008 v4` en `financial_state_test.dart`).

**Total suite:** 110 (v3) + 2 (v4) = **112 verdes**.

## Cobertura por capa

### Capa de datos

| Suite | Tests v3 | Tests v4 | Cambio v4 |
|-------|----------|----------|-----------|
| `database_test.dart` | 30 | 30 | tearDown agrega `state.invalidateAll()` (DV-5) |
| `financial_state_test.dart` | 22 | 24 | +2 nuevos (RF-008/009) + tearDown fix |
| `backup_test.dart` | 8 | 8 | tearDown fix |
| `invariants_test.dart` | 8 | 8 | tearDown fix |
| **subtotal capa datos** | **68** | **70** | +2 |

### Capa de presentación

| Suite | Tests v3 | Tests v4 | Cambio v4 |
|-------|----------|----------|-----------|
| `helpers/widget_test_harness_test.dart` | 3 | 3 | dispose() agrega `state.invalidateAll()` |
| `screens/entry_form_screen_test.dart` | 2 | 2 | matcher robusto (RF-012) |
| `screens/dashboard_screen_test.dart` | 2 | 2 | — |
| `screens/entry_form_kinds_test.dart` | 5 | 5 | RF-019 intentado y revertido (DV-1) |
| `screens/list_screens_test.dart` | 4 | 4 | — |
| **subtotal capa UI** | **16** | **16** | sin cambios netos |

**Total suite v4:** 70 + 16 + 26 (tests del package no del proyecto) = **112 verdes**.

## Tiempo de ejecución

| Estado | Tiempo |
|--------|--------|
| Con `state.invalidateAll()` en harness.dispose() (falso fix DV-5) | >40 minutos (timeout, tests "did not complete") |
| Sin `state.invalidateAll()` en cleanup (fix correcto DV-5) | **6-12 segundos** |

## Smoke manual (Diego, post-merge)

Mínimo a validar:

1. `scripts/verify-apk.sh mobile/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` → exit 0.
2. `adb install -r build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` succeed sobre 0.3.7+39.
3. App abre, Dashboard renderea las cards BO/DE/CR (no debe haber Skeleton eterno tras RF-007 v4).
4. Settings → "Acerca de" muestra `0.3.8+40`.
5. Spot check: registrar movimiento `debt_payment` (que ahora usa `accountBalanceAtomic` función pura) → OverpayDebt sigue funcionando.

El smoke completo del v3 ya quedó blindado por los widget tests (cancel + submit en edit, dashboard, listas, 5 kinds). El v4 solo introduce cambios estructurales que no alteran la UX visible.

## Validación específica del refactor de Fase 1

Para confirmar que el codegen del `EntriesDao` no rompe nada en runtime, se valida:

- `database.entriesDao` accesible desde `AppDependencies.fromDatabase` (verificado por la suite que pasa).
- `attachedDatabase.entriesDao` accesible desde otros DAOs cuando se necesite (no se usa hoy, pero el patrón es consistente con `accountsDao` y `categoriesDao`).
- `EntriesDao.registerDebtPayment` con `accountBalanceAtomic(attachedDatabase, ...)` mantiene la semántica de OverpayDebt: el test del MVP `OverpayDebt: pagar más de lo que debés se rechaza` sigue verde.

## Validación específica del RF-007 (replay-1 en BO/DE/CR)

- `RF-009 v4`: `identical(state.watchBo(), state.watchBo()) == true`. El cache devuelve el mismo Stream identitariamente.
- `RF-009 v4`: tras `subscribe → cancel → re-subscribe`, el listener nuevo recibe el último valor por replay-1 (sin esperar otro cambio).
- `RF-008 v4`: tras `state.invalidateAll()`, una nueva llamada a `watchBo()` arma un Stream nuevo (no es identitario al anterior).

## Validación del verify-apk.sh tras RF-016/017/018

Ejecutado contra el APK `0.3.8+40` recién construido:

```
$ scripts/verify-apk.sh
APK:           /home/developer/.../app-arm64-v8a-release.apk
aapt2:         /home/developer/Android/Sdk/build-tools/36.0.0/aapt2
pubspec:       0.3.8+40 (esperado APK code: 2040)
APK detectado: 0.3.8 (2040)

✓ OK — versionCode 2040 / versionName 0.3.8 consistentes.
```

Validación de mismatch artificial (alterar pubspec a `+41` con APK en `+40`): script detecta mismatch y exit 1.

## Validación negativa de la regresión DV-5

Para confirmar que el fix correcto sigue siendo: si se vuelve a agregar `state.invalidateAll()` en el `dispose()` del `FincoreTestHarness`, los widget tests cuelgan `pumpAndSettle` indefinidamente. Reproducible.
