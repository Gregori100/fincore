# Clarificaciones

## 2026-06-29

- Pregunta: P-001
  Decision: **chip "✨ Sugerida"** pequeño debajo del `CategoryPicker`, color accent suave, icono sparkle + texto. Desaparece cuando el usuario cambia la selección.
  Impacto en spec: confirmación de RF-005 + S-08. Sin cambios estructurales.

- Pregunta: P-002
  Decision (cambio en 2026-06-29): **`expense` + `credit_expense` + `income`**. Diego corrigió la decisión previa para incluir income también. Para income, la "cuenta relevante" del algoritmo es `account_destination_id`; para expense/credit_expense es `account_origin_id`. El servicio recibe `accountId` único y el form decide cuál pasar según el kind.
  Impacto en spec: RN-S01 reescrita (incluye income + clarifica "cuenta relevante"), RN-S03 reescrita (cascada usa "cuenta relevante" en lugar de "cuenta origen"), RF-001 (firma del servicio + nota sobre quién elige el accountId), RF-003 (form invoca con la cuenta relevante según kind), agregados CP-07 (caso principal income) + CB-T13 (cambio de kind cambia cuenta relevante), AC-05 reescrito, S-04 reescrito, eliminada la línea "Income" de Fuera de alcance, Alcance actualizado.

- Pregunta: P-003
  Decision: **match exacto** (case-insensitive, trimmed) en el paso 1 de la cascada. Sin substring.
  Impacto en spec: confirmación de RN-S03 paso 1 y S-05. Sin cambios estructurales.

- Pregunta: P-004
  Decision: **30 días** para "más usado" (paso 3), **90 días** para "monto+cuenta" (paso 2).
  Impacto en spec: confirmación de RN-S03 pasos 2 y 3, S-06. Sin cambios estructurales.

## 2026-06-29 — v2 (post-uso real)

Diego instaló el APK `0.11.2+65` y reportó que la sugerencia disparaba al seleccionar la cuenta (paso 3 "más usada") sin haber tipeado nada. Le pareció intrusivo y descubrió que su modelo mental era distinto al algoritmo implementado.

- Cambio: ¿el monto es relevante como criterio (paso 2)?
  Decision: **NO**. Diego confirmó que para él el monto no es indicador útil para sugerir categoría. Eliminado el paso 2.
  Impacto en código: `_stepAmountAccountMatch` removido del servicio. RN-S03 simplificada.

- Cambio P-003: ¿el match de descripción debe ser exacto o substring?
  Decision (corrige P-003 original): **substring** — la nueva descripción **contiene** la histórica. Ejemplo: histórico `"Café"` matchea con nueva `"Café para mi novia"` y con `"Café del amigo Juan"`. Para evitar falsos positivos masivos, descripción histórica debe medir al menos 3 caracteres (`LENGTH(TRIM(j.description)) >= 3`). La nueva descripción también short-circuit si <3 chars.
  Impacto en código: query del paso 1 cambia de `LOWER(TRIM(j.description)) = ?` a `? LIKE '%' || LOWER(TRIM(j.description)) || '%'` con filtro de LENGTH.

- Cambio: ¿se mantiene el fallback estadístico (paso 3 "más usada por kind+cuenta")?
  Decision: **NO**. El fallback genera sugerencias sin señal explícita del usuario, lo cual erosiona confianza. La sugerencia ahora SOLO aparece cuando hay match basado en lo que Diego escribió.
  Impacto en código: `_stepMostUsedRecent` removido del servicio. La cascada se reduce a un único criterio.

- Cambio de firma del servicio: `suggestForNewEntry` ya no recibe `accountId`, `amount` ni `now`. Firma nueva: `({required String kind, required String? description})`.

- Cambio en el form: removido el listener de `_amountCtrl`. Removidas las invocaciones de `_recalcSuggestionImmediate()` en los `onChanged` de `AccountPicker`. El cambio de `_kind` sigue disparando porque `applies_to` cambia.

- Tests: refactor completo de `category_suggestion_test.dart` v2 (18 tests cubriendo match exacto, substring "caso Diego", edge cases, kinds y compatibility). Widget tests `entry_form_suggestion_test.dart` siguen verdes sin cambios.

Versión bumped: `0.11.2+65 → 0.11.3+66`.

## 2026-06-29 — v2.1 (match bidireccional, post smoke v2)

Diego instaló el APK `0.11.3+66` y reportó que el match de descripción solo funcionaba en una dirección. Caso concreto: histórico tiene `"fiscal"` con categoría Sueldo. Al tipear `"fisca"` (5 chars, prefijo de "fiscal"), la sugerencia NO aparecía hasta completar `"fiscal"`. Razón: el SQL solo evaluaba "la nueva contiene la histórica" — `"fisca"` es más corta que `"fiscal"` y no la contiene.

- Cambio: el match ahora es **bidireccional**.
  Decision: `(? LIKE '%' || histórica || '%') OR (histórica LIKE '%' || ? || '%')`. Esto cubre los dos patrones reales:
  - **Histórico corto + tipeo largo**: histórico `"Café"`, tipeo `"Café para mi novia"` → rama A matchea.
  - **Histórico largo + tipeo de prefijo**: histórico `"fiscal"`, tipeo `"fisca"` → rama B matchea (la sugerencia aparece antes de terminar de escribir).
  Impacto en código: SQL agrega `OR` con la rama inversa. Doble Variable para el mismo `normalizedDesc`. Filtro `LENGTH(histórica) >= 3` sigue aplicando, y el short-circuit en Dart si tipeo <3 chars también.

- Tests: agregado UT-12 explícito para el caso de Diego (`"fiscal"` vs `"fisca"`). UT-13..UT-19 renumerados.

Versión bumped: `0.11.3+66 → 0.11.4+67`.
