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
///
/// Modo `repeatMode = true` (ruta `/onboarding/review`): se invoca desde
/// HelpScreen para revisar el tour de nuevo. NO persiste el flag, NO
/// modifica `FirstRunState` y al terminar/saltar solo hace `pop()` para
/// volver al caller. El AppBar muestra back arrow para que el usuario
/// pueda salir en cualquier momento.
class OnboardingScreen extends StatefulWidget {
  final bool repeatMode;

  const OnboardingScreen({super.key, this.repeatMode = false});

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
    // Modo review desde HelpScreen: no persistimos flag ni cambiamos el
    // router state — el usuario ya completó el onboarding original y
    // está repasando. Solo cerramos la pantalla.
    if (widget.repeatMode) {
      if (!mounted) return;
      Navigator.of(context).maybePop();
      return;
    }
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
        // En modo review (desde HelpScreen) mostramos back arrow para
        // poder volver con un tap. En modo inicial NO hay back: el
        // usuario debe completar o saltar explícitamente.
        leading: widget.repeatMode
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).maybePop(),
              )
            : null,
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            onPressed: _completeOnboarding,
            style: TextButton.styleFrom(
              foregroundColor: FincoreColors.textSubtle,
            ),
            child: Text(widget.repeatMode ? 'Cerrar' : 'Saltar'),
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
                  child: Text(
                    isLast
                        ? (widget.repeatMode ? 'Listo' : 'Empezar')
                        : 'Siguiente',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Slide 1 con animación de entrada en 3 etapas que se solapan:
///   - 0-450ms: símbolo (fade + scale 0.7 → 1.0)
///   - 300-700ms: wordmark "Fin Core" (slide up 24px + fade)
///   - 600-900ms: párrafo descriptivo (fade)
///
/// La animación se dispara en `initState` cada vez que el slide se
/// monta. PageView lo re-monta al volver de slides 2/3, así que el
/// usuario ve la animación cada vez que entra — refuerza identidad
/// y no es molesto porque dura <1s.
class _Slide1 extends StatefulWidget {
  const _Slide1();

  @override
  State<_Slide1> createState() => _Slide1State();
}

class _Slide1State extends State<_Slide1>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _symbolOpacity;
  late final Animation<double> _symbolScale;
  late final Animation<double> _wordmarkOpacity;
  late final Animation<Offset> _wordmarkOffset;
  late final Animation<double> _textOpacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _symbolOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
    );
    _symbolScale = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOutBack),
      ),
    );

    _wordmarkOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.33, 0.78, curve: Curves.easeOut),
    );
    _wordmarkOffset = Tween<Offset>(
      begin: const Offset(0, 0.4),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.33, 0.78, curve: Curves.easeOut),
      ),
    );

    _textOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.66, 1.0, curve: Curves.easeOut),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FadeTransition(
              opacity: _symbolOpacity,
              child: ScaleTransition(
                scale: _symbolScale,
                child: const SizedBox(
                  width: 120,
                  height: 120,
                  child: Image(
                    image: AssetImage('assets/icon/foreground_1024.png'),
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            FadeTransition(
              opacity: _wordmarkOpacity,
              child: SlideTransition(
                position: _wordmarkOffset,
                child: const FincoreLogo(fontSize: 56, showTagline: true),
              ),
            ),
            const SizedBox(height: 32),
            FadeTransition(
              opacity: _textOpacity,
              child: const Text(
                'Una libreta digital privada para tus cuentas, gastos e '
                'ingresos. Todo en tu celular, sin servidores ni cuentas.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: FincoreColors.textSubtle,
                  fontSize: 14,
                  height: 1.5,
                ),
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
              'Registrar cada movimiento',
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
              'transferencias entre cuentas. Categorizar cada uno para '
              'entender a dónde se va el dinero.',
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
    // Patrón `LayoutBuilder + ConstrainedBox + IntrinsicHeight` para
    // permitir scroll cuando el contenido excede la altura disponible
    // (7 reportes = mucho contenido en pantallas chicas), preservando
    // el centrado vertical cuando sí cabe. Sprint flutter-budgets-v1.
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight - 48, // resta padding vertical
            ),
            child: const IntrinsicHeight(
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
              'Ver reportes y patrones',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: FincoreColors.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 16),
            Text(
              '10 reportes para entender el dinero: en qué se gasta más, '
              'de dónde viene cada peso, cómo fluye mes a mes, qué '
              'movimientos pesan, cuánto hay a la fecha, la comparación '
              'contra el promedio, el estado de las tarjetas, el '
              'progreso de los presupuestos, el calendario del mes y '
              'el heatmap anual de gastos.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: FincoreColors.textSubtle,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            SizedBox(height: 24),
            // Filas explícitas para coincidir con "6 reportes" del párrafo.
            // Se actualizó en el sprint flutter-reports-credit-cards-v1
            // con la nueva fila "Estado de tarjetas".
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
            _KindRow(
              icon: Icons.credit_card_outlined,
              color: FincoreColors.warning,
              label: 'Estado de tarjetas',
            ),
            _KindRow(
              icon: Icons.savings_outlined,
              color: FincoreColors.positive,
              label: 'Presupuestos',
            ),
            _KindRow(
              icon: Icons.trending_up,
              color: FincoreColors.positive,
              label: 'Ingreso por categoría',
            ),
            _KindRow(
              icon: Icons.calendar_month,
              color: FincoreColors.accent,
              label: 'Calendario',
            ),
            _KindRow(
              icon: Icons.grid_view,
              color: FincoreColors.negative,
              label: 'Heatmap anual',
            ),
                ],
              ),
            ),
          ),
        );
      },
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
