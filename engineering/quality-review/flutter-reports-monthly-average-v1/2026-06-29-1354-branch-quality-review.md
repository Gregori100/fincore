# Branch Quality Review: flutter-reports-monthly-average-v1

## Metadata

- Fecha: 2026-06-29
- Rama revisada: `main` (cambios uncommitteados sobre `71fc691`)
- Rama base: `main`
- Rango: working tree vs HEAD
- Commit HEAD: `71fc691`
- Autor de revisión: Claude Code (carriles paralelos con asignación de modelo: Sonnet para SQL+UX, Haiku para tests+arquitectura).
- Carpeta de reporte: `engineering/quality-review/flutter-reports-monthly-average-v1/`

## Resumen ejecutivo

- Sprint introduce un 5° tab "Promedio mensual" en `/reports` + método `monthlyAverage` con query agregada de prorrateo + 19 tests nuevos. 321/321 verdes, analyze limpio.
- Estado funcional: **entregable** con 2 correcciones menores recomendadas antes de commit (H1 UX const + H2 UX docstring).
- **1 hallazgo Alta semántica** (B1: divisor del promedio cuenta meses-con-datos en lugar de meses-cerrados, viola CB-T04 del spec). Escenario que dispara el bug es **raro en uso real single-user** (mes intermedio con 0 gastos), pero corresponde discutir si se respeta la spec o se actualiza la spec.
- **Un falso positivo descartado**: el agente Tests reportó como Alta que WT-01 crashearía en enero por `DateTime(year, 0, day)`. Verificado en Dart: la normalización es automática (`DateTime(2026, 0, 10, 12) → 2025-12-10 12:00:00.000`). El test es determinista.
- 4 carriles revisados (SQL/Data, Frontend/UX, Tests, Arquitectura). El de Arquitectura cerró conforme sin hallazgos.

## Alcance revisado

- Cambios sobre commit `71fc691` (working tree no commiteado):
  - `mobile/lib/data/reports.dart` (+290 líneas: modelos + método + helpers)
  - `mobile/lib/screens/reports/monthly_average_tab.dart` (nuevo, ~470 líneas)
  - `mobile/lib/screens/reports_screen.dart` (length 4→5, tab nuevo)
  - `mobile/pubspec.yaml` (0.10.0+62 → 0.11.0+63)
  - `mobile/android/app/build.gradle.kts` (versionCode 63, versionName 0.11.0)
  - `mobile/test/data/reports_test.dart` (+430 líneas, 15 UT)
  - `mobile/test/screens/monthly_average_tab_test.dart` (nuevo, 4 WT)
- Áreas: SQL agregada con prorrateo, modelos inmutables nuevos, UI compleja (semáforo + breakdown), reactividad, integración con TabBar existente.
- Comandos usados: `git status`, `git diff --stat`, lecturas con `Read`, agentes paralelos con asignación de modelo.

## Hallazgos bloqueantes

Ninguno crítico. **B1 (Alta semántica)** se discute abajo — la decisión sobre arreglar o actualizar spec queda en manos de Diego.

### B1. Divisor del promedio usa meses-con-datos en lugar de meses-cerrados (CB-T04)

- Severidad: **Alta** (semántica, viola caso borde explícito del spec)
- Área: SQL / data layer / lógica de promedio
- Evidencia: `mobile/lib/data/reports.dart:733-737` calcula `monthsAvailable` como `monthsWithData.length`. El spec en **CB-T04** dice explícitamente: *"Mes cerrado intermedio con 0 entries cuenta como mes con gasto = 0 en el prorrateo"*. RN-A04 habla de degradación parcial "anterior a la primera entry registrada".
- Impacto:
  - Si la ventana es `[Oct, Nov, Dic]` con N=3 y Nov tiene $0 en gastos, el código produce `monthsAvailable=2` → divide por 2 e **infla el promedio**.
  - Según CB-T04 debería dividir por 3 (Nov cuenta como 0 en numerador y denominador).
  - En uso real single-user que registra cada gasto, el escenario es **muy raro** (raro tener un mes completo sin un solo gasto). Pero la spec lo cubre explícitamente.
- Recomendación: distinguir entre "meses cerrados dentro del período activo del usuario" (denominador correcto) y "meses cerrados anteriores a la primera entry jamás registrada" (degradación RN-A04). Una implementación: usar `closedMonths.length` como divisor cuando `firstEntryDate <= closedMonths.first`; degradar a `monthsWithDataFromFirstEntry` cuando no.
- Depende de: confirmación de Diego sobre si respeta CB-T04 o relaja la regla.

