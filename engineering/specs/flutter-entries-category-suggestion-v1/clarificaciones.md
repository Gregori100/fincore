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
