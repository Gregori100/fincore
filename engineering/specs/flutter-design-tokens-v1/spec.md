# Sistema de tokens de diseño (Sprint Foundations)

## Resumen

Primer sprint del roadmap de la auditoría de diseño 2026-07-14. Extrae 5 archivos de tokens fundacionales (tipografía, spacing, radios, alphas, motion) que hoy viven hardcoded/repetidos en widgets y screens, los cablea al `ThemeData` de la app, y migra los widgets compartidos (`mobile/lib/widgets/*.dart`) como piloto. Las screens quedan para sprints por módulo. Sprint puramente estructural: cero cambios visuales percibidos.

Bump esperado: 0.20.2+96 → 0.21.0+97 (minor por refactor sistémico).

## Problema a resolver

- `textTheme` está definido en `fincore_theme.dart:146-162` pero **sin `fontSize` por slot**, por eso ningún widget lo consume: aunque un dev hiciera `Theme.of(context).textTheme.bodyMedium`, obtendría el default M3 (14) que no matchea los tamaños reales de la app. Como resultado, 226 usos inline de `TextStyle(fontSize: N)` en el código con **14 valores únicos** (10, 11, 12, 13, 14, 15, 16, 18, 20, 22, 26, 56, 72). En `mobile/lib/widgets/` solamente: 6 usos de 12, 3 de 15, 3 de 11, 2 de 13, 1 cada uno de 14/18/20.
- **Spacing** sin tokens: en widgets compartidos aparecen `SizedBox(height: N)` con al menos 8 valores únicos (2, 4, 6, 8, 10, 12, 16, 20, 24) y `EdgeInsets` con 16+ variantes. El literal `EdgeInsets.fromLTRB(16, 16, 16, 96)` (FAB clearance) está copiado en 16 archivos sin explicación.
- **Radios** sin tokens: `borderRadius: BorderRadius.circular(N)` con 9 valores únicos (2, 3, 4, 6, 8, 10, 12, 16, 20). En el propio `fincore_theme.dart` conviven `circular(8)` para inputs/botones, `circular(12)` para cards y `circular(16)` para chips.
- **Alphas** sin tokens: al menos 5 variaciones del concepto "estado seleccionado" (`0.10`, `0.12`, `0.15`, `0.18`, `0.20`) usadas indistintamente. `withValues(alpha: 0.15)` para tint de badge, `alpha: 0.20` para picker seleccionado — sin criterio documentado.
- **Motion** sin tokens: solo `skeleton.dart` y `onboarding_screen.dart` usan `Curves`; el resto hereda defaults de `go_router` y de Material. `Duration(milliseconds: 1100)` en el skeleton es literal. Cuando un sprint futuro agregue animaciones, cada uno definirá su propia curva sin filosofía compartida.
- Consecuencia sistémica: la app "cambia de personalidad" entre pantallas aunque técnicamente use la misma paleta. La auditoría global identifica esto como **S1, S2 (tokens) + P1-1, P1-2 (Sistémico)** — hallazgo transversal en varios reportes.

## Objetivo

Establecer la base de un sistema de diseño explícito y ejercitable:

1. 5 archivos de tokens en `mobile/lib/theme/` (tipografía, spacing, radios, motion) + extensión de `fincore_colors.dart` con 4 alphas semánticos.
2. `textTheme` de `fincore_theme.dart` cableado con `fontSize` explícito por slot, mapeando los 7 tokens tipográficos a los slots de M3.
3. Widgets compartidos (`mobile/lib/widgets/*.dart`) migrados a consumir tokens como piloto vivo de la nueva convención.
4. Documentación en `CLAUDE.md` con reglas vinculantes que las siguientes iteraciones (screens y sprints por módulo) deben seguir sin excepción.

Al terminar el sprint, cualquier dev que quiera agregar un nuevo widget o pantalla tiene una base explícita: `Theme.of(context).textTheme.bodyMedium`, `kSpaceLg`, `kRadiusMd`, `alphaTint`, `kMotionMedium` + `kCurveEmphasized`.

## Alcance

### Archivos nuevos

