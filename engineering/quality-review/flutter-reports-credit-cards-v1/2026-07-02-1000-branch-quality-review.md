# Quality Review — flutter-reports-credit-cards-v1

**Fecha**: 2026-07-02 · **Rama**: `main` (sin commit) vs. `HEAD@main` · **Slug**: `flutter-reports-credit-cards-v1`

## Alcance revisado

Rango: diff local (uncommitted) sobre `main` posterior al último commit `89c2bda` (sprint onboarding). Cubre 18 archivos modificados + 4 nuevos + spec/plan/implementation. ~1000 líneas netas de código productivo + tests.

Áreas revisadas por 4 agentes en paralelo:
- **Migración SQL + integridad de datos**
- **Streams reactivos + performance**
- **Frontend UX + validación de formularios**
- **Cobertura de tests + regresión**

## Bloqueantes

### B1 — Migración v4→v5 sin tests reales de ejecución (UT-14..18, CB-D02)

- **Archivo**: `mobile/test/data/database_test.dart:739-747`
- **Descripción**: El único test de migración es UT-19 ("idempotencia sobre BD limpia") que se limita a correr `CREATE INDEX IF NOT EXISTS` sobre una BD ya en v5. No ejercita `onUpgrade(m, 4, 5)` contra una BD sembrada en v4 con `credit_limit=null`. UT-14 (backfill de nulls), UT-15/16/17 (rutas defensivas desde v3/v2/v1), UT-18 (preservación de FKs `journal_entries → accounts` tras la recreación de tabla) están todos ausentes.
- **Impacto**: La migración es la garantía núcleo del sprint. Cualquier bug en el `alterTable` o el orden de recreación pasa silenciosamente los tests y llega al APK de Diego. Los criterios de aprobación del test-plan.md exigen "Migración v4→v5 idempotente y con preservación de datos verificada en UT-14..UT-19".
- **Recomendación**: Agregar helper que instancie schema previo (o simule inserts con nulls y FKs vía `customStatement`) antes de correr la migración, cubrir UT-14, UT-17, UT-18. Priorizar UT-18 (preservación FKs) por ser el riesgo más alto de la recreación de tabla.

## Hallazgos Altos

### A1 — `nextOccurrenceOfDay` salta al mes siguiente aunque el clamp del mes actual sea aún futuro

- **Archivo**: `mobile/lib/data/date_helpers.dart:26`
- **Descripción**: La condición `today.day > normalized || normalized > daysInCurrentMonth` avanza al mes siguiente si el mes actual no tiene el `targetDay`, aunque el clamp al último día del mes actual **todavía sería una fecha futura respecto a `today`**.
- **Evidencia**: `today = 2024-02-15`, `targetDay = 31`. Rama tomada: `31 > 29` → salta a marzo → retorna `2024-03-31`. Semánticamente esperado: `2024-02-29` (día de corte cae en último día del mes actual porque feb no llega a 31).
- **Impacto**: Tarjetas con `closingDay` o `paymentDay` entre 29–31 muestran `nextClosingDate` desfasado ~1 mes durante febrero (y abril/junio/sept/nov con day=31). El `daysToClosing/Payment` queda inflado y el `_ProximityBadge` no dispara warning cuando debería. Diego no vería "Hoy" o "Mañana" en tarjetas cuyo corte real cae en el último día del mes actual.
- **Recomendación**: Cambiar la condición a `today.day > normalized || (normalized > daysInCurrentMonth && today.day > daysInCurrentMonth)`. O refactor: clampar primero al último día del mes actual, luego comparar contra `today.day`. Agregar test `(2024-02-15, 31) → 2024-02-29`.

### A2 — `AccountFormScreen` sin cobertura de widget para los inputs nuevos (WT-08..12)

- **Archivo**: N/A — no existe `mobile/test/screens/account_form_screen_test.dart`
- **Descripción**: El sprint agrega inputs `minimumPaymentPct` e `interestRate` con validadores (0-100) al form. Ninguno de los flujos nuevos se ejercita: mostrar/ocultar según type=cash/credit (CB-D22), rechazo con `invalid_credit_limit` al crear credit sin límite (WT-10), rechazo por rango inválido (CB-D24..CB-D26), save exitoso con nuevos valores persistidos (WT-11).
- **Impacto**: Es la entrada primaria de datos que alimentan `watchCreditCards`. Un validator mal enrutado o la conversión decimal ↔ porcentaje mal invertida puede persistir valores incorrectos sin fallar ningún test.
- **Recomendación**: Cinco widget tests en `test/screens/account_form_screen_test.dart` cubriendo WT-08/09/10/11/12. Al menos priorizar WT-10 (submit rechaza sin límite) y WT-11 (persistencia y round-trip de valores).

