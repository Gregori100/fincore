import 'package:fincore/data/database.dart';
import 'package:fincore/data/daos/accounts_dao.dart';
import 'package:fincore/data/daos/categories_dao.dart';

/// Crea la Bolsa singleton + 10 categorías default tras "Arrancar limpio"
/// del primer arranque (RF-006). Idempotente: si ya existe contenido, no hace
/// nada — verificado por bootstrap.hasBolsa antes de llamar.
///
/// Las 10 categorías default coinciden 1:1 con las que el listener
/// CreateUserDefaultCategories del backend creaba al registrarse un usuario,
/// para que un export del backend importado en la nueva app no genere duplicados
/// (la reconciliación usa nombre).
Future<void> seedDefaults({
  required FincoreDatabase db,
  required AccountsDao accountsDao,
  required CategoriesDao categoriesDao,
}) async {
  await accountsDao.createBolsa();

  // Categorías de ingreso (3).
  const incomeDefaults = [
    ('Sueldo', 'green', 'banknotes'),
    ('Freelance', 'teal', 'briefcase'),
    ('Otros ingresos', 'indigo', 'arrow-trending-up'),
  ];
  // Categorías de gasto (7).
  const expenseDefaults = [
    ('Comida', 'orange', 'shopping-cart'),
    ('Transporte', 'blue', 'truck'),
    ('Servicios', 'yellow', 'bolt'),
    ('Hogar', 'red', 'home'),
    ('Entretenimiento', 'purple', 'film'),
    ('Salud', 'pink', 'heart'),
    ('Otros gastos', 'gray', 'tag'),
  ];

  for (final (name, color, icon) in incomeDefaults) {
    try {
      await categoriesDao.create(
        name: name,
        appliesTo: 'income',
        colorSlug: color,
        iconSlug: icon,
      );
    } on CategoriesDaoError catch (e) {
      // Idempotente: si una categoría ya existe (duplicate_category_name),
      // saltamos. Cualquier otro error sí escala.
      if (e.code != 'duplicate_category_name') rethrow;
    }
  }
  for (final (name, color, icon) in expenseDefaults) {
    try {
      await categoriesDao.create(
        name: name,
        appliesTo: 'expense',
        colorSlug: color,
        iconSlug: icon,
      );
    } on CategoriesDaoError catch (e) {
      if (e.code != 'duplicate_category_name') rethrow;
    }
  }
}
