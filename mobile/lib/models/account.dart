import 'package:fincore/constants/account_types.dart';

class Account {
  final String id;
  final String name;
  final AccountType type;
  final String? description;
  final bool isProtected;
  final DateTime? deletedAt;

  // Metadata específica de credit. Null en cash/debit.
  final num? creditLimit;
  final int? closingDay;
  final int? paymentDay;
  final num? interestRate;
  final num? minimumPaymentPct;

  // Balance derivado que el backend incluye en state/list. No es persistido.
  final num? balance;

  const Account({
    required this.id,
    required this.name,
    required this.type,
    required this.description,
    required this.isProtected,
    required this.deletedAt,
    this.creditLimit,
    this.closingDay,
    this.paymentDay,
    this.interestRate,
    this.minimumPaymentPct,
    this.balance,
  });

  bool get isArchived => deletedAt != null;
  bool get isCash => type == AccountType.cash;
  bool get isCredit => type == AccountType.credit;

  factory Account.fromJson(Map<String, dynamic> json) {
    return Account(
      id: json['id'] as String,
      name: json['name'] as String,
      type: parseAccountType(json['type'] as String),
      description: json['description'] as String?,
      isProtected: json['is_protected'] as bool? ?? false,
      deletedAt: json['deleted_at'] == null
          ? null
          : DateTime.parse(json['deleted_at'] as String),
      creditLimit: json['credit_limit'] as num?,
      closingDay: json['closing_day'] as int?,
      paymentDay: json['payment_day'] as int?,
      interestRate: json['interest_rate'] as num?,
      minimumPaymentPct: json['minimum_payment_pct'] as num?,
      balance: json['balance'] as num?,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'type': type.apiValue,
        'description': description,
        'is_protected': isProtected,
        'deleted_at': deletedAt?.toIso8601String(),
        'credit_limit': creditLimit,
        'closing_day': closingDay,
        'payment_day': paymentDay,
        'interest_rate': interestRate,
        'minimum_payment_pct': minimumPaymentPct,
        'balance': balance,
      };
}