### A3 — Widget test del badge "Excedido" (WT-06) faltante

- **Archivo**: `mobile/test/screens/reports/credit_cards_tab_test.dart`
- **Descripción**: No hay test que renderee el badge `_OverdueBadge` cuando `debt > credit_limit`. UT-11 verifica el modelo (`isOverdue=true`), pero el path desde `CreditCardStatus.isOverdue` al widget queda descubierto.
- **Impacto**: Un typo en la condición del builder del badge (`debt > creditLimit` en vez de `isOverdue`) o intercambio de color no genera regresión visible en tests.
- **Recomendación**: Agregar WT-06 con seed que registre un `credit_expense` que exceda el límite y `expect(find.textContaining('Excedido'), findsOneWidget)`.

## Hallazgos Medios

### M1 — `referenceDate = DateTime.now()` no se re-evalúa al cruzar medianoche

- **Archivo**: `mobile/lib/data/reports.dart:885`
- **Descripción**: El `now ?? DateTime.now()` se evalúa dentro del `.map` del stream. Como el stream solo re-emite ante cambios en `accounts` o `journal_entries`, si el usuario deja el tab abierto y cruza medianoche sin registrar nada, `daysToClosing/Payment` no se recalculan.
- **Impacto**: Badge "Hoy" persiste como "Hoy" al día siguiente hasta que ocurra el próximo evento reactivo. Trivial en uso normal (una interacción refresca), pero notable si el usuario deja la pantalla abierta.
- **Recomendación**: Documentar el trade-off como aceptado (single-user, uso esporádico) o combinar el stream con un tick horario (`Stream.periodic(Duration(hours: 1))` + `combineLatest`). Fix opcional: al re-abrir el tab, forzar recreación del `_stream` en `didChangeDependencies` (invalida la microoptimización pero refresca la fecha).

### M2 — `compareForReport` sin tiebreak final; `List.sort` no es estable en Dart

- **Archivo**: `mobile/lib/data/reports.dart:1324-1346`
- **Descripción**: En dos ramas del comparador (con deuda + `paymentDay` con mismos días y misma deuda; sin `paymentDay` con misma deuda) no hay tiebreak final. `List<T>.sort` de Dart usa introsort no estable.
- **Impacto**: Dos tarjetas con métricas idénticas pueden reordenarse visualmente entre re-emits. Cosmético pero afecta percepción de estabilidad del reporte durante una ráfaga de cargos.
- **Recomendación**: Agregar `a.name.toLowerCase().compareTo(b.name.toLowerCase())` como último tiebreak en las dos ramas. Cero costo.

### M3 — Comentario engañoso sobre atomicidad de la migración v4→v5

- **Archivo**: `mobile/lib/data/database.dart:284`
- **Descripción**: El comentario afirma "Todo dentro de la transacción implícita de onUpgrade — si falla a media migración, rollback automático." Drift NO envuelve `onUpgrade` en transacción usuario (limitación de `PRAGMA foreign_keys` que no puede togglearse en transacción).
- **Impacto**: No hay corrupción real — la migración ES idempotente por diseño. Pero el comentario induce a un reviewer futuro a asumir garantías que no existen.
- **Recomendación**: Corregir a: "onUpgrade NO corre en transacción usuario (limitación de PRAGMA foreign_keys). La migración es idempotente por diseño: si crashea antes de que drift persista schemaVersion=5, el siguiente open re-ejecuta 4→5 sin efectos secundarios."

### M4 — UT-12 (reactividad) potencialmente flaky por `Future.delayed`

- **Archivo**: `mobile/test/data/reports_test.dart:1880-1907`
- **Descripción**: El test suscribe con `.listen()` y espera con `Future.delayed(50/100ms)` para observar emits. En CI compartida o con carga puede no llegar el emit inicial en 50ms.
- **Impacto**: Test intermitentemente rojo en CI.
- **Recomendación**: Reemplazar por `expectLater(stream, emitsThrough(predicate(...)))` o usar `fakeAsync`. Para el snapshot inicial, `await stream.first` es más determinístico.

