# Branch Quality Review: flutter-movements-filters-v1

## Metadata

- Fecha: 2026-06-25
- Rama revisada: `main` (commit `97c13b6` recién creado, no pusheado)
- Rama base: `origin/main` (los commits previos `5138326`, `f0767ff`, `35bfad4` ya están en main local pero no pusheados)
- Rango: `97c13b6~1..97c13b6` (28 archivos, +3546/-447 líneas)
- Commit HEAD: `97c13b6f84acbb38c6e03f587a0799741a4f4fd7`
- Autor de revisión: 6 subagentes Explore en paralelo (SQL/perf, arquitectura, frontend, tests, concurrencia, UX, seguridad) + integración
- Carpeta de reporte: `engineering/quality-review/flutter-movements-filters-v1/`

## Resumen ejecutivo

- **Estado: entregable con correcciones recomendadas antes del próximo push.** Sin hallazgos críticos de seguridad ni integridad de datos. Hay 1 bloqueante de trazabilidad (desviaciones de UI sin documentar) y varios issues menores de UX y arquitectura.
- **Capa de datos sólida.** El DAO con `kinds`/`accountIds`/`categoryIds` está bien parametrizado vía Drift (cero riesgo de SQL injection). El JOIN con filtro de archivadas en el ON sigue cubriendo el bucket "Sin categoría" elegantemente.
- **Hallazgo más relevante: desviaciones de UI no documentadas (U1+U2+U3+U4).** El spec original decía single-select para kinds (con preset "Gastos") y single-select para cuenta. Tras feedback de Diego se cambiaron a multi-select, pero el cambio NO está registrado en `desviaciones-plan.md`. Trazabilidad rota — auditor futuro no podrá rastrear por qué la implementación no coincide con RF-008/RF-009/RF-012/CA-06.
- **Mejora de accesibilidad relevante: tap target del "X" en chips de filtros activos (F1).** Hoy es ~18dp efectivos; Material guideline pide ≥44dp. Difícil de tappear en cel.
- **Constante `kUncategorizedFilterToken` vive en el DAO pero se importa desde 4 archivos (A1).** Riesgo si se cambia el valor. Vale mover a `lib/constants/`.
- **Test diferido reactivable (T1).** El widget test del deep link via URL puro se difería por `pumpAndSettle` colgándose con StreamBuilders anidados en `_ActiveFiltersBar`. El patch perf v1 eliminó esos StreamBuilders — debería poder reactivarse.
- **Mutación de `_filters` fuera de `setState` (C2).** En `_removeDimension` y `_openFilters` se hace `_filters = ...` antes del `setState(_buildStream)`. Ventana de inconsistencia teórica si un build intermedio captura la asignación nueva sin el stream nuevo. Fácil de corregir.
- **Sin riesgo confirmado en C1** (preset recalculado con `DateTime.now()`): el reporte siempre usa `DateRangePreset.custom` con fechas absolutas para el deep link. El riesgo del subagente aplicaba a deep links manualmente construidos con preset relativo — no es vector real desde el flujo del producto.
- **Override `colorScheme.secondaryContainer = accent` (F4).** Necesario para arreglar el chip verde, pero afecta a otros componentes M3 (Badge, NavigationBar futura). Sin componentes en uso hoy, pero hay que documentar.

## Alcance revisado

- **Commits del sprint** (1 único commit):
  - `97c13b6 feat(mobile): sprint flutter-movements-filters-v1 — panel de filtros + deep link`
- **28 archivos** modificados/creados/movidos:
  - Nuevos: `entries_filters.dart`, `entries_filters_screen.dart`, `date_range_presets.dart`, `date_field_outlined.dart`, 5 archivos de tests, 11 archivos de `engineering/specs/flutter-movements-filters-v1/`.
  - Modificados: `entries_dao.dart`, `entries_list_screen.dart`, `spending_by_category_tab.dart`, `fincore_theme.dart`, `pubspec.yaml`, `build.gradle.kts`.
  - Eliminados: `lib/screens/reports/range_presets.dart` (movido a constants).
