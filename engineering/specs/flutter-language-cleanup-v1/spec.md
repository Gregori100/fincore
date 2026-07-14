# Purga total del voseo rioplatense (Sprint Language cleanup)

## Resumen

Sprint 2 del roadmap de la auditoría de diseño 2026-07-14. Purga toda la app de voseo rioplatense (`pagás/configurá/probá/…`) para respetar la regla vinculante de español neutral guardada en memoria el 2026-07-14 (`feedback_spanish_neutral.md`). Agrega un test guardrail que falla en CI si aparece voseo nuevo. Bonus: limpia jerga técnica ("kinds") filtrada al copy visible al usuario.

Sprint muy chico: 10 sitios de copy UI + 5 tests dependientes + 15 comentarios + 1 mención de "kinds" + 1 test guardrail = ~30 cambios pequeños. Cero refactor estructural.

Bump esperado: `0.21.0+97` → `0.21.1+98` (patch).

## Problema a resolver

La app tiene voseo rioplatense en 10 sitios de `mobile/lib/` (según discovery del 2026-07-14):

- `screens/entry_form_screen.dart:712` — `'Pagás desde'` (label del origen en `debtPayment`).
- `widgets/kind_picker.dart:122` — `'Pagás una tarjeta desde otra cuenta'` (descripción del kind `debtPayment`).
- `widgets/entries_paginated_list.dart:226` — `'Acotá filtros para ver entries más viejos.'`.
- `widgets/entries_empty_state.dart:31` — `'No hay movimientos con esos filtros.\nProbá ajustarlos.'`.
- `widgets/error_snackbar.dart:174` — `'El nombre no es válido. Probá con 1-50 caracteres.'`.
- `screens/entries_filters_screen.dart:490` — `'Configurá al menos un filtro antes de guardar.'`.
- `screens/saved_views_list_screen.dart:221` — `'Configurá filtros y tap "Guardar como vista" …'`.
- `screens/reports/monthly_average_tab.dart:441` — `'Necesitás al menos 1 mes cerrado de uso para calcular promedio.'`.
- `screens/onboarding_screen.dart:14` — `'Registrá cada movimiento'` (comentario que además cita el copy del slide 2 del onboarding — puede aplicar tanto al comentario como al copy real del slide).
- `data/daos/saved_views_dao.dart:146` — `'El nombre no es válido. Probá con 1-50 caracteres.'`.

Adicionales:

- **15 usos de "acá"** en comentarios de código (`main.dart`, `first_run_screen`, `entry_form_screen`, `settings_screen`, `calendar_screen`, `backup.dart`, `app_preferences_keys.dart`, `fincore_motion.dart`, `list_screen.dart`, `reports.dart`, `error_snackbar.dart` en lib/; y 4 en `test/`).
- **1 mención de "kinds"** en copy visible al usuario: `settings_screen.dart:501` `'FAQ sobre kinds, reportes y backup.'` (jerga interna del schema `journal_entries.kind` filtrada al FAQ).
- **5 matchers en `integration_test/`** que verifican strings voseadas (`'Ingresá un nombre.'` × 2 y `'Ya tenés una cuenta/categoría con ese nombre'`). **Hallazgo colateral**: esas strings NO aparecen hoy en `mobile/lib/` — los tests parecen estar apuntando a copy que ya no existe. Debe validarse el estado de esos tests.

Todo esto contradice la regla `feedback_spanish_neutral.md`: "Usar 'tienes/puedes/aquí' en strings UI y comentarios; nunca 'tenés/podés/acá'".

## Objetivo

1. Reemplazar los **10 sitios de voseo verbal** en `mobile/lib/` por su equivalente neutral (tú directo o infinitivo impersonal según contexto).
2. Reemplazar las **15 ocurrencias de "acá"** en comentarios por "aquí".
3. Reemplazar la mención de "**kinds**" en `settings_screen.dart:501` por "tipos de movimientos".
4. Actualizar los **5 matchers de tests** en `integration_test/` para el nuevo copy neutral (o si los tests están rotos, marcarlos como pendientes de investigación en `desviaciones-plan.md`).
5. Agregar un **test guardrail** (`mobile/test/language/no_voseo_test.dart`) que falla si aparece voseo nuevo en `lib/`.
6. Documentar la convención en `CLAUDE.md` (extender la sección "Convenciones del repo").

## Alcance

### Cambios de copy UI (visible al usuario) — prioridad alta

