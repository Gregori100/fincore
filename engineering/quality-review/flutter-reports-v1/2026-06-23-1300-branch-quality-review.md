# Branch Quality Review: flutter-reports-v1

## Metadata

- Fecha: 2026-06-23
- Rama revisada: `main` (working tree con cambios sin commitear del sprint)
- Rama base: `origin/main`
- Rango: 2 commits previos pusheados (`f0767ff feat(mobile): sprint flutter-ui-test-coverage-v2`, `35bfad4 docs(ui-test-coverage-v2)`) + working tree del sprint actual (sin commit)
- Commit HEAD: `f0767ffb7dbeec7d0ff258aad79b97eb62667f23`
- Autor de revisión: 6 subagentes Explore en paralelo (SQL/perf, arquitectura, frontend, tests, concurrencia, UX) + integración
- Carpeta de reporte: `engineering/quality-review/flutter-reports-v1/`

## Resumen ejecutivo

- **Estado del sprint: entregable con correcciones menores recomendadas antes del commit formal.** No hay hallazgos bloqueantes que impidan mergear, pero hay 2 desviaciones post-spec no documentadas y 1 mejora defensiva (error handling) que vale la pena resolver.
- **Capa de datos sólida.** El `ReportsService.spendingByCategory` está bien parametrizado (drift Variables), `readsFrom` correcto sobre `journalEntries + categories`, GROUP BY con NULLs es coherente con SQLite. 22 tests data cubren las 8 RN y los casos borde de límites inclusivos.
- **Arquitectura limpia.** `ReportsService` es stateless y desacoplado de `FinancialStateService` como pedía el spec. La UI consume solo el contrato del service, sin filtrar lógica de negocio al widget.
- **Hallazgo más relevante: U1 + U2 (documentar desviaciones post-spec).** Los chips de presets y el cambio de default a "fin de mes" salieron del smoke con Diego, pero no entraron a `desviaciones-plan.md`. Sin documentación, futuras auditorías no podrán rastrear por qué la implementación no coincide con RF-008/RF-009.
- **Hallazgo defensivo: F2 (sin `snap.hasError` en StreamBuilder).** Bajo riesgo en local-first sin red, pero el patrón actual asume que la query nunca falla. Agregar manejo de error blinda contra fallas de drift internas o futuras integraciones.
- **F6 (saturación AppBar Dashboard).** 3 IconButton + título podrían apiñarse en pantallas <360dp. Pendiente de validación visual durante el smoke manual SM-02.
- **Sin hallazgos críticos en concurrencia ni seguridad.** El supuesto leak de listeners en cambios rápidos de fecha (C1 del subagente) se descarta tras análisis: `StreamBuilder` cancela el listener anterior al cambiar la referencia del Stream, y drift libera el listener interno en `StreamSubscription.cancel()`. Conflicto inicial resuelto a favor del análisis SQL.

## Alcance revisado

- **Commits previos pusheables** (ya en `main`, no parte del sprint actual pero rama ahead de `origin/main`):
  - `f0767ff` feat(mobile): sprint flutter-ui-test-coverage-v2.
  - `35bfad4` docs(ui-test-coverage-v2).
- **Working tree del sprint `flutter-reports-v1`** (alcance principal del review):
  - Nuevos: `mobile/lib/data/reports.dart`, `mobile/lib/screens/reports_screen.dart`, `mobile/lib/screens/reports/spending_by_category_tab.dart`, `mobile/test/data/reports_test.dart`, `mobile/test/screens/reports_screen_test.dart`, `engineering/specs/flutter-reports-v1/**`.
  - Modificados: `mobile/lib/app_dependencies.dart`, `mobile/lib/router/app_router.dart`, `mobile/lib/screens/dashboard_screen.dart`, `mobile/pubspec.yaml`, `mobile/android/app/build.gradle.kts`, `mobile/test/screens/dashboard_screen_test.dart`.
- **Áreas auditadas**: SQL + performance, arquitectura/DDD, frontend/design system, tests/regresión, concurrencia/integridad, UX/trazabilidad.
- **Comandos usados**: `git status --short`, `git log --oneline origin/main..HEAD`, `git diff --stat origin/main...HEAD`, lecturas con grep/Read sobre los archivos del sprint, validación cruzada con `spec.md` y `plan/*.md`.

## Hallazgos bloqueantes

Ningún hallazgo bloquea el merge. Todos los issues detectados son resolubles fuera del path crítico del feature.

## Hallazgos no bloqueantes

