# Pruebas — flutter-local-hardening-v2

Resumen de las pruebas ejecutadas durante la implementación. Cobertura por requisito en `test-plan.md` del plan.

## Pruebas automatizadas

- `flutter test` ejecutado al final de cada fase. Resultado al cierre: **91 tests verdes** (87 previos + 4 nuevos del sprint).
- `flutter analyze`: 0 errores. 6 hints `info` preexistentes (cosméticos `prefer_const_constructors` en `skeleton.dart:75`, `entry_form_screen.dart:271/273` y similares).

### Nuevos tests del sprint

1. **`backup_test.dart`** — `Import con name de 200 chars exactos pasa validación de longitud` (RF-003). Defiende el límite inclusivo.
2. **`financial_state_test.dart`** — `wipeAll invalida cache de streams (RF-004)`. Verifica que tras `BackupService.wipeAll()` la próxima suscripción crea un Stream nuevo (no la referencia cacheada).
3. **`database_test.dart`** — `watchPage no incluye badge para categorías archivadas (RF-005)`. Defensa contra la regresión del smoke del sprint anterior: el join filtra por `categories.deletedAt IS NULL` y la categoría archivada queda como `null` en el `WithCategory.category`.
4. **`financial_state_test.dart`** — `watchAccountBalance cacheado acepta múltiples suscriptores (RF-006)`. Suscribe 2 listeners simultáneos, dispara un evento y verifica que ambos reciben. Subcaso: cancela ambos, resuscribe a la misma key, dispara segundo evento y verifica que el listener nuevo recibe (broadcast sigue vivo).

## Pruebas manuales

- **Build APK release**: `flutter build apk --release --split-per-abi` corrido tras los bumps. Output verificado con `aapt2 dump badging app-arm64-v8a-release.apk`:
  - `versionCode='2033'`, `versionName='0.3.1'`, `minSdk=24`, `targetSdk=35`.

## Pruebas pendientes

- **T015 smoke en Redmi** (Diego). Detalle de checks en `pendientes.md`.
- **Test del timeout en `Share.shareXFiles`** (RF-010): no se cubrió con test unitario porque `share_plus` no expone API para mockear el sheet del sistema. Cubierto por revisión visual en T015.

## Riesgos residuales después de las pruebas

- El test de doble suscriptor (T007) pasa sin necesitar `onCancel`. Queda como riesgo latente si en el futuro algún caller cancela y resuscribe muy rápido y reaparece el `Bad state` del broadcast cerrado. Documentado en `pendientes.md`.
