import 'package:fincore/app_dependencies.dart';
import 'package:fincore/data/app_preferences_keys.dart';
import 'package:fincore/router/app_router.dart';
import 'package:fincore/theme/fincore_colors.dart';
import 'package:fincore/widgets/fincore_logo.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Pantalla de onboarding mostrada a usuarios nuevos antes del first-run.
/// Sprint `flutter-onboarding-for-testers-v1`.
///
/// 3 slides en `PageView` horizontal:
/// 1. Wordmark + tagline.
/// 2. "Registrá cada movimiento" + lista de los 5 kinds.
/// 3. "Mirá tus reportes y patrones" + lista de los 5 tabs de /reports.
///
/// Botón "Saltar" en la AppBar (top-right) visible siempre. Botón
/// principal en el bottom: "Siguiente" en slides 1-2, "Empezar" en
/// slide 3. Dots tappeables para navegación directa.
///
/// Al saltar o completar, persiste `onboarding_seen = 'true'` y navega
/// a `/first-run` (caso normal: tester con BD vacía). Si por algún
/// motivo `hasBolsa = true`, va a `/dashboard` defensivamente.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _currentPage = 0;
  static const int _totalPages = 3;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding() async {
    final deps = AppDependencies.of(context);
    final state = FirstRunStateProvider.of(context);
    await deps.appPreferencesDao.set(kPrefOnboardingSeen, 'true');
    state.setOnboardingSeen(true);
    if (!mounted) return;
    // El refreshListenable del router va a re-evaluar el redirect
    // automáticamente. Como `setOnboardingSeen(true)` notifica, el router
    // empuja al destino correcto sin necesidad de un `context.go` manual.
    // Aún así llamamos `context.go` defensivamente para casos donde el
    // listener no dispare a tiempo (e.g. tests sin pumpAndSettle largo).
    final hasBolsa = state.hasBolsa ?? false;
    context.go(hasBolsa ? '/dashboard' : '/first-run');
  }

  void _next() {
    if (_currentPage == _totalPages - 1) {
      _completeOnboarding();
      return;
    }
    _controller.animateToPage(
      _currentPage + 1,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeInOut,
    );
  }

  void _jumpToDot(int index) {
    if (index == _currentPage) return;
    _controller.animateToPage(
      index,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _currentPage == _totalPages - 1;
    return Scaffold(
      backgroundColor: FincoreColors.canvas,
      appBar: AppBar(
        backgroundColor: FincoreColors.canvas,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _completeOnboarding,
            style: TextButton.styleFrom(
              foregroundColor: FincoreColors.textSubtle,
            ),
            child: const Text('Saltar'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (i) => setState(() => _currentPage = i),
                children: const [
                  _Slide1(),
                  _Slide2(),
                  _Slide3(),
                ],
              ),
            ),
            // Dots indicador.
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_totalPages, (i) {
                  final active = i == _currentPage;
                  return GestureDetector(
                    onTap: () => _jumpToDot(i),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: active ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: active
                            ? FincoreColors.accent
                            : FincoreColors.border,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  );
                }),
              ),
            ),
            // Botón principal.
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _next,
                  style: FilledButton.styleFrom(
                    backgroundColor: FincoreColors.accent,
                    foregroundColor: FincoreColors.canvas,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(isLast ? 'Empezar' : 'Siguiente'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Slide1 extends StatelessWidget {
  const _Slide1();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FincoreLogo(fontSize: 64, showTagline: true),
            SizedBox(height: 32),
            Text(
              'Una libreta digital privada para tus cuentas, gastos e '
              'ingresos. Todo en tu cel, sin servidores ni cuentas.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: FincoreColors.textSubtle,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Slide2 extends StatelessWidget {
  const _Slide2();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_circle_outline,
              color: FincoreColors.accent,
              size: 80,
            ),
            SizedBox(height: 24),
            Text(
              'Registrá cada movimiento',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: FincoreColors.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Ingresos, gastos, cargos a tarjeta, pagos de tarjeta y '
              'transferencias entre cuentas. Categorizá para entender '
              'a dónde se va tu plata.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: FincoreColors.textSubtle,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            SizedBox(height: 24),
            // F3 quality review v1: 5 filas explícitas para coincidir
            // con el texto del párrafo ("5 tipos") en lugar de fusionar
            // pago de tarjeta + transferencia.
            _KindRow(
              icon: Icons.trending_up,
              color: FincoreColors.positive,
              label: 'Ingreso',
            ),
            _KindRow(
              icon: Icons.trending_down,
              color: FincoreColors.negative,
              label: 'Gasto',
            ),
            _KindRow(
              icon: Icons.credit_card_outlined,
              color: FincoreColors.warning,
              label: 'Cargo a tarjeta',
            ),
            _KindRow(
              icon: Icons.payments_outlined,
              color: FincoreColors.positive,
              label: 'Pago de tarjeta',
            ),
            _KindRow(
              icon: Icons.swap_horiz_outlined,
              color: FincoreColors.accent,
              label: 'Transferencia',
            ),
          ],
        ),
      ),
    );
  }
}

class _Slide3 extends StatelessWidget {
  const _Slide3();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.insights_outlined,
              color: FincoreColors.accent,
              size: 80,
            ),
            SizedBox(height: 24),
            Text(
              'Mirá tus reportes y patrones',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: FincoreColors.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 16),
            Text(
              '5 reportes para entender tu plata: dónde gastás más, '
              'cómo fluye mes a mes, qué movimientos pesan, cuánto tenés '
              'a la fecha y cómo te ubicás vs tu promedio.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: FincoreColors.textSubtle,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            SizedBox(height: 24),
            // F3 quality review v1: 5 filas explícitas para coincidir
            // con el texto ("5 reportes") en lugar de fusionar saldo a
            // fecha + promedio mensual.
            _KindRow(
              icon: Icons.pie_chart_outline,
              color: FincoreColors.accent,
              label: 'Gasto por categoría',
            ),
            _KindRow(
              icon: Icons.show_chart,
              color: FincoreColors.positive,
              label: 'Cashflow mensual',
            ),
            _KindRow(
              icon: Icons.list_alt,
              color: FincoreColors.warning,
              label: 'Top movimientos',
            ),
            _KindRow(
              icon: Icons.calendar_today_outlined,
              color: FincoreColors.accent,
              label: 'Saldo a fecha',
            ),
            _KindRow(
              icon: Icons.insights_outlined,
              color: FincoreColors.positive,
              label: 'Promedio mensual',
            ),
          ],
        ),
      ),
    );
  }
}

class _KindRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;

  const _KindRow({
    required this.icon,
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: FincoreColors.textPrimary,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
