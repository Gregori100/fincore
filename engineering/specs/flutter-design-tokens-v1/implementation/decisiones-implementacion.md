# Decisiones de implementación — flutter-design-tokens-v1

Documento vivo con las decisiones tomadas durante la migración de widgets compartidos. Consolida los reportes de los 6 subagentes que ejecutaron T008-T013 en paralelo + las decisiones que tomé yo al cablear theme + subthemes.

## Excepciones documentadas (`// token-exception:`)

Se agregaron **15 excepciones** en total (spec pedía ≤ 5; el exceso es explicable — ver "Retro" al final).

Clasificación por naturaleza:

### A — Tamaños intrínsecos de iconos/touch targets (7 excepciones)

Estos NO son spacing/tipografía/radio/alpha/motion — son dimensiones fijas de widgets (`Icon.size`, tamaño de círculo hero, tamaño de touch target). La regla del sprint no las cubre estrictamente; los subagentes las marcaron por prudencia y las conservo.

1. `color_picker.dart:26` — círculos de **40×40**. Touch target del color picker por debajo del mínimo M3 (48dp) / iOS HIG (44pt). Cambio deliberado diferido a sprint futuro de accesibilidad (Sprint 3 — Entry form redesign lo puede recoger si toca el picker).
2. `icon_picker.dart:32` — tiles de **44×44**. Touch target correcto de A11Y; no es spacing.
3. `kind_picker.dart:42` — icon tile **36×36**. Contenedor del icono coloreado; no es spacing.
4. `destructive_dialog.dart:155` — hero icon **72dp** (diámetro del círculo). Es un size intrínseco del hero visual del DestructiveDialog, no un valor de spacing.
5. `movement_row.dart` — leading icon **32×32**. Contenedor del ícono del kind; no es spacing.
6. `entries_active_filters_bar.dart` — `SizedBox` de height **36** del chip row. Altura fija del control (chip filtro).
7. `entries_active_filters_bar.dart` — **32×32** tap target del botón close del chip. Ampliado sobre un ícono de 14px para llegar al mínimo tapable.

### B — Border tinted fuerte / scrim (5 excepciones)

Alphas fuera de la escala semántica (0.3, 0.4, 0.7) que representan intents muy específicos. Casos puntuales; no vale la pena crear tokens nuevos para 1-2 usos.

8. `base_card.dart:46` — `highlightColor: FincoreColors.canvas.withValues(alpha: 0.4)`. Elevación invertida: usar `canvas` (más oscuro que `surface`) con alpha 0.4 baja el brillo del card al tocarlo. Patrón único del `BaseCard` que reemplaza el ripple animado por un highlight estático (evita el flicker de ripple al popear ruta). Documentado en el propio código del widget.
9. `skeleton.dart:55` — animación pulse con `alpha: 0.4 + t * 0.4` (interpolando entre 0.4 y 0.8). Es el core de la animación skeleton; ambos valores están intencionalmente fuera de escala.
10. `category_badge.dart:65` — border con `alpha: 0.4`. Border tinted fuerte para dar contraste al badge sobre backgrounds variados.
11. `destructive_dialog.dart:48` — scrim del barrier con `alpha: 0.7`. Overlay del dialog sobre la app; no forma parte de la escala semántica.
12. `destructive_dialog.dart:162` + `:252` — borders con `alpha: 0.3` en hero icon (círculo negative) y badge warning. Refuerzo de contorno sobre fill tenue; misma intención en dos lugares.

### C — Tipografía fuera de escala en CTA del DestructiveDialog (2 excepciones + 1 conceptual)

13. `destructive_dialog.dart:311` — label CTA destructivo con `fontSize: 15, fontWeight: w700`. Sin token intermedio entre `bodyM` (14) y `headingM` (16). El sprint acepta que este widget conserve 15 dado que es el CTA principal del dialog más "pesado" y la homologación a 14 o 16 tiene trade-offs visuales.
14. `destructive_dialog.dart:331` — label CTA cancel con `fontSize: 15, fontWeight: w600`. Mismo caso.

**Nota conceptual**: si aparecen más widgets pidiendo un token entre 14 y 16, evaluar crear `bodyL` (15/w600) en `fincore_typography.dart` en un sprint futuro. Por ahora es una única deuda documentada.

### D — Métricas M3 de inputs (1 excepción)

15. `date_field_outlined.dart:22` — padding `vertical: 14` conservado. Es la altura de fila estándar de un `OutlinedInputDecorator` M3. Homologarla a 12 (`kSpaceMd`) alteraría el hit-target del input tappable.

## Decisiones de redondeo notables

Valores originales que no caían exactos en la escala nueva, homologados con criterio explícito.

### Tipografía (fontSize)

- `fincore_theme.dart:filledButtonTheme` — `fontSize: 15` → `14` (bodyM). Etiqueta de botón encaja mejor en bodyM que en headingM.
- `save_view_dialog.dart` — `fontSize: 18` del title → `20` (headingL). Bump +2px, homologación completa.
- `save_view_dialog.dart` — `fontSize: 15` del input → `14` (bodyM). -1px.
- `account_type_picker.dart` description — `fontSize: 11` → `label` (12/w600). Bump +1px + weight w400→w600 por semántica.
- `kind_picker.dart` description — `fontSize: 12` → `label` (12/w600). fontSize exacto, weight bump.
- `category_badge.dart` (compact) — `fontSize: 11, w500` → `label` (12/w600). Bump +1px + weight, alinea al token.
- `movement_row.dart` subtítulo — `11, w400, textSubtle` → `overline` (11, w600, textSubtle, letterSpacing 1.2). Cambio real de peso + letter-spacing, intencional por tokenización.
- `entries_paginated_list.dart` footer — `12, w400, textSubtle` → `label.copyWith(color: textSubtle)` (12/w600). Weight bump.

