# Pendientes — flutter-ui-test-coverage-v1

Trabajo no terminado al cierre del sprint o diferido a sprints futuros.

## Pendientes inmediatos

- **Smoke manual del 0.3.9+41** (Diego post-merge): instalar APK arm64 sobre `0.3.8+40`, verificar Settings → "Acerca de" muestra `0.3.9+41`. Los flujos de UI están cubiertos por la suite + el smoke del v3/v4 sigue válido.

## Diferidos del v1 (con detalle para sprint futuro)

### DV-1 v1 — Pago de tarjeta + Transferencia sin dropdown verify

**Esfuerzo estimado:** 2-3 h. El gap es la **contaminación de overlays Material 3** entre tests del isolate.

**Solución correcta identificada:**
- Opción A: agregar `addTearDown(() => tester.binding.reset())` en cada test que abre dropdown.
- Opción B: migrar `_DropdownMenu` de Material 3 a un widget custom con `Key` específico.
- Opción C: investigar si `WidgetsBinding.instance.focusManager.primaryFocus?.unfocus()` limpia el overlay.

**Por qué no se hizo en v1:** ROI menor. El filtro RN-011 ya queda blindado por Ingreso (cash/debit) + Gasto (cash/debit) + Gasto a tarjeta (credit).

### DV-2 v1 — Account CRUD con 3 tests (no los 5 del plan)

**Esfuerzo estimado:** 2-3 h para los 3 casos faltantes (alta vacía + duplicate_name + Bolsa protected).

**Por qué no se hizo en v1:** los 3 casos faltantes son polishing aditivo. El path crítico UI → DAO está cubierto por alta + edición. Los validators y errores del DAO están blindados en `database_test.dart`.

## Diferidos heredados (v3 + v4)

- **L1-H6 (Future.delayed en tests):** patrón heredado, migrar a `expectLater` cuando se ataque la suite por completo.
- **L1-H7 (`harness.dispose()` race):** requiere acceso al tester desde dispose. Refactor invasivo.
- **L2-H3 / RF-014 (`hasListener` guard):** descartado por causar cuelgues. Si aparece `Bad state` en producción, atacar con `try/catch` puntual en lugar del guard.
- **Tests de widget_test_harness para multi-isolate parallel:** no aplica al scheduler actual.

## Sin diferidos del backlog histórico

Todos los ítems del backlog `flutter-local-mvp` que fueron parte de los hardening v1-v4 quedaron cerrados o tienen plan claro de continuación.

## Próximo sprint sugerido

**Reportes** (cashflow mensual, gasto por categoría, top categorías por monto). Antes de planear, definir filosofía del balance derivado:

- `FinancialStateService` actual agrega totales sin filtro de fecha.
- Reportes querés cortes "hasta hoy" o por rango → filtrar por `occurred_at`.

Recomendación: arrancar con un `ReportsService` separado y dejar `FinancialStateService` intacto. Más mantenible.
