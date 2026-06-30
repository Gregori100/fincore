import 'package:fincore/theme/fincore_colors.dart';
import 'package:flutter/material.dart';

/// Pantalla fallback mostrada si el state de FirstRun llega null al router
/// (no debería ocurrir post-cambio de `main.dart` que awaitea antes de
/// `runApp`, pero la dejamos como defensa).
///
/// El render es visualmente idéntico al splash nativo Android (símbolo
/// centrado sobre canvas) para que si el router llega a pintar este frame
/// durante un edge case, el usuario no perciba transición distinta. Sin
/// wordmark ni spinner — esos creaban el efecto de "dos logos seguidos"
/// que reportó Diego.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: FincoreColors.canvas,
      body: Center(
        child: SizedBox(
          width: 120,
          height: 120,
          child: Image(
            image: AssetImage('assets/icon/foreground_1024.png'),
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}
