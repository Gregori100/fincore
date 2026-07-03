import 'package:fincore/theme/fincore_colors.dart';
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _HeroIcon(icon: icon),
              const SizedBox(height: 20),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: FincoreColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '"$objectName"',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: FincoreColors.textMuted,
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                ),
              ),
              if (impacts.isNotEmpty) ...[
                const SizedBox(height: 20),
                _ImpactList(impacts: impacts),
              ],
              const SizedBox(height: 20),
              Text(
                description,
                style: const TextStyle(
                  color: FincoreColors.textSubtle,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              const _IrreversibleBadge(),
              const SizedBox(height: 24),
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
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: FincoreColors.negative.withValues(alpha: 0.12),
          border: Border.all(
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
          if (i > 0) const SizedBox(height: 8),
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: FincoreColors.surfaceElevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: FincoreColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: FincoreColors.negative.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Icon(
              impact.icon,
              size: 16,
              color: FincoreColors.negative,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              impact.label,
              style: const TextStyle(
                color: FincoreColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 1.35,
              ),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: FincoreColors.warning.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: FincoreColors.warning.withValues(alpha: 0.3)),
      ),
      child: const Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            size: 16,
            color: FincoreColors.warning,
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Esta acción es definitiva y no se puede deshacer.',
              style: TextStyle(
                color: FincoreColors.warning,
                fontSize: 12,
                fontWeight: FontWeight.w600,
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
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(
            confirmLabel,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.1,
            ),
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton(
          onPressed: onCancel,
          style: OutlinedButton.styleFrom(
            foregroundColor: FincoreColors.textPrimary,
            side: const BorderSide(color: FincoreColors.border),
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(
            cancelLabel,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
