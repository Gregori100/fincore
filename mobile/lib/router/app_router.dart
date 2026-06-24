import 'package:fincore/app_dependencies.dart';
import 'package:fincore/data/bootstrap.dart';
import 'package:fincore/screens/account_form_screen.dart';
import 'package:fincore/screens/accounts_list_screen.dart';
import 'package:fincore/screens/categories_list_screen.dart';
import 'package:fincore/screens/category_form_screen.dart';
import 'package:fincore/screens/dashboard_screen.dart';
import 'package:fincore/screens/entries_list_screen.dart';
import 'package:fincore/screens/entry_form_screen.dart';
import 'package:fincore/screens/first_run_screen.dart';
import 'package:fincore/screens/reports_screen.dart';
import 'package:fincore/screens/settings_screen.dart';
import 'package:fincore/screens/splash_screen.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Notifica al router cuando el estado "BD tiene Bolsa" cambia (después de
/// seed o import). Sin esto, el redirect inicial queda colgado en /first-run.
class FirstRunState extends ValueNotifier<bool?> {
  FirstRunState() : super(null); // null = no chequeado todavía
}

/// Provider para exponer el FirstRunState desde el árbol de widgets.
/// Lo usa FirstRunScreen para notificar "complete" tras seed o import.
class FirstRunStateProvider extends InheritedWidget {
  final FirstRunState state;
  const FirstRunStateProvider({
    super.key,
    required this.state,
    required super.child,
  });

  static FirstRunState of(BuildContext context) {
    final provider =
        context.dependOnInheritedWidgetOfExactType<FirstRunStateProvider>();
    assert(provider != null, 'FirstRunStateProvider no encontrado en el árbol.');
    return provider!.state;
  }

  @override
  bool updateShouldNotify(FirstRunStateProvider oldWidget) =>
      state != oldWidget.state;
}

GoRouter buildAppRouter({
  required AppDependencies deps,
  required FirstRunState firstRunState,
}) {
  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: firstRunState,
    redirect: (context, state) {
      final hasBolsa = firstRunState.value;
      final loc = state.matchedLocation;
      if (hasBolsa == null) {
        // todavía chequeando: forzá la splash si el target no es ya la splash.
        return loc == '/splash' ? null : '/splash';
      }
      // Listo el chequeo: si seguimos en splash, redirigir según hasBolsa.
      if (loc == '/splash') return hasBolsa ? '/dashboard' : '/first-run';
      if (!hasBolsa && loc != '/first-run') return '/first-run';
      if (hasBolsa && loc == '/first-run') return '/dashboard';
      return null;
    },
    routes: <RouteBase>[
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/first-run', builder: (_, __) => const FirstRunScreen()),
      GoRoute(path: '/dashboard', builder: (_, __) => const DashboardScreen()),
      GoRoute(
        path: '/accounts',
        builder: (_, __) => const AccountsListScreen(),
        routes: <RouteBase>[
          GoRoute(path: 'new', builder: (_, __) => const AccountFormScreen()),
          GoRoute(
            path: ':id/edit',
            builder: (_, st) => AccountFormScreen(accountId: st.pathParameters['id']),
          ),
        ],
      ),
      GoRoute(
        path: '/categories',
        builder: (_, __) => const CategoriesListScreen(),
        routes: <RouteBase>[
          GoRoute(path: 'new', builder: (_, __) => const CategoryFormScreen()),
          GoRoute(
            path: ':id/edit',
            builder: (_, st) => CategoryFormScreen(categoryId: st.pathParameters['id']),
          ),
        ],
      ),
      GoRoute(
        path: '/entries',
        builder: (_, __) => const EntriesListScreen(),
        routes: <RouteBase>[
          GoRoute(path: 'new', builder: (_, __) => const EntryFormScreen()),
          GoRoute(
            path: ':id/edit',
            builder: (_, st) => EntryFormScreen(entryId: st.pathParameters['id']),
          ),
        ],
      ),
      GoRoute(path: '/reports', builder: (_, __) => const ReportsScreen()),
      GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
    ],
  );
}

/// Verifica al arrancar si la BD ya tiene Bolsa (seed corrido o import hecho).
/// Llamar una vez desde main(), antes de runApp, para que el redirect inicial
/// sepa a dónde mandar.
Future<void> initializeFirstRunState({
  required AppDependencies deps,
  required FirstRunState state,
}) async {
  final exists = await hasBolsa(deps.database);
  state.value = exists;
}

/// Llamado por first_run_screen tras "Arrancar limpio" o "Importar respaldo"
/// para notificar al router que ya hay Bolsa y debe ir a /dashboard.
void markFirstRunComplete(FirstRunState state) {
  state.value = true;
}