### M5 — UT-02 no cubre el caso del test-plan (null explícito)

- **Archivo**: `mobile/test/data/database_test.dart:699-712`
- **Descripción**: UT-02 en test-plan.md especifica `updateAccount(id, creditLimit: null)` como caso de error. El test implementado usa `creditLimit: -100`. Además, la firma del DAO (`double? creditLimit` con `?? existing.creditLimit`) hace que null se interprete como "no tocar".
- **Impacto**: Divergencia entre plan y tests que puede confundir revisores futuros. Y CB-D08 ("null explícito debe fallar") queda sin poder implementarse con la firma actual.
- **Recomendación**: Renombrar el test para reflejar que cubre "creditLimit negativo". O explicitar la asimetría con `create` (create rechaza null, update lo ignora) como decisión documentada.

### M6 — WT-13/WT-14/WT-15 (Onboarding/Help/Reports tabs count) sin cobertura

- **Archivo**: N/A
- **Descripción**: Los textos del slide 3 de onboarding ("6 reportes"), del FAQ de HelpScreen y el conteo de tabs de ReportsScreen se actualizaron pero no hay assertions directas. Los 5 widget tests del `CreditCardsTab` implícitamente confirman que el tab "Tarjetas" existe, pero ninguno cuenta los 6.
- **Impacto**: Si alguien futuro toca el arreglo de tabs o el catálogo del onboarding y omite el nuevo, los tests siguen verdes hasta el smoke SM-07/SM-09.
- **Recomendación**: Un test rápido para cada uno: `find.byType(Tab)` con `findsNWidgets(6)` en `reports_screen_test.dart`, `find.text('6 reportes')` en el slide 3, "Estado de tarjetas" en HelpScreen.

## Hallazgos Bajos

### L1 — `updateAccount` ignora silenciosamente `creditLimit: null` explícito

- **Archivo**: `mobile/lib/data/daos/accounts_dao.dart:177-179`
- **Descripción**: `create(type: 'credit', creditLimit: null)` lanza `invalid_credit_limit` (nuevo). Pero `updateAccount(id: creditAccount, creditLimit: null)` NO lanza — el companion resuelve a `Value.absent()`. Asimetría entre create y update.
- **Impacto**: Semántica ambigua. En la práctica el form nunca pasa null explícito (siempre construye desde texto → double), así que sin bug productivo hoy.
- **Recomendación**: Comentario explícito en la firma: `creditLimit == null significa "no modificar"; para bajar el límite a 0, pasar 0 explícito`.

### L2 — UT-06 reescrito pierde precisión numérica en la aserción de CR

- **Archivo**: `mobile/test/data/reports_test.dart:1165-1170`
- **Descripción**: El test anterior asertaba `report.cr, closeTo(50000 + (0.01 - 50), 0.001)`. El nuevo solo `lessThan(50000)`. Un bug que hiciera `cr = 40000` pasaría igual.
- **Impacto**: Perdimos cobertura direccional específica.
- **Recomendación**: Cambiar por `expect(report.cr, closeTo(50000 - 50, 0.001))` — Visa del seed (50000) + VisaZero (-50) = 49950.

### L3 — CTA "Agregar tarjeta" no preselecciona type=credit

- **Archivo**: `mobile/lib/screens/reports/credit_cards_tab.dart:115` + `mobile/lib/screens/account_form_screen.dart:30`
- **Descripción**: El empty state del tab navega a `/accounts/new`. `AccountFormScreen` inicializa `_type = AccountType.debit`, así el usuario debe cambiar el picker para ver los campos credit-only.
- **Impacto**: Fricción pequeña. El usuario que viene desde el tab "Tarjetas" espera un form pre-configurado.
- **Recomendación**: Pasar query param `?type=credit` en el `context.push` y leerlo en el form para setear el default.

### L4 — Skeleton loading no matchea altura real del tile

