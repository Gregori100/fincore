# Sprint flutter-entries-category-suggestion-v1 — Sugerencia automática de categoría al capturar

## Resumen

Al ingresar un nuevo movimiento (`/entries/new`) que acepte categoría, la app **pre-selecciona** una categoría sugerida en el `CategoryPicker` basándose en el histórico del usuario. La sugerencia se calcula con un algoritmo en cascada (match por descripción → match por monto+cuenta → más usada reciente). Diego puede confirmar dejando la sugerencia tal cual o cambiar libremente.

Objetivo: **bajar la fricción de captura** para que Diego registre más gastos sin pensar la categoría cada vez. Esto mejora la calidad del dataset que alimenta el reporte "Promedio mensual" recién instalado y el futuro módulo Presupuestos.

## Problema a resolver

Hoy `/entries/new` muestra el `CategoryPicker` vacío ("Sin categoría" seleccionado por default). Diego tiene que:

1. Recordar qué categoría usó la última vez para algo similar.
2. Abrir el dropdown.
3. Buscar la categoría correcta entre las activas.
4. Seleccionarla.

Para un gasto recurrente (café, gasolina, suscripción) o repetitivo (compras, comida), este paso es ruido. La consecuencia es que muchos gastos quedan con categoría `null` o con una categoría inconsistente, lo que degrada los reportes que dependen de categorías (Gasto por categoría, Promedio por categoría, Presupuestos futuro).

## Objetivo

- Pre-seleccionar una categoría en el `CategoryPicker` cuando hay evidencia clara desde el histórico.
- No bloquear: Diego siempre puede cambiar la sugerencia o limpiarla a "Sin categoría".
- No intrusiva: si no hay sugerencia clara, el picker arranca vacío como hoy.
- Mantener el flujo de captura fluido: la sugerencia se recalcula a medida que Diego ingresa más datos (descripción, monto, cuenta) sin pisar lo que ya tocó manualmente.

## Alcance

- Pantalla: `mobile/lib/screens/entry_form_screen.dart`, solo en modo **nuevo entry** (no edición).
- Kinds aplicables: `expense`, `credit_expense`, `income` (P-002 v2). Para income, la "cuenta relevante" del algoritmo es `account_destination_id` (a dónde llega el dinero); para expense/credit_expense es `account_origin_id` (de dónde sale).
- Algoritmo de sugerencia en cascada (RN-S03). Implementado como método del DAO o de un servicio nuevo `CategorySuggestionService`.
- Sello visual sutil "Sugerida" al lado o debajo del picker para que Diego sepa que la categoría no fue elegida por él (RF-005).
- Sugerencia se recalcula al cambiar descripción/monto/cuenta (con debounce ~300 ms para no spamear queries) hasta que Diego toque manualmente el picker. Después de eso, la sugerencia queda fija y no se sobrescribe (RN-S07).
- Categorías archivadas (`deleted_at IS NOT NULL`) **nunca** se sugieren.
- Categorías cuyo `appliesTo` no coincide con el kind del entry tampoco se sugieren (mismas reglas que ya aplica `CategoryPicker`).
- Tests: data layer (unit) del algoritmo + widget tests del form.

## Fuera de alcance

- **Sugerencia al editar entry existente**: el entry ya tiene categoría seteada; sobrescribirla sería destructivo.
- **Aprendizaje sobre sugerencias rechazadas**: si Diego cambia la sugerencia por otra, no se penaliza la primera para futuras consultas. Modelo "memoria simple" sin scoring adaptativo.
- **Sugerencia de cuenta o monto**: solo categoría. Cuenta y monto los elige Diego.
- **NLP, embeddings, similitud semántica**: matching es por texto literal (case-insensitive trimmed). Sin tokenización compleja.
- **Toast/snackbar cada vez que se sugiere**: sería ruidoso. El sello visual es suficiente.
- **Configuración de usuario** para apagar la sugerencia: si Diego la rechaza repetidamente, la propia cascada cae a "más usada" y eventualmente a nada. No hay setting.
- **Sugerencia de varias opciones** (e.g., "te sugerimos Comida, Café o Restaurante"): solo una.
- **Match por substring / contains**: solo match exacto (trimmed + lowercase). Documentado en S-05.

