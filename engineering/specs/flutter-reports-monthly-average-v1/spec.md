# Sprint flutter-reports-monthly-average-v1 — Promedio mensual + comparativa del mes en curso

## Resumen

Agrega un **5° tab en `/reports`** llamado "Promedio" que muestra el **gasto promedio mensual de los últimos N meses cerrados, prorrateado al mismo día del mes que hoy**, y lo compara con el **gasto del mes en curso** para responder la pregunta diaria de Diego: *"¿estoy gastando más o menos que de costumbre?"*. El tab incluye un **desglose por categoría** con la misma comparación.

Es el **paso 0 del módulo Presupuestos** futuro: Diego no puede presupuestar si no conoce su gasto real promedio. Sin schema bump, sin deps externas — solo lectura del journal y un método nuevo en `ReportsService`.

## Problema a resolver

Hoy `/reports` muestra:

- Gasto del mes actual (Spending by Category).
- Flujo entrada/salida agrupado por mes (Cashflow).
- Top movimientos del período.
- Saldo de cuentas a una fecha.

Falta una vista que **contraste el real contra la base histórica** del propio usuario, sin tener que mirar a ojo el Cashflow mes a mes. Diego dijo que quiere ver algo del tipo "Junio al día 22: gastaste $4200 / promedio últimos 3 meses (prorrateado al día 22) $5800 → vas 28% abajo" para conectar con la regla 30/50/20 y saber si está alineado con su patrón de consumo, además de identificar **en qué categorías** se desvió.

## Objetivo

- Calcular el **gasto promedio mensual** de los últimos N meses cerrados (presets `[1, 3, 6, 12, 24]`, default N=3), **prorrateado al mismo día del mes** que `now`.
- Mostrar **gasto del mes en curso** (parcial, hasta hoy).
- Comparar contra el **promedio prorrateado** para que el delta sea justo intra-mes.
- Indicar **delta absoluto + porcentual** con semáforo de color.
- Mostrar **desglose por categoría** con la misma métrica para identificar dónde se desvió el gasto.
- Dejar la base lista para que el módulo Presupuestos pueda reusar el método del servicio.

## Alcance

- Tab nuevo "Promedio" en `/reports`, posicionado después de "Saldo a fecha" (5° y último).
- Método nuevo `ReportsService.monthlyAverage({ int monthsBack, DateTime now })` que retorna `Stream<MonthlyAverageReport>`.
- Modelo `MonthlyAverageReport` con: promedio mensual prorrateado, total mes actual, delta absoluto, delta porcentual, cantidad de meses considerados, día del mes de corte, lista de `CategoryAverageDelta` por categoría.
- Modelo `CategoryAverageDelta` con: `categoryId` (nullable para "Sin categoría"), `name`, `colorSlug`, `iconSlug`, `historicalAverage` (prorrateado), `currentMonthSpent`, `deltaAbsolute`, `deltaPercent`.
- UI:
  - Header con chips de presets de ventana `[1, 3, 6, 12, 24]` meses.
  - Card principal con 3 métricas globales (promedio prorrateado, mes actual, delta) + semáforo + chip de estado.
  - Subtítulo explicativo del prorrateo ("Comparación al día D del mes").
  - Sección scrolleable "Desglose por categoría" con filas ordenadas por delta absoluto descendente.
- Empty / partial state: si hay <2 meses cerrados con datos de histórico, mostrar mensaje "Necesitás al menos 1 mes cerrado de uso para calcular promedio" o degradar a "Promedio basado en M meses" con M < N.
- Tests: data layer (unit) + tab (widget) siguiendo convenciones del repo.

## Fuera de alcance

- Módulo Presupuestos completo (sprint posterior, scope grande).
- Proyección hacia el final del mes (e.g. "si seguís a este ritmo terminás en $X"). Conceptualmente cerca pero distinto; queda para iteración futura.
- Comparativa de `income` (ingresos). Diego confirmó que solo le interesa gasto en esta primera versión.
- Persistir preferencias del usuario (e.g. "siempre quiero ver N=6"). Se mantiene en memoria del state del tab.
- Configuración custom de qué kinds entran en el cálculo. Hardcoded: `expense` + `credit_expense` (mismo set que el campo `expense` del Cashflow).
- Datos por cuenta (filtrar por cuenta específica). Es un agregador global.
- Mediana, trimmed mean u otros agregados estadísticos alternativos al promedio aritmético.
- Mostrar el detalle día por día del histórico (curva). Solo se usa internamente para el prorrateo.