- **Áreas auditadas**: SQL + performance, arquitectura/DDD, frontend/design system, tests/regresión, concurrencia/integridad, UX/trazabilidad, seguridad.
- **Comandos usados**: `git log`, `git diff --stat`, `git diff --name-only`, lecturas con Read/grep sobre los archivos del sprint, validación cruzada con `spec.md` y `desviaciones-plan.md`.

## Hallazgos bloqueantes

### B1. Desviaciones de UI multi-select no documentadas en `desviaciones-plan.md`

- Severidad: Alta
- Área: UX / Trazabilidad spec → implementación
- Evidencia:
  - `spec.md` RF-008: *"Selección única (radio-like). 'Gastos' mapea a `kinds = ['expense', 'credit_expense']`; los otros a single kind."*
  - `spec.md` RF-009: *"Single-select. 'Todas' como chip al inicio para desactivar."*
  - `spec.md` RF-012: *"query params del router: `from`, `to`, `kinds` (csv), `categoryIds` (csv), `accountId`."* (singular)
  - `spec.md` CA-06: *"filtro 'Gastos' muestra `expense + credit_expense` y ningún otro."*
  - Implementación real (`entries_filters_screen.dart:225-250`): 5 chips `FilterChip` multi-select para tipo (sin preset "Gastos"), chips multi-select para cuenta (sin chip "Todas"). Modelo `EntriesFilters.accountIds: List<String>` (plural).
  - Comentario en `entries_filters.dart:14-16`: *"Patch v3 — `kinds`, `accountIds` y `categoryIds` son listas multi-select. ... ya no existe un preset 'Gastos' combinado."*
  - `desviaciones-plan.md` no tiene Desviación-6 ni Desviación-7 documentando estos cambios.
- Impacto: el lector del spec ve definiciones que no coinciden con el código. Cualquier auditoría futura marcará inconsistencia sin contexto. El CA-06 ("filtro 'Gastos'") es literalmente inverificable porque "Gastos" no existe como concepto en la UI actual.
- Recomendación: agregar dos desviaciones nuevas a `desviaciones-plan.md`:
  - **Desviación-6**: `kinds` multi-select reemplaza al preset "Gastos" combinado (feedback de Diego durante smoke, *"debió de haber sido seleccion multiple"*).
  - **Desviación-7**: `accountIds` multi-select reemplaza al `accountId` single-select + chip "Todas" (consistencia con `kinds` y `categoryIds`). Ningún chip seleccionado = todas las cuentas.
  - Notar que CA-06 queda invalidado y proponer reescritura: *"con `kinds = ['expense', 'credit_expense']` (ambos chips marcados), la lista muestra entries con `kind IN ('expense', 'credit_expense')` y ningún otro."*
- Depende de: nada.

## Hallazgos no bloqueantes

### M1. `kUncategorizedFilterToken` no centralizado — riesgo de duplicación

- Severidad: Alta (no bloqueante por ser internal-only)
- Área: Arquitectura / DDD
- Evidencia: constante `kUncategorizedFilterToken = '__null__'` en `mobile/lib/data/daos/entries_dao.dart:62`. Importada y usada en:
  - `entries_filters_screen.dart:269` (chip "Sin categoría").
  - `entries_list_screen.dart:301` (label en bar de filtros activos).
  - `spending_by_category_tab.dart:320` (construcción del deep link).
  - `entries_dao.dart` (lógica del filtro SQL).
- Impacto: si se renombra a `'__uncategorized__'` o `null` literal, alto riesgo de olvido en uno de los 4 sitios → deep link roto, filtros inconsistentes.
- Recomendación: mover a `mobile/lib/constants/filter_tokens.dart` (nuevo) o agregar a `mobile/lib/constants/kinds.dart` con docstring claro. El DAO sigue siendo dueño de la lógica pero la constante vive en `constants/`.
- Depende de: nada. Cambio de 1 import + 1 archivo nuevo.

### M2. Tap target del "X" en chips de filtros activos subminimum