## Reglas de negocio

- **RN-S01 (kinds incluidos)**: `expense`, `credit_expense` e `income`. Los `transfer` y `debt_payment` no usan sugerencia (no aceptan categoría a nivel modelo). Para income, la "cuenta relevante" para la cascada es `account_destination_id`; para expense/credit_expense es `account_origin_id`.
- **RN-S02 (solo en alta)**: la sugerencia solo se calcula en modo nuevo entry. En edición, el form respeta el `categoryId` actual.
- **RN-S03 (cascada de sugerencia)**: el algoritmo evalúa los criterios en este orden, y retorna la primera categoría activa que encuentre. La "cuenta relevante" se elige según el kind: `account_origin_id` para `expense`/`credit_expense`, `account_destination_id` para `income`.
  1. **Match exacto de descripción** (case-insensitive, trimmed). Buscar el entry más reciente con el mismo `kind` y `LOWER(TRIM(description)) = LOWER(TRIM(?))` que tenga categoría activa. Retornar esa categoría.
  2. **Match de monto + cuenta relevante + kind reciente**. Buscar el entry más reciente con el mismo `kind`, misma "cuenta relevante" (origin o destination según kind), mismo `amount` (igualdad exacta) dentro de los últimos 90 días. Retornar su categoría si está activa.
  3. **Categoría más usada por kind + cuenta relevante en últimos 30 días**. Contar usos por categoría activa entre entries con el mismo `kind` y misma "cuenta relevante" en los últimos 30 días. Retornar la más frecuente. Tiebreak: la más reciente.
  4. Si ningún paso devuelve resultado: **sin sugerencia** (picker vacío como hoy).
- **RN-S04 (excluir categorías archivadas)**: cualquier paso de la cascada debe filtrar `categories.deleted_at IS NULL`. Si el entry histórico que matchearía tiene categoría archivada, se ignora y se pasa al siguiente paso.
- **RN-S05 (excluir entries cancelados)**: cualquier paso debe filtrar `journal_entries.deleted_at IS NULL`.
- **RN-S06 (compatibilidad de `applies_to`)**: la categoría sugerida debe tener `applies_to` compatible con el kind del entry actual (mismas reglas que aplica `CategoryPicker`). Si no, se descarta y se pasa al siguiente paso.
- **RN-S07 (respeto a elección manual)**: si Diego cambió el picker manualmente (incluso a "Sin categoría"), la sugerencia **no se recalcula más** hasta que el form se reinicie. Se considera "manual" cualquier interacción con el dropdown (selección de un valor, incluido `null`).
- **RN-S08 (debounce)**: el cálculo se dispara con debounce de ~300 ms para no consultar BD en cada tecla mientras Diego escribe descripción.
- **RN-S09 (degradación silenciosa)**: si la query falla por cualquier razón, no mostrar error al usuario; loguear internamente y dejar el picker vacío. Diego no debe enterarse de fallas internas en sugerencias.

## Requisitos funcionales

