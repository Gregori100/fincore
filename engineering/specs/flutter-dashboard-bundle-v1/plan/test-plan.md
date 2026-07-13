# Plan de pruebas — flutter-dashboard-bundle-v1

## Casos borde detectados

Consolidación de CB-01..CB18 de la spec + CB-P01..CB-P05 nuevos del
plan:

- **CB-01**: Día sin movimientos → vista "Hoy" muestra `$0 · $0 ·
  Neto $0` en `textMuted`.
- **CB-02**: Usuario nuevo con solo Bolsa y 0 movimientos →
  sparklines de los 3 cards muestran línea horizontal.
- **CB-03**: Usuario con solo 1 movimiento en los 30 días → sparkline
  muestra un cambio de nivel; días previos con saldo inicial, días
  posteriores con nuevo saldo.
- **CB-04**: Historia completa 30+ días → sparkline reactiva completa.
- **CB-05**: Saldo negativo (libreta libre) → sparkline se ajusta al
  min-max, puede pasar por debajo del baseline.
- **CB-06**: Credit con deuda estable 30d → línea horizontal (min ==
  max).
- **CB-07**: Registrar `transfer` → NO afecta vista "Hoy" ni
  sparklines de tipo (mueve entre cash+debit dentro del agregado BO).
- **CB-08**: Registrar `debt_payment` → NO afecta vista "Hoy". SÍ
  afecta sparklines: BO baja, DE baja, CR sube.
- **CB-09**: Cancelar movimiento de hoy → vista "Hoy" y sparkline
  del día actual recalculan.
- **CB-10**: Cancelar movimiento de hace 10 días → sparkline
  recalcula backfill desde ese día en adelante.
- **CB-11**: Filtrar por cuenta X + registrar mov que NO toca X →
  lista NO cambia.
- **CB-12**: Filtrar por cuenta X + registrar mov que SÍ toca X →
  lista se re-emite.
- **CB-13**: Filtrar por cuenta X + archivar cuenta X → chip
  desaparece, filtro cae a "Todas".
- **CB-14**: 10+ cuentas → chips scrollean horizontalmente.
- **CB-15**: Renombrar cuenta con chip seleccionado → label del
  chip se actualiza.
- **CB-16**: Cruzar medianoche → vista "Hoy" NO cambia hasta
  refresh (RN-DB15).
- **CB-17**: Timezone borderline (23:30 UTC del día anterior que
  localmente es hoy) → cuenta en el día local correcto.
- **CB-18**: Dataset volátil (huge swings) → escala se ajusta.
- **CB-P01**: Dataset denso (200+ mov en 30d) → query agrupada por
  día, compute negligible.
- **CB-P02**: Landscape / pantalla ancha → sparkline responsive.
- **CB-P03**: Multiple listeners simultáneos → drift no colapsa.
- **CB-P04**: Solo Bolsa (1 cuenta) → chip "Todas" + "Bolsa" ambos
  visibles.
- **CB-P05**: 20+ cuentas → chips scroll horizontal.

## Pruebas unitarias necesarias

Sobre `mobile/test/data/reports_test.dart` (2 grupos nuevos):

**Grupo `watchTodaySummary (sprint dashboard-bundle)`**:

- **UT-TD01**: día sin movimientos → totalIncome=0, totalExpense=0,
  net=0.
- **UT-TD02**: 1 income + 1 expense del día → agregación correcta,
  net = income - expense.
- **UT-TD03**: mix con `credit_expense` → cuenta en `totalExpense`
  (RN-DB01).
- **UT-TD04**: `transfer` y `debt_payment` NO cuentan (RN-DB01).
- **UT-TD05**: movimiento cancelado NO cuenta (RN-DB03).
- **UT-TD06**: movimiento de hoy 23:30 UTC que localmente es mañana
  → NO cuenta en hoy si el localtime cae en el día siguiente
  (blindaje timezone RN-DB02).
- **UT-TD07**: reactividad — registrar income de hoy con stream
  abierto → `emitsThrough` con nuevo total.

**Grupo `watchDailyBalance30d (sprint dashboard-bundle)`**:

- **UT-SP01**: BD vacía (1 cuenta cash, 0 mov) → 30 puntos con
  balance = 0.
- **UT-SP02**: 1 income de $1000 el día `hoy - 15d` → 15 puntos
  primeros a $0, 15 restantes a $1000 (backfill correcto).
- **UT-SP03**: kind='bo' con 2 cuentas (cash + debit) → sparkline
  suma ambos balances.
- **UT-SP04**: kind='de' con 1 cuenta credit → sparkline muestra la
  deuda (positiva, invertida) día a día.
- **UT-SP05**: kind='cr' con 1 cuenta credit + `credit_limit=10000`
  → sparkline = `10000 - deuda` día a día.
- **UT-SP06**: cuenta archivada → NO cuenta en el agregado del kind
  correspondiente.
- **UT-SP07**: reactividad — registrar movimiento nuevo con stream
  abierto → `emitsThrough`.

## Pruebas de integracion o API necesarias

No aplica.

## Pruebas de UI o flujo necesarias si aplica

Sobre `mobile/test/screens/dashboard_screen_test.dart` (crear si no
existe; probable):

- **WT-DB01**: dashboard con Bolsa y 1 income de hoy → vista "Hoy"
  muestra `+$X · $0 · Neto +$X` en positive.
