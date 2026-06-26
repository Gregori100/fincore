# Tasks — flutter-movements-amount-filter-v1

## F0 — Validación pre-sprint

- [ ] T001 Validación de calidad: confirmar baseline antes de tocar.
  RF: —
  Depende de: ninguna
  Paralelizable: no
  Criterio de terminado: `flutter test` → 235/235 verdes,
  `flutter analyze` → 0 errores, `git status` limpio en `mobile/`.

## F1 — Modelo

- [ ] T002 Backend: agregar campos `minAmount: double?` y `maxAmount:
  double?` al constructor de `EntriesFilters` en
  `mobile/lib/data/entries_filters.dart`.
  RF: RF-001
  Depende de: T001
  Paralelizable: no
  Criterio de terminado: campos `final` con default null en constructor
  + getters. Compila sin tocar callers existentes.

- [ ] T003 Backend: extender `EntriesFilters.copyWith` con
  `double? minAmount`, `double? maxAmount`, `bool clearMinAmount`,
  `bool clearMaxAmount` para distinguir "no cambiar" de "limpiar".
  RF: RF-002
  Depende de: T002
  Paralelizable: no
  Criterio de terminado: `copyWith()` no cambia, `copyWith(minAmount:
  100)` setea, `copyWith(clearMinAmount: true)` limpia. La
  combinación `clearMinAmount: true, minAmount: X` lanza assert o
  ignora `X` (decisión: ignorar con doc-comment).

- [ ] T004 Backend: extender `clearDimension`, `activeCount`, `parse`
  y `toDeepLink` para soportar la dimensión amount.
  RF: RF-004, RF-005, RF-006, RF-007
  Depende de: T003
  Paralelizable: no
  Criterio de terminado:
  - `clearDimension(FilterDimension.amount)` retorna copia con ambos
    en null.
  - `activeCount` suma 1 si `min != null || max != null`.
  - `parse({'minAmount': '500'})` → minAmount=500. Negativos y
    no-numéricos → null.
  - `toDeepLink()` agrega `minAmount=X` y/o `maxAmount=Y` cuando
    están presentes; omite cuando son null.

- [ ] T005 Backend: agregar `amount` al enum `FilterDimension` al final
  del archivo.
  RF: RF-003
  Depende de: T004
  Paralelizable: no
  Criterio de terminado: `enum FilterDimension { date, kinds,
  accounts, categories, amount }`. `flutter analyze` 0 errores.

## F2 — DAO

- [ ] T006 Backend: extender `EntriesDao.watchPage` con `minAmount:
  double?` y `maxAmount: double?` opcionales.
  RF: RF-008
  Depende de: T001 (independiente de F1; toca otro archivo)
  Paralelizable: si (con F1)
  Criterio de terminado: si `minAmount != null` agrega
  `query.where(journalEntries.amount.isBiggerOrEqualValue(minAmount))`.
  Idem para `maxAmount` con `isSmallerOrEqualValue`. Documentar en el
  docstring del método.

## F3 — UI

- [ ] T007 Frontend: agregar sección "Monto" en
  `mobile/lib/screens/entries_filters_screen.dart` entre las secciones
  "Cuenta" y "Categorías" con 2 `TextFormField`.
  RF: RF-009, RF-010
  Depende de: T005
  Paralelizable: si (con T008, T010)
  Criterio de terminado:
  - 2 controllers `_minAmountCtrl`, `_maxAmountCtrl` inicializados con
    los valores de `widget.initial.minAmount`/`maxAmount` formateados
    como string (o vacíos si null).
  - Row con 2 fields "Mínimo" (izq) y "Máximo" (der) con prefijo
    `$`, keyboard `numberWithOptions(decimal: true)`, inputFormatter
    que solo permite dígitos + un punto.
  - Sección colocada entre "Cuenta" y "Categorías".
  - dispose() libera los controllers.

- [ ] T008 Frontend: agregar chip de monto en
  `mobile/lib/widgets/entries_active_filters_bar.dart` + helper
  `_amountLabel`.
  RF: RF-012
  Depende de: T005
  Paralelizable: si
  Criterio de terminado:
  - Nuevo `if (filters.minAmount != null || filters.maxAmount != null)`
    en el Row del bar agrega `_ActiveChip` con `label: _amountLabel(...)`.
  - `_amountLabel`: solo min → `'≥ ${formatAmount(min)}'`, solo max →
    `'≤ ${formatAmount(max)}'`, ambos →
    `'${formatAmount(min)} – ${formatAmount(max)}'`.
  - `onRemove` llama `onRemove(FilterDimension.amount)`.

