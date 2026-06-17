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
import 'package:mocktail/mocktail.dart';

// Mocks reusables para widget tests.
class MockAuthApi extends Mock implements AuthApi {}
class MockStateApi extends Mock implements StateApi {}
class MockAccountsApi extends Mock implements AccountsApi {}
class MockCategoriesApi extends Mock implements CategoriesApi {}
class MockEntriesApi extends Mock implements EntriesApi {}
class MockTokenStorage extends Mock implements TokenStorage {}
class MockApiClient extends Mock implements ApiClient {}

/// Builder que monta una pantalla dentro de un MaterialApp con tema FinCore y
/// un AppDependenciesProvider con todos los mocks. Las pantallas que dependan
/// de navegación de go_router pueden necesitar wrap adicional según el test.
Widget testApp({
  required Widget child,
  AuthApi? authApi,
  StateApi? stateApi,
  AccountsApi? accountsApi,
  CategoriesApi? categoriesApi,
  EntriesApi? entriesApi,
  TokenStorage? tokenStorage,
  AuthStateNotifier? authState,
  String apiUrl = 'https://test.example/api',
}) {
  final deps = AppDependencies(
    apiClient: MockApiClient(),
    tokenStorage: tokenStorage ?? MockTokenStorage(),
    authState: authState ?? AuthStateNotifier(),
    authApi: authApi ?? MockAuthApi(),
    stateApi: stateApi ?? MockStateApi(),
    accountsApi: accountsApi ?? MockAccountsApi(),
    categoriesApi: categoriesApi ?? MockCategoriesApi(),
    entriesApi: entriesApi ?? MockEntriesApi(),
    apiUrl: apiUrl,
  );
  return AppDependenciesProvider(
    deps: deps,
    child: MaterialApp(
      theme: fincoreDarkTheme(),
      home: child,
    ),
  );
}
