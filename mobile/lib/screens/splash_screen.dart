import 'package:fincore/theme/fincore_colors.dart';
import 'package:fincore/widgets/fincore_logo.dart';
import 'package:flutter/material.dart';

/// Pantalla mostrada mientras se detecta si la BD tiene Bolsa (decide entre
/// /first-run y /dashboard). El router redirige automáticamente cuando termina.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: FincoreColors.canvas,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FincoreLogo(fontSize: 64),
            SizedBox(height: 48),
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: FincoreColors.accent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
