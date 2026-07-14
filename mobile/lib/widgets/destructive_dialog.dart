import 'package:fincore/theme/fincore_colors.dart';
import 'package:fincore/theme/fincore_radii.dart';
import 'package:fincore/theme/fincore_spacing.dart';
import 'package:fincore/theme/fincore_typography.dart' as t;
import 'package:flutter/material.dart';

/// Ítem de impacto que se muestra como chip visual en el diálogo. Cada uno
/// comunica una consecuencia concreta de la acción destructiva (ej: "42
/// movimientos activos", "Saldos de otras cuentas se ajustarán").
class DestructiveImpact {
  final IconData icon;
  final String label;

  const DestructiveImpact({required this.icon, required this.label});
}

/// Diálogo de confirmación para acciones destructivas (archivar cuenta,
/// categoría, resetear BD). Diseñado para transmitir gravedad sin ser
/// abrumador: ícono destacado + nombre del objeto + chips visuales que
/// resumen el impacto + advertencia final sobre irreversibilidad.
///
/// Uso:
/// ```dart
/// final ok = await showDestructiveDialog(
///   context,
///   title: 'Archivar cuenta',
///   objectName: account.name,
///   icon: Icons.archive_outlined,
///   impacts: [
///     DestructiveImpact(icon: Icons.receipt_long, label: '42 movimientos'),
///     DestructiveImpact(icon: Icons.account_balance_wallet, label: 'Saldos ajustados'),
///   ],
///   description: 'Los movimientos donde esta cuenta aparece como origen '
///                'o destino se cancelarán.',
///   confirmLabel: 'Archivar todo',
/// );
/// ```
Future<bool> showDestructiveDialog(
  BuildContext context, {
  required String title,
  required String objectName,
  required IconData icon,
  required List<DestructiveImpact> impacts,
  required String description,
  required String confirmLabel,
  String cancelLabel = 'Cancelar',
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    // token-exception: barrier scrim, 0.7 calibrado para el destructive
    // (más denso que el default M3) y no forma parte de la escala alpha.
    barrierColor: Colors.black.withValues(alpha: 0.7),
    builder: (context) => _DestructiveDialog(
      title: title,
      objectName: objectName,
      icon: icon,
      impacts: impacts,
      description: description,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
    ),
  );
  return result ?? false;
}

class _DestructiveDialog extends StatelessWidget {
  final String title;
  final String objectName;
  final IconData icon;
  final List<DestructiveImpact> impacts;
  final String description;
  final String confirmLabel;
  final String cancelLabel;