## Reglas de negocio

- **RN-A01 (kinds incluidos)**: el "gasto" considera entries con `kind IN ('expense', 'credit_expense')` y `deleted_at IS NULL`, idéntico al criterio del reporte Cashflow para el campo `expense`. Quedan excluidos `transfer`, `debt_payment` e `income` (no son consumo del bolsillo).
- **RN-A02 (mes cerrado)**: un "mes cerrado" es cualquier mes calendario completo anterior al mes en curso. Mes en curso = mes calendario del `now` parámetro (default `DateTime.now()`).
- **RN-A03 (ventana de N meses)**: la ventana son los N meses cerrados inmediatamente anteriores. Ejemplo con N=3 y hoy 2026-06-29: ventana = marzo, abril, mayo de 2026.
- **RN-A04 (denominador del promedio)**: `monthsAvailable` = cantidad de meses cerrados dentro de la ventana **con al menos un entry** de gasto registrado. Se usa como divisor de `historicalAverage` (decisión deliberada: el promedio refleja el patrón real de consumo en los meses donde el usuario sí registró gasto). Razón: dividir por meses sin entries dilye el promedio con ceros artificiales (un mes sin ningún gasto registrado típicamente significa que el usuario no usó la app, no que su consumo real fue cero). Si M=0, retornar reporte vacío.
- **RN-A05 (mes en curso parcial)**: el "gasto del mes en curso" suma todos los entries de gasto desde el día 1 del mes actual hasta `now` (inclusive, fin del día de hoy).
- **RN-A06 (soft delete)**: entries con `deleted_at IS NOT NULL` se excluyen, igual que en Cashflow / SpendingByCategory.
- **RN-A07 (modo de comparación: prorrateado, decisión P-001)**: el promedio histórico se calcula sobre el **gasto acumulado de cada mes cerrado hasta el mismo día del mes** que `now`. Fórmula:
  ```
  historicalAverage = Σ (gasto_acumulado_mes_i_hasta_día_D) / M
  ```
  donde `D = day(now)`, `M = monthsAvailable`, `gasto_acumulado_mes_i_hasta_día_D = Σ amount` para entries del mes i con `day(occurred_at) <= D`.
- **RN-A08 (día del mes inexistente)**: si `D` (día de `now`) no existe en un mes histórico (ejemplo: hoy es 31 de mayo, en febrero no hay día 31), se usa el último día existente de ese mes. Para el ejemplo: febrero usa día 28 (o 29 si fue bisiesto).
- **RN-A09 (categorías archivadas en el desglose)**: entries con `category_id` apuntando a una categoría archivada (deleted_at IS NOT NULL) se agregan al bucket "Sin categoría" en el desglose, consistente con `spendingByCategory` (RN-R04).
- **RN-A10 (semáforo)**: color del delta según porcentaje del mes actual sobre el promedio prorrateado:
  - Verde (`positive`) si actual ≤ 95% del promedio.
  - Amarillo (`warning`) si 95% < actual ≤ 110%.
  - Rojo (`negative`) si actual > 110%.
  - Aplica tanto al delta global como al delta por categoría.
- **RN-A11 (cero promedio)**: si el promedio histórico es 0 (BD reciente o sin gasto histórico en esa categoría), no calcular delta porcentual; mostrar "—" y suprimir semáforo. Aplica también por categoría.
- **RN-A12 (orden del desglose)**: las filas del desglose por categoría se ordenan por `deltaAbsolute DESC` (mayor desviación al alza primero). Empate de delta → orden alfabético por nombre.
- **RN-A13 (categoría sin histórico)**: si una categoría tiene gasto en el mes actual pero `historicalAverage == 0`, aparece en el desglose con delta absoluto = `currentMonthSpent` y delta porcentual nulo (RN-A11).
- **RN-A14 (categoría con histórico pero sin gasto actual)**: aparece en el desglose con `currentMonthSpent = 0`, delta absoluto negativo. Útil para identificar gastos que el usuario "esperaba" y aún no realizó.

