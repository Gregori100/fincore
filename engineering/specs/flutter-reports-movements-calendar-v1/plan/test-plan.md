# Plan de pruebas — flutter-reports-movements-calendar-v1

## Casos borde detectados

- **CB-01**: mes sin ningún movimiento → `Map` vacío emitido; widget renderiza calendario sin marcadores; sin crash.
- **CB-02**: día con 1 solo income → marcador verde único; sin rojo ni azul.
- **CB-03**: día con 1 solo expense → marcador rojo único.
- **CB-04**: día con 1 solo credit_expense → marcador rojo único (agrupado con expense, RN-CAL01).
- **CB-05**: día con 1 solo transfer → marcador azul único.
- **CB-06**: día con 1 solo debt_payment → marcador azul único.
- **CB-07**: día con 1 income + 1 expense + 1 transfer → 3 marcadores en orden verde-rojo-azul.
- **CB-08**: entries fuera del rango del mes en foco (mes anterior/siguiente) → no cuentan para el `Map`.
- **CB-09**: movimiento con `occurred_at` exacto a `firstDayOfMonth 00:00:00` → cae en el día 1.
- **CB-10**: movimiento con `occurred_at` exacto a `lastDayOfMonth 23:59:59.999` → cae en el último día del mes.
- **CB-11**: movimiento cancelado (`deleted_at IS NOT NULL`) → NO cuenta.
- **CB-12**: cancelar un entry del día 15 con el tab abierto → marcador del día 15 se recalcula; si era el único, desaparece.
- **CB-13**: registrar un nuevo income el día actual con el tab abierto → marcador verde aparece en el día correspondiente sin refresh manual.
- **CB-14**: cambiar de mes con las flechas → el stream se recrea con el nuevo rango; marcadores del nuevo mes visibles en <1 s.
- **CB-15**: día seleccionado inicial = hoy si cae en el mes actual (test correr en un mes con "hoy" adentro); si el mes en foco es enero pero "hoy" es julio, `_selectedDay = null`.
- **CB-16**: tap en día del mes vs tap en día del spillover (mes previo/siguiente que renderiza el `TableCalendar` por relleno visual): default del paquete lo maneja; validar en smoke que no rompe.
- **CB-17**: tap en día sin movimientos → navega a `/entries` con filtro `from = to = ese día` y lista vacía.
- **CB-18**: BD con muchos años de historia (>5 años, >10.000 entries) → performance de `movementsByDay` para 1 mes < 100 ms.
- **CB-19**: categoría archivada asociada a movimientos del mes → NO afecta la agregación (query no joinea categories).
- **CB-20**: dependencia `table_calendar` con warning de deprecación en Dart 3.7.2 → detectado por `flutter analyze` en T001.

## Pruebas unitarias necesarias

Sobre `mobile/test/data/reports_test.dart` (grupo nuevo `movementsByDay (sprint movements-calendar)`):

- **UT-CAL01**: BD sin entries → Map vacío. Cubre CB-01.
- **UT-CAL02**: 1 income el día 5 → Map con 1 entrada `{DateTime(y,m,5): DayActivity(hasIncome: true, totalCount: 1)}`. Cubre CB-02.
- **UT-CAL03**: 1 expense el día 10 → Map con `hasSpending: true`. Cubre CB-03.
- **UT-CAL04**: 1 credit_expense el día 12 → `hasSpending: true` (agrupado con expense por RN-CAL01). Cubre CB-04.
- **UT-CAL05**: 1 transfer el día 15 → `hasInternal: true`. Cubre CB-05.
- **UT-CAL06**: 1 debt_payment el día 20 → `hasInternal: true`. Cubre CB-06.
- **UT-CAL07**: día con 3 kinds mezclados (income + expense + transfer) → los 3 flags true, `totalCount = 3`. Cubre CB-07.
- **UT-CAL08**: entries del mes anterior + siguiente → NO cuentan; solo el mes en foco. Cubre CB-08.
- **UT-CAL09**: entry cancelado post-registro → desaparece del Map (verificar re-emit con `emitsThrough`). Cubre CB-11, CB-12.
- **UT-CAL10**: entry en el borde `firstDayOfMonth 00:00:00` → cae en día 1. Cubre CB-09.
- **UT-CAL11**: entry en el borde `lastDayOfMonth 23:59:59.999` → cae en último día. Cubre CB-10.
- **UT-CAL12**: reactividad — registrar un income con el stream escuchando → re-emite con nueva entrada. Usar `emitsThrough` (NO `Future.delayed` para evitar flakiness). Cubre CB-13.

Sobre `mobile/test/data/entries_filters_test.dart` (grupo nuevo `forDay (sprint movements-calendar)`):

- **UT-CAL13**: `forDay(day: DateTime(2026, 6, 15))` → `datePreset: custom`, `from = DateTime(2026, 6, 15, 0, 0, 0)`, `to = DateTime(2026, 6, 15, 23, 59, 59, 999)`, sin kinds ni cuentas ni categorías.
- **UT-CAL14**: `forDay` produce `toDeepLink()` roundtrip parseable con `EntriesFilters.fromSavedJson` que preserva el rango.

## Pruebas de integracion o API necesarias

No aplica. App local-first sin API expuesta.

## Pruebas de UI o flujo necesarias si aplica

Sobre `mobile/test/screens/reports/movements_calendar_tab_test.dart` (nuevo):

