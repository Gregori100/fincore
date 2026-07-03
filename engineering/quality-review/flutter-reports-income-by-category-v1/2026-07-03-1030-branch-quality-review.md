# Branch quality review — flutter-reports-income-by-category-v1

**Fecha:** 2026-07-03
**Slug del sprint:** `flutter-reports-income-by-category-v1`
**Rama:** `main` (cambios sin commit sobre HEAD `a826d99`)
**Diff bajo revisión:** `git diff HEAD` (11 archivos modificados + 3 nuevos)

## Alcance

Sprint aditivo puro: nuevo tab "Ingreso por categoría" (8vo en `/reports`), análogo al tab existente de gastos. Sin schema bump. Nuevos: `IncomeReport`, `IncomeBucket`, `ReportsService.incomeByCategory`, `EntriesFilters.forIncomeBucket`, widget `IncomeByCategoryTab`. Onboarding + FAQ actualizados a "8 reportes".

Se ejecutaron **3 agentes en paralelo** con foco separado: data + SQL correctness, frontend + UX, tests + regresión. Este reporte consolida sus hallazgos por severidad, agregando la verificación cruzada del bug de drill-down (único hallazgo con acción recomendada antes del commit).

## Hallazgos por severidad

### Media/Alta — Drill-down "Sin categoría" no coincide con el reporte para incomes con categoría `applies_to='expense'`

**Archivos:** `mobile/lib/data/reports.dart:390-395` + `mobile/lib/data/daos/entries_dao.dart:99-136`

**Descripción:** Divergencia de semántica entre el reporte y el drill-down para el edge legacy blindado por RN-I05.

- El SQL de `incomeByCategory` agrega **tres casos** al bucket "Sin categoría":
  1. `journal_entries.category_id IS NULL`.
  2. Categoría archivada (`deleted_at IS NOT NULL`).
  3. Categoría con `applies_to = 'expense'` (edge legacy).
- El `EntriesDao.watchPage` que ejecuta el drill-down solo cubre los casos (1) y (2) — su LEFT JOIN filtra `deleted_at IS NULL` pero **no** `applies_to != 'expense'` (línea 99-103). Cuando `categoryIds:[kUncategorizedFilterToken]` traduce a `categories.id IS NULL`, los incomes del caso (3) siguen matcheando la categoría real y quedan fuera del filtro.

**Impacto:** El reporte muestra p.ej. "Sin categoría: $12,000 · 5 movimientos" pero al tapear el bucket, `/entries` lista solo los del caso (1)+(2). El delta se convierte en dinero fantasma no accionable. Rompe la promesa del deep link ("muestra solo los ingresos de esa categoría en el rango exacto del reporte").

**Cuándo aparece:** requiere que Diego (a) haya registrado incomes con una categoría, (b) haya editado esa categoría cambiando `applies_to` de `income`/`both` a `expense`. Ambas operaciones están expuestas por la UI actual (form de categoría). Bajo en probabilidad, real en semántica.

**Simetría con spending:** el hallazgo aplica en ambas direcciones. El tab de gastos también tendría el mismo problema con categorías cuyo `applies_to` haya sido cambiado a `income`, pero además —según el otro hallazgo Baja de data— el propio `spendingByCategory` ni siquiera aplica el filtro simétrico en el JOIN del reporte. Ambos temas conviene atacarlos juntos.

**Recomendación:** No es bloqueante para el commit (edge raro, no rompe el core). Registrar como pendiente en un sprint corto de "coherencia reporte↔drill-down" que:
1. Alinee el `EntriesDao.watchPage` con la definición de "sin categoría" del reporte cuando el filtro incluye `kUncategorizedFilterToken` y `kinds=['income']` o `['expense']` — expandir el `where` a `categories.id.isNull() | categories.appliesTo.equals(kindOpuesto)`.
2. Agregue el filtro simétrico `applies_to != 'income'` en el JOIN de `spendingByCategory` (falta hoy — hallazgo Baja del review de data).
3. Sume un test que verifique paridad `report.count == drillDown.count` en el edge de `applies_to` cambiado post-facto.

---

### Alta — WT-I04 (drill-down bucket → `/entries`) sin cobertura de widget test

**Archivo:** `mobile/test/screens/reports/income_by_category_tab_test.dart`

**Descripción:** El test-plan lista WT-I04 explícitamente como test del flujo tap-en-bucket → navegación a `/entries` con `EntriesFilters.forIncomeBucket(...)` pre-cargado. Es el mayor valor de negocio del sprint (deep link) y el único plumbing nuevo entre UI y ruta. El archivo solo cubre WT-I01/I02/I03. La cobertura del factory `forIncomeBucket` aislado (UT-I11/I12) no prueba el wire-up desde el tab.