## Hallazgos no bloqueantes

### M1. WT-02 verifica solo que el tab sigue visible (falso verde)

- Severidad: Media
- Área: tests
- Evidencia: `mobile/test/screens/monthly_average_tab_test.dart:92-98`. Tras `tester.tap(find.text('6 meses'))`, el único assert es `expect(find.byType(MonthlyAverageTab), findsOneWidget)`. No valida que el preset cambió, ni que el subtítulo refleja "6 meses cerrados", ni que el promedio se recalculó.
- Impacto: si el preset rompiera silenciosamente (e.g., `_selectPreset` se rompiera), el test pasaría igual.
- Recomendación: agregar `expect(find.textContaining('6 meses'), findsOneWidget)` o validar el chip seleccionado.
- Depende de: nada.

### M2. UT-08 menciona `debt_payment` en el nombre pero no lo siembra

- Severidad: Media
- Área: tests
- Evidencia: `mobile/test/data/reports_test.dart:1485-1522`. El test "kinds excluidos (income, transfer, debt_payment) NO cuentan" siembra `income`, `transfer`, `expense`, `credit_expense` pero **no llama a `registerDebtPayment`**. La query SQL filtra correctamente, pero el test no lo blinda.
- Impacto: si alguien cambiara la query a incluir `debt_payment` por error, el test seguiría pasando.
- Recomendación: agregar un `registerDebtPayment` al seed del test y validar que el monto no contribuye al `historicalAverage`.
- Depende de: nada.

### M3. `_BreakdownHeader` sin constructor `const`

- Severidad: Baja
- Área: frontend / consistencia
- Evidencia: `mobile/lib/screens/reports/monthly_average_tab.dart:200`. `class _BreakdownHeader extends StatelessWidget` no declara constructor. Línea 113 lo instancia como `_BreakdownHeader()` sin `const`. Todos los demás widgets privados del archivo siguen el patrón `const _Foo()`.
- Impacto: hint cosmético de `prefer_const_constructor_declarations`. Inconsistencia mínima.
- Recomendación: agregar `const _BreakdownHeader();` y prefix con `const` en línea 113.
- Depende de: nada.

### M4. Docstring desactualizado: dice "Promedio" pero el label es "Promedio mensual"

- Severidad: Mínima
- Área: documentación
- Evidencia:
  - `mobile/lib/screens/reports/monthly_average_tab.dart:9` → `Tab "Promedio"`.
  - `mobile/lib/screens/reports_screen.dart:14` → comentario `"Promedio (sprint...)"`.
  - El label real en pantalla es `'Promedio mensual'` (reports_screen.dart:38). El AC-01 del spec también dice "Promedio".
- Impacto: confusión leve al leer el código.
- Recomendación: alinear ambos comentarios a "Promedio mensual".
- Depende de: nada.

### M5. Delta absoluto con `historicalAverage == 0` se muestra sin baseline

- Severidad: Baja
- Área: UX / interpretación
- Evidencia: `mobile/lib/screens/reports/monthly_average_tab.dart:156-159` muestra `_formatDelta(report.deltaAbsolute)` (e.g. `+$4.200,00`) en `textMuted` cuando `historicalAverage == 0`. El status chip dice "Sin histórico". El número es técnicamente correcto (delta = current - 0 = current) pero confunde: "+$4200" sin baseline puede leerse como una desviación al alza.
- Impacto: confusión leve la primera vez que el usuario ve el reporte sin histórico.
- Recomendación: mostrar "—" en el campo Delta global también cuando `historicalAverage == 0`, alineado con cómo `_CategoryRow:262` muestra "—" para el porcentaje.
- Depende de: nada.

### M6. Casos borde del test-plan sin cobertura explícita

- Severidad: Baja
- Área: tests / cobertura
- Evidencia:
  - **CB-D06**: `now` = último día del mes (30, 31). Sin test directo.
  - **CB-D17**: actual exactamente en el threshold (0.95 y 1.10 del semáforo). Sin test directo.
  - El wrap de año en `_iterateClosedMonths` está cubierto en UT-05 indirectamente (D=31 con histórico febrero/marzo/abril) pero no hay test específico con `now = 2026-01-15` y `monthsBack=3` para validar octubre/noviembre/diciembre del año previo.
- Impacto: cobertura aceptable para v1, gap mínimo.
- Recomendación: agregar 2-3 tests cuando se toque el archivo de nuevo.
- Depende de: nada.

