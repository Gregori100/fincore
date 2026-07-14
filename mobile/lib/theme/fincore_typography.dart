import 'package:fincore/theme/fincore_colors.dart';
import 'package:flutter/material.dart';

/// Tokens tipográficos canónicos de FinCore (sprint flutter-design-tokens-v1).
///
/// Estos 7 estilos definen TODA la escala tipográfica de la app. Cualquier
/// texto en widgets o screens debe consumir uno de estos tokens, ya sea
/// directamente (`import 'fincore_typography.dart' show bodyM;`) o vía
/// `Theme.of(context).textTheme.xxx` (que cablea a estos mismos tokens).
///
/// Prohibido `TextStyle(fontSize: N)` inline en el resto de la app.
/// Excepción documentada: `fincore_logo.dart` usa fontSize proporcional.
///
/// Cambiar el fontSize/weight/letterSpacing de un token afecta a toda la
/// app y requiere PR dedicada + comparación visual.

/// Logo splash y first-run. Único caso donde se justifica un tamaño display.
const TextStyle displayXL = TextStyle(
  color: FincoreColors.textPrimary,
  fontSize: 56,
  fontWeight: FontWeight.w800,
  letterSpacing: -1.5,
);

/// Título de dialog, screen hero, tarjetas grandes.
const TextStyle headingL = TextStyle(
  color: FincoreColors.textPrimary,
  fontSize: 20,
  fontWeight: FontWeight.w700,
  letterSpacing: -0.3,
);

/// Título de card, subhead de sección.
const TextStyle headingM = TextStyle(
  color: FincoreColors.textPrimary,
  fontSize: 16,
  fontWeight: FontWeight.w600,
  letterSpacing: 0,
);

/// Default para texto largo, descripciones, cuerpo.
const TextStyle bodyM = TextStyle(
  color: FincoreColors.textPrimary,
  fontSize: 14,
  fontWeight: FontWeight.w400,
  letterSpacing: 0,
);

/// Chips, badges, item primario en listas densas.
const TextStyle bodyS = TextStyle(
  color: FincoreColors.textPrimary,
  fontSize: 13,
  fontWeight: FontWeight.w500,
  letterSpacing: 0,
);

/// Metadata, subtítulos de fila, texto secundario. Default color muted.
const TextStyle label = TextStyle(
  color: FincoreColors.textMuted,
  fontSize: 12,
  fontWeight: FontWeight.w600,
  letterSpacing: 0.1,
);

/// SectionTitle "MIS CUENTAS" y similares. Color subtle + uppercase.
const TextStyle overline = TextStyle(
  color: FincoreColors.textSubtle,
  fontSize: 11,
  fontWeight: FontWeight.w600,
  letterSpacing: 1.2,
);