- Severidad: Alta (no bloqueante, pero impacta UX táctil real)
- Área: Frontend / Accesibilidad
- Evidencia: `mobile/lib/screens/entries_list_screen.dart:343-350`:
  ```dart
  InkWell(
    onTap: onRemove,
    borderRadius: BorderRadius.circular(10),
    child: const Padding(
      padding: EdgeInsets.all(2),
      child: Icon(Icons.close, size: 14, color: FincoreColors.accent),
    ),
  ),
  ```
  Tap target efectivo: 14 (icono) + 2*2 (padding) = ~18dp. Material Design 3 guideline mínimo: 44dp (Apple HIG: 44pt, Google: 48dp).
- Impacto: difícil tappear el "X" en el cel real. Diego tiende a tappear el chip entero por error y abre una acción incorrecta o nada.
- Recomendación: envolver el `InkWell` en `SizedBox(width: 44, height: 44)` con `Center` o usar `IconButton` minimal con `padding: EdgeInsets.zero` + `constraints: BoxConstraints(minWidth: 44, minHeight: 44)`.
- Depende de: nada.

### M3. Test diferido del deep link via URL puro reactivable

- Severidad: Alta (gap de cobertura)
- Área: Pruebas
- Evidencia: `mobile/test/screens/entries_list_screen_test.dart:130-142` documenta diferimiento por: *"cuando `EntriesListScreen` rinde `_ActiveFiltersBar` (que tiene 2 StreamBuilders anidados ...) cuelga `pumpAndSettle`"*. El patch perf v1 (0.5.1+48) eliminó esos StreamBuilders — `_ActiveFiltersBar` ahora recibe `accounts` y `categories` como `List<>` resueltas del padre (`entries_list_screen.dart:204-205`).
- Impacto: gap de cobertura sobre RF-012 (lectura de query params del router). El flujo end-to-end desde el reporte (`reports_deeplink_test.dart`) cubre la mayoría, pero no el deep link manual via URL.
- Recomendación: reactivar el test borrando el comentario de diferimiento y descomentando la implementación. Si vuelve a colgar, diagnosticar la nueva causa raíz (puede ser otra). Si pasa, sumar cobertura RF-012 directa.
- Depende de: nada.

### M4. `_filters` mutado fuera de `setState`

- Severidad: Media
- Área: Concurrencia / Frontend
- Evidencia:
  - `entries_list_screen.dart:104-105` (`_openFilters`): `_filters = result; _rebuildStream();` (donde `_rebuildStream` hace `setState`).
  - `entries_list_screen.dart:114-129` (`_removeDimension`): `_filters = _filters.copyWith(...)` antes del `_rebuildStream()` final.
- Impacto: ventana teórica de inconsistencia. Si un `build()` se dispara entre la asignación y el `setState`, capturaría `_filters` nuevo sin `_stream` nuevo. En la práctica el async gap es nulo o casi nulo, pero es anti-patrón.
- Recomendación: envolver TODO el cambio dentro de `setState`:
  ```dart
  setState(() {
    _filters = _filters.copyWith(...);
    _buildStream();
  });
  ```
- Depende de: nada.

### M5. Chip de filtro activo muestra "Categoría" cuando se archiva entre tanto

- Severidad: Media
- Área: UX
- Evidencia: `entries_list_screen.dart:299-307`:
  ```dart
  String _categoriesLabel(List<String> ids) {
    if (ids.length == 1) {
      if (ids.first == kUncategorizedFilterToken) return 'Sin categoría';
      for (final c in categories) {
        if (c.id == ids.first) return c.name;
      }
      return 'Categoría';  // fallback genérico
    }
    return '${ids.length} categorías';
  }
  ```
  Si Diego tiene `categoryIds = ['cat-123']` y archiva esa categoría desde otra pantalla, `_categories` ya no la incluye (porque viene de `watchActive()`).
- Impacto: chip activo dice "Categoría" sin contexto. El filtro en BD sigue funcionando (entries históricos con esa categoría no se ven porque ya están en bucket "Sin categoría" virtual). UX confusa.
- Recomendación: mostrar `'Categoría (archivada)'` o auto-limpiar el filtro cuando la categoría se archiva. Decisión de UX.
- Depende de: nada.

