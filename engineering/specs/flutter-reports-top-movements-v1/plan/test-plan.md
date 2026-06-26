# Test plan — flutter-reports-top-movements-v1

## Casos borde detectados

Inventario completo, incluyendo huecos no abarcados explícitamente
por la spec:

- **CB-T01** — BD vacía → `entries: []`, `isEmpty: true`.
- **CB-T02** — Solo 5 entries en el rango, limit=20 → muestra los 5
  sin completar.
- **CB-T03** — 30 entries en el rango, limit=20 → muestra exactamente
  20.
- **CB-T04** — Orden por monto desc: 3 entries con montos 100, 500,
  300 → orden `[500, 300, 100]`.
- **CB-T05** — Tiebreak: 2 entries con monto idéntico, occurred_at
  diferente → más reciente primero.
- **CB-T06** — Tiebreak: 2 entries con monto y occurred_at idénticos,
  created_at diferente → más reciente primero.
- **CB-T07** — Entry soft-deleted en el rango → NO aparece.
- **CB-T08** — Categoría archivada del entry: badge `null` en
  `TopMovementEntry.category`.
- **CB-T09** — Rango inclusivo en `from` exacto: entry con
  `occurred_at == from` aparece.
- **CB-T10** — Rango inclusivo en `to` exacto: entry con `occurred_at`
  igual al final del día de `to` aparece.
- **CB-T11** — Filtro de kinds: `kinds: ['expense']` excluye income,
  credit_expense, transfer, debt_payment.
- **CB-T12** — Atajo defensivo: `kinds: []` retorna reporte vacío sin
  consultar BD.
- **CB-T13** — Entry con `description == null`: la UI muestra
  `kind.label` como fallback.
- **CB-T14** — Concurrencia: cancelar entry top desde
  `/entries/:id/edit` → al volver, el top refresca sin él.
- **CB-T15** — Cambio de preset de fecha: state se mantiene en chips
  de kinds (`_selectedKinds` no se resetea).
- **CB-T16** — Cambio de tab y vuelta: el state se pierde (chips de
  kinds vuelven a default 5 seleccionados). Esperado, no es bug.

## Pruebas unitarias necesarias

### En `mobile/test/data/reports_test.dart`

Nuevo grupo `group('topMovements — agregación básica', ...)`:

- **UT-01**: BD vacía → `entries: []`, `isEmpty: true`.
- **UT-02**: orden por monto desc con 3 entries (100, 500, 300) → ids
  ordenados según `[500, 300, 100]`.
- **UT-03**: tiebreak por occurred_at desc con 2 entries de monto
  idéntico → más reciente primero.

Nuevo grupo `group('topMovements — soft delete y archivos', ...)`:

- **UT-04**: entry soft-deleted no cuenta.
- **UT-05**: entry con categoría archivada → `category == null` en
  el resultado.

Nuevo grupo `group('topMovements — limit', ...)`:

- **UT-06**: 30 entries sembrados, limit=20 → retorna 20.
- **UT-07**: 5 entries sembrados, limit=20 → retorna 5.

Nuevo grupo `group('topMovements — rango temporal', ...)`:

- **UT-08**: rango inclusivo en `from` exacto.
- **UT-09**: rango inclusivo en `to` exacto (final del día).

Nuevo grupo `group('topMovements — filtro de kinds', ...)`:

- **UT-10**: `kinds: ['expense']` excluye otros kinds.
- **UT-11**: atajo defensivo `kinds: []` retorna lista vacía sin
  consultar BD (validar con un spy o assertion sobre el resultado
  inmediato).

## Pruebas de integración o API necesarias

No aplica (sin red).

## Pruebas de UI o flujo necesarias

### En `mobile/test/screens/top_movements_tab_test.dart` (nuevo)

- **WT-01**: render con datos: 3 entries sembrados con kinds y montos
  variados → 3 rows visibles ordenados desc.
- **WT-02**: empty state cuando rango vacío: "No hay movimientos en
  este rango." con icono visible.
- **WT-03**: empty state cuando sin kinds seleccionados (Diego
  destilda los 5 chips) → "Seleccioná al menos un tipo de
  movimiento."
- **WT-04**: tap en row navega a `/entries/:id/edit` (validar con
  `find.byType(EntryFormScreen)` o equivalente tras pumpAndSettle).

### En `mobile/test/screens/reports_screen_test.dart`

