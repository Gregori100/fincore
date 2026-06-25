import 'package:fincore/theme/fincore_colors.dart';
import 'package:flutter/material.dart';

/// Tema único oscuro de FinCore. Mapea la paleta `FincoreColors` (réplica de
/// las CSS variables de la Vue web) a un `ColorScheme.dark` custom de Material 3.
ThemeData fincoreDarkTheme() {
  // chip color fix v2: `secondaryContainer` se usa por Material 3 como
  // background del ChoiceChip seleccionado + base del ripple/overlay al
  // tappear. Sin override, derivaba del `secondary` (positive verde) y se
  // veía verde al pickear los chips de filtros. Override al accent para que
  // el ripple/state quede consistente con el accent azul cyan.
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
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: FincoreColors.border, width: 1),
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: FincoreColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: FincoreColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: FincoreColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: FincoreColors.accent, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: FincoreColors.negative),
      ),
      labelStyle: const TextStyle(color: FincoreColors.textMuted),
      hintStyle: const TextStyle(color: FincoreColors.textSubtle),
    ),

    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: FincoreColors.accent,
        foregroundColor: FincoreColors.canvas,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
      selectedColor: FincoreColors.accent.withValues(alpha: 0.18),
      checkmarkColor: FincoreColors.accent,
      // surfaceTintColor transparente evita el tint M3 verde-grisáceo
      // que se aplicaba al chip elevado al tappear.
      surfaceTintColor: Colors.transparent,
      labelStyle: const TextStyle(color: FincoreColors.textPrimary, fontSize: 13),
      side: const BorderSide(color: FincoreColors.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),

    textTheme: const TextTheme(
      displayLarge: TextStyle(color: FincoreColors.textPrimary, fontWeight: FontWeight.w700),
      displayMedium: TextStyle(color: FincoreColors.textPrimary, fontWeight: FontWeight.w700),
      displaySmall: TextStyle(color: FincoreColors.textPrimary, fontWeight: FontWeight.w700),
      headlineLarge: TextStyle(color: FincoreColors.textPrimary, fontWeight: FontWeight.w600),
      headlineMedium: TextStyle(color: FincoreColors.textPrimary, fontWeight: FontWeight.w600),
      headlineSmall: TextStyle(color: FincoreColors.textPrimary, fontWeight: FontWeight.w600),
      titleLarge: TextStyle(color: FincoreColors.textPrimary, fontWeight: FontWeight.w600),
      titleMedium: TextStyle(color: FincoreColors.textPrimary, fontWeight: FontWeight.w600),
      titleSmall: TextStyle(color: FincoreColors.textPrimary, fontWeight: FontWeight.w500),
      bodyLarge: TextStyle(color: FincoreColors.textPrimary),
      bodyMedium: TextStyle(color: FincoreColors.textPrimary),
      bodySmall: TextStyle(color: FincoreColors.textMuted),
      labelLarge: TextStyle(color: FincoreColors.textPrimary, fontWeight: FontWeight.w500),
      labelMedium: TextStyle(color: FincoreColors.textMuted),
      labelSmall: TextStyle(color: FincoreColors.textSubtle),
    ),
  );
}
