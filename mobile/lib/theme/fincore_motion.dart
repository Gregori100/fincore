import 'package:flutter/animation.dart';

/// Tokens de motion canónicos de FinCore (sprint flutter-design-tokens-v1).
///
/// Filosofía: **motion existe para (1) señalizar causalidad ("esto vino
/// de acá") y (2) suavizar cambios de estado. Nunca para decorar.**
///
/// - No usar animaciones spring bouncy en formularios (dan sensación de
///   juguete en una app financiera).
/// - Sí usar micro-easing en snackbar, chip toggle, sheet enter, dialog.
/// - Preferir fade + slide sutil (dy: 0.02) para transiciones de contenido.
/// - Loops (skeleton, spinner) usan `kCurveLinear` con duración larga.
///
/// Prohibido `Duration(milliseconds: N)` en animaciones sin usar uno de
/// estos tokens. Excepciones puntuales se marcan con `// token-exception:`.

/// Ripple substitute, feedback táctil.
const Duration kMotionInstant = Duration(milliseconds: 100);

/// Snackbar in/out, chip toggle, hover state.
const Duration kMotionFast = Duration(milliseconds: 200);

/// Dialog/sheet enter, page transition.
const Duration kMotionMedium = Duration(milliseconds: 300);

/// Onboarding hero, transiciones enfáticas.
const Duration kMotionSlow = Duration(milliseconds: 500);

/// Loop del skeleton (pulse).
const Duration kMotionPulse = Duration(milliseconds: 1100);

/// Curva default para animaciones "in" (enter).
const Curve kCurveStandard = Curves.easeOutCubic;

/// Curva default para animaciones "out" (exit).
const Curve kCurveExit = Curves.easeIn;

/// Curva emphasized de Material 3 (sheet enter, hero, page).
const Curve kCurveEmphasized = Cubic(0.2, 0, 0, 1);

/// Curva lineal para loops (skeleton, spinner).
const Curve kCurveLinear = Curves.linear;
