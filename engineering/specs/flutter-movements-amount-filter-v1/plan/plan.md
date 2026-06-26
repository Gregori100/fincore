# Plan técnico — flutter-movements-amount-filter-v1

## Enfoque técnico

Sprint chico (~2-3h) que **extiende** el sistema de filtros existente
sin redesign. La estrategia es **aditiva en 5 capas**:

1. **Modelo**: extender `EntriesFilters` con `minAmount: double?` y
   `maxAmount: double?` + `copyWith` con sentinels para limpiar.
   Extender `FilterDimension` enum.
2. **DAO**: extender `EntriesDao.watchPage` con 2 params opcionales que
   agregan `journal_entries.amount.isBiggerOrEqualValue` /
   `isSmallerOrEqualValue`.
3. **Panel**: agregar sección "Monto" en `EntriesFiltersScreen` entre
   "Cuenta" y "Categorías" con 2 `TextFormField` + validación
   `min > max` en `_apply`.
4. **Bar**: agregar chip de monto en `EntriesActiveFiltersBar` con
   helper de label (`"≥ $X"`, `"≤ $X"`, `"$X – $Y"`).
5. **Lista**: `EntriesPaginatedList` pasa `minAmount`/`maxAmount` al
   `watchPage` y compara también en `_filtersChanged` para resetear
   paginación.

Cero schema bump, cero deps externas, cero cambios productivos
breaking. Los nuevos campos del modelo y del DAO son **opcionales con
default null** para preservar callers existentes.

## Requisitos funcionales cubiertos

- **RF-001**: campos `minAmount`/`maxAmount` en `EntriesFilters` (T002).
- **RF-002**: `copyWith` con `bool clearMinAmount`/`clearMaxAmount` (T003).
- **RF-003**: `FilterDimension.amount` (T005).
- **RF-004**: `clearDimension(FilterDimension.amount)` (T004).
- **RF-005**: `activeCount` incluye amount como 1 dimensión (T004).
- **RF-006**: `parse(queryParameters)` lee `minAmount`/`maxAmount`
  con validación (T004).
- **RF-007**: `toDeepLink()` serializa ambos cuando están presentes (T004).
- **RF-008**: `EntriesDao.watchPage` acepta `minAmount`/`maxAmount`
  opcionales (T006).
- **RF-009**: sección "Monto" en el panel entre "Cuenta" y "Categorías"
  (T007).
- **RF-010**: 2 `TextFormField` con prefijo `$`, keyboard decimal,
  input formatter (T007).
- **RF-011**: validación `min > max` en `_apply` con snackbar warning
  (T009).
- **RF-012**: chip de monto en la bar con label condicional (T008).
- **RF-013**: `_filtersChanged` detecta cambios en `minAmount`/
  `maxAmount` (T010).
- **RF-014**: `EntriesListScreen` sin cambios productivos — confirmado
  por construcción (T010).

## Archivos o módulos probablemente afectados

Modificados:

- `mobile/lib/data/entries_filters.dart` (+~50 líneas: 2 campos,
  copyWith con clear sentinels, clearDimension, activeCount, parse,
  toDeepLink, FilterDimension enum).
- `mobile/lib/data/daos/entries_dao.dart` (+~12 líneas: 2 params en
  signature + 2 where clauses).
- `mobile/lib/screens/entries_filters_screen.dart` (+~70 líneas:
  sección "Monto" + 2 controllers + validación en `_apply`).
- `mobile/lib/widgets/entries_active_filters_bar.dart` (+~30 líneas:
  chip de monto + helper `_amountLabel`).
- `mobile/lib/widgets/entries_paginated_list.dart` (+~6 líneas:
  comparar `minAmount`/`maxAmount` + pasar al `watchPage`).
- `mobile/test/data/entries_dao_filters_test.dart` (+~120 líneas:
  grupo nuevo `watchPage — amount`).
- `mobile/test/data/entries_filters_test.dart` (+~60 líneas: tests del
  modelo).
- `mobile/test/screens/entries_filters_screen_test.dart` (+~80 líneas:
  3 tests del panel + chip).
- `mobile/pubspec.yaml` (bump 0.7.1+59 + nota).
- `mobile/android/app/build.gradle.kts` (versionCode 59 / versionName
  0.7.1).

No tocados intencionalmente:

- `entries_list_screen.dart`: el padre solo pasa `_filters` al hijo;
  no necesita awareness del nuevo campo.
- `reports/*`: el cashflow agrega por mes sin tocar amount individual;
  fuera de alcance.
- `entries_dao.dart` métodos de write (`registerExpense`, etc.): sin
  cambios.

## Entidades y estados afectados

- **`EntriesFilters`** (inmutable): pasa de 5 dimensiones efectivas
  (date, kinds, accountIds, categoryIds) a 6 (agregando amount).
  Invariante: si `minAmount != null && maxAmount != null` entonces
  `minAmount <= maxAmount` cuando se aplica (no cuando se construye —
  el panel valida; el constructor no defensivo).
- **`FilterDimension`** enum: `{date, kinds, accounts, categories,
  amount}`.
- **`journal_entries.amount`**: solo lectura. Convención RN-A01:
  siempre positivo, signo deriva del kind. El filtro respeta esto sin
  conversión.
- **Sin transiciones de estado** nuevas. Sin invariantes en BD nuevos.

## Compatibilidad con datos y procesos existentes

- **Backward compatible**:
  - `EntriesFilters(...)` con args existentes sigue funcionando porque
    los nuevos campos son opcionales con default null.
  - `EntriesDao.watchPage(...)` con args existentes sigue funcionando.
  - El cashflow y el spending tab no consultan estos campos.
  - Tests existentes que construyen `EntriesFilters` sin amount siguen
    pasando.