  const _DestructiveDialog({
    required this.title,
    required this.objectName,
    required this.icon,
    required this.impacts,
    required this.description,
    required this.confirmLabel,
    required this.cancelLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: FincoreColors.surface,
      elevation: 12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadiusXl)),
      // Vertical usa composición kSpace2xl + kSpaceSm = 40 para preservar
      // el inset original alrededor del dialog.
      insetPadding: const EdgeInsets.symmetric(
        horizontal: kSpaceXl,
        vertical: kSpace2xl + kSpaceSm,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Padding(
          padding: kEdgeDialog,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _HeroIcon(icon: icon),
              const SizedBox(height: kSpaceXl),
              Text(
                title,
                textAlign: TextAlign.center,
                style: t.headingL,
              ),
              const SizedBox(height: kSpaceSm),
              Text(
                '"$objectName"',
                textAlign: TextAlign.center,
                style: t.bodyM.copyWith(
                  color: FincoreColors.textMuted,
                  fontStyle: FontStyle.italic,
                ),
              ),
              if (impacts.isNotEmpty) ...[
                const SizedBox(height: kSpaceXl),
                _ImpactList(impacts: impacts),
              ],
              const SizedBox(height: kSpaceXl),
              Text(
                description,
                style: t.bodyS.copyWith(
                  color: FincoreColors.textSubtle,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: kSpaceLg),
              const _IrreversibleBadge(),
              const SizedBox(height: kSpaceXl),
              _ActionRow(
                cancelLabel: cancelLabel,
                confirmLabel: confirmLabel,
                onCancel: () => Navigator.of(context).pop(false),
                onConfirm: () => Navigator.of(context).pop(true),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroIcon extends StatelessWidget {
  final IconData icon;
  const _HeroIcon({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        // token-exception: hero icon del DestructiveDialog, diámetro específico
        // calibrado para presencia visual (72dp) fuera de la escala de spacing.
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: FincoreColors.negative.withValues(alpha: FincoreColors.alphaHairline),
          border: Border.all(
            // token-exception: borde del hero icon, 0.3 calibrado para separar
            // el círculo del surface sin competir con el fill (alphaHairline).
            color: FincoreColors.negative.withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        alignment: Alignment.center,
        child: Icon(
          icon,
          size: 34,
          color: FincoreColors.negative,
        ),
      ),
    );
  }
}

class _ImpactList extends StatelessWidget {
  final List<DestructiveImpact> impacts;
  const _ImpactList({required this.impacts});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (int i = 0; i < impacts.length; i++) ...[
          if (i > 0) const SizedBox(height: kSpaceSm),
          _ImpactChip(impact: impacts[i]),
        ],
      ],
    );
  }
}

class _ImpactChip extends StatelessWidget {
  final DestructiveImpact impact;
  const _ImpactChip({required this.impact});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: kSpaceLg, vertical: kSpaceMd),
      decoration: BoxDecoration(
        color: FincoreColors.surfaceElevated,
        borderRadius: BorderRadius.circular(kRadiusLg),
        border: Border.all(color: FincoreColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: FincoreColors.negative.withValues(alpha: FincoreColors.alphaHairline),
              borderRadius: BorderRadius.circular(kRadiusMd),
            ),
            alignment: Alignment.center,
            child: Icon(
              impact.icon,
              size: 16,
              color: FincoreColors.negative,
            ),
          ),
          const SizedBox(width: kSpaceMd),
          Expanded(
            child: Text(
              impact.label,
              style: t.bodyS.copyWith(height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

class _IrreversibleBadge extends StatelessWidget {
  const _IrreversibleBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: kSpaceMd, vertical: kSpaceSm),
      decoration: BoxDecoration(
        color: FincoreColors.warning.withValues(alpha: FincoreColors.alphaHairline),
        borderRadius: BorderRadius.circular(kRadiusMd),
        // token-exception: borde de badge warning, 0.3 refuerza el contorno
        // sobre el fill tinted (alphaHairline) sin ser tan intenso como el body.
        border: Border.all(color: FincoreColors.warning.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            size: 16,
            color: FincoreColors.warning,
          ),
          const SizedBox(width: kSpaceSm),
          Expanded(
            child: Text(
              'Esta acción es definitiva y no se puede deshacer.',
              style: t.label.copyWith(
                color: FincoreColors.warning,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final String cancelLabel;
  final String confirmLabel;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  const _ActionRow({
    required this.cancelLabel,
    required this.confirmLabel,
    required this.onCancel,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    // Apilado vertical con destructivo arriba y cancel abajo. Full-width
    // en ambos: acomoda labels largos sin overflow, y sigue el patrón
    // móvil moderno (Material 3 / iOS bottom sheets) donde el CTA principal
    // queda cerca del pulgar.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton(
          onPressed: onConfirm,
          style: FilledButton.styleFrom(
            backgroundColor: FincoreColors.negative,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: kSpaceMd),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(kRadiusLg),
            ),
          ),
          child: Text(
            confirmLabel,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15, // token-exception: CTA destructivo, sin token entre bodyM (14) y headingM (16).
              fontWeight: FontWeight.w700,
              letterSpacing: 0.1,
            ),
          ),
        ),
        const SizedBox(height: kSpaceMd),
        OutlinedButton(
          onPressed: onCancel,
          style: OutlinedButton.styleFrom(
            foregroundColor: FincoreColors.textPrimary,
            side: const BorderSide(color: FincoreColors.border),
            padding: const EdgeInsets.symmetric(vertical: kSpaceMd),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(kRadiusLg),
            ),
          ),
          child: Text(
            cancelLabel,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15, // token-exception: pareado con el confirm CTA (mismo criterio).
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