1. **`mobile/lib/theme/fincore_typography.dart`** — 7 tokens semánticos como `TextStyle` const (con color = `textPrimary` por default; permitir override desde el consumidor con `copyWith`).
2. **`mobile/lib/theme/fincore_spacing.dart`** — 7 constantes `double` + 4 semánticos derivados (`EdgeInsets` constantes) + un helper documentado para el bottom-padding con FAB.
3. **`mobile/lib/theme/fincore_radii.dart`** — 5 constantes `double` (usar como `BorderRadius.circular(kRadiusLg)` en el consumidor).
4. **`mobile/lib/theme/fincore_motion.dart`** — 5 `Duration` const + 4 `Curve` const + docstring de filosofía.

### Archivos modificados

5. **`mobile/lib/theme/fincore_colors.dart`** — 4 constantes `double` nuevas (`alphaHover`, `alphaHairline`, `alphaTint`, `alphaSelected`) al final de la clase, con comentarios de uso.
6. **`mobile/lib/theme/fincore_theme.dart`** — cablear el `textTheme` con los 7 tokens tipográficos (con `fontSize` explícito por slot); migrar los literales del theme (`borderRadius`, `EdgeInsets`, `fontSize`) a los tokens correspondientes.
7. **`mobile/lib/widgets/*.dart`** — todos los widgets del directorio, migrados a consumir tokens.
8. **`CLAUDE.md`** — sección nueva "Sistema de tokens de diseño" con las reglas y convenciones.
9. **`mobile/pubspec.yaml`** — bump version a `0.21.0+97`.
10. **`mobile/android/app/build.gradle.kts`** — `versionCode = 97`, `versionName = "0.21.0"`.

### Mapping de slots del textTheme a los tokens

- `displayLarge / displayMedium / displaySmall` → `displayXL` (56pt, w800, letterSpacing -1.5).
- `headlineLarge / headlineMedium / headlineSmall` → `headingL` (20pt, w700, letterSpacing -0.3).
- `titleLarge / titleMedium` → `headingM` (16pt, w600, letterSpacing 0).
- `titleSmall` → `bodyS` (13pt, w500, letterSpacing 0).
- `bodyLarge / bodyMedium` → `bodyM` (14pt, w400, letterSpacing 0).
- `bodySmall` → `label` (12pt, w600, letterSpacing 0.1) — con `color: textMuted` para preservar el semántico actual.
- `labelLarge` → `label` (12pt, w600, letterSpacing 0.1).
- `labelMedium` → `label` (12pt, w600, letterSpacing 0.1) — con `color: textMuted`.
- `labelSmall` → `overline` (11pt, w600, letterSpacing 1.2) — con `color: textSubtle`.

## Fuera de alcance

Los siguientes puntos aparecen en la auditoría pero **NO** entran en este sprint. Van a sprints posteriores del roadmap.

- Migración de `mobile/lib/screens/**/*.dart` a los tokens — solo widgets compartidos en este sprint. Cada sprint por módulo (Entry form, Dashboard, Reports, etc.) migra sus screens.
- Refactor de `BaseCard` a variantes semánticas (`InfoCard`, `ActionCard`, `AlertCard`) — Sprint 6.
- Extracción de `SelectableCard` compartido para pickers (`KindPicker`, `AccountTypePicker`) — Sprint 6.
- Componentes compartidos `EmptyState`, `ErrorState`, `LoadingState` — Sprint 6.
- Purga global de voseo rioplatense (`pagás`, `configurá`, `probá`, …) — Sprint 2.
- Desaturación de la paleta `categoryX` para separar de `positive/negative` — Sprint 6.
- Migración masiva de iconografía (outlined vs filled cleanup) — solo se documenta la convención, la migración de sitios específicos queda para sprints por módulo.
- Rediseño del amount input como hero, quick-chips de fecha, hub de reportes, etc. — Sprints 3+.
- Creación de `AppIcons` helper con los 20 iconos canónicos — considerado en Sprint 6.

## Reglas de negocio

Este sprint no toca dominio. Reglas del sistema de tokens:

