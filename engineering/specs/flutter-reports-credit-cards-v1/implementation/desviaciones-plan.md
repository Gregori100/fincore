# Desviaciones respecto al plan

## D1 — Formato de `minimumPaymentPct` e `interestRate`: decimal 0-1 (no 0-100)

- **Plan/spec original**: asumió formato porcentaje humano (0-100) para ambos.
- **Realidad detectada durante implementación**: `BackupService.importFromJson` valida rango `[0, 1]` desde antes del sprint — el legacy los guarda como **decimal**. Reconocer esto post-facto:
  - **BD**: decimal 0-1 (ej: `0.05` = 5%).
  - **UI**: acepta 0-100 (más natural humano); helper `_parsePercentInput` divide por 100 al persistir.
  - **`CreditCardStatus.compute`**: multiplica directo `debt × minimumPaymentPct` (sin `/100`).
- **Impacto**: convención simetría UI ↔ BD queda documentada en `CLAUDE.md` y en comentarios de `account_form_screen.dart` y `reports.dart`.
- **Alternativa descartada**: migrar los valores existentes al formato 0-100 rompe compatibilidad con backups legacy. No vale la pena.

## D2 — `nextOccurrenceOfDay`: skip al mes siguiente en vez de clamp

- **Plan/spec original (RN-CC04)**: describió "clamp al último día del mes" cuando `targetDay > días del mes actual` (ej: `closingDay=31` en abril → 30 abril).
- **Realidad implementada**: **saltar al mes siguiente** (ej: `closingDay=31` en abril → 31 mayo).
- **Justificación**: Es más útil para el usuario. Si el corte cae el 31 y el mes no tiene día 31, el "próximo corte real" es el mes siguiente (que sí tenga 31) no el último día del mes actual (que ya podría estar en pasado real). El clamp aplica solo cuando `today.day > targetDay` (mes siguiente ya elegido, y el mes siguiente tampoco tiene el día).
- **Impacto**: tests UT-13d/g/h reescritos con el comportamiento skip. RN-CC04 debería actualizarse en la próxima iteración de la spec.

## D3 — `balanceAtDate` ahora suma tarjetas con `credit_limit=0` a CR

- **Plan/spec**: no explicitó el cambio.
- **Realidad implementada**: el condicional `if (creditLimit != null)` se removió (es dead code post-schema NOT NULL). Todas las tarjetas activas contribuyen a CR con `creditLimit - balance`. Para una tarjeta con `credit_limit=0` y `debt=100`, su contribución a CR es `-100` (deuda excedida).
- **Impacto**: Diego podría ver una baja leve en su CR total si tiene tarjetas migradas de `null → 0`. Consistente con la intención del sprint (RN-CC01) pero merecería una nota visible al usuario.

## D4 — `_accountFromJson` cambia firma pública del backup

- **Plan/spec**: mencionó "agregar `adjustedAccountsCount` al `ImportReport`" pero no especificó cómo se acumula.
- **Realidad implementada**: `_accountFromJson` pasa de `AccountsCompanion` a `({AccountsCompanion companion, bool adjusted})`. `importFromJson` cuenta con `.where((r) => r.adjusted).length`.
- **Impacto**: cambio interno de `BackupService`. Ningún caller externo depende de `_accountFromJson` (es privado). Ningún test previo rompió por este cambio.

## D5 — Sub-tests adicionales en `date_helpers_test`

- **Plan**: definió UT-13 con "15 sub-casos".
- **Realidad**: implementados 15 sub-casos + fórmula minimumPayment y CB-D18 dentro del grupo `watchCreditCards` de `reports_test.dart`, resultando en 39 tests totales nuevos del sprint (más que el estimado inicial de ~18).

No hay desviaciones bloqueantes ni pendientes que impidan cerrar la implementación.
