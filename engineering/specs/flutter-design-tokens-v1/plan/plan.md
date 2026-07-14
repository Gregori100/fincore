# Plan técnico — flutter-design-tokens-v1

## Enfoque tecnico

Sprint puramente estructural que introduce un sistema de tokens de diseño explícito. Se compone de 4 capas ordenadas:

1. **Capa de tokens** — 4 archivos nuevos (`fincore_typography.dart`, `fincore_spacing.dart`, `fincore_radii.dart`, `fincore_motion.dart`) + extensión a `fincore_colors.dart`. Todo son constantes `const` (`TextStyle`, `double`, `EdgeInsets`, `Duration`, `Curve`). Sin lógica ni funciones — los tokens son datos.
2. **Capa de theme** — `fincore_theme.dart` cablea los 7 tokens tipográficos a los 15 slots del `textTheme` (con `fontSize` explícito por slot) y migra los sub-themes (`cardTheme`, `inputDecorationTheme`, `filledButtonTheme`, `chipTheme`) para consumir los tokens de radio, spacing y tipografía.
3. **Capa de widgets** — los 24 widgets compartidos en `mobile/lib/widgets/*.dart` se migran a consumir tokens. Reglas de migración:
   - `TextStyle(fontSize: N, fontWeight: W)` inline → `Theme.of(context).textTheme.xxx` (default) o import directo de `fincore_typography.dart` cuando el widget es `const`.
   - `SizedBox(height: N)` → `SizedBox(height: kSpaceX)`.
   - `EdgeInsets.all(N)` / `.symmetric(...)` / `.fromLTRB(...)` → tokens semánticos derivados (`kEdgeCard`, `kEdgeListItem`, etc.) o construidos con tokens (`EdgeInsets.symmetric(horizontal: kSpaceLg, vertical: kSpaceMd)`).
   - `BorderRadius.circular(N)` → `BorderRadius.circular(kRadiusX)`.
   - `withValues(alpha: N)` → `withValues(alpha: alphaX)` cuando N cae en la escala semántica; excepciones marcadas con `// token-exception:`.
   - `Duration(milliseconds: N)` en animaciones → `kMotionX`.
   - Valores fuera de la escala se resuelven redondeando (documentado en `decisiones-implementacion.md`).
4. **Capa de documentación** — `CLAUDE.md` extendido con la sección "Sistema de tokens de diseño" que declara las convenciones como reglas vinculantes para sprints futuros.

**Filosofía**: cero cambios visuales percibidos. El sprint no toca lógica de dominio ni comportamiento de UI. Los diffs serán grandes en volumen (24 widgets + theme + docs) pero pequeños en riesgo por línea.

## Requisitos funcionales cubiertos

- **RF-001** (fincore_typography.dart, 7 tokens) → T001.
- **RF-002** (fincore_spacing.dart, 7 tokens + semánticos) → T002.
- **RF-003** (fincore_radii.dart, 5 tokens) → T003.
- **RF-004** (fincore_colors.dart extendido con 4 alphas) → T004.
- **RF-005** (fincore_motion.dart, 5 durations + 4 curves + docstring) → T005.
- **RF-006** (textTheme cableado con fontSize por slot) → T006.
- **RF-007** (subthemes migrados a tokens) → T007.
- **RF-008** (widgets migrados, cero `fontSize`/`SizedBox`/`BorderRadius`/`alpha` inline no-token) → T008-T013.
- **RF-009** (CLAUDE.md con sección "Sistema de tokens de diseño" + reglas y convenciones) → T014.
- **RF-010** (bump version 0.21.0+97) → T015.
- **RF-011** (`flutter analyze` 0 errores + 680 tests verdes) → T016, T017.

## Archivos o modulos probablemente afectados

**Nuevos**:
- `mobile/lib/theme/fincore_typography.dart`
- `mobile/lib/theme/fincore_spacing.dart`
- `mobile/lib/theme/fincore_radii.dart`
- `mobile/lib/theme/fincore_motion.dart`

**Modificados en `mobile/lib/theme/`**:
- `mobile/lib/theme/fincore_colors.dart` (agregar 4 alphas al final)
- `mobile/lib/theme/fincore_theme.dart` (textTheme completo con fontSize + subthemes con tokens)

