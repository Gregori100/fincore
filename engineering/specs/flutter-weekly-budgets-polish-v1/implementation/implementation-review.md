# Implementation Review: flutter-weekly-budgets-polish-v1

## Resumen

Sprint 7 acotado. BalanceFooter con INGRESOS + GASTOS visibles arriba de la barra.

## Archivos modificados

- `mobile/lib/screens/weekly_budgets/widgets/balance_footer.dart` — nuevo widget privado `_MiniAmount` + Row de 3 columnas (INGRESOS · percent · GASTOS) reemplaza el header "GASTOS PLANEADOS" solo. Skeleton state preserva layout.
- `mobile/test/screens/weekly_budgets/detail_screen_test.dart` — 4 matchers actualizados (GASTOS PLANEADOS → INGRESOS/GASTOS; findsNWidgets(2) → findsWidgets por duplicación de monto en mini-amount).
- Bump `0.25.1+103`.

## Tareas completadas

RF-001 a RF-005.

## Tareas pendientes (diferidas)

- H1 "Esta semana" hero, H3 compare colors, H5 multi-select, H8 KindPicker mejorado, H9 calendar leyenda.

## Pruebas realizadas

- `flutter test`: 707/707 verdes.
- `flutter analyze`: verde.

## Recomendaciones code review

- Verificar que en 360dp el Row de 3 columnas no se desborda cuando los amounts son grandes.