- `screens/entry_form_screen.dart:712` — `'Pagás desde'` → `'Pago desde'` (label sustantivo, más claro que el verbo).
- `widgets/kind_picker.dart:122` — `'Pagás una tarjeta desde otra cuenta'` → `'Pagar una tarjeta desde otra cuenta'` (infinitivo, alinea con las otras descripciones del picker).
- `widgets/entries_paginated_list.dart:226` — `'Acotá filtros para ver entries más viejos.'` → `'Reducir el rango de filtros para ver movimientos más antiguos.'` (además de neutralizar el verbo, cambia "entries" → "movimientos" para eliminar jerga).
- `widgets/entries_empty_state.dart:31` — `'No hay movimientos con esos filtros.\nProbá ajustarlos.'` → `'No hay movimientos con esos filtros.\nAjusta los filtros o cambia el rango.'`.
- `widgets/error_snackbar.dart:174` — `'El nombre no es válido. Probá con 1-50 caracteres.'` → `'El nombre no es válido. Debe tener entre 1 y 50 caracteres.'`.
- `screens/entries_filters_screen.dart:490` — `'Configurá al menos un filtro antes de guardar.'` → `'Configura al menos un filtro antes de guardar.'`.
- `screens/saved_views_list_screen.dart:221` — `'Configurá filtros y tap "Guardar como vista" …'` → `'Configura filtros y toca "Guardar como vista" …'` (además, "tap" → "toca" es más neutro y localiza el anglicismo).
- `screens/reports/monthly_average_tab.dart:441` — `'Necesitás al menos 1 mes cerrado de uso para calcular promedio.'` → `'Se necesita al menos 1 mes cerrado de uso para calcular el promedio.'` (voz impersonal, alinea con "Se pudo/No se pudo" del resto de errores).
- `data/daos/saved_views_dao.dart:146` — `'El nombre no es válido. Probá con 1-50 caracteres.'` → mismo cambio que `error_snackbar.dart:174` (misma string duplicada).
- `screens/onboarding_screen.dart:14` — chequear si el comentario cita literalmente el copy del slide 2. Si el slide muestra "Registrá cada movimiento", cambiar tanto la string real como el comentario.

### Cambios de copy adicional (visible o interno)

- `screens/settings_screen.dart:501` — `'FAQ sobre kinds, reportes y backup.'` → `'FAQ sobre tipos de movimientos, reportes, presupuestos y respaldo.'` (elimina "kinds" y "backup", alinea con el vocabulario de la app y agrega "presupuestos" que ya existe en la ayuda).

### Cambios de comentarios "acá" → "aquí" — prioridad baja

- 15 ocurrencias en `lib/` (11) y `test/` (4): reemplazo mecánico `\bacá\b` → `aquí`. No requiere criterio contextual porque siempre es adverbio de lugar en estos matches.

### Actualización de matchers en `integration_test/`

- `integration_test/account_form_test.dart:106` — matcher `'Ingresá un nombre.'`.
- `integration_test/account_form_test.dart:134` — matcher `'Ya tenés una cuenta con ese nombre'`.
- `integration_test/category_form_test.dart:102` — matcher `'Ingresá un nombre.'`.
- `integration_test/category_form_test.dart:123` — matcher `'Ya tenés una categoría con ese nombre'`.
- Además: comentario de `account_form_test.dart:21` cita `"Ingresá un nombre."` en un docstring de test — actualizar.

**Investigación previa obligatoria**: verificar si esos tests corren hoy. Si están skipped/rotos, documentar en `desviaciones-plan.md` y ajustar el matcher para el copy que efectivamente muestra la app hoy. Grep en `lib/` sugiere que las strings originales ya no existen — puede que la app haya cambiado el copy en un sprint anterior sin actualizar los tests, o que los tests estén corriendo con `warnIfMissed: false` y no detecten el mismatch.

### Test guardrail nuevo

- `mobile/test/language/no_voseo_test.dart` — nuevo archivo. Test que:
  - Lee todos los `.dart` de `mobile/lib/` recursivamente.
  - Excluye archivos `.g.dart` (generados por drift).
  - Aplica la regex `\b(pagás|configurá|probá|acotá|poné|tocá|ingresá|guardá|elegí|hacé|deslizá|necesitás|registrá|querés|tenés|podés|acá|allá|andá|seteás|fijate|dale)\b` case-sensitive Y case-insensitive.
  - Falla con `fail('Voseo detectado en <archivo>:<línea>: <match>')` si encuentra cualquier ocurrencia.
  - Corre con `flutter test` normal.

### Documentación

