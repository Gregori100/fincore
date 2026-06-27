# Test plan — flutter-reports-balance-at-date-v1

## Casos borde detectados

Inventario completo:

- **CB-T01** — BD sin cuentas (extraño, sin Bolsa): BO=0, DE=0, CR=0,
  accounts=[]. Empty state.
- **CB-T02** — Fecha = hoy: coincide con `FinancialStateService.
  watchBo/De/Cr` exactos.
- **CB-T03** — Fecha pasada filtra entries posteriores: entry de hoy
  no cuenta para saldo a ayer.
- **CB-T04** — Entry con `occurred_at` exacto al final del día de
  `asOf` (23:59:59): cuenta.
- **CB-T05** — Entry con `occurred_at` 1 ms después del fin del día:
  NO cuenta.
- **CB-T06** — Soft-deleted entry: NO cuenta.
- **CB-T07** — Cuenta credit con `credit_limit = null`: contribuye a
  DE pero no a CR.
- **CB-T08** — Cuenta credit con `credit_limit = 0`: contribuye a CR
  con valor 0 (vacío de espacio disponible).
- **CB-T09** — Cuenta archivada (`accounts.deleted_at != NULL`): NO
  aparece en accounts ni contribuye a totales.
- **CB-T10** — Sin movimientos hasta la fecha: cuentas en lista con
  balance=0.
- **CB-T11** — Orden de la lista: cash → debit → credit, dentro de
  cada tipo alfabético asc.
- **CB-T12** — Reactividad: registrar entry desde otra pantalla con
  `occurred_at <= asOf` → reporte refresca.
- **CB-T13** — Default `_asOf`: enero → diciembre del año anterior.
  Diciembre → noviembre.

## Pruebas unitarias necesarias

### En `mobile/test/data/reports_test.dart`

Nuevo grupo `group('balanceAtDate — totales', ...)`:

- **UT-01**: BD sin entries → BO=0, DE=0, CR=0.
- **UT-02**: fecha = hoy con seed estándar → BO/DE/CR coinciden con
  los valores de `FinancialStateService.watchBo/De/Cr` (validación
  cruzada).
- **UT-03**: fecha pasada filtra entries posteriores. Sembrar 2
  entries, el segundo con `occurred_at` después de `asOf` → solo
  el primero cuenta.
- **UT-04**: entry exacto al final del día de `asOf` cuenta. Entry 1
  ms después NO cuenta.

Nuevo grupo `group('balanceAtDate — soft delete y archivos', ...)`:

- **UT-05**: entry soft-deleted excluido.
- **UT-06**: cuenta credit con `credit_limit = null` contribuye a DE,
  no a CR. Cuenta credit con `credit_limit = 0` contribuye a CR con
  valor 0.

Nuevo grupo `group('balanceAtDate — lista de cuentas', ...)`:

- **UT-07**: lista ordenada por tipo (cash → debit → credit) +
  alfabético dentro de cada tipo. Sembrar Bolsa, "Z BBVA", "A
  BBVA", "Visa", "Mastercard" → orden esperado:
  Bolsa, A BBVA, Z BBVA, Mastercard, Visa.
- **UT-08**: cuenta sin movimientos hasta la fecha aparece con
  balance=0.

### Tests cruzados (validación de cosherencia con FinancialState)

- UT-02 ya cubre esto: valida que `balanceAtDate(asOf=hoy)` coincide
  con `FinancialStateService.watchBo/De/Cr.first` en una BD sembrada.

## Pruebas de integración o API necesarias

No aplica (sin red).

## Pruebas de UI o flujo necesarias

### En `mobile/test/screens/balance_at_date_tab_test.dart` (nuevo)

- **WT-01**: render con datos: BD seeded, abrir tab → 3 cards con
  montos formateados visibles + lista de cuentas con sus saldos.
- **WT-02**: empty state cuando BD vacía: tab muestra "No hay cuentas
  activas." con icono neutro.
- **WT-03**: tap en el field de fecha abre `showDatePicker` (smoke,
  no necesita seleccionar).