- **RF-001**: nuevo método `CategorySuggestionService.suggestForNewEntry({required String kind, required String? accountId, required String? description, required double? amount, DateTime? now})` que retorna `Future<String?>` con el `categoryId` sugerido o `null`. El parámetro `accountId` es la "cuenta relevante" según el kind (origin para expense/credit_expense, destination para income); el caller (form) decide cuál pasar. `now` opcional para tests deterministas.
- **RF-002**: el servicio aplica la cascada RN-S03 con filtros RN-S04 + RN-S05 + RN-S06 dentro de una sola query SQL agregada cuando sea posible. Si requiere más de una query, ejecutarlas en orden hasta encontrar resultado.
- **RF-003**: `entry_form_screen.dart` invoca el servicio:
  - Tras el primer `didChangeDependencies` cuando es nuevo entry y hay kind seleccionado.
  - Tras cambio de `kind`, cuenta relevante (`_accountOriginId` para expense/credit_expense, `_accountDestinationId` para income), `_descCtrl.text` o `_amountCtrl.text` (con debounce 300 ms).
  - **NO** lo invoca si el usuario ya tocó el `CategoryPicker` manualmente (flag `_categoryTouched`).
- **RF-004**: si el servicio retorna un `categoryId`, el form setea `_categoryId = suggestion` y marca un flag `_categorySuggested = true` para distinguirlo de la elección manual.
- **RF-005**: el `CategoryPicker` muestra un **sello visual sutil** cuando la categoría actual es una sugerencia: un chip pequeño debajo del picker con texto "Sugerida" y un icono (✨ o similar). El sello desaparece cuando Diego cambia la selección manualmente.
- **RF-006**: si Diego toca el `CategoryPicker` (cambio de valor), `_categoryTouched = true` y la sugerencia no se recalcula más en este form.
- **RF-007**: si Diego limpia el campo (selecciona "Sin categoría" manualmente), `_categoryTouched = true` y la sugerencia tampoco vuelve.
- **RF-008**: al cancelar el entry y volver a entrar a `/entries/new`, el form arranca limpio y la sugerencia se vuelve a evaluar.
- **RF-009**: la query del servicio usa los índices existentes (`idx_entries_kind`, `idx_entries_occurred_active`) sin schema bump.

## Casos principales

- **CP-01**: Diego escribe "Café Starbucks" en descripción de un nuevo `expense`. Si en histórico hay un entry con `description = "Café Starbucks"` y categoría "Café" activa, el picker se pre-selecciona con "Café" + sello "Sugerida".
- **CP-02**: Diego ingresa monto $1500 en `expense` desde cuenta debit "Banamex" sin descripción. Si en últimos 90 días hay un entry con `amount = 1500`, `kind = expense`, `account_origin_id = banamex_id` y categoría "Renta" activa, el picker sugiere "Renta".
- **CP-03**: Diego ingresa solo `kind = expense` + cuenta "Banamex" sin descripción ni monto. La cascada cae al paso 3 (más usada últimos 30 días en expense+Banamex). Si la categoría más usada es "Comida", se sugiere.
- **CP-07** (income): Diego ingresa `kind = income` + cuenta destino "Bolsa" + monto $25000 + descripción "Salario MGT". Si en histórico hay un entry income con esa descripción y categoría "Salario" activa, el picker sugiere "Salario". El algoritmo usa `account_destination_id = bolsa_id` como cuenta relevante.
- **CP-04**: BD nueva sin entries históricos → cascada cae a "sin sugerencia" → picker arranca vacío como hoy.
- **CP-05**: Diego cambia la sugerencia manualmente. El sello desaparece. Diego no es interrumpido cuando termina de escribir descripción adicional.
- **CP-06**: Diego ingresa una descripción que sí matchea histórico, pero esa categoría histórica fue archivada. La cascada salta al siguiente paso (monto+cuenta o más usada).

## Casos borde

