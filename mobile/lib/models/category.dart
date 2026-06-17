class Category {
  final String id;
  final String name;
  final String appliesTo; // income | expense | both
  final String colorSlug;
  final String iconSlug;
  final num? monthlyLimit;
  final DateTime? deletedAt;

  const Category({
    required this.id,
    required this.name,
    required this.appliesTo,
    required this.colorSlug,
    required this.iconSlug,
    required this.monthlyLimit,
    required this.deletedAt,
  });

  bool get isArchived => deletedAt != null;

  bool matchesKindFilter(List<String> validAppliesTo) {
    return validAppliesTo.contains(appliesTo);
  }

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] as String,
      name: json['name'] as String,
      appliesTo: json['applies_to'] as String,
      colorSlug: json['color_slug'] as String,
      iconSlug: json['icon_slug'] as String,
      monthlyLimit: json['monthly_limit'] as num?,
      deletedAt: json['deleted_at'] == null
          ? null
          : DateTime.parse(json['deleted_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'applies_to': appliesTo,
        'color_slug': colorSlug,
        'icon_slug': iconSlug,
        'monthly_limit': monthlyLimit,
        'deleted_at': deletedAt?.toIso8601String(),
      };
}
