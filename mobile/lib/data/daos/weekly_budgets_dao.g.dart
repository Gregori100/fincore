// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'weekly_budgets_dao.dart';

// ignore_for_file: type=lint
mixin _$WeeklyBudgetsDaoMixin on DatabaseAccessor<FincoreDatabase> {
  $WeeklyBudgetsTable get weeklyBudgets => attachedDatabase.weeklyBudgets;
  $CategoriesTable get categories => attachedDatabase.categories;
  $WeeklyBudgetItemsTable get weeklyBudgetItems =>
      attachedDatabase.weeklyBudgetItems;
  WeeklyBudgetsDaoManager get managers => WeeklyBudgetsDaoManager(this);
}

class WeeklyBudgetsDaoManager {
  final _$WeeklyBudgetsDaoMixin _db;
  WeeklyBudgetsDaoManager(this._db);
  $$WeeklyBudgetsTableTableManager get weeklyBudgets =>
      $$WeeklyBudgetsTableTableManager(_db.attachedDatabase, _db.weeklyBudgets);
  $$CategoriesTableTableManager get categories =>
      $$CategoriesTableTableManager(_db.attachedDatabase, _db.categories);
  $$WeeklyBudgetItemsTableTableManager get weeklyBudgetItems =>
      $$WeeklyBudgetItemsTableTableManager(
        _db.attachedDatabase,
        _db.weeklyBudgetItems,
      );
}
