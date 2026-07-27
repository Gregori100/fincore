import 'package:drift/drift.dart';
import 'package:fincore/data/database.dart';
import 'package:fincore/data/uuid.dart';
import 'package:intl/intl.dart';

part 'weekly_budgets_dao.g.dart';

const _validItemKinds = {'income', 'expense'};

/// Errores tipados del `WeeklyBudgetsDao`. Cada `code` mapea a un mensaje
/// amigable en `lib/widgets/error_snackbar.dart`.
class WeeklyBudgetsDaoError implements Exception {
  final String code;
  final String message;
  const WeeklyBudgetsDaoError(this.code, this.message);

  @override
  String toString() => 'WeeklyBudgetsDaoError($code): $message';
}

/// CRUD del presupuesto semanal (sin sus renglones — ver `WeeklyBudgetItemsDao`
/// para eso, T006). Hard delete: no hay `deleted_at` en `weekly_budgets`.
@DriftAccessor(tables: [WeeklyBudgets, WeeklyBudgetItems])
class WeeklyBudgetsDao extends DatabaseAccessor<FincoreDatabase>
    with _$WeeklyBudgetsDaoMixin {
  WeeklyBudgetsDao(super.db);

  /// Crea un presupuesto semanal. `weekStartDate` se normaliza a medianoche
  /// local (el rango cubierto es `[weekStartDate, weekStartDate + 7 días)`).
  /// Valida `label` no vacío/no whitespace-only, máx 60 caracteres
  /// (`invalid_budget_label`). Retorna el id v7 generado.
  Future<String> createBudget({
    required DateTime weekStartDate,
    required String label,
  }) async {
    _validateLabel(label);
    final normalizedWeekStart = DateTime(
      weekStartDate.year,
      weekStartDate.month,
      weekStartDate.day,
    );
    final now = DateTime.now();
    final id = UuidV7.generate();
    await into(weeklyBudgets).insert(WeeklyBudgetsCompanion.insert(
      id: id,
      weekStartDate: normalizedWeekStart,
      label: label,
      createdAt: now,
      updatedAt: now,
    ));
    return id;
  }

  /// Edita `label`. `weekStartDate` es inmutable post-create (RN-B09): pasar
  /// un valor no-null lanza `immutable_field`. Retorna las filas afectadas.
  Future<int> updateBudget(
    String id, {
    String? label,
    DateTime? weekStartDate,
  }) async {
    if (weekStartDate != null) {
      throw const WeeklyBudgetsDaoError(
        'immutable_field',
        'week_start_date no se puede editar',
      );
    }
    if (label != null) {
      _validateLabel(label);
    }
    return (update(weeklyBudgets)..where((b) => b.id.equals(id))).write(
      WeeklyBudgetsCompanion(
        label: label != null ? Value(label) : const Value.absent(),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Borrado físico del presupuesto y cascade aplicativa de sus renglones,
  /// dentro de una transacción. Lanza `not_found` si el id no existe.
  Future<void> deleteBudget(String id) async {
    await transaction(() async {
      await (delete(weeklyBudgetItems)
            ..where((i) => i.budgetId.equals(id)))
          .go();
      final deletedRows =
          await (delete(weeklyBudgets)..where((b) => b.id.equals(id))).go();
      if (deletedRows == 0) {
        throw const WeeklyBudgetsDaoError(
          'not_found',
          'El presupuesto no existe.',
        );
      }
    });
  }

  /// Retorna el presupuesto con `id` dado o `null` si no existe.
  Future<WeeklyBudgetRow?> findById(String id) {
    return (select(weeklyBudgets)..where((b) => b.id.equals(id)))
        .getSingleOrNull();
  }

  /// Stream reactivo de todos los presupuestos (hard delete: no hay filtro
  /// `deleted_at`).
  Stream<List<WeeklyBudgetRow>> watchAll() {
    return (select(weeklyBudgets)).watch();
  }

  void _validateLabel(String label) {
    if (label.trim().isEmpty || label.length > 60) {
      throw const WeeklyBudgetsDaoError(
        'invalid_budget_label',
        'El nombre del presupuesto debe tener entre 1 y 60 caracteres.',
      );
    }
  }

  // ===========================================================================
  // CRUD de budget items (T006)
  // ===========================================================================

  /// Agrega un renglón al presupuesto. Valida `name` 1..60 chars
  /// (`invalid_item_name`), `amount > 0` estricto (`invalid_item_amount`),
  /// `kind ∈ {income, expense}` (`invalid_kind`), `categoryId` activo si se
  /// provee (`invalid_category_reference`) y que el presupuesto exista
  /// (`not_found`). Asigna `sort_order` en bloques de 100: el primer item
  /// queda en 10, el siguiente en 110, etc.
  Future<String> addItem({
    required String budgetId,
    required String name,
    String? categoryId,
    required int amount,
    required String kind,
  }) async {
    final budget = await findById(budgetId);
    if (budget == null) {
      throw const WeeklyBudgetsDaoError(
        'not_found',
        'El presupuesto no existe.',
      );
    }
    _validateItemName(name);
    _validateItemAmount(amount);
    _validateKind(kind);
    if (categoryId != null) {
      await _validateCategoryActive(categoryId);
    }

    final now = DateTime.now();
    final id = UuidV7.generate();
    // Fix M2 (branch-quality-review flutter-weekly-budgets-v1): leer
    // max(sort_order) e insertar eran round-trips separados; un
    // doble-submit podía generar dos items con el mismo sort_order.
    // La transacción no cambia la firma pública ni el comportamiento salvo
    // atomicidad.
    await transaction(() async {
      final nextSortOrder = await _nextSortOrder(budgetId);
      await into(weeklyBudgetItems).insert(
        WeeklyBudgetItemsCompanion.insert(
          id: id,
          budgetId: budgetId,
          name: name,
          categoryId: Value(categoryId),
          amount: amount,
          kind: kind,
          sortOrder: nextSortOrder,
          createdAt: now,
          updatedAt: now,
        ),
      );
    });
    return id;
  }

  /// Edita un renglón existente. Todos los parámetros son opcionales salvo
  /// `itemId`. `categoryId` distingue "no cambiar" (omitido) de "desasignar
  /// explícitamente" vía `clearCategory: true` — mismo patrón que
  /// `EntriesDao.updateEntry`. Lanza `not_found` si el item no existe.
  Future<int> updateItem(
    String itemId, {
    String? name,
    String? categoryId,
    int? amount,
    String? kind,
    int? sortOrder,
    bool clearCategory = false,
  }) async {
    final existing = await (select(weeklyBudgetItems)
          ..where((i) => i.id.equals(itemId)))
        .getSingleOrNull();
    if (existing == null) {
      throw const WeeklyBudgetsDaoError(
        'not_found',
        'El renglón no existe.',
      );
    }
    if (name != null) _validateItemName(name);
    if (amount != null) _validateItemAmount(amount);
    if (kind != null) _validateKind(kind);
    // Fix M1 (branch-quality-review flutter-weekly-budgets-v1): si el
    // intent es desasignar (`clearCategory: true`), `categoryId` se ignora
    // sin validar — evita `invalid_category_reference` cuando el caller
    // manda ambos por accidente (ej: `categoryId` de una categoría ya
    // archivada junto con `clearCategory: true`).
    if (!clearCategory && categoryId != null) {
      await _validateCategoryActive(categoryId);
    }

    return (update(weeklyBudgetItems)..where((i) => i.id.equals(itemId)))
        .write(
      WeeklyBudgetItemsCompanion(
        name: name != null ? Value(name) : const Value.absent(),
        categoryId: clearCategory
            ? const Value(null)
            : (categoryId != null ? Value(categoryId) : const Value.absent()),
        amount: amount != null ? Value(amount) : const Value.absent(),
        kind: kind != null ? Value(kind) : const Value.absent(),
        sortOrder: sortOrder != null ? Value(sortOrder) : const Value.absent(),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Sprint flutter-budgets-item-completion-v1: invierte `is_done` del
  /// renglón. Lanza `not_found` si el id no existe. Devuelve el nuevo estado.
  /// Flag manual — no valida ni ejecuta efectos secundarios sobre entries.
  Future<bool> toggleItemDone(String itemId) async {
    final existing = await (select(weeklyBudgetItems)
          ..where((i) => i.id.equals(itemId)))
        .getSingleOrNull();
    if (existing == null) {
      throw const WeeklyBudgetsDaoError(
        'not_found',
        'El renglón no existe.',
      );
    }
    final next = !existing.isDone;
    await (update(weeklyBudgetItems)..where((i) => i.id.equals(itemId))).write(
      WeeklyBudgetItemsCompanion(
        isDone: Value(next),
        updatedAt: Value(DateTime.now()),
      ),
    );
    return next;
  }

  /// Borrado físico de un renglón del presupuesto. Lanza `not_found` si el id
  /// no existe.
  Future<void> deleteItem(String itemId) async {
    final deletedRows =
        await (delete(weeklyBudgetItems)..where((i) => i.id.equals(itemId)))
            .go();
    if (deletedRows == 0) {
      throw const WeeklyBudgetsDaoError(
        'not_found',
        'El renglón no existe.',
      );
    }
  }

  /// Renumera `sort_order` de todos los renglones de `budgetId` según su
  /// posición (índice) en `orderedItemIds`, en bloques de 100 (10, 110, 210,
  /// ...). Corre dentro de una transacción. Filtra defensivamente por
  /// `budgetId` para no reordenar items de otro presupuesto.
  Future<void> reorderItems(
    String budgetId,
    List<String> orderedItemIds,
  ) async {
    await transaction(() async {
      for (var index = 0; index < orderedItemIds.length; index++) {
        await (update(weeklyBudgetItems)
              ..where((i) =>
                  i.id.equals(orderedItemIds[index]) &
                  i.budgetId.equals(budgetId)))
            .write(
          WeeklyBudgetItemsCompanion(
            sortOrder: Value((index + 1) * 100 - 90),
            updatedAt: Value(DateTime.now()),
          ),
        );
      }
    });
  }

  /// Renglones de un presupuesto, ordenados por `sort_order` ascendente.
  Stream<List<WeeklyBudgetItemRow>> watchBudgetItems(String budgetId) {
    return (select(weeklyBudgetItems)
          ..where((i) => i.budgetId.equals(budgetId))
          ..orderBy([(i) => OrderingTerm(expression: i.sortOrder)]))
        .watch();
  }

  // ===========================================================================
  // Balance reactivo (T007)
  // ===========================================================================

  /// Balance del presupuesto: Σ ingresos − Σ gastos de sus renglones. Stream
  /// reactivo cacheado por drift (se invalida solo cuando cambia
  /// `weekly_budget_items`).
  Stream<int> watchBudgetBalance(String budgetId) {
    const sql = '''
SELECT COALESCE(SUM(CASE WHEN kind = 'income' THEN amount ELSE 0 END), 0)
     - COALESCE(SUM(CASE WHEN kind = 'expense' THEN amount ELSE 0 END), 0)
       AS balance
FROM weekly_budget_items
WHERE budget_id = ?
''';
    return customSelect(
      sql,
      variables: [Variable.withString(budgetId)],
      readsFrom: {weeklyBudgetItems},
    ).watchSingle().map((row) => row.read<int>('balance'));
  }

  // ===========================================================================
  // Plantillas — refactor 2026-07-14 (flutter-weekly-budgets-v1)
  // ===========================================================================
  // El concepto de "plantilla" dejó de ser una entidad separada
  // (`budget_templates` + `budget_template_items`, ambas eliminadas) y ahora
  // es un flag boolean (`is_template`) sobre el propio `WeeklyBudgetRow`. Un
  // budget marcado como plantilla convive con el resto en el listado normal
  // y, además, puede usarse como origen de `createBudgetFromTemplate`.

  /// Invierte `is_template` del budget con `id` dado. Lanza `not_found` si
  /// no existe. Retorna las filas afectadas (siempre 1 si no lanza).
  Future<int> toggleTemplateFlag(String id) async {
    final budget = await findById(id);
    if (budget == null) {
      throw const WeeklyBudgetsDaoError(
        'not_found',
        'El presupuesto no existe.',
      );
    }
    return (update(weeklyBudgets)..where((b) => b.id.equals(id))).write(
      WeeklyBudgetsCompanion(
        isTemplate: Value(!budget.isTemplate),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Stream reactivo de los budgets marcados como plantilla
  /// (`is_template = true`), ordenados por `week_start_date` descendente
  /// (más recientes primero) — alimenta el selector "Desde plantilla".
  Stream<List<WeeklyBudgetRow>> watchTemplates() {
    return (select(weeklyBudgets)
          ..where((b) => b.isTemplate.equals(true))
          ..orderBy([
            (b) => OrderingTerm(
                  expression: b.weekStartDate,
                  mode: OrderingMode.desc,
                ),
          ]))
        .watch();
  }

  /// Genera un label automático para un presupuesto nuevo, formato
  /// "Semana del D mmm" (ej: "Semana del 17 jul"). Si ya existe un budget
  /// con ese label exacto (case-sensitive), agrega un sufijo `(2)`, `(3)`,
  /// ... hasta encontrar uno libre. No crea el budget — solo calcula el
  /// nombre final.
  Future<String> generateAutoLabel(DateTime weekStartDate) async {
    final formatted = DateFormat('d MMM', 'es_MX').format(weekStartDate);
    final baseLabel = 'Semana del $formatted';
    var candidate = baseLabel;
    var suffix = 2;
    while (await _labelExists(candidate)) {
      candidate = '$baseLabel ($suffix)';
      suffix++;
    }
    return candidate;
  }

  Future<bool> _labelExists(String label) async {
    final existing = await (select(weeklyBudgets)
          ..where((b) => b.label.equals(label)))
        .getSingleOrNull();
    return existing != null;
  }

  // ===========================================================================
  // Snapshot copier — crear budget desde plantilla (T009)
  // ===========================================================================

  /// Crea un presupuesto nuevo copiando los renglones de otro budget marcado
  /// como plantilla (`templateId`, un `WeeklyBudgetRow.id` con
  /// `is_template = true`). Snapshot: los items copiados tienen NUEVOS ids
  /// v7, sin compartir referencia con los de la plantilla (RN-B15/B16) —
  /// editar la plantilla después no afecta este presupuesto. Lanza
  /// `not_found` si `templateId` no existe o no es plantilla. El budget
  /// nuevo se crea con `isTemplate = false` explícito.
  Future<String> createBudgetFromTemplate({
    required DateTime weekStartDate,
    required String label,
    required String templateId,
  }) async {
    _validateLabel(label);
    final template = await findById(templateId);
    if (template == null || !template.isTemplate) {
      throw const WeeklyBudgetsDaoError(
        'not_found',
        'La plantilla no existe.',
      );
    }

    final normalizedWeekStart = DateTime(
      weekStartDate.year,
      weekStartDate.month,
      weekStartDate.day,
    );

    return transaction(() async {
      final now = DateTime.now();
      final budgetId = UuidV7.generate();
      await into(weeklyBudgets).insert(WeeklyBudgetsCompanion.insert(
        id: budgetId,
        weekStartDate: normalizedWeekStart,
        label: label,
        isTemplate: const Value(false),
        createdAt: now,
        updatedAt: now,
      ));

      final templateItems = await (select(weeklyBudgetItems)
            ..where((i) => i.budgetId.equals(templateId))
            ..orderBy([(i) => OrderingTerm(expression: i.sortOrder)]))
          .get();

      for (final item in templateItems) {
        final itemNow = DateTime.now();
        // Sprint flutter-budgets-item-completion-v1: `is_done` NO se propaga
        // desde la plantilla. Los items del clon arrancan en `false` (default
        // de la columna). Un presupuesto duplicado representa una semana
        // nueva: nada se ha "cumplido" aún.
        await into(weeklyBudgetItems).insert(WeeklyBudgetItemsCompanion.insert(
          id: UuidV7.generate(),
          budgetId: budgetId,
          name: item.name,
          categoryId: Value(item.categoryId),
          amount: item.amount,
          kind: item.kind,
          sortOrder: item.sortOrder,
          createdAt: itemNow,
          updatedAt: itemNow,
        ));
      }

      return budgetId;
    });
  }

  // ===========================================================================
  // Helpers privados
  // ===========================================================================

  Future<int> _nextSortOrder(String budgetId) async {
    final query = selectOnly(weeklyBudgetItems)
      ..addColumns([weeklyBudgetItems.sortOrder.max()])
      ..where(weeklyBudgetItems.budgetId.equals(budgetId));
    final row = await query.getSingle();
    final maxSortOrder = row.read(weeklyBudgetItems.sortOrder.max());
    return (maxSortOrder ?? -90) + 100;
  }

  Future<void> _validateCategoryActive(String categoryId) async {
    final active =
        await attachedDatabase.categoriesDao.findActiveById(categoryId);
    if (active == null) {
      throw const WeeklyBudgetsDaoError(
        'invalid_category_reference',
        'La categoría seleccionada no existe o está archivada.',
      );
    }
  }

  void _validateItemName(String name) {
    if (name.trim().isEmpty || name.length > 60) {
      throw const WeeklyBudgetsDaoError(
        'invalid_item_name',
        'El nombre del renglón debe tener entre 1 y 60 caracteres.',
      );
    }
  }

  void _validateItemAmount(int amount) {
    // Fix A3 (branch-quality-review flutter-weekly-budgets-v1): `amount <= 0`
    // por sí solo evalúa a `false` para NaN e Infinity, dejándolos pasar.
    // `isFinite` cubre NaN, +Infinity y -Infinity en un solo check.
    if (!amount.isFinite || amount <= 0) {
      throw const WeeklyBudgetsDaoError(
        'invalid_item_amount',
        'El monto debe ser mayor a 0.',
      );
    }
  }

  void _validateKind(String kind) {
    if (!_validItemKinds.contains(kind)) {
      throw const WeeklyBudgetsDaoError(
        'invalid_kind',
        'El tipo de renglón debe ser ingreso o gasto.',
      );
    }
  }
}
