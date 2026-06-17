/// Estructura típica que Laravel devuelve con `->paginate()`.
class Paginated<T> {
  final List<T> data;
  final int currentPage;
  final int? lastPage;
  final int? perPage;
  final int? total;

  const Paginated({
    required this.data,
    required this.currentPage,
    required this.lastPage,
    required this.perPage,
    required this.total,
  });

  bool get hasNext => lastPage != null && currentPage < lastPage!;

  factory Paginated.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) itemFromJson,
  ) {
    return Paginated<T>(
      data: ((json['data'] as List<dynamic>?) ?? const [])
          .map((e) => itemFromJson(e as Map<String, dynamic>))
          .toList(),
      currentPage: (json['current_page'] as int?) ?? 1,
      lastPage: json['last_page'] as int?,
      perPage: json['per_page'] as int?,
      total: json['total'] as int?,
    );
  }
}
