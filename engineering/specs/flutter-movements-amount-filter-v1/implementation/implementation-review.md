# Implementation Review: flutter-movements-amount-filter-v1

## Resumen de lo implementado

Sprint chico cerrado. Se agregó la dimensión "Monto" al panel de filtros
de `/entries` con 2 fields numéricos opcionales (mínimo y máximo). El
DAO extiende `watchPage` con `minAmount`/`maxAmount` opcionales que
aplican `amount >= min` y `amount <= max` (RN-A02/A03 — inclusivos).
Chip nuevo en la `EntriesActiveFiltersBar` con label condicional según
qué extremo esté presente. Validación `min > max` con snackbar warning.
Sin schema bump, sin deps externas, sin cambios productivos breaking.

## Archivos principales modificados

Productivos:

- `mobile/lib/data/entries_filters.dart`: campos `minAmount`/`maxAmount`,
  `copyWith` con `clear*` sentinels, `clearDimension(amount)`,
  `activeCount` extendido, `serialize`/`parse` con
  `_tryParseNonNegativeDouble` helper, `FilterDimension.amount`.
- `mobile/lib/data/daos/entries_dao.dart`: `watchPage` con
  `minAmount`/`maxAmount` opcionales que agregan
  `isBiggerOrEqualValue`/`isSmallerOrEqualValue`.
- `mobile/lib/screens/entries_filters_screen.dart`: sección "Monto"
  entre "Cuenta" y "Categorías", 2 `TextEditingController` con
  `inputFormatter` `[0-9.]`, `_apply` con validación + parsing +
  snackbar.
- `mobile/lib/widgets/entries_active_filters_bar.dart`: chip de monto
  + helper `_amountLabel` con casos `≥`, `≤`, rango.
- `mobile/lib/widgets/entries_paginated_list.dart`: `_filtersChanged`
  compara `minAmount`/`maxAmount` + `_buildStream` los pasa al
  `watchPage`.

Tests:

