# Plan de pruebas — flutter-reports-credit-cards-v1

## Casos borde detectados

- **CB-D01**: BD real con 3 cuentas credit con `credit_limit=null` + 2 cuentas debit con `credit_limit=null` → migración v4→v5 rellena las 5 a 0. Cero pérdida de datos.
- **CB-D02**: Migración v4→v5 sobre BD con FKs (`journal_entries` apunta a `accounts`) → recreación de tabla `accounts` mantiene las FKs y los índices sin romper referencias.
- **CB-D03**: `onUpgrade(m, 4, 5)` corrido dos veces → segunda corrida idempotente (no rompe aunque en producción esto no ocurre).
- **CB-D04**: Backup JSON v1 con `credit_limit=null` para 3 cuentas credit → import ajusta a 0, incrementa `adjustedAccountsCount = 3`, emite snackbar con el conteo.
- **CB-D05**: Backup JSON v1 con `credit_limit=-100` para 1 cuenta credit → import rechaza con `invalid_credit_limit`.
- **CB-D06**: Backup JSON v1 con `credit_limit=0` para 1 cuenta credit → import acepta (antes rechazaba, ahora es válido).
- **CB-D07**: DAO `create` con `type='credit'` y `creditLimit=null` → error tipado `invalid_credit_limit`, mensaje en español.
- **CB-D08**: DAO `updateAccount` de una cuenta credit existente pasando `creditLimit: null` explícito → error tipado. Pasando `creditLimit: Value.absent()` (no tocar) → OK.
- **CB-D09**: Servicio `watchCreditCards()` sobre BD sin cuentas credit activas → emite lista vacía.
- **CB-D10**: Servicio `watchCreditCards()` sobre BD con 2 cuentas credit archivadas + 1 activa → emite lista con solo la activa.
- **CB-D11**: `nextOccurrenceOfDay(hoy, 31)` cuando el mes actual es febrero de año no bisiesto → devuelve 28 de febrero.
- **CB-D12**: `nextOccurrenceOfDay(hoy, 29)` cuando el mes actual es febrero de año bisiesto (ej. 2024) → devuelve 29 de febrero.
- **CB-D13**: `nextOccurrenceOfDay(2024-01-15, 15)` → devuelve 2024-01-15 (mismo día, "Hoy").
- **CB-D14**: `nextOccurrenceOfDay(2024-01-16, 15)` → devuelve 2024-02-15.
- **CB-D15**: `nextOccurrenceOfDay(2024-12-31, 5)` cruzando año → devuelve 2025-01-05.
- **CB-D16**: `nextOccurrenceOfDay(2024-01-30, 31)` cuando febrero-siguiente es no bisiesto → devuelve 2024-01-31 (mismo mes primero).
- **CB-D17**: Tarjeta con `debt > credit_limit` (excedido) → `usedPct = 100`, `isOverdue = true`, `availableCredit = 0`.
- **CB-D18**: Tarjeta con `debt = 0` y `minimumPaymentPct = 5` → `minimumPayment = 0`, `isDebtFree = true`, card muestra badge "Sin deuda".
- **CB-D19**: Tarjeta con `debt = 0` y `credit_limit = 0` → `usedPct = null`, `availableCredit = 0`, `isDebtFree = true`.
- **CB-D20**: Registrar `credit_expense` sobre una tarjeta con el reporte abierto → el `CreditCardStatus` correspondiente re-emite con nueva deuda y pago mínimo.
- **CB-D21**: Editar `credit_limit` de una tarjeta desde `AccountFormScreen` con el reporte abierto en otro tab → al volver al reporte, la card refleja el nuevo límite y % usado.
- **CB-D22**: `AccountFormScreen` con `_type=cash` → los 5 campos credit-only (incluidos los 2 nuevos) están ocultos.
- **CB-D23**: `AccountFormScreen` con `_type=credit` y usuario deja `_minPaymentPctCtrl` vacío → save exitoso con `minimumPaymentPct=null`.
- **CB-D24**: `AccountFormScreen` con `_type=credit` y usuario escribe `_minPaymentPctCtrl='abc'` → validator rechaza.
- **CB-D25**: `AccountFormScreen` con `_type=credit` y usuario escribe `_minPaymentPctCtrl='150'` → validator rechaza (fuera de 0-100).
- **CB-D26**: `AccountFormScreen` con `_type=credit` y usuario escribe `_interestRateCtrl='250'` → validator rechaza (fuera de 0-200).
- **CB-D27**: Tab "Tarjetas" con 5 tarjetas: 3 con deuda (fechas de pago 5/15/25), 2 sin deuda (alfabético "Amex", "Banorte") → orden es (pago-5, pago-15, pago-25, Amex, Banorte).
- **CB-D28**: Onboarding slide 3 muestra 6 filas de reportes (5 previas + "Estado de tarjetas") y el párrafo dice "6 reportes".
- **CB-D29**: HelpScreen FAQ "¿Cómo se calculan los reportes?" menciona los 6 tabs.