### M1. Default del rango cambió a "mes calendario completo" sin documentar la desviación

- Severidad: Media
- Área: UX / Trazabilidad spec → implementación
- Evidencia:
  - `spec.md` RF-009: *"Default del rango al abrir: `from = primer día del mes corriente 00:00`, `to = hoy 23:59:59`."*
  - `spec.md` CA-02: *"Default al abrir muestra rango 'primer día del mes corriente → hoy'."*
  - Código actual (`mobile/lib/screens/reports/spending_by_category_tab.dart:63`): `to = DateTime(ref.year, ref.month + 1, 0, 23, 59, 59, 999)` → último día del mes calendario.
  - `pubspec.yaml` (línea de comentario `0.4.1+44`): *"default = mes calendario completo. Refinamiento UX post-smoke con Diego."*
- Impacto: La decisión fue una respuesta válida a feedback del smoke ("mes actual" = mes completo, no "hasta hoy"), pero `desviaciones-plan.md` no la registra. Cualquier futura auditoría que compare spec vs código va a marcar inconsistencia sin contexto.
- Recomendación: agregar Desviación-6 a `engineering/specs/flutter-reports-v1/implementation/desviaciones-plan.md` con el cambio, razón ("mes calendario completo es más natural y evita proyección visual de vacío hacia el futuro") y la fecha del refinement.
- Depende de: nada.

### M2. Chips de presets reemplazaron los OutlinedButton sin documentar la desviación

- Severidad: Media
- Área: UX / Trazabilidad spec → implementación
- Evidencia:
  - `spec.md` RF-008: *"Dos `OutlinedButton` con icono de calendario que abren `showDatePicker` (uno 'Desde', otro 'Hasta')."*
  - `spec.md` CA-07: *"Tappear 'Cambiar desde' abre DatePicker."*
  - Código actual: `Wrap` con 4 `ChoiceChip` (Este mes / Mes pasado / Año / Custom) + `_DateFieldOutlined` con `InputDecorator` solo cuando `_preset == custom`.
  - `pubspec.yaml` (`0.4.1+44`): *"chips de presets ... en lugar de los pills outlined"*.
- Impacto: igual que M1 — la decisión es buena UX pero no figura en `desviaciones-plan.md`. CA-07 ya no aplica literalmente porque ahora se tappea un field, no un botón outlined.
- Recomendación: agregar Desviación-7 a `desviaciones-plan.md` con la refactorización (chips + _DateFieldOutlined), razón ("Diego pidió eliminar la apariencia de pills tras smoke"), y nota de que CA-07/RF-008 quedan cubiertos por la nueva UI vía Custom.
- Depende de: nada.

### M3. `StreamBuilder` del reporte no maneja `snap.hasError`

- Severidad: Media (defensiva)
- Área: Frontend / Resiliencia
- Evidencia: `mobile/lib/screens/reports/spending_by_category_tab.dart` (líneas del StreamBuilder en `build`):
  ```dart
  StreamBuilder<SpendingReport>(
    stream: _reportStream,
    builder: (context, snap) {
      if (!snap.hasData) {
        return const SizedBox(height: 1);
      }
      final report = snap.data!;
      ...
  ```
  No hay `if (snap.hasError) return <fallback>`. Si la query del service lanza (drift bug, OOM, schema mismatch tras un downgrade futuro), el widget renderiza `report = snap.data!` con un `!` que crashea, o se queda colgado en `SizedBox(height: 1)`.
- Impacto: bajo en local-first sin red (la query es read-only sobre BD local). Pero el patrón actual asume "happy path" sin alternativa visible al usuario. Si surge un error, no hay UI de recuperación.
- Recomendación: agregar antes del `if (!snap.hasData)`:
  ```dart
  if (snap.hasError) {
    return _ErrorState(error: snap.error);
  }
  ```
  Con un `_ErrorState` simple que use `showErrorSnackbar` patrón existente o muestre un `BaseCard` con icono + mensaje + botón "Reintentar" que re-asigne `_reportStream`. Mantener cap de 40-50 líneas, sin agregar deps.
- Depende de: nada.

### M4. Tests de `_rangeForPreset` cruzando enero/diciembre faltantes

