import 'package:drift/drift.dart';
import 'package:fincore/data/database.dart';

/// Helpers para detectar el estado inicial de la BD en el primer arranque.
///
/// hasBolsa = true significa que el seed ya corrió (o un backup se importó);
/// en ese caso el router lleva directo al dashboard. Si es false, redirect a
/// /first-run para que el usuario elija "Arrancar limpio" o "Importar respaldo".
Future<bool> hasBolsa(FincoreDatabase db) async {
  final query = db.selectOnly(db.accounts)
    ..addColumns([db.accounts.id.count()])
    ..where(db.accounts.type.equals('cash') & db.accounts.deletedAt.isNull());
  final row = await query.getSingle();
  final count = row.read<int>(db.accounts.id.count()) ?? 0;
  return count > 0;
}