## Pruebas unitarias necesarias

- **UT-01** DAO — `AccountsDao.create(type: 'credit', creditLimit: null)` lanza `AccountsDaoError('invalid_credit_limit')`.
- **UT-02** DAO — `AccountsDao.updateAccount(id, creditLimit: null)` sobre credit activa lanza `invalid_credit_limit`.
- **UT-03** DAO — `create(type: 'credit', creditLimit: 0)` OK (0 es válido).
- **UT-04** DAO — `create(type: 'cash', creditLimit: null)` OK (no aplica validación).
- **UT-05** Servicio — `watchCreditCards()` sobre BD vacía emite lista vacía.
- **UT-06** Servicio — `watchCreditCards()` con 1 tarjeta sin metadata (`closingDay=null`, `paymentDay=null`, `minimumPaymentPct=null`) → emite `CreditCardStatus` con `nextClosingDate=null`, `nextPaymentDate=null`, `minimumPayment=null`.
- **UT-07** Servicio — `watchCreditCards()` con 3 cuentas (2 credit activas + 1 credit archivada) → emite lista con 2 elementos.
- **UT-08** Servicio — orden correcto por RN-CC09 con mix de tarjetas con y sin deuda.
- **UT-09** Servicio — `usedPct` correcto para deuda=50, límite=100 → 50.0.
- **UT-10** Servicio — `usedPct = null` para credit_limit=0.
- **UT-11** Servicio — `isOverdue=true` para deuda=150, límite=100.
- **UT-12** Servicio — reactividad: dentro de un `Stream.first` posterior a registrar un `credit_expense` que sube la deuda, el `CreditCardStatus` refleja la nueva deuda.
- **UT-13** Helper — `nextOccurrenceOfDay` en 15 casos:
  - Mismo día del mes (hoy.day == targetDay) → hoy.
  - Día futuro del mes actual → mismo mes.
  - Día ya pasado del mes actual → mes siguiente.
  - Target > días del mes destino (31 en abril) → clamp al 30.
  - Target = 29 en febrero no bisiesto → 28.
  - Target = 29 en febrero bisiesto → 29.
  - Cambio de año (diciembre → enero).
- **UT-14** Migración — `onUpgrade(m, 4, 5)` sobre BD con 3 credits con `credit_limit=null` → post-migración las 3 tienen `credit_limit=0` y no se pueden insertar null.
- **UT-15** Migración — `onUpgrade(m, 3, 5)` (defensiva) → crea tabla `app_preferences` primero, luego aplica cambio de credit_limit.
- **UT-16** Migración — `onUpgrade(m, 2, 5)` → crea `saved_views`, luego `app_preferences`, luego cambio credit_limit.
- **UT-17** Migración — `onUpgrade(m, 1, 5)` → crea índice de journal_entries, `saved_views`, `app_preferences`, luego cambio credit_limit.
- **UT-18** Migración — preserva `journal_entries` con FK a `accounts` post-recreación de tabla.
- **UT-19** Migración — idempotencia: correr `onUpgrade(m, 4, 5)` sobre BD ya migrada no rompe.

## Pruebas de integracion o API necesarias

No aplica — la app es Flutter local sin API HTTP. La equivalencia son las pruebas de widget + data layer cubiertas arriba.

## Pruebas de UI o flujo necesarias si aplica

