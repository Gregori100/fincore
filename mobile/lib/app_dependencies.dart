import 'package:fincore/data/backup.dart';
import 'package:fincore/data/daos/accounts_dao.dart';
import 'package:fincore/data/daos/categories_dao.dart';
import 'package:fincore/data/daos/entries_dao.dart';
import 'package:fincore/data/database.dart';
import 'package:fincore/data/financial_state.dart';
import 'package:flutter/widgets.dart';

/// Bag de servicios disponibles vía `AppDependencies.of(context)`.
/// Construidos una vez en `main.dart` y propagados por el InheritedWidget.
///
/// Versión local-first: sin apiClient, sin tokenStorage, sin authState,
/// sin auth*. Solo database + DAOs + StateService + BackupService.
class AppDependencies {
  final FincoreDatabase database;
  final AccountsDao accountsDao;
  final CategoriesDao categoriesDao;
  final EntriesDao entriesDao;
  final FinancialStateService stateService;
  final BackupService backupService;

  const AppDependencies({
    required this.database,
    required this.accountsDao,
    required this.categoriesDao,
    required this.entriesDao,
    required this.stateService,
    required this.backupService,
  });

  /// Builder de conveniencia: construye toda la cadena de servicios desde una
  /// instancia de FincoreDatabase (que main.dart abre con drift_flutter,
  /// y los tests abren con NativeDatabase.memory()).
  factory AppDependencies.fromDatabase(FincoreDatabase database) {
    // M2 del quality review v2 (2026-06-19): usar las instancias del codegen
    // (`database.accountsDao` / `database.categoriesDao`) que vienen del
    // `@DriftDatabase(daos: [AccountsDao, CategoriesDao])`, en vez de
    // instanciar manualmente. Evita que existan dos instancias paralelas
    // del mismo DAO (una desde acá y otra desde `attachedDatabase`).
    // `EntriesDao` queda manual porque su constructor requiere
    // `FinancialStateService` y drift codegen no sabe construirlo.
    final stateService = FinancialStateService(database);
    final accountsDao = database.accountsDao;
    final categoriesDao = database.categoriesDao;
    final entriesDao = EntriesDao(database, stateService);
    final backupService = BackupService(database, stateService);
    return AppDependencies(
      database: database,
      accountsDao: accountsDao,
      categoriesDao: categoriesDao,
      entriesDao: entriesDao,
      stateService: stateService,
      backupService: backupService,
    );
  }

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
    final provider =
        context.dependOnInheritedWidgetOfExactType<AppDependenciesProvider>();
    assert(provider != null, 'AppDependenciesProvider no encontrado en el árbol.');
    return provider!.deps;
  }

  @override
  bool updateShouldNotify(AppDependenciesProvider oldWidget) => false;
}
