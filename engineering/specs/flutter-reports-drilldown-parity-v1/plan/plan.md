# Plan técnico — flutter-reports-drilldown-parity-v1

## Enfoque tecnico

Sprint correctivo puro sobre la capa de datos. Dos cambios pequeños y ortogonales, más tests que validan la paridad entre reporte y drill-down.

1. **`ReportsService.spendingByCategory`** (`mobile/lib/data/reports.dart:151-167`): agregar `AND c.applies_to != 'income'` al `ON` del `LEFT JOIN categories`. Deja el SQL simétrico al de `incomeByCategory` (que ya tiene el filtro opuesto `!= 'expense'`).
2. **`EntriesDao.watchPage`** (`mobile/lib/data/daos/entries_dao.dart:118-137`): refactor pequeño de la rama que maneja `kUncategorizedFilterToken`. Extraer una expresión helper `Expression<bool> uncategorizedCondition` que dependa del conjunto efectivo de `kinds`:
   - `kinds == ['income']` → `categories.id.isNull() | categories.appliesTo.equals('expense')`
   - `kinds ⊆ {'expense', 'credit_expense'}` y no vacío → `categories.id.isNull() | categories.appliesTo.equals('income')`
   - resto → `categories.id.isNull()` (comportamiento actual)
3. **Tests** (`mobile/test/data/`): 9 tests nuevos que cubren cada rama de la lógica + paridad `report.count == drillDown.length` en 2 escenarios.
4. **`CLAUDE.md`**: actualizar la sección "Reglas clave de los DAOs" con la nueva convención de `kUncategorizedFilterToken`.
5. **Version bump**: `0.15.0+77` → `0.15.0+78` en `mobile/pubspec.yaml` y `mobile/android/app/build.gradle.kts`.
6. **APK release + verify** al cierre.

Diseño respeta el principio del sprint: aditivo, sin schema bump, sin cambios de UI ni de rutas, cero regresión sobre callers que no usan el token.

## Requisitos funcionales cubiertos

- **RF-001** (SQL de `spendingByCategory` con filtro simétrico): T003.
- **RF-002** (expansión del `where` en `watchPage` para kinds `= {income}`): T004.
- **RF-003** (expansión para kinds `⊆ {expense, credit_expense}`): T004.
- **RF-004** (comportamiento inalterado en RN-P03): T004 (rama default) + UT-DP04 y UT-DP05.
- **RF-005** (unión disyuntiva con ids reales): T004 + UT-DP09.
- **RF-006** (tests de paridad `income`): T006 (UT-DP01, UT-DP08).
- **RF-007** (tests de paridad `spending`): T006 (UT-DP02, UT-DP03, UT-DP06, UT-DP07).
- **RF-008** (documentación en `CLAUDE.md`): T008.

## Archivos o modulos probablemente afectados

Confirmados por lectura previa:

- `mobile/lib/data/reports.dart` — SQL de `spendingByCategory` (línea 161).
- `mobile/lib/data/daos/entries_dao.dart` — bloque de token en `watchPage` (líneas 118-137).
- `mobile/test/data/reports_test.dart` — grupo `spendingByCategory` y `incomeByCategory` para tests de paridad.
- `mobile/test/data/entries_dao_test.dart` (a confirmar el nombre exacto; probablemente exista) — tests del token en `watchPage`.
- `mobile/pubspec.yaml` — bump `version: 0.15.0+78`.
- `mobile/android/app/build.gradle.kts` — bump `versionCode = 78`, `versionName = "0.15.0"`.
- `CLAUDE.md` — actualización de la subsección "Reglas clave de los DAOs".

Por confirmar durante la implementación:

- Existencia y ruta exacta del test file del DAO (buscar en `mobile/test/data/`).
- Si algún widget test de `entries_filters_screen_test.dart` toca el token de "Sin categoría" combinado con kinds, revisar si sigue verde tras el cambio.

## Entidades y estados afectados

