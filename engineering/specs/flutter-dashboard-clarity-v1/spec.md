# Dashboard clarity (Sprint 4)

## Resumen

Sprint 4 del roadmap 2026-07-14. Ataca 3 fricciones de comprensión del dashboard identificadas en la auditoría (Dashboard P1 jerarquía KPIs + P2 chip filtro + P2 sparklines + First-run P1) + 1 regla pendiente (`credit` type debe migrar de `warning` a color neutro según CLAUDE.md).

Bump `0.22.0+99` → `0.23.0+100`.

## Problema a resolver

1. **KPIs BO/DE/CR en criptograma**: el `_TotalCard` renderiza el código corto (`BO`) grande y descriptivo (`Bolsa + Débito`) en 10sp textSubtle. Un usuario nuevo tarda 3-5 sesiones en decodificarlos.
2. **First-run**: dos cards equivalentes (Importar / Arrancar limpio), copy con jerga técnica (`BD`, `Bolsa singleton`, `10 categorías por defecto`).
3. **Chip filtro de cuenta** entre secciones (después del SectionTitle "Últimos movimientos" pero visualmente independiente): parece que filtra el dashboard completo cuando solo filtra la lista de abajo.
4. **`credit` type = `warning` (amarillo)** en `_typeColor` — viola la regla de CLAUDE.md ("warning para alertas operativas, NO para tipos de cuenta").
5. **Sparklines por card con escala independiente**: comparación visual imposible entre cards; sin data delta explícito.

## Objetivo

1. Invertir la jerarquía del `_TotalCard`: label descriptivo arriba (más grande), código BO/DE/CR desaparece o queda como caption.
2. First-run reescrito: "Arrancar limpio" recomendado (borde accent + orden invertido), copy sin jerga.
3. Chip filtro dentro del bloque "Últimos movimientos" (visualmente agrupado con la lista que filtra).
4. `credit` type migra de `warning` a `textMuted` (o color propio) en `_typeColor`.
5. Sparklines: agregar delta numérico "+2.3%" o quitar la escala visual (mantener el trend). Elección en implementación.

## Alcance

### `dashboard_screen.dart` `_TotalCard` (jerarquía KPIs)

- Nuevo layout del card:
  - Label descriptivo arriba (`label` token, `w600`, `textMuted`): "BOLSA + DÉBITO", "DEUDA", "DISPONIBLE".
  - Monto grande centrado (`fontSize: 26` hero, `w800`, color según semántica).
  - Código `BO/DE/CR` en `overline` caption abajo (o eliminarlo).
  - Sparkline conservado si aplica (fallback: delta numérico + trend arrow).

### `dashboard_screen.dart` `_typeColor` para tipo credit

- `credit` mapea a `FincoreColors.textMuted` (color neutro).
- El card de tarjeta de crédito en el dashboard sigue mostrando "Deuda" con `negative`, pero el ícono del tipo pasa a neutral.

### `dashboard_screen.dart` chip filtro dentro del grupo Movimientos

- Reorganizar: envolver `SectionTitle('Últimos movimientos')` + `_AccountFilterChips` + la lista dentro de un `BaseCard` o un `Column` con background sutil `surface` que los agrupa visualmente. Padding interno consistente.
- El SectionTitle puede tener un `trailing: IconButton(Icons.filter_list)` que abre el filtro (o mantener los chips inline; decidir según densidad).

### Sparklines (`dashboard_screen.dart` `_Sparkline`)

- Agregar delta numérico `+2.3%` (o `-$120`) en `bodyS textMuted` al lado del label. Da anclaje verbal al trend visual.
- Alternativa: quitar la escala independiente (mantener línea sin y-scale, solo dirección). Decidir en implementación por comparación visual.

### `first_run_screen.dart`

- Reordenar: **"Arrancar limpio" primero**, marcado como recomendado (border 2px `accent` + badge "Recomendado" opcional).
- Reescribir copy sin jerga:
  - "Arrancar limpio" → título "Empezar desde cero"; descripción "Crea tu Bolsa y 10 categorías listas para usar. Puedes agregar cuentas y ajustar todo después."
  - "Importar respaldo" → título; descripción "¿Ya usaste FinCore antes? Restaura tu archivo `.json`."
- Header: "¿Cómo quieres empezar?" (pregunta directa, tuteo, sin dos puntos).
- Si el `FilePicker` cancela sin resultado en import: mostrar `showInfoSnackbar` (o silencio con log — decidir).

