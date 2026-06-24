# flutter-reports-v1 — Pantalla de reportes con primer reporte "Gasto por categoría"

## Resumen

Introducir una nueva pantalla `/reports` con `TabBar` extensible que entrega el primer reporte de la app: **"Gasto por categoría"** en un rango de fechas libre, con bar chart horizontal + tabla. Es el primer feature visible al usuario después de cerrar el ciclo de hardening + testing. Habilita análisis del consumo real registrado en el journal.

## Problema a resolver

Diego registra movimientos diariamente pero la app actual solo muestra balances agregados (BO/DE/CR) y lista cruda de entries. No hay forma de responder preguntas como **"¿en qué se me fue la plata el mes pasado?"** sin exportar el JSON y procesarlo afuera. Esto rompe la promesa local-first de "el archivo es el producto" porque la lectura del producto exige herramienta externa.

## Objetivo

Entregar un primer reporte agregado consultable desde la app que responda **"cuánto gasté en cada categoría en X período"**, dejando armado el shell de UI (`/reports` con tabs) y la capa de datos (`ReportsService`) para futuros sprints de cashflow, saldo a fecha, top movimientos.

## Alcance

- Nueva ruta `/reports` con `TabBar` de Material 3.
- Primera tab: **"Gasto por categoría"**.
- Filtros: dos `DatePicker` (desde / hasta). Default al abrir: primer día → último día del mes en curso.
- Total acumulado del rango como header visible arriba del chart.
- Bar chart horizontal con `fl_chart`: una barra por categoría, ordenado por monto desc.
- Tabla debajo del chart con: badge de categoría (`CategoryBadge`) + nombre + monto + % del total.
- Estado vacío explícito: "No hay gastos en el rango seleccionado".
- Acceso: ítem nuevo en el AppBar del Dashboard (icono `bar_chart` + tooltip "Reportes").
- Nueva clase `ReportsService` en `lib/data/reports.dart`, separada de `FinancialStateService`.
- Tests data + widget.
- Release `0.4.0+43`.

## Fuera de alcance

- Otros reportes (cashflow mensual, saldo a fecha, top movimientos) — futuros sprints.
- Export del reporte a CSV/PDF.
- Comparativas inter-período (mes vs mes, año vs año).
- Drill-down: tap en categoría no abre detalle de entries del rango (versión 1 es solo lectura agregada).
- Presupuestos por categoría (`monthly_limit` queda dormido).
- Reportes por cuenta o tipo de cuenta.
- Persistencia del rango elegido entre sesiones (cada apertura empieza en mes en curso).

## Reglas de negocio

- **RN-R01**: Solo cuentan los `kind ∈ { expense, credit_expense }` para "gasto". Los `transfer` y `debt_payment` son movimientos internos y se excluyen del total.
- **RN-R02**: `income` se excluye totalmente del reporte "Gasto por categoría".
- **RN-R03**: Entries con `categoryId = NULL` se agrupan en bucket especial **"Sin categoría"**.
- **RN-R04**: Entries cuyo `categoryId` apunta a una categoría archivada (`deleted_at IS NOT NULL`) caen también en el bucket **"Sin categoría"**, consistente con RN-H03 ya aplicada en `EntriesDao.updateEntry`.
- **RN-R05**: El filtro de rango es **inclusivo en ambos extremos**: `occurred_at >= from 00:00:00` y `occurred_at <= to 23:59:59` (zona local del dispositivo).
- **RN-R06**: El rango debe cumplir `from <= to`. Si el usuario elige `from > to`, la UI bloquea (no se llama al service).
- **RN-R07**: Entries soft-deleted (`deleted_at IS NOT NULL` en `journal_entries`) NO se cuentan.
- **RN-R08**: El bucket "Sin categoría" usa color/icono neutros (`gray` + `category_outlined`) y nombre literal "Sin categoría". No se confunde con categoría archivada de nombre similar.

## Requisitos funcionales

