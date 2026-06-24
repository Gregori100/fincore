# Test plan — flutter-reports-v1

## Casos borde detectados

Más allá de los CB-01 a CB-10 del `spec.md`, la planeación detectó:

- **CB-T01**: BD con seed mínimo (solo Bolsa + 10 categorías) y sin entries → `ReportsService.spendingByCategory` retorna `total = 0, buckets = []`. UI muestra estado vacío.
- **CB-T02**: Múltiples entries con `categoryId = NULL` en el rango → un único bucket "Sin categoría" con suma agregada y `count` correcto.
- **CB-T03**: Múltiples entries con `categoryId` distintos pero todos apuntando a categorías archivadas (RN-H03) → todos colapsan en bucket "Sin categoría" (no aparecen como buckets separados por nombre histórico).
- **CB-T04**: Mezcla de categoría activa + categoría archivada con mismo nombre — categoría archivada va a "Sin categoría", activa al bucket propio. Sin colisión por nombre.
- **CB-T05**: Entry `expense` exactamente a `occurred_at = from 00:00:00.000` → cuenta (límite inclusivo).
- **CB-T06**: Entry `expense` exactamente a `occurred_at = to 23:59:59.999` → cuenta (límite inclusivo).
- **CB-T07**: Entry `expense` a `occurred_at = to 23:59:59.999 + 1ms` → NO cuenta.
- **CB-T08**: Un `transfer` con origen `Bolsa` y destino `Banamex` (ambos cash/debit) con `categoryId` pegado por flujo viejo → NO cuenta como gasto.
- **CB-T09**: Un `debt_payment` con `categoryId` pegado → NO cuenta como gasto (es pago de tarjeta).
- **CB-T10**: Un `income` con `categoryId` pegado → NO cuenta como gasto.
- **CB-T11**: Un `expense` con `deleted_at IS NOT NULL` (cancelado) → NO cuenta.
- **CB-T12**: Dos buckets con `total` igual y nombres distintos → tiebreak alfabético asc.
- **CB-T13**: Un único bucket → `percent = 1.0`, chart renderiza una sola barra al 100%.
- **CB-T14**: Tres buckets `total` 100, 200, 700 → `percent` 0.1, 0.2, 0.7. Suma == 1.0 ± epsilon.
- **CB-T15**: `from = to` (mismo día) → válido. La query usa rango inclusivo, así que captura todos los entries del día.
- **CB-T16**: `from > to` → la UI bloquea antes de invocar el service y muestra SnackBar. No se llega a una query con rango inválido.
- **CB-T17**: Importar respaldo JSON v1 con `BackupService.importFromJson` mientras `/reports` está abierta. El `wipeAll + insert` corre dentro de una transacción, así que la query no ve estado intermedio. La query se debe reinvocar tras cierre de la transacción (si se usa Stream con `readsFrom`).
- **CB-T18**: 30+ buckets en el rango → la lista renderiza con scroll vertical; el chart con alto dinámico ≤ 400px también scrollea si hay overflow.
- **CB-T19**: Cuenta con `is_protected = true` (Bolsa) tiene entries `expense` → cuentan normalmente. No hay distinción de cuenta protegida en el reporte.
- **CB-T20**: Cuenta archivada (`accounts.deleted_at IS NOT NULL`) con entries históricos → entries siguen contando. No filtramos por estado de cuenta.

## Pruebas unitarias necesarias

Archivo: `mobile/test/data/reports_test.dart`. BD in-memory siguiendo patrón existente (override `sqlite_override.dart`).

Mínimo 12 tests:

