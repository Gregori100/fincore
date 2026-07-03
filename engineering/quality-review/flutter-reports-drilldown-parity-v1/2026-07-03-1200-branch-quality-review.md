# Branch quality review — flutter-reports-drilldown-parity-v1

**Fecha:** 2026-07-03
**Slug del sprint:** `flutter-reports-drilldown-parity-v1`
**Rama:** `main` (cambios sin commit sobre HEAD `8315c82`)
**Diff bajo revisión:** `git diff HEAD` (7 archivos: 5 código/test + 2 docs)

## Alcance

Sprint correctivo puro sobre la capa de datos. Dos cambios ortogonales:

1. `spendingByCategory` — filtro simétrico `AND c.applies_to != 'income'` en el ON del LEFT JOIN.
2. `EntriesDao.watchPage` — helper privado `_uncategorizedCondition` que expande la definición del token `__null__` según kinds efectivo (RN-P01/P02/P03).

Sin schema bump, sin cambios de UI, sin migración. 9 tests nuevos (UT-DP01..09). Total 461/461 verdes. Version bump `0.15.0+77` → `0.15.1+78`.

Se ejecutaron **3 agentes en paralelo** con asignación de modelo por criterio: 2 Haiku para verificaciones estructuradas (SQL correctness + cobertura de tests) y 1 Sonnet para el análisis con criterio (regresión + callers + UX).

## Hallazgos por severidad

### Alta — Docstring de `incomeByCategory` no atado al sprint drilldown-parity

**Archivo:** `mobile/lib/data/reports.dart:359-375`

**Descripción:** El docstring de `incomeByCategory` (creado en el sprint income-by-category) sigue diciendo "RN-I05" pero no menciona que su filtro `applies_to != 'expense'` y el nuevo `!= 'income'` de `spendingByCategory` son parte del mismo cierre de coherencia. `spendingByCategory` sí refiere a RN-P04. La inconsistencia rompe la trazabilidad cuando alguien busca el origen del comportamiento simétrico.

**Impacto:** Documentación desalineada. Un revisor futuro que llegue a `incomeByCategory` no verá el link al sprint drilldown-parity y podría pensar que el filtro es una decisión local del sprint income anterior.

**Recomendación:** Fix trivial de 2 líneas. Agregar mención al sprint drilldown-parity en el docstring de `incomeByCategory`. Ver acción `A1` abajo.

---

### Media — Asserts sin `reason:` en UT-DP07

**Archivo:** `mobile/test/data/entries_dao_filters_test.dart:290-292`

**Descripción:** El test más complejo del grupo (unión de token + realIds + edge) tiene 2 asserts sin `reason:` explicativo. El comentario previo (línea 289) documenta la intención, pero los asserts no. Los otros tests del sprint son consistentes en usar `reason:` cuando ayuda.

**Impacto:** Bajo — no bloquea, comportamiento verificado. Sólo trazabilidad menor. Coherente con patrón de tests existentes que también omiten `reason:` en asserts cortos.

**Recomendación:** Cosmético. Aceptable como está. Si se quiere blindar, agregar `reason: 'Unión: 1 seed + 1 catIncomeReal + 1 edge (3).'` en línea 290.

---

### Baja — Comentario sobre invariante NOT NULL de `applies_to`

**Archivo:** `mobile/lib/data/daos/entries_dao.dart:620-634` (helper `_uncategorizedCondition`)

**Descripción:** El helper asume que `categories.applies_to` no es NULL cuando `categories.id` no es NULL. En `database.dart` la columna está definida como NOT NULL con CHECK constraint, así que la asunción es sólida. La defensiva no está documentada como comentario del helper.

**Impacto:** Muy bajo — sólo higiene. Sin riesgo real, la invariante se preserva por schema.

**Recomendación:** Cosmético. Comentario de 1 línea si se decide.

---

### Baja — Fragilidad de `.every()` con `kindSet` potencialmente vacío

**Archivo:** `mobile/lib/data/daos/entries_dao.dart:630`

**Descripción:** Si alguien refactoriza el orden de chequeos removiendo el `if (effectiveKinds == null || effectiveKinds.isEmpty)` inicial, el `kindSet.every(spendingKinds.contains)` retornaría `true` para set vacío (comportamiento de Dart `.every`) y expandiría la condición incorrectamente.

**Impacto:** Muy bajo hoy. Es un guardrail para refactors futuros.

**Recomendación:** Opcional: `assert(kindSet.isNotEmpty)` al inicio del helper como blindaje defensivo.

---

