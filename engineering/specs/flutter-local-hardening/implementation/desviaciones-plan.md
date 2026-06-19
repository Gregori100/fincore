# Desviaciones del plan — flutter-local-hardening

Diferencias entre `plan/tasks.md` y la implementación real, con razón y mitigación.

## Fase 1 — Test `Import con FK rota rechaza invalid_reference`

- **Plan original**: el plan no contemplaba cambiar tests existentes; solo agregar nuevos en T020.
- **Real**: el test `Import con FK rota rechaza invalid_reference` (backup_test.dart línea 122) usaba `"account_origin_id": "ID-INEXISTENTE"` (string no-UUID) para simular una FK rota. Con la nueva validación de formato UUID (T008/RF-006), ese string ahora es rechazado **antes** con `invalid_uuid_format`. El test fallaba esperando `invalid_reference` y recibía `invalid_uuid_format`.
- **Mitigación**: cambié el JSON del test a usar un UUID v7 válido pero inexistente en accounts: `00000000-0000-7000-8000-fffffffffff0`. El test sigue validando exactamente lo mismo conceptualmente (FK rota) pero con un formato de ID que pasa la primera validación.
- **Sin impacto en RFs**: el cambio es solo al fixture del test. El comportamiento del sistema queda igual, salvo que ahora hay una validación más estricta antes del check de FK (lo cual era el objetivo del sprint).

## Fase 2 — Migrator API

- **Plan original**: usar `m.customStatement(...)` dentro de `onUpgrade`.
- **Real**: el `Migrator` (parámetro `m`) en drift 2.20 NO expone `customStatement` directo. El método correcto en `onUpgrade(Migrator m, int from, int to)` es invocar el `customStatement` heredado del enclosing `FincoreDatabase`. Funcionalmente equivalente.
- **Mitigación**: ajustada la implementación a `await customStatement('CREATE INDEX ...')` (sin prefijo `m.`).

## Post-review (2026-06-19) — Fixes adicionales sobre 3 bloqueantes

El `branch-quality-review` ejecutado al cierre detectó 3 bloqueantes que se resolvieron en la misma sesión, alineado con el patrón del sprint anterior (`flutter-local-mvp`). Detalle en `engineering/quality-review/flutter-local-hardening/2026-06-19-1019-branch-quality-review.md` + sección "Post-review" en `progreso.md`. APK bumpeado a `0.3.0+31` para que pueda reinstalarse sobre `0.3.0+30` sin downgrade.

## Fase 3 — `attachedDatabase.categoriesDao`

- **Plan original**: en `EntriesDao.updateEntry`, delegar la validación de categoría activa a `attachedDatabase.categoriesDao.findActiveById(id)`.
- **Real**: el `@DriftDatabase(tables: [...])` del proyecto NO declara `daos: [AccountsDao, CategoriesDao, EntriesDao]`, por lo que el getter generado `database.categoriesDao` no existe.
- **Mitigación**: en `updateEntry` se hace una query inline equivalente: `(select(categories)..where((c) => c.id.equals(...) & c.deletedAt.isNull())).getSingleOrNull()`. Comportamiento idéntico a `findActiveById`; el helper sigue existiendo en `CategoriesDao` para uso desde la UI (RF-015) y desde futuros DAOs si se decide registrar los `@DriftAccessor` en el `@DriftDatabase`. Documentado en CLAUDE.md.
- **No es regresión**: el comportamiento esperado de RN-H03 se cumple. Refactor a `daos: [...]` queda como ítem futuro si la duplicación molesta.
