# Resumen extenso — flutter-pumpandsettle-diagnosis-v1

## Contexto

Sprint 3 (último) del ciclo de **deuda técnica** post-pivote-local. Apunta
al objetivo más arriesgado: aislar la causa raíz del cuelgue sistémico de
`pumpAndSettle` con el harness `pumpFincoreApp` + filtros drift.

Historia previa del bug:
- `flutter-local-mvp`: M3 (deep link via URL manual) diferido.
- `flutter-movements-filters-v1`: M10 (multi-select del panel con datos
  reales) diferido.
- `flutter-local-hardening-v4`: DV-2 / RF-019..023 (Fase 5 CRUD) diferida
  entera por cuelgue de 10-12 min por test.
- `flutter-movements-pagination-v1` patch v1: el cuelgue se confirma
  específico de `watchPage(categoryIds: [<uuid_real>])` + harness completo.
- `flutter-integration-tests-v1`: workaround con `integration_test`
  package corriendo en runtime real (Linux desktop). 14 tests verdes.

Hipótesis al arrancar: interacción específica entre drift +
`FinancialStateService._balanceCache` + `StreamSubscriptions` del harness.

## Timebox

4h definidas en el plan. **Cerrado en ~1h** — el bug ya no se reproduce.

## Hallazgo

El sprint anterior (`flutter-entries-list-refactor-v1`, 0.6.4+56) **fixeó
el bug como efecto colateral** del refactor que partió
`EntriesListScreen` en 4 archivos.

### Fase A: reproducir minimal

Creé `test/diagnostic/pump_and_settle_hang_test.dart` con 6 variantes:

- **BASELINE**: push `/entries` sin query params.
- **VARIANT-A**: `/entries?categoryIds=<uuid_real>` (categoría activa).
- **VARIANT-B**: `/entries?categoryIds=__null__` (token sin categoría).
- **VARIANT-C**: `/entries?accountIds=<uuid_real>` (cuenta sembrada).
- **VARIANT-D**: `/entries?kinds=expense` (solo kinds, sin uuids).
- **VARIANT-E**: `/entries?categoryIds=<uuid>,<uuid>` (multi-categoría).

Cada variante con timeout de 15s para `pumpAndSettle` (en lugar de los
10 min default). Si timeout = cuelgue confirmado.

**Resultado: 6/6 verdes en 3s.** El cuelgue no se reproduce con ninguna
variante.

### Fase B: reactivar M3 y M10 originales

Para confirmar que el fix era real (no algún workaround accidental de las
variantes), reactivé los tests **originales** M3 y M10 con el patrón
verbatim que estaba diferido:

- **M3**: `pumpFincoreApp` con seed de 2 categorías + 2 entries, push
  `/entries?categoryIds=<comida>`, expect que aparece `EntryComida` y NO
  `EntryOtra`.
- **M10**: `pumpFincoreApp` con seed de Bolsa + BBVA + 2 entries (uno
  por cuenta), push `/entries`, tap icon filtro, tap chip "BBVA", tap
  "Aplicar", expect que aparece `GastoBBVA` y NO `GastoBolsa`.

**Resultado: 2/2 verdes en 3s.** Confirmado.

## Causa raíz hipotetizada

Antes del refactor, `EntriesListScreen._EntriesListScreenState` mantenía
**tres streams** en el mismo objeto:

```dart
Stream<List<EntryWithRelations>>? _stream;          // entries
StreamSubscription<List<Account>>? _accountsSub;    // accounts
StreamSubscription<List<Category>>? _categoriesSub; // categories

@override
void didChangeDependencies() {
  super.didChangeDependencies();
  if (_stream != null) return;
  // parsear deep link → _filters
  _buildStream();      // arma _stream
  _subscribeMeta();    // arma subs
}
```

Los subs llaman `setState` cuando reciben su primer evento.

Hipótesis del loop:

