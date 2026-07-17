import 'package:flutter/material.dart';

/// Paleta réplica de `frontend/src/assets/main.css` (bloque `@theme`).
///
/// Los valores oklch del CSS se convirtieron a sRGB usando la matriz oficial
/// oklch → oklab → linear RGB → sRGB (gamma corregida). Las constantes están
/// pre-calculadas para no requerir conversión runtime; cada comentario muestra
/// el oklch fuente y el hex sRGB resultante.
///
/// Si Diego nota diferencia perceptible vs Vue, ajustar a mano aquí.
abstract final class FincoreColors {
  // === Superficies y bordes ===

  /// oklch(0.18 0.01 250) — fondo principal de la app.
  static const Color canvas = Color(0xFF1F242B);

  /// oklch(0.22 0.012 250) — fondo de cards/inputs.
  static const Color surface = Color(0xFF272D35);

  /// oklch(0.27 0.014 250) — surface elevada (cards activas, dialogs).
  static const Color surfaceElevated = Color(0xFF333B44);

  /// oklch(0.32 0.012 250) — bordes y dividers.
  static const Color border = Color(0xFF3F4751);

  // === Tipografía ===

  /// oklch(0.96 0.005 250) — texto principal.
  static const Color textPrimary = Color(0xFFF3F4F6);

  /// oklch(0.72 0.01 250) — texto secundario / muted.
  static const Color textMuted = Color(0xFFAAB0B8);

  /// oklch(0.55 0.01 250) — texto terciario / subtle.
  static const Color textSubtle = Color(0xFF7B8088);

  // === Acentos funcionales ===

  /// oklch(0.74 0.16 215) — color de acción/links (azul cyan).
  static const Color accent = Color(0xFF4CABDB);

  /// oklch(0.78 0.16 215) — hover del accent.
  static const Color accentHover = Color(0xFF67B9E2);

  /// oklch(0.78 0.18 145) — positivo (saldo a favor, ingreso).
  static const Color positive = Color(0xFF50CC8E);

  /// oklch(0.7 0.2 25) — negativo (saldo negativo, error).
  static const Color negative = Color(0xFFE05959);

  /// oklch(0.82 0.14 75) — warning (badge amarillo cálido).
  static const Color warning = Color(0xFFEBBD52);

  // === Catálogo de categorías (10 slugs) ===
  // Estos slugs son contrato compartido con backend (CategoryDefaults.php) y
  // Vue (frontend/src/constants/categoryCatalog.js).

  /// oklch(0.74 0.16 240)
  static const Color categoryBlue = Color(0xFF5A9AE0);

  /// oklch(0.78 0.18 145)
  static const Color categoryGreen = Color(0xFF50CC8E);

  /// oklch(0.7 0.2 25)
  static const Color categoryRed = Color(0xFFE05959);

  /// oklch(0.78 0.16 60)
  static const Color categoryOrange = Color(0xFFE0A04F);

  /// oklch(0.7 0.18 305)
  static const Color categoryPurple = Color(0xFFB561D6);

  /// oklch(0.78 0.16 350)
  static const Color categoryPink = Color(0xFFE068A4);

  /// oklch(0.75 0.14 195)
  static const Color categoryTeal = Color(0xFF52BDC4);

  /// oklch(0.85 0.16 100)
  static const Color categoryYellow = Color(0xFFE5D552);

  /// oklch(0.65 0.18 275)
  static const Color categoryIndigo = Color(0xFF7B7DE0);

  /// oklch(0.68 0.02 250)
  static const Color categoryGray = Color(0xFFA4A8B0);

  // === Alphas semánticos (sprint flutter-design-tokens-v1) ===
  // Usar como `Color.withValues(alpha: FincoreColors.alphaX)`.
  // Prohibido `withValues(alpha: N)` con N literal fuera de esta escala en
  // widgets/screens, salvo excepciones marcadas con `// token-exception:`.

  /// Overlay hover sobre surface (cards interactivas).
  static const double alphaHover = 0.08;

  /// Bordes tinted (destructive hero, alert card).
  static const double alphaHairline = 0.12;

  /// Fill tinted por color de contexto (badge, kind tile, semántico).
  static const double alphaTint = 0.15;

  /// Estado seleccionado (chip active, picker tile).
  static const double alphaSelected = 0.20;

  /// Sprint flutter-budgets-polish-v1: atenuación uniforme para estado
  /// "completado / done" en items de presupuesto. Aplicar al stripe, monto
  /// tachado, badge de categoría y a cualquier acento de color que deba
  /// leerse como "presente pero secundario". Un solo valor para evitar la
  /// incoherencia de 3 alphas distintas (0.35/0.45/0.50) en el mismo row.
  static const double alphaMuted = 0.45;
}
