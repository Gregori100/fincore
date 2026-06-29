# Test plan — flutter-reports-monthly-average-v1

## Casos borde detectados

Más allá de los listados en `spec.md`, esta lista cubre escenarios que pueden romper o degradar el reporte:

- **CB-D01**: BD totalmente vacía (sin Bolsa, sin entries, sin categorías). El método debe retornar `MonthlyAverageReport` con `isEmpty: true` sin crash.
- **CB-D02**: BD con N meses cerrados pero **sin entries de tipo expense/credit_expense** (solo income/transfer). Histórico = 0, mes actual = 0 → reporte con promedio 0 y delta null.
- **CB-D03**: BD con entries históricos pero **todos cancelados** (`deleted_at NOT NULL`). El filtro debe excluirlos → reporte con histórico 0.
- **CB-D04**: Múltiples entries del mismo día / mes / categoría. El `SUM(amount) GROUP BY` debe agregarlos correctamente.
- **CB-D05**: Entry con `category_id` NULL (sin categoría asignada) y otro con categoría archivada → ambos se agregan al **mismo bucket "Sin categoría"** (consistencia con `spendingByCategory`).
- **CB-D06**: `now` = último día del mes (e.g., 30 de junio). El filtro `day <= 30` incluye todos los días posibles del mes. Sin lógica especial.
- **CB-D07**: `now` cambia de día entre dos refreshes del stream. El stream re-emite con el nuevo prorrateo solo cuando cambian las tablas observadas; si solo cambia `now`, no re-emite por sí solo. Aceptable en v1 (el tab se reconstruye al cambiar de tab).
- **CB-D08**: Ventana N=24 con 24 meses cerrados todos con datos → reporte completo. Validar performance.
- **CB-D09**: Categoría reactivada **no aplica** porque la convención del repo dice "archivado terminal sin reactivación". No es un caso a cubrir.
- **CB-D10**: Cambio de mes calendario mientras el stream está activo (entry creado el 1° a las 00:00:01 después del refresh). Acceptable que el reporte considere el entry como mes actual al siguiente refresh.
- **CB-D11**: Entry con `kind = transfer` entre dos cuentas debit. NO debe contar (RN-A01).
- **CB-D12**: Entry con `kind = debt_payment` (pago de tarjeta). NO debe contar (RN-A01).
- **CB-D13**: Entry con `kind = income`. NO debe contar.
- **CB-D14**: Categoría con histórico positivo pero `currentMonthSpent == 0`. Aparece en breakdown con delta negativo. (RN-A14, CB-T11 de spec.)
- **CB-D15**: Empty state visual: cuando `isEmpty`, no se renderiza la card ni el breakdown.
- **CB-D16**: Stream cancelado por dispose del tab. No debe haber leak de StreamSubscription.
- **CB-D17**: Sentido del semáforo: actual **igual** a histórico (delta 0) → debe caer en "verde" (≤95% del promedio NO se cumple si exactamente igual, pero 100% del promedio NO es ≤95%, así que cae en "amarillo"). **Decisión a confirmar**: el umbral correcto para "En línea" es realmente `>95% AND ≤110%`. Si Diego espera que "exactamente igual" sea verde, ajustar a `<100% AND ≤110%`. Documentar en test.

## Pruebas unitarias necesarias

Ubicación: `mobile/test/data/reports_test.dart` — nuevo grupo `monthlyAverage`.

- **UT-01**: BD vacía → `isEmpty == true`, todos los campos numéricos en 0, `categoryBreakdown` vacío.
- **UT-02**: N=1 con 1 mes histórico completo y mes actual completo → `historicalAverage` = total mes histórico hasta día D, `currentMonthSpent` = total mes actual hasta día D, delta correcto.
- **UT-03**: N=3 con 3 meses históricos. Filtro de prorrateo `day <= D = 15`. Entries del día 14, 15 y 16 → cuentan los primeros dos, no el del 16.
- **UT-04**: Mes en curso. Entries del día 1 al día D=20. Todos cuentan en `currentMonthSpent`.
- **UT-05** (RN-A08): `now = 2026-05-31`, D=31. Mes histórico febrero 2026 (28 días). Entry del 28 de feb → cuenta. Entry del 1 de marzo NO cuenta para el bucket de febrero.
- **UT-06**: Entry con categoría archivada → su monto va al bucket "Sin categoría". Otro entry con `category_id NULL` también va al mismo bucket; ambos se suman.
- **UT-07**: Soft delete excluye entry. `deleted_at NOT NULL` no participa del promedio.
- **UT-08**: kinds. Entries con kinds `expense` y `credit_expense` cuentan. Entries con `income`, `transfer`, `debt_payment` NO cuentan.
- **UT-09**: Degradación M<N. N=12 pero solo 3 meses cerrados con datos. `monthsAvailable == 3`. Promedio computado sobre 3 meses.
- **UT-10**: `historicalAverage == 0` (BD sin gasto histórico). `deltaAbsolute == currentMonthSpent`, `deltaPercent == null` (no infinito).
- **UT-11**: Categoría histórico positivo, mes actual = 0. Aparece en breakdown con `deltaAbsolute < 0`, `deltaPercent ≈ -100%`.
- **UT-12**: Categoría sin histórico (gasto solo en mes actual). Aparece con `historicalAverage == 0`, `deltaAbsolute == currentMonthSpent`, `deltaPercent == null`.
- **UT-13**: Orden del breakdown: 3 categorías con deltas absolutos {200, -100, 50}. Resultado: orden {200, 50, -100}. Empate de delta → orden alfabético.
- **UT-14**: Stream reactivo. Cancelar (soft-delete) un entry mientras el stream está vivo → re-emite con nuevo total.
- **UT-15**: D < 28 → todos los meses históricos aportan días [1, D]. Validar con D=10 sobre 3 meses, cada mes con 1 entry el día 10. Promedio == total del día 10 / 3.
- **UT-16**: Performance smoke (opcional pero recomendado). 1000 entries en 24 meses → reporte completa en <100ms. Asercion lap-time soft (no estricto).

