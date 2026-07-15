import 'package:fincore/theme/fincore_colors.dart';
import 'package:fincore/theme/fincore_spacing.dart';
import 'package:fincore/theme/fincore_typography.dart' as typo;
import 'package:flutter/material.dart';

/// Empty state genérico reusable en toda la app.
///
/// Sprint `flutter-reports-shared-widgets-v1` (parte del roadmap de la
/// auditoría 2026-07-14). Reemplaza `Text` centrados en `textMuted` con
/// un componente que da ícono grande + título + body opcional + CTA.
///
/// Uso típico:
/// ```
/// FincoreEmptyState(
///   icon: Icons.receipt_long_outlined,
///   title: 'Aún no hay movimientos',
///   body: 'Registra el primero desde el botón +.',
///   cta: FilledButton(onPressed: ..., child: const Text('Registrar')),
/// )
/// ```
class FincoreEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? body;
  final Widget? cta;

  const FincoreEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.body,
    this.cta,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: kSpaceXl,
        vertical: kSpaceXl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 48,
            color: FincoreColors.textMuted,
          ),
          const SizedBox(height: kSpaceMd),
          Text(
            title,
            textAlign: TextAlign.center,
            style: typo.headingM.copyWith(color: FincoreColors.textPrimary),
          ),
          if (body != null) ...[
            const SizedBox(height: kSpaceSm),
            Text(
              body!,
              textAlign: TextAlign.center,
              style: typo.bodyM.copyWith(color: FincoreColors.textMuted),
            ),
          ],
          if (cta != null) ...[
            const SizedBox(height: kSpaceLg),
            cta!,
          ],
        ],
      ),
    );
  }
}