### Documentación

- `CLAUDE.md`: nota en "Sistema de tokens de diseño" que el sprint aplicó la regla "credit no usa warning".
- Bump `0.23.0+100`.

## Fuera de alcance

- Sparklines completamente reescritos con escala compartida (más complejo, evaluar en sprint futuro).
- Reorganización de la topbar (`Icons.calendar_month_outlined` para presupuestos): audit lo marcó como P2 pero es Sprint 6 (component library) donde se puede consolidar iconografía.
- Detalle de cada cuenta al tap (audit P3).
- Long-press para toggle privacy mode (P4).

## Reglas de negocio

- Los códigos BO/DE/CR desaparecen del display principal pero pueden vivir en `Semantics.label` para accesibilidad (screen readers). No es prioridad este sprint.
- El chip "Recomendado" en first-run debe ser visualmente obvio pero no gritón — border 2px accent es suficiente.

## Requisitos funcionales

- **RF-001**: `_TotalCard` renderiza label descriptivo arriba (`label` token con `textMuted`), monto grande centrado (26sp w800), código BO/DE/CR eliminado del display principal o degradado a `overline` caption.
- **RF-002**: `_typeColor(credit)` retorna `FincoreColors.textMuted` (era `warning`).
- **RF-003**: en el dashboard, `SectionTitle('Últimos movimientos')` + chips filtro + lista viven en el mismo bloque visual (envueltos en un container/card con background y padding coherentes).
- **RF-004**: `_Sparkline` (si se preserva) tiene delta numérico visible al lado del label del card, o se reemplaza por un indicador más simple.
- **RF-005**: `first_run_screen.dart` reordena las 2 cards con "Arrancar limpio" primero, marcado como recomendado (border 2px `accent`). Copy reescrito sin jerga (`BD`, `singleton`, `defecto`).
- **RF-006**: `pubspec.yaml` bumpea a `0.23.0+100`, `build.gradle.kts` `versionCode = 100 / versionName = "0.23.0"`.
- **RF-007**: `flutter analyze` verde. `flutter test` 707+ verdes (matchers actualizados donde matchea copy viejo).

## Casos principales

1. Usuario nuevo abre la app → first-run con card "Empezar desde cero" recomendado arriba → tap → dashboard con KPIs claros (BOLSA + DÉBITO grande, monto grande).
2. Usuario existente ve el dashboard → identifica los 3 números principales sin decodificar códigos.
3. Usuario tap chip de filtro "Bolsa" → la lista de movimientos abajo se filtra; los KPIs no cambian (comportamiento previo, ahora visualmente claro).

## Casos borde

- BD vacía sin ninguna cuenta → `_TotalCard` muestra $0.00; label sigue siendo "BOLSA + DÉBITO" (no cambia).
- credit type sin balance → ícono en `textMuted` (no gritón).
- First-run tras wipe → `Arrancar limpio` recomendado nuevamente.

## Criterios de aceptacion

- Al abrir dashboard, los 3 números son legibles sin memorizar códigos.
- Al abrir first-run, "Arrancar limpio" está visualmente destacado como opción por defecto.
- El chip filtro de cuenta está visualmente agrupado con la lista de movimientos.
- Icons de tipo credit ya no son amarillos.
- `flutter test` verde.

## Criterios medibles de exito

- Reducción de las 3 labels de 20sp textSubtle → **cero** códigos BO/DE/CR grandes.
- Reducción de instancias de `warning` para credit: de N a **0**.
- Al menos 1 comentario `// token-exception:` nuevo esperado por el hero 26sp del monto principal.

## Riesgos

- Cambios visuales grandes en dashboard — validar en smoke.
- El chip de filtro dentro del bloque puede reducir el espacio; ver si cabe bien en 360dp.

## Supuestos

- El comentario existente `// A5` sobre "Categorías movida al overflow por wordmark wrap" sigue vigente; no se toca la topbar.
- La regla del CLAUDE.md sobre `credit != warning` se ejecuta en este sprint como quedó documentado.

## Impacto esperado

- Primer contacto más claro (nuevos usuarios entienden dashboard sin explicación).
- First-run con recomendación clara reduce fricción de decisión.
- Chip filtro agrupado reduce ambigüedad "¿esto filtra todo o solo esto?".
- `credit` neutro libera `warning` para su uso semántico correcto (alertas operativas).