- Los 7 tokens tipográficos, 7 de spacing, 5 de radio, 4 de alpha y 5+4 de motion son **la única fuente autorizada** en toda la app a partir de este sprint. Un valor fuera de estas escalas requiere justificación documentada en el diff (comentario en la línea).
- El `FincoreLogo` (`mobile/lib/widgets/fincore_logo.dart`) es la excepción documentada: puede usar `fontSize` proporcional (56/72) y proporciones internas propias, porque su tamaño es paramétrico.
- Los estilos únicos de un widget muy singular (por ejemplo el hero grande de un dialog destructivo) pueden usar valores propios si el uso es único; deben marcarse con un comentario `// token-exception:` explicando por qué.
- Cuando un `fontSize` actual (ej. 15) no cae en la escala nueva (14 o 16), redondear al más cercano según el semántico: si es label/CTA de botón → 14 (bodyM) o 12 (label) con weight superior; si es título → 16 (headingM). Documentar la elección con un comentario breve en el diff.
- Cuando un `SizedBox(height: N)` no cae exacto (ej. 20 no es token), redondear al más cercano (16 = `kSpaceLg` o 24 = `kSpaceXl`). Documentar cuando la elección no es obvia.
- La regla anterior aplica a `EdgeInsets` con valores no canónicos: buscar la combinación de tokens que represente la intención.
- Prohibido crear tokens nuevos "ad-hoc" durante la migración de widgets. Si un tamaño no cabe y ninguno de los existentes representa bien el caso, dejarlo con `// token-exception:` y llevarlo al retro al cierre del sprint.
- Los tokens son constantes `const` `double` / `Duration` / `Curve` / `EdgeInsets` según corresponda. No usar getters ni funciones.
- Los alphas se aplican con `Color.withValues(alpha: alphaX)` (API nueva, no `withOpacity`).

## Requisitos funcionales

- **RF-001**: `fincore_typography.dart` expone 7 `TextStyle` const (`displayXL`, `headingL`, `headingM`, `bodyM`, `bodyS`, `label`, `overline`) con `fontSize`, `fontWeight`, `letterSpacing` y `color` (default `FincoreColors.textPrimary`).
- **RF-002**: `fincore_spacing.dart` expone 7 `double` const (`kSpace2xs=2`, `kSpaceXs=4`, `kSpaceSm=8`, `kSpaceMd=12`, `kSpaceLg=16`, `kSpaceXl=24`, `kSpace2xl=32`) + 4 `EdgeInsets` const derivados: `kEdgeCard` (`all(kSpaceLg)`), `kEdgeListItem` (`symmetric(horizontal: kSpaceLg, vertical: kSpaceMd)`), `kEdgeDialog` (`fromLTRB(kSpaceXl, kSpace2xl, kSpaceXl, kSpaceXl)`), `kEdgeScreen` (`fromLTRB(kSpaceLg, kSpaceMd, kSpaceLg, kSpace2xl)` sin clearance de FAB) + helper documentado `kEdgeScreenWithFab` (`fromLTRB(kSpaceLg, kSpaceMd, kSpaceLg, kSpace2xl * 3)`, el clearance de 96 documentado como `kFabClearance = kSpace2xl * 3`).
- **RF-003**: `fincore_radii.dart` expone 5 `double` const (`kRadiusSm=6`, `kRadiusMd=8`, `kRadiusLg=12`, `kRadiusXl=20`, `kRadiusPill=999`).
- **RF-004**: `fincore_colors.dart` extendido con 4 `double` const (`alphaHover=0.08`, `alphaHairline=0.12`, `alphaTint=0.15`, `alphaSelected=0.20`), con comentarios de uso: `alphaHover` para overlay sobre surface; `alphaHairline` para bordes tinted; `alphaTint` para fills tinted (badge, kind tile); `alphaSelected` para estado seleccionado (chip active, picker tile).
- **RF-005**: `fincore_motion.dart` expone 5 `Duration` const (`kMotionInstant=100ms`, `kMotionFast=200ms`, `kMotionMedium=300ms`, `kMotionSlow=500ms`, `kMotionPulse=1100ms`) + 4 `Curve` const (`kCurveStandard=Curves.easeOutCubic`, `kCurveExit=Curves.easeIn`, `kCurveEmphasized=Cubic(0.2, 0, 0, 1)`, `kCurveLinear=Curves.linear`) + docstring al inicio con filosofía de motion.
- **RF-006**: `fincore_theme.dart` `textTheme` cableado con `fontSize`, `fontWeight`, `letterSpacing` y `color` explícitos por slot, siguiendo el mapping definido en Alcance.
- **RF-007**: `fincore_theme.dart` `cardTheme`, `inputDecorationTheme`, `filledButtonTheme`, `chipTheme` migrados a consumir tokens: `borderRadius: BorderRadius.circular(kRadiusMd)` para inputs/botones, `circular(kRadiusLg)` para cards, `circular(kRadiusLg)` para chips (era 16 → redondear a 12). `padding` de `FilledButton` usa `EdgeInsets.symmetric(horizontal: kSpaceXl, vertical: kSpaceMd)` (era `horizontal: 24, vertical: 14`; 14 no es token, se redondea a `kSpaceMd=12`). Justificación documentada en el diff.
- **RF-008**: Todos los widgets en `mobile/lib/widgets/*.dart` migrados a consumir tokens: cero `fontSize: N` inline nuevos, cero `SizedBox(height: N)` con N literal fuera de la escala, cero `borderRadius: BorderRadius.circular(N)` con N literal fuera de la escala, cero `withValues(alpha: N)` con N literal fuera de la escala de alphas semánticos (excepto usos legítimos de gradientes o rampa fina, marcados con `// token-exception:`).
- **RF-009**: `CLAUDE.md` extendido con sección nueva "Sistema de tokens de diseño" que incluye: (a) los 5 archivos y su rol; (b) las reglas prohibidas (inline `fontSize`, `SizedBox` con literal, `borderRadius.circular(N)` con literal); (c) las excepciones documentadas (`FincoreLogo`, `token-exception:`); (d) convención de iconografía (outlined default, filled solo para current/selected); (e) convención de dialogs (`ConfirmDialog` = reversible/bajo impacto, `DestructiveDialog` = irreversible/alto impacto); (f) reserva de colores semánticos (`positive/negative` = dinero, `accent` = affordance/acción, `warning` = alertas operativas, `categoryX` = taxonomía, y **liberar `warning` del tipo credit** — hoy `dashboard_screen.dart:_typeColor` mapea `credit → warning`, la regla obliga a migrar a `textMuted` o color propio en el sprint que toque Dashboard).
- **RF-010**: `pubspec.yaml` bumpea a `0.21.0+97` y `android/app/build.gradle.kts` bumpea `versionCode = 97` + `versionName = "0.21.0"`.
- **RF-011**: `flutter analyze` queda en 0 errores. Los 680 tests existentes (`flutter test`) siguen pasando sin modificación del cuerpo del test (solo se permiten ajustes puntuales si un `find.byWidgetPredicate` matcheaba explícitamente un `fontSize: N` que ahora vive en el token — no debería ser el caso, es un smell si lo es).

