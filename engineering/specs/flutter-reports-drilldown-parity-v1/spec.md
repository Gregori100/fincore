# Paridad reporte ↔ drill-down para el bucket "Sin categoría" (income + spending)

## Resumen

Sprint corto correctivo para cerrar el hallazgo Media/Alta del quality review de `flutter-reports-income-by-category-v1`: el bucket "Sin categoría" del reporte agrega hasta 3 casos (categoría NULL, archivada, o `applies_to` opuesto al kind), pero el drill-down desde el bucket a `/entries` solo cubre 2 de ellos. El resultado es un delta invisible: el reporte muestra "N movimientos", el drill-down lista menos. Simétrico entre los tabs de ingresos y gastos.

También corrige un gap simétrico en `ReportsService.spendingByCategory`: hoy no filtra el edge legacy de gastos con categoría `applies_to='income'` en el JOIN, así que el tab de gastos muestra el nombre de la categoría income-only en el reporte (en lugar de mandarlo al bucket "Sin categoría").

Sprint aditivo puro. Sin schema bump. Sin cambios de UI ni de rutas.

## Problema a resolver

Estado actual verificado en el código:

- `ReportsService.incomeByCategory` (`mobile/lib/data/reports.dart:385-395`) blindaje correcto: `LEFT JOIN categories c ON c.id = j.category_id AND c.deleted_at IS NULL AND c.applies_to != 'expense'`. Cubre los 3 casos "Sin categoría": (1) `j.category_id IS NULL`, (2) categoría archivada, (3) categoría con `applies_to='expense'` (edge legacy).
- `ReportsService.spendingByCategory` (`mobile/lib/data/reports.dart:159-167`) blindaje parcial: `LEFT JOIN categories c ON c.id = j.category_id AND c.deleted_at IS NULL`. Cubre (1) y (2), pero **no** el simétrico (3): un expense con categoría `applies_to='income'` sigue matcheando la categoría real y aparece con el nombre de la income category en el reporte de gastos (en lugar de caer en "Sin categoría").
- `EntriesDao.watchPage` (`mobile/lib/data/daos/entries_dao.dart:99-136`): el LEFT JOIN a `categories` filtra solo `deleted_at IS NULL`. Cuando `categoryIds` contiene `kUncategorizedFilterToken` (constante `'__null__'` en `mobile/lib/constants/filter_tokens.dart:20`), traduce a `categories.id IS NULL` — sólo cubre (1) y (2). El caso (3) queda fuera del drill-down.

Impacto observable:

- Usuario registra ingresos con una categoría `applies_to='income'`.
- Usuario edita la categoría, cambia `applies_to` a `expense` (la UI del form de categoría lo expone).
- En el tab "Ingreso por categoría" esos ingresos aparecen en el bucket "Sin categoría" con su count real.
- Al tapear el bucket, `/entries` con filtro `categoryIds:['__null__']` + `kinds:['income']` los omite → dinero fantasma.
- Simétrico para gastos con categoría cambiada a `applies_to='income'`, con la particularidad extra de que hoy ni siquiera caen en "Sin categoría" del reporte (falta el filtro JOIN).

## Objetivo

Cerrar la brecha de paridad entre el reporte y el drill-down para los dos tabs (`Ingreso por categoría` y `Gasto por categoría`). Al tapear el bucket "Sin categoría" en cualquiera de los dos tabs, `/entries` debe listar exactamente la misma cantidad de movimientos que el bucket reporta. El reporte y el drill-down deben coincidir en su definición operativa de "sin categoría" cuando la consulta al DAO está restringida a un único tipo de flujo (ingresos o gastos).

## Alcance

- SQL de `ReportsService.spendingByCategory` (`mobile/lib/data/reports.dart`): agregar `AND c.applies_to != 'income'` al `ON` del LEFT JOIN (paridad simétrica con `incomeByCategory`).
- `EntriesDao.watchPage` (`mobile/lib/data/daos/entries_dao.dart`): expandir el `where` que hoy genera cuando `categoryIds` incluye `kUncategorizedFilterToken`, para que además de `categories.id IS NULL` incluya el edge (3) cuando el conjunto de kinds del query es puramente ingreso o puramente gasto.
- Tests unitarios (data layer): agregar casos que verifiquen paridad `report.count == drillDownEntries.length` para los 4 escenarios (sin categoría (1)+(2)+(3) sobre spending y sobre income).
- Documentación breve en `CLAUDE.md` sobre la nueva regla operativa de "sin categoría" según la restricción de kinds (queda como convención del DAO).

## Fuera de alcance

- Refactor compartido entre `IncomeByCategoryTab` y `SpendingByCategoryTab`. Los archivos siguen en paralelo.
- Migración de datos existentes (no hay corrupción real; el edge requiere una edición manual del usuario para reproducirse).
- Cambios de UX en el bucket "Sin categoría" o en el drill-down (mismo formato de texto, mismo icono, mismo deep link).
- Ajuste del comportamiento cuando `kinds` es `null` o mezcla ingresos con gastos (queda igual a hoy: token = solo casos 1+2).
- Widget tests nuevos (la lógica es puramente data-layer; los widgets no cambian).
- Cambios en `topMovements`, `cashflowByMonth`, `watchBudgetsProgress`, `monthlyAverage`, `watchCreditCards` o cualquier otro reporte no relacionado.

