import 'package:fincore/api/auth_api.dart';
import 'package:fincore/models/user.dart';
import 'package:fincore/screens/account_form_screen.dart';
import 'package:fincore/screens/accounts_list_screen.dart';
import 'package:fincore/screens/categories_list_screen.dart';
import 'package:fincore/screens/category_form_screen.dart';
import 'package:fincore/screens/dashboard_screen.dart';
import 'package:fincore/screens/entries_list_screen.dart';
import 'package:fincore/screens/entry_form_screen.dart';
import 'package:fincore/screens/settings_screen.dart';
import 'package:fincore/screens/login_screen.dart';
import 'package:fincore/screens/verify_email_screen.dart';
import 'package:fincore/storage/token_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

/// Estado de sesión. El router se suscribe a esto vía `refreshListenable` y
/// reevalúa los redirects cuando cambia.
enum AuthStatus { unknown, authenticated, unverified, anonymous }

class AuthSession {
  final AuthStatus status;
  final User? user;
  const AuthSession({required this.status, this.user});

  AuthSession copyWith({AuthStatus? status, User? user, bool clearUser = false}) {
    return AuthSession(
      status: status ?? this.status,
      user: clearUser ? null : (user ?? this.user),
    );
  }
}

class AuthStateNotifier extends ValueNotifier<AuthSession> {
  AuthStateNotifier() : super(const AuthSession(status: AuthStatus.unknown));

  AuthStatus get status => value.status;
  User? get user => value.user;
}

GoRouter buildAppRouter({required AuthStateNotifier authState}) {
  return GoRouter(
    initialLocation: '/dashboard',
    refreshListenable: authState,
    redirect: (context, state) {
      final loc = state.matchedLocation;
      final status = authState.status;

      // Estado desconocido aún (boot): no redirigir.
      if (status == AuthStatus.unknown) return null;

      final isAuthRoute = loc == '/login' || loc == '/verify-email';

      if (status == AuthStatus.anonymous) {
        return isAuthRoute ? null : '/login';
      }
      if (status == AuthStatus.unverified) {
        return loc == '/verify-email' ? null : '/verify-email';
      }
      // authenticated
      if (isAuthRoute) return '/dashboard';
      return null;
    },
    routes: <RouteBase>[
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/verify-email', builder: (_, __) => const VerifyEmailScreen()),
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
      GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
    ],
  );
}

/// Resuelve el estado de sesión inicial leyendo el token + me() si existe.
/// Llamado una vez al arrancar la app desde main().
Future<void> bootstrapAuthState({
  required TokenStorage tokenStorage,
  required AuthApi authApi,
  required AuthStateNotifier notifier,
}) async {
  final token = await tokenStorage.read();
  if (token == null || token.isEmpty) {
    notifier.value = const AuthSession(status: AuthStatus.anonymous);
    return;
  }
  try {
    final user = await authApi.me();
    notifier.value = AuthSession(
      status: user.isVerified ? AuthStatus.authenticated : AuthStatus.unverified,
      user: user,
    );
  } catch (e) {
    if (kDebugMode) {
      debugPrint('bootstrapAuthState: me() falló, asumimos sesión inválida — $e');
    }
    notifier.value = const AuthSession(status: AuthStatus.anonymous);
  }
}
