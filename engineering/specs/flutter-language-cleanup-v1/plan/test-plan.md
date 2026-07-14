# Test plan — flutter-language-cleanup-v1

## Casos borde detectados

Los 10 bordes de la spec + adicionales del planeamiento:

- **B-01**: `\bacá\b` no debe matchear `académico`, `acatar`, `acabaste`, etc. Verificar con regex `\b...\b` estricto.
- **B-02**: `\btenés\b` no debe matchear apellidos (Menéndez, Fernández, etc.) — la palabra tiene tilde solo en la última sílaba `és`, apellidos usualmente no.
- **B-03**: strings en tests que verifican identidad literal — improbable en este sprint pero verificar.
- **B-04**: el propio archivo del guardrail contiene la regex del voseo — auto-referencia. Excluir por path en el scan.
- **B-05**: si el guardrail se ejecuta sobre `lib/` completo, incluye `lib/data/database.g.dart` (generado por drift). Debe excluirlo por sufijo `.g.dart`.
- **B-06**: el guardrail debe ser rápido (&lt;500ms). Si es lento, cachear o lazy.
- **B-07**: strings duplicadas — cambiar en los 2 sitios.
- **B-08**: comentarios de bitácora en `pubspec.yaml` con voseo antiguo — NO modificar.
- **B-09**: onboarding slide 2 — verificar si "Registrá cada movimiento" es copy real o solo comentario.
- **B-10**: strings alargadas por reemplazo — validar layout en 360dp.
- **B-11**: los tests de integration_test pueden estar apuntando a copy inexistente en la app — el update del matcher puede requerir consulta con AccountsDao/CategoriesDao para saber qué string real se muestra.

## Pruebas unitarias necesarias

- **UT-01**: `mobile/test/language/no_voseo_test.dart` — nuevo:
  - `it('detecta voseo en un archivo con la palabra "pagás"', ...)` — con archivo fixture temporal.
  - `it('no detecta falsos positivos en palabras que contienen sufijo pero no son voseo', ...)` — testa que `académico` no matcheе.
  - `it('escanea todo lib/ y reporta cero matches en el estado actual', ...)` — el test real que corre en cada `flutter test`.
  - `it('excluye .g.dart y a sí mismo del scan', ...)` — validar exclusiones.

## Pruebas de integracion o API necesarias

- **IT-01**: correr los 5 tests afectados en `integration_test/account_form_test.dart` + `category_form_test.dart` en emulador o dispositivo. Si el harness lo permite, correr solo esos con `flutter test integration_test/account_form_test.dart integration_test/category_form_test.dart`. Verificar que pasan con el nuevo copy neutral.

## Pruebas de UI o flujo necesarias si aplica

No aplica (sprint sin refactor de widgets; solo cambia texto de strings).

## Pruebas de permisos y seguridad si aplica

No aplica.

## Pruebas de datos, migracion o compatibilidad si aplica

No aplica.

## Pruebas de regresion sobre flujos existentes

- **REG-01**: `flutter test` completo (680 tests previos) sigue en verde. Ningún matcher de widget test debería estar apuntando a las strings voseadas que se cambiaron — si alguno lo está, actualizar (documentar).

## Pruebas manuales o smoke tests necesarios

- **SM-01**: `flutter run -d linux` — navegar a Entries y verificar el empty state con filtros activos. Debe decir "Ajusta los filtros o cambia el rango." (no "Probá ajustarlos.").
- **SM-02**: intentar guardar una vista sin filtros → snackbar "Configura al menos un filtro antes de guardar.".
- **SM-03**: Settings → Ayuda → ver "FAQ sobre tipos de movimientos, reportes, presupuestos y respaldo." (no "FAQ sobre kinds").
- **SM-04**: crear un movimiento kind=Pago de tarjeta → label del origen dice "Pago desde" (no "Pagás desde").
- **SM-05**: Reports → Monthly Average sin data → mensaje "Se necesita al menos 1 mes cerrado…".
- **SM-06 (Android en 360dp)**: verificar que los strings alargados (`Ajusta los filtros o cambia el rango.` y `Reducir el rango de filtros para ver movimientos más antiguos.`) no causan wrap o ellipsis raro.

## Datos de prueba recomendados

- BD real de Diego (para smoke).
- BD limpia con solo la Bolsa + 1-2 categorías para reproducir empty states.

## Comandos o validaciones locales sugeridas

```bash
cd mobile

# Análisis estático
flutter analyze

# Suite completa (esperado 681+)
flutter test

# Solo el guardrail nuevo
flutter test test/language/no_voseo_test.dart

# Verificación mecánica (esperado 0)
grep -rnE '\b(pagás|configurá|probá|acotá|poné|tocá|ingresá|guardá|elegí|hacé|deslizá|necesitás|registrá|querés|tenés|podés|acá|allá|andá|seteás|fijate|dale)\b' lib/ --include='*.dart' | grep -v '\.g\.dart'

# Verificación de "kinds" en copy visible
grep -n "kinds" lib/screens/settings_screen.dart

# Build
flutter build apk --release --split-per-abi
```

## Criterios minimos para aprobar la implementacion

- `grep` de voseo en `lib/`: **0 resultados** (excepto guardrail auto-referencial).
- `grep` de "kinds" en `settings_screen.dart`: 0 en línea de copy visible.
- `flutter analyze`: 0 errores.
- `flutter test`: 681+ verdes (680 previos + guardrail).
- Smoke SM-01 a SM-05 desktop sin regresión visual.
- Smoke SM-06 Android sin wrap/ellipsis inesperado en las 2 strings alargadas.
- `CLAUDE.md` con la convención documentada.

## Validacion final recomendada

Si `branch-quality-review` está disponible, ejecutar al cierre. Reporte en `engineering/quality-review/flutter-language-cleanup-v1/`.

Si no está disponible, revisión manual equivalente:
- Diff completo del sprint archivo por archivo.
- Los `grep` de guardrails en verde.
- Confirmación con Diego de que ningún copy suena raro tras el cambio.
