import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:fincore/data/database.dart';
import 'package:fincore/data/entries_filters.dart';
import 'package:fincore/data/uuid.dart';

part 'saved_views_dao.g.dart';

/// Errores tipados del `SavedViewsDao`. Cada `code` mapea a un mensaje
/// amigable en `lib/widgets/error_snackbar.dart`.
class SavedViewsDaoError implements Exception {
  final String code;
  final String message;
  const SavedViewsDaoError(this.code, this.message);

  @override
  String toString() => 'SavedViewsDaoError($code): $message';
}

/// Modelo inmutable de una vista guardada. Los `filters` se deserializan al
/// leer de BD (no se exponen como JSON string al caller).
class SavedView {
  final String id;
  final String name;
  final EntriesFilters filters;
  final DateTime createdAt;

  const SavedView({
    required this.id,
    required this.name,
    required this.filters,
    required this.createdAt,
  });
}

@DriftAccessor(tables: [SavedViews])
class SavedViewsDao extends DatabaseAccessor<FincoreDatabase>
    with _$SavedViewsDaoMixin {
  SavedViewsDao(super.db);

  /// Crea una vista nueva con name + filters. Retorna el id v7 generado.
  ///
  /// Validaciones (RN-V02 / RN-V03):
  /// - `name` trimmed entre 1 y 50 caracteres → `invalid_name`.
  /// - `name` único case-insensitive (LOWER comparison en BD) →
  ///   `duplicate_name`.
  Future<String> create({
    required String name,
    required EntriesFilters filters,
  }) async {
    final trimmedName = name.trim();
    _validateName(trimmedName);
    await _ensureNameAvailable(trimmedName, excludeId: null);
    final id = UuidV7.generate();
    final now = DateTime.now();
    await into(savedViews).insert(SavedViewsCompanion.insert(
      id: id,
      name: trimmedName,
      filtersJson: jsonEncode(filters.toSavedJson()),
      createdAt: now,
    ));
    return id;
  }

  /// Lista todas las vistas ordenadas por `created_at DESC` (RN-V07).
  Future<List<SavedView>> listAll() async {
    final rows = await (select(savedViews)
          ..orderBy([
            (t) => OrderingTerm(
                  expression: t.createdAt,
                  mode: OrderingMode.desc,
                ),
          ]))
        .get();
    return rows.map(_toModel).toList(growable: false);
  }

  /// Stream reactivo de la lista. Re-emite cuando hay insert/update/delete.
  Stream<List<SavedView>> watchAll() {
    return (select(savedViews)
          ..orderBy([
            (t) => OrderingTerm(
                  expression: t.createdAt,
                  mode: OrderingMode.desc,
                ),
          ]))
        .watch()
        .map((rows) => rows.map(_toModel).toList(growable: false));
  }

  /// Retorna la vista con id dado o null si no existe.
  Future<SavedView?> findById(String id) async {
    final row = await (select(savedViews)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _toModel(row);
  }

  /// Renombra una vista existente. Valida que el id existe y que el nuevo
  /// nombre no duplica (case-insensitive, excluyendo el propio id).
  Future<void> rename({
    required String id,
    required String name,
  }) async {
    final trimmedName = name.trim();
    _validateName(trimmedName);
    final existing = await findById(id);
    if (existing == null) {
      throw const SavedViewsDaoError(
          'not_found', 'Esa vista ya no existe.');
    }
    await _ensureNameAvailable(trimmedName, excludeId: id);
    await (update(savedViews)..where((t) => t.id.equals(id))).write(
      SavedViewsCompanion(name: Value(trimmedName)),
    );
  }

  /// Borrado físico de la vista. Lanza `not_found` si el id no existe.
  ///
  /// Nombre `removeById` (no `delete`) para no chocar con
  /// `DatabaseConnectionUser.delete` (statement builder de drift).
  Future<void> removeById({required String id}) async {
    final existing = await findById(id);
    if (existing == null) {
      throw const SavedViewsDaoError(
          'not_found', 'Esa vista ya no existe.');
    }
    await (delete(savedViews)..where((t) => t.id.equals(id))).go();
  }

  /// Borrado físico de TODAS las vistas. Usado por
  /// `BackupService.wipeAll()` para mantener coherencia con "arrancar
  /// limpio" (RN-V10).
  Future<void> removeAll() async {
    await delete(savedViews).go();
  }

  // -------------------------------------------------------------------------
  // helpers privados
  // -------------------------------------------------------------------------

  void _validateName(String trimmed) {
    if (trimmed.isEmpty || trimmed.length > 50) {
      throw const SavedViewsDaoError(
        'invalid_name',
        'El nombre no es válido. Probá con 1-50 caracteres.',
      );
    }
  }

  /// Verifica que `name` no exista (case-insensitive) en BD. Si
  /// `excludeId` no es null, excluye esa fila del check (útil para
  /// `rename`).
  Future<void> _ensureNameAvailable(
    String trimmedName, {
    required String? excludeId,
  }) async {
    final query =
        'SELECT id FROM saved_views WHERE LOWER(name) = LOWER(?) LIMIT 1';
    final rows = await customSelect(
      query,
      variables: [Variable.withString(trimmedName)],
      readsFrom: {savedViews},
    ).get();
    for (final row in rows) {
      final id = row.read<String>('id');
      if (id != excludeId) {
        throw const SavedViewsDaoError(
          'duplicate_name',
          'Ya existe una vista con ese nombre.',
        );
      }
    }
  }

  SavedView _toModel(SavedViewRow row) {
    return SavedView(
      id: row.id,
      name: row.name,
      filters: _deserialize(row.filtersJson),
      createdAt: row.createdAt,
    );
  }

  /// Deserialización tolerante. Si el JSON está corrupto, fallback a
  /// `EntriesFilters.thisMonth()` (RN-V04 + R-T05).
  EntriesFilters _deserialize(String json) {
    try {
      final decoded = jsonDecode(json);
      if (decoded is Map<String, dynamic>) {
        return EntriesFilters.fromSavedJson(decoded);
      }
      return EntriesFilters.thisMonth();
    } catch (_) {
      return EntriesFilters.thisMonth();
    }
  }
}

