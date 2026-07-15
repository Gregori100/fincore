# Reports shared widgets (Sprint 5 acotado)

## Resumen

Sprint 5 del roadmap 2026-07-14. Scope acotado: extraer `DeltaChip` a widget compartido y crear `FincoreEmptyState` genérico. **No cambia arquitectura de tabs a hub** (queda para sprint futuro por complejidad/riesgo).

Bump `0.23.0+100` → `0.24.0+101`.

## Problema a resolver

- `_DeltaChip` privado en `cashflow_tab.dart` con helpers `_deltaColor`/`_formatDelta`. La auditoría propone reusarlo en drill-downs de spending/income por categoría, credit_cards, balance_at_date. Diferido por scope.
- Empty states inconsistentes (audit P3.7): `credit_cards_tab` y `budgets_tab` tienen empty premium con CTA; el resto usa `Text` centrado en `textMuted`. Sin componente compartido.

## Objetivo

1. Extraer `DeltaChip` público a `mobile/lib/widgets/delta_chip.dart` con helpers `deltaColor` y `formatDelta`.
2. Crear `FincoreEmptyState({icon, title, body?, cta?})` en `mobile/lib/widgets/fincore_empty_state.dart` — base compartida para reemplazar empty states ad-hoc en sprints siguientes.
3. Actualizar `cashflow_tab.dart` para consumir `DeltaChip` compartido.

## Alcance

- Nuevo `mobile/lib/widgets/delta_chip.dart`: `DeltaChip` widget + `deltaColor` + `formatDelta` como top-level públicos.
- Nuevo `mobile/lib/widgets/fincore_empty_state.dart`: widget genérico con ícono 48px `textMuted`, título `headingM`, body opcional `bodyM textMuted`, CTA opcional (Widget).
- `cashflow_tab.dart`: reemplaza `_DeltaChip(...)` por `DeltaChip(...)` (import agregado), elimina el widget privado y helpers `_deltaColor`/`_formatDelta`.
- Bump.

## Fuera de alcance

- Hub visual reemplazando tabs (audit P1.1). Diferido — requiere rediseño arquitectural completo + spec propia.
- `ReportShell` compartido (audit P1.2). Diferido — cada tab tiene estructura muy diferente; consolidarlo requiere sprint dedicado.
- Migración de todos los reports a `FincoreEmptyState`. Solo se crea el componente en este sprint; consumidores adoptan en sprints por módulo.
- Fusión de spending/income por categoría en 1 tab (audit P2.2). Diferido.

## Requisitos funcionales

- **RF-001**: `mobile/lib/widgets/delta_chip.dart` expone `DeltaChip` público con misma API/comportamiento que el `_DeltaChip` privado extraído.
- **RF-002**: `deltaColor(direction, {isExpenseSide})` y `formatDelta(DeltaPercent)` públicos en el mismo archivo.
- **RF-003**: `mobile/lib/widgets/fincore_empty_state.dart` expone `FincoreEmptyState` con parámetros `icon`, `title`, `body?`, `cta?`.
- **RF-004**: `cashflow_tab.dart` importa y consume `DeltaChip`; `_DeltaChip`/`_deltaColor`/`_formatDelta` eliminados.
- **RF-005**: `pubspec.yaml` bumpea a `0.24.0+101`, `build.gradle.kts` `versionCode = 101 / versionName = "0.24.0"`.
- **RF-006**: `flutter analyze` verde. `flutter test` 707+ verdes sin regresión.

## Casos principales

1. Usuario abre sheet de desglose del cashflow: cada bucket muestra `DeltaChip` con `+45%`/`×2.4`/`-15%` según el helper unificado.

## Casos borde

- Sin `body` y sin `cta`: `FincoreEmptyState` muestra solo ícono + título centrados.
- `DeltaChip` con `delta == null`: muestra `—`.

## Criterios de aceptacion

- `grep -rn "_DeltaChip\|_deltaColor\|_formatDelta" mobile/lib/screens/reports/cashflow_tab.dart` retorna 0 (menos el comentario del refactor).
- `flutter analyze` verde.
- `flutter test` 707/707.

## Criterios medibles de exito

- 3 widgets/helpers extraídos a componentes públicos.
- Sin regresión en tests.

## Riesgos

- Bajo. Cambio contenido; API pública nueva sin dependientes externos aún.

## Supuestos

- Los tests actuales del cashflow_tab no matchean `_DeltaChip` por type (privado). Verificado.

## Impacto esperado

- Base para reutilizar en Sprint 8 (accounts polish con delta chip) y sprints futuros de reports.
- `FincoreEmptyState` reduce duplicación de código en próximos sprints.
