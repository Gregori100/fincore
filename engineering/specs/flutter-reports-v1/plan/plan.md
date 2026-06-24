# Plan técnico — flutter-reports-v1

## Enfoque técnico

Sprint aditivo puro. Sin schema bump, sin migraciones, sin tocar DAOs existentes. Se introduce una capa de lectura agregada nueva (`ReportsService`) consumida por una pantalla nueva (`/reports`) accesible desde el Dashboard. La filosofía sigue el patrón existente del proyecto: dominio en la capa de datos (servicio puro con SQL via `customSelect`), UI delgada que solo consume y formatea.

División en 6 fases incrementales y verificables:

- **F1**: Capa de datos (`ReportsService` + modelos `SpendingReport`/`SpendingBucket` + tests data).
- **F2**: Scaffold UI (ruta `/reports`, `ReportsScreen` con `TabBar`).
- **F3**: Primera tab (`SpendingByCategoryTab` con bar chart + tabla + filtros de fecha).
- **F4**: Acceso desde Dashboard (icono `bar_chart` en AppBar).
- **F5**: Widget tests de la pantalla y el acceso.
- **F6**: Release `0.4.0+43` (bump + build + verify APK).

`fl_chart ^0.69.0` se agrega como dep nueva. El chart se mantiene sin interactividad (sin tap/tooltip) para minimizar superficie de test y reducir riesgo de incompatibilidades.

Cualquier hallazgo de performance (R-02) se atiende reactivamente: si el reporte rinde > 200ms con la query nueva, se considera agregar `idx_journal_entries_occurred_at_kind` en un sprint dedicado de hardening (con schema bump correspondiente y respeto a la convención de `MigrationStrategy`).

## Requisitos funcionales cubiertos

- **RF-001 a RF-005** (capa de datos): se atienden en F1 — creación de `lib/data/reports.dart`, modelos `SpendingReport`/`SpendingBucket`, query SQL única con `customSelect` y readsFrom para retriguer reactivo, orden por monto desc + tiebreak alfabético.
- **RF-006, RF-007** (ruta + scaffold): F2 — `app_router.dart` extendido y `ReportsScreen` montado con `TabBar` lista para futuros reportes.
- **RF-008, RF-009, RF-010, RF-011, RF-012** (tab spending): F3 — `SpendingByCategoryTab` con header de DatePickers, card total, bar chart horizontal, tabla, estado vacío, manejo de rango inválido.
- **RF-013** (acceso desde Dashboard): F4 — `IconButton` en `AppBar` con icono `Icons.bar_chart`.
- **RF-014** (dep `fl_chart`): F3 — `pubspec.yaml` actualizado.
- **RF-015** (tests data): F1 — `test/data/reports_test.dart` con ≥10 tests cubriendo todos los RNs.
- **RF-016, RF-017** (widget tests): F5 — `test/screens/reports_screen_test.dart` + extensión de `test/screens/dashboard_screen_test.dart`.
- **RF-018, RF-019** (release): F6 — bump versión + APK + verify.

## Archivos o módulos probablemente afectados

Nuevos:

- `mobile/lib/data/reports.dart` — `ReportsService` + modelos.
- `mobile/lib/screens/reports_screen.dart` — `Scaffold` + `TabBar`.
- `mobile/lib/screens/reports/spending_by_category_tab.dart` — primera tab.
- `mobile/lib/widgets/spending_bucket_tile.dart` — item reutilizable de la tabla (probable, por confirmar si vale extraer).
- `mobile/test/data/reports_test.dart`.
- `mobile/test/screens/reports_screen_test.dart`.

Modificados:

- `mobile/lib/router/app_router.dart` — nueva ruta `/reports`.
- `mobile/lib/screens/dashboard_screen.dart` — `IconButton` nuevo en `AppBar.actions`.
- `mobile/pubspec.yaml` — agrega `fl_chart`, bump versión.
- `mobile/android/app/build.gradle.kts` — bump versionCode + versionName.
- `mobile/test/screens/dashboard_screen_test.dart` — test del nuevo icono.

Probablemente no afectados (verificar):

- `mobile/lib/data/database.dart` — sin cambios. `schemaVersion=1` se mantiene. No se agregan tablas ni columnas.
- `mobile/lib/data/financial_state.dart` — sin cambios. `ReportsService` es independiente.
- DAOs existentes — sin cambios.
- `mobile/lib/data/backup.dart` — sin cambios. El reporte no se exporta.

