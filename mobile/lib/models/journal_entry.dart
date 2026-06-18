import 'package:fincore/constants/kinds.dart';
import 'package:fincore/models/account.dart';
import 'package:fincore/models/category.dart';

class JournalEntry {
  final String id;
  final JournalKind kind;
  final String? accountOriginId;
  final String? accountDestinationId;
  final num amount;
  final String? description;
  final DateTime occurredAt;
  final String? categoryId;
  final DateTime? deletedAt;

  // Relaciones embebidas opcionales (vienen en listEntries y state).
  final Account? accountOrigin;
  final Account? accountDestination;
  final Category? category;

  const JournalEntry({
    required this.id,
    required this.kind,
    required this.accountOriginId,
    required this.accountDestinationId,
    required this.amount,
    required this.description,
    required this.occurredAt,
    required this.categoryId,
    required this.deletedAt,
    this.accountOrigin,
    this.accountDestination,
    this.category,
  });

  bool get isCancelled => deletedAt != null;

  factory JournalEntry.fromJson(Map<String, dynamic> json) {
    return JournalEntry(
      id: json['id'] as String,
      kind: parseJournalKind(json['kind'] as String),
      accountOriginId: json['account_origin_id'] as String?,
      accountDestinationId: json['account_destination_id'] as String?,
      amount: json['amount'] as num,
      description: json['description'] as String?,
      occurredAt: DateTime.parse(json['occurred_at'] as String),
      categoryId: json['category_id'] as String?,
      deletedAt: json['deleted_at'] == null
          ? null
          : DateTime.parse(json['deleted_at'] as String),
      accountOrigin: json['account_origin'] == null
          ? null
          : Account.fromJson(json['account_origin'] as Map<String, dynamic>),
      accountDestination: json['account_destination'] == null
          ? null
          : Account.fromJson(json['account_destination'] as Map<String, dynamic>),
      category: json['category'] == null
          ? null
          : Category.fromJson(json['category'] as Map<String, dynamic>),
    );
  }
}