**Impacto:** Un refactor futuro de `_buildDeepLink`, `EntriesFilters.forIncomeBucket` o del manejo de query params en `EntriesListScreen` puede romper el drill-down silenciosamente. Diego valida vía smoke SM-05, pero la validación humana única no protege contra regresión post-release. El precedente del tab de gastos también carece de este test — clase de riesgo preexistente pero la spec de este sprint la pedía.

**Recomendación:** Agregar WT-I04 mínimo (seed de 1 bucket + tap + verificar que `EntriesListScreen` se monta con `kinds=['income']` y `categoryIds` correcto). Como alternativa aceptable, marcar la desviación D3 como debt formal en `pendientes.md` y aceptar la cobertura vía SM-05 como suficiente para el MVP local-first.

---

### Media — UT-I10 no cubre la intención del test-plan (`total_general=0`)

**Archivo:** `mobile/test/data/reports_test.dart:2523-2534`

**Descripción:** El test-plan describe UT-I10 como "Cálculo defensivo: si `total_general=0` (edge), `percent=0` y `isEmpty=true`" (CB-D19). El test implementado valida en cambio "rango que excluye el único income → `isEmpty=true`", que es redundante con UT-I01 (BD sin incomes) movida por filtro temporal.

**Impacto:** El escenario "buckets con `amount=0` sumando `total=0`" no está cubierto. Si un backup legacy trae incomes con `amount=0` (edge raro pero posible), el path defensivo `total > 0 ? r.total / total : 0` en `_buildIncomeReport` no está protegido contra regresión. Bajo por probabilidad, medio por criticidad (una regresión = división por cero → runtime error del reporte).

**Recomendación:** Renumerar el UT-I10 actual como UT-I10-bis (variante de UT-I01) y añadir un UT-I10 real que inserte vía `customStatement` un income con `amount=0` y verifique que `isEmpty=true` o `percent==0`.

---

### Media — UT-I08 con patrón `Future.delayed` flaky

**Archivo:** `mobile/test/data/reports_test.dart:2488-2502`

**Descripción:** Test de reactividad usa `stream.listen(events.add)` + `await Future.delayed(50ms)` + registro + `Future.delayed(100ms)` + assertion. En el quality review del sprint `flutter-budgets-v1` este exacto patrón fue marcado como M2 por probabilidad de flakiness bajo CI cargado (drift no garantiza notificación en <100ms).

**Impacto:** Test intermitente en CI cuando lo haya; local desktop probablemente siempre verde. Un rerun ocasional puede fallar sin cambio real y erosionar la confianza en la suite.

**Recomendación:** Reemplazar por `stream.take(2).toList()` o `expectLater(stream, emitsInOrder([...]))`. Ejemplo:

```dart
final future = reports.incomeByCategory(from: iFrom, to: iTo).take(2).toList();
await entriesDao.registerIncome(...);
final events = await future;
expect(events.last.total, 1000);
```

---

### Baja — Falta simetría del filtro `applies_to` en `spendingByCategory`

**Archivo:** `mobile/lib/data/reports.dart:159-167`

**Descripción:** `incomeByCategory` filtra `c.applies_to != 'expense'` en el JOIN para blindar el edge legacy (income con categoría expense-only cae en "Sin categoría"). El equivalente simétrico en `spendingByCategory` (expense con categoría `applies_to='income'`, edge idéntico e igualmente posible via backup legacy) **no** existe.

**Impacto:** UX inconsistente entre los dos reportes gemelos. Un backup legacy con categorías cross-appliesTo verá comportamiento distinto según el tab. Riesgo bajo hoy: el DAO valida el combo al registrar, así que solo aplica a datos importados.

**Recomendación:** No bloquea este sprint (es TD del sprint anterior). Atacar junto con el hallazgo Media/Alta de arriba en el próximo sprint de coherencia reporte↔drill-down.

---

### Baja — Inclusividad de `to` delegada al caller

**Archivo:** `mobile/lib/data/reports.dart:390-393`

**Descripción:** El WHERE usa `j.occurred_at <= ?` con el valor crudo de `to`. Si el caller pasa `DateTime(2026, 6, 30)` (00:00 local), los incomes del día 30 con hora > 00:00 se pierden. Los tests usan `DateTime(y, m, d, 23, 59, 59, 999)` correcto; el widget también (verificado por lectura de `_pickTo`). Riesgo latente si un caller futuro no normaliza.

**Recomendación:** Alternativa robusta: mover la extensión al fin del día dentro del servicio (como ya hace `EntriesDao.watchPage` línea 144). Cambio pequeño, blindaria todos los callers actuales y futuros. Aplica también a `spendingByCategory` y otros métodos con la misma firma.

---

### Baja — `_TotalCard` habla en "movimientos" genéricos en vez de "ingresos"

**Archivo:** `mobile/lib/screens/reports/income_by_category_tab.dart:243-244`

**Descripción:** El texto de conteo dice "N movimientos" en un card cuyo título es "Total del período" y cuyo tab es "Ingreso por categoría". La palabra semánticamente correcta sería "ingreso(s)". Consistente con `_TotalCard` de gastos (que también dice "movimientos" en vez de "gastos"), así que el hallazgo aplica simétricamente.