- **Archivo**: `mobile/lib/screens/reports/credit_cards_tab.dart:60-73`
- **Descripción**: `_LoadingState` renderiza 2 `SkeletonCard()` de ~60px, pero cada `_CreditCardTile` real mide 180-220px (ring + filas + fechas). Salto visual fuerte al llenar la lista.
- **Impacto**: UX ligeramente inconsistente durante el pequeño loading inicial.
- **Recomendación**: Aceptar la inconsistencia (barato) o crear variante `SkeletonCard.tall({height=180})` con dummy internos.

### L5 — Input decimal sin soporte para coma

- **Archivo**: `mobile/lib/screens/account_form_screen.dart:307,377,398`
- **Descripción**: `FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))` bloquea `,`. Algunos teclados numéricos de Android en es_MX renderizan coma como separador decimal.
- **Impacto**: Fricción invisible para usuarios cuyo teclado renderiza coma — el input "no responde".
- **Recomendación**: Aceptar `[0-9.,]` y normalizar `,` → `.` en el submit antes de `double.tryParse`.

### L6 — Ring 72×72 puede overflow con text scale grande

- **Archivo**: `mobile/lib/screens/reports/credit_cards_tab.dart:294-330`
- **Descripción**: El `_UsedRing` con Column de 2 líneas de texto sin `FittedBox` puede romper layout con `textScaler >= 1.5` (accesibilidad Android).
- **Impacto**: Usuario con accesibilidad activada puede ver `RenderBox overflow` en dev o clip en release.
- **Recomendación**: Envolver la Column interna con `FittedBox(fit: BoxFit.scaleDown)`.

### L7 — Precisión decimal se pierde en round-trip de tasas

- **Archivo**: `mobile/lib/screens/account_form_screen.dart:80-85`
- **Descripción**: `(account.interestRate! * 100).toStringAsFixed(2)` recorta a 2 decimales. Cada re-save encoge la precisión (0.05678 → 5.68 → 0.0568).
- **Impacto**: Bajo hoy (tasas típicas son enteras). Riesgo si en el futuro se calculan intereses financieros.
- **Recomendación**: `toStringAsFixed(4)` o mostrar sin recorte con trim de trailing zeros.

### L8 — `credit_limit=0` se acepta silenciosamente sin advertencia

- **Archivo**: `mobile/lib/screens/account_form_screen.dart:308-315`
- **Descripción**: Validator rechaza solo `n < 0`. Si el usuario pone 0 desde el form, no ve helper text que le diga que la tarjeta quedará sin cupo.
- **Impacto**: UX suave. Con 0, el reporte muestra "—" en % usado y disponible = 0.
- **Recomendación**: `helperText` dinámico o `errorText` suave si `n == 0`: "Sin límite → todo cargo será 'excedido'".

### L9 — `isOverdue` con `creditLimit=0` nunca marca overdue

- **Archivo**: `mobile/lib/data/reports.dart:1276`
- **Descripción**: `isOverdue = normalizedDebt > creditLimit && creditLimit > 0`. Si `creditLimit=0` y `debt=100`, no se marca overdue.
- **Impacto**: Ambigüedad de producto: si `0` significa "límite indefinido", el comportamiento actual es correcto; si `0` significa "no puedo cargar nada", debería marcar overdue.
- **Recomendación**: Documentar la decisión con comentario en el bool y docstring de `CreditCardStatus.isOverdue`.

### L10 — DT-06 (export incluye siempre credit_limit) sin assertion explícita

- **Archivo**: `mobile/test/data/backup_test.dart:676-693`
- **Descripción**: DT-05 hace round-trip como proxy indirecto. Sin aserción directa de que el JSON exportado contenga `credit_limit` en cada cuenta.
- **Impacto**: Bajo. Si alguien omite el campo para cuentas cash, DT-05 sigue verde.
- **Recomendación**: `expect(json['accounts'].every((a) => a.containsKey('credit_limit')), isTrue)`.

## Notas informativas (no requieren acción)