- **RF-001**: Crear `lib/data/reports.dart` con `ReportsService` y método `spendingByCategory({required DateTime from, required DateTime to})` que retorne `Future<SpendingReport>`.
- **RF-002**: Definir `SpendingReport` con `total: int` (centavos), `buckets: List<SpendingBucket>`, `from: DateTime`, `to: DateTime`.
- **RF-003**: Definir `SpendingBucket` con `categoryId: String?` (null para "Sin categoría"), `name: String`, `colorSlug: String`, `iconSlug: String`, `total: int`, `percent: double` (0.0–1.0), `count: int`.
- **RF-004**: Query SQL única vía `customSelect` que junte `journal_entries` LEFT JOIN `categories` filtrando por `kind IN ('expense', 'credit_expense')`, `journal_entries.deleted_at IS NULL`, `occurred_at BETWEEN ... AND ...`, y agregue `SUM(amount)` + `COUNT(*)` por `category_id` (o NULL si categoría archivada).
- **RF-005**: Buckets ordenados por `total` desc; en caso de empate, alfabético por `name` asc.
- **RF-006**: Crear ruta `/reports` en `lib/router/app_router.dart` apuntando a `ReportsScreen`.
- **RF-007**: Crear `lib/screens/reports_screen.dart` con `Scaffold` + `AppBar` "Reportes" + `TabBar` con una sola tab por ahora ("Gasto por categoría"). Estructura preparada para agregar tabs.
- **RF-008**: Crear `lib/screens/reports/spending_by_category_tab.dart` con:
  - Header: dos `OutlinedButton` con icono de calendario que abren `showDatePicker` (uno "Desde", otro "Hasta").
  - Card de total: monto formateado + texto "Total del período" + count agregado de movimientos.
  - `SizedBox` con `BarChart` horizontal de `fl_chart` (alto fijo: `min(buckets.length * 48, 400)` px).
  - `ListView` con `SpendingBucketTile` por bucket: badge + nombre + monto + % del total.
- **RF-009**: Default del rango al abrir: `from = primer día del mes corriente 00:00`, `to = hoy 23:59:59`. (Decisión: usar "hoy" como to-end en lugar de "fin de mes" para que la lectura del mes en curso refleje lo registrado hasta ahora, no proyecte vacío hacia adelante).
- **RF-010**: El cambio de fechas reinvoca `spendingByCategory` y reconstruye chart + tabla. UI muestra loader (`Skeleton`) durante el await.
- **RF-011**: Estado vacío (sin buckets): card centrado con icono + texto "No hay gastos en el rango seleccionado" + sugerencia "Ajustá las fechas o registrá un movimiento".
- **RF-012**: Manejar selección inválida `from > to`: tras cerrar el DatePicker, si `from > to`, mostrar `SnackBar` warning "El rango no es válido. Revisá las fechas." y revertir al rango previo.
- **RF-013**: Agregar `IconButton` con icono `Icons.bar_chart` en el `AppBar` del `DashboardScreen` que haga `context.push('/reports')`. Tooltip "Reportes".
- **RF-014**: Agregar `fl_chart: ^0.69.0` al `pubspec.yaml` (sección `dependencies`).
- **RF-015**: Tests data en `test/data/reports_test.dart`:
  - Rango vacío → total 0, buckets vacíos.
  - `expense` simple → bucket único con monto correcto.
  - `expense + credit_expense` → ambos cuentan.
  - `transfer + debt_payment + income` → ignorados.
  - Entry con `categoryId = null` → bucket "Sin categoría".
  - Entry con categoría archivada → bucket "Sin categoría" (RN-R04).
  - Entry fuera del rango → no cuenta.
  - Soft-deleted entry → no cuenta.
  - Orden por monto desc + tiebreak alfabético.
  - `percent` suma 1.0 ± epsilon cuando hay buckets.
- **RF-016**: Widget tests en `test/screens/reports_screen_test.dart`:
  - Render `/reports` con BD vacía → estado vacío.
  - Seed con `expense` en distintas categorías → render del chart + tabla con buckets ordenados.
  - Cambio de "Desde" repega la query y actualiza vista.
- **RF-017**: Widget test en `test/screens/dashboard_screen_test.dart`: el AppBar tiene icono bar_chart y al tappearlo navega a `/reports`.
- **RF-018**: Bump versión a `0.4.0+43` en `pubspec.yaml` + `android/app/build.gradle.kts` (versionCode=43, versionName="0.4.0").
- **RF-019**: Build APK release con `--split-per-abi` + validar con `scripts/verify-apk.sh`.

