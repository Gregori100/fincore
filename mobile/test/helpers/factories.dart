import 'package:drift/drift.dart';
import 'package:fincore/data/database.dart';
import 'package:fincore/data/uuid.dart';

/// Fixtures rápidas para tests. Todas las fechas usan UTC para deterministic
/// comparisons.
class Factories {
  static DateTime now = DateTime.utc(2026, 6, 17, 12, 0, 0);

  static AccountsCompanion debit({
    String? id,
    String name = 'Banamex',
    String? description,
  }) {
    return AccountsCompanion.insert(
      id: id ?? UuidV7.generate(),
      name: name,
      type: 'debit',
      description: Value(description),
      createdAt: now,
      updatedAt: now,
    );
  }

  static AccountsCompanion credit({
    String? id,
    String name = 'Visa',
    int creditLimit = 50000,
    int closingDay = 15,
    int paymentDay = 5,
  }) {
    return AccountsCompanion.insert(
      id: id ?? UuidV7.generate(),
      name: name,
      type: 'credit',
      creditLimit: Value(creditLimit),
      closingDay: Value(closingDay),
      paymentDay: Value(paymentDay),
      createdAt: now,
      updatedAt: now,
    );
  }

  static AccountsCompanion bolsa({String? id}) {
    return AccountsCompanion.insert(
      id: id ?? UuidV7.generate(),
      name: 'Bolsa',
      type: 'cash',
      isProtected: const Value(true),
      createdAt: now,
      updatedAt: now,
    );
  }

  static CategoriesCompanion category({
    String? id,
    String name = 'Comida',
    String appliesTo = 'expense',
    String colorSlug = 'orange',
    String iconSlug = 'shopping-cart',
  }) {
    return CategoriesCompanion.insert(
      id: id ?? UuidV7.generate(),
      name: name,
      appliesTo: appliesTo,
      colorSlug: colorSlug,
      iconSlug: iconSlug,
      createdAt: now,
      updatedAt: now,
    );
  }
}
