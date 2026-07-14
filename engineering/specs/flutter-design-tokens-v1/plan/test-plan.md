# Test plan — flutter-design-tokens-v1

## Casos borde detectados

Además de los 15 casos borde documentados en `spec.md`:

- **B-01**: widgets migrados que son consumidos por muchas screens (`base_card`, `movement_row`, `error_snackbar`, `skeleton`) generan cambios en cascada. Aunque el sprint no toca screens, un cambio sub-perceptible en `BaseCard` afecta ~63 usos. Requiere smoke visual en las pantallas principales.
- **B-02**: `Skeleton` con `kMotionPulse = 1100ms` puede colgar `pumpAndSettle` en tests. Verificar todos los tests que usen skeletons.
- **B-03**: widgets que consumen `Theme.of(context).textTheme.bodyMedium` esperan hoy defaults M3 (14pt, w400, color heredado). Al cablear con el token `bodyM` (14pt, w400, color explícito `textPrimary`), un widget que dependía del color heredado del `DefaultTextStyle` puede cambiar visualmente. Grep `DefaultTextStyle` para localizar.
- **B-04**: `AmountFormatter` probablemente devuelve `String`, no widget con estilo. Verificar; si es puro string, no requiere migración.
- **B-05**: `FincoreLogo` con `fontSize` proporcional queda como excepción. Verificar que ningún test matchee explícitamente su `fontSize`.
- **B-06**: valores fuera de escala (15, 20, 14) en widgets requieren redondeo con criterio. Riesgo: dos devs distintos redondean el mismo `fontSize: 15` a 14 en un widget y a 16 en otro, generando inconsistencia. Mitigación: primer pass redondea todo `15 → 14` (bodyM) por default; solo se sube a 16 (headingM) si el semántico es "título de sección".
- **B-07**: `chipTheme.selectedColor: FincoreColors.accent.withValues(alpha: 0.18)` homologa a `alphaSelected = 0.20`. Cambio de opacidad de 0.18 a 0.20 en el chip seleccionado es visualmente sub-perceptible pero real.
- **B-08**: `Skeleton` corner radius default 4 no está en la escala. Redondeo a `kRadiusSm = 6` levanta ligeramente todos los skeletons. Aceptado.
- **B-09**: si un widget usa un ícono con tamaño fijo (`Icon(Icons.x, size: 14)`), el `size: 14` no es un token de spacing formal pero tampoco es tipografía. Regla ad-hoc: mantener el tamaño literal de iconos (fuera de esta política) — los iconos tienen su propia escala visual (14/16/18/20/24/32/40/48).
- **B-10**: `EdgeInsets` con valores mixtos (`fromLTRB(10, 6, 10, 6)`): ninguno cae exacto. Redondeo: `10 → kSpaceSm=8` (o `kSpaceMd=12`) y `6 → kSpaceSm=8` (o `kSpaceXs=4`). Depende del contexto; documentar.
- **B-11**: widgets que usan `NumberFormat` o similares para formato — no son estilísticos, no requieren tokens.
- **B-12**: `error_snackbar.dart` con fondos saturados (`positive`/`negative`/`warning` full-saturation) NO tiene alpha aplicado — el color entero permanece. Migrar solo tipografía + spacing + margin, NO el color del fondo.
- **B-13**: si el `flutter analyze` reporta warning nuevo "unused_import" tras la migración (por ejemplo, un widget importaba `dart:ui` para `FontFeature` y ya no lo usa), limpiar en el mismo commit.
- **B-14**: `SegmentedButton` de M3 (usado en `AppliesToPicker`, `BudgetKindPicker` locales de weekly budgets — pero al menos `AppliesToPicker` es compartido). Verificar que el override de padding/borderRadius que M3 aplica no rompa con los tokens.
- **B-15**: `DropdownMenu` de M3 (usado en `AccountPicker`, `CategoryPicker`) — mismo caso que B-14. El estilo del menu flotante lo controla el theme; verificar consistencia.

## Pruebas unitarias necesarias

- **UT-01**: la definición de cada token se puede validar con un test trivial que compare valores esperados:
  ```dart
  test('kSpaceLg is 16', () => expect(kSpaceLg, 16));
  test('kMotionPulse is 1100ms', () => expect(kMotionPulse, const Duration(milliseconds: 1100)));
  ```
  Escala: 1 test por archivo (5 tests). No obligatorios pero baratos y evitan regresión accidental (ej. alguien cambia `kSpaceLg` a 15 sin actualizar consumidores).