## Casos principales

**Caso 1: dev agrega un botón nuevo en una pantalla.**
Consume `Theme.of(context).textTheme.labelLarge` para el texto (que ya viene con `label = 12/w600`), `kSpaceLg` para el padding horizontal, `BorderRadius.circular(kRadiusMd)` para las esquinas. Sin abrir ningún archivo de tokens.

**Caso 2: dev necesita un chip con estado seleccionado.**
Consume `FincoreColors.accent.withValues(alpha: alphaSelected)` para el fill, y `Theme.of(context).textTheme.bodySmall` (que mapea a `label` con color muted).

**Caso 3: dev agrega una animación de entrada a un widget.**
Consume `AnimatedContainer(duration: kMotionFast, curve: kCurveEmphasized, ...)`. Filosofía documentada en el docstring del archivo lo guía a no usar spring bouncy en formularios.

**Caso 4: refactor de `error_snackbar.dart` (widget compartido).**
Migra `fontSize: 13` → `Theme.of(context).textTheme.bodySmall` (que resuelve a 13 con `label`). Migra `SizedBox(height: 8)` → `SizedBox(height: kSpaceSm)`. Migra el margin del snackbar de literales `EdgeInsets.fromLTRB(16, 0, 16, 12)` → `EdgeInsets.fromLTRB(kSpaceLg, 0, kSpaceLg, kSpaceMd)`.

**Caso 5: refactor de `destructive_dialog.dart`.**
El hero icon de 28dp es un caso donde el `SizedBox` no cae en la escala. Redondear a `kSpace2xl = 32` (más cercano) o marcar como `// token-exception:` si el diseño lo pide en 28 exactamente. Documentar la elección en el diff.

## Casos borde

**Borde 1: fontSize sin match exacto en la escala.**
Ejemplo: `error_snackbar.dart` tiene `fontSize: 15` en el texto del botón "Cerrar" (o similar). Escala nueva: 14 (bodyM) o 16 (headingM). Regla: redondear a 14 (label del botón encaja mejor semánticamente en bodyM que en headingM). Documentar con comentario `// era fontSize: 15 → bodyM (14)`.