- **UT-01**: BD vacía → `total = 0, buckets = []`.
- **UT-02**: Único `expense` de $1000 categoría "Comida" → 1 bucket con `total = 1000, percent = 1.0, count = 1`.
- **UT-03**: Dos `expense` mismas categoría → bucket único con `total = suma, count = 2`.
- **UT-04**: Dos `expense` distinta categoría → 2 buckets, orden por monto desc.
- **UT-05**: Empate de monto en dos buckets → tiebreak alfabético asc por nombre.
- **UT-06**: `expense + credit_expense` mismo rango → ambos cuentan, agregados por categoría.
- **UT-07**: `transfer + debt_payment + income` con categoryId pegado → ninguno cuenta (CB-T08, CB-T09, CB-T10).
- **UT-08**: Entry con `categoryId = null` → bucket "Sin categoría" con color `gray` + icono `category_outlined`.
- **UT-09**: Entry con categoría archivada → bucket "Sin categoría" (RN-R04).
- **UT-10**: Mezcla NULL + archivadas → todas en mismo bucket "Sin categoría" (agregadas).
- **UT-11**: Entry fuera del rango (occurred_at < from o > to) → NO cuenta.
- **UT-12**: Entry soft-deleted (`journal_entries.deleted_at IS NOT NULL`) → NO cuenta (CB-T11).
- **UT-13**: Limite inclusivo `from 00:00:00.000` y `to 23:59:59.999` → cuentan (CB-T05, CB-T06).
- **UT-14**: Entry a `to + 1ms` → NO cuenta (CB-T07).
- **UT-15**: `from = to` → rango válido de un día (CB-T15).
- **UT-16**: `percent` suma a 1.0 ± 1e-9 con buckets múltiples.
- **UT-17**: `report.total == sum(buckets.total)` invariante.

## Pruebas de integración o API necesarias

App local-first sin API. La integración real es `EntriesDao.registerExpense` + `ReportsService.spendingByCategory` sobre la misma BD.

- **IT-01**: Registrar 5 expenses con `EntriesDao` en distintas categorías + 1 transfer + 1 income. Invocar reporte. Validar que solo los 5 expenses cuentan, agrupados correctamente.
- **IT-02**: Registrar expense, cancelarlo con `EntriesDao.cancel`, invocar reporte → entry no aparece (validación end-to-end del filtro soft-delete).
- **IT-03**: Registrar expense con categoría, archivar la categoría con `CategoriesDao.archive`, invocar reporte → bucket va a "Sin categoría" sin nombre histórico.

Estos casos se pueden incluir dentro del mismo archivo `reports_test.dart` como group "ReportsService — integración con DAOs".

## Pruebas de UI o flujo necesarias

Archivo: `mobile/test/screens/reports_screen_test.dart`. Usa `pumpFincoreApp` del harness existente.

- **WT-01**: BD con seed básico, push a `/reports`, valida que `ReportsScreen` se monta con `AppBar` "Reportes" + `TabBar` con tab "Gasto por categoría". Estado vacío visible.
- **WT-02**: BD seeded con 3 expenses en 2 categorías distintas, push a `/reports`. Valida que el bar chart renderiza (find `BarChart`), tabla renderiza con 2 `SpendingBucketTile` (o equivalente), total formateado correctamente.
- **WT-03**: Cambio de fecha "Desde" — abrir `DatePicker`, seleccionar fecha pasada, cerrar. La vista repega la query. Valida con `await pumpAndSettle` y buscar el monto nuevo.
- **WT-04** (opcional, si timing lo permite): Selección inválida `from > to` → SnackBar warning visible + rango previo preservado.

Archivo: `mobile/test/screens/dashboard_screen_test.dart` (extensión).

- **WT-05**: Dashboard con seed básico — tap del icono `bar_chart` del AppBar → navegación a `/reports` exitosa (find `ReportsScreen` después del tap).

## Pruebas de permisos y seguridad

No aplica. Single-user, sin auth, sin permisos.

## Pruebas de datos, migración o compatibilidad

- **MG-01**: BD con `schemaVersion = 1` (estado actual) → abrir app no dispara `onUpgrade` (no hay bump). Verificar que la app rinde igual con BD pre-sprint.
- **MG-02**: Importar respaldo JSON v1 antes del sprint → abrir reporte → debe contar los entries importados correctamente.

Estos se pueden cubrir como smoke manual, no requieren test automatizado.

## Pruebas de regresión sobre flujos existentes

La suite actual es 126 tests verdes. Tras el sprint debe seguir verde en su totalidad. Áreas con mayor riesgo de regresión:

- **RG-01**: Dashboard widget tests (cambio en AppBar.actions puede romper assertions de structure).
- **RG-02**: Toda la suite de `entries_dao_test.dart` y `financial_state_test.dart` — debe quedar intacta. `ReportsService` no toca esos paths.
- **RG-03**: Backup round-trip (`backup_test.dart`) — sin cambios.
- **RG-04**: Router redirect (`first_run_state` flow) — sin cambios.