- `CLAUDE.md` — agregar en "Convenciones del repo" (línea ~270): "Lenguaje UI y comentarios usan español neutral. Nunca voseo rioplatense (`pagás/podés/tenés/acá`). El test `mobile/test/language/no_voseo_test.dart` blindea contra regresión."

### Bump de versión

- `mobile/pubspec.yaml` `version: 0.21.0+97` → `0.21.1+98` + comentario changelog.
- `mobile/android/app/build.gradle.kts` `versionCode = 97 / versionName = "0.21.0"` → `98 / "0.21.1"`.

## Fuera de alcance

- Rediseño de copy más allá del reemplazo del voseo. Ejemplo: si un mensaje voseado es también torpe, se neutraliza pero no se reescribe estilísticamente (esa optimización es Sprint 4 — Dashboard clarity y Sprint 5 — Reports hub).
- Cambios en el idioma completo (mantener español, solo cambiar registro).
- Modificar mensajes del backend legacy (Vue/Laravel en la rama `legacy/`).
- Comentarios de version antiguos en `pubspec.yaml` (bitácora histórica; solo se agrega la línea del nuevo release).
- Localización a otros idiomas (i18n) — sigue siendo app single-locale es_MX.
- Sistema de tokens de diseño (Sprint 1, ya completo).

## Reglas de negocio

Sprint sin dominio. Reglas del sistema de lenguaje:

- **Registro neutral tú**: preferir "tú" (`configuras/pagas/pruebas`) en instrucciones directas o feedback al usuario. Alinea con la mayor parte de la app (que ya usa tú, no vos).
- **Infinitivo impersonal**: preferir infinitivo (`Ingresar un nombre.`, `Configurar al menos un filtro.`, `Reducir el rango`) en instrucciones sistémicas y validators. Es el patrón dominante que ya usa la mayoría de la app.
- **Voz impersonal**: preferir "se necesita/se pudo/no se pudo" para condiciones o errores generales, en vez de "necesitás/pudiste".
- **Cero jerga técnica visible**: prohibido `kinds`, `entries`, `dao`, `backup` sin traducir en copy visible al usuario. Sustituir por `tipos de movimientos`, `movimientos`, `respaldo`.
- **Anglicismos naturalizados**: `tap` → `toca` cuando aparezca; `backup` → `respaldo`; `entries` → `movimientos`.
- **Excepciones documentadas**: strings en tests que verifican identidad literal (código HTTP, hashes) pueden mantener texto original si el test explícitamente lo requiere. No hay excepciones esperadas en este sprint.

## Requisitos funcionales

- **RF-001**: los 10 sitios de voseo verbal en `mobile/lib/` (listados en Alcance) reemplazados por su equivalente neutral según la tabla del Alcance.
- **RF-002**: las 15 ocurrencias de `acá` en comentarios de `mobile/lib/` y `mobile/test/` reemplazadas por `aquí`.
- **RF-003**: la mención de "kinds" en `screens/settings_screen.dart:501` reemplazada por "tipos de movimientos".
- **RF-004**: los 5 matchers en `integration_test/` actualizados al nuevo copy neutral (o marcados como pendientes en `desviaciones-plan.md` si el test estaba matcheando copy ya inexistente).
- **RF-005**: nuevo test `mobile/test/language/no_voseo_test.dart` que falla con mensaje claro si aparece voseo en `mobile/lib/`.
- **RF-006**: `CLAUDE.md` extendido con la convención en "Convenciones del repo".
- **RF-007**: `pubspec.yaml` bumpea a `0.21.1+98` + `build.gradle.kts` `versionCode = 98 / versionName = "0.21.1"`.
- **RF-008**: `flutter analyze` en 0 errores. `flutter test` en 681+ tests verdes (los 680 existentes + el nuevo guardrail).

## Casos principales

**Caso 1**: usuario abre `/entries` sin movimientos → ve empty state con copy neutral ("Ajusta los filtros o cambia el rango.") en lugar del voseo.

**Caso 2**: usuario intenta guardar una vista sin filtros → snackbar "Configura al menos un filtro antes de guardar." en lugar de "Configurá".

**Caso 3**: usuario abre Settings → sección Ayuda → ve "FAQ sobre tipos de movimientos, reportes, presupuestos y respaldo." en lugar de "FAQ sobre kinds, reportes y backup.".

**Caso 4**: usuario abre entry form con kind `debtPayment` → ve label "Pago desde" en lugar de "Pagás desde".

**Caso 5** (test guardrail): un dev futuro agrega un widget con string `'Configurá el rango'` → el test `no_voseo_test.dart` falla en CI con mensaje `Voseo detectado en lib/widgets/foo.dart:42: Configurá`. El PR queda bloqueado hasta que se corrija.