**Borde 2: SizedBox(height: 20) sin match exacto.**
Escala nueva: `kSpaceLg=16` o `kSpaceXl=24`. Regla: redondear al más cercano (`kSpaceXl=24` si el intent era "generoso"; `kSpaceLg=16` si el intent era "estándar"). Depende del contexto; documentar.

**Borde 3: borderRadius: BorderRadius.circular(16) del chipTheme.**
Escala nueva: 12 (kRadiusLg) o 20 (kRadiusXl, dialogs/sheets). Regla: `kRadiusLg=12` (el radio actual es "chip mediano", no "dialog"). Documentar la homologación en el diff.

**Borde 4: padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14) del FilledButton.**
Vertical 14 no es token. Redondear a `kSpaceMd=12` (baja levemente el alto del botón) o dejar como `token-exception:` si el sprint 3 (entry form redesign) va a cambiar los botones igual. Regla: `kSpaceMd=12` — el sprint prioriza consistencia sobre preservación exacta.

**Borde 5: `Duration(milliseconds: 1100)` del skeleton.**
Match exacto con `kMotionPulse = 1100ms`. Reemplazo directo.

**Borde 6: `withValues(alpha: 0.10)` en `AccountTypePicker` para tint de card seleccionado.**
Alphas semánticos: `alphaHover=0.08`, `alphaTint=0.15`, `alphaSelected=0.20`. Regla: `alphaSelected=0.20` (subir levemente refuerza el estado; los usuarios ganan un tint más visible sin que el diseño se distorsione).

**Borde 7: `withValues(alpha: 0.18)` del `chipTheme.selectedColor` en `fincore_theme.dart`.**
Match cercano a `alphaSelected=0.20`. Reemplazo homologando a `alphaSelected`. Documentar.

**Borde 8: `withValues(alpha: 0.12)` del hero del `DestructiveDialog`.**
Match exacto con `alphaHairline=0.12`. Reemplazo directo.

**Borde 9: `withValues(alpha: 0.4)` del border del `CategoryBadge` (border tinted más fuerte que hairline).**
No cae en la escala. Marcar como `// token-exception: border tinted fuerte, uso puntual` y llevarlo al retro. Es un caso legítimo de "queremos más contraste en el borde de este badge específico"; no vale la pena crear un token nuevo para 1-2 usos.

**Borde 10: `Skeleton` con `SkeletonCard` que crea 3 `AnimationController` (uno por Skeleton).**
Fuera del alcance de este sprint refactorizar la arquitectura de skeleton (el hallazgo P2-4 del Sistémico va a Sprint 6). Solo migrar el `Duration(milliseconds: 1100)` a `kMotionPulse` y el color/border a los alphas correspondientes.

**Borde 11: widgets que consumen el theme pero también hacen overrides con `TextStyle().copyWith(...)`.**
Válido siempre que la base sea el token. Por ejemplo `Theme.of(context).textTheme.bodyMedium?.copyWith(color: FincoreColors.negative)` para un amount rojo. No se rompe la regla.

**Borde 12: tests que usan `pumpAndSettle()`.**
La `kMotionPulse` de 1100ms puede hacer que `pumpAndSettle` cuelgue si el skeleton está montado en el screen bajo test. Precedente: comentario en `CLAUDE.md` sobre `state.invalidateAll()` en tearDown documenta un problema similar. Regla del sprint: si algún test cuelga, envolver el `AnimationController` del skeleton con un check `if (WidgetsBinding.instance.debugSemanticsDisableAnimations != true)` — pero no atacar el problema en este sprint, dejarlo pendiente para Sprint 6 (refactor de Skeleton). Si ocurre, documentar en `pendientes.md`.

**Borde 13: `FincoreLogo` con `fontSize` proporcional (56/72).**
Excepción explícita documentada. No migrar.

**Borde 14: widget que usa `Icons.check_circle` (filled) para "seleccionado" en `KindPicker`.**
Fuera de alcance el cambio de iconografía (la migración de sitios específicos va por sprint de módulo). Solo se documenta la convención en `CLAUDE.md`.

**Borde 15: `withValues(alpha: 0.15)` que aparece como fill para semánticos (positive/negative/warning tinted).**
Match con `alphaTint=0.15`. Reemplazo directo. Confirma que la escala es correcta.

## Criterios de aceptacion