### Baja — Sorpresa observable potencial en el sheet de filtros manual

**Archivo:** `mobile/lib/screens/entries_filters_screen.dart:406-413` + `CLAUDE.md`

**Descripción:** El nuevo comportamiento (tickear "Sin categoría" + kind puro incluye entries con categoría editada post-facto) solo aparece si el edge (3) existe en la BD. En una BD sin ese edge, no hay diferencia visible. El sheet no distingue "Sin categoría clásico" de "Sin categoría ampliado" con tooltip ni badge.

**Impacto:** Muy bajo. El escenario patológico (usuario que edita masivamente `applies_to` esperando que sus entries desaparezcan del bucket) es poco realista.

**Recomendación:** No accionar en este sprint. Si a futuro Diego reporta confusión, considerar un hint sutil en el chip "Sin categoría" del sheet ("incluye categorías editadas").

---

### Baja — Asserts sin `reason:` en UT-DP08

**Archivo:** `mobile/test/data/entries_dao_filters_test.dart:316-317`

**Descripción:** Mismo patrón que la Media de UT-DP07, pero menor porque el test es más simple y el comentario previo (líneas 298-303) documenta claramente la intención.

**Recomendación:** Cosmético.

---

### Notas positivas (no accionables)

- **Cobertura exhaustiva**: los 9 tests cubren las 3 ramas del helper + reactividad + regresión RN-P03 + unión disyuntiva. Cero gaps vs test-plan.
- **Reactividad con `emitsThrough`**: UT-DP09 usa el patrón robusto (aprendido del quality review previo). Cero flakiness esperada.
- **Callers aislados**: Dashboard (`limit:10` sin filtros) → helper no se ejecuta. Cero regresión. EntriesPaginatedList transparente al DAO.
- **Factories alineados**: `forIncomeBucket` y `forCategoryBucket` disparan RN-P01/P02 correctamente cuando el usuario tapea el bucket "Sin categoría".
- **Documentación coherente**: `CLAUDE.md` describe el comportamiento operativo con 3 bullets; no contradice la sección legacy "Joins con categorías archivadas".
- **Simetría verificada**: `incomeByCategory` con `!= 'expense'` y `spendingByCategory` con `!= 'income'` son exactamente análogos.
- **Sin regresión en tests widget**: 150+ tests del sheet siguen verdes; no ejercitan el flujo específico que cambió (verifican render/tap/propagación, no la capa DAO).

## Acciones sugeridas

- **A1 (Alta, aplicar antes del commit — 2 min)**: agregar mención al sprint drilldown-parity en el docstring de `incomeByCategory` en `mobile/lib/data/reports.dart:359-375`.
- **A2 (Media, opcional)**: agregar `reason:` en asserts de UT-DP07 (`entries_dao_filters_test.dart:290-292`).
- **A3 (Baja, opcional futuro)**: `assert(kindSet.isNotEmpty)` en `_uncategorizedCondition` como blindaje contra refactors.
- **A4 (Baja, opcional futuro)**: hint en chip "Sin categoría" del sheet cuando se combine con kind puro y haya edge (3) en la BD.

## Riesgos residuales

- **Cero riesgo visual**: sin cambios de UI ni UX observables al usuario común.
- **Sorpresa observable en filtro manual**: aplica solo si el usuario ya tiene edge (3) en su BD. Documentado.
- **Reactividad**: cubierta por UT-DP09 con `emitsThrough` (sin `Future.delayed`).

## Pruebas ejecutadas por el sprint

- `flutter analyze` limpio (4 hints info pre-existentes tolerados).
- `flutter test` → **461/461 verdes** (452 baseline + 9 nuevos).
- Build APK release `--split-per-abi` OK; `verify-apk.sh` OK con versionCode 2078 / versionName 0.15.1.
- Smokes SM-01..04 confirmados por Diego en cel real ("Al parecer todo bien").

## Recomendación de merge

**APTO PARA COMMIT.** Recomiendo aplicar A1 (2 minutos) antes del commit final por consistencia de trazabilidad entre los 2 sprints ligados (income-by-category + drilldown-parity). Los otros hallazgos son cosméticos o para futuros.

## Pendientes sugeridos para sprints futuros

- **Consistencia visual del sheet de filtros** (prioridad baja): si Diego observa confusión al usar el filtro manual "Sin categoría" combinado con kind puro, agregar un hint sutil en el chip.
- **Guardrail defensivo en `_uncategorizedCondition`** (prioridad muy baja): `assert(kindSet.isNotEmpty)` para futuros refactors.
