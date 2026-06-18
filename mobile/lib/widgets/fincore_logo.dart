import 'package:fincore/theme/fincore_colors.dart';
import 'package:flutter/material.dart';

/// Logo wordmark de FinCore. "Fin" en azul (accent), "Core" en blanco
/// (textPrimary). Tagline opcional debajo.
class FincoreLogo extends StatelessWidget {
  final double fontSize;
  final bool showTagline;
  final String tagline;

  const FincoreLogo({
    super.key,
    this.fontSize = 56,
    this.showTagline = true,
    this.tagline = 'Tu libreta digital de cuentas',
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.5,
              height: 1.0,
            ),
            children: const [
              TextSpan(
                text: 'Fin',
                style: TextStyle(color: FincoreColors.accent),
              ),
              TextSpan(
                text: 'Core',
                style: TextStyle(color: FincoreColors.textPrimary),
              ),
            ],
          ),
        ),
        if (showTagline) ...[
          SizedBox(height: fontSize * 0.18),
          Text(
            tagline,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: FincoreColors.textMuted,
              fontSize: fontSize * 0.27,
              fontWeight: FontWeight.w400,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ],
    );
  }
}
