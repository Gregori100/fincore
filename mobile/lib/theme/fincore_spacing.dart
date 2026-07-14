import 'package:flutter/widgets.dart';

/// Tokens de spacing canónicos de FinCore (sprint flutter-design-tokens-v1).
///
/// Escala 2/4/8/12/16/24/32 alineada a grid 4dp. Cualquier padding, margin
/// o SizedBox en widgets/screens debe usar uno de estos tokens (o un
/// EdgeInsets derivado). Prohibido literales fuera de la escala.
///
/// Excepciones puntuales se marcan con `// token-exception:` explicando por qué.

/// Micro-gap (badge inner icon-text).
const double kSpace2xs = 2;

/// Inter-línea dentro de chip/badge.
const double kSpaceXs = 4;

/// Gap default intra-widget.
const double kSpaceSm = 8;

/// Gap default entre widgets, list separator.
const double kSpaceMd = 12;

/// Padding de card, gap entre secciones.
const double kSpaceLg = 16;

/// Padding de screen/dialog, gap entre bloques.
const double kSpaceXl = 24;

/// Hero del dialog destructivo, respiración especial.
const double kSpace2xl = 32;

// === EdgeInsets derivados semánticos ===

/// Padding interno de una card estándar (`all(kSpaceLg)`).
const EdgeInsets kEdgeCard = EdgeInsets.all(kSpaceLg);

/// Padding de una fila en una lista (`symmetric(H:kSpaceLg, V:kSpaceMd)`).
const EdgeInsets kEdgeListItem = EdgeInsets.symmetric(
  horizontal: kSpaceLg,
  vertical: kSpaceMd,
);

/// Padding interior de un dialog (`fromLTRB(kSpaceXl, kSpace2xl, kSpaceXl, kSpaceXl)`).
const EdgeInsets kEdgeDialog = EdgeInsets.fromLTRB(
  kSpaceXl,
  kSpace2xl,
  kSpaceXl,
  kSpaceXl,
);

/// Padding base de una screen sin FAB (`fromLTRB(kSpaceLg, kSpaceMd, kSpaceLg, kSpaceXl)`).
/// Si la screen tiene FAB visible, usar `kEdgeScreen.copyWith(bottom: kFabClearance)`.
const EdgeInsets kEdgeScreen = EdgeInsets.fromLTRB(
  kSpaceLg,
  kSpaceMd,
  kSpaceLg,
  kSpaceXl,
);

/// Bottom padding cuando la screen tiene FloatingActionButton visible.
/// `kSpace2xl * 3 = 96`. Evita que el FAB tape la última fila.
///
/// Uso: `EdgeInsets.fromLTRB(kSpaceLg, kSpaceMd, kSpaceLg, kFabClearance)`.
const double kFabClearance = 96;
