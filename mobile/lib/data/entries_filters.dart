import 'package:fincore/constants/date_range_presets.dart';
import 'package:fincore/constants/filter_tokens.dart';

/// Snapshot inmutable de filtros aplicados a la lista de movimientos.
///
/// Tres usos:
/// 1. State del `EntriesListScreen` (qué filtros están activos hoy).
/// 2. Argumento al abrir el panel `EntriesFiltersScreen` (state inicial).
/// 3. Serialización a / desde query params del router para el deep link
///    desde `/reports`.
///
/// Inmutable: usar [copyWith] para producir variantes. La factory
/// [EntriesFilters.thisMonth] retorna el default al abrir `/entries`. La
/// factory [EntriesFilters.forCategoryBucket] arma el filtro equivalente al
/// bucket del reporte (M8 del quality review v1).
///
/// Patch v3 — `kinds`, `accountIds` y `categoryIds` son listas multi-select.
/// Si un usuario quiere ver "Gasto + Gasto a tarjeta", selecciona ambos
/// chips; ya no existe un preset "Gastos" combinado.
///
/// M9 del quality review v1: las 3 listas internas se guardan vía
/// `List.unmodifiable` para impedir mutación accidental por callers que
/// obtengan la referencia.
class EntriesFilters {
  final DateRangePreset datePreset;
  final DateTime from;
  final DateTime to;
  final List<String> kinds;
  final List<String> accountIds;
  final List<String> categoryIds;

  /// Filtro de monto mínimo (inclusivo). Null = no filtra por mínimo.
  /// Sprint `flutter-movements-amount-filter-v1`, RN-A02. Opera sobre el
  /// `amount` crudo (siempre positivo en BD — RN-A01).
  final double? minAmount;

  /// Filtro de monto máximo (inclusivo). Null = no filtra por máximo.
  /// Sprint `flutter-movements-amount-filter-v1`, RN-A03.
  final double? maxAmount;

  EntriesFilters({
    required this.datePreset,
    required this.from,
    required this.to,
    List<String> kinds = const [],
    List<String> accountIds = const [],
    List<String> categoryIds = const [],
    this.minAmount,
    this.maxAmount,
  })  : kinds = List.unmodifiable(kinds),
        accountIds = List.unmodifiable(accountIds),
        categoryIds = List.unmodifiable(categoryIds);

  /// Default al abrir `/entries` sin query params: rango = mes calendario
  /// corriente, sin restricciones de tipo / cuentas / categorías.
  factory EntriesFilters.thisMonth([DateTime? now]) {
    final ref = now ?? DateTime.now();
    final (from, to) = dateRangeForPreset(DateRangePreset.thisMonth, ref);
    return EntriesFilters(
      datePreset: DateRangePreset.thisMonth,
      from: from,
      to: to,
    );
  }

  /// Factory para el deep link desde un bucket del reporte de gasto por
  /// categoría (M8 del quality review v1). Encapsula la composición de:
  /// `datePreset = custom`, `from`/`to` exactos del reporte, kinds = Gasto
  /// + Gasto a tarjeta, categoryIds = id del bucket o token Sin categoría.
  factory EntriesFilters.forCategoryBucket({
    required String? categoryId,
    required DateTime from,
    required DateTime to,
  }) {
    return EntriesFilters(
      datePreset: DateRangePreset.custom,
      from: from,
      to: to,
      kinds: const ['expense', 'credit_expense'],
      categoryIds: [categoryId ?? kUncategorizedFilterToken],
    );
  }

  /// Cuenta cuántas dimensiones tienen al menos un valor distinto del default.
  /// Usado para el badge numérico en el AppBar. Max 4.
  int get activeCount {
    var count = 0;
    if (datePreset != DateRangePreset.thisMonth) count++;
    if (kinds.isNotEmpty) count++;
    if (accountIds.isNotEmpty) count++;
    if (categoryIds.isNotEmpty) count++;
    if (minAmount != null || maxAmount != null) count++;
    return count;
  }

