// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'saved_views_dao.dart';

// ignore_for_file: type=lint
mixin _$SavedViewsDaoMixin on DatabaseAccessor<FincoreDatabase> {
  $SavedViewsTable get savedViews => attachedDatabase.savedViews;
  SavedViewsDaoManager get managers => SavedViewsDaoManager(this);
}

class SavedViewsDaoManager {
  final _$SavedViewsDaoMixin _db;
  SavedViewsDaoManager(this._db);
  $$SavedViewsTableTableManager get savedViews =>
      $$SavedViewsTableTableManager(_db.attachedDatabase, _db.savedViews);
}
