# Plan de pruebas — flutter-reports-drilldown-parity-v1

## Casos borde detectados

- **CB-01**: `kinds=['income']` + token → expandir con `applies_to='expense'`.
- **CB-02**: `kinds=['expense']` + token → expandir con `applies_to='income'`.
- **CB-03**: `kinds=['credit_expense']` + token → expandir con `applies_to='income'`.
- **CB-04**: `kinds=['expense', 'credit_expense']` + token → expandir con `applies_to='income'`.
- **CB-05**: `kinds=null` + token → NO expandir (comportamiento actual).
- **CB-06**: `kinds=[]` + token → NO expandir (equivale a null en el DAO por el `effectiveKinds`).
- **CB-07**: `kinds=['income', 'expense']` + token → NO expandir (mixto ingreso+gasto).
- **CB-08**: `kinds=['transfer']` + token → NO expandir (movimiento interno, semántica del desglose no aplica).
- **CB-09**: `kinds=['debt_payment']` + token → NO expandir.
- **CB-10**: `kinds=['income', 'transfer']` + token → NO expandir (mixto con no-income puro).
- **CB-11**: `categoryIds=[realId, kUncategorizedFilterToken]` + `kinds=['income']` con edge (3) sembrado → unión: entries de `realId` OR entries del edge.
- **CB-12**: entry con `category_id` NULL + `kinds=['income']` + token → incluye (sigue funcionando el caso base 1).
- **CB-13**: entry con categoría archivada (soft delete) + `kinds=['income']` + token → incluye (sigue funcionando el caso base 2).
- **CB-14**: categoría con `applies_to='both'` + income entry + token → NO cae en el bucket (la unión no incluye applies_to='both'; matchea por `categoryId`).
- **CB-15**: al cambiar `applies_to` de una categoría con entries asociadas mientras hay un stream activo → `watchPage` debe re-emitir.
- **CB-16**: `spendingByCategory` con expense + categoría `applies_to='income'` (edge legacy inverso) → cae en el bucket "Sin categoría" del reporte (nuevo comportamiento simétrico a `incomeByCategory`).
- **CB-17**: paridad `spendingByCategory.buckets['Sin categoría'].count == watchPage(kinds:['expense','credit_expense'], categoryIds:['__null__']).length` con dataset que incluye edge (3).
- **CB-18**: paridad `incomeByCategory.buckets['Sin categoría'].count == watchPage(kinds:['income'], categoryIds:['__null__']).length` con dataset que incluye edge (3).

## Pruebas unitarias necesarias

Sobre `mobile/test/data/reports_test.dart`:

- **UT-DP01** (grupo `incomeByCategory` extendido): paridad income con edge (3): sembrar 1 income con categoría A `applies_to='income'`, cambiar A a `applies_to='expense'` vía `categoriesDao.updateCategory` (o `customStatement` si el DAO valida). Verificar `report.buckets[0].name == 'Sin categoría'`, `report.buckets[0].count == 1`. Luego llamar `entriesDao.watchPage(kinds:['income'], categoryIds:['__null__'], from, to).first` y verificar `length == 1`.
- **UT-DP02** (grupo `spendingByCategory` extendido, análogo): paridad spending con edge (3) inverso: sembrar 1 expense con categoría B `applies_to='expense'`, cambiar B a `applies_to='income'`. Verificar bucket "Sin categoría" con count=1 en el reporte y `watchPage(kinds:['expense'], categoryIds:['__null__']).length == 1`. CB-16 + CB-17.
- **UT-DP03** (grupo `spendingByCategory`): mismo escenario que UT-DP02 pero con `kinds:['expense','credit_expense']` → confirmar que los 2 kinds de gasto expanden igual. CB-04.
- **UT-DP04** (grupo `spendingByCategory` regresión): mismo dataset con edge (3) sembrado, pero llamar `watchPage(kinds:null, categoryIds:['__null__'])` → NO incluye el edge (3). CB-05.
- **UT-DP05** (grupo `spendingByCategory` regresión): `watchPage(kinds:['income','expense'], categoryIds:['__null__'])` con edge (3) sembrado → NO incluye el edge (3). CB-07.

Sobre `mobile/test/data/entries_dao_test.dart` (o el archivo equivalente si existe; buscar en T001):

- **UT-DP06** (grupo del token en watchPage): CB-14 — categoría con `applies_to='both'` + income entry + token → NO incluye la entry (no cae en el bucket).
- **UT-DP07** (grupo del token): CB-11 — combinación `categoryIds:[realId, '__null__']` + `kinds:['income']` con dataset que tiene entries de `realId` y entries del edge (3) → resultado es la unión.
- **UT-DP08** (grupo del token): CB-08 — `kinds:['transfer']` + token → NO expande.
- **UT-DP09** (grupo del token): CB-15 — reactividad: suscribirse a `watchPage(kinds:['income'], categoryIds:['__null__'])`, cambiar `applies_to` de una categoría con 1 income asociado → verificar re-emit con la entry ahora incluida. Usar `emitsThrough` para evitar flakiness.

## Pruebas de integracion o API necesarias

