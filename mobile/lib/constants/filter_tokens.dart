// Tokens especiales compartidos entre el modelo de filtros, el DAO de
// movimientos, la UI del panel y el deep link desde el reporte.
//
// Centralizado en `lib/constants/` desde el quality review v1 del sprint
// `flutter-movements-filters-v1` (M1): antes vivía en
// `lib/data/daos/entries_dao.dart` pero se importaba desde 4 sitios
// distintos. Centralizar elimina el riesgo de divergencia si el valor
// literal cambia.

/// Token que matchea entries con `category_id IS NULL` o cuya categoría está
/// archivada (`categories.deleted_at IS NOT NULL`).
///
/// En `EntriesDao.watchPage` el filtro `categoryIds.contains(this)` se
/// traduce a `WHERE categories.id IS NULL` sobre la columna del LEFT JOIN
/// (que ya filtra `deleted_at IS NULL` en la cláusula ON, por lo que ambos
/// casos quedan cubiertos).
///
/// Consistente con el bucket "Sin categoría" del reporte de gasto por
/// categoría (RN-R03/R04 del sprint `flutter-reports-v1`).
const String kUncategorizedFilterToken = '__null__';