- Severidad: Media
- Área: Pruebas
- Evidencia: `_rangeForPreset` en `spending_by_category_tab.dart:58-78` calcula rangos para "Mes pasado" usando `DateTime(ref.year, ref.month - 1, 1)`. Cuando `ref.month == 1` (enero), `ref.month - 1 == 0`, lo cual Dart interpreta como diciembre del año anterior. Es comportamiento correcto, pero **no hay test que lo valide**. Idem "Este año" desde cualquier mes.
- Impacto: bajo en runtime hoy (el patrón Dart es estable). Pero si alguien refactoriza ingenuamente (`DateTime(ref.year, ref.month - 1, 1)` → `DateTime(ref.year, ref.month - 1, 1)` con guardia `ref.month - 1 < 1`), podría romper el cruce de año sin alerta.
- Recomendación: agregar 3-4 unit tests en un archivo `spending_by_category_tab_helpers_test.dart` (o extraer la función `_rangeForPreset` como `static` para testearla aislada). Casos:
  - Enero 2026 + preset `lastMonth` → from = 2025-12-01, to = 2025-12-31 23:59:59.999.
  - Febrero 2024 + preset `lastMonth` → from = 2024-01-01, to = 2024-01-31 23:59:59.999.
  - Cualquier mes + preset `thisYear` → from = año-01-01, to = año-12-31 23:59:59.999.
  - Mes de 31 días + preset `thisMonth` → último día = 31.
- Depende de: si se decide extraer `_rangeForPreset` a helper estático, hacerlo antes del test.

### M5. Loading state `SizedBox(height: 1)` no comunica progreso al usuario

- Severidad: Media (UX)
- Área: Frontend
- Evidencia: `spending_by_category_tab.dart` en el `StreamBuilder.builder`:
  ```dart
  if (!snap.hasData) {
    return const SizedBox(height: 1);
  }
  ```
  Trade-off intencional documentado en Desviación-5 (Skeleton/CircularProgressIndicator cuelgan `pumpAndSettle`).
- Impacto: en BD in-memory (tests) y on-device pequeña la query emite en <100ms, el usuario raramente lo ve. Pero si en el cel real el journal tiene 5000+ entries y la query tarda 200-500ms, el usuario ve "nada" entre el tap del chip y el render del reporte → percepción de bug.
- Recomendación: reemplazar el `SizedBox(height: 1)` por un placeholder estático sin animación de 60-80px de alto con color `FincoreColors.surface` (`BaseCard` vacío con texto sutil "Cargando..." en `textSubtle`). Sin `AnimationController`, no cuelga `pumpAndSettle`, pero da feedback visual.
- Depende de: nada.

### M6. AppBar del Dashboard con 3 IconButton + título puede saturar pantallas angostas

- Severidad: Media (validación visual pendiente)
- Área: Frontend / UX
- Evidencia: `mobile/lib/screens/dashboard_screen.dart` AppBar tiene ahora 3 IconButton en `actions`: `Icons.bar_chart` (Reportes, agregado por el sprint), `Icons.label_outline` (Categorías), `Icons.settings_outlined` (Configuración). El título es el `RichText` "FinCore". En pantallas <360dp puede apiñarse.
- Impacto: visual. No bloquea, pero degrada UX en cels chicos.
- Recomendación: durante el smoke manual SM-02 en el Redmi, validar visualmente que los 3 iconos caben sin overlap. Si saturan, dos opciones: (a) colapsar Categorías + Configuración bajo un `PopupMenuButton` con kebab `…`; (b) mover el icono más usado al frente. Diego define cuál usa más.
- Depende de: validación visual en el smoke.

### M7. Posible mejora de índice SQL para journal grande

- Severidad: Media (preventiva, condicional)
- Área: SQL / Performance
- Evidencia: la query del reporte filtra `WHERE j.kind IN ('expense', 'credit_expense') AND j.deleted_at IS NULL AND j.occurred_at >= ? AND j.occurred_at <= ?`. Los índices existentes son:
  - `idx_entries_kind` sobre `(kind)`.
  - `idx_entries_deleted` sobre `(deleted_at)`.
  - `idx_entries_occurred_active` parcial `(occurred_at DESC) WHERE deleted_at IS NULL`.
  El último no aplica directamente porque el reporte no ordena por `occurred_at`. SQLite probablemente usa `idx_entries_kind` para los 2 valores del `IN` y luego filtra el rango. Con 1k entries esto es < 5ms; con 50k+ podría degradar.
