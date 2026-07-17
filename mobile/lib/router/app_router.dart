import 'package:fincore/app_dependencies.dart';
import 'package:fincore/data/app_preferences_keys.dart';
import 'package:fincore/data/bootstrap.dart';
import 'package:fincore/screens/account_form_screen.dart';
import 'package:fincore/screens/accounts_list_screen.dart';
import 'package:fincore/screens/categories_list_screen.dart';
import 'package:fincore/screens/category_form_screen.dart';
import 'package:fincore/screens/dashboard_screen.dart';
import 'package:fincore/screens/entries_list_screen.dart';
import 'package:fincore/screens/entry_form_screen.dart';
import 'package:fincore/screens/first_run_screen.dart';
import 'package:fincore/screens/help_screen.dart';
import 'package:fincore/screens/loan_capital_payment_form.dart';
import 'package:fincore/screens/loan_detail_screen.dart';
import 'package:fincore/screens/loan_form_screen.dart';
import 'package:fincore/screens/loan_monthly_payment_form.dart';
import 'package:fincore/screens/loans_list_screen.dart';
import 'package:fincore/screens/onboarding_screen.dart';
import 'package:fincore/screens/reports_screen.dart';
import 'package:fincore/screens/settings_screen.dart';
import 'package:fincore/screens/weekly_budgets/calendar_screen.dart';
import 'package:fincore/screens/weekly_budgets/compare_screen.dart';
import 'package:fincore/screens/weekly_budgets/detail_screen.dart';
import 'package:fincore/screens/weekly_budgets/list_screen.dart';
import 'package:fincore/screens/splash_screen.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Notifica al router sobre el estado de arranque de la app.
/// Sprint `flutter-onboarding-for-testers-v1`: extendido con
/// `onboardingSeen` además del `hasBolsa` original.
///
/// Ambos arrancan en `null` (chequeo pendiente). El router redirige
/// según los 4 estados combinados:
/// - `hasBolsa=true`: usuario con datos → `/dashboard`.
/// - `hasBolsa=false && onboardingSeen=false`: tester nuevo → `/onboarding`.
/// - `hasBolsa=false && onboardingSeen=true`: ya vio el tour → `/first-run`.
/// - cualquiera `== null`: chequeo pendiente → `/splash`.
///
/// Backward compat: `value` retorna `hasBolsa` para que el código viejo
/// que escucha el listener siga funcionando (tests del harness).
class FirstRunState extends ChangeNotifier {
  bool? _hasBolsa;
  bool? _onboardingSeen;

  bool? get hasBolsa => _hasBolsa;
  bool? get onboardingSeen => _onboardingSeen;

  /// Backward compat: el `redirect` original consultaba `state.value`
  /// como `hasBolsa`. Tests existentes del harness también lo usan.
  bool? get value => _hasBolsa;

  /// Backward compat setter para tests/harness que hacían
  /// `firstRunState.value = true` para señalar "ya tiene Bolsa".
  set value(bool? v) {
    if (_hasBolsa != v) {
      _hasBolsa = v;
      notifyListeners();
    }
  }

  /// Setea ambos flags atómicamente y notifica una sola vez. Lo usa
  /// `initializeFirstRunState` tras el `Future.wait` paralelo.
  void setInitial({required bool hasBolsa, required bool onboardingSeen}) {
    _hasBolsa = hasBolsa;
    _onboardingSeen = onboardingSeen;
    notifyListeners();
  }

  void setHasBolsa(bool v) {
    if (_hasBolsa != v) {
      _hasBolsa = v;
      notifyListeners();
    }
  }