- **CB-T01**: Descripción nueva con espacios al inicio/final y mayúsculas mezcladas (`"  Café  "`). El match es `LOWER(TRIM(...))`, debe encontrar entries con `"café"` o `"CAFÉ"`. Confirmar que SQLite `LOWER` con UTF-8 acentos funciona (en general, SQLite `LOWER` es ASCII-only; ver R-02).
- **CB-T02**: Descripción vacía o solo whitespace. El paso 1 de la cascada se omite (no hay descripción válida que matchear).
- **CB-T03**: Monto = 0. Paso 2 se omite o se aplica con `amount = 0` (raro; probable que se omita por convención).
- **CB-T04**: Múltiples entries históricos matchean la descripción exacta pero tienen categorías distintas. Se elige la categoría del entry **más reciente** (orden por `occurred_at DESC`).
- **CB-T05**: Histórico tiene la misma descripción pero todas las categorías referenciadas están archivadas. Paso 1 retorna `null`, se intenta paso 2.
- **CB-T06**: Empate en frecuencia en el paso 3 (categorías A y B con 5 usos cada una en últimos 30 días). Tiebreak: la más recientemente usada (por `MAX(occurred_at)`).
- **CB-T07**: Diego cambia el kind del entry de `expense` a `credit_expense` después de que se calculó una sugerencia. La sugerencia debe recalcularse para el nuevo kind, **a menos que** Diego ya haya tocado el picker manualmente.
- **CB-T08**: Diego cambia la cuenta relevante (origen para expense/credit_expense, destino para income). Recalcular sugerencia (mismo criterio que CB-T07).
- **CB-T13** (income): cambio de kind de `expense` a `income` debe cambiar la "cuenta relevante" usada en la cascada (de `account_origin_id` a `account_destination_id`). El form pasa el ID correspondiente al servicio según el kind actual.
- **CB-T09**: Diego escribe descripción muy larga (>200 chars). El campo ya está limitado por `maxLength: 200` en el form, no se espera issue, pero el match SQL debe normalizar igual.
- **CB-T10**: La sugerencia es una categoría que tiene `applies_to = 'income'` y el kind es `expense`. Se descarta por RN-S06.
- **CB-T11**: Diego abre el dropdown sin tocar (solo para ver opciones) y lo cierra. ¿Cuenta como interacción manual? **Decisión**: no, solo se considera manual si efectivamente cambia el valor (`onSelected` se dispara con un valor distinto al actual).
- **CB-T12**: Performance: con 5000+ entries históricos, las 3 queries no deben superar ~50 ms en total.

## Criterios de aceptación

- **AC-01**: Al abrir `/entries/new` con `kind = expense` preseleccionado, si hay histórico con match por descripción, el picker muestra la categoría sugerida + sello "Sugerida".
- **AC-02**: El sello desaparece cuando Diego cambia el valor del picker a otra categoría o a "Sin categoría".
- **AC-03**: Categorías archivadas nunca aparecen como sugerencia.
- **AC-04**: Categorías con `applies_to` incompatible con el kind nunca aparecen como sugerencia.
- **AC-05**: Cambiar el kind o la cuenta relevante (origin para expense/credit_expense, destination para income) recalcula la sugerencia, siempre y cuando Diego no haya tocado manualmente el picker.
- **AC-06**: La sugerencia se calcula con debounce: cambiar descripción rápidamente no dispara más de 1 query cada ~300 ms.
- **AC-07**: BD vacía o sin matches: picker arranca sin sugerencia, sin sello, sin error.
- **AC-08**: Editar un entry existente NO modifica su `categoryId` con sugerencias.
- **AC-09**: La sugerencia no rompe el flujo: Diego puede guardar el movimiento con la sugerencia tal cual o cambiarla y guardar igual; ambos paths funcionan.
- **AC-10**: 0 errores en `flutter analyze`; suite verde en `flutter test`.

## Criterios medibles de éxito

- **CME-01**: `flutter test` pasa con al menos +10 tests nuevos (unit del servicio + widget del form).
- **CME-02**: Performance del servicio con 1000 entries históricos: <50 ms por sugerencia (test perf opcional).
- **CME-03**: En uso real de Diego, al menos el 50% de los nuevos entries con sugerencia activa se aceptan tal cual (sin medición automática; smoke manual a las 2 semanas).
- **CME-04**: La sugerencia no introduce regresiones en widget tests existentes del form (`entry_form_screen_test.dart` + `entry_form_kinds_test.dart`).