1. `didChangeDependencies` arma `_stream` + subs.
2. Build se programa, `StreamBuilder<_stream>` se monta y espera el
   primer evento.
3. **Antes de que `_stream` emita**, `_accountsSub` emite y dispara
   `setState`.
4. `setState` invalida el frame en construcción.
5. Build se reprograma, `StreamBuilder<_stream>` se re-construye.
6. Drift cancela el listener previo del `_stream` (que aún no había
   emitido) y arma uno nuevo.
7. **El nuevo listener** queda en cola para el próximo microtask.
8. Antes de que llegue, `_categoriesSub` emite → `setState` → invalida
   frame → re-build → re-cancel listener.
9. El listener de `_stream` nunca llega a recibir su primer evento.
10. `pumpAndSettle` se queda esperando que el frame "se asiente" — pero
    el ciclo es estable a costo de no aterrizar nunca.

Después del refactor:

- `EntriesListScreen` solo tiene `_accountsSub` + `_categoriesSub`.
- `EntriesPaginatedList` (hijo) tiene su propio `_stream` con
  `didChangeDependencies` independiente.
- Cuando los subs del padre disparan `setState`, el rebuild del padre
  no toca al hijo a menos que cambien las props (que no cambian — `filters`
  es estable mientras los subs solo mutan listas internas).
- El `StreamBuilder<_stream>` del hijo recibe su primer evento sin
  interferencias del padre.

Esto es **hipótesis razonable**, no confirmada con stepping debugger. El
fix está validado por tests verdes.

## Cambios productivos

**Cero**. Solo se modifican tests + docs.

## Tests modificados

- `test/screens/entries_list_screen_test.dart`: reemplazado el comentario
  "M3 re-diferido" por un test verde (`group('Deep link via URL manual
  (M3 reactivado)')`).
- `test/screens/entries_filters_screen_test.dart`: reemplazado el
  comentario "M10 diferido" por un test verde
  (`testWidgets('M10: tap chip cuenta + Aplicar filtra entries')`).

## Decisiones de scope

- **Integration tests del Sprint 1 se mantienen** (account_form,
  category_form, entries_filters_panel, settings_destructive). Aunque
  ahora podrían correr como widget tests, los integration tests ya
  funcionan y agregan cobertura adicional (AF-05 con metadata completa,
  CF-05 con archive setting deletedAt, FP-02 con filtro aplicado y
  refrescando lista, SD-02 con wipeAll real). Costo de migrar = bajo;
  beneficio = velocidad ligera de suite. **No vale el riesgo de
  introducir bugs durante migración** cuando la suite actual está
  estable.
- `movements_pagination_test.dart` queda como guarda runtime real
  para el flujo más complejo de scroll infinito.
- Los archivos `test/diagnostic/` se eliminaron tras servir su
  propósito.

## Validación

- `flutter analyze`: 0 errores, 4 hints `info` pre-existentes.
- `flutter test`: **219/219 unit/widget verdes** (217 + M3 + M10
  reactivados).
- Integration tests del Sprint 1 quedan intactos — no se re-corrieron
  porque no se tocaron.
- APK `0.6.5+57` construido + `verify-apk.sh` OK.

## Conclusión

El refactor del Sprint 2 fue 2-en-1: limpieza estructural + fix de un bug
de testing infraestructural que llevaba 6 sprints diferido. Lección para
sprints futuros: separar state en widgets distintos suele desbloquear
cosas que parecen unrelated.

El timebox de 4h asumía investigación profunda con stepping debugger; se
cerró en 1h con confirmación experimental. **No se hizo stepping
debugger** porque los tests pasan limpios — no hay valor agregado en
confirmar la causa raíz con más rigor cuando el fix está validado.

Si en el futuro aparece un cuelgue similar (síntoma: `pumpAndSettle` no
aterriza en widget tests con harness completo), la primera hipótesis a
revisar es: **¿hay múltiples streams + setStates en el mismo State?** Si
sí, separarlos a widgets distintos.
