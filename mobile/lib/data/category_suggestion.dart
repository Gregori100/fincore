import 'package:drift/drift.dart';
import 'package:fincore/data/database.dart';

/// Servicio de sugerencia automática de categoría al capturar un nuevo
/// movimiento. Sprint `flutter-entries-category-suggestion-v1`,
/// algoritmo **v2** post-uso real (decisión del 2026-06-29).
///
/// **Algoritmo v2 — un solo criterio: match por substring de descripción.**
///
/// La nueva descripción se compara contra descripciones históricas usando
/// `LIKE`: se considera match cuando la nueva descripción **contiene**
/// como substring la descripción de un entry previo del mismo `kind`
/// con categoría activa y `applies_to` compatible.
///
/// Ejemplo: histórico tiene un entry con `description = "Café"` y
/// categoría "Café". Si Diego tipea `"Café para mi novia"`, la nueva
/// contiene `"Café"` → sugiere "Café". Igual para `"Café del amigo Juan"`.
///
/// Filtro defensivo: la descripción histórica debe medir **al menos 3
/// caracteres tras trim**, para que entries con descripciones muy cortas
/// (`"a"`, `"x"`) no generen falsos positivos masivos. La nueva
/// descripción también debe tener al menos 3 chars.
///
/// Orden ante múltiples matches: `occurred_at DESC, created_at DESC` →
/// la categoría del entry más reciente gana.
///
/// **Algoritmo v1 (descartado)**: tenía dos pasos adicionales — match
/// por monto+cuenta últimos 90 días, y categoría más usada por
/// kind+cuenta últimos 30 días. Diego confirmó en uso real que el monto
/// es irrelevante y que el fallback estadístico ("más usada") es
/// intrusivo porque dispara sin señal del usuario, erosiona confianza.
/// Bitácora completa en `clarificaciones.md` v2.
///
/// Categorías archivadas (`deleted_at IS NOT NULL`) nunca se sugieren.
/// Entries soft-deleted tampoco contribuyen.
class CategorySuggestionService {
  final FincoreDatabase _db;
  CategorySuggestionService(this._db);

  /// Retorna el `categoryId` sugerido o `null` si no hay match.
  ///
  /// Parámetros:
  /// - `kind`: uno de `'expense'`, `'credit_expense'`, `'income'`.
  ///   Otros kinds (transfer, debt_payment) retornan `null` sin tocar BD.
  /// - `description`: si es null o medida <3 chars (tras trim), retorna
  ///   `null` sin tocar BD.
  ///
  /// Tras el refactor v2 ya no recibe `accountId`, `amount` ni `now` —
  /// ninguno influye en la lógica.
  Future<String?> suggestForNewEntry({
    required String kind,
    required String? description,
  }) async {
    // Kinds sin categoría → no hay nada que sugerir.
    if (kind != 'expense' && kind != 'credit_expense' && kind != 'income') {
      return null;
    }
    // Normalización en Dart (`.trim().toLowerCase()`) cubre UTF-8 con
    // acentos correctamente. SQLite `LOWER` ASCII-only se aplica solo al
    // lado histórico (limitación documentada).
    final normalizedDesc = description?.trim().toLowerCase() ?? '';
    if (normalizedDesc.length < 3) return null;

    final appliesTo = _validAppliesTo(kind);
    final appliesToPlaceholders =
        List.filled(appliesTo.length, '?').join(', ');

    // NOTA (M2 quality review v1): SQLite `LOWER` es ASCII-only —
    // descripciones históricas con acentos en mayúscula no matchearán
    // con tipeo nuevo en minúscula. Limitación aceptada.
    //
    // Patrón LIKE: la **nueva** descripción contiene la **histórica**.
    // - `?` ya viene normalizado en Dart con trim+toLowerCase.
    // - `LENGTH(TRIM(j.description)) >= 3`: evita falsos positivos por
    //   descripciones históricas muy cortas (`"a"`, `"x"`).
    // - El patrón `'%' || ... || '%'` envuelve la columna histórica;
    //   pasa como Variable sin interpolar `%` directamente desde Dart.
    final sql = '''
      SELECT j.category_id AS category_id
      FROM journal_entries j
      INNER JOIN categories c
        ON c.id = j.category_id AND c.deleted_at IS NULL
      WHERE j.kind = ?
        AND j.deleted_at IS NULL
        AND j.description IS NOT NULL
        AND LENGTH(TRIM(j.description)) >= 3
        AND ? LIKE '%' || LOWER(TRIM(j.description)) || '%'
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

  /// Mapeo de kind → lista de `applies_to` compatibles (RN-S06).
  /// Duplicado del enum `JournalKind.validCategoryAppliesTo` para no
  /// acoplar el data layer con `constants/kinds.dart`.
  List<String> _validAppliesTo(String kind) {
    if (kind == 'income') return const ['income', 'both'];
    return const ['expense', 'both'];
  }
}
