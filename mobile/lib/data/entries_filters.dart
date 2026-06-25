import 'package:fincore/constants/date_range_presets.dart';

/// Snapshot inmutable de filtros aplicados a la lista de movimientos.
///
/// Sirve tres usos en el sprint `flutter-movements-filters-v1`:
/// 1. State del `EntriesListScreen` (qué filtros están activos hoy).
/// 2. Argumento al abrir el panel `EntriesFiltersScreen` (state inicial).
/// 3. Serialización a / desde query params del router para el deep link
///    desde `/reports`.
///
/// Inmutable: usar [copyWith] para producir variantes. La factory
/// [EntriesFilters.thisMonth] retorna el default al abrir `/entries`.
///
/// Patch v3 — `kinds`, `accountIds` y `categoryIds` son listas multi-select.
/// Si un usuario quiere ver "Gasto + Gasto a tarjeta", selecciona ambos
/// chips; ya no existe un preset "Gastos" combinado.
class EntriesFilters {
  final DateRangePreset datePreset;
  final DateTime from;
  final DateTime to;
  final List<String> kinds;
  final List<String> accountIds;
  final List<String> categoryIds;

  const EntriesFilters({
    required this.datePreset,
    required this.from,
    required this.to,
    this.kinds = const [],
    this.accountIds = const [],
    this.categoryIds = const [],
  });

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

  /// Cuenta cuántas dimensiones tienen al menos un valor distinto del default.
  /// Usado para el badge numérico en el AppBar. Max 4.
  ///
  /// El default `thisMonth` cuenta como dimensión NO activa: si el usuario
  /// abre la pantalla por primera vez, el badge es 0.
  int get activeCount {
    var count = 0;
    if (datePreset != DateRangePreset.thisMonth) count++;
    if (kinds.isNotEmpty) count++;
    if (accountIds.isNotEmpty) count++;
    if (categoryIds.isNotEmpty) count++;
    return count;
  }

  EntriesFilters copyWith({
    DateRangePreset? datePreset,
    DateTime? from,
    DateTime? to,
    List<String>? kinds,
    List<String>? accountIds,
    List<String>? categoryIds,
  }) {
    return EntriesFilters(
      datePreset: datePreset ?? this.datePreset,
      from: from ?? this.from,
      to: to ?? this.to,
      kinds: kinds ?? this.kinds,
      accountIds: accountIds ?? this.accountIds,
      categoryIds: categoryIds ?? this.categoryIds,
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
    return map;
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

    final accountIds =
        _parseCsv(params['accountIds']).toSet().toList(growable: false);

    final categoryIds =
        _parseCsv(params['categoryIds']).toSet().toList(growable: false);

    return EntriesFilters(
      datePreset: preset,
      from: from,
      to: to,
      kinds: kinds,
      accountIds: accountIds,
      categoryIds: categoryIds,
    );
  }
}

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

List<String> _parseCsv(String? raw) {
  if (raw == null || raw.isEmpty) return const [];
  return raw
      .split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList(growable: false);
}
