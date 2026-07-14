/// Tokens de radio canónicos de FinCore (sprint flutter-design-tokens-v1).
///
/// 5 valores discretos. Usar como `BorderRadius.circular(kRadiusLg)`.
/// Prohibido `BorderRadius.circular(N)` con N literal fuera de esta escala
/// en widgets/screens.
///
/// Excepciones puntuales se marcan con `// token-exception:` explicando por qué.
library;

/// Chips micro, indicadores.
const double kRadiusSm = 6;

/// Inputs, buttons, picker tiles.
const double kRadiusMd = 8;

/// Cards, snackbars, chips.
const double kRadiusLg = 12;

/// Dialogs, bottom sheets.
const double kRadiusXl = 20;

/// Chips de filtro, badges circulares (fully rounded).
const double kRadiusPill = 999;
