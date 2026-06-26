# Test plan — flutter-movements-amount-filter-v1

## Casos borde detectados

- **CB-T01** — Solo `minAmount`: entries con `amount >= min` aparecen;
  los `< min` quedan fuera.
- **CB-T02** — Solo `maxAmount`: entries con `amount <= max` aparecen;
  los `> max` quedan fuera.
- **CB-T03** — Ambos extremos (rango): entries con
  `min <= amount <= max`.
- **CB-T04** — `minAmount == maxAmount`: filtro exacto. Solo entries
  con `amount == X`.
- **CB-T05** — `minAmount > maxAmount` al "Aplicar": snackbar warning,
  panel queda abierto, NO emite resultado.
- **CB-T06** — Decimales: ej. `1499.50`. Filtro respeta decimales.
- **CB-T07** — `minAmount = 0`: cuenta como dimensión activa.
- **CB-T08** — Limpiar el field (texto vacío): `null` → no filtra.
- **CB-T09** — Combinado con filtro de kind + fecha: condiciones se
  componen con AND.
- **CB-T10** — Tap "X" del chip de monto: `clearDimension(amount)`
  limpia ambos campos.
- **CB-T11** — Cambiar monto resetea paginación a `_kPageSize`.
- **CB-T12** — Deep link `?minAmount=500`: pre-carga el filtro.
- **CB-T13** — Deep link `?minAmount=abc`: ignorado por
  `double.tryParse`.
- **CB-T14** — Deep link `?minAmount=-500`: ignorado por RN-A07.
- **CB-T15** — Entry soft-deleted con `amount` en el rango: NO cuenta
  (regresión del filtro de soft-delete existente).
- **CB-T16** — Concurrencia: cancelar entry desde `/entries/:id/edit`
  mientras el filtro de monto está activo. Stream re-emite sin el
  entry. Sin reset de paginación.

## Pruebas unitarias necesarias

### En `mobile/test/data/entries_dao_filters_test.dart`

Nuevo grupo `group('watchPage — amount (RN-A01..A08)', ...)` con
setUp que siembra 3-4 entries con montos distintos en el mes
corriente:

- **UT-01**: solo `minAmount = 100` → entries con `amount >= 100`
  aparecen.
- **UT-02**: solo `maxAmount = 500` → entries con `amount <= 500`.
- **UT-03**: rango `min = 100, max = 500` → solo en `[100, 500]`.
- **UT-04**: `min == max == 250` → solo entries con `amount == 250`.
- **UT-05**: combinado con `kinds = ['expense']` + rango de fecha →
  AND.
- **UT-06**: regresión: sin filtro de monto → todos los entries del
  rango aparecen (mismo comportamiento que antes).

### En `mobile/test/data/entries_filters_test.dart` (probablemente nuevo)

Si no existe, crear archivo con grupo `EntriesFilters — amount`:

- **UT-07**: `copyWith(minAmount: 100)` setea, `copyWith(clearMinAmount:
  true)` limpia, `copyWith()` no cambia.
- **UT-08**: `clearDimension(FilterDimension.amount)` limpia ambos
  campos.
- **UT-09**: `activeCount` cuenta amount como 1 dimensión cuando solo
  hay min o solo max o ambos.
- **UT-10**: `parse({'minAmount': '500', 'maxAmount': '1500'})`
  retorna filtros con valores parseados.
- **UT-11**: `parse({'minAmount': 'abc'})` → minAmount queda null.
- **UT-12**: `parse({'minAmount': '-500'})` → minAmount queda null.
- **UT-13**: `toDeepLink()` con `minAmount = 500` y `maxAmount = 1500`
  serializa ambos como query params.

## Pruebas de integración o API necesarias

No aplica (sin red).

## Pruebas de UI o flujo necesarias

### En `mobile/test/screens/entries_filters_screen_test.dart`

- **WT-01**: sección "Monto" renderea 2 fields ("Mínimo", "Máximo")
  con prefijo `$`.
- **WT-02**: ingresar `min = 100` + Aplicar emite filtros con
  `minAmount = 100`.
- **WT-03**: ingresar `min = 1000, max = 100` + Aplicar muestra
  snackbar warning + NO emite (panel queda).

### En `mobile/test/screens/entries_list_screen_test.dart` (probable extensión)

Opcional pero valorable:

- **WT-04**: deep link `?minAmount=500` filtra la lista al pre-cargar.