  /// `clearMinAmount` / `clearMaxAmount` permiten setear el campo a null
  /// explícitamente, distinguiendo "no cambiar" (default null en
  /// `minAmount`/`maxAmount`) de "limpiar". Si se pasan `clearXxx: true`
  /// junto a un valor explícito en `xxx`, el clear gana (documentado).
  EntriesFilters copyWith({
    DateRangePreset? datePreset,
    DateTime? from,
    DateTime? to,
    List<String>? kinds,
    List<String>? accountIds,
    List<String>? categoryIds,
    double? minAmount,
    double? maxAmount,
    bool clearMinAmount = false,
    bool clearMaxAmount = false,
  }) {
    return EntriesFilters(
      datePreset: datePreset ?? this.datePreset,
      from: from ?? this.from,
      to: to ?? this.to,
      kinds: kinds ?? this.kinds,
      accountIds: accountIds ?? this.accountIds,
      categoryIds: categoryIds ?? this.categoryIds,
      minAmount: clearMinAmount ? null : (minAmount ?? this.minAmount),
      maxAmount: clearMaxAmount ? null : (maxAmount ?? this.maxAmount),
    );
  }

  /// Aplica un preset a partir del estado actual: para `custom` conserva el
  /// rango previo, para los otros lo recalcula a partir de `now`.
  EntriesFilters withPreset(DateRangePreset preset, [DateTime? now]) {
    final (newFrom, newTo) = dateRangeForPreset(
      preset,
      now ?? DateTime.now(),
      currentFrom: from,
      currentTo: to,
    );
    return copyWith(datePreset: preset, from: newFrom, to: newTo);
  }

  /// Limpia una dimensión específica devolviendo un nuevo filtro. Reemplaza
  /// el enum privado `_FilterDimension` que duplicaba el modelo (M7 del
  /// quality review v1).
  EntriesFilters clearDimension(FilterDimension dim) {
    switch (dim) {
      case FilterDimension.date:
        return withPreset(DateRangePreset.thisMonth);
      case FilterDimension.kinds:
        return copyWith(kinds: const []);
      case FilterDimension.accounts:
        return copyWith(accountIds: const []);
      case FilterDimension.categories:
        return copyWith(categoryIds: const []);
      case FilterDimension.amount:
        return copyWith(clearMinAmount: true, clearMaxAmount: true);
    }
  }

  /// Convierte los filtros a una URL de deep link `/entries?...`. Encapsula
  /// la dependencia del consumidor (reporte) con el formato interno del
  /// `serialize()` (M8 del quality review v1).
  String toDeepLink() {
    return Uri(path: '/entries', queryParameters: serialize()).toString();
  }

  /// Serializa los filtros a query params del router. Omite campos default
  /// para mantener URLs cortas.
  Map<String, String> serialize() {
    final map = <String, String>{};
    if (datePreset != DateRangePreset.thisMonth) {
      map['datePreset'] = datePreset.slug;
    }
    if (datePreset == DateRangePreset.custom) {
      map['from'] = from.toIso8601String();
      map['to'] = to.toIso8601String();
    }
    if (kinds.isNotEmpty) {
      map['kinds'] = kinds.join(',');
    }
    if (accountIds.isNotEmpty) {
      map['accountIds'] = accountIds.join(',');
    }
    if (categoryIds.isNotEmpty) {
      map['categoryIds'] = categoryIds.join(',');
    }
    if (minAmount != null) {
      map['minAmount'] = minAmount!.toString();
    }
    if (maxAmount != null) {
      map['maxAmount'] = maxAmount!.toString();
    }
    return map;
  }

