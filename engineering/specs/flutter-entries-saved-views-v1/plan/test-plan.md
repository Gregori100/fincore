# Test plan — flutter-entries-saved-views-v1

## Casos borde detectados

Inventario completo:

- **CB-T01** — Migración 2 → 3: BD existente con datos del usuario.
  Tras migrar, `accounts`, `categories`, `journal_entries` intactos +
  tabla nueva `saved_views` vacía.
- **CB-T02** — Nombre vacío / solo espacios → rechazado con
  `invalid_name`.
- **CB-T03** — Nombre > 50 chars → rechazado.
- **CB-T04** — Nombre duplicado case-insensitive ("Comida" vs
  "comida") → rechazado con `duplicate_name`.
- **CB-T05** — Nombre con espacios externos → trim antes de validar
  y guardar.
- **CB-T06** — Nombre con caracteres especiales (emoji, acentos) →
  aceptado.
- **CB-T07** — `findById` con id inexistente → retorna null (no
  lanza).
- **CB-T08** — `rename` de id inexistente → lanza `not_found`.
- **CB-T09** — `delete` de id inexistente → lanza `not_found`.
- **CB-T10** — `watchAll` reactivo: insert → stream emite con la
  nueva vista. Delete → stream emite con la lista sin la vista.
- **CB-T11** — Orden de `listAll`/`watchAll`: created_at DESC (más
  recientes arriba).
- **CB-T12** — Serializer round-trip: `EntriesFilters` complejo
  (kinds + accountIds + categoryIds + minAmount + custom date) →
  toSavedJson → fromSavedJson → coincide field por field.
- **CB-T13** — Serializer rolling: `EntriesFilters` con preset
  `thisMonth` guardado en junio. Al deserializar en julio, `from/to`
  se recalculan a julio.
- **CB-T14** — Serializer custom: `EntriesFilters` con preset
  `custom` y `from=2026-05-01, to=2026-05-31`. Al deserializar
  cualquier mes, mantiene esas fechas exactas.
- **CB-T15** — JSON corrupto: `fromSavedJson({})` → retorna
  `EntriesFilters.thisMonth()` (fallback).
- **CB-T16** — JSON con campos extra: ignorados sin error.
- **CB-T17** — Aplicar vista con accountId/categoryId archivado: el
  panel ya tolera (sprint anterior).
- **CB-T18** — `wipeAll()` borra también `saved_views`.
- **CB-T19** — Backup/import: las vistas locales sobreviven (no están
  en el JSON v1).

## Pruebas unitarias necesarias

### En `mobile/test/data/saved_views_dao_test.dart` (nuevo)

Grupo `SavedViewsDao — CRUD`:

- **UT-01**: `create` + `findById` retorna la vista creada con id no
  vacío.
- **UT-02**: `create` con name vacío → lanza `invalid_name`.
- **UT-03**: `create` con name > 50 chars → lanza `invalid_name`.
- **UT-04**: `create` con name duplicado case-insensitive → lanza
  `duplicate_name`. Verificar "Comida" vs "comida".
- **UT-05**: `rename` actualiza el name. Validar también que
  `rename` rechaza duplicados.
- **UT-06**: `delete` borra físicamente.
- **UT-07**: `listAll` retorna en orden created_at DESC.
- **UT-08**: `watchAll` emite tras `create` y tras `delete`.

Grupo `SavedViewsDao — errores tipados`:

- **UT-09**: `rename` con id inexistente → lanza `not_found`.
- **UT-10**: `delete` con id inexistente → lanza `not_found`.

### En `mobile/test/data/entries_filters_saved_test.dart` (nuevo)

Grupo `EntriesFilters — toSavedJson/fromSavedJson`:

- **UT-11**: round-trip preserva todos los campos.
- **UT-12**: preset `thisMonth` guardado en junio se aplica como
  `thisMonth` en julio (recalcula).
- **UT-13**: preset `custom` guarda `from`/`to` ISO8601 y los
  preserva exactos en deserialización.
- **UT-14**: `fromSavedJson({})` → fallback a `thisMonth`.
- **UT-15**: campos extra en el JSON se ignoran sin error.
- **UT-16**: `fromSavedJson` con `kinds` lista de strings, parsea
  bien.

### En `mobile/test/data/database_migration_test.dart` (nuevo)

- **UT-17**: crear BD en `schemaVersion = 2` con seed (Bolsa + 1
  cuenta + 1 categoría + 1 entry) → migrar a 3 → tabla `saved_views`
  existe + datos viejos intactos.

## Pruebas de integración o API necesarias

No aplica (sin red).

## Pruebas de UI o flujo necesarias

### En `mobile/test/screens/saved_views_flow_test.dart` (nuevo)