- **JournalEntry**: sin cambios. Sigue con `category_id` nullable y `kind ∈ {income, expense, credit_expense, debt_payment, transfer}`.
- **Category**: sin cambios de schema. Se sigue usando `applies_to ∈ {income, expense, both}` como filtro discriminante. El cambio de `applies_to` de una categoría existente sigue siendo una operación soportada por `CategoriesDao.updateCategory` y expuesta por la UI.
- **Estado "Sin categoría"**: cambia su definición operativa dentro del DAO cuando el filtro está restringido a un único tipo de flujo. Antes: `journal_entries.category_id IS NULL OR categoría archivada`. Después (en RN-P01/P02): `journal_entries.category_id IS NULL OR categoría archivada OR categoría con applies_to opuesto al kind`.
- **Invariante**: el bucket "Sin categoría" del reporte y el drill-down desde ese bucket comparten la misma definición operativa. Antes se rompía en el edge (3); ahora no.

## Compatibilidad con datos y procesos existentes

- **Datos históricos**: si Diego tiene alguna entry con edge (3) en la BD actual, tras el update empezará a comportarse consistentemente (aparece en "Sin categoría" y también en el drill-down). No requiere migración: el cambio es puramente en la query.
- **Callers de `watchPage`**:
  - `/entries` (screen + drill-down desde reportes): sensible al cambio, es el objetivo del sprint.
  - Dashboard: usa `watchPage` sin filtro de categoría; RN-P03 aplica (comportamiento inalterado).
  - Otros consumidores del DAO: verificar durante implementación que ninguno pasa el token con `kinds=null` o mixto esperando el comportamiento viejo.
- **Reportes vecinos**: `topMovements`, `cashflowByMonth`, `watchBudgetsProgress`, `monthlyAverage`, `watchCreditCards` no leen el token; sin impacto.
- **Import de backup JSON v1**: sin impacto. El schema y el formato JSON no cambian.
- **Reactividad**: al cambiar `applies_to` de una categoría, drift re-emite tanto en el reporte (declara `readsFrom: {journalEntries, categories}`) como en `watchPage` (joinea `categories`). Verificado en el diseño.

## Cambios de datos si aplica

No aplica. Sin cambios de schema, sin `ALTER TABLE`, sin migración. Sprint aditivo puro en query layer.

## Cambios de API si aplica

No aplica. La firma pública de `spendingByCategory` y `watchPage` queda idéntica. El cambio es interno a la lógica de la query.

## Cambios de integraciones si aplica

No aplica. No hay integraciones externas (app local-first single-user).

## Cambios de UI si aplica

No aplica. Cero cambio visual. La feature se percibe como una corrección de correctness.

## Cambios de permisos si aplica

No aplica. App single-user.

## Riesgos tecnicos

- **R1 — Ambiguedad en el conjunto efectivo de kinds**: la lógica debe distinguir "kinds vacío / null" de "kinds contiene solo income" con un set literal comparable. Usar `Set<String>` comparado con `{'income'}` y con subset de `{'expense', 'credit_expense'}`. Cubrir con UT-DP04 y UT-DP05.
- **R2 — Reactividad al cambiar `applies_to`**: el stream `watchPage` debe re-emitir cuando el `applies_to` de una categoría cambia. drift lo hace automáticamente porque el LEFT JOIN a `categories` declara la dependencia; se verifica indirectamente con UT-DP01/02 (que registran, cambian applies_to, y esperan re-emit).
- **R3 — Combinación con ids reales**: el escenario RF-005 (unión disyuntiva) debe agrupar correctamente entre `IN (realIds)` y la condición extendida del token. Cubrir con UT-DP09.
- **R4 — Regresión en filtros manuales de `/entries`**: un usuario que abra `/entries` desde el FAB y tickee manualmente "Sin categoría" + kind income verá comportamiento diferente al de hoy. Es el objetivo, no un bug — documentar en `CLAUDE.md` que el token es semanticamente "sin categoría dentro de este tipo de flujo".
- **R5 — Regresión en Dashboard**: el Dashboard usa `watchPage` sin filtro de categoría; RN-P03 aplica y el comportamiento no cambia. Verificar con smoke que la lista de últimos movimientos sigue igual.