### M6. Override `colorScheme.secondaryContainer = accent` sin auditoría completa

- Severidad: Media
- Área: Frontend / Design system
- Evidencia: `mobile/lib/theme/fincore_theme.dart:20` (override agregado en este sprint).
  ```dart
  secondaryContainer: FincoreColors.accent,
  onSecondaryContainer: FincoreColors.canvas,
  ```
- Impacto: Material 3 usa `secondaryContainer` en varios componentes (Badge, NavigationBar, AppBar tint, FilledTonalButton, ListTile selected). Hoy el proyecto no usa ninguno de esos. Pero futuros sprints sí los podrían introducir y tomarán accent sin que el desarrollador lo note.
- Recomendación: agregar al docstring del override una lista de componentes M3 que tomarán este color. Mejor aún: extraer el override a un comentario que diga "TODO: si se introduce Badge/NavigationBar, verificar consistencia visual".
- Depende de: nada (documentación).

### M7. `_FilterDimension` enum privado duplica las dimensiones de `EntriesFilters`

- Severidad: Media
- Área: Arquitectura
- Evidencia: `entries_list_screen.dart:225` define `enum _FilterDimension { date, kinds, accounts, categories }` que mapea 1-a-1 con campos de `EntriesFilters`.
- Impacto: si se agrega dimensión nueva (ej. `amountRange`), hay que recordar actualizar ambos lugares. El switch exhaustive del Dart 3 ayuda, pero es señal de duplicación de dominio.
- Recomendación: mover a extension method de `EntriesFilters`. Ejemplo:
  ```dart
  enum FilterDimension { date, kinds, accounts, categories }
  extension EntriesFiltersClearing on EntriesFilters {
    EntriesFilters clear(FilterDimension dim) { ... }
  }
  ```
  Así `EntriesFilters` es la fuente única de verdad.
- Depende de: nada.

### M8. `SpendingByCategoryTab` acoplado a `.serialize()` de `EntriesFilters`

- Severidad: Media
- Área: Arquitectura / Cohesión
- Evidencia: `spending_by_category_tab.dart:319-329` construye `EntriesFilters` directamente y llama `.serialize()`. El reporte conoce el formato interno del filtro.
- Impacto: si la estrategia de serialización cambia (ej. URLs aún más cortas), el reporte queda frágil.
- Recomendación: agregar factory en `EntriesFilters`:
  ```dart
  factory EntriesFilters.forCategoryBucket({
    required String? categoryId,
    required DateTime from,
    required DateTime to,
  }) {
    return EntriesFilters(
      datePreset: DateRangePreset.custom,
      from: from, to: to,
      kinds: const ['expense', 'credit_expense'],
      categoryIds: [categoryId ?? kUncategorizedFilterToken],
    );
  }
  ```
  El reporte solo llama `filters.toDeepLink()` (otro helper).
- Depende de: A1 (centralizar token).

### M9. `EntriesFilters.copyWith` no clona listas internas

- Severidad: Media
- Área: Concurrencia / Inmutabilidad
- Evidencia: `entries_filters.dart:60-76`:
  ```dart
  EntriesFilters copyWith({ List<String>? kinds, ... }) {
    return EntriesFilters(kinds: kinds ?? this.kinds, ...);
  }
  ```
  Pasa la referencia tal cual. El constructor no clona.
- Impacto: si un caller obtiene `filters.kinds` y muta vía `.add()`, corrompe el estado inmutable. Hoy todos los callers usan `.toList()` antes de mutar, así que está seguro en la práctica.
- Recomendación: `kinds: kinds != null ? List.unmodifiable(kinds) : this.kinds` (y mismo patrón para `accountIds` y `categoryIds`). Defensa preventiva.
- Depende de: nada.

### M10. Tests del panel con `accounts: []` + `categories: []` son falso positivo