  void setOnboardingSeen(bool v) {
    if (_onboardingSeen != v) {
      _onboardingSeen = v;
      notifyListeners();
    }
  }
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
      final hasBolsa = firstRunState.hasBolsa;
      final onboardingSeen = firstRunState.onboardingSeen;
      final loc = state.matchedLocation;
      // Chequeo pendiente (cualquiera de los dos nulo): forzá splash.
      if (hasBolsa == null || onboardingSeen == null) {
        return loc == '/splash' ? null : '/splash';
      }
      // Tester nuevo sin onboarding visto: forzá `/onboarding` salvo si
      // ya está ahí.
      if (!hasBolsa && !onboardingSeen) {
        return loc == '/onboarding' ? null : '/onboarding';
      }
      // Usuario que ya vio onboarding pero sin Bolsa: forzá `/first-run`.
      if (!hasBolsa && onboardingSeen) {
        return loc == '/first-run' ? null : '/first-run';
      }
      // Usuario con Bolsa: cualquier `/splash`/`/onboarding`/`/first-run`
      // va a `/dashboard`. El resto de rutas se respeta.
      if (hasBolsa) {
        if (loc == '/splash' ||
            loc == '/onboarding' ||
            loc == '/first-run') {
          return '/dashboard';
        }
      }
      return null;
    },
    routes: <RouteBase>[
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(
        path: '/onboarding',
        builder: (_, __) => const OnboardingScreen(),
        routes: <RouteBase>[
          // Modo review: invocado desde HelpScreen para repasar el tour.
          // No persiste el flag de onboarding ni cambia el router state.
          GoRoute(
            path: 'review',
            builder: (_, __) =>
                const OnboardingScreen(repeatMode: true),
          ),
        ],
      ),
      GoRoute(path: '/first-run', builder: (_, __) => const FirstRunScreen()),
      GoRoute(path: '/dashboard', builder: (_, __) => const DashboardScreen()),
      GoRoute(path: '/help', builder: (_, __) => const HelpScreen()),
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
      // Sprint flutter-loans-v1: módulo de préstamos personales.
      GoRoute(
        path: '/loans',
        builder: (_, __) => const LoansListScreen(),
        routes: <RouteBase>[
          GoRoute(path: 'new', builder: (_, __) => const LoanFormScreen()),
          GoRoute(
            path: ':id',
            builder: (_, st) =>
                LoanDetailScreen(loanId: st.pathParameters['id']!),
            routes: <RouteBase>[
              GoRoute(
                path: 'edit',
                builder: (_, st) =>
                    LoanFormScreen(loanId: st.pathParameters['id']),
              ),
              GoRoute(
                path: 'payments/new/monthly',
                builder: (_, st) => LoanMonthlyPaymentForm(
                  loanId: st.pathParameters['id']!,
                ),
              ),
              GoRoute(
                path: 'payments/new/capital',
                builder: (_, st) => LoanCapitalPaymentForm(
                  loanId: st.pathParameters['id']!,
                ),
              ),
              // Hotfix smoke Diego: edición de pagos existentes.
              GoRoute(
                path: 'payments/:paymentId/edit/monthly',
                builder: (_, st) => LoanMonthlyPaymentForm(
                  loanId: st.pathParameters['id']!,
                  paymentId: st.pathParameters['paymentId'],
                ),
              ),
              GoRoute(
                path: 'payments/:paymentId/edit/capital',
                builder: (_, st) => LoanCapitalPaymentForm(
                  loanId: st.pathParameters['id']!,
                  paymentId: st.pathParameters['paymentId'],
                ),
              ),
            ],
          ),
        ],
      ),
      GoRoute(path: '/reports', builder: (_, __) => const ReportsScreen()),
      GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
      // Sprint flutter-weekly-budgets-v1: planeador semanal + plantillas.
      GoRoute(
        path: '/budgets',
        builder: (_, __) => const WeeklyBudgetsListScreen(),
        routes: <RouteBase>[
          GoRoute(
            path: 'calendar',
            builder: (_, __) => const BudgetCalendarScreen(),
          ),
          // Comparación side-by-side de 2 presupuestos de la misma semana.
          // Path estático de 3 segmentos ('compare/:a/:b'), sin ambigüedad
          // con ':id' (1 segmento) sin importar el orden de declaración.
          GoRoute(
            path: 'compare/:a/:b',
            builder: (_, st) => BudgetCompareScreen(
              budgetIdA: st.pathParameters['a']!,
              budgetIdB: st.pathParameters['b']!,
            ),
          ),
          GoRoute(
            path: ':id',
            builder: (_, st) =>
                WeeklyBudgetScreen(budgetId: st.pathParameters['id']!),
          ),
        ],
      ),
    ],
  );
}

/// Verifica al arrancar el estado de Bolsa y de onboarding visto.
/// Llamar una vez desde main(), antes de runApp, para que el redirect
/// inicial sepa a dónde mandar.
///
/// Sprint `flutter-onboarding-for-testers-v1`: extendido para cargar
/// `onboarding_seen` en paralelo con `hasBolsa`. Para Diego (con Bolsa)
/// el splash debe seguir siendo instantáneo — por eso ejecutamos las dos
/// consultas en paralelo con `Future.wait` y notificamos una sola vez
/// con `setInitial`, evitando "destellos" de transición.
Future<void> initializeFirstRunState({
  required AppDependencies deps,
  required FirstRunState state,
}) async {
  final results = await Future.wait([
    hasBolsa(deps.database),
    deps.appPreferencesDao.get(kPrefOnboardingSeen),
  ]);
  final bolsa = results[0] as bool;
  final seenRaw = results[1] as String?;
  state.setInitial(
    hasBolsa: bolsa,
    onboardingSeen: seenRaw == 'true',
  );
}

/// Llamado por first_run_screen tras "Arrancar limpio" o "Importar respaldo"
/// para notificar al router que ya hay Bolsa y debe ir a /dashboard.
void markFirstRunComplete(FirstRunState state) {
  state.value = true;
}