- **UT-02**: `fincore_typography.dart` — validar que cada token expone `fontSize`, `fontWeight`, `letterSpacing` y `color` esperado. 7 tests.
- **UT-03**: `fincore_theme.dart` — test que instancia el ThemeData y valida que `textTheme.bodyMedium?.fontSize == 14`, `textTheme.labelSmall?.fontSize == 11`, etc. Cubre RF-006. Ayuda a detectar regresiones si alguien toca el mapping.

## Pruebas de integracion o API necesarias

No aplica (sprint sin dominio ni integraciones).

## Pruebas de UI o flujo necesarias si aplica

- **UI-01**: los 16 widget tests existentes (`test/screens/` y `test/helpers/`) deben pasar sin modificación. Cubre implícitamente que la migración no rompió el shape/behavior de los widgets consumidos.
- **UI-02**: si algún widget test matchea `find.byWidgetPredicate((w) => w is Text && w.style?.fontSize == 15)`, va a fallar tras la migración. Grep en tests para detectar y ajustar (documentar en `decisiones-implementacion.md`).
- **UI-03**: no se agregan widget tests nuevos en este sprint (los 16 existentes ya cubren la superficie de screens críticas).

## Pruebas de permisos y seguridad si aplica

No aplica.

## Pruebas de datos, migracion o compatibilidad si aplica

- **MC-01**: no hay migración de schema, pero validar que la app abre la BD SQLite existente sin problemas tras el bump de versión. Smoke manual: `flutter run` con BD pre-existente.
- **MC-02**: export → import de backup JSON debe seguir siendo round-trip perfecto. Cubierto por los tests existentes de `backup_test.dart` (8 tests). Deben seguir pasando sin modificación.

## Pruebas de regresion sobre flujos existentes

Todos los flujos consumen widgets compartidos migrados. Regresión posible en:

- **REG-01**: Dashboard — usa `BaseCard`, `Skeleton`, `MovementRow`, `AmountFormatter`. Smoke: cards de KPI se ven idénticas, lista de movimientos idéntica.
- **REG-02**: Entry form — usa `KindPicker`, `AccountPicker`, `CategoryPicker`, `AccountBalanceHint`, `DateFieldOutlined`, `AmountFormatter`, `ErrorSnackbar`. Smoke: alta y edición de movimiento, chequear tipografía de campos y padding.
- **REG-03**: Entries list — usa `EntriesPaginatedList`, `EntriesEmptyState`, `EntriesActiveFiltersBar`, `MovementRow`. Smoke: lista completa, filtros activos, empty state.
- **REG-04**: Accounts + Categories forms — usa `AccountTypePicker`, `AppliesToPicker`, `ColorPicker`, `IconPicker`, `CategoryBadge`, `ConfirmDialog`, `DestructiveDialog`. Smoke: alta y edición.
- **REG-05**: Settings — usa `ConfirmDialog`, `DestructiveDialog`, `SaveViewDialog` (si aplica). Smoke: export/import, reset con confirm.
- **REG-06**: Weekly Budgets — usa widgets locales, pero también `BaseCard`, `Skeleton`, `AmountFormatter`, `ConfirmDialog`, `DestructiveDialog`. Smoke: list + detail.
- **REG-07**: Reports — usa `BaseCard`, `Skeleton`, `AmountFormatter`, `CategoryBadge`. Smoke: 3 tabs distintos (cashflow, heatmap, credit_cards).
- **REG-08**: Splash + First-run + Onboarding — usan `FincoreLogo` (excepción). Smoke: pantalla splash aparece correcta, first-run con dos cards.

## Pruebas manuales o smoke tests necesarios

**Manual desktop** (`flutter run -d linux`):

- **SM-01**: abrir la app con BD pre-existente. Verificar que:
  - Splash aparece con el logo (sin cambios de fontSize proporcional).
  - Dashboard carga con las 3 cards BO/DE/CR + lista de cuentas + últimos movimientos.
  - Fonts, spacings, radios y colores se ven **idénticos** a antes del sprint (aceptar diferencias documentadas: chip radius, button vertical).
- **SM-02**: navegar a Entries → registrar un movimiento nuevo → verificar teclado, pickers, snackbar.
- **SM-03**: navegar a Reports → cambiar entre 3 tabs (cashflow, heatmap gastos, credit cards).
- **SM-04**: navegar a Weekly Budgets → abrir un budget → editar un item.
- **SM-05**: navegar a Settings → tocar export (cancelar antes de guardar archivo).
- **SM-06**: Categorías → crear una categoría nueva → validar color picker y icon picker.

**Manual Android** (`flutter build apk --split-per-abi` + `adb install -r`):

Los mismos SM-01 a SM-06 en dispositivo real. Chequeo especial:

