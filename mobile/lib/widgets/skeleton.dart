import 'package:fincore/theme/fincore_colors.dart';
import 'package:fincore/theme/fincore_motion.dart';
import 'package:fincore/theme/fincore_radii.dart';
import 'package:fincore/theme/fincore_spacing.dart';
import 'package:flutter/material.dart';

/// Rectángulo con pulse animado para placeholder mientras carga data.
/// Sin dependencias externas; un AnimationController interno cicla opacidad
/// entre 0.4 y 0.8 cada ~1.1s.
class Skeleton extends StatefulWidget {
  final double width;
  final double height;
  final double radius;

  const Skeleton({
    super.key,
    required this.width,
    required this.height,
    this.radius = kRadiusSm,
  });

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: kMotionPulse,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final t = Curves.easeInOut.transform(_ctrl.value);
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            // token-exception: valores intencionalmente fuera de escala para el efecto pulse
            color: FincoreColors.border.withValues(alpha: 0.4 + t * 0.4),
            borderRadius: BorderRadius.circular(widget.radius),
          ),
        );
      },
    );
  }
}

/// Card placeholder usado en la lista de cuentas y de movimientos mientras
/// el primer evento del stream no ha llegado.
class SkeletonCard extends StatelessWidget {
  const SkeletonCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: kSpaceMd,
        vertical: kSpaceMd,
      ),
      decoration: BoxDecoration(
        color: FincoreColors.surface,
        borderRadius: BorderRadius.circular(kRadiusMd),
        border: Border.all(color: FincoreColors.border),
      ),
      child: const Row(
        children: [
          Skeleton(width: 40, height: 40, radius: kRadiusMd),
          SizedBox(width: kSpaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Skeleton(width: 140, height: 14),
                SizedBox(height: kSpaceSm),
                Skeleton(width: 90, height: 11),
              ],
            ),
          ),
          SizedBox(width: kSpaceSm),
          Skeleton(width: 70, height: 16),
        ],
      ),
    );
  }
}