## Entidades y estados afectados

Sin cambios en entidades de dominio. El reporte es **lectura derivada** sobre `journal_entries` + `categories` existentes.

Nuevas entidades de presentación (no persistidas):

- `SpendingReport`: agregado `{ total, buckets, from, to }`. Inmutable.
- `SpendingBucket`: `{ categoryId, name, colorSlug, iconSlug, total, percent, count }`. Inmutable.

Estados de UI:

- `ReportsScreen`: solo selecciona tab activa. No tiene estado complejo.
- `SpendingByCategoryTab`: mantiene `from`/`to` y `Future<SpendingReport>` activo. Reacciona a cambios de pickers.

Invariantes a respetar:

- `bucket.percent ∈ [0.0, 1.0]` y `sum(buckets.percent) ≈ 1.0` cuando hay buckets.
- `bucket.total >= 0` (no hay gastos negativos por construcción de `expense`/`credit_expense`).
- `report.total == sum(buckets.total)`.
- `from <= to` siempre que se haya invocado el servicio (UI bloquea antes).

## Compatibilidad con datos y procesos existentes

- **Backup JSON v1**: sin cambios. El reporte es lectura agregada en memoria, no persiste nada. Importar un respaldo de v1 anterior funciona idéntico.
- **Datos históricos**: el reporte lee todo el journal sin discriminación de origen. Respaldos pre-pivote ya importados rinden correctamente.
- **Soft delete de categorías (RN-H03)**: el reporte agrupa entries con categoría archivada en "Sin categoría", consistente con el comportamiento ya implementado en `EntriesDao.updateEntry`. No regresión.
- **Soft delete de entries**: el filtro `journal_entries.deleted_at IS NULL` en la query evita contar entries cancelados.
- **Soft delete de cuentas**: las cuentas archivadas con entries históricos siguen contribuyendo (sus entries no se borran). Cubierto por CB-10 del spec.
- **`FinancialStateService`**: sin acoplamiento. Los streams BO/DE/CR siguen funcionando intactos.
- **`MigrationStrategy.onUpgrade`**: no se toca. El guardrail del `UnimplementedError` queda igual.

## Cambios de datos

No aplica. No hay cambios de schema, ni tablas nuevas, ni columnas nuevas, ni índices nuevos en V1.

Nota de riesgo (R-02 del spec): si la query del reporte resulta lenta con journal grande, el siguiente sprint puede agregar `idx_journal_entries_occurred_at_kind` con bump a `schemaVersion=2` y la rama correspondiente en `onUpgrade`. **No se hace en este sprint.**

## Cambios de API

No aplica. App local-first sin endpoints HTTP.

## Cambios de integraciones

Nueva dep externa: `fl_chart ^0.69.0`. Se documenta en `pubspec.yaml` y queda sujeta a la política RF-018 del proyecto (no `flutter pub upgrade` sin revisar changelogs).

Si `pub get` falla por incompatibilidad con drift o intl, fallback a `fl_chart ^0.68.0` aceptable sin replanificar (S-07 del spec).

## Cambios de UI

- Nueva ruta `/reports` no protegida por `FirstRunState`. Accesible solo desde Dashboard ya hidratado (S-05 del spec).
- `DashboardScreen.appBar.actions`: se agrega `IconButton(icon: Icons.bar_chart, tooltip: 'Reportes', onPressed: () => context.push('/reports'))` antes del icono de Settings.
- `ReportsScreen`: `Scaffold` con `AppBar` ("Reportes") y `body` que contiene `Column` con `TabBar` arriba y `Expanded(child: TabBarView)`. Una sola tab por ahora.
- `SpendingByCategoryTab`:
  - Header `Row` con dos `OutlinedButton.icon(Icons.calendar_today, ...)` para "Desde" y "Hasta". Texto del botón muestra fecha formateada (`DateFormat.yMMMd('es_MX')`).
  - `BaseCard` con total acumulado + texto "Total del período" + texto "X movimientos".
  - `SizedBox(height: chartHeight, child: BarChart(...))` con barras horizontales (`BarChartData.alignment = BarChartAlignment.spaceAround`, `rotationQuarterTurns = 1` para horizontal).
  - `ListView.separated` con `SpendingBucketTile` por bucket.
- Estado vacío: `Center` con `Icon(Icons.bar_chart_outlined, size: 64)` + textos.
- Loading: `SkeletonCard` durante el `FutureBuilder`/`StreamBuilder`.
- Tema: respeta `FincoreColors`. Color de barra usa `categoryColorFromSlug(bucket.colorSlug)`. Total se muestra en `negative` (rojo `#E05959`) porque son gastos.

