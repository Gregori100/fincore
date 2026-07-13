# Branch quality review — flutter-dashboard-bundle-v1

**Fecha:** 2026-07-13
**Slug:** `flutter-dashboard-bundle-v1`
**Rama:** `main` (sin commit sobre HEAD `a6a0527`, cambios locales)

## Alcance

Bundle de 3 features aditivas al Dashboard: vista "Hoy" + sparklines
30d en cards BO/DE/CR + chips filtro por cuenta arriba de "Últimos
movimientos". Sin cambio de schema. Bump `0.19.0+93`.

Revisión con 4 dimensiones en paralelo (2 Sonnet correctness, 1 Haiku
consistencia, 1 Sonnet UX/A11Y). 9 hallazgos verificados sin
bloqueantes.

## Hallazgos por severidad

### Alta — Touch target de chips < mínimo A11Y

**Archivo:** `mobile/lib/screens/dashboard_screen.dart` (_AccountFilterChips)

**Descripción:** `SizedBox(height: 34)` + `MaterialTapTargetSize.shrinkWrap`
en `ChoiceChip` daba un hit area de ~30 px vertical. Debajo del mínimo
WCAG 2.5.5 (44x44) y del touch target Material (48 dp). Riesgo real
de mistap en dedos gruesos o pantallas pequeñas.

**Estado: RESUELTO (A4)** — `SizedBox(height: 44)` + `padding
vertical: 8` en el chip + `shrinkWrap` removido. `visualDensity:
compact` se preserva para densidad visual.

---

### Alta — Gap UT-TD06 (borderline por día calendario)

**Archivo:** `mobile/test/data/reports_test.dart`

**Descripción:** El test-plan documentaba UT-TD01..07 pero UT-TD06
(filtro por día calendario en frontera) quedó omitido en la
implementación. El bracket `occurred_at` (fix A2) + `strftime
localtime` no tenía cobertura explícita de días adyacentes.

**Estado: RESUELTO (A9)** — UT-TD06 nuevo. Sembra 3 incomes en mediodía
local de 14/15/16 de junio y verifica que solo el 15/jun cuenta.
Blinda el bracket + filtro strftime. Evita medianoches exactas por
flakiness inter-TZ.

---

### Media — Kind inválido en `watchDailyBalance30d` no falla temprano

**Archivo:** `mobile/lib/data/reports.dart` (watchDailyBalance30d)

**Descripción:** El parámetro `kind` acepta `String` sin validar; si
un caller pasa `'invalid'` o `'BO'` (mayúscula), el helper Dart
colapsa a la rama default (`bo`) sin señal. Un typo en una PR futura
pasaría silencioso.

**Estado: RESUELTO (A1)** — `assert(kind == 'bo' || kind == 'de' ||
kind == 'cr', ...)` al inicio del método. En debug crash inmediato;
en release paga cero costo.

---

### Media — Query `watchTodaySummary` sin bracket `occurred_at`

**Archivo:** `mobile/lib/data/reports.dart` (watchTodaySummary)

**Descripción:** Filtro solo por `strftime('%Y-%m-%d',
occurred_at, 'localtime') = ?` obliga a SQLite a recomputar strftime
sobre TODA la tabla — el índice `idx_entries_occurred_active` queda
inutilizado. Con dataset chico single-user es irrelevante, pero es la
misma antipattern que el sprint `flutter-reports-movements-calendar-v1`
tuvo que corregir en `movementsByDay`.

**Estado: RESUELTO (A2)** — bracket `occurred_at >= dayStartUtc AND
occurred_at < dayEndUtc` agregado antes del strftime. SQLite puede
usar el índice para descartar >99% de rows; strftime queda como red
de seguridad exacta del día calendario local.

---

### Media — netLabel muestra `+$0` sin movimientos

**Archivo:** `mobile/lib/screens/dashboard_screen.dart` (_TodayCard)

