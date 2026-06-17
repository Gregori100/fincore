import 'package:fincore/api/accounts_api.dart';
import 'package:fincore/api/api_client.dart';
import 'package:fincore/api/auth_api.dart';
import 'package:fincore/api/categories_api.dart';
import 'package:fincore/api/entries_api.dart';
import 'package:fincore/api/state_api.dart';
import 'package:fincore/router/app_router.dart';
import 'package:fincore/storage/token_storage.dart';
import 'package:flutter/widgets.dart';

/// Bag de servicios disponibles vía `AppDependencies.of(context)`.
/// Construidos una vez en `main.dart` y propagados por el InheritedWidget.
class AppDependencies {
  final ApiClient apiClient;
  final TokenStorage tokenStorage;
  final AuthStateNotifier authState;
  final AuthApi authApi;
  final StateApi stateApi;
  final AccountsApi accountsApi;
  final CategoriesApi categoriesApi;
  final EntriesApi entriesApi;
  final String apiUrl;

  const AppDependencies({
    required this.apiClient,
    required this.tokenStorage,
    required this.authState,
    required this.authApi,
    required this.stateApi,
    required this.accountsApi,
    required this.categoriesApi,
    required this.entriesApi,
    required this.apiUrl,
  });

  /// Atajo para acceder a las deps desde cualquier widget.
  static AppDependencies of(BuildContext context) =>
      AppDependenciesProvider.of(context);
}

class AppDependenciesProvider extends InheritedWidget {
  final AppDependencies deps;

  const AppDependenciesProvider({
    super.key,
    required this.deps,
    required super.child,
  });

  static AppDependencies of(BuildContext context) {
    final provider = context.dependOnInheritedWidgetOfExactType<AppDependenciesProvider>();
    assert(provider != null, 'AppDependenciesProvider no encontrado en el árbol.');
    return provider!.deps;
  }

  @override
  bool updateShouldNotify(AppDependenciesProvider oldWidget) => false;
}