## Requisitos funcionales

- RF-001: Tab "Promedio" como 5° tab en `/reports`, después de "Saldo a fecha".
- RF-002: Header del tab con chips de presets de ventana `[1, 3, 6, 12, 24]` meses. Default seleccionado: 3.
- RF-003: Card principal con 3 métricas globales:
  - **Promedio prorrateado al día D**: total de gasto promedio de los últimos N meses cerrados hasta el día D.
  - **Mes en curso**: total de gasto del mes calendario actual hasta `now`.
  - **Delta**: diferencia (absoluta y porcentual) entre Mes en curso y Promedio prorrateado.
- RF-004: Subtítulo de la card explicando el prorrateo. Texto: "Comparación al día D del mes (basado en M meses cerrados)" donde D = `currentDayOfMonth` y M = `monthsAvailable`.
- RF-005: Semáforo de color del delta global según RN-A10. El color aplica al número del delta y a un chip de estado ("Por debajo", "En línea", "Por encima").
- RF-006: Sección "Desglose por categoría" debajo de la card global:
  - Filas tipo `BaseCard` con: badge color+icon, nombre, promedio prorrateado, gasto actual, delta abs+%.
  - Ordenadas según RN-A12.
  - Semáforo de color por fila siguiendo RN-A10.
- RF-007: Empty state cuando M=0 (sin meses cerrados con datos): icono + texto "Necesitás al menos 1 mes cerrado de uso para calcular promedio".
- RF-008: Método `ReportsService.monthlyAverage({ required int monthsBack, DateTime? now })` retorna `Stream<MonthlyAverageReport>` con `customSelect.watch(readsFrom: {journalEntries, categories})` para reactividad consistente con el resto de reportes (suma `categories` porque el desglose necesita join con la tabla).
- RF-009: Modelo `MonthlyAverageReport` inmutable con campos:
  - `monthsRequested: int`
  - `monthsAvailable: int`
  - `windowFrom: DateTime`, `windowTo: DateTime`
  - `currentDayOfMonth: int`
  - `historicalAverage: double` (prorrateado)
  - `currentMonthSpent: double`
  - `deltaAbsolute: double`
  - `deltaPercent: double?` (null si historicalAverage == 0)
  - `categoryBreakdown: List<CategoryAverageDelta>`
  - `bool get isEmpty` para empty state (cuando monthsAvailable == 0).
- RF-010: Modelo `CategoryAverageDelta` inmutable con: `categoryId` (nullable para "Sin categoría"), `name`, `colorSlug` (nullable), `iconSlug` (nullable), `historicalAverage`, `currentMonthSpent`, `deltaAbsolute`, `deltaPercent` (nullable).
- RF-011: El tab cachea el `Stream` en el state (patrón de los otros tabs) para que `pumpAndSettle` asiente correctamente en widget tests.
- RF-012: Cambiar el preset N reinicia el `Stream` (nuevo `_buildStream()` con `monthsBack` actualizado).

## Casos principales

- **CP-01**: Diego tiene 6+ meses de uso, abre tab Promedio con preset 3 default. Ve promedio basado en últimos 3 meses cerrados prorrateado al día actual + gasto del mes actual + delta global con semáforo. Debajo, ve desglose por categoría ordenado por delta absoluto.
- **CP-02**: Diego cambia preset de 3 → 6 meses. La card y el desglose se recalculan. Subtítulo y footer reflejan "6 meses cerrados".
- **CP-03**: Diego cambia preset a 24 meses pero solo tiene 5 meses de histórico. El reporte usa los 5 meses, subtítulo indica "5 meses cerrados (M < 24)".
- **CP-04**: BD nueva sin meses cerrados → empty state amigable.
- **CP-05**: Hay meses cerrados pero promedio = 0 (sin gasto histórico). Mostrar "Promedio: $0.00" y delta sin porcentaje (`—`). El desglose también queda vacío o solo con categorías del mes actual.
- **CP-06**: Diego identifica gracias al desglose que la categoría "Comida fuera" está 80% arriba del promedio (delta rojo), aunque el global está en línea (verde) porque otras categorías compensan.

## Casos borde