- Severidad: Media
- Área: Pruebas
- Evidencia: `entries_filters_screen_test.dart:35-36`:
  ```dart
  EntriesFiltersScreen(initial: initial, accounts: const [], categories: const []),
  ```
  Comentario del helper: *"pasamos listas vacías por default (suficiente para validar el render del panel y los chips fijos)"*. Pero el panel debería renderizar chips reales de cuentas/categorías.
- Impacto: no validamos render con N cuentas, ni interacción multi-select real, ni scroll vertical del Wrap con muchas categorías.
- Recomendación: agregar `EntriesFiltersScreen — render con datos` que sembra 3 cuentas + 5 categorías y valida que aparecen sus chips. Mismo helper, con factory de datos realistas.
- Depende de: nada.

### M11. Falta indicador de truncamiento cuando journal > 200

- Severidad: Media
- Área: UX
- Evidencia: `entries_list_screen.dart:83` (`limit: 200` fijo) + `_EmptyState` solo cubre lista vacía. Sin indicador cuando hay 250 entries y solo se muestran 200.
- Impacto: Diego ve subset sin saber. Spec S-01 dijo que paginación es futura, pero no documenta UX intermedia.
- Recomendación: agregar footer simple debajo de la lista cuando `entries.length == limit`: *"Mostrando primeros 200. Ajustá filtros para ver más recientes."* O bumpear el limit a 500 si la query rinde.
- Depende de: nada.

### M12. Estado vacío con filtros activos sin botón "Limpiar"

- Severidad: Media
- Área: UX
- Evidencia: `entries_list_screen.dart:358-377` (`_EmptyState`): muestra texto pero no acción.
- Impacto: Diego tiene que abrir el panel (tap tune) o tappear "X" en chips uno por uno para limpiar.
- Recomendación: agregar `OutlinedButton.icon` con `Icons.refresh` + label *"Limpiar filtros"* dentro del `_EmptyState` cuando `hasFilters = true`. Tap → `_filters = EntriesFilters.thisMonth()` + rebuild.
- Depende de: nada.

### M13. Validación `from > to` en panel sin widget test

- Severidad: Media
- Área: Pruebas / UX
- Evidencia: el panel tiene la lógica de `showWarningSnackbar` cuando el rango es inválido (`entries_filters_screen.dart:67-72, 90-94`). Pero ningún widget test la cubre. El unit test de `EntriesFilters.parse` valida fallback a `thisMonth`, no la UI.
- Impacto: regresión silenciosa si se refactoriza `_pickFrom`/`_pickTo`.
- Recomendación: agregar widget test que simule selección de fecha inválida (mockeando `showDatePicker` o usando approach indirecto). Si es muy frágil, dejar como pendiente.
- Depende de: nada.

### M14. Cobertura faltante de transfer + multi-account

- Severidad: Media
- Área: Pruebas
- Evidencia: el test "accountIds multi" en `entries_dao_filters_test.dart:260-269` valida que filtrar por `[bolsa, debit]` retorna 6 entries. El seed tiene 1 transfer (debit → bolsa). El test no valida explícitamente que **el transfer aparece en `accountIds=[bolsa]`** Y **también en `accountIds=[debit]`** (por el `OR`).
- Impacto: si el SQL cambia el `OR` a `AND` por error, el test general no detecta.
- Recomendación: agregar 2 tests específicos del transfer: matchea en single-account = origin y matchea en single-account = destination.
- Depende de: nada.

### B2. OR sin index merge con multi-account (performance futura)

- Severidad: Baja
- Área: SQL / Performance
- Evidencia: `entries_dao.dart:122-125`: `WHERE accountOriginId IN (...) | accountDestinationId IN (...)`. SQLite no usa Index Merge sobre 2 columnas distintas con OR.
- Impacto: con journal > 5000 entries + multi-account, query degrada a table scan parcial. Hoy con < 500 entries, imperceptible.
- Recomendación: monitorear con journal grande. Si degrada, opciones: (a) índice compuesto `(account_origin_id, account_destination_id)` (no ayuda con OR), (b) reescribir como `UNION` de dos sub-queries. Documentar en `database.dart` cerca del comentario M7 del quality review previo.
- Depende de: nada.

### B3. Resolución lineal de nombres O(N) en chips activos

