# Resumen ejecutivo — flutter-ui-test-coverage-v1

**Status:** sprint cerrado con 5 fases entregadas (1 parcial). Resuelve la deuda de UI testing del v4. APK `0.3.9+41` validado. Suite **112 → 123 tests verdes** (+11).

## Qué entregó el sprint

### Patrón del Material 3 DropdownMenu identificado (Fase 1)

`tester.tap(find.text(label))` NO logra hit-test sobre el field. Fix: `tap` directo del `DropdownMenu<String>` localizado via `find.ancestor`. Helpers `openDropdownByLabel` + `verifyDropdownItems` en el harness. **Reusable para sprints futuros.**

### Cobertura UI cierra el 80% del backlog del v4

| Fase | Áreas cubiertas | Tests |
|------|-----------------|-------|
| 1 | RN-011 en dropdowns (3 kinds) | 0 nuevos, 3 ampliados |
| 2 | Settings destructivas | 2 |
| 3 | Entries_list bottom sheet | 3 |
| 4 | Category_form preview live | 3 |
| 5 | Accounts CRUD | 3 |

### Resolución del cuelgue del v4 RF-020

El v4 documentó el cuelgue del account_form_screen como "10-12 min sin avance, causa desconocida". **Causa real:** el botón submit está fuera del viewport 800x600. Fix de 3 líneas con `scrollUntilVisible`. RF-020 cerrado en el primer intento.

### 4 convenciones nuevas documentadas

- Tap del `DropdownMenu<String>` por field localizado.
- NO `pumpAndSettle` con Settings montado (FutureBuilder de PackageInfo nunca resuelve).
- `scrollUntilVisible` para botones submit fuera del viewport.
- Cleanup de overlays Material 3 entre tests sigue siendo problema abierto (DV-1).

## Qué se decidió diferir

- **DV-1**: Pago de tarjeta + Transferencia sin dropdown verify por contaminación de overlays Material 3 entre tests. Cobertura semántica del filtro RN-011 ya queda en los otros 3 kinds.
- **DV-2**: RF-020 con 3 tests (no los 5 del plan). Path crítico UI → DAO cubierto; casos de polishing (alta vacía, duplicate_name, Bolsa protected) deferidos.

## Métricas

| Métrica | Antes (v4 cerrado) | Después (v1 cerrado) | Δ |
|---------|--------------------|-----------------------|---|
| Tests automatizados | 112 | 123 | +11 |
| Cobertura capa UI | 16 widget tests | 27 widget tests | +11 |
| Tiempo de suite | 6 seg | ~11 seg | +5 seg |
| Versión APK | 0.3.8+40 | 0.3.9+41 | +1 patch |
| Convenciones documentadas | (varias) | +4 nuevas | — |

## Riesgos cubiertos

- **Regresión de RN-011 en kinds simples**: blindado por dropdown verify (3 kinds).
- **Regresión de reset destructivo de cuenta**: blindado por settings_screen_test.
- **Regresión del filtro de entries_list**: blindado por entries_list_screen_test.
- **Regresión del preview de category_form**: blindado por category_form_screen_test.
- **Regresión del CRUD básico de cuentas**: blindado por account_form_screen_test.

## Próximo paso natural

**Sprint de reportes** (cashflow mensual, gasto por categoría). Antes de planear, definir filosofía del balance derivado:
- `FinancialStateService` actual agrega totales sin filtro de fecha.
- Reportes necesitan cortes por fecha → filtrar por `occurred_at`.

Recomendación: arrancar con un `ReportsService` separado y dejar `FinancialStateService` intocado.