- Los 5 archivos nuevos existen en `mobile/lib/theme/` con las constantes declaradas en RF-001..RF-005.
- `fincore_colors.dart` tiene las 4 constantes `alphaX` al final de la clase con sus comentarios.
- `fincore_theme.dart` `textTheme` tiene `fontSize`, `fontWeight`, `letterSpacing` y `color` explícitos por cada uno de los 15 slots (displayLarge..labelSmall) mapeados a los 7 tokens tipográficos.
- `fincore_theme.dart` los subthemes (`cardTheme`, `inputDecorationTheme`, `filledButtonTheme`, `chipTheme`) consumen tokens de radio/spacing/tipografía.
- Ningún archivo en `mobile/lib/widgets/*.dart` contiene `TextStyle(fontSize: N)` inline (salvo `fincore_logo.dart` marcado como excepción).
- Ningún archivo en `mobile/lib/widgets/*.dart` contiene `SizedBox(height: N)` o `SizedBox(width: N)` con N literal fuera de la escala de spacing (salvo casos marcados con `// token-exception:`).
- Ningún archivo en `mobile/lib/widgets/*.dart` contiene `BorderRadius.circular(N)` con N literal fuera de la escala de radios.
- Ningún archivo en `mobile/lib/widgets/*.dart` contiene `withValues(alpha: N)` con N literal fuera de la escala de alphas (salvo excepciones marcadas).
- `CLAUDE.md` contiene la sección "Sistema de tokens de diseño" con las reglas y convenciones.
- `pubspec.yaml` versionado a `0.21.0+97`.
- `android/app/build.gradle.kts` versionado con `versionCode = 97` y `versionName = "0.21.0"`.
- `flutter analyze` reporta 0 errores.
- `flutter test` pasa los 680 tests sin modificar el cuerpo de ningún test (a menos que un test estuviera matcheando explícitamente un `fontSize` literal, en cuyo caso se ajusta el test para matchear el token — esta modificación debe documentarse en `decisiones-implementacion.md`).
- La app compila y corre en Linux y Android sin cambios visuales percibidos (validación manual con `flutter run`).

## Criterios medibles de exito

- **Reducción de `fontSize` únicos en `mobile/lib/widgets/`**: de 8 valores actuales (según `grep`) a 0 valores inline no-token (excepto `FincoreLogo`).
- **Reducción de `SizedBox` únicos en `mobile/lib/widgets/`**: de 10 valores actuales a valores exclusivamente de la escala de 7 tokens.
- **Adopción de `textTheme`**: el reporte `grep -r "Theme.of(context).textTheme" mobile/lib/widgets/` debe mostrar al menos 30 consumos (hoy es prácticamente 0).
- **Excepciones documentadas**: cualquier `// token-exception:` en el diff debe listarse en `implementation/decisiones-implementacion.md` con la razón. Meta: ≤ 5 excepciones en toda la migración de widgets.
- **Regresiones visuales**: 0 según validación manual + tests widget existentes.
- **Cero errores de `flutter analyze`**.
- **Cero cambios en el cuerpo de tests** (salvo excepciones documentadas por matcheo explícito de literales).

## Riesgos