  /// Serializa los filtros a JSON para guardar en BD (sprint
  /// `flutter-entries-saved-views-v1`). Diferente de [serialize] (que es
  /// para query params del router):
  ///
  /// - Híbrido preset/custom (RN-V04):
  ///   - Si `datePreset` es semántico (`thisMonth`/`lastMonth`/`thisYear`):
  ///     guarda solo el slug; al deserializar se recalcula con
  ///     `dateRangeForPreset(preset, DateTime.now())` → rolling.
  ///   - Si `datePreset == custom`: guarda `from`/`to` como ISO8601 → fijo.
  /// - Listas: serializadas como `List<String>` nativo, no CSV.
  /// - Defaults vacíos no se incluyen (JSON más chico).
  Map<String, dynamic> toSavedJson() {
    final json = <String, dynamic>{
      'datePreset': datePreset.slug,
    };
    if (datePreset == DateRangePreset.custom) {
      json['from'] = from.toIso8601String();
      json['to'] = to.toIso8601String();
    }
    if (kinds.isNotEmpty) {
      json['kinds'] = List<String>.from(kinds);
    }
    if (accountIds.isNotEmpty) {
      json['accountIds'] = List<String>.from(accountIds);
    }
    if (categoryIds.isNotEmpty) {
      json['categoryIds'] = List<String>.from(categoryIds);
    }
    if (minAmount != null) {
      json['minAmount'] = minAmount;
    }
    if (maxAmount != null) {
      json['maxAmount'] = maxAmount;
    }
    return json;
  }

  /// Deserializa filtros desde un JSON guardado en BD. Tolerante a campos
  /// faltantes (RN-V04, R-T05): cualquier campo inválido cae al default
  /// sin lanzar. Si el JSON es vacío o totalmente corrupto, retorna
  /// [EntriesFilters.thisMonth].
  factory EntriesFilters.fromSavedJson(
    Map<String, dynamic> json, [
    DateTime? now,
  ]) {
    final ref = now ?? DateTime.now();
    if (json.isEmpty) {
      return EntriesFilters.thisMonth(ref);
    }

    final preset = dateRangePresetFromSlug(json['datePreset'] as String?) ??
        DateRangePreset.thisMonth;

    DateTime from;
    DateTime to;
    if (preset == DateRangePreset.custom) {
      // Custom: usa from/to del JSON exactos. Si falta o están corruptos,
      // fallback a thisMonth.
      final parsedFrom = _tryParseDate(json['from'] as String?);
      final parsedTo = _tryParseDate(json['to'] as String?);
      if (parsedFrom == null ||
          parsedTo == null ||
          parsedFrom.isAfter(parsedTo)) {
        final fb = dateRangeForPreset(DateRangePreset.thisMonth, ref);
        from = fb.$1;
        to = fb.$2;
      } else {
        from = parsedFrom;
        to = parsedTo;
      }
    } else {
      // Preset semántico → rolling: recalcula con la fecha actual.
      final r = dateRangeForPreset(preset, ref);
      from = r.$1;
      to = r.$2;
    }

    final kinds = _parseSavedList(json['kinds'])
        .where(_kValidKinds.contains)
        .toSet()
        .toList(growable: false);
    final accountIds = _parseSavedList(json['accountIds'])
        .toSet()
        .toList(growable: false);
    final categoryIds = _parseSavedList(json['categoryIds'])
        .toSet()
        .toList(growable: false);
    final minAmount = _tryParseDouble(json['minAmount']);
    final maxAmount = _tryParseDouble(json['maxAmount']);

    return EntriesFilters(
      datePreset: preset,
      from: from,
      to: to,
      kinds: kinds,
      accountIds: accountIds,
      categoryIds: categoryIds,
      minAmount: minAmount,
      maxAmount: maxAmount,
    );
  }