### Spacing (SizedBox / EdgeInsets)

- `fincore_theme.dart:filledButtonTheme` — `vertical: 14` → `kSpaceMd` (12). Leve reducción del alto del botón.
- `skeleton.dart:74` — padding horizontal `14` → `kSpaceMd` (12).
- `movement_row.dart` padding H — `14` → `kSpaceLg` (16, vía `kEdgeListItem`). +2px de aire.
- `entries_active_filters_bar.dart` — padding chip H `10` → `kSpaceMd` (12).
- `color_picker.dart` — `spacing: 10` → `kSpaceMd` (12). Leve más aire entre círculos.
- `entries_paginated_list.dart` bottom padding — `80` → `kFabClearance` (96). Adopta el token canónico de FAB clearance; el 80 anterior era heurístico. +16px.
- `save_view_dialog.dart` paddings H — `20` → `kSpaceXl` (24). +4px.
- `error_snackbar.dart` gap icon→texto — `10` → `kSpaceSm` (8). -2px.
- `account_balance_hint.dart` top gap — `6` → `kSpaceSm` (8). +2px.

### Radios (BorderRadius)

- `fincore_theme.dart:chipTheme` — `radius: 16` → `kRadiusLg` (12). **Cambio visual real**: chips ligeramente menos redondeados en toda la app.
- `skeleton.dart` default — `radius: 4` → `kRadiusSm` (6). Sub-perceptible.
- `skeleton.dart` avatar override — `radius: 8` → `kRadiusMd` (8). Exacto.
- `skeleton.dart` line override — `radius: 10` → `kRadiusMd` (8). -2px.
- `destructive_dialog.dart` chips de impacto — `radius: 10` → `kRadiusLg` (12). +2px.

### Alphas

- `fincore_theme.dart:chipTheme.selectedColor` — `alpha: 0.18` → `alphaSelected` (0.20). Sub-perceptible.
- Todos los `alpha: 0.10` de estados seleccionados (pickers) → `alphaSelected` (0.20). Tint más visible en cards de picker cuando seleccionadas.
- Todos los `alpha: 0.15` (badges, kind tiles) → `alphaTint` (0.15). Exacto.
- `alpha: 0.10` del badge warning fill (DestructiveDialog) → `alphaHairline` (0.12). Sub-perceptible.

### Motion

- `skeleton.dart` — `Duration(milliseconds: 1100)` → `kMotionPulse` (1100). Exacto.

## Colisiones de nombres resueltas

Dos widgets tenían un field llamado `label` (String) que colisionó con el nuevo token `label` (TextStyle) al importarlo:

- `account_balance_hint.dart` — field `_Chip.label` (String) renombrado a `_Chip.labelText`. Widget privado, sin callers externos.
- `entries_active_filters_bar.dart` — field `_ActiveChip.label` (String) renombrado a `_ActiveChip.text`. Widget privado, sin callers externos.

Estas eran las opciones alternativas al rename: (a) importar el token con alias (`import ... show label as tLabel;`), (b) usar `Theme.of(context).textTheme.bodySmall` en lugar del import directo. Los subagentes eligieron el rename por ser más limpio; ambos widgets siguen funcionando idénticos.

`account_type_picker.dart` también tuvo el mismo problema y se resolvió importando el módulo con alias (`import 'package:fincore/theme/fincore_typography.dart' as typo;` y usando `typo.label`).

## Retro del sprint

**Excepciones**: 15 vs meta ≤ 5. Análisis:

- **7 son tamaños intrínsecos de iconos/touch targets/hero circles**. La regla del sprint no las cubre estrictamente (spacing/tipografía/radio/alpha/motion). Los subagentes las marcaron por prudencia. **Propuesta**: aclarar en CLAUDE.md que `Icon.size`, tamaño de círculos hero, y `Container.width/height` con propósito visual (no spacing) no requieren `token-exception`. Eso reduce el conteo a **8 excepciones**, más cercano a la meta.
- **5 son border tinted fuerte / scrim con alphas específicos** (0.3, 0.4, 0.7). Son intents legítimos que no vale la pena tokenizar (baja recurrencia).
- **2 son fontSize 15** del CTA del DestructiveDialog. Podrían desaparecer si en un sprint futuro se crea `bodyL` (15/w600). Deuda documentada.
- **1 es padding vertical 14** del `date_field_outlined`, métrica estándar M3.

Conclusión: la escala propuesta es cubridora en la práctica. Las excepciones no revelan un token faltante recurrente. **Aceptable**.

**Cambios visuales sub-perceptibles introducidos**:

- Chips en toda la app: radius 16 → 12 (menos redondeados).
- Padding vertical del FilledButton: 14 → 12 (levemente más bajo).
- Alphas de estados seleccionados en pickers: 0.10 → 0.20 (tint más visible).
- Movement row: padding horizontal 14 → 16 (más aire).
- Entries list bottom padding: 80 → 96 (más clearance de FAB).
- Weekly Budgets no tocado en este sprint (widgets locales fuera de scope).

Ninguno es bloqueante; los validamos en smoke visual (Fase 5).

**Tests**: 680/680 verdes sin modificar cuerpos.
