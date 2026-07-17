// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'loans_dao.dart';

// ignore_for_file: type=lint
mixin _$LoansDaoMixin on DatabaseAccessor<FincoreDatabase> {
  $AccountsTable get accounts => attachedDatabase.accounts;
  $LoansTable get loans => attachedDatabase.loans;
  $CategoriesTable get categories => attachedDatabase.categories;
  $JournalEntriesTable get journalEntries => attachedDatabase.journalEntries;
  LoansDaoManager get managers => LoansDaoManager(this);
}

class LoansDaoManager {
  final _$LoansDaoMixin _db;
  LoansDaoManager(this._db);
  $$AccountsTableTableManager get accounts =>
      $$AccountsTableTableManager(_db.attachedDatabase, _db.accounts);
  $$LoansTableTableManager get loans =>
      $$LoansTableTableManager(_db.attachedDatabase, _db.loans);
  $$CategoriesTableTableManager get categories =>
      $$CategoriesTableTableManager(_db.attachedDatabase, _db.categories);
  $$JournalEntriesTableTableManager get journalEntries =>
      $$JournalEntriesTableTableManager(
        _db.attachedDatabase,
        _db.journalEntries,
      );
}
