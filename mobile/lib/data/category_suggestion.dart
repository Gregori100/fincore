import 'package:drift/drift.dart';
import 'package:fincore/data/database.dart';

/// Servicio de sugerencia automática de categoría al capturar un nuevo
/// movimiento. Sprint `flutter-entries-category-suggestion-v1`.
///
/// Aplica una cascada de 3 criterios (RN-S03) sobre el journal para
/// proponer al usuario una categoría coherente con su histórico:
///
/// 1. **Match exacto de descripción** (case-insensitive, trimmed): entry
///    más reciente del mismo `kind` con descripción normalizada idéntica
///    y categoría activa compatible con `applies_to`.
/// 2. **Match de monto + cuenta relevante + kind reciente** (últimos 90
///    días): entry más reciente con esos atributos exactos.
/// 3. **Categoría más usada por kind + cuenta relevante** en los últimos
///    30 días. Tiebreak por uso más reciente.
///
/// "Cuenta relevante" (RN-S01):
/// - Para `expense` y `credit_expense`: `account_origin_id`.
/// - Para `income`: `account_destination_id`.
/// El form decide qué pasar al `accountId` según el kind actual.
///
/// Categorías archivadas (`deleted_at IS NOT NULL`) NUNCA se sugieren
/// (RN-S04). Entries soft-deleted tampoco contribuyen (RN-S05).
///
/// La sugerencia es puntual (Future, no Stream): se computa una vez con
/// los inputs actuales y se aplica al picker. Los re-cálculos los gobierna
/// el form con debounce + `_suggestionGeneration` para evitar races.
class CategorySuggestionService {
  final FincoreDatabase _db;
  CategorySuggestionService(this._db);

  /// Retorna el `categoryId` sugerido o `null` si ningún paso de la
  /// cascada matchea. Nunca lanza excepción para errores de cascada: si
  /// alguna query falla, propaga (el caller decide cómo manejarlo;
  /// típicamente el form ignora y deja el picker vacío — RN-S09).
  ///
  /// Parámetros:
  /// - `kind`: uno de `'expense'`, `'credit_expense'`, `'income'`. Otros
  ///   kinds (transfer, debt_payment) no aceptan categoría y retornan
  ///   `null` sin tocar BD.
  /// - `accountId`: la "cuenta relevante" según `kind`. Si es null, los
  ///   pasos 2 y 3 se saltan.
  /// - `description`: si es null/empty (tras trim), el paso 1 se salta.
  /// - `amount`: si es null o 0, el paso 2 se salta.
  /// - `now`: fecha de referencia para las ventanas de 30/90 días.
  ///   Default `DateTime.now()`. Inyectable para tests deterministas.
  Future<String?> suggestForNewEntry({
    required String kind,
    required String? accountId,
    required String? description,
    required double? amount,
    DateTime? now,
  }) async {
    // Kinds sin categoría → no hay nada que sugerir.
    if (kind != 'expense' && kind != 'credit_expense' && kind != 'income') {
      return null;
    }
    final nowValue = now ?? DateTime.now();
    final appliesTo = _validAppliesTo(kind);
    final accountColumn =
        kind == 'income' ? 'account_destination_id' : 'account_origin_id';

    // Paso 1: match exacto de descripción.
    final normalizedDesc = description?.trim().toLowerCase() ?? '';
    if (normalizedDesc.isNotEmpty) {
      final result = await _stepDescriptionMatch(
        kind: kind,
        normalizedDesc: normalizedDesc,
        appliesTo: appliesTo,
      );
      if (result != null) return result;
    }

    // Paso 2: match de monto + cuenta + kind dentro de últimos 90 días.
    if (accountId != null && amount != null && amount != 0) {
      final result = await _stepAmountAccountMatch(
        kind: kind,
        accountColumn: accountColumn,
        accountId: accountId,
        amount: amount,
        now: nowValue,
        appliesTo: appliesTo,
      );
      if (result != null) return result;
    }

    // Paso 3: más usada por kind + cuenta últimos 30 días.
    if (accountId != null) {
      final result = await _stepMostUsedRecent(
        kind: kind,
        accountColumn: accountColumn,
        accountId: accountId,
        now: nowValue,
        appliesTo: appliesTo,
      );
      if (result != null) return result;
    }

    return null;
  }