Validación: `flutter test` final con 126 + nuevos tests = 139+ verdes.

## Pruebas manuales o smoke tests necesarios

Tras instalar `0.4.0+43` en el Redmi:

- **SM-01**: Abrir app → Dashboard. Confirmar que el icono `bar_chart` aparece en el AppBar.
- **SM-02**: Tap icono → navegar a Reportes. Confirmar tab "Gasto por categoría" activa.
- **SM-03**: Confirmar default = primer día del mes corriente → hoy.
- **SM-04**: Verificar que los movimientos reales registrados durante el mes aparecen en el reporte.
- **SM-05**: Cambiar "Desde" al primer día del mes anterior y "Hasta" al último día del mes anterior → ver reporte del mes pasado.
- **SM-06**: Validar que ningún `transfer`/`debt_payment`/`income` aparece en el chart o tabla.
- **SM-07**: Volver al Dashboard (back nativo del cel) → tap Settings → confirmar `0.4.0+43` en "Acerca de".
- **SM-08**: Smoke de regresión rápido: registrar un movimiento nuevo, volver a Reportes → confirmar que ya aparece.

## Datos de prueba recomendados

Para los unitarios (`reports_test.dart`):

- Bolsa por seed default + 2-3 cuentas debit/credit creadas manualmente en el test.
- 3-5 categorías expense activas + 1-2 archivadas.
- Entries variados:
  - `expense` $100 categoría "Comida" 2026-06-10.
  - `expense` $200 categoría "Transporte" 2026-06-15.
  - `expense` $150 categoría null 2026-06-12.
  - `expense` $300 categoría archivada 2026-06-08.
  - `credit_expense` $500 categoría "Comida" 2026-06-20.
  - `transfer` $1000 Bolsa→Banamex 2026-06-11 (no debe contar).
  - `debt_payment` $400 Bolsa→Visa 2026-06-25 (no debe contar).
  - `income` $5000 categoría "Salario" 2026-06-01 (no debe contar).

Para los widget tests, reutilizar el `seed` callback de `pumpFincoreApp` con un set chico (≤5 entries) que demuestre la agrupación.

## Comandos o validaciones locales sugeridas

```bash
cd mobile

# Tras F1 (capa data):
flutter test test/data/reports_test.dart

# Tras F1 completo (validar 0 regresiones):
flutter test

# Tras F2 (scaffold UI):
flutter pub get
flutter analyze

# Tras F3 (primera tab):
flutter run -d linux  # iteración visual

# Tras F5 (widget tests):
flutter test

# Tras F6 (release):
flutter analyze  # 0 errores, 0 warnings
flutter build apk --release --split-per-abi
scripts/verify-apk.sh build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

## Criterios mínimos para aprobar la implementación

- ≥12 tests unitarios de `ReportsService` verdes (cubriendo RN-R01 a RN-R08).
- ≥3 widget tests de `/reports` verdes + 1 widget test del icono nuevo del Dashboard.
- Suite total ≥139 tests verdes (126 actual + 13 nuevos mínimo).
- `flutter analyze`: 0 errores, 0 warnings (hints info preexistentes tolerados).
- `scripts/verify-apk.sh` retorna exit 0 con versionCode=2043.
- APK release instalable en el Redmi sin downgrade error.
- Smoke manual SM-01 a SM-08 pasados (Diego confirma).
- Sin regresión en la suite existente (RG-01 a RG-04).

## Validación final recomendada

Antes del commit formal del sprint, invocar `/branch-quality-review` para revisión exhaustiva de:

- Inconsistencias en RN-R*/RF-* entre spec.md y código entregado.
- Patrones de testing usados (¿se respetó la convención DV-5 de no `invalidateAll` en tearDown?).
- Documentos pendientes (cierre.md en `implementation/` dentro de `engineering/specs/flutter-reports-v1/`).
- Hints de `flutter analyze` introducidos por el sprint.
- Tamaño del APK release (impacto de `fl_chart`).
- Cumplimiento de política RF-018 sobre `pub upgrade`.

El reporte de `branch-quality-review` se genera en `engineering/quality-review/<slug>/`, no en `implementation/`.

Hallazgos críticos deben resolverse antes del commit. Hallazgos no críticos pueden quedar documentados como "diferidos" en `implementation/pendientes.md` con justificación.