## Cambios de permisos

No aplica. Single-user, sin auth.

## Riesgos técnicos

- **RT-01**: `fl_chart` mantiene `^0.69.0` pero el ecosistema cambia rápido. Validar con `flutter pub get` que resuelve sin conflictos. Si falla, downgrade documentado.
- **RT-02**: La query con LEFT JOIN puede degradar con journal grande (1000+ entries). Mitigación reactiva: medir con `Stopwatch` ad-hoc; si > 200ms, abrir sprint de índice.
- **RT-03**: Material 3 `DatePicker` abre un dialog modal — los widget tests deben usar `pumpAndSettle` y verificar cierre del dialog antes de assert (lección DV-1 v1).
- **RT-04**: Si el `BarChart` rinde con interactividad por default (tooltip o tap), los tests pueden colgar en `pumpAndSettle` por animaciones perpetuas. Forzar `BarTouchData(enabled: false)`.
- **RT-05**: `DateTime` en Dart respeta TZ del dispositivo. Al construir `from`/`to` con `DateTime(year, month, day)` se usa local TZ, lo cual es lo que queremos (S-01). No usar `DateTime.utc(...)`.
- **RT-06**: El `customSelect` necesita `readsFrom: {journalEntries, categories}` para retriguer reactivo. Sin esto, el reporte no se actualiza tras agregar/borrar movimientos mientras la pantalla está abierta.
- **RT-07**: Si el chart se rinde con `LayoutBuilder` para calcular alto dinámico, conflictos con `ListView` adentro de `TabBarView`. Probar con alto fijo primero, ajustar solo si layout rompe.

## Estrategia de pruebas

Capa data en F1 (no avanzar a UI sin tests data verdes). Capa UI en F5. Test plan completo detallado en `test-plan.md`.

- **Tests unitarios de `ReportsService`**: ≥10 cases sobre BD in-memory cubriendo RN-R01 hasta RN-R08 + casos borde CB-01 hasta CB-10 cuando aplique.
- **Widget tests de `/reports`**: ≥3 cases (vacío, render con datos, cambio de fecha repega).
- **Widget test del Dashboard**: ≥1 case (icono bar_chart navega).
- **Regresión**: la suite actual de 126 tests debe quedar verde tras los cambios.
- **Smoke manual**: instalar APK release en el Redmi y validar el flujo real.

`flutter analyze` debe quedar en 0 errores / 0 warnings al final.

## Estrategia de rollback

El sprint es aditivo puro. Si algo se rompe en QA después del merge a `main`:

- **Opción A — revert completo**: `git revert <hash>` del commit del sprint. Sin pérdida de datos del usuario, sin migración a desandar.
- **Opción B — patch parcial**: si solo falla el chart pero la data es correcta, agregar flag temporal `showChart = false` y emitir hotfix `0.4.0+44` con solo la tabla. La capa data queda intacta.
- **APK ya instalado**: el usuario puede reinstalar el `0.3.10+42` previo (downgrade) usando el flag `-d` de adb si guardó el APK; los datos sobreviven porque schemaVersion no cambió.

## Orden sugerido de implementación

1. **F1 — Capa de datos**:
   1.1. Crear `mobile/lib/data/reports.dart` con `ReportsService`, `SpendingReport`, `SpendingBucket`.
   1.2. Implementar `spendingByCategory({from, to})` con `customSelect` + `readsFrom`.
   1.3. Crear `mobile/test/data/reports_test.dart` con ≥10 cases. Correr `flutter test test/data/reports_test.dart` hasta verde.
   1.4. Correr toda la suite `flutter test` para confirmar 0 regresiones.
2. **F2 — Scaffold UI**:
   2.1. Agregar `fl_chart: ^0.69.0` a `pubspec.yaml` (sección `dependencies`). Correr `flutter pub get` y validar resolución.
   2.2. Crear `mobile/lib/screens/reports_screen.dart` con `Scaffold` + `TabBar` (una tab placeholder).
   2.3. Registrar ruta `/reports` en `app_router.dart`.
   2.4. `flutter analyze` debe quedar limpio.