## Casos borde

**Borde 1**: string voseada dentro de un comentario multilínea `///` en un widget — el guardrail la detecta y falla. Esperado, porque también los comentarios deben respetar la convención.

**Borde 2**: `\bacá\b` puede aparecer también en identificadores raros o URLs. Verificar que la regex NO matchee cosas como `académico`, `acatar` (con `\b` la palabra debe empezar y terminar limpia — no debería). Confirmar con test.

**Borde 3**: `\btenés\b` puede aparecer en apellidos, contenido de usuario, o en comentarios que citen jerga rioplatense por metacomentario. El guardrail no distingue contexto — se acepta que raramente puede haber falsos positivos y se documenta con `// ignore-voseo:` inline para saltear el linter en el sitio.

**Borde 4**: los 4 `acá` en `mobile/test/` matchean el guardrail si el guardrail escanea también `test/`. **Decisión**: el guardrail solo escanea `lib/`, no `test/` (para permitir que test docs citen literal el voseo cuando esté verificando la ausencia). Los `acá` en `test/` se corrigen igualmente en este sprint por consistencia pero no bloquean el guardrail.

**Borde 5**: onboarding_screen slide 2 — verificar si el string `'Registrá cada movimiento'` es el copy del slide o solo un comentario. Si es copy real, cambiar el slide + el comentario. Si es solo comentario, cambiar solo el comentario.

**Borde 6**: strings duplicadas (`'El nombre no es válido. Probá con 1-50 caracteres.'` en `error_snackbar.dart:174` y `saved_views_dao.dart:146`) — cambiar las dos con el mismo replacement. Idealmente centralizarlas en `error_snackbar.dart` para futuro (fuera de scope).

**Borde 7**: matchers en `integration_test/` apuntan a strings que ya no existen en `lib/` (`'Ingresá un nombre.'`, `'Ya tenés una cuenta con ese nombre'`). Antes de "actualizar el matcher", buscar qué string real muestra la app hoy (probablemente `'Ingresar un nombre.'` o similar en `AccountsDao`/`CategoriesDao`). Los tests pueden estar rotos o pasando por casualidad.

**Borde 8**: comentarios de `pubspec.yaml` (histórico de versiones) tienen voseo — permanecen intocados por regla explícita (bitácora inmutable).

**Borde 9**: el propio `spec.md` de este sprint contiene la palabra "voseo" y varios ejemplos textuales de voseo. Como no es código, no dispara el guardrail. Sin embargo, si el guardrail se extiende a `.md` en el futuro, se agregan las excepciones adecuadas.

**Borde 10**: el `no_voseo_test.dart` debe correr **rápido** — leer 100+ archivos con regex debe tomar &lt;500ms. Si es lento, cachear la lista de archivos o correr solo en CI con flag.

## Criterios de aceptacion

- `grep -rE '\b(pagás|configurá|probá|acotá|poné|tocá|ingresá|guardá|elegí|hacé|deslizá|necesitás|registrá|querés|tenés|podés|acá|allá|andá|seteás|fijate|dale)\b' mobile/lib/ --include='*.dart' | grep -v '\.g\.dart'` devuelve **0 resultados** (excepto `// ignore-voseo:` si aplica).
- El mismo `grep` en `mobile/test/` puede tener matches en `no_voseo_test.dart` (que contiene la regex del guardrail como string) — se acepta si el archivo tiene un comentario `// ignore-voseo: contiene la regex del guardrail`.
- `grep -rn "kinds" mobile/lib/screens/settings_screen.dart` no devuelve la línea del FAQ.
- `flutter test mobile/test/language/no_voseo_test.dart` corre en verde.
- `flutter test` suite completa en verde con 681+ tests (los 680 previos + el guardrail).
- `flutter analyze` en 0 errores.
- `pubspec.yaml` en `0.21.1+98`.
- `build.gradle.kts` en `versionCode = 98, versionName = "0.21.1"`.
- `CLAUDE.md` tiene la línea de convención de español neutral con referencia al test guardrail.

## Criterios medibles de exito

- **Voseo verbal en `lib/`**: de 10 sitios actuales a **0**.
- **"kinds" en copy visible**: de 1 sitio a **0**.
- **"acá" en comentarios de `lib/`**: de 11 sitios a **0**.
- **"acá" en comentarios de `test/`**: de 4 sitios a **0**.
- **Tiempo de ejecución del guardrail**: &lt;500ms.
- **Regresiones en tests existentes**: 0 (a menos que los 5 matchers de integration_test estén rotos y requieran fix — documentado si aplica).