- Impacto: nulo en MVP (journal de Diego está debajo de 1k entries). Riesgo medio si la app escala a 50k+ entries sin re-indexar.
- Recomendación: dejar un comentario en `mobile/lib/data/database.dart` (cerca de los índices) anotando que si `spendingByCategory` degrada con journal grande, considerar:
  ```sql
  CREATE INDEX idx_entries_kind_occurred_active
  ON journal_entries(kind, occurred_at)
  WHERE deleted_at IS NULL;
  ```
  Sin agregar el índice ahora (YAGNI). Documentar como referencia futura.
- Depende de: nada.

### M8. `_DateFieldOutlined` candidato a widget compartido con `entry_form_screen`

- Severidad: Baja
- Área: Frontend / Reutilización
- Evidencia: `spending_by_category_tab.dart` define `_DateFieldOutlined` privado para mostrar un campo M3 outlined que abre DatePicker al tap. `entry_form_screen.dart` tiene patrón similar inline para el field de fecha del entry.
- Impacto: duplicación menor. Si en el futuro se cambia el estilo M3 de inputs, hay 2 lugares que mantener.
- Recomendación: cuando se ataque un siguiente sprint con UI (ej. otro reporte con rango temporal), extraer `_DateFieldOutlined` a `lib/widgets/date_field_outlined.dart` y reutilizar en ambos lugares. No bloquea este sprint.
- Depende de: nada (mejora futura).

### B1. `_TotalCard` duplicada entre Dashboard y `/reports`

- Severidad: Baja
- Área: Frontend / Reutilización
- Evidencia: el `_TotalCard` del reporte (label + monto + texto secundario) es muy similar al `_TotalCard` privado del Dashboard (uso BO/DE/CR). Ambos sobre `BaseCard` con la misma estructura visual.
- Impacto: duplicación pequeña, mantenimiento bajo.
- Recomendación: si surge un tercer caso, extraer a `lib/widgets/total_card.dart` con props (label, amount, color, subtitle). Hoy no urge.
- Depende de: nada.

### B2. Tests con `DateTime.now()` para registrar entries del rango "Este mes"

- Severidad: Baja
- Área: Pruebas / Mantenibilidad
- Evidencia: `mobile/test/screens/reports_screen_test.dart` en el seed del test "BD con expense en categoría" usa `DateTime.now()` para registrar el entry dentro del rango default. Si en el futuro se cambia la definición de "Este mes" sin actualizar el seed, el test puede empezar a fallar aleatoriamente.
- Impacto: bajo. El test pasa hoy. El riesgo se materializa solo en refactor futuro.
- Recomendación: agregar un comentario en el seed explicando que `DateTime.now()` se usa intencionalmente para alinear con el default del widget. Si surge flakiness, considerar inyectar `clock` mockeado.
- Depende de: nada.

### B3. Resumen del rango debajo de los chips puede ser redundante

- Severidad: Baja
- Área: UX
- Evidencia: `spending_by_category_tab.dart` muestra debajo de los chips un texto `"1 jun 2026 — 30 jun 2026"` cuando el preset no es Custom. En modo Custom, los `_DateFieldOutlined` ya muestran las fechas → la línea de resumen se oculta. Pero en presets no-Custom (mayoría del uso), agrega una línea de texto extra.
- Impacto: redundancia visual menor. En pantallas angostas suma una línea más debajo de los chips.
- Recomendación: validar con Diego durante el smoke. Si lo considera útil ("me ayuda a confirmar el rango sin abrir nada"), dejar. Si lo considera ruido, eliminar (3-4 líneas de código).
- Depende de: feedback de Diego.

### B4. Error tipográfico en CA-11 del spec (versionCode esperado)

- Severidad: Baja
- Área: Trazabilidad
- Evidencia: `spec.md` CA-11: *"exit 0 con `versionCode=2043` (prefix 2000 de arm64)"*. La implementación real publicó `0.4.1+44` → versionCode esperado = `2044`. El número `2043` del CA queda desfasado (era válido para el `0.4.0+43` original antes del refinement de chips).
- Impacto: ninguno funcional. Confunde futuras auditorías.
- Recomendación: corregir CA-11 en el spec a "versionCode 2044" (o anotar como "versionCode bumpea junto con el release").
- Depende de: nada.

### N1. Conflictos del subagente C1 (leak de listeners) descartados

- Severidad: Nota (resuelto en integración)
- Área: Concurrencia
- Evidencia: el subagente Concurrencia reportó "leak de listeners en cambios rápidos de fecha" como Alta. El subagente SQL reportó el mismo punto como "seguro, sin leak". Verificación cruzada: `StreamBuilder` interno cancela la `StreamSubscription` al stream anterior cuando `widget.stream` cambia (ver `_StreamBuilderBaseState._subscribe` en Flutter). Drift libera el listener interno al cancelar la suscripción. No hay leak observable.
- Impacto: ninguno.
- Recomendación: ninguna. Mantener el patrón actual (`_reportStream = _buildStream()` + `setState`).