## Estrategia de pruebas

Ver `test-plan.md` para el detalle.

Foco: unitarios de data layer (9 tests). Sin widget tests nuevos (cero cambio de UI). Smoke manual al final para verificar los 2 escenarios reales del usuario.

## Estrategia de rollback

- Revert del commit del sprint es limpio: los 3 cambios (spendingByCategory, watchPage, docs) están en el mismo commit y son ortogonales al resto.
- Ninguna migración de datos, así que revert no deja BD en estado intermedio.
- APK release: si el bump `0.15.0+78` genera algún problema en cel, `adb install -r` con el APK `0.15.0+77` desinstala el nuevo automáticamente (no hay downgrade permitido por Android, así que hay que desinstalar y reinstalar el 77).
- Si se detecta un edge no cubierto post-merge, un hotfix se puede aplicar en un mini-sprint corto — el diseño no obliga a rollback total.

## Orden sugerido de implementacion

1. **T001**: leer el archivo de tests del DAO para conocer el patrón exacto de setUp (probablemente `mobile/test/data/entries_dao_test.dart`).
2. **T002**: identificar helper para "kinds subset" — evaluar si conviene extraerlo o inline (lookup rápido en el archivo).
3. **T003**: cambio de 1 línea en el SQL de `spendingByCategory` (`reports.dart`).
4. **T004**: refactor del bloque del token en `watchPage` (`entries_dao.dart`).
5. **T005**: correr `flutter analyze` y `flutter test` para confirmar 452 verdes.
6. **T006**: agregar los 9 tests nuevos (UT-DP01..09) y verificar verdes.
7. **T007**: actualizar CLAUDE.md.
8. **T008**: bump de versión `0.15.0+78` y build APK release + verify-apk.sh.
9. **T009**: smoke manual (Diego) — 2 escenarios reales.
10. **T010**: `branch-quality-review`.
11. **T011**: commit final.

## Casos borde que condicionan la solucion

- `kinds` con `null` o vacío + token → NO expandir (RN-P03).
- `kinds` mixto income+expense + token → NO expandir (RN-P03).
- `kinds` con `transfer` o `debt_payment` (aislados o mezclados) + token → NO expandir (RN-P03). Semánticamente el desglose por categoría no aplica a movimientos internos.
- `kinds` con `credit_expense` solo + token → EXPANDIR con `applies_to='income'` (subconjunto no vacío de kinds de gasto).
- `kinds` con `expense` y `credit_expense` + token → EXPANDIR con `applies_to='income'`.
- `applies_to='both'` en la categoría — nunca cae en el edge (3), sigue matcheando por `journalEntries.categoryId`. Debe pasar los tests que hoy pasan (UT-I04 del sprint income y su análogo del spending).
- Combinación `categoryIds:[realId1, realId2, kUncategorizedFilterToken]` con kind income y con edge (3) presente → unión de `IN (realId1, realId2)` OR condición extendida. UT-DP09.
- Reactividad de `applies_to`: cambio de `applies_to` de una categoría con entries asociadas debe re-emitir en el stream. Cubierto por drift default.

## Preguntas o supuestos que siguen afectando la implementacion

Ninguna pregunta bloqueante.

Supuestos que se documentaron en la spec y se mantienen:

- La UI del form de categoría permite editar `applies_to` de una categoría existente con entries asociadas.
- El comportamiento del token en `kinds=null` o mixto es correcto y no se cambia.
- Los tests unitarios del DAO usan el patrón estándar de `NativeDatabase.memory()` con el override de `libsqlite3.so.0` para Linux desktop (verificar en T001).