No aplica. App local-first sin API expuesta.

## Pruebas de UI o flujo necesarias si aplica

No aplica. Sprint sin cambio de UI. Los widget tests existentes de `entries_filters_screen_test.dart`, `income_by_category_tab_test.dart` y `spending_by_category_tab_test.dart` (si existiera este último) deben seguir verdes.

## Pruebas de permisos y seguridad si aplica

No aplica. App single-user.

## Pruebas de datos, migracion o compatibilidad si aplica

No aplica. Sin schema bump.

## Pruebas de regresion sobre flujos existentes

- **RT-01**: `flutter test` completo. 452 tests actuales deben quedar verdes; con los 9 nuevos el total esperado es ≥ 461.
- **RT-02**: los 30 tests del grupo `spendingByCategory` en `reports_test.dart` (UT-01..30 aprox) siguen verdes tras el cambio del JOIN.
- **RT-03**: los tests del token de `entries_dao_test.dart` que hoy pasan con `kinds=null` siguen verdes (RN-P03 preserva ese path).
- **RT-04**: el test WT-15 de `credit_cards_tab_test.dart` (8 tabs) sigue verde.

## Pruebas manuales o smoke tests necesarios

- **SM-01**: en el cel de Diego, en un ambiente con al menos 1 income registrado con una categoría, entrar a Categorías → editar esa categoría → cambiar `applies_to` de `income` (o `both`) a `expense`. Ir a `/reports` → tab "Ingreso por categoría" → confirmar bucket "Sin categoría" con el count esperado. Tap → `/entries` lista exactamente el mismo número de entries.
- **SM-02**: simétrico para gastos. Editar una categoría de expense a income y verificar tab "Gasto por categoría" + drill-down.
- **SM-03**: Dashboard sigue mostrando los últimos movimientos igual que antes (RN-P03, `kinds=null`).
- **SM-04**: en `/entries` (accediendo desde el FAB, sin filtro pre-cargado), tickear manualmente "Sin categoría" en el sheet de filtros y agregar filtro de kind = income → verificar que la lista incluye ahora las entries del edge (3). Este es el comportamiento intencional documentado.

## Datos de prueba recomendados

- Bolsa sembrada + 1 cuenta debit + 1 cuenta credit.
- 3 categorías: `Ingreso_A` (`applies_to='income'`), `Gasto_B` (`applies_to='expense'`), `Ambos_C` (`applies_to='both'`).
- Set inicial:
  - 1 income con `Ingreso_A`.
  - 1 income con `Ambos_C`.
  - 1 expense con `Gasto_B`.
  - 1 income sin categoría (caso 1).
  - 1 expense sin categoría (caso 1 simétrico).
- Escenario "edge (3) income": tomar `Ingreso_A` con `updateCategory(appliesTo: 'expense')`. El income con `Ingreso_A` queda como edge (3).
- Escenario "edge (3) expense": simétrico con `Gasto_B` → `applies_to='income'`.
- Alternativa cuando el DAO valida el edge: usar `db.customStatement("INSERT INTO journal_entries ...")` como ya hace UT-I03 de `reports_test.dart`.

## Comandos o validaciones locales sugeridas

```bash
cd mobile
flutter analyze
flutter test test/data/reports_test.dart
flutter test test/data/entries_dao_test.dart  # nombre por confirmar en T001
flutter test
flutter build apk --release --split-per-abi
../scripts/verify-apk.sh 78
~/Android/Sdk/platform-tools/adb install -r build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

Correr `flutter analyze` antes de commit — no debe agregar errores. Los hints info pre-existentes se toleran.

## Criterios minimos para aprobar la implementacion

- 9 tests nuevos verdes (UT-DP01..09).
- `flutter test` completo verde con al menos 461 tests (452 baseline + 9 nuevos; sumar más si algún widget test se ajusta como regresión).
- `flutter analyze` sin errores nuevos.
- APK release compilado y verificado con `verify-apk.sh` (versionCode 2078 con prefix arm64 / versionName 0.15.0).
- Documentación de `CLAUDE.md` actualizada.
- SM-01 y SM-02 verificados por Diego en cel.
- Delta `report.buckets['Sin categoría'].count - drillDown.length == 0` en los smokes.

## Validacion final recomendada

Ejecutar `branch-quality-review` con slug `flutter-reports-drilldown-parity-v1` antes del commit final. La skill genera su propio reporte en `engineering/quality-review/<slug>/` — no duplicar dentro de `implementation/`.

Si por alguna razón la skill no está disponible, ejecutar la checklist equivalente:

1. Revisar diff completo con `git diff HEAD`.
2. Confirmar que no hay archivos de más ni cambios accidentales fuera del alcance (`reports.dart`, `entries_dao.dart`, `reports_test.dart`, `entries_dao_test.dart`, `pubspec.yaml`, `build.gradle.kts`, `CLAUDE.md`).
3. Verificar que la sección de docs en `CLAUDE.md` describe correctamente el nuevo comportamiento del token.
4. Revisar que ninguno de los tests nuevos usa el patrón flaky `Future.delayed` (usar `emitsThrough` o `stream.take(N)`).