- **WT-01** `CreditCardsTab` — con 0 tarjetas credit activas → renderea empty state con texto "Aún no tenés tarjetas de crédito" y botón "Agregar tarjeta". Tap navega a `/accounts/new`.
- **WT-02** `CreditCardsTab` — con 2 tarjetas con datos completos → renderea 2 cards con: nombre, deuda formateada en MXN, % usado, disponible, próximo corte, próximo pago, pago mínimo estimado.
- **WT-03** `CreditCardsTab` — tarjeta sin `minimumPaymentPct` → no muestra la línea de pago mínimo.
- **WT-04** `CreditCardsTab` — tarjeta sin `closingDay` → muestra "—" en próximo corte.
- **WT-05** `CreditCardsTab` — tarjeta con `debt=0` → badge "Sin deuda", sin línea de pago mínimo.
- **WT-06** `CreditCardsTab` — tarjeta con `debt > creditLimit` → badge "Excedido por $X" en color negativo.
- **WT-07** `CreditCardsTab` — reactividad: registrar un `credit_expense` desde el harness mientras el widget está montado → la card re-buildea con nueva deuda.
- **WT-08** `AccountFormScreen` — form con `_type=credit` muestra los 5 campos (creditLimit, closingDay, paymentDay, minimumPaymentPct, interestRate).
- **WT-09** `AccountFormScreen` — form con `_type=cash` NO muestra los 5 campos credit-only.
- **WT-10** `AccountFormScreen` — crear cuenta credit sin `creditLimit` → submit rechazado con snackbar `invalid_credit_limit`.
- **WT-11** `AccountFormScreen` — crear cuenta credit con `creditLimit=0`, `minimumPaymentPct=5`, `interestRate=45` → save exitoso, cuenta persiste con esos valores.
- **WT-12** `AccountFormScreen` — editar cuenta credit existente sin cambiar `minimumPaymentPct` → save exitoso, valor no cambia.
- **WT-13** `OnboardingScreen` slide 3 — verifica que aparecen 6 filas de reportes (5 previas + "Estado de tarjetas") y el párrafo dice "6 reportes".
- **WT-14** `HelpScreen` — FAQ "¿Cómo se calculan los reportes?" incluye texto sobre "Estado de tarjetas".
- **WT-15** `ReportsScreen` — el `TabBar` renderea 6 tabs.

## Pruebas de permisos y seguridad si aplica

No aplica. App single-user local sin autorización.

## Pruebas de datos, migracion o compatibilidad si aplica

- **DT-01** Import backup JSON v1 con `credit_limit=null` en 3 cuentas credit → `adjustedAccountsCount=3`, cuentas persisten con `credit_limit=0`.
- **DT-02** Import backup JSON v1 con `credit_limit=-50` → rechaza con `invalid_credit_limit`.
- **DT-03** Import backup JSON v1 con `credit_limit=0` → acepta.
- **DT-04** Import backup JSON v1 sin cuentas credit → `adjustedAccountsCount=0`, snackbar sin línea de ajustes.
- **DT-05** Round-trip: exportar → wipeAll → importar → estado idéntico (incluye `credit_limit` con valor no-null en cada credit).
- **DT-06** Export JSON post-sprint contiene `credit_limit` en cada cuenta (nunca omitido).

## Pruebas de regresion sobre flujos existentes

- **RT-01** Los 5 reportes existentes (Gasto por categoría, Cashflow mensual, Top movimientos, Saldo a fecha, Promedio mensual) siguen renderizando sin cambio.
- **RT-02** Dashboard sigue mostrando BO/DE/CR correcto post-migración.
- **RT-03** Registrar los 5 kinds sigue funcionando (income, expense, credit_expense, debt_payment, transfer).
- **RT-04** `SettingsScreen._import` sigue funcionando cuando el backup no requiere ajustes.
- **RT-05** Vistas guardadas en `/entries` siguen funcionando post-migración de schema.
- **RT-06** Onboarding slide 1 y 2 sin cambio.
- **RT-07** El helper de fechas nuevo no interfiere con otros usos de `DateTime` en la app.
- **RT-08** Test de widget del `OnboardingScreen` (WT-O01..WT-O06) sigue pasando post-actualización del slide 3.
- **RT-09** Test de widget del `HelpScreen` (WT-H*) sigue pasando post-actualización del FAQ.

## Pruebas manuales o smoke tests necesarios