- **SM-07**: ellipsis o wrap de texto en pantallas de 360dp (posible cambio si la tipografía cambió sutilmente).
- **SM-08**: bottom sheets (SaveViewDialog, BudgetItemFormSheet) siguen respetando la nav bar gestual (`viewPadding.bottom` incluido en el padding).
- **SM-09**: haptic + ripple en botones (verificar que no se rompió por override de tokens).

## Datos de prueba recomendados

- BD pre-existente con datos reales (los de Diego): mejor que BD limpia porque expone regresiones en muchas cuentas, categorías, presupuestos.
- Si se hace la validación con BD vacía, generar al menos: 3 cuentas (Bolsa + Débito + Crédito), 5 categorías, 10 movimientos de kinds mixtos, 1 presupuesto semanal.

## Comandos o validaciones locales sugeridas

```bash
cd mobile

# Análisis estático — cero errores
flutter analyze

# Suite completa — 680 tests verdes
flutter test

# Verificación de tokens en widgets migrados (regla RF-008)
# Debería devolver 0 resultados (excepto fincore_logo.dart y // token-exception:)
grep -rn "fontSize: [0-9]" lib/widgets/ | grep -v "fincore_logo" | grep -v "token-exception"

grep -rn "SizedBox(height: [0-9]" lib/widgets/ | grep -v "kSpace" | grep -v "token-exception"

grep -rn "BorderRadius.circular([0-9]" lib/widgets/ | grep -v "kRadius" | grep -v "token-exception"

grep -rn "withValues(alpha: 0\." lib/widgets/ | grep -v "alpha" | grep -v "token-exception"

# Consumo del textTheme (meta: ≥30 resultados post-sprint, hoy ~0)
grep -rn "Theme.of(context).textTheme" lib/widgets/

# Excepciones documentadas
grep -rn "// token-exception:" lib/widgets/

# Run desktop
flutter run -d linux

# Build APK release
flutter build apk --release --split-per-abi

# Verificar versionCode + versionName
grep -E "versionCode|versionName" android/app/build.gradle.kts

# Sync check
scripts/verify-apk.sh
```

## Criterios minimos para aprobar la implementacion

- Los 5 archivos nuevos de tokens existen y compilan.
- `fincore_colors.dart` tiene los 4 alphas nuevos.
- `fincore_theme.dart` tiene `textTheme` con `fontSize` explícito por los 15 slots M3.
- `mobile/lib/widgets/*.dart` migrados: cero `fontSize`/`SizedBox`/`BorderRadius`/`alpha` literales fuera de la escala (salvo `fincore_logo.dart` y excepciones marcadas con `// token-exception:`, con ≤ 5 excepciones totales).
- `CLAUDE.md` tiene la sección "Sistema de tokens de diseño".
- `pubspec.yaml` en `0.21.0+97` y `build.gradle.kts` en `versionCode = 97 / versionName = "0.21.0"`.
- `flutter analyze` en 0 errores.
- `flutter test` con 680 tests verdes (cero modificación de cuerpo de tests, o modificación mínima documentada en `decisiones-implementacion.md`).
- Smoke desktop SM-01 a SM-06 sin regresión visual bloqueante.
- Smoke Android SM-01 a SM-09 sin regresión visual bloqueante (ejecutado por Diego).
- Excepciones documentadas en `implementation/decisiones-implementacion.md`.
- `implementation/pruebas.md` con evidencia de ejecución de tests + smoke.

## Validacion final recomendada

Ejecutar la skill `branch-quality-review` al terminar la implementación. Su reporte vive en `engineering/quality-review/flutter-design-tokens-v1/`.

Foco de la revisión sugerido para el reviewer:

- Confirmar que ningún widget quedó con `fontSize` inline fuera de escala sin marcar como excepción.
- Detectar `TextStyle` inline en widgets que podrían consumir `textTheme` pero no lo hacen (ej. `TextStyle(color: FincoreColors.negative, fontWeight: FontWeight.w600)` sin fontSize — puede indicar dependencia de un default M3 que ahora vale distinto).
- Verificar que `Theme.of(context).textTheme.bodyMedium` (u otro slot) tras la migración devuelve exactamente el token esperado.
- Detectar excepciones (`// token-exception:`) sin justificación clara o repetitivas (2+ excepciones al mismo valor sugieren token faltante).
- Validar que la documentación en `CLAUDE.md` es coherente con lo implementado (no dice "prohibido X" cuando el sprint no aplicó la regla al 100%).

Si la skill no está disponible o falla, ejecutar checklist manual:

- Diff completo del sprint reviewed archivo por archivo.
- `grep` de guardrails del test-plan corriendo en verde.
- Comparación visual side-by-side de 5 pantallas (screenshots antes/después).
- Confirmación con Diego de que la sensación visual no cambió.