### En `mobile/test/screens/cashflow_tab_test.dart` (cobertura existente)

Sin cambios — confirmar que `flutter test` completo sigue verde.

## Pruebas de permisos y seguridad

No aplica.

## Pruebas de datos, migración o compatibilidad

- **DT-01**: round-trip de backup JSON con entries que tengan
  variedad de `amount`. El export/import no introduce ni elimina
  campos; el filtro nuevo es de UI, no de modelo persistente.

## Pruebas de regresión sobre flujos existentes

- **RG-01**: `flutter test` completo verde post implementación
  (~243 tests).
- **RG-02**: tests existentes de `watchPage` con filtros de
  kind/account/category/fecha siguen verdes (los nuevos campos son
  opcionales).
- **RG-03**: tests existentes de `EntriesFilters` (parse,
  toDeepLink, copyWith con dimensiones existentes) siguen verdes.
- **RG-04**: integration tests del Sprint 1
  (`entries_filters_panel_test`) siguen verdes — el panel solo
  agrega una sección.
- **RG-05**: cashflow (sprint reciente) no afectado.
- **RG-06**: spending tab (sprint anterior) no afectado.

## Pruebas manuales o smoke tests necesarios

Tras APK release:

- **SM-01**: abrir `/entries` → tap "Filtros" → scroll del panel →
  ver sección "Monto" entre "Cuenta" y "Categorías".
- **SM-02**: escribir `min = 1000` → Aplicar → lista filtra entries
  con `amount >= 1000`. Chip "≥ $1.000" aparece en la bar.
- **SM-03**: tap "X" del chip → lista refresca, chip desaparece.
- **SM-04**: escribir `min = 100, max = 500` → Aplicar → chip
  "$100 – $500" + lista filtrada.
- **SM-05**: escribir `min = 1000, max = 100` → Aplicar → snackbar
  warning, panel queda abierto.
- **SM-06**: filtros combinados: monto + kind + fecha. Lista coherente.
- **SM-07**: cancelar un entry desde `/entries/:id/edit` con filtro
  de monto activo → lista refresca sin él.

## Datos de prueba recomendados

Para tests data: 4-5 entries con montos variados
(50, 100, 250, 500, 1000) en el mes corriente con kinds mixtos.
Reusar setUp existente del archivo de tests del DAO.

Para widget tests: el harness `pumpFincoreApp` con seed minimal —
los tests del panel no requieren entries reales porque el panel solo
construye `EntriesFilters` sin tocar BD.

## Comandos o validaciones locales sugeridas

```bash
cd mobile

# Solo el grupo nuevo del DAO durante F4:
flutter test test/data/entries_dao_filters_test.dart --name 'amount'

# Solo los tests del modelo:
flutter test test/data/entries_filters_test.dart

# Solo los tests del panel:
flutter test test/screens/entries_filters_screen_test.dart

# Suite completa antes de commit:
flutter test

# Analyze:
flutter analyze

# Build APK release:
flutter build apk --release --split-per-abi

# Verify APK:
bash ../scripts/verify-apk.sh
```

## Criterios mínimos para aprobar la implementación

- [ ] 6 tests data del DAO pasan (UT-01 a UT-06).
- [ ] 7 tests del modelo pasan (UT-07 a UT-13).
- [ ] 3 widget tests del panel pasan (WT-01 a WT-03).
- [ ] `flutter test` completo verde (~243 tests).
- [ ] `flutter analyze` 0 errores.
- [ ] APK `0.7.1+59` construido + `verify-apk.sh` OK.
- [ ] Tests existentes del DAO con kind/account/category/fecha
      siguen verdes.
- [ ] Smoke manual SM-01 a SM-05 (Diego).

## Validación final recomendada

Tras la implementación cerrada, ejecutar la skill
`branch-quality-review` para revisión exhaustiva de la rama. Esa skill
genera su propio reporte en `engineering/quality-review/<slug>/`; no
duplicar dentro de `implementation/`.

Si la skill no está disponible, checklist equivalente:

- [ ] El `inputFormatter` del field "Mínimo" y "Máximo" filtra todo lo
      no-numérico en pruebas manuales.
- [ ] El chip de monto no desborda con montos grandes (`$10.000.000`).
- [ ] La validación `min > max` se respeta también al cambiar de
      preset de fecha + monto + cuenta + categoría en un solo "Aplicar".
- [ ] Deep link funciona desde el browser/intent del cel (no solo
      desde tests).