**Descripción:** Al no haber movimientos, `data.net >= 0` evaluaba
true → `'+$0'`. El signo `+` sobre cero es ruido semántico (sugiere
que hubo un ingreso donde no lo hubo).

**Estado: RESUELTO (A5)** — rama explícita `!hasMovements` retorna
`'$0'` sin signo. Ramas de ingreso positivo y neto negativo
preservan sus signos.

---

### Media — Montos largos ellipsizean en cel angosto

**Archivo:** `mobile/lib/screens/dashboard_screen.dart` (_TodayMetric)

**Descripción:** `Text(value, maxLines: 1, overflow: ellipsis)` en
3 columnas de una row de ~360 px trunca montos de 7+ dígitos
(`$1,234,567`) con `...` a la derecha. Impacta legibilidad
justamente cuando el dato importa más.

**Estado: RESUELTO (A6)** — envuelto en `FittedBox(fit:
BoxFit.scaleDown, alignment: centerLeft)`. `scaleDown` solo achica
cuando no cabe (montos chicos se ven al tamaño natural fontSize 14).

---

### Media — `readsFrom` en `.get()` es dead code

**Archivo:** `mobile/lib/data/reports.dart` (watchDailyBalance30d)

**Descripción:** El sub-query `sqlInitial` pasa `readsFrom:
{journalEntries, accounts}` a un `.get()` one-shot. Ese parámetro
solo aplica a `.watch()` (participa del sistema reactivo de drift);
en `.get()` no hace nada. Confunde en refactors futuros.

**Estado: RESUELTO (A7)** — removido de `.get()`, comment explica
que la reactividad vive en el driver principal (`sqlChanges.watch()`)
+ documenta el TD conocido (6 queries por cambio con 3 sparklines
suscritos; optimización futura vía `UNION ALL` con sentinel `day_key
= 'initial'`).

---

### Baja — Sparkline sin skeleton durante loading

**Archivo:** `mobile/lib/screens/dashboard_screen.dart` (_Sparkline)

**Descripción:** Durante los ~150-200 ms iniciales del `StreamBuilder`
sin snapshot, `_Sparkline` retornaba `SizedBox.shrink()`. El card
BO/DE/CR se veía sin sparkline y luego "aparecía" — parpadeo visual
inconsistente con el resto del dashboard que usa `Skeleton`
placeholders.

**Estado: RESUELTO (A8)** — `Skeleton(height: 24)` durante loading
(y también en el edge de data vacía, defensivo — el servicio garantiza
30 puntos backfilled pero la degradación grácil no cuesta nada).

---

### Baja — RN-DB01 sin nota en docstring de balance

**Archivo:** `mobile/lib/data/reports.dart` (watchDailyBalance30d)

**Descripción:** RN-DB01 dice "transfer y debt_payment se excluyen
de flujos". Para balances agregados esa regla NO aplica: transfer
mueve dinero entre dos cuentas del mismo `kind` y auto-cancela;
debt_payment cruza kinds (cash/debit → credit) y también cancela
mathematically en el agregado por kind. Aceptar todos los kinds en
el sub-query de balance es correcto, pero la ausencia de nota en el
docstring podría llevar a un revisor a "fixear" el edge inexistente.

**Estado: RESUELTO (A3)** — comment explica que RN-DB01 solo aplica
a flujos (`watchTodaySummary`), no a balances agregados, y por qué
transfer/debt_payment self-cancelan matemáticamente.

## Resumen

- 9 hallazgos verificados, todos resueltos antes del commit.
- 2 altos (touch target + gap UT-TD06), 5 medios, 2 bajos.
- 0 bloqueantes.
- Suite: 591/591 verdes (+1 test nuevo: UT-TD06).
- `flutter analyze`: limpio.
- APK release verificado (`versionCode 2093 / versionName 0.19.0`).

Sprint apto para smoke con Diego + commit final.