**Modificados en `mobile/lib/widgets/`** (24 archivos, según `ls`):
- `account_balance_hint.dart`
- `account_picker.dart`
- `account_type_picker.dart`
- `amount_formatter.dart`
- `applies_to_picker.dart`
- `base_card.dart`
- `category_badge.dart`
- `category_picker.dart`
- `color_picker.dart`
- `confirm_dialog.dart`
- `date_field_outlined.dart`
- `destructive_dialog.dart`
- `entries_active_filters_bar.dart`
- `entries_empty_state.dart`
- `entries_paginated_list.dart`
- `entry_account_label.dart`
- `error_snackbar.dart`
- `fincore_logo.dart` (excepción documentada — mantiene `fontSize` proporcional)
- `icon_picker.dart`
- `kind_picker.dart`
- `movement_row.dart`
- `save_view_dialog.dart`
- `skeleton.dart`

**Modificados en raíz**:
- `CLAUDE.md` (sección nueva)
- `mobile/pubspec.yaml` (version)
- `mobile/android/app/build.gradle.kts` (versionCode + versionName)

**No tocados en este sprint** (aunque consumen widgets migrados):
- `mobile/lib/screens/**/*.dart` — quedan para sprints por módulo.
- `mobile/lib/screens/weekly_budgets/widgets/*.dart` — widgets locales del feature, no compartidos, van al Sprint 7.
- `mobile/lib/data/**`, `mobile/lib/router/**`, `mobile/lib/data/**` — sin cambios (sprint puro de theming).

## Entidades y estados afectados

No aplica. Sprint sin cambios de dominio, entidades, estados ni invariantes. Los DAOs, servicios y modelos permanecen intocados.

## Compatibilidad con datos y procesos existentes

- **BD SQLite**: sin cambios. Sin schema bump. La BD existente se abre sin migración.
- **Backup JSON v1**: sin cambios. Round-trip export/import preservado bit a bit.
- **Widgets consumidos por screens**: las screens no se modifican en este sprint, pero consumen widgets migrados. La sensación visual debe ser idéntica salvo por los ajustes explícitos documentados (chip radius 16 → 12, filled button vertical 14 → 12) — validación manual comparativa.
- **APK vs versión previa**: bump minor `0.21.0` incrementa `versionCode = 97`, compatible con `adb install -r` sobre la BD existente sin pérdida de datos.
- **Tests**: no se modifica el cuerpo de ningún test salvo si un `find.byWidgetPredicate` o similar matchea explícitamente `fontSize: N` literal (improbable). Si ocurre, documentar en `decisiones-implementacion.md`.

## Cambios de datos si aplica

No aplica.

## Cambios de API si aplica

No aplica (single-user local, sin API HTTP).

## Cambios de integraciones si aplica

No aplica.

## Cambios de UI si aplica

Sí — cambios sub-perceptibles derivados de la homologación de valores a la escala. Documentados como riesgos R-02, R-03.

- **chipTheme radius**: 16 → 12 (kRadiusLg). Impacto perceptible: chips ligeramente más "cuadrados". Se acepta en el sprint; si Diego lo prefiere en 16, se ajusta en la retro.
- **FilledButton padding vertical**: 14 → 12 (kSpaceMd). Impacto: botón levemente menos alto. Se acepta.
- **FilledButton fontSize**: 15 → tomado del token semántico del texto en botón (probablemente `label = 12` con w600, o `bodyM = 14`). Instrucción de diff: probar en visual y elegir el que preserve mejor el look actual. Documentar la elección.
- **Skeleton pulse duration**: 1100ms exacto → `kMotionPulse = 1100ms`. Sin cambio.
- **Alphas**: `0.10` (AccountTypePicker) → `alphaSelected = 0.20`. Tint más visible. Se acepta.

## Cambios de permisos si aplica

No aplica.

## Riesgos tecnicos