  /// Parsea desde query params. Tolerante a URLs malformadas: cualquier
  /// campo inválido cae al default sin lanzar.
  ///
  /// Si `params` está vacío, retorna [EntriesFilters.thisMonth].
  factory EntriesFilters.parse(Map<String, String> params, [DateTime? now]) {
    final ref = now ?? DateTime.now();
    if (params.isEmpty) {
      return EntriesFilters.thisMonth(ref);
    }

    final presetSlug = params['datePreset'];
    final preset = dateRangePresetFromSlug(presetSlug) ?? DateRangePreset.thisMonth;

    DateTime from;
    DateTime to;
    if (preset == DateRangePreset.custom) {
      final parsedFrom = _tryParseDate(params['from']);
      final parsedTo = _tryParseDate(params['to']);
      if (parsedFrom == null ||
          parsedTo == null ||
          parsedFrom.isAfter(parsedTo)) {
        final fallback = dateRangeForPreset(DateRangePreset.thisMonth, ref);
        from = fallback.$1;
        to = fallback.$2;
      } else {
        from = parsedFrom;
        to = parsedTo;
      }
    } else {
      final r = dateRangeForPreset(preset, ref);
      from = r.$1;
      to = r.$2;
    }

    final kinds = _parseCsv(params['kinds'])
        .where(_kValidKinds.contains)
        .toSet()
        .toList(growable: false);

    // B5 del quality review v1: defensa en profundidad.
    // - SQL injection ya está mitigado por drift (parametrización).
    // - Aceptamos cualquier string non-empty como ID. Si el ID no existe en
    //   BD, el filtro retorna 0 entries silenciosamente — comportamiento
    //   defensivo aceptable.
    // - Validación estricta de UUID v7 quedaría como sprint dedicado si
    //   surge necesidad de feedback explícito ("ID no encontrado").
    final accountIds =
        _parseCsv(params['accountIds']).toSet().toList(growable: false);

    final categoryIds =
        _parseCsv(params['categoryIds']).toSet().toList(growable: false);

    // RN-A07: negativos y no-numéricos en minAmount/maxAmount caen a null.
    final minAmount = _tryParseNonNegativeDouble(params['minAmount']);
    final maxAmount = _tryParseNonNegativeDouble(params['maxAmount']);

    return EntriesFilters(
      datePreset: preset,
      from: from,
      to: to,
      kinds: kinds,
      accountIds: accountIds,
      categoryIds: categoryIds,
      minAmount: minAmount,
      maxAmount: maxAmount,
    );
  }
}

/// Dimensiones que el usuario puede quitar individualmente desde los chips
/// de filtros activos arriba de la lista (M7 del quality review v1).
enum FilterDimension { date, kinds, accounts, categories, amount }

const _kValidKinds = {
  'income',
  'expense',
  'credit_expense',
  'debt_payment',
  'transfer',
};

DateTime? _tryParseDate(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  return DateTime.tryParse(raw);
}

/// Helper para `parse`: retorna el double parseado si es >= 0; null en
/// cualquier otro caso (string vacío, no-numérico, negativo). RN-A07 del
/// sprint `flutter-movements-amount-filter-v1`.
double? _tryParseNonNegativeDouble(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  final v = double.tryParse(raw);
  if (v == null || v < 0) return null;
  return v;
}

List<String> _parseCsv(String? raw) {
  if (raw == null || raw.isEmpty) return const [];
  return raw
      .split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList(growable: false);
}

/// Sprint `flutter-entries-saved-views-v1`: parsea una lista del JSON
/// guardado. Acepta List nativa de strings o null. Si el campo no es
/// lista, retorna lista vacía sin lanzar.
List<String> _parseSavedList(dynamic raw) {
  if (raw is! List) return const [];
  return raw
      .where((e) => e is String && e.isNotEmpty)
      .cast<String>()
      .toList(growable: false);
}

/// Sprint `flutter-entries-saved-views-v1`: parsea un double tolerante.
/// Acepta `double` o `int` directo; null/no-numérico → null.
double? _tryParseDouble(dynamic raw) {
  if (raw == null) return null;
  if (raw is double) return raw;
  if (raw is int) return raw.toDouble();
  if (raw is String) return double.tryParse(raw);
  return null;
}