## Reglas de negocio

- **RN-P01**: en `EntriesDao.watchPage`, cuando `categoryIds` contiene `kUncategorizedFilterToken` y el conjunto efectivo de `kinds` es exactamente `{'income'}`, la condición de "sin categoría" incluye además de `categories.id IS NULL` el caso `categories.applies_to = 'expense'`.
- **RN-P02**: en `EntriesDao.watchPage`, cuando `categoryIds` contiene `kUncategorizedFilterToken` y el conjunto efectivo de `kinds` es subconjunto no vacío de `{'expense', 'credit_expense'}` (sólo tipos de gasto), la condición de "sin categoría" incluye además de `categories.id IS NULL` el caso `categories.applies_to = 'income'`.
- **RN-P03**: en cualquier otro escenario donde el token esté presente (kinds `null`, kinds mixto con income y expense, kinds con `transfer` o `debt_payment`), el comportamiento del token es el actual: solo `categories.id IS NULL`. No se expande porque no hay un "opuesto" semánticamente único.
- **RN-P04**: en el SQL de `spendingByCategory`, el ON del LEFT JOIN queda: `c.id = j.category_id AND c.deleted_at IS NULL AND c.applies_to != 'income'`. Simétrico al que ya tiene `incomeByCategory`.
- **RN-P05**: la unión con IDs reales (cuando el filtro combina el token con ids de categoría concretos) es aditiva: `journalEntries.categoryId IN (realIds) OR (condición extendida de sin categoría)`. Las categorías reales listadas por el usuario tienen precedencia y matchean por `journalEntries.categoryId`; el edge (3) solo aplica al lado del token.
- **RN-P06**: cambio en el DAO NO afecta el badge visual en listas de movimientos generales (`Dashboard`, `/entries` sin filtro de categoría). El JOIN base sigue devolviendo `null` para categorías archivadas gracias a `deleted_at IS NULL`; la categoría con `applies_to` cambiado sigue siendo una categoría "activa" y su badge se sigue mostrando en listas donde no hay filtro por token. La expansión sólo aplica cuando el filtro contiene el token y kinds está restringido.

## Requisitos funcionales

- RF-001: `ReportsService.spendingByCategory` incorpora `AND c.applies_to != 'income'` en el ON del LEFT JOIN.
- RF-002: `EntriesDao.watchPage` reconoce el escenario RN-P01 y expande el `where` correspondiente (`categories.id.isNull() | categories.appliesTo.equals('expense')`).
- RF-003: `EntriesDao.watchPage` reconoce el escenario RN-P02 y expande el `where` (`categories.id.isNull() | categories.appliesTo.equals('income')`).
- RF-004: `EntriesDao.watchPage` conserva el comportamiento actual (`categories.id.isNull()`) en el escenario RN-P03.
- RF-005: cuando `categoryIds` combina `kUncategorizedFilterToken` con ids de categoría reales, el `where` final es la unión disyuntiva `journalEntries.categoryId.isIn(realIds) | (condición del token según RN-P01/P02/P03)`.
- RF-006: `flutter test` cubre paridad `report.buckets['Sin categoría'].count == watchPage(...).items.length` para los escenarios RN-P01 y RN-P02 con datos sembrados vía `customStatement` (bypaseando validación del DAO).
- RF-007: `flutter test` cubre paridad simétrica sobre `spendingByCategory` para el edge (3) que hoy no cae en "Sin categoría".
- RF-008: `CLAUDE.md` documenta la nueva convención de `kUncategorizedFilterToken` según kinds en la sección "Reglas clave de los DAOs" (o equivalente).

## Casos principales

1. Tab "Ingreso por categoría" con edge (3) presente: usuario tiene 2 ingresos con categoría A (`applies_to='income'`), edita A a `applies_to='expense'`, abre el tab → bucket "Sin categoría" muestra count=2. Tap → `/entries` lista exactamente 2 entries.
2. Tab "Gasto por categoría" con edge (3) simétrico presente: usuario tiene 2 gastos con categoría B (`applies_to='expense'`), edita B a `applies_to='income'`, abre el tab → bucket "Sin categoría" muestra count=2 (nuevo comportamiento). Tap → `/entries` lista exactamente 2 entries.
3. Ambos tabs sin edge (3): solo casos (1) y (2). El comportamiento observable no cambia respecto a hoy.
4. `/entries` con filtro manual `Sin categoría` y sin filtro de kinds: comportamiento igual a hoy (solo casos 1+2).

## Casos borde

