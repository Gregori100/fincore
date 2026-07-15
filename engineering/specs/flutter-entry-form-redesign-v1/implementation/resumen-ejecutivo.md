# Resumen ejecutivo — flutter-entry-form-redesign-v1

## Qué se implementó

Sprint 3 del roadmap. El flujo de registro de movimientos —el más frecuente de la app— fue rediseñado por completo. El monto es ahora un hero visual de 36sp con formato de miles en vivo y color por tipo de movimiento. La fecha se elige con chips "Hoy/Ayer/Anteayer/Otro" (1 tap vs 4 antes). El botón Guardar está siempre visible en el AppBar. El KindPicker pasó de columna vertical (330dp) a grid compacto (~180dp). El CategoryPicker pasó de dropdown a bottom sheet con búsqueda, agrupación por tipo, y MRU en memoria.

Cero cambios de dominio. Cero schema. Sin regresión funcional.

## Impacto esperado

- **Captura estándar de gasto**: bajó de ~7-8 taps a ~5 taps.
- **Amount input**: rechaza inputs inválidos en tiempo real (`1.2.3` no se acepta), formato de miles automático (`1500` → `1,500`).
- **Fecha**: 90% de los movimientos son de hoy/ayer — ahora se marcan con 1 tap.
- **Category picker**: escala a 30-50 categorías con search + agrupación (antes era scroll lineal sin búsqueda).
- **KindPicker**: ocupa 180dp vs 330dp — cabe en cualquier pantalla sin scroll.
- **Percepción**: amount input hero + tabular figures + color emocional dan un feel más premium.

## Riesgos o pendientes relevantes

- Smoke desktop + Android pendientes de validación por Diego.
- 1 excepción documentada: `fontSize: 36` del amount hero fuera de la escala tipográfica. Si aparecen más heros grandes en sprints siguientes, se considerará agregar `displayS` al sistema de tokens.

## Estado de pruebas

- `flutter analyze`: **verde**.
- `flutter test`: **707/707 verdes** (681 previos + 26 nuevos del `AmountInputFormatter`).
- Guardrail de español neutral del Sprint 2 sigue verde.

## Próximo paso

Sprint 4 — Dashboard clarity (invertir jerarquía KPIs BO/DE/CR, first-run reescrito, chip filtros dentro del grupo Movimientos, credit utilization con barra).
