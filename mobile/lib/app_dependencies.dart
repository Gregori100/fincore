import 'package:fincore/data/backup.dart';
import 'package:fincore/data/daos/accounts_dao.dart';
import 'package:fincore/data/daos/categories_dao.dart';
import 'package:fincore/data/daos/entries_dao.dart';
import 'package:fincore/data/daos/saved_views_dao.dart';
import 'package:fincore/data/database.dart';
import 'package:fincore/data/financial_state.dart';
import 'package:fincore/data/reports.dart';
import 'package:flutter/widgets.dart';

/// Bag de servicios disponibles vía `AppDependencies.of(context)`.
/// Construidos una vez en `main.dart` y propagados por el InheritedWidget.
///
/// Versión local-first: sin apiClient, sin tokenStorage, sin authState,
/// sin auth*. Solo database + DAOs + StateService + BackupService + ReportsService.
class AppDependencies {
  final FincoreDatabase database;
  final AccountsDao accountsDao;
  final CategoriesDao categoriesDao;
  final EntriesDao entriesDao;
  final SavedViewsDao savedViewsDao;
  final FinancialStateService stateService;
  final BackupService backupService;
  final ReportsService reportsService;

  const AppDependencies({
    required this.database,
    required this.accountsDao,
    required this.categoriesDao,
    required this.entriesDao,
    required this.savedViewsDao,
    required this.stateService,
    required this.backupService,
    required this.reportsService,
  });

  /// Builder de conveniencia: construye toda la cadena de servicios desde una
  /// instancia de FincoreDatabase (que main.dart abre con drift_flutter,
  /// y los tests abren con NativeDatabase.memory()).
  factory AppDependencies.fromDatabase(FincoreDatabase database) {
    // M2 quality review v2 + RF-005 v4: los 3 DAOs vienen del codegen del
    // `@DriftDatabase(daos: [AccountsDao, CategoriesDao, EntriesDao])`. Evita
    // dobles instancias entre `attachedDatabase.xDao` y constructores
    // manuales. `EntriesDao` quedó incluido tras extraer
    // `accountBalanceAtomic` como función pura (RF-001 v4) y eliminar la
    // dependencia del DAO con `FinancialStateService`.
    final stateService = FinancialStateService(database);
    final accountsDao = database.accountsDao;
    final categoriesDao = database.categoriesDao;
    final entriesDao = database.entriesDao;
    final savedViewsDao = database.savedViewsDao;
    final backupService = BackupService(database, stateService);
    final reportsService = ReportsService(database);
    return AppDependencies(
      database: database,
      accountsDao: accountsDao,
      categoriesDao: categoriesDao,
      entriesDao: entriesDao,
      savedViewsDao: savedViewsDao,
      stateService: stateService,
      backupService: backupService,
      reportsService: reportsService,
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
