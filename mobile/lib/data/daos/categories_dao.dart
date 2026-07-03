import 'package:drift/drift.dart';
import 'package:fincore/constants/category_catalog.dart';
import 'package:fincore/data/database.dart';
import 'package:fincore/data/uuid.dart';

part 'categories_dao.g.dart';

class CategoriesDaoError implements Exception {
  final String code;
  final String message;
  const CategoriesDaoError(this.code, this.message);

  @override
  String toString() => 'CategoriesDaoError($code): $message';
}

const _validAppliesTo = {'income', 'expense', 'both'};

@DriftAccessor(tables: [Categories])
class CategoriesDao extends DatabaseAccessor<FincoreDatabase>
    with _$CategoriesDaoMixin {
  CategoriesDao(super.db);

  Stream<List<Category>> watchActive({String? appliesTo}) {
    final query = select(categories)..where((c) => c.deletedAt.isNull());
    if (appliesTo != null) {
      query.where((c) => c.appliesTo.equals(appliesTo));
    }
    query.orderBy([(c) => OrderingTerm(expression: c.name)]);
    return query.watch();
  }

  Future<List<Category>> listAll({bool includeArchived = false}) {
    final query = select(categories);
    if (!includeArchived) query.where((c) => c.deletedAt.isNull());
    query.orderBy([(c) => OrderingTerm(expression: c.name)]);
    return query.get();
  }

  Future<Category?> findById(String id) {
    return (select(categories)..where((c) => c.id.equals(id))).getSingleOrNull();
  }

  /// Devuelve la categoría solo si está activa (no archivada). Helper canónico
  /// (RF-015) para validar antes de un write y para joins desde la UI que NO
  /// deben mostrar categorías fantasma. Documentado en CLAUDE.md bajo
  /// "Joins con categorías archivadas".
  Future<Category?> findActiveById(String id) {
    return (select(categories)
          ..where((c) => c.id.equals(id) & c.deletedAt.isNull()))
        .getSingleOrNull();
  }

  Future<String> create({
    required String name,
    required String appliesTo,
    required String colorSlug,
    required String iconSlug,
    double? monthlyLimit,
  }) async {
    _validateAppliesTo(appliesTo);
    _validateColorSlug(colorSlug);
    _validateIconSlug(iconSlug);
    _validateMonthlyLimit(appliesTo: appliesTo, monthlyLimit: monthlyLimit);
    await _validateNameUnique(name);

    final now = DateTime.now();
    final id = UuidV7.generate();
    await into(categories).insert(CategoriesCompanion.insert(
      id: id,
      name: name,
      appliesTo: appliesTo,
      colorSlug: colorSlug,
      iconSlug: iconSlug,
      monthlyLimit: Value(monthlyLimit),
      createdAt: now,
      updatedAt: now,
    ));
    return id;
  }

  /// Actualiza una categoría existente. Todos los parámetros son opcionales.
  ///
  /// Sprint flutter-budgets-v1: `monthlyLimit` acepta `Value<double?>` para
  /// distinguir 3 casos:
  ///   - `Value.absent()` (default): no modificar el campo.
  ///   - `Value(5000)`: setear a 5000.
  ///   - `Value(null)`: limpiar explícitamente (para cambio a `applies_to=income`).
  Future<void> updateCategory({
    required String id,
    String? name,
    String? appliesTo,
    String? colorSlug,
    String? iconSlug,
    Value<double?> monthlyLimit = const Value.absent(),
  }) async {
    final existing = await findById(id);
    if (existing == null) {
      throw const CategoriesDaoError('not_found', 'La categoría no existe.');
    }
    if (appliesTo != null) _validateAppliesTo(appliesTo);
    if (colorSlug != null) _validateColorSlug(colorSlug);
    if (iconSlug != null) _validateIconSlug(iconSlug);
    if (name != null && name != existing.name) {
      await _validateNameUnique(name, excludeId: id);
    }
    // Validar binomio applies_to + monthly_limit con el valor efectivo
    // post-update: si `monthlyLimit` es Value.absent() (no cambia), usamos
    // el existente; si viene explícito (present), usamos el nuevo (incluye
    // Value(null) que limpia).
    final effectiveMonthlyLimit =
        monthlyLimit.present ? monthlyLimit.value : existing.monthlyLimit;
    _validateMonthlyLimit(
      appliesTo: appliesTo ?? existing.appliesTo,
      monthlyLimit: effectiveMonthlyLimit,
    );

    await (update(categories)..where((c) => c.id.equals(id))).write(
      CategoriesCompanion(
        name: name != null ? Value(name) : const Value.absent(),
        appliesTo: appliesTo != null ? Value(appliesTo) : const Value.absent(),
        colorSlug: colorSlug != null ? Value(colorSlug) : const Value.absent(),
        iconSlug: iconSlug != null ? Value(iconSlug) : const Value.absent(),
        monthlyLimit: monthlyLimit,
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Archivar (soft delete). Los entries históricos conservan category_id pero
  /// la UI los muestra sin badge (porque las queries de listado filtran activos).
  Future<void> archive(String id) async {
    final existing = await findById(id);
    if (existing == null) {
      throw const CategoriesDaoError('not_found', 'La categoría no existe.');
    }
    await (update(categories)..where((c) => c.id.equals(id))).write(
      CategoriesCompanion(
        deletedAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> _validateNameUnique(String name, {String? excludeId}) async {
    final query = select(categories)
      ..where((c) => c.name.equals(name) & c.deletedAt.isNull());
    if (excludeId != null) {
      query.where((c) => c.id.equals(excludeId).not());
    }
    final existing = await query.getSingleOrNull();
    if (existing != null) {
      throw const CategoriesDaoError(
        'duplicate_category_name',
        'Ya tenés una categoría con ese nombre.',
      );
    }
  }

  void _validateAppliesTo(String value) {
    if (!_validAppliesTo.contains(value)) {
      throw const CategoriesDaoError(
        'invalid_category_applies_to',
        'El "aplica a" de la categoría es inválido.',
      );
    }
  }

  void _validateColorSlug(String slug) {
    final found = kCategoryColors.any((c) => c.slug == slug);
    if (!found) {
      throw const CategoriesDaoError(
        'invalid_color_slug',
        'El color seleccionado no está disponible.',
      );
    }
  }

  void _validateIconSlug(String slug) {
    final found = kCategoryIcons.any((i) => i.slug == slug);
    if (!found) {
      throw const CategoriesDaoError(
        'invalid_icon_slug',
        'El ícono seleccionado no está disponible.',
      );
    }
  }

  /// Sprint flutter-budgets-v1: `monthly_limit` es opcional pero cuando existe
  /// debe cumplir dos reglas: (1) no puede ser negativo (0 es válido, significa
  /// "meta de no gastar en esta categoría"); (2) no puede coexistir con
  /// `applies_to = 'income'` porque los presupuestos aplican solo a categorías
  /// que pueden recibir gastos.
  void _validateMonthlyLimit({
    required String appliesTo,
    required double? monthlyLimit,
  }) {
    if (monthlyLimit == null) return;
    if (monthlyLimit < 0) {
      throw const CategoriesDaoError(
        'invalid_monthly_limit',
        'El presupuesto mensual no puede ser negativo.',
      );
    }
    if (appliesTo == 'income') {
      throw const CategoriesDaoError(
        'invalid_monthly_limit_for_income',
        'Las categorías de tipo ingreso no pueden tener presupuesto.',
      );
    }
  }
}
