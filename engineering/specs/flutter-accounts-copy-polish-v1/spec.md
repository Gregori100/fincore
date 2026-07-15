# Accounts copy polish (Sprint 8 acotado)

## Resumen

Sprint 8 del roadmap 2026-07-14 con scope acotado a copy fixes de mayor impacto en `account_form_screen.dart`:

- Header "Metadata de la tarjeta" → "Datos de la tarjeta" (audit P2 Accounts).
- Validators telegráficos "1-31" y "Distinto al corte" → frases completas (audit P2.5).

**Scope reducido**: los otros hallazgos (agrupación por tipo con subtotales P1, credit utilization bar P1, Bolsa detail screen P2, live preview de categorías P2, poda catálogo de iconos P2) quedan para sprints dedicados.

Bump `0.25.1+103` → `0.25.2+104` (patch).

## Alcance

- `account_form_screen.dart` línea 278: "Metadata de la tarjeta" → "Datos de la tarjeta".
- `account_form_screen.dart` líneas 323, 341: `return '1-31'` → `return 'Debe estar entre 1 y 31.'`.
- `account_form_screen.dart` línea 344: `return 'Distinto al corte'` → `return 'Debe ser un día distinto al corte.'`.
- Test actualizado: `account_form_screen_test.dart:236` matcher.

## Fuera de alcance

- P1: lista de cuentas agrupada por tipo + subtotales.
- P1: Bolsa detail screen (dead-end).
- P1: credit utilization bar visual.
- P2: AccountBalanceHint más visible (P2.5).
- P2: `_ProtectedView` (P2 Bolsa dead-end).
- Todos los polish de Categorías (5 hallazgos P1/P2).

## Requisitos

- **RF-001**: 4 copy fixes en `account_form_screen.dart`.
- **RF-002**: 1 test matcher actualizado.
- **RF-003**: bump `0.25.2+104`.
- **RF-004**: `flutter test` 707/707 verdes.

## Impacto

- Elimina 3 sitios de copy débil/técnico en el flujo de creación de tarjetas.