## Riesgos

- **R-01** (RN-S07 estado del flag): si el flag `_categoryTouched` se resetea por error al cambiar kind/cuenta, Diego puede sentir que la app "le borra" su elección manual. Mitigar con test específico (CB-T07/CB-T08).
- **R-02** (`LOWER` ASCII-only en SQLite): el match por descripción usa `LOWER(TRIM(...))` en SQL. SQLite built-in `LOWER` es ASCII-only: "Café" y "CAFÉ" se considerarían distintos. Para español hispano la incidencia es baja (acentos en mayúsculas raros). Mitigar normalizando en Dart antes de la query (`description.trim().toLowerCase()` y pasar como Variable). Documentar.
- **R-03** (performance debounce): debounce mal implementado puede dejar queries pendientes que se ejecutan después del cierre del form. Mitigar cancelando el Timer en `dispose()`.
- **R-04** (sello visual intrusivo): si el chip "Sugerida" molesta visualmente en uso real, lo cambiamos en sprint posterior. Decisión barata de revertir.
- **R-05** (sugerencia incorrecta repetida): si la lógica sugiere mal sistemáticamente, Diego pierde confianza. Mitigación: el algoritmo es transparente y predecible (cascada con criterios claros). Si una sugerencia es mala, Diego la cambia y la próxima sugerencia respeta esa elección manual.
- **R-06** (test determinístico con `DateTime.now()`): los criterios "últimos 30/90 días" requieren `now` inyectable. Mitigar con parámetro opcional `DateTime? now` en el servicio para tests.

## Supuestos

- **S-01**: Sin schema bump. Toda la información necesaria ya está en `journal_entries` y `categories`.
- **S-02**: Sin nuevas dependencias en `pubspec.yaml`.
- **S-03**: La fecha actual se toma de `DateTime.now()` por default, con override opcional para tests.
- **S-04**: La sugerencia aplica a `expense`, `credit_expense` e `income` (P-002 v2 confirmado). Para income la "cuenta relevante" del algoritmo es `account_destination_id`.
- **S-05**: El match por descripción es **exacto** (case-insensitive, trimmed). No hay substring matching ni similitud aproximada (P-003 confirmado).
- **S-06**: Ventana del paso 3 ("más usada reciente"): últimos **30 días**. Ventana del paso 2 ("match por monto+cuenta"): últimos **90 días** (P-004 confirmado).
- **S-07**: Debounce de 300 ms para el recalculo al tipear. Estándar de la industria.
- **S-08**: El sello visual es un chip pequeño con texto "Sugerida" y un icono ✨ (sparkle al inicio + texto), color accent suave, ubicado debajo del picker (P-001 confirmado).
- **S-09**: Si el usuario cambia el picker, la sugerencia no se recalcula más hasta que el form se reinicie. La marca de "interacción manual" solo se considera si cambia el valor (no por abrir y cerrar el dropdown).
- **S-10**: Performance OK con índices existentes. Sin necesidad de índices nuevos para v1.
- **S-11**: El servicio `CategorySuggestionService` se inyecta en `AppDependencies` y se accede en el form vía `AppDependencies.of(context).categorySuggestionService`.

## Impacto esperado

- **Funcional**: Diego registra más entries con categoría correcta sin pensar, especialmente para gastos recurrentes (café, gasolina, suscripciones, alquiler).
- **Calidad del dataset**: los reportes que dependen de categorías (Gasto por categoría, Promedio por categoría, módulo Presupuestos futuro) ganan precisión.
- **Preparatorio**: el patrón de "servicio que consulta el journal con cascada de heurísticas" se puede reutilizar en sprints futuros (sugerencia de cuenta, sugerencia de monto recurrente, detección de duplicados).
- **UX**: bajo riesgo de molestar — la sugerencia es pre-selección + sello visual, no es modal ni snackbar. Diego puede ignorarla con cero fricción.