- Filtro con token + id de categoría real + kind income: la unión debe listar ambos conjuntos (entries de la categoría real seleccionada + entries "sin categoría" según la expansión). No debe duplicar filas ni omitirlas.
- Filtro con token + kind income + kind expense: RN-P03 aplica. No se expande.
- Filtro con token + kind transfer o debt_payment aislado: RN-P03 aplica. No se expande (semántica del token para movimientos internos no aplica al desglose por categoría).
- Categoría con `applies_to='both'` (nunca cae en el edge): no debe ser afectada por el nuevo where. Sigue matcheando por `journalEntries.categoryId`.
- Reactividad: cambiar el `applies_to` de una categoría existente debe hacer re-emit tanto en el reporte (streams `incomeByCategory`, `spendingByCategory`) como en el drill-down (`watchPage`). Hoy ambos declaran `readsFrom: {journalEntries, categories}` (o el join equivalente en drift), así que la reactividad ya está garantizada.
- Backup importado con la combinación inválida `applies_to='expense'` + income entry (o simétrica): el edge (3) ya se puede materializar aunque el DAO valide al crear. La solución tiene que funcionar sobre datos que ya están en BD, no dependa de re-validación al importar.

## Criterios de aceptacion

- `flutter test` verde con al menos 4 nuevos tests: paridad income/expense × edge (3) presente/ausente (los ausentes ya se cubren en la suite existente, así que basta con los 2 tests de paridad nuevos + 2 más de simetría exhaustiva).
- `flutter analyze` en 0 errores nuevos.
- Ejecutar smoke manual: registrar 2 ingresos con categoría A, editar A a `applies_to='expense'`, ir a `/reports` → tab "Ingreso por categoría" → verificar bucket "Sin categoría" con count=2 → tap → `/entries` muestra exactamente 2 entries.
- Smoke simétrico para gastos.
- Regresión: los 452 tests actuales siguen verdes.
- Regresión UX: al abrir `/entries` desde el Dashboard (sin filtros) o desde el FAB, los badges de categoría se ven igual que antes.

## Criterios medibles de exito

- 4 tests nuevos verdes cubriendo los 4 escenarios (income/expense × edge presente/ausente).
- 0 regresiones en la suite existente (452 → ≥ 456 verdes).
- Delta `report.buckets[Sin categoría].count - drillDown.length == 0` en los smokes.
- `flutter analyze` 0 errores nuevos.
- APK release build OK (`0.15.0+78` o el siguiente disponible, tras bump obligatorio en `pubspec.yaml` y `android/app/build.gradle.kts`).

## Riesgos

- **Explosion combinatoria de casos**: el `if` que decide la expansión debe cubrir claramente los escenarios RN-P01/P02/P03. Un test que combine kinds mixtos con el token debe pasar, no expandir.
- **Impacto en filtros del screen `/entries`**: el usuario puede seleccionar el token manualmente desde el sheet de filtros. La lógica del DAO debe ser consistente para ese caso también, no solo para el drill-down programático. La regla del kind (RN-P01/P02) aplica sin importar el origen del filtro.
- **Reactividad de re-emit**: al cambiar `applies_to`, el stream `watchPage` debe re-emitir. Verificar que el join a `categories` en drift dispara la re-emisión (drift lo hace por default al declarar el join).
- **Semántica en filtro combinado real+token**: la unión disyuntiva puede sobre-incluir si un id real casualmente coincide con el edge (3), pero como el usuario no vería una categoría archivada o cambiada a `applies_to` opuesto en la lista de selección de filtro, ese caso es improbable. Documentar como aceptable.
- **Documentación**: `CLAUDE.md` describe el DAO en la sección "Reglas clave de los DAOs". Actualizar sin romper la coherencia con el resto del documento.

## Supuestos

- La UI expone el cambio de `applies_to` desde el form de categoría. Verificado en `mobile/lib/screens/categories/` durante sprints previos.
- El backup JSON v1 puede traer combinaciones inválidas (edge histórico) y no las valida en import. Verificado por el test UT-B08 del sprint budgets (que blindaría este mismo edge para presupuestos).
- La UI del filtro de categorías en `/entries` permite tickear "Sin categoría" como un chip aparte, sin restringir por kind. La expansión propuesta aplica a todos los orígenes de invocación de `watchPage`.
- El comportamiento actual del token con `kinds=null` es el correcto y no se cambia (sería un cambio de UX no contemplado).
- El sprint no requiere migración: los datos existentes (si es que hay algún edge (3) en la BD de Diego) empezarán a comportarse consistentemente con el nuevo código automáticamente.

## Impacto esperado

- Cierre del delta reporte↔drill-down sobre el bucket "Sin categoría" en los 2 tabs por categoría.
- Blindaje simétrico del reporte de gastos contra el edge (3) inverso, con paridad respecto al reporte de ingresos.
- Coherencia operativa: al usar el filtro manual "Sin categoría" en `/entries` con un solo kind income o expense, el listado también incluye el edge (3) — comportamiento que un usuario esperaría intuitivamente ("todo lo que quedó sin categoría desde el punto de vista de este tipo de flujo").
- Cero cambio visual. La feature se percibe como una corrección de correctness, no como una nueva funcionalidad.
- Sprint corto: ~2-3h de trabajo estimadas. Aditivo, bajo riesgo.