- **N1** — `readsFrom` sin debounce: irrelevante <10 tarjetas; import de backup se ejecuta en transacción y emite una sola vez. No es hot path.
- **N2** — SQL con `LEFT JOIN` sobre OR: <10K entries imperceptible. Si crece a 100K, considerar `UNION ALL`.
- **N3** — `.first` en tests sin timeout: drift asegura emit inicial. Sin problema hoy.
- **N4** — `_stream ??=` sobrevive al build entre navegaciones: microoptimización correcta. Relacionado con M1 pero no bloqueante.
- **N5** — `models/account.dart` código muerto post-schema v5. Fuera de scope; considerar limpieza en sprint futuro.
- **N6** — Idempotencia de migración verificada implícitamente: correcta por diseño.
- **N7** — Auto-ajuste `null→0` en backup solo afecta credit — comportamiento correcto y testeado.
- **N8** — `ImportReport` constructor con default `= 0` no rompe callers externos.
- **N9** — Onboarding slide 3 con `credit_card_outlined` + `FincoreColors.warning` matchea el color del ring y `_OverdueBadge` — refuerzo visual coherente.
- **N10** — Snackbar de import con pluralización correcta para 0/1/N.
- **N11** — `FontFeature.tabularFigures()` sin `import 'dart:ui'`: compila porque material.dart lo re-exporta.
- **N12** — Cuenta de tests contra objetivo del test-plan: ≥385 objetivo, 406 verdes, +39 nuevos. Cumple con margen (pero calidad > cuantitativo, ver B1/A2/A3).
- **N13** — Sección "Metadata de la tarjeta" con 5 campos es densa pero funcional; opcional subagrupar "obligatorios" vs "opcionales".
- **N14** — `_stream` no maneja hot-swap de `AppDependencies`: no aplica en runtime (reset navega a /first-run y desmonta el subtree).

## Tareas de corrección en orden de dependencia

Para desbloquear el commit, resolver mínimo B1 + A1 + A3. A2 y M1-M6 son recomendados pero no bloqueantes.

### Prioridad 1 — antes del commit final

1. **[B1]** Agregar tests de migración: UT-14 (backfill 4→5), UT-17 (defensiva 1→5), UT-18 (preservación FKs). Helper `sembrarV4` con `customStatement` para insertar filas con `credit_limit=null` bypaseando el schema.
2. **[A1]** Fix del bug `nextOccurrenceOfDay` — condición corregida + test `(2024-02-15, 31) → 2024-02-29`.
3. **[A3]** WT-06 con tarjeta excedida → badge "Excedido por $X" visible.

### Prioridad 2 — recomendado antes del commit

4. **[A2]** Widget tests del `AccountFormScreen` (WT-10, WT-11) para persistencia y validación de nuevos inputs.
5. **[M3]** Corregir comentario del `onUpgrade` sobre "rollback automático".
6. **[M2]** Tiebreak alfabético final en `compareForReport`.
7. **[M4]** Reemplazar `Future.delayed` de UT-12 por `emitsThrough`.
8. **[L2]** Apretar la aserción de UT-06 a `closeTo(49950, 0.001)`.

### Prioridad 3 — mejoras diferibles a otro sprint

9. **[M1]** Tick horario para refrescar fechas — o marcar como "aceptado" con comentario.
10. **[M5]** Renombrar UT-02 o documentar asimetría create/update.
11. **[M6]** Widget tests WT-13/14/15 (onboarding, help, tabs count).
12. **[L1]** Comentario sobre semántica `null` en `updateAccount`.
13. **[L3-L10]** Mejoras UX opcionales (CTA type=credit, skeleton alto, coma decimal, FittedBox del ring, precisión de tasas, helper text de límite 0, docstring de isOverdue, assertion DT-06).

## Limitaciones y validaciones no ejecutadas

- **No se corrió una simulación real de migración**: el helper para probar UT-14/17/18 requiere un fixture de schema v4. Los agentes revisaron la lógica del `onUpgrade` estáticamente. Recomendado ejecutar smoke SM-01 en cel real de Diego antes del commit para validar la migración con datos reales.
- **No se validó el APK 0.13.0+71 en device real**: build y verify-apk.sh pasaron, pero smokes SM-01..09 no ejecutados aún.
- **Los agentes leen excerpts (no archivos completos)**: puede haber matices en dependencias transitivas no reportados.

## Estado final

- Confirmado: rama `main`, sin commit pendiente, 22 archivos tocados.
- Reporte generado: `engineering/quality-review/flutter-reports-credit-cards-v1/2026-07-02-1000-branch-quality-review.md`.
- 1 bloqueante, 3 altos, 6 medios, 10 bajos, 14 notas.
- Sin agentes ni procesos pendientes al cerrar.