  Future<String?> _stepDescriptionMatch({
    required String kind,
    required String normalizedDesc,
    required List<String> appliesTo,
  }) async {
    final appliesToPlaceholders =
        List.filled(appliesTo.length, '?').join(', ');
    // NOTA (M2 quality review v1): SQLite `LOWER` es ASCII-only — no
    // normaliza acentos en mayúscula (e.g. `LOWER('CAFÉ')` = `'cafÉ'`).
    // Descripciones históricas con acentos mayúsculos NO matchean con
    // tipeo nuevo en minúscula. La normalización Dart cubre UTF-8 en
    // ambos extremos, pero no podemos pre-normalizar la columna en SQL.
    // Limitación documentada en R-04 del plan y CB-D16 del test-plan.
    final sql = '''
      SELECT j.category_id AS category_id
      FROM journal_entries j
      INNER JOIN categories c
        ON c.id = j.category_id AND c.deleted_at IS NULL
      WHERE j.kind = ?
        AND j.deleted_at IS NULL
        AND j.description IS NOT NULL
        AND LOWER(TRIM(j.description)) = ?
        AND c.applies_to IN ($appliesToPlaceholders)
      ORDER BY j.occurred_at DESC, j.created_at DESC
      LIMIT 1
    ''';
    final row = await _db
        .customSelect(
          sql,
          variables: [
            Variable.withString(kind),
            Variable.withString(normalizedDesc),
            for (final a in appliesTo) Variable.withString(a),
          ],
          readsFrom: {_db.journalEntries, _db.categories},
        )
        .getSingleOrNull();
    return row?.read<String?>('category_id');
  }

  Future<String?> _stepAmountAccountMatch({
    required String kind,
    required String accountColumn,
    required String accountId,
    required double amount,
    required DateTime now,
    required List<String> appliesTo,
  }) async {
    final from = now.subtract(const Duration(days: 90));
    final appliesToPlaceholders =
        List.filled(appliesTo.length, '?').join(', ');
    final sql = '''
      SELECT j.category_id AS category_id
      FROM journal_entries j
      INNER JOIN categories c
        ON c.id = j.category_id AND c.deleted_at IS NULL
      WHERE j.kind = ?
        AND j.deleted_at IS NULL
        AND j.$accountColumn = ?
        AND j.amount = ?
        AND j.occurred_at >= ?
        AND c.applies_to IN ($appliesToPlaceholders)
      ORDER BY j.occurred_at DESC, j.created_at DESC
      LIMIT 1
    ''';
    final row = await _db
        .customSelect(
          sql,
          variables: [
            Variable.withString(kind),
            Variable.withString(accountId),
            Variable.withReal(amount),
            Variable.withDateTime(from),
            for (final a in appliesTo) Variable.withString(a),
          ],
          readsFrom: {_db.journalEntries, _db.categories},
        )
        .getSingleOrNull();
    return row?.read<String?>('category_id');
  }

  Future<String?> _stepMostUsedRecent({
    required String kind,
    required String accountColumn,
    required String accountId,
    required DateTime now,
    required List<String> appliesTo,
  }) async {
    final from = now.subtract(const Duration(days: 30));
    final appliesToPlaceholders =
        List.filled(appliesTo.length, '?').join(', ');
    // B2 quality review v1: tercer criterio `category_id ASC` para que
    // el resultado sea determinístico cuando dos categorías empatan en
    // count + MAX(occurred_at). Caso raro en single-user (timestamps
    // únicos al segundo) pero evita tests flaky.
    final sql = '''
      SELECT j.category_id AS category_id,
             COUNT(*) AS uses,
             MAX(j.occurred_at) AS last_use
      FROM journal_entries j
      INNER JOIN categories c
        ON c.id = j.category_id AND c.deleted_at IS NULL
      WHERE j.kind = ?
        AND j.deleted_at IS NULL
        AND j.$accountColumn = ?
        AND j.occurred_at >= ?
        AND c.applies_to IN ($appliesToPlaceholders)
      GROUP BY j.category_id
      ORDER BY uses DESC, last_use DESC, j.category_id ASC
      LIMIT 1
    ''';
    final row = await _db
        .customSelect(
          sql,
          variables: [
            Variable.withString(kind),
            Variable.withString(accountId),
            Variable.withDateTime(from),
            for (final a in appliesTo) Variable.withString(a),
          ],
          readsFrom: {_db.journalEntries, _db.categories},
        )
        .getSingleOrNull();
    return row?.read<String?>('category_id');
  }

  /// Mapeo de kind → lista de `applies_to` compatibles (RN-S06).
  /// Coincide con `JournalKind.validCategoryAppliesTo` del enum del repo,
  /// pero se duplica acá para no depender del enum desde el data layer.
  List<String> _validAppliesTo(String kind) {
    if (kind == 'income') return const ['income', 'both'];
    return const ['expense', 'both'];
  }
}
