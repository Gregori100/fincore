# Resumen ejecutivo — flutter-design-tokens-v1

## Qué se implementó

FinCore ahora tiene un **sistema de tokens de diseño explícito**: tipografía (7 estilos con nombre), spacing (7 valores + semánticos derivados), radios (5), alphas semánticos (4) y motion (5 durations + 4 curves). Estos tokens viven en `mobile/lib/theme/` y son la única fuente autorizada para tamaños, colores y animaciones en toda la app.

El sprint también migró los **24 widgets compartidos** de `mobile/lib/widgets/` a consumir tokens como piloto vivo del nuevo sistema. Screens quedan para sprints por módulo posteriores.

`CLAUDE.md` incluye una sección nueva con las reglas vinculantes para futuros contribuidores: prohibido `fontSize/SizedBox/BorderRadius/alpha` inline fuera de la escala, convenciones de iconografía y dialogs, reserva de colores semánticos.

## Impacto esperado

- **Consistencia visual acumulativa**: los sprints siguientes (Entry form redesign, Dashboard clarity, Reports hub) parten de una base compartida en vez de repetir decisiones ad-hoc.
- **Velocidad de desarrollo**: agregar un botón o card nuevo se hace con `kSpaceLg` y `kRadiusMd` en lugar de mirar 3 widgets análogos para copiar valores.
- **Documentación viva**: `CLAUDE.md` deja las reglas escritas; el siguiente PR sabe qué esperar.
- **Base para modo denso opt-in**: los tokens son variables — un futuro sprint puede introducir un multiplicador global para "densidad reducida" sin tocar 200 widgets.

## Riesgos o pendientes relevantes

- **Cambios visuales sub-perceptibles** (documentados): chips levemente menos redondeados (16 → 12), botón filled un poco más bajo (padding vertical 14 → 12), tint de pickers seleccionados más visible (0.10 → 0.20). Validación pendiente vía smoke manual de Diego.
- **14 excepciones** al sistema (`// token-exception:`), la mayoría son tamaños intrínsecos de iconos y touch targets que la regla no cubre estrictamente. Sin impacto en producto.
- **Sprint no toca screens**: la migración a tokens de dashboard, entries, reports, weekly_budgets, settings queda para sprints por módulo. La regla "boy scout" documentada en CLAUDE.md obliga a migrar el archivo tocado cuando se hace otro cambio ahí.

## Estado de pruebas

- `flutter analyze`: **verde** (cero errores nuevos).
- `flutter test`: **680/680 verdes** (cero modificaciones de cuerpo de test).
- Guardrails de `grep`: **cero violaciones** en `mobile/lib/widgets/`.
- Smoke desktop y Android: pendiente de Diego.
- Build APK Android release en curso (background).

## Próximo paso

Cuando Diego valide el smoke, aprobar commit final. Después: arrancar Sprint 2 — Language cleanup (purga total del voseo rioplatense).
