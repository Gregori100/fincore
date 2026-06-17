import 'package:fincore/api/accounts_api.dart';
import 'package:fincore/api/api_client.dart';
import 'package:fincore/api/auth_api.dart';
import 'package:fincore/api/categories_api.dart';
import 'package:fincore/api/entries_api.dart';
import 'package:fincore/api/state_api.dart';
import 'package:fincore/app_dependencies.dart';
import 'package:fincore/router/app_router.dart';
import 'package:fincore/storage/token_storage.dart';
import 'package:fincore/theme/fincore_theme.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// URL del API del backend Laravel. Se inyecta SOLO en compile time vía
/// `--dart-define=FINCORE_API_URL=https://...`. Sin valor por defecto a propósito:
/// preferimos que el build falle en arranque a que conecte silenciosamente al
/// host viejo. Ver `mobile/scripts/run-linux.sh` y `mobile/scripts/build-apk.sh`.
const String kApiUrl = String.fromEnvironment('FINCORE_API_URL');

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (kApiUrl.isEmpty) {
    throw StateError(
      'FINCORE_API_URL no está definido. Reconstruye pasando '
      '--dart-define=FINCORE_API_URL=https://tu-backend.example.com',
    );
  }

  final tokenStorage = TokenStorage();
  final authState = AuthStateNotifier();

  final apiClient = ApiClient(
    baseUrl: '$kApiUrl/api',
    tokenStorage: tokenStorage,
    onUnauthorized: () async {
      await tokenStorage.clear();
      authState.value = const AuthSession(status: AuthStatus.anonymous);
    },
    onUnverified: () async {
      authState.value = authState.value.copyWith(status: AuthStatus.unverified);
    },
  );

  final authApi = AuthApi(apiClient);
  final stateApi = StateApi(apiClient);
  final accountsApi = AccountsApi(apiClient);
  final categoriesApi = CategoriesApi(apiClient);
  final entriesApi = EntriesApi(apiClient);

  final deps = AppDependencies(
    apiClient: apiClient,
    tokenStorage: tokenStorage,
    authState: authState,
    authApi: authApi,
    stateApi: stateApi,
    accountsApi: accountsApi,
    categoriesApi: categoriesApi,
    entriesApi: entriesApi,
    apiUrl: kApiUrl,
  );

  final router = buildAppRouter(authState: authState);

  // Boot async para detectar token previo (no bloquea el primer frame).
  unawaited(bootstrapAuthState(
    tokenStorage: tokenStorage,
    authApi: authApi,
    notifier: authState,
  ));

  runApp(FincoreApp(deps: deps, router: router));
}

/// Equivalente a `Future.unawaited` para evitar warning de lint cuando un
/// Future intencionalmente no se aguarda.
void unawaited(Future<void> future) {}

class FincoreApp extends StatelessWidget {
  final AppDependencies deps;
  final GoRouter router;

  const FincoreApp({super.key, required this.deps, required this.router});

  @override
  Widget build(BuildContext context) {
    return AppDependenciesProvider(
      deps: deps,
      child: MaterialApp.router(
        title: 'FinCore',
        debugShowCheckedModeBanner: false,
        theme: fincoreDarkTheme(),
        routerConfig: router,
      ),
    );
  }
}