## Riesgos

- **R-01**: los 5 matchers en `integration_test/` apuntan a strings voseadas que ya no aparecen en `lib/` (`'Ingresá un nombre.'`, `'Ya tenés una cuenta/categoría con ese nombre'`). Antes de "actualizar el matcher", investigar qué copy real muestra la app hoy y si esos tests están efectivamente pasando (`flutter test` los cubre; si están skipped o si el harness es tolerante al mismatch, hay que abrir sub-tarea). Mitigación: correr esos tests aislados antes de tocarlos.
- **R-02**: al cambiar `'Pagás desde'` → `'Pago desde'` en el kind `debtPayment`, el label del origen queda como sustantivo. Si otro widget consumía la string voseada por igualdad literal (`if (label == 'Pagás desde')`), rompe. **Búsqueda previa obligatoria**: grep de la string por si hay dependencias. Improbable pero baja el riesgo a 0.
- **R-03**: el test guardrail es un archivo Dart que contiene la regex del voseo como string. Cuando el guardrail se corra sobre sí mismo, matcheará la regex (por ejemplo la palabra `pagás` dentro del pattern). Mitigación: excluir explícitamente `no_voseo_test.dart` del propio scan (auto-referencia) O escribir la regex construyéndola con concatenación (`'pag' + 'ás'`) para evitar el match — feo pero robusto.
- **R-04**: futuros contribuidores pueden agregar strings voseadas y el test guardrail las bloquea. Es el objetivo, pero si un dev externo (o Claude en un futuro sprint sin contexto) no entiende el mensaje, puede intentar workarounds. Mitigación: mensaje de error del test muy claro con link a `CLAUDE.md`.
- **R-05**: reemplazos que cambian la longitud del texto pueden alterar el layout en pantallas de 360dp. Ejemplo: `'Configurá al menos un filtro antes de guardar.'` (46 chars) → `'Configura al menos un filtro antes de guardar.'` (46 chars, exacto). Verificar cada reemplazo — si algún cambio hace crecer significativamente el texto, revisar visual.
- **R-06**: el hallazgo de que integration_test apunta a strings inexistentes puede indicar que hay OTRAS strings ya cambiadas en `lib/` que no aparecen en el grep del voseo (por ejemplo, ya alguien cambió `'Pagás una tarjeta'` a `'Pagas una tarjeta'` en algún lugar). No es un problema del sprint pero indica salud del testing: los integration_test posiblemente están desactualizados como conjunto.

## Supuestos

- El discovery de 10 sitios de voseo verbal en `lib/` es completo. La regex cubre todos los verbos comunes; si aparecen otros durante la implementación (verbos raros como `partí/salí/dormí/tosé` — presente/imperativo voseante), se agregan al guardrail.
- Los reemplazos propuestos en el Alcance son razonables. Si al implementar suena mejor una alternativa, se ajusta y se documenta en `decisiones-implementacion.md`.
- Los 5 matchers de `integration_test/` que apuntan a strings inexistentes en `lib/` pueden estar (a) pasando por casualidad con matcher laxo, (b) fallando pero no detectados en CI porque los integration tests no corren en cada PR, o (c) apuntando a strings generadas dinámicamente que el grep no captura. La implementación investiga y actúa.
- El test guardrail es suficiente con lectura de archivos + regex; no requiere AST parsing.
- La convención escrita en `CLAUDE.md` es acatada por futuros sprints. Si un sprint futuro necesita voseo por alguna razón (improbable), se agrega excepción con `// ignore-voseo:` justificada.
- El bump a `0.21.1+98` (patch) es apropiado porque es fix de copy sin refactor estructural. Si Diego prefiere otro esquema, se ajusta.

## Impacto esperado

**Positivo**:
- Cumplimiento de la política de español neutral que llevaba ~1 mes sin ejecutarse.
- Test guardrail bloquea regresión futura sin depender de code review humano.
- Copy uniforme mejora la sensación de producto (evita el "cambia el tono según qué pantalla abras").
- Elimina jerga técnica ("kinds") de la ayuda al usuario final.

**Negativo** (aceptado):
- Sprint sin funcionalidad nueva. Cambios de copy pueden pasar desapercibidos para el usuario final si no compara side-by-side.
- Diff moderado (30 cambios pequeños) pero de bajo riesgo.

**Neutral**:
- Bump `0.21.1` no requiere migración; APK se instala normal.