## Casos principales

- **C-01**: Diego abre `/reports`, ve gasto por categoría del mes en curso (default), identifica que "Comida" lidera, decide ajustar consumo el resto del mes.
- **C-02**: Diego cambia "Desde" al primer día del mes anterior y "Hasta" al último día del mes anterior, ve el reporte del mes pasado para comparar mentalmente con el actual.
- **C-03**: Diego abre la pantalla y la BD del mes en curso no tiene gastos todavía → ve el estado vacío con sugerencia de ajustar fechas o registrar.
- **C-04**: Diego selecciona un rango histórico de un año completo (1 ene → 31 dic) y la pantalla rinde con buckets agregados anualmente sin lag perceptible.

## Casos borde

- **CB-01**: Entry creada exactamente a las 23:59:59 del día `to` → cuenta (inclusiva).
- **CB-02**: Entry creada a las 00:00:00 del día `from` → cuenta (inclusiva).
- **CB-03**: Entry creada a las 23:59:59.999 del día `from - 1` → no cuenta.
- **CB-04**: Categoría archivada con entries históricas + categoría activa con mismo nombre → los entries archivados van a "Sin categoría", los activos al bucket de la categoría activa. Sin colisión.
- **CB-05**: Único bucket "Sin categoría" → chart renderiza una sola barra al 100%.
- **CB-06**: 30+ categorías distintas en el rango → chart renderiza con scroll vertical, no se rompe el layout.
- **CB-07**: Total = 0 con buckets vacíos → estado vacío (no card de total con $0.00 + chart vacío).
- **CB-08**: Importar respaldo JSON v1 mientras `/reports` está abierta → la suscripción a `journal_entries` retriguera la query y la vista se actualiza sola.
- **CB-09**: Usuario cancela el DatePicker (botón Cancelar) → el rango previo se mantiene, no se reinvoca el service.
- **CB-10**: Cuenta archivada con entries históricos en el rango → los entries siguen contando (archivar cuenta no oculta histórico). El bucket de su categoría suma normalmente.

## Criterios de aceptación

- **CA-01**: Existe ruta `/reports` accesible desde el icono `bar_chart` del AppBar del Dashboard.
- **CA-02**: Default al abrir muestra rango "primer día del mes corriente → hoy" en los pickers.
- **CA-03**: Con BD que solo tenga seed de Bolsa + 10 categorías y sin entries, `/reports` muestra estado vacío sin crashear.
- **CA-04**: Con al menos un `expense` y un `credit_expense` en el rango, el chart muestra ambos en barras separadas si son distintas categorías; o agregados si comparten categoría.
- **CA-05**: Un `transfer` o `debt_payment` en el rango NUNCA aparece en chart/tabla/total.
- **CA-06**: Un `income` en el rango NUNCA aparece en chart/tabla/total.
- **CA-07**: Tappear "Cambiar desde" abre DatePicker, seleccionar fecha cierra y la vista se actualiza con nuevo rango.
- **CA-08**: Seleccionar `from > to` muestra SnackBar warning y NO modifica el rango actual.
- **CA-09**: `flutter test` queda en verde con los tests nuevos sumando al total actual.
- **CA-10**: `flutter analyze` queda en 0 errores y 0 warnings (hints info preexistentes tolerados).
- **CA-11**: `scripts/verify-apk.sh` exit 0 con versionCode consistente con el pubspec (prefix 2000 del `--split-per-abi` arm64). Para el release inicial `0.4.0+43` → 2043; para el refinement `0.4.1+44` → 2044 (corregido tras quality review v1, B4).

## Criterios medibles de éxito

- **CME-01**: Cobertura nueva: ≥ 10 tests data sobre `ReportsService.spendingByCategory` + ≥ 3 widget tests sobre `/reports`.
- **CME-02**: Suite total post-sprint ≥ 139 tests verdes (126 actual + 13 nuevos como mínimo).
- **CME-03**: Tiempo de respuesta de `spendingByCategory` con 1000 entries y 20 categorías ≤ 200ms en debug build (medible con `Stopwatch` en test ad-hoc, no test recurrente).
- **CME-04**: APK release `app-arm64-v8a-release.apk` instalado en el Redmi se abre, navega a Reportes, muestra el mes en curso correctamente con datos reales del usuario.
- **CME-05**: Diego puede responder verbalmente "qué categoría lideró mi gasto del mes" en ≤ 5 segundos desde abrir la app, sin necesitar export JSON.