- **WT-CAL01**: render inicial con mes actual → `TableCalendar` visible; header con nombre del mes en español.
- **WT-CAL02**: seed con 1 expense el día 10 del mes actual + tab montado → marcador rojo visible en el día 10.
- **WT-CAL03**: tap en el día 10 → navegación a `/entries` con `EntriesFilters` que tiene `from = to = ese día`. Verificar deep link generado.
- **WT-CAL04**: tap en la flecha derecha del header → mes cambia al siguiente; los marcadores del mes actual desaparecen.

## Pruebas de permisos y seguridad si aplica

No aplica. App single-user.

## Pruebas de datos, migracion o compatibilidad si aplica

No aplica. Sin schema bump ni migración.

## Pruebas de regresion sobre flujos existentes

- **RT-01**: `flutter test` completo verde. 474 tests actuales + 14 nuevos = ≥ 488 esperados.
- **RT-02**: los 8 tabs anteriores de `/reports` siguen verdes en sus widget tests.
- **RT-03**: el test WT-15 de `credit_cards_tab_test.dart` (conteo de tabs) actualizado de `findsNWidgets(8)` a `findsNWidgets(9)`.
- **RT-04**: los tests del onboarding (`onboarding_screen_test.dart`) siguen verdes tras agregar la 9ª fila del slide 3 (no verifican conteo exacto).
- **RT-05**: los tests del Help (`help_screen_test.dart`) siguen verdes tras actualizar prefacio + bullet (no verifican texto completo).

## Pruebas manuales o smoke tests necesarios

- **SM-01**: Diego abre `/reports` → ve 9 tabs y "Calendario" al final. `TabBar` no overflowea en el ancho de su cel.
- **SM-02**: entra al tab → mes actual visible con nombres de días/mes en español neutro (Lun/Mar/Mié, etc.) y marcadores en los días con sus movimientos reales.
- **SM-03**: tapea un día con actividad → `/entries` se abre con el filtro pre-cargado (`Este día` visible en el header) y lista los movimientos exactos.
- **SM-04**: registra un movimiento nuevo desde el FAB → vuelve al tab → marcador nuevo aparece en el día correspondiente sin refresh manual.
- **SM-05**: tapea la flecha izquierda del header → mes anterior visible con sus marcadores.
- **SM-06**: onboarding "Ver tour de bienvenida" desde Ayuda → slide 3 muestra 9 filas legibles con scroll si es necesario; la 9ª es "Calendario".
- **SM-07**: Ayuda → tile "¿Cómo se calculan los reportes?" menciona "9 pestañas" y el bullet nuevo del calendario.

## Datos de prueba recomendados

Setup para tests unitarios (in-memory BD):

- Bolsa (seed default) + 1 cuenta debit "BBVA_CAL" + 1 cuenta credit "Visa_CAL".
- Rango mes: junio 2026 (para tests deterministas).
- Entries:
  - 1 income de $5000 el 2026-06-05 → catIncomeSueldo.
  - 1 expense de $200 el 2026-06-10 → catComida.
  - 1 credit_expense de $800 el 2026-06-12 → catComida.
  - 1 transfer de $500 el 2026-06-15 → Bolsa → BBVA.
  - 1 debt_payment de $700 el 2026-06-20 → Bolsa → Visa.
  - 1 income + 1 expense + 1 transfer el mismo día (2026-06-25) → verifica día con 3 kinds.

Para smokes con la BD real de Diego: no requiere seed extra; el calendario debe renderizar con lo que ya hay.

## Comandos o validaciones locales sugeridas

```bash
cd mobile
flutter pub get                                       # tras agregar table_calendar
flutter analyze                                        # 0 errores nuevos
flutter test test/data/reports_test.dart               # UT-CAL01..12
flutter test test/data/entries_filters_test.dart      # UT-CAL13..14
flutter test test/screens/reports/movements_calendar_tab_test.dart  # WT-CAL01..04
flutter test                                           # suite completa ≥ 488 verdes
flutter build apk --release --split-per-abi
../scripts/verify-apk.sh                               # arm64 versionCode 2082
~/Android/Sdk/platform-tools/adb install -r build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

## Criterios minimos para aprobar la implementacion

- 14 tests nuevos verdes (12 UT servicio + 2 UT factory + 4 widget; contar según distribución final).
- `flutter test` completo ≥ 488 tests verdes (474 baseline + 14 nuevos).
- `flutter analyze` sin errores nuevos; 4 hints info pre-existentes tolerados.
- APK release build OK; `verify-apk.sh` OK con `versionCode 2082 / versionName 0.16.0`.
- SM-01..07 confirmados por Diego en cel real.
- Delta `report día 15 dice 2 movimientos → drill-down lista 2 movimientos` en 0 casos observados en la BD real de Diego.

## Validacion final recomendada

Ejecutar la skill `branch-quality-review` con slug `flutter-reports-movements-calendar-v1` antes del commit final. La skill genera su propio reporte en `engineering/quality-review/<slug>/`; no duplicar dentro de `implementation/`.

Si por alguna razón la skill no está disponible, ejecutar la checklist equivalente:

1. Revisar diff completo con `git diff HEAD`.
2. Confirmar que no hay archivos de más ni cambios accidentales fuera del alcance (solo los archivos listados en `plan.md`).
3. Verificar que la dependencia `table_calendar` quedó fijada con versión exacta (no `^`).
4. Confirmar que el widget del tab NO usa `Future.delayed` en tests reactivos (usar `emitsThrough`).
5. Revisar que `RN-CAL02` (soft delete) y `RN-CAL11` (borde de día) están cubiertos por UT-CAL09/10/11.
6. Verificar que el bump de versión coincide en `pubspec.yaml` y `build.gradle.kts`.