- **CB-T01**: `now` = primer día del mes. Mes en curso tiene 1 día de datos posibles. Histórico se prorratea al día 1: solo cuentan entries del día 1 de los meses cerrados. Comparación justa pero con valores chicos.
- **CB-T02**: Mes en curso = enero. Ventana N=3 cruza año (octubre, noviembre, diciembre del año previo).
- **CB-T03**: `now` = día 31. Histórico se prorratea al día 31; meses con menos de 31 días usan último día (RN-A08).
- **CB-T04**: Mes cerrado intermedio con 0 entries de gasto. **NO contribuye al promedio**: ni al numerador (no hay entries) ni al denominador (`monthsAvailable` lo excluye, según RN-A04). El promedio refleja solo los meses con consumo registrado. Sienta precedente del comportamiento "promedio condicional al uso" que también aplicará en el módulo Presupuestos futuro.
- **CB-T05**: Entry exacto a las 23:59:59.999 del día D de un mes cerrado. Debe contar en el acumulado hasta el día D (filtro `day(occurred_at) <= D`).
- **CB-T06**: Soft delete de un entry mientras el reporte está abierto. El stream debe re-emitir automáticamente.
- **CB-T07**: Entry con `kind = credit_expense` y `account_origin_id` apuntando a tarjeta activa: cuenta como gasto.
- **CB-T08**: Cambio de mes entre apertura del tab y refresh (cruce de medianoche). En la primera versión basta con que el tab se reconstruya en el siguiente `setState`/cambio de tab.
- **CB-T09**: Histórico con outlier (un mes con compra grande). El promedio aritmético incluye el outlier; v1 no ofrece mediana ni filtrado. Aceptable.
- **CB-T10**: Categoría nueva creada este mes sin histórico → aparece en desglose con `historicalAverage = 0` y delta porcentual nulo (RN-A13).
- **CB-T11**: Categoría archivada con entries históricos → sus entries históricos contribuyen al bucket "Sin categoría" del desglose (RN-A09). El bucket "Sin categoría" puede aparecer con histórico no trivial.
- **CB-T12**: Día D no existe en mes histórico (e.g., D=31 en febrero). Usa último día disponible (RN-A08). El cálculo NO falla.
- **CB-T13**: Todas las categorías en delta verde → el desglose se renderiza igual, sin filtros. Diego puede ver la lista completa.

## Criterios de aceptación

- **AC-01**: Al abrir `/reports` y seleccionar "Promedio", se ve un tab con título "Promedio" en español como 5° opción del TabBar.
- **AC-02**: Con seed de N meses de datos (verificable en widget test), el promedio prorrateado mostrado coincide con `Σ(gasto_acumulado_mes_i_hasta_día_D) / M` redondeado a 2 decimales.
- **AC-03**: El delta porcentual mostrado es `(currentMonthSpent - historicalAverage) / historicalAverage * 100`, redondeado a 1 decimal. Si `historicalAverage == 0`, muestra "—".
- **AC-04**: El color del número del delta cumple RN-A10 (verde/amarillo/rojo según umbrales). El chip de estado dice "Por debajo / En línea / Por encima" coherente con el color.
- **AC-05**: Cambiar el preset de N=3 a N=6 actualiza la card y el desglose sin recargar pantalla, en <500ms (`pumpAndSettle` del widget test debe terminar).
- **AC-06**: BD sin entries muestra empty state con copy claro y sin error.
- **AC-07**: Cancelar (soft-delete) un entry desde otra pantalla actualiza el reporte automáticamente al volver al tab (`watch` reactivo).
- **AC-08**: El desglose por categoría está ordenado por delta absoluto descendente; empate alfabético (RN-A12).
- **AC-09**: Una categoría con `currentMonthSpent > 0` y `historicalAverage == 0` aparece en el desglose con delta absoluto = `currentMonthSpent` y delta porcentual "—".
- **AC-10**: 0 errores en `flutter analyze`, suite completa verde en `flutter test`.

## Criterios medibles de éxito