- **Sin migración** de schema.
- **Reactividad coherente**: drift re-emite el stream cuando cambian
  `journal_entries` (incluye cancelaciones que mueven entries dentro/
  fuera del rango de monto).
- **Deep links existentes**: query params `from`, `to`, `kinds`,
  `accountIds`, `categoryIds` siguen funcionando; `minAmount` y
  `maxAmount` son aditivos.

## Cambios de datos

No aplica (sólo lectura).

## Cambios de API

No aplica (app local sin red).

## Cambios de integraciones

No aplica.

## Cambios de UI

- `EntriesFiltersScreen` gana una sección "Monto" entre "Cuenta" y
  "Categorías". Sin re-layout del resto del panel.
- `EntriesActiveFiltersBar` gana un chip más cuando aplica. El
  `ListView` horizontal absorbe sin overflow gracias al scroll.
- Sin cambios en `EntriesListScreen` ni en `EntriesPaginatedList`
  visualmente.

## Cambios de permisos

No aplica (single-user local).

## Riesgos técnicos

- **R-T01** (bajo): el `copyWith` con `bool clearMinAmount` /
  `bool clearMaxAmount` introduce un patrón que `EntriesFilters` no
  usa hoy para los otros campos. Justificación: los demás campos son
  `List<String>` o `DateTime` no-nullable; null no es un valor válido
  para limpiar. Decisión documentada en spec R-01.
- **R-T02** (bajo): el `inputFormatter` con regex `[0-9.]` permite
  múltiples puntos. Mitigación: el panel valida con `double.tryParse`
  al `_apply`; si parsea null, equivale a no aplicar el campo.
- **R-T03** (bajo): el chip "≥ $X" / "≤ $X" usa caracteres no-ASCII.
  Validado por construcción: el `_ActiveChip` ya renderea acentos
  (chips de fecha con "—" y de cuenta con "(archivada)").
- **R-T04** (bajo): el snackbar del panel se muestra dentro del
  `EntriesFiltersScreen` (no del `EntriesListScreen`). Patrón ya usado
  por el date picker custom. Sin riesgo de stale context.
- **R-T05** (medio): tests del `EntriesFilters` (parse, toDeepLink,
  copyWith) pueden tener constructores con `kinds`, `accountIds`,
  `categoryIds` explícitos sin `minAmount`/`maxAmount`. Mitigación:
  default null no requiere cambios en tests viejos.

## Estrategia de pruebas

3 niveles:

1. **Tests data** del DAO (6 nuevos): cubren las combinaciones
   solo-min / solo-max / ambos / iguales / combinado con kind+fecha /
   regresión sin filtro.
2. **Tests del modelo** (`entries_filters_test.dart` si existe, o
   uno nuevo): parse, toDeepLink, copyWith con clear sentinels,
   clearDimension, activeCount.
3. **Widget tests** (3 nuevos en `entries_filters_screen_test.dart`):
   sección "Monto" renderea, chip activo cuando solo min, validación
   `min > max` muestra snackbar.

Ver `test-plan.md` para detalle exhaustivo.

## Estrategia de rollback

- **Sin migración** → rollback es trivial: revert del commit.
- Si el panel rompe en producción, hot-fix puede ocultar la sección
  con un feature flag temporal (no implementado, pero el patrón es
  posible).
- No hay state persistente nuevo (los filtros viven solo en memoria
  del screen).

## Orden sugerido de implementación

Fases en serie con paralelización dentro:

- **F0**: baseline 235 verdes.
- **F1**: modelo `EntriesFilters` (T002-T004) + enum (T005). T002-T005
  son secuenciales dentro del archivo.
- **F2**: DAO `watchPage` (T006). Independiente de F3+.
- **F3**: UI panel (T007, T009) + bar (T008) + lista (T010).
  T007-T010 paralelizables entre sí porque tocan archivos distintos.
- **F4**: Tests (T011-T015). T011 (DAO), T012 (modelo), T013-T015
  (panel/bar) paralelizables.
- **F5**: Release (T016-T019). T017+T018 paralelizables.

## Casos borde que condicionan la solución

- **CB-T01** (zonas horarias): no aplica al filtro de monto.
- **CB-T02** (concurrencia): otro tab/pantalla registra un entry con
  monto fuera del rango activo. El Stream re-emite sin él. Sin reset
  de paginación.
- **CB-T03** (deep link con `minAmount=abc`): `double.tryParse`
  retorna null → ignorado. Cubrir en test del modelo.
- **CB-T04** (deep link con `minAmount=-500`): negativos ignorados en
  `parse`. Cubrir en test del modelo.
- **CB-T05** (`minAmount == 0`): cuenta como dimensión activa (Diego
  lo escribió) y filtra `amount >= 0` (trivialmente todos). UX
  coherente con escribir explícitamente cero.

## Preguntas o supuestos que siguen afectando la implementación

Sin preguntas abiertas. Todos los supuestos documentados en
`spec.md` (sección Supuestos) y `checklist.md`. Resaltados los más
relevantes:

- Filtrar por **amount crudo** (sin signo).
- **Inclusivo** en ambos extremos.
- Validación `min > max` **al "Aplicar"** (no en tiempo real al typing).
- **Sección "Monto" entre "Cuenta" y "Categorías"** en el orden
  visual.
- Nuevos campos del modelo y DAO son **opcionales con default null**
  para preservar callers existentes.
