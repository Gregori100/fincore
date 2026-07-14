import 'package:fincore/theme/fincore_colors.dart';
import 'package:fincore/theme/fincore_radii.dart';
import 'package:fincore/theme/fincore_spacing.dart';
import 'package:fincore/theme/fincore_typography.dart' as ft;
import 'package:flutter/material.dart';

/// Tema único oscuro de FinCore. Mapea la paleta `FincoreColors` (réplica de
/// las CSS variables de la Vue web) a un `ColorScheme.dark` custom de Material 3.
///
/// El `textTheme` cablea los 15 slots M3 a los 7 tokens de `fincore_typography.dart`
/// (sprint flutter-design-tokens-v1). Radios y padding consumen tokens de
/// `fincore_radii.dart` y `fincore_spacing.dart`.
ThemeData fincoreDarkTheme() {
  // chip color fix v2: `secondaryContainer` se usa por Material 3 como
  // background del ChoiceChip seleccionado + base del ripple/overlay al
  // tappear. Sin override, derivaba del `secondary` (positive verde) y se
  // veía verde al pickear los chips de filtros. Override al accent para que
  // el ripple/state quede consistente con el accent azul cyan.
  //
  // M6 del quality review v1 — auditoría de componentes M3 que toman
  // `secondaryContainer` heredado:
  //   - Chip / ChoiceChip / FilterChip → ya cubiertos por chipTheme.
  //   - Badge (no en uso hoy) → tomaría accent. Aceptable.
  //   - NavigationBar (no en uso hoy) → tomaría accent en el indicator.
  //   - NavigationDrawer (no en uso hoy) → tomaría accent en el highlight.
  //   - FilledTonalButton (no en uso hoy) → tomaría accent.
  //   - ListTile selected (no en uso hoy) → tomaría accent.
  // Si en futuros sprints se introduce alguno de estos componentes, validar
  // visualmente que el accent en el lugar de secondaryContainer luce
  // intencional. Si no, considerar tema más granular vía componentTheme.
  const colorScheme = ColorScheme.dark(
    brightness: Brightness.dark,
    primary: FincoreColors.accent,
    onPrimary: FincoreColors.canvas,
    primaryContainer: FincoreColors.accentHover,
    onPrimaryContainer: FincoreColors.canvas,
    secondary: FincoreColors.positive,
    onSecondary: FincoreColors.canvas,
    secondaryContainer: FincoreColors.accent,
    onSecondaryContainer: FincoreColors.canvas,
    tertiary: FincoreColors.warning,
    onTertiary: FincoreColors.canvas,
    error: FincoreColors.negative,
    onError: FincoreColors.textPrimary,
    surface: FincoreColors.surface,
    onSurface: FincoreColors.textPrimary,
    surfaceContainerHighest: FincoreColors.surfaceElevated,
    surfaceContainerHigh: FincoreColors.surfaceElevated,
    surfaceContainer: FincoreColors.surface,
    surfaceContainerLow: FincoreColors.surface,
    surfaceContainerLowest: FincoreColors.canvas,
    outline: FincoreColors.border,
    outlineVariant: FincoreColors.border,
    onSurfaceVariant: FincoreColors.textMuted,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: FincoreColors.canvas,

    appBarTheme: const AppBarTheme(
      backgroundColor: FincoreColors.canvas,
      foregroundColor: FincoreColors.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),

    cardTheme: CardThemeData(
      color: FincoreColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kRadiusLg),
        side: const BorderSide(color: FincoreColors.border, width: 1),
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: FincoreColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kRadiusMd),
        borderSide: const BorderSide(color: FincoreColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kRadiusMd),
        borderSide: const BorderSide(color: FincoreColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kRadiusMd),
        borderSide: const BorderSide(color: FincoreColors.accent, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kRadiusMd),
        borderSide: const BorderSide(color: FincoreColors.negative),
      ),
      labelStyle: const TextStyle(color: FincoreColors.textMuted),
      hintStyle: const TextStyle(color: FincoreColors.textSubtle),
    ),

    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: FincoreColors.accent,
        foregroundColor: FincoreColors.canvas,
        // era `horizontal: 24, vertical: 14` → tokenizado.
        // vertical 14 se homologa a kSpaceMd=12 (leve reducción de alto del
        // botón, decisión del sprint flutter-design-tokens-v1 documentada
        // en decisiones-implementacion.md).
        padding: const EdgeInsets.symmetric(
          horizontal: kSpaceXl,
          vertical: kSpaceMd,
        ),
        // era fontSize: 15 → bodyM (14). La etiqueta de botón encaja mejor
        // en bodyM que en headingM.
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadiusMd)),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: FincoreColors.accent,
      ),
    ),

    snackBarTheme: const SnackBarThemeData(
      backgroundColor: FincoreColors.surfaceElevated,
      contentTextStyle: TextStyle(color: FincoreColors.textPrimary),
      behavior: SnackBarBehavior.floating,
    ),

    dividerTheme: const DividerThemeData(
      color: FincoreColors.border,
      thickness: 1,
      space: 1,
    ),

    listTileTheme: const ListTileThemeData(
      iconColor: FincoreColors.textMuted,
      textColor: FincoreColors.textPrimary,
    ),

    chipTheme: ChipThemeData(
      backgroundColor: FincoreColors.surfaceElevated,
      // Quality review v1 — el ChoiceChip de M3 usaba `secondary` del
      // colorScheme para selectedColor + state overlay, lo cual mapeaba a
      // FincoreColors.positive (#50CC8E verde de ingresos) y desentonaba
      // de la paleta del feature. Override explícito al accent:
      // era `alpha: 0.18` → alphaSelected (0.20). Cambio sub-perceptible.
      selectedColor: FincoreColors.accent.withValues(alpha: FincoreColors.alphaSelected),
      checkmarkColor: FincoreColors.accent,
      // surfaceTintColor transparente evita el tint M3 verde-grisáceo
      // que se aplicaba al chip elevado al tappear.
      surfaceTintColor: Colors.transparent,
      // era fontSize: 13 → bodyS (13, exacto).
      labelStyle: const TextStyle(color: FincoreColors.textPrimary, fontSize: 13),
      side: const BorderSide(color: FincoreColors.border),
      // era radius 16 → kRadiusLg (12). Chips ligeramente menos redondeados;
      // decisión del sprint flutter-design-tokens-v1.
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadiusLg)),
    ),

    // textTheme cableado a los 7 tokens de fincore_typography.dart.
    // Mapping documentado en engineering/specs/flutter-design-tokens-v1/spec.md
    // (sección Alcance). fontSize explícito por slot (antes estaba sin fontSize
    // y por eso nadie consumía el textTheme).
    textTheme: TextTheme(
      // Display slots → displayXL (56/w800/-1.5).
      displayLarge: ft.displayXL,
      displayMedium: ft.displayXL,
      displaySmall: ft.displayXL,
      // Headline slots → headingL (20/w700/-0.3).
      headlineLarge: ft.headingL,
      headlineMedium: ft.headingL,
      headlineSmall: ft.headingL,
      // Title Large/Medium → headingM (16/w600/0).
      titleLarge: ft.headingM,
      titleMedium: ft.headingM,
      // Title Small → bodyS (13/w500/0).
      titleSmall: ft.bodyS,
      // Body Large/Medium → bodyM (14/w400/0).
      bodyLarge: ft.bodyM,
      bodyMedium: ft.bodyM,
      // Body Small → label (12/w600) con color muted (default del token label).
      bodySmall: ft.label,
      // Label Large → label (12/w600) pero con color primary (override).
      labelLarge: ft.label.copyWith(color: FincoreColors.textPrimary),
      // Label Medium → label (12/w600) con color muted (default).
      labelMedium: ft.label,
      // Label Small → overline (11/w600/1.2) con color subtle (default).
      labelSmall: ft.overline,
    ),
  );
}