**Recomendación:** Cambiar a `'1 ingreso'` / `'${count} ingresos'`. Si querés paridad con spending, aplicar el cambio en ambos tabs.

---

### Baja — WT-I05 (validación `from > to` con snackbar) sin cobertura

**Archivo:** `mobile/lib/screens/reports/income_by_category_tab.dart:83-125`

**Descripción:** Plan pide WT-I05 para verificar snackbar cuando `to < from` en modo custom. La lógica existe pero no hay test. Mismo pattern reusado del tab de gastos sin test tampoco.

**Recomendación:** Aceptar como desviación D3 documentada. Diego valida vía SM-07.

---

### Baja — `_EmptyState` sin CTA "Registrar ingreso"

**Archivo:** `mobile/lib/screens/reports/income_by_category_tab.dart:384-421`

**Descripción:** El empty state sugiere "Ajustar las fechas o registrar un movimiento" sin botón. Los tabs Presupuestos y Tarjetas tienen CTA; Gastos tampoco tiene.

**Recomendación:** Aceptable. Si se decide unificar, aplicar en Gastos e Ingresos con `TextButton.icon` "Registrar ingreso" → `/entries/new?kind=income`.

---

### Notas (no accionables)

- **`_IncomeBucketRow` con `colorBySlug`**: correcto — la identidad visual de cada categoría prima sobre el refuerzo semántico `positive`. Consistente con Gastos.
- **Summary de rango debajo de los chips**: útil (desambigua el chip "Este mes" con fechas absolutas). Mantener.
- **`|| categoryName == null` en `_buildIncomeReport:435`**: defensiva redundante (schema tiene `name` NOT NULL). Copia limpia del pattern del spending. Dejar por simetría.
- **UT-I03 PK con caracteres no-hex**: fixture con `'i03legacyexp'` en el UUID. No bloquea (schema no valida formato). Cambio mecánico opcional para higiene.
- **Simetría de modelos `IncomeReport`/`SpendingReport`**: confirmada (mismos campos, contratos y token `kUncategorizedFilterToken`).
- **WT-I07/I08 (onboarding + FAQ) sin assertions específicas**: cosmético. Suficiente con SM-08/SM-09.
- **Label "Ingreso por categoría" (19 chars)**: no overfloea con `isScrollable`.
- **State cachea `_from/_to/_preset`**: correcto al volver del `context.push` del drill-down.

## Riesgos residuales

- **Duplicación de código con `SpendingByCategoryTab`**: intencional (R7 del plan). Cambios futuros en lógica compartida (chips, formato de porcentaje, empty state) deben aplicarse en ambos archivos hasta que se decida un refactor común.
- **Coherencia reporte ↔ drill-down**: el hallazgo Media/Alta es el más importante del review. Es preexistente en spending y ahora reproducido en income. Amerita un sprint corto dedicado.

## Pruebas ejecutadas por el sprint

- `flutter analyze` limpio (4 hints info pre-existentes).
- `flutter test` → 452/452 verdes (437 baseline + 15 nuevos).
- Build APK release `--split-per-abi` OK; `verify-apk.sh` OK con versionCode 2077 / versionName 0.15.0.
- Smokes SM-01..09 confirmados por Diego en cel real ("Ya lo probé se ve bien").

## Recomendación de merge

**Apto para commit sin acción previa obligatoria.**

Los 3 hallazgos accionables no bloquean:

1. **Media/Alta (drill-down inconsistente)**: edge raro, preexistente en spending. Sprint corto dedicado sería el path correcto — no un hotfix acá.
2. **Alta (WT-I04 sin cobertura)**: aceptable como D3 documentada + SM-05 validado.
3. **Media (UT-I10 y UT-I08)**: mejoras de robustez de la suite; se pueden aplicar en un patch de calidad de tests posterior sin ceremonia de sprint.

Si se quisiera blindar algo antes del commit: solo UT-I08 (reemplazo del `Future.delayed` por `emitsInOrder`) es cambio de 5 minutos y elimina flakiness reproducible en CI.

## Pendientes sugeridos para sprints futuros

1. **Sprint de coherencia reporte ↔ drill-down** (prioridad media): alinear la definición de "sin categoría" en `EntriesDao.watchPage` con la del servicio de reportes, aplicar filtro `applies_to != 'income'` simétrico en `spendingByCategory`, agregar test de paridad `report.count == drillDown.count`.
2. **Sprint de robustez de tests reactivos** (prioridad baja): reemplazar el patrón `Future.delayed` por `emitsInOrder` en UT-I08 e identificar callers similares en el resto de la suite.
3. **Refactor helper compartido `_ByCategoryTab`** (prioridad baja): cuando exista un 3er tab por categoría (nunca hoy en roadmap), extraer el pattern compartido entre `SpendingByCategoryTab` e `IncomeByCategoryTab`.