### En `mobile/test/screens/reports_screen_test.dart`

- **WT-04**: suite existente verde tras bump a 4 tabs (sin
  modificaciones esperadas — sprint anterior estableció patrón).

### Cobertura existente que se debe preservar

- `cashflow_tab_test.dart` (3 tests) → verde sin cambios.
- `top_movements_tab_test.dart` (4 tests) → verde sin cambios.
- `reports_deeplink_test.dart` → verde sin cambios.

## Pruebas de permisos y seguridad

No aplica (single-user local).

## Pruebas de datos, migración o compatibilidad

- **DT-01**: round-trip de backup JSON con cuentas y entries variados
  → tras import, `balanceAtDate(asOf=hoy)` da los mismos totales.

## Pruebas de regresión sobre flujos existentes

- **RG-01**: `flutter test` completo verde con 266 tests previos +
  11 nuevos = ~277.
- **RG-02**: dashboard BO/DE/CR sin cambios — los streams cacheados de
  `FinancialStateService` siguen funcionando.
- **RG-03**: los 3 tabs anteriores de `/reports` sin cambios.
- **RG-04**: panel de filtros + lista de `/entries` sin cambios.

## Pruebas manuales o smoke tests necesarios

Tras APK release:

- **SM-01**: abrir app → tap "Reportes" → ver TabBar con 4 tabs
  scrollable: "Gasto por categoría", "Cashflow mensual", "Top
  movimientos", "Saldo a fecha".
- **SM-02**: tap "Saldo a fecha" → ver field con fecha default (fin
  del mes anterior) + 3 cards BO/DE/CR + lista de cuentas con sus
  saldos.
- **SM-03**: cambiar fecha a hoy → BO/DE/CR coinciden con dashboard.
- **SM-04**: cambiar fecha a inicio del mes → reporte refresca, los
  saldos cambian si hay movimientos del mes.
- **SM-05**: registrar entry desde `/entries/new` con `occurred_at`
  reciente, volver al tab → reporte refresca.
- **SM-06**: tap en field de fecha → date picker se abre con
  `lastDate = hoy`. No se puede seleccionar fecha futura.

## Datos de prueba recomendados

Para tests data: el setUp existente con Bolsa + debit + credit +
categorías es suficiente para 7/8 tests. UT-07 requiere sembrar
cuentas adicionales con nombres específicos para validar el orden.

Para widget tests: el harness `pumpFincoreApp` con seed minimal.
WT-01 necesita 1 entry para que los totales sean != 0. WT-02 sin
seed (BD vacía). WT-03 no necesita seed.

## Comandos o validaciones locales sugeridas

```bash
cd mobile

# Solo el grupo nuevo durante F2:
flutter test test/data/reports_test.dart --name 'balanceAtDate'

# Solo el archivo del tab nuevo durante F5:
flutter test test/screens/balance_at_date_tab_test.dart

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

- [ ] 8 tests data nuevos pasan (UT-01 a UT-08).
- [ ] 3 widget tests del tab nuevo pasan (WT-01 a WT-03).
- [ ] `flutter test` completo verde (~277 tests).
- [ ] `flutter analyze` 0 errores.
- [ ] APK `0.9.0+61` construido + `verify-apk.sh` OK.
- [ ] Tests existentes de `reports_screen_test.dart`,
      `cashflow_tab_test.dart`, `top_movements_tab_test.dart` siguen
      verdes.
- [ ] Smoke manual SM-01 a SM-06 (Diego).

## Validación final recomendada

Tras la implementación cerrada, ejecutar la skill
`branch-quality-review` para revisión exhaustiva. Esa skill genera
su propio reporte en `engineering/quality-review/<slug>/`.

Si la skill no está disponible, checklist equivalente:

- [ ] BO/DE/CR a fecha=hoy coinciden con dashboard (validación
      cruzada manual).
- [ ] Sin cuentas archivadas en la lista.
- [ ] Lista ordenada por tipo + alfabético.
- [ ] Tap en field abre picker funcional.
- [ ] Sin print() ni TODO colgados en el código nuevo.