- **R-01**: cambio del `textTheme` con `fontSize` explícito puede alterar visualmente componentes M3 que hoy heredan del textTheme sin fontSize (que resolvían a defaults M3). Mitigación: comparar visualmente Splash / Dashboard / Entry form / Reports / Weekly Budgets después de la migración; si algo cambia perceptiblemente, ajustar el token puntual para preservar el look.
- **R-02**: la homologación de `chip radius 16 → 12` reduce ligeramente el radio del chip. Mitigación: comparación visual; si Diego lo prefiere en 16, subir `kRadiusLg` a 14 o crear `kRadiusChip=14` como excepción (evitar tokens extras si es posible).
- **R-03**: la homologación de `FilledButton vertical 14 → 12` reduce ligeramente el alto del botón. Mitigación: idem R-02; si molesta, ajustar el theme del botón con padding vertical `kSpaceMd + kSpace2xs` (12+2=14) sin crear token nuevo.
- **R-04**: `pumpAndSettle` puede colgar si algún test monta widgets con skeleton animado. Mitigación: si ocurre, no bloquear el sprint — documentar el fix pendiente para Sprint 6 (refactor de skeleton) y usar `pump()` explícito en el test afectado.
- **R-05**: la migración de widgets puede generar muchos diffs simultáneos, aumentando riesgo de conflicto con work in progress no committeado. Mitigación: `git status` limpio antes de arrancar; commits atómicos por archivo o por lote pequeño (typography → radii → spacing → alphas → motion → migración widgets → docs) para facilitar bisect si algo se rompe.
- **R-06**: tokens crean un contrato implícito que otros sprints van a expectar. Un cambio de valor en `kSpaceLg` de 16 a 15 en el futuro se propagará. Mitigación: escribir en el docstring de cada token que "cambiar este valor afecta a toda la app" y agregar una regla en `CLAUDE.md`: los tokens fundacionales se cambian con PR dedicada y comparación visual.
- **R-07**: el consumo del `textTheme` requiere `Theme.of(context)`, que no es const. Widgets `const` que hoy declaran `TextStyle` const literal no pueden migrarse a `textTheme.xxx` sin perder `const`. Mitigación: en esos casos, importar directamente el `TextStyle` const desde `fincore_typography.dart` (`import 'package:fincore/theme/fincore_typography.dart' show bodyM;` y usar `bodyM` como const). Es la razón de que `fincore_typography.dart` exponga `const TextStyle` además del cableado en `textTheme`.
- **R-08**: la regla "cero cambios visuales" es difícil de verificar sin herramientas de golden test. Mitigación aceptada: validación manual por comparación side-by-side (screenshot antes/después de las 3-4 pantallas más visibles). Si Diego nota algo raro post-sprint, hotfix inmediato.

## Supuestos

- Los widgets compartidos en `mobile/lib/widgets/` (~24 archivos) son el universo del piloto. `mobile/lib/screens/weekly_budgets/widgets/` (widgets locales del feature) NO entran en este sprint — quedan para el sprint 7 (weekly budgets polish).
- Los tokens propuestos en la auditoría son razonables y no requieren discovery adicional. Si durante la migración se descubre un tamaño que no cabe, se marca como `token-exception:` y se lleva al retro; no se crean tokens nuevos ad-hoc.
- El `textTheme` cableado con `color` por slot (algunos slots con `textMuted` o `textSubtle`) es aceptable como default; los widgets pueden hacer `copyWith(color: ...)` si necesitan otro color.
- Los tests existentes no matchean `fontSize` literales — supuesto verificable con `grep -r "fontSize" mobile/test/`. Si aparecen matches, ver en la implementación cómo tratarlos.
- La regla "sin cambios visuales" tolera diferencias sub-pixel imperceptibles (por ejemplo, chip radius 16 → 12 es un cambio perceptible; padding vertical 14 → 12 apenas).
- El bump de versión a `0.21.0+97` es apropiado dado que es un refactor grande estructural (minor bump). Si Diego prefiere `0.20.3+97` (patch), lo cambiamos al final; no bloquea el sprint.
- La documentación de la convención de iconografía (outlined default) en `CLAUDE.md` es informativa; su ejecución masiva queda para sprints por módulo. En este sprint, si un widget usa un icono inconsistente, se documenta pero no se migra.
- No hay agentes externos (backend, sincronización) que dependan del schema visual, por lo que los cambios de tokens son locales a la app.

## Impacto esperado

**Positivo**:
- Base para todos los sprints siguientes: cualquier refactor visual (dashboard clarity, entry form redesign, reports hub, etc.) parte de tokens explícitos.
- Reducción inmediata de deuda visual en widgets compartidos: la próxima persona que abra `error_snackbar.dart` o `base_card.dart` ve la nueva convención y la copia.
- Documentación viva en `CLAUDE.md` que los siguientes sprints (y futuros contribuidores) deben respetar.
- Retro al cierre del sprint puede detectar si la escala propuesta es realmente cubridora (via el conteo de `token-exception:`); ajustes finos antes de expandir a las screens.

**Negativo** (aceptado):
- Sprint entero sin cambios visuales percibidos: no aporta feature al usuario final. Es inversión estructural.
- Diffs grandes en `mobile/lib/widgets/` y `mobile/lib/theme/`: presión sobre revisión.
- Riesgo pequeño de regresión visual sub-pixel en pantallas que no forman parte del scope (screens que consumen widgets migrados podrían verse levemente distintas — validación manual necesaria).

**Neutral**:
- El bump a `0.21.0` refleja el cambio estructural. La APK sigue instalándose normal (compatible con la BD SQLite existente, sin schema bump).