- **CME-01**: `flutter test` pasa con al menos +15 tests nuevos cubriendo data layer (`monthlyAverage`, prorrateo, desglose) y widget (tab + presets + breakdown).
- **CME-02**: `flutter analyze` no introduce warnings o errores nuevos (los 4 hints `info` preexistentes siguen tolerados).
- **CME-03**: Tiempo de cálculo del reporte para una BD con 1k entries, N=24 y desglose por 30 categorías es <100ms (medible con perf log si Diego lo solicita; default no obligatorio).
- **CME-04**: La card global cabe en una pantalla típica; el desglose hace scroll independiente o continúa el scroll del tab.
- **CME-05**: Diego puede usar el reporte para identificar **al menos una categoría** desviada >10% sin necesidad de mirar Gasto por categoría.

## Riesgos

- **R-01**: Cálculo del prorrateo requiere agregar gastos por mes + día del mes. La query SQL puede crecer en complejidad. Mitigación: query agregada con `strftime` o agrupación equivalente en Dart sobre filas mensuales. Definir en plan técnico.
- **R-02**: Outliers en el histórico distorsionan el promedio. Aceptado en v1; documentar como mejora futura (mediana o trimmed mean).
- **R-03**: Si `now` se inyecta vs `DateTime.now()` directo, los widget tests son más estables pero el método queda menos limpio. Mitigar con parámetro opcional `DateTime? now` que default a `DateTime.now()`.
- **R-04**: Performance del cálculo con journals grandes (>10k entries) + desglose denso no medido. Mitigar: una sola query agregada `SUM(amount) GROUP BY year, month, category_id` filtrando por día del mes, evitar fan-out en Dart.
- **R-05**: Categorías archivadas en el desglose pueden confundir si el bucket "Sin categoría" aparece con histórico grande. Mitigar con label claro y consistencia con `spendingByCategory`.
- **R-06**: La regla RN-A08 (día inexistente → último día) puede generar pequeños sesgos para D=31 (febrero da 28-29, no 31). Aceptado y documentado; no es crítico para el uso esperado.

## Supuestos

- **S-01**: Sin schema bump. Toda la información necesaria ya está en `journal_entries`.
- **S-02**: Sin nuevas dependencias en `pubspec.yaml`.
- **S-03**: La fecha actual `now` se toma de `DateTime.now()` por default, con override opcional para tests.
- **S-04**: Los presets de N son hardcoded `[1, 3, 6, 12, 24]`. No hay UI de "custom N" en v1.
- **S-05**: Default N = 3 al abrir el tab. Diego validó que es el más común en literatura financiera.
- **S-06**: Default preset (N=3) se elige al ingresar al tab cada vez (no se persiste preferencia entre sesiones).
- **S-07**: Solo se mide **gasto**, no ingresos.
- **S-08**: El tab se ubica como 5° (al final). Diego puede pedir reordenamiento posteriormente; cambio mínimo.
- **S-09**: La paleta y el patrón visual heredan tokens existentes en `FincoreColors` y patrón `BaseCard`.
- **S-10**: El método del servicio respeta el patrón reactivo del resto: `Stream` con `customSelect(...).watch(readsFrom: {...})`.
- **S-11**: El desglose muestra **todas** las categorías con histórico o gasto actual en el rango. Sin paginación, sin límite top-N (BD single-user esperada <50 categorías activas).
- **S-12** (quality review v1): la fórmula del promedio es "condicional al uso" — ver RN-A04 + CB-T04. Si un mes cerrado tiene 0 entries de gasto, no participa ni en numerador ni en denominador. Esto refleja mejor el patrón real del usuario que un promedio diluido con ceros artificiales, y mantiene coherencia con el módulo Presupuestos futuro donde un mes "sin uso" tampoco debería arrastrar el promedio a la baja.

## Impacto esperado

- **Funcional**: Diego puede responder de un vistazo si su gasto del mes está alineado con su patrón habitual y, en la misma pantalla, identificar en qué categorías se está desviando.
- **Preparatorio**: el método `monthlyAverage` queda disponible para el módulo Presupuestos futuro (mismas reglas de inclusión por kind, misma definición de "mes en curso", mismo prorrateo).
- **Técnico**: introduce el patrón de "ventana móvil de N meses" + prorrateo intra-mes, reusable para reportes futuros (proyección, comparativa interanual).
- **Confianza del producto**: refuerza el dataset que va a alimentar el presupuesto. Diego está incentivado a registrar todos los gastos porque el desglose categórico le sirve más mientras más fiel sea la captura.
