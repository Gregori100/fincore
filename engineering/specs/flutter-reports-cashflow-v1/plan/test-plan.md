# Test plan — flutter-reports-cashflow-v1

## Casos borde detectados

Inventario completo, incluyendo huecos que la spec no abarca con
explicitud:

- **CB-T01** — BD vacía en el rango: `total_income=0`, `total_expense=0`,
  `net=0`, `months=[]` (o array con los meses del rango con 0s,
  según RN-C06). Decisión: array poblado con ceros para mantener UX
  consistente.
- **CB-T02** — Rango con un solo `income` en un mes: `MonthCashflow`
  con `income > 0`, `expense = 0`, `net = income`. Los meses restantes
  del rango (si los hay) aparecen con 0s.
- **CB-T03** — Rango con `expense` + `credit_expense` ambos en el mismo
  mes: se suman en `expense` (RN-C02).
- **CB-T04** — Rango con `transfer` o `debt_payment`: NO contribuyen
  (RN-C03). Verifica el aislamiento por kind.
- **CB-T05** — Entry soft-deleted con `deleted_at != NULL`: NO cuenta.
- **CB-T06** — Rango cruzando año (ej. dic-2025 a feb-2026): 3 meses
  en orden cronológico ascendente.
- **CB-T07** — Mes intermedio sin entries: aparece con 0/0 (RN-C06).
- **CB-T08** — Categoría archivada con `expense` activo: el expense
  cuenta normalmente (cashflow es agregado, no desglosa por categoría).
- **CB-T09** — Límite inclusivo en `from` exacto: entry con
  `occurred_at == from` cuenta.
- **CB-T10** — Límite inclusivo en `to` exacto: entry con
  `occurred_at == to` cuenta.
- **CB-T11** — `from == to` dentro del mismo mes: 1 entrada en
  `months` con los datos de ese día.
- **CB-T12** — Rango de 1 mes y 1 día (ej. 1 dic - 1 ene): 2 entradas
  en `months` (diciembre y enero), incluso si solo un día de enero
  está en el rango. Por RN-C06 el mes parcial cuenta.
- **CB-T13** — Net = 0 exacto: ingresos == gastos. Verificar que el
  formato no muestre signo confuso ("-0" vs "0"). UI usa `formatAmount`
  estándar.
- **CB-T14** — Concurrencia: cancelar un entry desde `/entries` mientras
  el tab está visible debe re-emitir el reporte sin reset de scroll.
- **CB-T15** — Re-cálculo tras cambio de preset: el state recrea
  `_reportStream`; el StreamBuilder reconstruye con loading state.
- **CB-T16** — Tap "Custom" → seleccionar `from` futuro a `to`: debe
  manejarse igual que en el spending tab (snackbar warning + ajuste
  automático).
- **CB-T17** — `amount=0` en un entry: suma 0, no afecta el cálculo.

## Pruebas unitarias necesarias

### En `mobile/test/data/reports_test.dart`

Nuevo grupo `group('cashflowByMonth — agregación básica', ...)`:

- **UT-01**: `BD sin entries en el rango: total=0, net=0, months tiene
  los meses del rango con 0s` (CB-T01, RN-C06).
- **UT-02**: `Único income en junio: 1 MonthCashflow con income > 0
  + net positivo` (CB-T02, RN-C01).
- **UT-03**: `expense + credit_expense del mismo mes se suman en
  expense` (CB-T03, RN-C02).

Nuevo grupo `group('cashflowByMonth — filtros de kind', ...)`:

- **UT-04**: `transfer NO cuenta` (CB-T04, RN-C03).
- **UT-05**: `debt_payment NO cuenta` (CB-T04, RN-C03).

Nuevo grupo `group('cashflowByMonth — soft delete', ...)`:

- **UT-06**: `Entry soft-deleted no cuenta` (CB-T05).

Nuevo grupo `group('cashflowByMonth — agrupación por mes', ...)`:

- **UT-07**: `Rango cruzando año tiene meses en orden cronológico`
  (CB-T06, RN-C08).
- **UT-08**: `Mes intermedio sin entries aparece con 0/0` (CB-T07,
  RN-C06).
- **UT-09**: `from == to: 1 MonthCashflow del mes correspondiente`
  (CB-T11).
- **UT-10**: `Rango de 1 día abarca 1 mes en months` (CB-T11).
- **UT-11**: `Rango cruza mes (último día de N → primer día de N+1):
  2 meses en months` (CB-T12).

Nuevo grupo `group('cashflowByMonth — invariantes', ...)`:

- **UT-12**: `net == income - expense para cada mes y para el total`
  (RN-C07).
- **UT-13**: `sum(months[].income) == totalIncome y sum(months[].expense)
  == totalExpense`.

## Pruebas de integración o API necesarias

No aplica (sin red, sin API externa).

## Pruebas de UI o flujo necesarias

### En `mobile/test/screens/cashflow_tab_test.dart` (nuevo archivo)

- **WT-01**: `Render con datos: 3 meses con income + expense → header
  muestra métricas correctas + chart visible + breakdown numérico
  visible`.
- **WT-02**: `Empty state: BD sin entries en thisMonth → texto "No
  hay movimientos en este rango." visible`.
- **WT-03**: `Tap preset "Año" cambia el rango y refresca el reporte`.