## Riesgos

- **R-01**: `fl_chart` es dep nueva y agrega ~300KB al APK. Verificar tamaño tras build. Mitigación: si el peso es problemático, downgrade a tablas-only y ajustar release a `0.4.0+43` igual.
- **R-02**: La query con LEFT JOIN + agregación sobre journal grande podría volverse lenta sin índice. Mitigación: confirmar que el índice existente sobre `journal_entries.occurred_at` cubra el rango; si no, agregar `idx_journal_entries_occurred_at_kind` en migración (bump schemaVersion → 2, agregar rama en `onUpgrade`).
- **R-03**: Material 3 `DropdownMenu` no se usa en este sprint, pero los `DatePicker` por sí solos también pueden contaminar widget tests con overlays. Mitigación: usar `pumpAndSettle` cuidadosamente, no asumir cleanup automático (lección de DV-1 v1).
- **R-04**: `RangeError` o división por cero al calcular `percent` cuando `total == 0`. Mitigación: short-circuit en `ReportsService` que retorne `buckets = []` y `total = 0` cuando no hay rows, sin construir buckets de % 0.
- **R-05**: Decimales de monto (`amount` es int en centavos) — al calcular `percent = bucket.total / report.total`, asegurar que el cast sea `double` para no perder precisión. Mitigación: explicit `bucket.total / report.total` en Dart ya da double si uno de los operandos es double; usar `.toDouble()` para asegurar.

## Supuestos

- **S-01**: El usuario opera en una sola zona horaria (la del dispositivo). No se persiste TZ con el rango porque la app es single-user local.
- **S-02**: 10-20 categorías activas es el caso típico; 30+ es caso borde pero soportado sin pérdida de UX.
- **S-03**: Sin paginación de buckets en V1: el `ListView` rinde todos los buckets del rango, ya que se espera < 50 buckets en uso típico.
- **S-04**: El chart no necesita interacción (tap en barra, tooltip animado): la tabla debajo ya da el detalle. Mantener la barra simple sin handlers.
- **S-05**: La pantalla `/reports` no entra en el flujo de `FirstRunState`: solo accesible desde Dashboard ya hidratado, así que no necesita guard contra BD vacía (el Dashboard ya está autorizado por el redirect).
- **S-06**: Versión bump a `0.4.0` se justifica como minor por agregar feature visible nuevo. Posteriores reportes en el `/reports` shell van a ser `0.4.x` patch.
- **S-07**: `fl_chart` `^0.69.0` es la línea estable a la fecha. Si hay incompatibilidades con drift o intl al hacer `pub get`, downgrade a `^0.68.0` aceptable sin replanificar.
- **S-08**: El usuario lee el reporte como espectador, no edita desde ahí. Cualquier acción correctiva (recategorizar entries, archivar categoría) sigue desde sus pantallas dedicadas.

## Impacto esperado

- **Producto**: primer feature de lectura agregada disponible sin export JSON. La promesa "el archivo local es el producto" se completa: lo registrado se lee directamente desde la app.
- **Código**:
  - Nuevo módulo `lib/data/reports.dart` (~120 líneas estimadas).
  - Nuevos screens `lib/screens/reports_screen.dart` + `lib/screens/reports/spending_by_category_tab.dart` (~250 líneas estimadas).
  - Nueva dep `fl_chart` (^0.69.x).
  - Ruta nueva en `app_router.dart` + 1 icon en AppBar del Dashboard.
  - +13 tests mínimo.
- **Compatibilidad**: aditivo puro. Sin cambios en schema (no se bump `schemaVersion`). Sin cambios en backup JSON v1. Sin cambios en DAOs existentes.
- **Sucesor**: deja el shell `/reports` listo para que próximos sprints agreguen tabs (cashflow mensual, saldo a fecha, top movimientos) reusando el TabBar y patrón de filtros.