- **RT-01** (heredado del R-01 de la spec): cambiar `textTheme` con `fontSize` explícito puede alterar componentes M3 que hoy heredan defaults. Mitigación: comparación visual pantalla por pantalla + reversión puntual si algo se ve peor.
- **RT-02** (heredado del R-04): `pumpAndSettle` puede colgar si algún test monta widgets con skeleton. Mitigación: si ocurre, cambiar a `pump()` explícito en ese test y documentar el fix pendiente para Sprint 6.
- **RT-03**: la homologación de valores (`14 → 12`, `16 → 12`, `15 → 14`) genera cambios visuales sub-perceptibles que no son testables automáticamente. Mitigación: smoke manual comparando pantallas antes/después. Si Diego valida y aprueba en la retro, quedan como norma.
- **RT-04**: widgets `const` que hoy declaran `TextStyle` const literal no pueden migrarse a `Theme.of(context).textTheme.xxx` sin perder `const`. Mitigación: importar tokens directamente desde `fincore_typography.dart` como `const TextStyle` (por eso el archivo expone tanto los tokens sueltos como el cableado a `textTheme`).
- **RT-05**: alto volumen de diff (24 widgets + theme) aumenta riesgo de merge conflict con work in progress. Mitigación: `git status` limpio antes de arrancar; commits atómicos por lote pequeño (tokens → theme → widgets estructurales → dialogs → pickers → …); si el sprint se pausa, cada commit deja el árbol estable.
- **RT-06**: la regla "cero cambios visuales" es difícil de garantizar sin herramientas de golden test. Aceptado como riesgo con validación manual (RT-03).
- **RT-07**: si un consumidor de theme (widget o screen) hace `Theme.of(context).textTheme.bodyMedium!.copyWith(...)` y el `bodyMedium` cambia de default M3 (14) a nuestro token `bodyM` (que también es 14), no hay problema. Pero si algún consumidor hace `.copyWith(fontSize: 14)` sobreescribiendo, ese sobrescribe se vuelve redundante — no rompe, pero deja código sucio. Post-migración de widgets, hacer un `grep` para detectarlos.
- **RT-08**: `TextStyle` no admite herencia de color de un ancestro por default — cada instancia lleva su color. Al cablear `textTheme` con `color` por slot (`textPrimary`, `textMuted`, `textSubtle` según semántica), los widgets que hoy override el color con `copyWith` lo siguen haciendo bien. Riesgo: si algún widget dependía de que `textTheme.bodyMedium` NO tuviera color (para que el `DefaultTextStyle` de un ancestro lo herede), ese contrato se rompe. Verificar con `grep -r "DefaultTextStyle" mobile/lib/`.

## Estrategia de pruebas

1. **`flutter analyze`** — cero errores permitidos. Cualquier warning nuevo (import no usado, const inference roto) se resuelve antes de cerrar el sprint.
2. **`flutter test`** — los 680 tests existentes pasan sin modificar el cuerpo del test. Si alguno rompe, el problema es la migración; ajustar el widget para preservar el matcher.
3. **Smoke manual desktop (`flutter run -d linux`)** — 5 pantallas críticas: Dashboard, Entries list + form, Reports (al menos 3 tabs), Weekly Budgets list + detail, Settings. Comparar contra screenshots pre-sprint (o memoria reciente); documentar cualquier cambio perceptible.
4. **Smoke manual Android (`flutter build apk --split-per-abi` + `adb install -r`)** — mismas 5 pantallas en dispositivo real. Foco especial en textos que puedan haberse re-medido (posibles ellipsis nuevos, wraps distintos).
5. **`branch-quality-review`** — al terminar la implementación, ejecutar la skill para auditoría exhaustiva de la rama. Su reporte vive en `engineering/quality-review/<slug>/`.

## Estrategia de rollback

- Sprint sin cambios de dominio ni de BD → rollback trivial: revertir los commits del sprint (`git revert` del rango).
- Si el rollback ocurre después de un release con `versionCode = 97`, el siguiente release debe bumpear a `98` (Android no permite downgrade de versionCode). Documentar en release notes.
- No hay side effects fuera del código: no hay migraciones a revertir, no hay archivos generados por build_runner que dependan de los tokens (el `database.g.dart` está intocado).
- Si un widget migrado produce regresión visual concreta post-release, revert selectivo por widget es seguro (los widgets consumen tokens pero también funcionan con literales — no hay contrato interno roto).

## Orden sugerido de implementacion

Optimizado para paralelización cuando posible + minimizar diff size por commit.

**Fase 1: Tokens (T001-T005)** — paralelizables entre sí (archivos independientes).
Un commit único con los 5 archivos nuevos + los 4 alphas en `fincore_colors.dart`. Título tentativo: `feat(mobile): crea tokens fundacionales de tipografía, spacing, radios, alphas y motion`.

**Fase 2: Cablear theme (T006-T007)** — secuencial, depende de Fase 1.
Un commit con `fincore_theme.dart` reescrito: textTheme completo con fontSize + subthemes con tokens. Título: `feat(mobile): cablea textTheme y subthemes de M3 a los tokens de diseño`.

**Fase 3: Migrar widgets compartidos (T008-T013)** — 6 tasks paralelizables (grupos por afinidad). En la práctica, correr secuencialmente (o subagentes paralelos con `worktree` si el volumen justifica) y hacer un commit por grupo. Títulos:
- `refactor(mobile): migra widgets estructurales (base_card, skeleton, badge, logo) a tokens`
- `refactor(mobile): migra dialogs (confirm, destructive, save_view) a tokens`
- `refactor(mobile): migra pickers a tokens`
- `refactor(mobile): migra widgets de amount y date a tokens`
- `refactor(mobile): migra widgets de movement y entries a tokens`
- `refactor(mobile): migra widgets de feedback (snackbar, balance_hint) a tokens`