### En `mobile/test/screens/reports_screen_test.dart` (ajuste)

- **WT-04**: validar que el archivo existente sigue verde tras el
  bump a 2 tabs. Posible ajuste: si algún test usaba
  `find.byType(Tab).single` o `findsOneWidget`, cambiar a
  `findsNWidgets(2)`. Si usaba `find.text('Gasto por categoría')`,
  sigue funcionando (el tab 0 conserva el label).

### Cobertura existente que se debe preservar

- `mobile/test/screens/reports_deeplink_test.dart` (sprint
  `flutter-movements-filters-v1`): valida tap en bucket → `/entries`.
  Debe seguir verde sin cambios (toca `SpendingByCategoryTab`, no
  el cashflow).

## Pruebas de permisos y seguridad

No aplica (single-user local).

## Pruebas de datos, migración o compatibilidad

- **DT-01**: round-trip de backup JSON con entries de income +
  expense + credit_expense: tras importar, el cashflow muestra los
  mismos totales (validar que la cobertura existente de
  `backup_test.dart` cubre esto implícitamente).
- **DT-02**: sin migración nueva → no aplica.

## Pruebas de regresión sobre flujos existentes

- **RG-01**: `flutter test` completo debe seguir verde con los 219 tests
  actuales + los nuevos (~14). Total esperado: ~233.
- **RG-02**: el `SpendingByCategoryTab` no sufre cambios visuales ni
  funcionales. Test smoke: abrir tab 0, verificar que muestra el reporte
  correcto.
- **RG-03**: el deep link desde el reporte de spending sigue navegando
  a `/entries` con los filtros equivalentes (cubierto por
  `reports_deeplink_test.dart`).
- **RG-04**: `/dashboard` BO/DE/CR siguen siendo correctos. No afectados
  por el cashflow service.
- **RG-05**: integration tests del Sprint 1 (`movements_pagination`,
  `account_form`, etc.) siguen verdes. Sin tocar.

## Pruebas manuales o smoke tests necesarios

Tras el APK release:

- **SM-01**: abrir app → tap "Reportes" → ver TabBar con 2 tabs:
  "Gasto por categoría" y "Cashflow mensual".
- **SM-02**: tap tab "Cashflow mensual" → ver chips de presets +
  header con 3 métricas + bar chart + breakdown.
- **SM-03**: tap preset "Año" → reporte refresca con más meses;
  scroll horizontal si no caben.
- **SM-04**: tap preset "Custom" → 2 date pickers; al confirmar el
  reporte refresca.
- **SM-05**: con la app abierta en el tab "Cashflow", abrir otra
  pestaña, registrar un nuevo income, volver al tab → el reporte
  refleja el nuevo dato (reactividad).
- **SM-06**: BD vacía: import un respaldo vacío → tap tab → empty
  state visible.

## Datos de prueba recomendados

Para los tests data, el setUp ya tiene Bolsa + debit + credit +
3 categorías (Comida, Transporte, Salud) sembradas. Reusar.

Para los widget tests:

- Seed mínimo: Bolsa + 3 entries en 3 meses distintos (1 income, 2
  expense, 1 credit_expense) para validar el render con datos.
- Seed adicional: 1 entry con `transfer` para verificar que NO
  contribuye al chart.

## Comandos o validaciones locales sugeridas

```bash
cd mobile

# Solo el grupo nuevo (durante desarrollo de F2):
flutter test test/data/reports_test.dart --name 'cashflowByMonth'

# Solo el archivo del tab nuevo (durante desarrollo de F5):
flutter test test/screens/cashflow_tab_test.dart

# Suite completa antes de commit:
flutter test

# Analyze antes de commit:
flutter analyze

# Build APK release:
flutter build apk --release --split-per-abi

# Verify APK matches pubspec:
bash ../scripts/verify-apk.sh
```

## Criterios mínimos para aprobar la implementación

- [ ] Los 13 tests data nuevos pasan.
- [ ] Los 3 widget tests del tab nuevo pasan.
- [ ] `flutter test` completo verde (~232 tests).
- [ ] `flutter analyze` con 0 errores.
- [ ] APK `0.7.0+58` construido y `verify-apk.sh` OK.
- [ ] El `reports_screen_test.dart` existente verde sin que regrese.
- [ ] El `reports_deeplink_test.dart` existente verde sin que regrese.
- [ ] Smoke manual SM-01, SM-02, SM-03 (Diego).

## Validación final recomendada

Tras la implementación cerrada, ejecutar la skill
`branch-quality-review` para revisión exhaustiva de la rama. Esa skill
genera su propio reporte en `engineering/quality-review/<slug>/`; no
duplicar dentro de `implementation/`.

Si la skill no está disponible, checklist equivalente:

- [ ] Hay 0 archivos sin tests críticos.
- [ ] Hay 0 `print()` ni `// TODO` colgados.
- [ ] Imports ordenados sin no-utilizados.
- [ ] Nombres de tests + grupos coherentes con la convención del repo
      (`cashflowByMonth — <categoría>`).
- [ ] El bar chart pareado tiene scroll horizontal funcional con
      rangos > 6 meses (validar visualmente en cel).
- [ ] La nota del bump de versión está en `pubspec.yaml` y refleja
      qué se entrega.