- `mobile/test/data/entries_dao_filters_test.dart` (+6 tests UT-01..06).
- `mobile/test/data/entries_filters_test.dart` (+7 tests UT-07..13).
- `mobile/test/screens/entries_filters_screen_test.dart` (+3 widget
  tests WT-01..03 + ajuste defensivo en test existente "Default
  thisMonth" con `scrollUntilVisible`).

Release:

- `mobile/pubspec.yaml` (0.7.1+59 + nota).
- `mobile/android/app/build.gradle.kts` (versionCode 59 / versionName
  0.7.1).

## Tareas completadas

Las 19 tareas de `plan/tasks.md` cerradas en orden:

- **F0** (T001): baseline 235 verdes confirmado.
- **F1** (T002-T005): modelo + enum extendidos. `_tryParseNonNegativeDouble`
  agregado como helper privado del archivo (no del plan, aceptable porque
  es un detalle de implementación interno).
- **F2** (T006): DAO con 2 params opcionales + 2 where clauses.
- **F3** (T007-T010): UI — sección Monto + controllers + validación en
  `_apply` + chip en bar + paso al watchPage en lista.
- **F4** (T011-T015): 16 tests nuevos (6 DAO + 7 modelo + 3 widget).
- **F5** (T016-T019): suite verde, bump, APK + verify, docs.

## Tareas pendientes

Ninguna del plan. Pendiente del usuario (no del sprint):

- Smoke manual SM-01..SM-07 en cel real con APK `0.7.1+59`.

## Riesgos residuales

- **R-T05 del plan** (mitigado): los tests existentes del `EntriesFilters`
  con `copyWith` no se rompieron porque `minAmount`/`maxAmount` son
  opcionales con default null. Verificado en suite completa.
- **R-T03 del plan** (cerrado): el chip "≥ $X" / "≤ $X" se renderea
  correctamente — los tests de UT-09 y WT-01 cubren la presencia.
- **Hallazgo nuevo de implementación**: la sección "Monto" empujó
  "Categorías" fuera del viewport inicial del `ListView` del panel,
  rompiendo un test existente que buscaba "Sin categoría" sin
  scrollear. Mitigación: el test ahora usa `scrollUntilVisible` antes
  del expect. No es regresión productiva — solo refleja la realidad
  de un panel más largo.
- **Default vacío al abrir el panel**: si Diego abre el panel con
  filtros aplicados desde antes (`initial.minAmount != null`), los
  controllers se inicializan con `toString()` que en double da
  `"100.0"` en vez de `"100"`. Aceptable visualmente (formatea como
  decimal). Sin issue funcional.

## Pruebas realizadas

- `flutter analyze` → 0 errores, 4 hints `info` cosméticos
  pre-existentes (no del sprint).
- `flutter test` completo → **251/251 verdes** en 17s (235 previos +
  16 nuevos).
- `flutter test test/data/entries_dao_filters_test.dart --name 'amount'`
  → 6/6 verdes (UT-01 a UT-06).
- `flutter test test/data/entries_filters_test.dart --name 'amount'`
  → 7/7 verdes (UT-07 a UT-13).
- `flutter test test/screens/entries_filters_screen_test.dart --name
  'sección Monto'` → 3/3 verdes (WT-01 a WT-03).
- `flutter build apk --release --split-per-abi` → 3 APKs.
- `bash scripts/verify-apk.sh` → versionCode 2059 / versionName 0.7.1
  consistentes.

## Pruebas recomendadas

Smoke manual en cel real con APK `0.7.1+59`:

- SM-01: abrir `/entries` → tap "Filtros" → scroll del panel → ver
  sección "Monto" entre "Cuenta" y "Categorías".
- SM-02: escribir `min = 1000` → Aplicar → lista filtra entries con
  `amount >= 1000`. Chip "≥ $1.000" aparece en la bar.
- SM-03: tap "X" del chip → lista refresca, chip desaparece.
- SM-04: escribir `min = 100, max = 500` → Aplicar → chip "$100 – $500"
  + lista filtrada.
- SM-05: escribir `min = 1000, max = 100` → Aplicar → snackbar warning,
  panel queda abierto.
- SM-06: filtros combinados: monto + kind + fecha. Lista coherente.
- SM-07: cancelar un entry con filtro activo → lista refresca sin él.

## Posibles regresiones

Cero detectadas en automatizado. Áreas a vigilar en smoke manual:

- **Panel más alto**: el `ListView` del panel ahora tiene una sección
  más. Asegurarse que el scroll siga fluido en el cel.
- **Deep link existente**: los query params `kinds`, `accountIds`,
  `categoryIds` siguen funcionando sin cambios. Validar con un push
  manual.
- **Reactividad**: cancelar entry desde `/entries/:id/edit` con filtro
  de monto activo debe re-emitir la lista sin él.
- Sin regresión esperada en cashflow ni en spending tab.

## Recomendaciones para code review humano

- Verificar que el `inputFormatter` `RegExp(r'[0-9.]')` permite
  múltiples puntos (validado por mitigación R-T02). El `double.tryParse`
  retorna null si hay más de un punto — el campo entonces queda como
  null tras `_apply` y no aplica filtro. Comportamiento aceptable pero
  silencioso; si se quiere mejorar la UX, agregar `validator` que
  rechace input inválido en tiempo real.
- El `copyWith` con `clearMinAmount: true` + `minAmount: X` ignora el
  valor explícito (el clear gana). Documentado en doc-comment.
- El chip se renderea con `≥` / `≤` no-ASCII. Validar en el cel real
  que la fuente del theme oscuro los muestra correctamente.
- El test "Default thisMonth está seleccionado al abrir" se ajustó
  defensivamente con `scrollUntilVisible` antes del expect de "Sin
  categoría". El cambio es benigno (más robusto contra futuros
  agregados de secciones).
- `branch-quality-review` NO se invocó (skill disponible pero no
  pedido por el usuario). Si Diego quiere revisión exhaustiva, ejecutar
  `branch-quality-review flutter-movements-amount-filter-v1` antes
  de merge.