- Severidad: Baja
- Área: Performance
- Evidencia: `entries_list_screen.dart:289-307` itera `for (final c in categories)` por cada chip activo.
- Impacto: con 100 cuentas/categorías + 5 chips, ~500 comparaciones por rebuild. Imperceptible.
- Recomendación: solo si crece, cachear como `Map<String, Account>` en state.
- Depende de: nada.

### B4. Deprecación de `kind: String?` y `accountId: String?` sin deadline

- Severidad: Baja
- Área: Documentación / Trazabilidad
- Evidencia: `entries_dao.dart` tiene `@Deprecated('Será eliminado en sprint posterior.')` sin sprint específico.
- Impacto: deuda permanente que nadie reactiva.
- Recomendación: agregar a `pendientes.md` del sprint con criterio claro de eliminación (ej. "cuando `grep -rn "watchPage(kind:\|watchPage(accountId:" mobile/` retorne 0 matches").
- Depende de: nada.

### B5. Sin validación de UUIDs en `accountIds`/`categoryIds` del parse

- Severidad: Baja
- Área: Seguridad / Defensa
- Evidencia: `entries_filters.dart:153-156`: `accountIds = _parseCsv(params['accountIds']).toSet().toList()`. Sin validación de formato UUID v7. Contrasta con `kinds` que filtra por whitelist `_kValidKinds`.
- Impacto: IDs malformados pasan al DAO. Drift parametriza (sin SQL injection), pero la query retorna 0 resultados silenciosamente. UX peor que rechazo explícito.
- Recomendación: agregar regex de UUID v7 en `_parseCsv` para `accountIds` y `categoryIds`. El token `__null__` debe pasar el filter como caso especial.
- Depende de: nada.

### B6. Loading state con `SizedBox.shrink()` puede sentirse abrupto

- Severidad: Baja (decisión consciente)
- Área: Frontend / UX
- Evidencia: `entries_list_screen.dart:203-204`. Justificado por bug sistémico con SkeletonCard + pumpAndSettle.
- Impacto: en cel con journal grande (>1k entries) puede notarse el "flash" antes de que aparezca la lista. Sin journal grande, invisible.
- Recomendación: documentado y aceptado. Si Diego reporta UX poor en cel real, considerar `BaseCard` estático con texto "Cargando..." (mismo patrón que `SpendingByCategoryTab._LoadingState`).
- Depende de: nada.

### N1. Subagente C1 (preset recalculado con `DateTime.now()`) descartado tras verificación

- Severidad: Nota
- Área: Concurrencia (false positive)
- Evidencia: el subagente concurrencia advertía que un deep link `?datePreset=last_month` recalculado en otro momento daría rango distinto. Verificación del código real (`spending_by_category_tab.dart:319-329`): el reporte SIEMPRE construye el deep link con `DateRangePreset.custom` + fechas absolutas `from`/`to`. Nunca usa preset relativo.
- Impacto: ninguno desde el flujo del producto. El riesgo solo aplicaría a deep links manualmente construidos por el usuario con preset relativo.
- Recomendación: ninguna. Documentar en la nota de Desviación-7 (cuando se cree) que el flujo producto es seguro.

### N2. Sin riesgo de SQL injection ni exposición de auth

- Severidad: Nota
- Área: Seguridad
- Evidencia: Drift parametriza todas las queries (`isIn`, `equals`, `customSelect.variables`). Sin endpoints HTTP nuevos. Sin logs sensibles introducidos.
- Impacto: ninguno.
- Recomendación: ninguna.

## Plan de corrección ordenado

Orden por dependencia y costo. Las correcciones B1 son **bloqueantes** para el commit/push formal del sprint; el resto son recomendadas.

1. **B1 — Documentar desviaciones-6 y -7** en `engineering/specs/flutter-movements-filters-v1/implementation/desviaciones-plan.md` (kinds multi-select reemplaza preset "Gastos", accountIds multi-select reemplaza single-select + chip "Todas"). Anotar invalidación de CA-06. ~15 min. Cero código.
2. **M1 — Centralizar `kUncategorizedFilterToken`** en `lib/constants/filter_tokens.dart`. Actualizar 4 imports. ~5 min.
3. **M2 — Tap target del "X" en `_ActiveChip`** envolviendo InkWell en `SizedBox(width: 44, height: 44)`. ~5 min.
4. **M4 — Mover mutaciones de `_filters` dentro de `setState`** (2 sitios). ~5 min.
5. **M3 — Reactivar test diferido del deep link via URL**. Borrar el comentario, descomentar y correr `flutter test`. Si pasa, ~10 min; si no, diagnosticar.
6. **M9 — `EntriesFilters.copyWith` con `List.unmodifiable`**. Defensa preventiva. ~10 min.
7. **M5 — Chip de filtro activo de categoría archivada con `"(archivada)"`**. ~10 min.
8. **B4 — Documentar deprecaciones en `pendientes.md`** con criterio claro. ~5 min.
9. **B5 — Validar UUIDs en `_parseCsv` con regex**. ~15 min (incluye 2 tests).
10. **M6 — Comentario auditoría `secondaryContainer`** en `fincore_theme.dart`. ~3 min.
11. **M11 — Indicador "mostrando 200 de N"** debajo de la lista cuando `entries.length == limit`. ~15 min.
12. **M12 — Botón "Limpiar filtros"** en `_EmptyState` cuando `hasFilters`. ~10 min.
13. **M10 — Tests del panel con datos reales** (cuentas + categorías sembradas). ~20 min.
14. **M13 — Widget test de rango inválido**. ~15 min.
15. **M14 — Tests del transfer en single-account**. ~10 min.

Diferidos a sprints futuros:

- M7 (`_FilterDimension` a extension): refactor, esperar siguiente sprint de UI.
- M8 (factory `EntriesFilters.forCategoryBucket`): mejora de cohesión, no urgente.
- B2 (índice futuro para multi-account OR): cuando journal degrade.
- B3 (cache O(1) de nombres): cuando cuentas/categorías crezcan a 50+.
- B6 (Skeleton estático en loading): cuando Diego reporte UX poor.

## Validaciones recomendadas

```bash
cd mobile

# Tras aplicar las correcciones del plan:
flutter analyze   # 0 errores, 0 warnings esperado
flutter test      # 213+ verdes (más los reactivados M3 + nuevos M10/M13/M14)

# Validar UUIDs en parse (B5):
flutter test test/data/entries_filters_test.dart

# Smoke manual tras instalar nuevo APK:
# - Tap "X" del chip activo es alcanzable con el pulgar (M2).
# - Archivar categoría con filtro activo → chip dice "(archivada)" (M5).
# - Lista vacía con filtros → botón "Limpiar filtros" visible (M12).
# - 200 entries → texto "mostrando 200 de N" (M11).
```

## Limitaciones

- **No medí performance real en el cel**: la observación de Diego sobre lag percibido motivó el patch perf v1 (eliminar StreamBuilders anidados + SkeletonCard animado). No reproduje el escenario en cel real con journal grande.
- **No verifiqué el override `secondaryContainer`** en el resto del repo. M6 dice "auditar Badge/NavigationBar futuros". Hoy no veo esos componentes en uso, pero la auditoría completa requiere grep + scroll por todo `lib/screens/`.
- **No probé el reactivar del test diferido (M3)**: el plan dice "borrar comentario y correr". Si vuelve a colgar por otra causa, se necesita diagnóstico nuevo.
- **No audité commits previos al sprint actual**: el HEAD anterior (`5138326`) ya tuvo su quality review. Solo se validó que no introducen riesgo retroactivo al sprint actual.
- **Subagente concurrencia C1 descartado** tras verificación cruzada con el código real. Si el flujo del reporte cambia en el futuro y empieza a usar presets relativos para el deep link, reabrir el hallazgo.
- **Spec `desviaciones-plan.md` solo tiene Desviaciones 1-5**: las 6 y 7 (que este review pide agregar) no están. El sprint anterior `flutter-reports-v1` tuvo el mismo patrón — documentar es trabajo aparte del código.