- **WT-05**: validar suite existente verde tras el bump a 3 tabs.
  Si algún test usa `find.byType(Tab)` con asunción de length=2,
  cambiar a `findsNWidgets(3)`. El sprint anterior validó que el bump
  1→2 no rompió nada — estimar lo mismo.

### Cobertura existente que se debe preservar

- `cashflow_tab_test.dart` (3 tests) → verde sin cambios.
- `reports_deeplink_test.dart` → verde sin cambios.

## Pruebas de permisos y seguridad

No aplica (single-user local).

## Pruebas de datos, migración o compatibilidad

- **DT-01**: round-trip de backup JSON con entries variados →
  tras importar, el top muestra los mismos entries con los mismos
  montos.
- **DT-02**: sin migración nueva → no aplica.

## Pruebas de regresión sobre flujos existentes

- **RG-01**: `flutter test` completo verde con los 251 tests
  actuales + nuevos (~14). Total esperado: ~265.
- **RG-02**: `SpendingByCategoryTab` y `CashflowTab` no sufren cambios.
  Tests existentes verdes.
- **RG-03**: deep link desde el reporte de spending sigue navegando.
- **RG-04**: `/dashboard` BO/DE/CR siguen correctos.
- **RG-05**: panel de filtros de `/entries` (sprint anterior) intacto.
- **RG-06**: filtro de monto (sprint anterior) intacto.

## Pruebas manuales o smoke tests necesarios

Tras APK release:

- **SM-01**: abrir app → tap "Reportes" → ver TabBar con 3 tabs:
  "Gasto por categoría", "Cashflow mensual", "Top movimientos".
- **SM-02**: tap "Top movimientos" → ver chips de presets + chips de
  kinds (los 5 seleccionados) + lista de hasta 20 entries.
- **SM-03**: tap preset "Año" → reporte refresca con más entries.
- **SM-04**: tap preset "Custom" → 2 date pickers funcionan.
- **SM-05**: destildar chip "Ingreso" → la lista refresca sin
  incomes.
- **SM-06**: destildar todos los 5 chips → empty state "Seleccioná
  al menos un tipo de movimiento.".
- **SM-07**: tap en una row → navega a `/entries/:id/edit` con
  datos pre-cargados.
- **SM-08**: cancelar el entry top desde edit + volver → el top
  refresca sin él.
- **SM-09**: cambiar a otro tab y volver → los chips vuelven a
  default (los 5 seleccionados).

## Datos de prueba recomendados

Para tests data: el setUp existente del `reports_test.dart` ya tiene
Bolsa + debit + credit + categorías sembradas. Reusar.

Para widget tests: el harness `pumpFincoreApp` con seed minimal.
Los tests del top necesitan al menos 1-3 entries variados para
validar render + tap. Para el test de empty state sin kinds, no
hace falta seed.

## Comandos o validaciones locales sugeridas

```bash
cd mobile

# Solo el grupo nuevo durante F2:
flutter test test/data/reports_test.dart --name 'topMovements'

# Solo el archivo del tab nuevo durante F5:
flutter test test/screens/top_movements_tab_test.dart

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

- [ ] 11 tests data nuevos pasan (UT-01 a UT-11).
- [ ] 4 widget tests del tab nuevo pasan (WT-01 a WT-04).
- [ ] `flutter test` completo verde (~266 tests).
- [ ] `flutter analyze` 0 errores.
- [ ] APK `0.8.0+60` construido + `verify-apk.sh` OK.
- [ ] `reports_screen_test.dart` verde tras bump a 3 tabs.
- [ ] `cashflow_tab_test.dart` y `reports_deeplink_test.dart` verdes.
- [ ] Smoke manual SM-01 a SM-09 (Diego).

## Validación final recomendada

Tras la implementación cerrada, ejecutar la skill
`branch-quality-review` para revisión exhaustiva. Esa skill genera su
propio reporte en `engineering/quality-review/<slug>/`.

Si la skill no está disponible, checklist equivalente:

- [ ] Hay 0 archivos sin tests críticos.
- [ ] Hay 0 `print()` ni `// TODO` colgados.
- [ ] El tap en row efectivamente navega — no hay regresión silenciosa.
- [ ] Los chips de kinds tienen estado coherente al ciclo de vida del
      tab (no se mezclan entre tabs).
- [ ] Sin print/logs colgados en el código nuevo.
