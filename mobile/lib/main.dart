import 'package:fincore/app_dependencies.dart';
import 'package:fincore/data/database.dart';
import 'package:fincore/router/app_router.dart';
import 'package:fincore/theme/fincore_colors.dart';
import 'package:fincore/theme/fincore_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Pinta status bar y navigation bar del sistema con el canvas de la app
  // para que no aparezca el gris default de Android sobre el fondo oscuro.
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: FincoreColors.canvas,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: FincoreColors.canvas,
    systemNavigationBarIconBrightness: Brightness.light,
    systemNavigationBarDividerColor: FincoreColors.canvas,
  ));

  // Inicializa los símbolos de fecha del locale es_MX antes de cualquier
  // DateFormat('...', 'es_MX'). Si se omite, las pantallas que formatean
  // fechas crashean silenciosamente en release y se ven en blanco.
  await initializeDateFormatting('es_MX', null);

  final database = FincoreDatabase();
  final deps = AppDependencies.fromDatabase(database);
  final firstRunState = FirstRunState();
  final router = buildAppRouter(deps: deps, firstRunState: firstRunState);

  // Detecta si la BD ya tiene Bolsa para decidir el redirect inicial.
  // Async sin bloquear: el router muestra splash mientras tanto.
  unawaited(initializeFirstRunState(deps: deps, state: firstRunState));

  runApp(FincoreApp(deps: deps, router: router, firstRunState: firstRunState));
}

/// Marca un Future como intencionalmente sin esperar.
void unawaited(Future<void> future) {}

class FincoreApp extends StatelessWidget {
  final AppDependencies deps;
  final GoRouter router;
  final FirstRunState firstRunState;

  const FincoreApp({
    super.key,
    required this.deps,
    required this.router,
    required this.firstRunState,
  });

  @override
  Widget build(BuildContext context) {
    return AppDependenciesProvider(
      deps: deps,
      child: FirstRunStateProvider(
        state: firstRunState,
        child: MaterialApp.router(
          title: 'FinCore',
          debugShowCheckedModeBanner: false,
          theme: fincoreDarkTheme(),
          routerConfig: router,
        ),
      ),
    );
  }
}