- **SM-01**: Diego actualiza APK sobre BD real con 1+ tarjetas activas → migración corre sin error visible, todas las tarjetas siguen presentes con sus balances correctos.
- **SM-02**: Diego abre `/reports` → ve 6 tabs, el nuevo "Tarjetas" es visible con scroll horizontal.
- **SM-03**: Diego abre el tab "Tarjetas" → ve una card por cada tarjeta activa con la deuda actual coincidiendo con la que ve en `/accounts` y en el dashboard (BO/DE/CR).
- **SM-04**: Diego registra un `credit_expense` desde el FAB → vuelve al reporte y ve que la card actualizó deuda + pago mínimo.
- **SM-05**: Diego edita una tarjeta y setea `minimumPaymentPct=5` + `interestRate=45` → guarda, vuelve al reporte y ve el pago mínimo estimado.
- **SM-06**: Diego archiva una tarjeta con deuda 0 → desaparece del reporte.
- **SM-07**: Diego abre `Settings → Ayuda → Ver tour de bienvenida` → slide 3 muestra 6 reportes.
- **SM-08**: Diego intenta importar un backup viejo (pre-sprint) con `credit_limit=null` → snackbar reporta N cuentas ajustadas.
- **SM-09**: Tester en cel limpio instala APK → onboarding slide 3 dice "6 reportes"; tab Tarjetas muestra empty state con CTA.

## Datos de prueba recomendados

Para tests unitarios/widget del `CreditCardsTab`, sembrar via `pumpFincoreApp` helper `seed`:

- **Seed A** — sin tarjetas credit: solo Bolsa (`type=cash`). Espera empty state.
- **Seed B** — 1 tarjeta completa: `credit_limit=10000`, `closingDay=15`, `paymentDay=5`, `minimumPaymentPct=5`, `interestRate=45`. Registrar 1 `credit_expense` de $3500 para tener deuda. Espera card con % usado = 35%.
- **Seed C** — 3 tarjetas con distintos escenarios:
  - "Amex Gold": completa, `debt=8000`, `paymentDay=5` → primera por proximidad.
  - "Banorte Clásica": sin `closingDay`, `debt=2000`, `paymentDay=15` → segunda por proximidad.
  - "Palacio": `credit_limit=0`, `debt=500` → tercera con "—" en %.
- **Seed D** — 2 tarjetas sin deuda: `debt=0` cada una. Espera orden alfabético al final.

## Comandos o validaciones locales sugeridas

```bash
cd mobile

# 1. Regenerar código drift tras cambiar schema
dart run build_runner build --delete-conflicting-outputs

# 2. Analyzer
flutter analyze

# 3. Tests completos
flutter test

# 4. Test específico de migración (rápido durante desarrollo)
flutter test test/data/database_test.dart

# 5. Build APK release y verify
flutter build apk --release --split-per-abi
bash ../scripts/verify-apk.sh

# 6. Install en cel de Diego para smokes
~/Android/Sdk/platform-tools/adb install -r \
  build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

## Criterios minimos para aprobar la implementacion

- `flutter analyze` en 0 errores (los 4 hints info pre-existentes tolerados).
- `flutter test` verde. Objetivo ≥ 385 tests (367 previos + ≥ 18 nuevos entre UT/WT/DT).
- Migración v4→v5 idempotente y con preservación de datos verificada en UT-14..UT-19.
- Backup round-trip verde (DT-05).
- `verify-apk.sh` OK con versionCode 71 / versionName 0.13.0.
- SM-01 y SM-03 confirmados por Diego en cel real antes de cerrar el sprint.

## Validacion final recomendada

Al terminar la implementación, invocar la skill `branch-quality-review` con slug `flutter-reports-credit-cards-v1` para revisión exhaustiva de rama antes del commit final. El reporte va a `engineering/quality-review/flutter-reports-credit-cards-v1/YYYY-MM-DD-HHMM-branch-quality-review.md`.

Si no está disponible el skill, la checklist equivalente es:

- Sin `TODO` sin resolver en los archivos tocados.
- Sin `print()` o `debugPrint()` de debug olvidados.
- Sin dependencies nuevas fuera de lo declarado en el plan.
- Sin hits de `grep -r "creditLimit ?? " mobile/lib/` que quedaron con default cosmético post-migración.
- Sin regresiones en los 5 reportes existentes (correr los tests de sus `_test.dart` explícitamente).
- Sin cambios accidentales en `android/app/src/main/res/` (splash, íconos).
