# Weekly budgets polish — BalanceFooter (Sprint 7 acotado)

## Resumen

Sprint 7 del roadmap 2026-07-14 con scope acotado. Rediseña `BalanceFooter` de weekly budgets para eliminar aritmética mental (audit H2): agrega 2 mini-amounts INGRESOS + GASTOS visibles arriba de la barra de progreso.

**Scope reducido**: los otros hallazgos del sprint (H1 "Esta semana" hero, H3 compare deltas, H5 multi-select discoverability, H9 calendar leyenda) quedan para sprints polish futuros.

Bump `0.25.0+102` → `0.25.1+103` (patch).

## Alcance

- `mobile/lib/screens/weekly_budgets/widgets/balance_footer.dart`:
  - Reemplaza el header "GASTOS PLANEADOS" solo por Row con 2 `_MiniAmount`:
    - `INGRESOS` label + monto verde (positive).
    - `GASTOS` label + monto rojo (negative).
    - Percent label en el centro.
  - Widget privado nuevo `_MiniAmount(label, amount, color, alignEnd)`.
  - Skeleton state actualizado para mantener el layout de 3 filas.
- 2 tests actualizados (`WT-DS01` matcher GASTOS PLANEADOS → INGRESOS/GASTOS; `WT-DS02/03/05` matchers findsNWidgets(2) → findsWidgets por duplicación de amounts).

## Fuera de alcance

- H1: "Esta semana" hero card.
- H3: colores emocionales en compare deltas.
- H5: multi-select discoverability.
- H8: KindPicker sheet mejorado.
- H9: calendar leyenda + dots semánticos.

## Requisitos funcionales

- **RF-001**: BalanceFooter tiene Row con `_MiniAmount(INGRESOS)` + percent + `_MiniAmount(GASTOS)` como primera fila.
- **RF-002**: `_MiniAmount` render con label uppercase (10sp w600) + monto formateado (13sp w700 color emocional).
- **RF-003**: skeleton state preserva el layout de 3 filas.
- **RF-004**: bump `0.25.1+103`.
- **RF-005**: `flutter test` 707+ verdes.

## Criterios de aceptación

- Footer muestra INGRESOS + GASTOS en cualquier presupuesto con al menos 1 item.
- Tests actualizados verdes.

## Impacto

- Elimina la necesidad de hacer aritmética mental para saber cuánto entra vs cuánto sale.
- Base para posibles agregados futuros (delta vs semana anterior, etc.).