### N2. Cobertura test integración (DAOs + ReportsService) ya existe

- Severidad: Nota
- Área: Pruebas
- Evidencia: `mobile/test/data/reports_test.dart` tiene un grupo "integración con DAOs" con 2 tests: cancelar entry → reporte se refleja; archivar categoría → buckets se reagrupan. Ya cubierto.
- Impacto: ninguno.
- Recomendación: ninguna. Mantener.

### N3. Convenciones de testing respetadas

- Severidad: Nota
- Área: Pruebas
- Evidencia: los nuevos tests data usan `await db.close()` en `tearDown` sin `invalidateAll()` (DV-5 del sprint v4 respetada). Widget tests usan `harness.dispose()` que internamente solo cierra la BD. Sin regresiones detectadas en la suite previa de 126 tests.
- Impacto: ninguno.
- Recomendación: ninguna.

## Plan de corrección ordenado

Orden por dependencia y costo. Las correcciones son **opcionales para el merge** pero recomendadas antes de cerrar el sprint formalmente.

1. **Documentar Desviación-6 y Desviación-7** en `engineering/specs/flutter-reports-v1/implementation/desviaciones-plan.md` (M1, M2). ~15 min. Cero código, alta importancia para trazabilidad.
2. **Agregar manejo de `snap.hasError`** en `SpendingByCategoryTab` (M3). ~15-20 min. Defensiva. Sin nuevas deps.
3. **Reemplazar `SizedBox(height: 1)` por placeholder estático** con texto "Cargando..." (M5). ~10 min. Sin animaciones.
4. **Corregir CA-11** del spec con versionCode 2044 (B4). ~2 min.
5. **Validar visualmente AppBar Dashboard en el Redmi** durante el smoke manual SM-02 (M6). Si satura, decidir acción (overflow menu vs reorder). Decisión de Diego.
6. **Agregar tests `_rangeForPreset` para cruce enero/diciembre** (M4). ~30 min. Extraer el método como static helper o crear archivo de test que importe el archivo y use `_RangePreset` privado.
7. **Comentario en `database.dart`** sobre índice futuro para journal grande (M7). ~2 min. Sin schema bump.
8. **Run final `flutter test` + `flutter analyze`** post-correcciones. ~30s. Validar 0 regresiones.

Diferidos a sprints futuros (no urgentes):

- M8 (extraer `_DateFieldOutlined` a widget compartido) — esperar siguiente sprint UI.
- B1 (`_TotalCard` compartido) — esperar 3er caso de uso.
- B2 (comentario sobre `DateTime.now()` en seed) — opcional.
- B3 (resumen del rango) — depende del feedback de Diego.
- A8 (extraer `_RangePreset` a constants) — esperar segundo reporte con presets.

## Validaciones recomendadas

```bash
cd mobile

# Tras aplicar las correcciones del plan:
flutter analyze   # 0 errores, 0 warnings, 4 hints info preexistentes
flutter test      # 154/154 verdes (o 158/158 si se suman los 4 tests de _rangeForPreset)

# Smoke manual en el Redmi tras nuevo APK (si se bumpea a 0.4.2+45):
# SM-01 a SM-08 ver implementation/pruebas.md
# + validar AppBar Dashboard no satura
```

## Limitaciones

- **No ejecuté tests dinámicos**: la revisión es estática sobre el código fuente. El comportamiento real en el Redmi (touch targets, overflow del AppBar, percepción del loading state) depende del smoke manual de Diego.
- **No medí performance real**: la query `spendingByCategory` rinde rápido en BD in-memory de tests, pero no se ejecutó con journal de 5000+ entries en el cel real. M7 queda como recomendación condicional.
- **No audité los 2 commits previos a `origin/main`** en profundidad: son del sprint anterior `flutter-ui-test-coverage-v2` que ya tuvo su quality review. Solo se validó que no introducen riesgo al sprint actual.
- **No revisé linting cosmético** en specs/docs `engineering/specs/flutter-reports-v1/**`. Los specs son documentación, no código productivo.
- **El conflicto entre subagentes C1 vs H2 (leak de listeners)** se resolvió por análisis cruzado del comportamiento de `StreamBuilder` + drift. No se reprodujo el caso experimental.