### M7. Overflow potencial en `_GlobalCard` con montos grandes

- Severidad: Baja
- Área: UI / layout
- Evidencia: `mobile/lib/screens/reports/monthly_average_tab.dart:143-161`. `Row(mainAxisAlignment: spaceBetween)` con tres `Column` sin `Expanded`/`Flexible`. En pantallas chicas (≤360dp) con montos largos (`$1.234.567,00`) puede desbordar.
- Impacto: el mismo patrón existe en `cashflow_tab.dart` (heredado), pero acá los 3 valores pueden ser simultáneamente grandes. Riesgo bajo en pantallas modernas pero no nulo.
- Recomendación: envolver cada `_HeaderMetric` en `Expanded` para que se ajusten proporcionalmente.
- Depende de: nada.

### M8. UT-14 reactividad indirecta

- Severidad: Baja
- Área: tests
- Evidencia: `mobile/test/data/reports_test.dart:1654-1673`. El test verifica que dos lecturas sucesivas de `stream.first` retornan valores actualizados tras cancelar un entry. No usa `StreamController` con assertions sobre emisiones.
- Impacto: el test funciona en práctica (drift re-emite), pero el patrón no es 100% canónico. Es el mismo patrón que usan otros tests del repo.
- Recomendación: opcional, dejar como está. Si se quiere robustecer, suscribir y aguardar emisiones explícitas.
- Depende de: nada.

### B1' Falso positivo descartado (NO accionable)

- El agente Tests reportó como Alta que WT-01 crashearía cuando se ejecutara en enero porque `DateTime(2026, 1, 1).month - 1 == 0` y `DateTime(2026, 0, 10, 12)` lanzaría excepción.
- Verificación: Dart **normaliza automáticamente** `DateTime(year, 0, day)` a `DateTime(year-1, 12, day)`. Probado con `DateTime(2026, 0, 10, 12) → 2025-12-10 12:00:00.000`.
- WT-01 es determinista todos los meses del año. No requiere acción.

## Plan de corrección ordenado

1. **B1 (Alta)** — decisión de producto: ¿se respeta CB-T04 (dividir por `closedMonths.length`) o se actualiza la spec para que diga "promediar solo meses con datos"? Si se respeta, modificar `_buildMonthlyAverageReport` para usar `closedMonths.length` cuando todos los meses cerrados están dentro del período activo. ~15-30 min + 1 test nuevo. (15 min si Diego decide actualizar la spec en lugar de cambiar el código).
2. **M1** — fortalecer WT-02 con assert real sobre cambio de preset. ~5 min.
3. **M2** — agregar `registerDebtPayment` al seed del UT-08. ~5 min.
4. **M3** — `const _BreakdownHeader()`. ~1 min.
5. **M4** — alinear docstrings a "Promedio mensual". ~2 min.
6. **M5** — mostrar "—" en delta global cuando `historicalAverage == 0`. ~5 min + ajustar `_GlobalCard`.
7. **M7** — envolver `_HeaderMetric` en `Expanded`. ~3 min.
8. **M6** — backfill tests cuando se toque el archivo de nuevo. ~10 min.
9. **M8** — opcional, dejar como está.

Total estimado (sin B1 con código): ~20-30 min para M1-M7. Si se decide arreglar B1: +30 min.

## Validaciones recomendadas

```bash
cd mobile
flutter test test/data/reports_test.dart
flutter test test/screens/monthly_average_tab_test.dart
flutter test
flutter analyze
```

Smoke manual recomendado (T017 del plan):

- SM-01: instalar `0.11.0+63` y validar carga del tab sobre BD real.
- SM-02: probar todos los presets `[1, 3, 6, 12, 24]`.
- SM-03: crear gasto grande del mes y volver al tab (reactividad).
- SM-04: archivar categoría con histórico (bucket "Sin categoría").
- SM-05: cancelar entry histórico (promedio baja).

## Limitaciones

- Review sobre cambios working-tree, no sobre commit final. Los cambios pueden ajustarse antes de commit.
- No se ejecutó `flutter test` durante la revisión (el implementation-review confirma 321 verdes).
- Performance del método con journal grande (>10k entries) no medida.
- El agente Tests devolvió un falso positivo (DateTime en enero) que fue verificado y descartado durante la integración del reporte. Esto evidencia el valor de validar agentes con razonamiento concreto sobre el lenguaje (Dart en este caso) antes de aceptar hallazgos.
- B1 (CB-T04) es interpretación de spec contra implementación. La decisión final corresponde a Diego.
