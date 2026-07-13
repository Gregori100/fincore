import 'package:fincore/data/daos/entries_dao.dart';
import 'package:fincore/data/database.dart';
import 'package:fincore/widgets/entry_account_label.dart';
import 'package:flutter_test/flutter_test.dart';

// Tests del helper `entryAccountLabel` — decide qué texto mostrar según
// el kind del movimiento. Sprint UX de visibilidad de cuenta.
void main() {
  Account account(String id, String name, String type) => Account(
        id: id,
        name: name,
        type: type,
        isProtected: false,
        creditLimit: 0,
        closingDay: null,
        paymentDay: null,
        interestRate: null,
        minimumPaymentPct: null,
        minimumCapitalPct: 0.015,
        minimumFloor: 150,
        description: null,
        deletedAt: null,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

  JournalEntry entry(String kind) => JournalEntry(
        id: 'entry-1',
        kind: kind,
        accountOriginId: null,
        accountDestinationId: null,
        categoryId: null,
        amount: 100,
        description: null,
        occurredAt: DateTime(2026, 1, 1),
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
        deletedAt: null,
      );

  final bolsa = account('a1', 'Bolsa', 'cash');
  final bbva = account('a2', 'BBVA', 'debit');
  final visa = account('a3', 'Visa', 'credit');

  test('UT-EAL01: income → nombre de la cuenta destino', () {
    final item = EntryWithRelations(
      entry: entry('income'),
      accountDestination: bolsa,
    );
    expect(entryAccountLabel(item), 'Bolsa');
  });

  test('UT-EAL02: expense → nombre de la cuenta origen', () {
    final item = EntryWithRelations(
      entry: entry('expense'),
      accountOrigin: bbva,
    );
    expect(entryAccountLabel(item), 'BBVA');
  });

  test('UT-EAL03: credit_expense → nombre de la tarjeta origen', () {
    final item = EntryWithRelations(
      entry: entry('credit_expense'),
      accountOrigin: visa,
    );
    expect(entryAccountLabel(item), 'Visa');
  });

  test('UT-EAL04: debt_payment → "origen → destino"', () {
    final item = EntryWithRelations(
      entry: entry('debt_payment'),
      accountOrigin: bolsa,
      accountDestination: visa,
    );
    expect(entryAccountLabel(item), 'Bolsa → Visa');
  });

  test('UT-EAL05: transfer → "origen → destino"', () {
    final item = EntryWithRelations(
      entry: entry('transfer'),
      accountOrigin: bolsa,
      accountDestination: bbva,
    );
    expect(entryAccountLabel(item), 'Bolsa → BBVA');
  });

  test('UT-EAL06: income sin destination resuelto → null (FK colgante)',
      () {
    final item = EntryWithRelations(entry: entry('income'));
    expect(entryAccountLabel(item), isNull);
  });

  test(
      'UT-EAL07: transfer con solo origin resuelto → devuelve origin sin flecha',
      () {
    final item = EntryWithRelations(
      entry: entry('transfer'),
      accountOrigin: bolsa,
    );
    expect(entryAccountLabel(item), 'Bolsa');
  });
}