- **WT-01**: Guardar vista desde el panel: abrir filtros → configurar
  filtro de kind "Gasto" → tap "Guardar vista" → escribir "Test View"
  → tap Guardar → snackbar éxito + vista persistida.
- **WT-02**: Aplicar vista desde AppBar: con 1 vista sembrada via
  DAO, tap icono bookmark → sheet con la vista → tap en la vista →
  filtros aplicados + sheet cerrado.
- **WT-03**: Empty state: BD sin vistas → tap icono bookmark → sheet
  muestra "No tenés vistas guardadas todavía.".

### En `mobile/test/screens/entries_filters_screen_test.dart` (probable
extensión)

- WT-04 (opcional): smoke de que el botón "Guardar vista" renderea
  dentro del panel.

## Pruebas de permisos y seguridad

No aplica.

## Pruebas de datos, migración o compatibilidad

- **DT-01** (cubierto por UT-17): migración 2 → 3.
- **DT-02**: backup round-trip con vistas locales: export → wipe →
  import → vistas locales **borradas** porque wipeAll las eliminó.
  Comportamiento esperado RN-V10.

## Pruebas de regresión sobre flujos existentes

- **RG-01**: `flutter test` completo verde (279 previos + 17 nuevos =
  ~296).
- **RG-02**: panel de filtros con filtros manuales sigue funcionando.
- **RG-03**: lista de `/entries` sigue refrescando con filtros
  aplicados.
- **RG-04**: `EntriesFilters.serialize/parse` (query params) sigue
  funcionando — no afectado por los nuevos métodos JSON.

## Pruebas manuales o smoke tests necesarios

Tras APK release:

- **SM-01**: Instalar APK encima de versión anterior → migración
  automática, BD sigue funcionando, vistas inicialmente 0.
- **SM-02**: Configurar filtros y guardar vista "Comida grandes" →
  vista aparece en el sheet.
- **SM-03**: Cambiar a otros filtros → tap bookmark → seleccionar
  "Comida grandes" → filtros se restauran.
- **SM-04**: Crear vista con `thisMonth` en junio → esperar a julio
  (o cambiar fecha del cel) → aplicar vista → rango = julio.
- **SM-05**: Tap ⋮ en una vista → "Renombrar" → editar → guardar.
- **SM-06**: Tap ⋮ → "Eliminar" → confirmar → vista desaparece.
- **SM-07**: Intentar guardar vista con nombre duplicado → snackbar
  error.
- **SM-08**: Settings → "Reiniciar cuenta" → vistas también borradas.

## Datos de prueba recomendados

Para tests data del DAO: BD limpia in-memory con drift. Cada test
crea sus vistas necesarias.

Para tests del serializer: helpers que construyen `EntriesFilters`
con combinaciones específicas.

Para widget tests: `pumpFincoreApp` con seed minimal + helpers para
abrir el panel o tappear el icono bookmark.

## Comandos o validaciones locales sugeridas

```bash
cd mobile

# DAO + serializer durante F2/F3:
flutter test test/data/saved_views_dao_test.dart
flutter test test/data/entries_filters_saved_test.dart

# Migración durante F1:
flutter test test/data/database_migration_test.dart

# UI durante F4/F5/F6:
flutter test test/screens/saved_views_flow_test.dart

# Suite completa antes de commit:
flutter test

# Analyze:
flutter analyze

# Build APK release:
flutter build apk --release --split-per-abi

# Verify APK:
bash ../scripts/verify-apk.sh
```

## Criterios mínimos para aprobar la implementación

- [ ] 10 tests data del DAO pasan.
- [ ] 6 tests del serializer pasan.
- [ ] 1 test de migración pasa.
- [ ] 3 widget tests del flow pasan.
- [ ] `flutter test` completo verde (~296 tests).
- [ ] `flutter analyze` 0 errores.
- [ ] APK `0.10.0+62` construido + `verify-apk.sh` OK.
- [ ] Migración 2 → 3 validada con APK encima de versión vieja en
      cel real (smoke crítico — primer schema bump).
- [ ] `wipeAll()` borra también `saved_views`.
- [ ] Smoke manual SM-01 a SM-08 (Diego).

## Validación final recomendada

Tras la implementación cerrada, ejecutar la skill
`branch-quality-review` para revisión exhaustiva (especialmente del
schema bump y la migración).

Si la skill no está disponible, checklist equivalente:

- [ ] Migración aditiva, no destructiva (verificar SQL).
- [ ] `wipeAll()` cubre la nueva tabla.
- [ ] `fromSavedJson` tolera JSON corrupto sin lanzar.
- [ ] `name` único case-insensitive validado en BD, no solo en UI.
- [ ] Sin print() ni TODO colgados.