**Fase 4: Documentación (T014)** — un commit con `CLAUDE.md` + `decisiones-implementacion.md` (todas las excepciones documentadas del sprint).

**Fase 5: Bump de versión (T015)** — un commit con `pubspec.yaml` + `build.gradle.kts`.

**Fase 6: Validación (T016-T020)** — sin commits: correr `flutter analyze`, `flutter test`, smoke manual, `branch-quality-review`. Si falla algo, hotfix como commit fuera de fase.

**Estrategia alternativa (single commit)**: si Diego prefiere un solo commit para el sprint (como se hizo en flutter-weekly-budgets-v1), se acumula todo y se commitea al final con un mensaje largo. Elegir al cierre del sprint.

## Casos borde que condicionan la solucion

Casos que la spec ya documenta (borde 1-15) + casos adicionales detectados durante el planeamiento:

- **Widgets consumidos por screens migradas simultáneamente**: como este sprint NO toca screens, no hay conflicto. Si un sprint futuro migra dashboard mientras hay work in progress en este sprint, resolver con merge normal.
- **Widget `fincore_logo.dart` en splash + first-run + dashboard**: si el splash usa `FincoreLogo(fontSize: 72)`, la lógica proporcional interna se preserva. Sin cambios.
- **`error_snackbar.dart` fondo saturado**: la spec (borde 15) confirma que `withValues(alpha: 0.15)` → `alphaTint`. El fondo del snackbar es `FincoreColors.positive/negative/warning` full-saturation, NO tiene alpha — permanece igual. La P3-3 del Sistémico (rediseñar snackbar con surfaceElevated + borde) queda fuera de este sprint.
- **`AmountFormatter`**: probablemente no usa `fontSize` (es un formatter puro devolviendo `String`). Verificar; si es puro string, no requiere migración.
- **`date_field_outlined.dart`**: usa `InputDecorator`; podría requerir override de radius que debe coincidir con `kRadiusMd` (input theme).
- **`DestructiveDialog`**: hero icon en círculo de 28dp. Marcarlo como `// token-exception:` si el radio del círculo o el padding interno usan valores fuera de la escala. Preferencia: homologar a `kSpace2xl=32` si visualmente es aceptable.
- **`skeleton.dart` cornerRadius por defecto 4 + overrides `8` en avatar y `10` en SkeletonCard**: 4 no está en la escala (mínimo `kRadiusSm=6`). Homologar a `kRadiusSm=6` (leve aumento) y `kRadiusMd=8` (idem). Documentar en el diff.
- **Widget que consume `Theme.of(context)` pero es `const`**: el widget entero no puede ser `const` si lee del context. Si un widget hoy es `const StatelessWidget` y necesita migrarse a `textTheme` via context, perder el `const` es aceptable (impacto de perf negligible). Alternativa: importar el token como `const TextStyle` directamente. Preferencia: usar el token importado cuando el widget es hot path (listas grandes: `MovementRow`, `entries_paginated_list`).
- **`applies_to_picker.dart`**: el borde 4 de la spec (flechas invertidas) NO se corrige en este sprint (fuera de alcance iconografía). Solo se migran valores estilísticos.
- **Tests que usan `pumpAndSettle`**: si el test monta `Skeleton` y espera `pumpAndSettle`, la animación de 1100ms hace que cuelgue. Mitigación: buscar con `grep -r "Skeleton" mobile/test/` y verificar. Si ocurre, `pump(Duration(seconds: 2))` en lugar de `pumpAndSettle`.

## Preguntas o supuestos que siguen afectando la implementacion

Ninguna pregunta bloqueante (verificado en `checklist.md`). Supuestos activos:

- El bump a `0.21.0+97` (minor) es apropiado. Si Diego prefiere `0.20.3+97` (patch), se ajusta al cierre; no bloquea el sprint.
- Los widgets locales de `mobile/lib/screens/weekly_budgets/widgets/` NO entran en este sprint.
- Las excepciones a la escala se marcan con `// token-exception:` y se listan en `implementation/decisiones-implementacion.md`. Meta: ≤ 5 excepciones totales.
- La regla "cero cambios visuales" tolera diferencias sub-pixel (chip radius 16 → 12, padding 14 → 12).
- `branch-quality-review` está disponible y se ejecuta al cierre de la implementación.
- El smoke manual Android lo ejecuta Diego (por regla de release workflow — Claude arma el build, Diego corre el `adb install`).
