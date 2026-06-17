import 'package:fincore/models/account.dart';
import 'package:fincore/models/category.dart';
import 'package:fincore/models/journal_entry.dart';

/// Snapshot que devuelve GET /api/finance/state.
class FinanceState {
  final num bo;
  final num de;
  final num cr;
  final List<Account> accounts;
  final List<JournalEntry> recentEntries;
  final List<Category> categories;

  const FinanceState({
    required this.bo,
    required this.de,
    required this.cr,
    required this.accounts,
    required this.recentEntries,
    required this.categories,
  });

  factory FinanceState.fromJson(Map<String, dynamic> json) {
    return FinanceState(
      bo: (json['bo'] as num?) ?? 0,
      de: (json['de'] as num?) ?? 0,
      cr: (json['cr'] as num?) ?? 0,
      accounts: ((json['accounts'] as List<dynamic>?) ?? const [])
          .map((e) => Account.fromJson(e as Map<String, dynamic>))
          .toList(),
      recentEntries: ((json['recent_entries'] as List<dynamic>?) ?? const [])
          .map((e) => JournalEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      categories: ((json['categories'] as List<dynamic>?) ?? const [])
          .map((e) => Category.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