3. **F3 — Primera tab**:
   3.1. Crear `mobile/lib/screens/reports/spending_by_category_tab.dart` con header de fechas + estado vacío básico.
   3.2. Integrar `FutureBuilder<SpendingReport>` que invoca el service.
   3.3. Integrar `BarChart` horizontal con `BarTouchData(enabled: false)`.
   3.4. Integrar `ListView` con `SpendingBucketTile`.
   3.5. Manejar caso `from > to` con SnackBar warning.
   3.6. Iterar visualmente con `flutter run -d linux`.
4. **F4 — Acceso desde Dashboard**:
   4.1. Agregar `IconButton` con icono `bar_chart` en el AppBar del `DashboardScreen`.
   4.2. Verificar visualmente que navega y vuelve correctamente.
5. **F5 — Widget tests**:
   5.1. Crear `mobile/test/screens/reports_screen_test.dart` con tests de vacío + render con datos + cambio de fecha.
   5.2. Extender `mobile/test/screens/dashboard_screen_test.dart` con test del icono.
   5.3. Correr `flutter test` hasta 100% verde.
6. **F6 — Release**:
   6.1. Bump `pubspec.yaml` a `0.4.0+43`.
   6.2. Bump `android/app/build.gradle.kts` a `versionCode=43`, `versionName="0.4.0"`.
   6.3. `flutter analyze` limpio.
   6.4. `flutter build apk --release --split-per-abi`.
   6.5. `scripts/verify-apk.sh build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` → exit 0.
   6.6. Sugerir comando de instalación a Diego.
7. **Validación de calidad**:
   7.1. Invocar `/branch-quality-review` antes del commit formal de sprint.
   7.2. Resolver hallazgos críticos antes del commit.
8. **Commit + push**: Diego ejecuta el push manual.

## Casos borde que condicionan la solución

Más allá de los CB-01 a CB-10 del spec:

- **CB-extra-01**: Suite de tests del Dashboard ya valida estructura del AppBar. El nuevo `IconButton` puede romper el conteo de actions previo. Verificar el test existente antes de extenderlo y ajustar el expect si es necesario.
- **CB-extra-02**: La query con `GROUP BY category_id` deja `NULL` agrupado correctamente en SQLite (NULL == NULL en GROUP BY desde SQLite 3.x). Verificar en test que el bucket "Sin categoría" agrega múltiples entries con `categoryId = NULL`.
- **CB-extra-03**: Entry con `categoryId` válido pero la categoría tiene `applies_to = 'income'` (mal-categorizada por flow viejo) — la query no filtra por `applies_to`, así que el bucket se forma con esa categoría. Es coherente con la filosofía libreta libre. Documentar como supuesto si surge.
- **CB-extra-04**: Locale `es_MX` para fechas en `OutlinedButton` y `DateFormat`. Asegurar que el `MaterialApp` ya tiene los delegates de locale (verificar `lib/main.dart` o donde se monta `MaterialApp.localizationsDelegates`).
- **CB-extra-05**: Si el chart usa colores del slug de categoría y dos categorías comparten el mismo slug (caso real, los colores son 10 reusables), las barras serán del mismo color pero los nombres distintos. UX aceptable, no es bug.

## Preguntas o supuestos que siguen afectando la implementación

Sin preguntas bloqueantes abiertas. Los supuestos críticos quedan documentados en `spec.md` (S-01 a S-08) y se respetan en el plan.

Decisiones técnicas tomadas durante la planeación (no requieren confirmación):

- **DT-01**: `BarTouchData(enabled: false)` para minimizar superficie de test.
- **DT-02**: Alto del chart fijo en `min(buckets.length * 48, 400)` px. Reevaluar tras prueba visual.
- **DT-03**: `SpendingBucketTile` se extrae a widget propio solo si se reutiliza; si no, queda inline.
- **DT-04**: Default `to` = `DateTime.now()` truncado a fin de día (no fin de mes). Refleja "hasta ahora" en el mes corriente.
- **DT-05**: Sin guardar último rango entre sesiones (S-04 del spec ya lo confirma).
- **DT-06**: El reporte usa `Future` simple, no `Stream`, en la primera versión. Si se quiere reactividad automática al agregar movimientos, migrar a `Stream` con `readsFrom` en sprint siguiente. Por ahora se invoca explícitamente al cambiar fechas, y la pantalla se reabre tras agregar movimiento (volver a Dashboard + push reentra).
  - **Reevaluar en F3**: si la reactividad reactiva es trivial con `customSelect.watch(...).map(...)`, hacerla desde V1. Si requiere refactor invasivo, queda para sprint siguiente.