## Pruebas de integración o API necesarias

No aplica. FinCore no tiene HTTP API. Las pruebas de integración aquí son las unit tests que tocan SQLite real con `NativeDatabase.memory()` (que es el patrón estándar del repo).

## Pruebas de UI o flujo necesarias

Ubicación: `mobile/test/screens/monthly_average_tab_test.dart` — archivo nuevo.

- **WT-01**: Carga inicial del tab con seed de N=3 meses de datos. Aparecen los 3 valores globales + chip de estado + sección "Desglose por categoría" con al menos 1 fila.
- **WT-02**: Cambiar preset `3 → 6`. El tab re-renderiza la card sin error. `pumpAndSettle` finaliza limpio.
- **WT-03**: Empty state. Con seed sin entries históricos: aparece el icono + texto "Necesitás al menos 1 mes cerrado de uso para calcular promedio".
- **WT-04**: Render del breakdown. 3 categorías con deltas distintos → 3 `BaseCard` en pantalla, en orden de delta absoluto desc.

Patrón a seguir: `mobile/test/screens/cashflow_screen_test.dart` (si existe) o `entries_filters_screen_test.dart`. Helper `pumpFincoreApp` del harness con seed extra para sembrar entries históricos.

## Pruebas de permisos y seguridad

No aplica (single-user, BD local).

## Pruebas de datos, migración o compatibilidad

No aplica (sin schema bump, sin migración). El smoke manual debe confirmar que abrir el APK nuevo sobre datos existentes no causa regresión.

## Pruebas de regresión sobre flujos existentes

- **RG-01**: Suite completa (`flutter test`) verde tras los cambios. Espera 302 → ~320 tests.
- **RG-02**: El tab "Saldo a fecha" (4°) sigue siendo accesible y renderea sin cambios.
- **RG-03**: Los otros 3 tabs (Gasto por categoría, Cashflow, Top movimientos) renderean igual. Sin cambios en su código.
- **RG-04**: `flutter analyze` no introduce warnings nuevos. Los 4 `info prefer_const_constructors` preexistentes siguen tolerados.

## Pruebas manuales o smoke tests necesarios

- **SM-01**: Instalar el APK sobre la BD actual de Diego (con histórico real). Abrir `/reports`, swipe al 5° tab "Promedio". Validar:
  - Carga sin spinner infinito.
  - Promedio histórico tiene sentido vs lo que Diego conoce de su gasto.
  - Delta tiene color correcto.
  - Subtítulo muestra "al día D del mes" con el día actual.
- **SM-02**: Cambiar preset 3 → 6 → 12 → 24 → 1 → 3. Validar fluido y sin re-fetch visible.
- **SM-03**: Crear un entry de gasto grande en el mes actual desde `/entries/new`. Volver al tab Promedio. Validar que el delta se actualizó automáticamente (reactividad).
- **SM-04**: Archivar una categoría con histórico. Volver al tab. Validar que su monto histórico ahora aparece en bucket "Sin categoría".
- **SM-05**: Cancelar un entry histórico desde `/entries`. Volver al tab. Validar que el promedio bajó.

## Datos de prueba recomendados

Para los unit tests del DAO:

- BD in-memory con 3 cuentas (Bolsa, debit Banamex, credit BBVA).
- 2-3 categorías activas (Comida, Transporte, Entretenimiento).
- 1 categoría archivada (Misceláneo).
- Entries históricos por 3-6 meses con distintos días del mes (1, 10, 15, 20, 28).
- Variedad de kinds para validar los excluidos.

Para widget tests:

- Reusar `pumpFincoreApp` con seed extra. Sembrar 3 meses cerrados con 5-10 entries cada uno + 2-3 entries del mes actual.

## Comandos o validaciones locales sugeridas

```bash
cd mobile

# Unit tests del DAO
flutter test test/data/reports_test.dart

# Widget tests del tab nuevo
flutter test test/screens/monthly_average_tab_test.dart

# Suite completa (regresión)
flutter test

# Lint
flutter analyze

# Validación de versión del APK release (RF-018 del repo)
flutter build apk --release --split-per-abi
scripts/verify-apk.sh build/app/outputs/flutter-apk/app-arm64-v8a-release.apk

# Smoke sobre device real
~/Android/Sdk/platform-tools/adb install -r build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

## Criterios mínimos para aprobar la implementación

- `flutter analyze` con 0 errores nuevos.
- `flutter test` verde, ~16 unit tests + 4 widget tests nuevos.
- Smoke SM-01 + SM-02 + SM-03 confirmados manualmente por Diego.
- Cumple AC-01 → AC-10 del spec.
- Sin cambios en pubspec.lock más allá del version bump.
- Sin TODO/FIXME marcados como deuda inmediata en los archivos nuevos.

## Validación final recomendada

Después de implementar y validar localmente, correr la skill `branch-quality-review` para auditar la rama antes del commit final. El reporte queda en `engineering/quality-review/flutter-reports-monthly-average-v1/`.

Si la skill no está disponible o Diego no la solicita, hacer revisión equivalente manual:

- Verificar que el método del service no tiene queries N+1 ocultas.
- Verificar que los modelos son inmutables (todos `final`).
- Verificar que el tab cachea el stream para no re-suscribir en cada `setState`.
- Verificar que no se introduce dependencia entre el tab y modelos de otros tabs (acoplamiento horizontal).
- Verificar que el version bump está sincronizado entre `pubspec.yaml` y `android/app/build.gradle.kts`.