- **WT-DB02**: BD vacía → vista "Hoy" muestra `$0 · $0 · Neto $0`
  en textMuted. Sparklines renderean (línea plana o vacía).
- **WT-DB03**: tap chip de cuenta → lista se filtra (verificar por
  `find.text` de una descripción sembrada solo en esa cuenta vs
  otra descripción de otra cuenta).
- **WT-DB04**: filtrar por cuenta X → archivar cuenta X → chip
  desaparece + filtro cae a "Todas".
- **WT-DB05**: tap chip "Todas" tras haber filtrado → lista vuelve a
  consolidado.

## Pruebas de permisos y seguridad si aplica

No aplica.

## Pruebas de datos, migracion o compatibilidad si aplica

No aplica. Cero schema, cero migración.

## Pruebas de regresion sobre flujos existentes

- **RT-01**: 572 tests baseline + 12 nuevos = **584+ verdes**
  esperados. Cualquier test existente del dashboard debe ajustarse
  si buscaba por widget tree exacto.
- **RT-02**: los 3 métodos existentes `watchBo/watchDe/watchCr` del
  `FinancialStateService` siguen funcionando.
- **RT-03**: `EntriesDao.watchPage(limit: 10)` sin `accountIds`
  sigue devolviendo el consolidado.
- **RT-04**: `EntriesDao.watchPage(limit: 10, accountIds: [X])`
  sigue devolviendo solo movimientos de X.
- **RT-05**: los tabs de `/reports` no cambian.

## Pruebas manuales o smoke tests necesarios

- **SM-01 (vista Hoy)**: abrir dashboard → ver card con fecha del día
  + 3 montos. Sin movimientos hoy → `$0 · $0 · Neto $0` en gris.
- **SM-02 (sparkline)**: los 3 cards BO/DE/CR muestran línea fina
  debajo del balance. Con datos reales las líneas reflejan la
  evolución.
- **SM-03 (filtro rápido)**: tapear chip de cuenta → lista se filtra.
  Tapear "Todas" → vuelve al consolidado.
- **SM-04 (reactividad)**: registrar income de hoy → vista "Hoy"
  recalcula, sparkline de BO refleja nuevo saldo del día, lista se
  actualiza si el chip incluye la cuenta.
- **SM-05 (archivar cuenta filtrada)**: filtrar por cuenta X →
  archivar X → chip desaparece + filtro vuelve a "Todas".
- **SM-06 (persistencia)**: filtrar por X → cerrar app → reabrir →
  chip "Todas" seleccionado (state en memoria).
- **SM-07 (medianoche automática)**: dashboard abierto justo antes
  de las 00:00 local → cruzar medianoche sin tocar la pantalla →
  vista "Hoy" se refresca sola a `$0 · $0 · Neto $0` (fecha del día
  nuevo) y sparklines corren su ventana 30d un día. Sin necesidad
  de salir/entrar del dashboard.

## Datos de prueba recomendados

Setup UT (in-memory BD):

- Bolsa (seed default) + 1 debit `Banamex` + 1 credit `Visa` con
  `creditLimit=50000`.
- Categorías básicas del seed.
- Sembrar movimientos con `occurredAt` puntual (`DateTime.now()`
  para hoy, `DateTime.now().subtract(Duration(days: N))` para
  histórico).

Setup widget test (`pumpFincoreApp` con `seed`):

- Similar pero con anchor de hoy.
- 1 income + 1 expense del día para blindar vista "Hoy".
- 2-3 movimientos históricos para que las sparklines tengan datos.
- 1 movimiento en cada cuenta (Bolsa, Banamex, Visa) para poder
  filtrar por chip.

## Comandos o validaciones locales sugeridas

```bash
cd mobile
flutter analyze
flutter test test/data/reports_test.dart --plain-name 'dashboard-bundle'
flutter test test/screens/dashboard_screen_test.dart
flutter test
flutter build apk --release --split-per-abi
../scripts/verify-apk.sh
~/Android/Sdk/platform-tools/adb install -r build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

## Criterios minimos para aprobar la implementacion

- 15 tests nuevos verdes (7 UT Today + 7 UT Sparkline + 5 widget +
  ajustes menores).
- `flutter test` completo ≥ 584 verdes (572 baseline + 12).
- `flutter analyze` limpio.
- APK release OK; `verify-apk.sh` OK con `versionCode 2093 /
  versionName 0.19.0`.
- SM-01..07 confirmados por Diego en cel real.

## Validacion final recomendada

Ejecutar `branch-quality-review` con slug `flutter-dashboard-bundle-v1`
antes del commit final. Foco:

- Correctness de `_computeDailyBalance` (fase inicial + acumulación
  + backfill).
- Semántica cash/debit vs credit (invertida) del sparkline.
- Layout responsive del `_TotalCard` con sparkline en cel angosto.
- Manejo del archive de cuenta seleccionada.
- Reactividad de los 3 sparklines simultáneos sin cuelgues.
- Regresión de tests existentes del dashboard.

Si no está disponible, checklist manual:

1. `git diff HEAD` acotado.
2. `flutter analyze` limpio.
3. `flutter test` verde ≥ 584.
4. UT-TD07 y UT-SP07 usan `emitsThrough`.
5. Sparkline con dataset típico < 30ms.
6. Version bump coincide en `pubspec.yaml` y `build.gradle.kts`.