- [ ] T009 Frontend: validación `min > max` en `_apply` del
  `EntriesFiltersScreen`. Mostrar `showWarningSnackbar` y NO emitir
  el resultado.
  RF: RF-011
  Depende de: T007
  Paralelizable: si
  Criterio de terminado:
  - `_apply` parsea ambos controllers con `double.tryParse`.
  - Si ambos resultan no-null y `min > max`,
    `showWarningSnackbar(context, 'El rango de monto no es válido.
    Revisá los montos.')` + `return` (no pop).
  - Antes del pop, hace `_editing = _editing.copyWith(...)` con los
    valores parseados (o `clearMinAmount: true` si el field quedó
    vacío). Para "vacío" usar `controller.text.trim().isEmpty`.

- [ ] T010 Frontend: extender
  `mobile/lib/widgets/entries_paginated_list.dart`: pasar
  `minAmount`/`maxAmount` al `watchPage` + agregar al
  `_filtersChanged`.
  RF: RF-013
  Depende de: T006
  Paralelizable: si (con T007, T008, T009)
  Criterio de terminado:
  - `_buildStream` pasa `minAmount: widget.filters.minAmount` y
    `maxAmount: widget.filters.maxAmount` al `watchPage`.
  - `_filtersChanged` agrega comparaciones
    `a.minAmount != b.minAmount` y `a.maxAmount != b.maxAmount`.

## F4 — Pruebas

- [ ] T011 Pruebas: agregar grupo `watchPage — amount (RN-A01..A08)`
  en `mobile/test/data/entries_dao_filters_test.dart` con 6 tests
  (UT-01 a UT-06).
  RF: RF-008
  Depende de: T006
  Paralelizable: si (con T012, T013-T015)
  Criterio de terminado: 6 tests pasan en local. Cobertura: solo min,
  solo max, rango, igualdad, combinado con kind+fecha, regresión sin
  filtro.

- [ ] T012 Pruebas: agregar tests del modelo `EntriesFilters` para los
  campos amount.
  RF: RF-002, RF-004, RF-005, RF-006, RF-007
  Depende de: T004
  Paralelizable: si
  Criterio de terminado: 7 tests (UT-07 a UT-13). Si
  `mobile/test/data/entries_filters_test.dart` no existe, crearlo.
  Cobertura: copyWith con sentinels, clearDimension, activeCount,
  parse (3 variantes), toDeepLink.

- [ ] T013 Pruebas: WT-01 en `entries_filters_screen_test.dart` —
  sección "Monto" renderea 2 fields con prefijo `$`.
  RF: RF-009, RF-010
  Depende de: T007
  Paralelizable: si (con T014, T015)
  Criterio de terminado: `pumpFincoreApp` + `openPanel` +
  `find.text('Mínimo')` + `find.text('Máximo')` + `findsAtLeastNWidgets(2)`
  para prefijo `$`.

- [ ] T014 Pruebas: WT-02 — ingresar `min = 100` + tap "Aplicar"
  retorna `EntriesFilters` con `minAmount = 100.0`.
  RF: RF-011
  Depende de: T009
  Paralelizable: si
  Criterio de terminado: el `future` del panel resuelve con
  `result.minAmount == 100.0` tras `enterText` + tap.

- [ ] T015 Pruebas: WT-03 — `min = 1000, max = 100` + "Aplicar"
  muestra snackbar warning + panel no emite.
  RF: RF-011
  Depende de: T009
  Paralelizable: si
  Criterio de terminado: `find.textContaining('rango de monto no es
  válido')` `findsOneWidget`. El panel sigue montado tras el tap.

## F5 — Release

- [ ] T016 Validación de calidad: `flutter analyze` + `flutter test`
  completos.
  RF: —
  Depende de: T011, T012, T013, T014, T015, T010
  Paralelizable: no
  Criterio de terminado: 0 errores en analyze (hints `info`
  pre-existentes tolerados). ~243 tests verdes.

- [ ] T017 Documentación: bump `pubspec.yaml` a `0.7.1+59` +
  `android/app/build.gradle.kts` (`versionCode = 59`, `versionName =
  "0.7.1"`). Nota del cambio en pubspec.
  RF: —
  Depende de: T016
  Paralelizable: si (con T018)
  Criterio de terminado: ambos archivos consistentes.

- [ ] T018 Validación de calidad: `flutter build apk --release
  --split-per-abi` + `bash scripts/verify-apk.sh`.
  RF: CM-04
  Depende de: T017
  Paralelizable: no
  Criterio de terminado: 3 APKs construidos, `verify-apk.sh` OK con
  `versionCode 2059 / versionName 0.7.1`.

- [ ] T019 Documentación: crear
  `engineering/specs/flutter-movements-amount-filter-v1/implementation/resumen-extenso.md`
  + `resumen-ejecutivo.md` + `implementation-review.md` con la
  trazabilidad del sprint.
  RF: —
  Depende de: T018
  Paralelizable: no
  Criterio de terminado: 3 archivos creados, listos para commit.
