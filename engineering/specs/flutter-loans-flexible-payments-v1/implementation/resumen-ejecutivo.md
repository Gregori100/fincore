# Resumen de implementación — flutter-loans-flexible-payments-v1

Versión entregada: **0.34.0+122**. Schema **v15**. Backup **v4**.
Suite: **954 tests verdes** (partió de 896). `flutter analyze`: 3 hints preexistentes en `entry_form_screen.dart:510-513`.

## Qué se implementó

Los 14 requisitos funcionales de `spec.md` quedaron cubiertos.

**Sustracción** — se eliminaron los dos candados de calendario (`duplicate_monthly_payment`, `capital_before_monthly`) de `registerLoanPayment` y `updateLoanPayment`, la cascada de borrado `cascadeCapitalInMonth` con su `DestructiveDialog`, el helper `countCapitalPaymentsInSameMonth`, el chip rojo de atraso del Dashboard, el bloque completo de cálculo de vencimientos en `LoansDao` (`watchMonthsOverdue`, `expectedPaymentMonths`, `_expectedPaymentMonths`, `_maxOverdueMonthsWindow`) y el MRU de `CategoryPicker`.

**Adición** — tabla `loan_adjustments` (schema v15), término de ajustes en la fórmula de saldo, cinco métodos en `LoansDao`, pantalla `loan_adjustment_form.dart` con sus dos rutas, sección de ajustes y desglose en `/loans/:id`, y backup v4.

## Desviaciones respecto al plan

### D-01 — Una sola rama de migración X→15 en vez de diez

El plan (RF-005) preveía replicar el patrón existente: una rama por versión de origen. `onUpgrade` ya tenía nueve ramas X→14 y duplicarlas habría hecho crecer el bloque al cuadrado sin agregar información, porque el paso de v15 es idéntico venga de donde venga.

Se implementó una sola rama `if (to == 15)` que delega la cadena previa (`migration.onUpgrade(m, from, 14)`) y agrega el paso nuevo. Es correcto porque **la v15 es puramente aditiva**: un `createTable`, cero transformación de datos existentes.

El guardrail RN-H02 se conserva intacto: si `from` no tiene ruta implementada hasta 14, la llamada delegada lanza `UnimplementedError` igual que antes. `MG-LF-04` ejercita las rutas 5, 8, 11, 13 y 14 → 15.

### D-02 — La fórmula del saldo estaba duplicada en tres sitios, no dos

El plan identificó el riesgo de divergencia entre `balanceOf` y `watchBalance` (RT-02) y propuso extraer `_balanceSql`. Al implementarlo apareció una **tercera copia**: `FinancialStateService._buildTotalLoansSource` (`financial_state.dart:208`) replica la fórmula inline para agregar sobre todos los préstamos activos, en vez de llamar a `balanceOf`.

No se puede reusar `_balanceSql` ahí porque está escrita para un `?1` puntual y la otra agrega sobre un conjunto. Quedó como duplicación consciente, documentada en ambos sitios y en `CLAUDE.md`, con un test dedicado (`el total de préstamos del Dashboard también incluye los ajustes`) que falla si divergen.

### D-03 — Seis regresiones del sprint anterior corregidas fuera de alcance

Al revisar los formularios aparecieron seis sitios que formateaban centavos con `toStringAsFixed(2)` o `toStringAsFixed(0)`, heredados del sprint `flutter-integer-cents-v1`. Compilaban sin advertencia porque `toStringAsFixed` existe en `num`, pero **producían prefills inflados ×100**: editar una cuenta con límite de $5,000 mostraba `500000.00`.

Sitios corregidos, todos a `formatAmountForInput`:

- `loan_capital_payment_form.dart` — monto del abono en edición y botón "saldar".
- `loan_form_screen.dart` — `principal_amount` y `monthly_payment` en edición.
- `account_form_screen.dart` — `credit_limit` en edición.
- `category_form_screen.dart` — `monthly_limit` en edición.
- `budget_item_form_sheet.dart` — `_formatInitialAmount`.

Es una regresión ya distribuida en 0.34.0's predecesora (0.33.0+121, instalada el 2026-08-05). Se corrigió aquí por ser la misma clase de defecto que RF-012 y por afectar al usuario en producción.

### D-04 — Tres desbordes de layout preexistentes

Los widget tests nuevos corren con viewport de teléfono real (360×800 lógicos) en vez del 800×600 por defecto de `flutter_test`, que es más ancho que alto y ocultaba desbordes horizontales.

Corregidos (ambos en `loan_detail_screen.dart`, archivo que el sprint ya tocaba):

- Enlace "Ver ingreso inicial en <cuenta>" — desbordaba 94px con nombres de cuenta largos.
- Fila de pago: fecha + `Spacer` + monto — desbordaba 30px.

También corregido, aunque fuera del alcance original: `kind_picker.dart` desbordaba 4px verticalmente en 360dp. Ver M5 en la sección de correcciones de la revisión.

### D-05 — `_submit` no puede hacer `setState` después del `pop`

El patrón `try/catch/finally { if (mounted) setState(...) }` que usan los formularios existentes lanza `Looking up a deactivated widget's ancestor is unsafe` cuando la rama feliz cierra la pantalla. En `loan_adjustment_form.dart` el `setState` de recuperación vive **sólo en la rama de error**.

Los formularios preexistentes conservan el patrón viejo; no se tocaron porque no están cubiertos por widget tests y el cambio no es trivial de verificar sin ellos.

### D-06 — UT-LF-20 probaba un escenario imposible

El plan pedía cubrir el ciclo "reabrir con un ajuste positivo → volver a cerrar editándolo". **No existe**: con saldo base 0, cualquier edición negativa dispara `invalid_adjustment` y cualquier positiva deja el préstamo abierto. El único camino de vuelta es borrar el ajuste, que ya cubre UT-LF-19.

El test se reescribió con el ciclo que sí existe: cerrar por ajuste negativo → reabrir reduciendo su magnitud. La imposibilidad quedó anotada en el propio test.

### D-07 — El harness de widget tests ganó dos capacidades

- `FincoreTestHarness.router` expuesto, para navegar a rutas cuyo path depende de un id generado dentro del `seed` (`/loans/:id`), imposible de pasar por `initialRoute`.
- Los tests documentan dos trampas que costaron varias iteraciones: `pumpAndSettle` **nunca termina** si hay una animación repetitiva en pantalla (los `SkeletonCard` pulsan en bucle), y `await stream.first` sobre drift **se cuelga** dentro de la zona de async falso de `testWidgets` — hay que envolverlo en `tester.runAsync`.

### D-08 — Tres widget tests del plan sin implementar

`test-plan.md` listaba once widget tests; se implementaron ocho. Faltan:

- **WT-LF-07** (doble tap en confirmar → un solo ajuste). El formulario tiene el guard `if (_saving) return`, pero no está verificado.
- **WT-LF-09** (el chip naranja de próximo pago sigue apareciendo). Es la regresión del comportamiento que **sí** se conserva; WT-LF-08 sólo verifica que el rojo desapareció.
- **WT-LF-11** (borrar un pago del mes ya no abre `DestructiveDialog`). El comportamiento de datos está cubierto por UT-LF-28 y la eliminación del diálogo la verifica `flutter analyze` (el import de `destructive_dialog.dart` quedó sin uso y se retiró), pero no hay test de interacción.

Los tres son verificables; se dejaron fuera al priorizar cerrar el sprint. Ninguno cubre lógica de dominio no probada en la capa de datos.

### D-09 — Bug encontrado por Diego en la revisión: borrar un ajuste podía dejar el saldo negativo

Diego preguntó cómo interactúa un ajuste con el cierre automático y el manual. Al escribir los cuatro tests que faltaban para responderle, uno falló y destapó un defecto real:

1. Un ajuste positivo amplía el capital que `overpay_loan` admite.
2. El usuario paga contra ese margen ampliado.
3. Borra el ajuste → el saldo cae por debajo de cero y el préstamo se cierra como `paid` mostrando una deuda negativa.

`_validateAdjustment` cubría el alta y la edición (RN-LF-07), pero `deleteAdjustment` no validaba nada. Corregido: el borrado ahora rechaza con `invalid_adjustment` si el saldo resultante sería negativo, indicando que hay que eliminar o reducir primero los pagos que se apoyaban en ese margen.

Los otros tres casos ya se comportaban bien y quedaron blindados:

- Un ajuste que liquida un préstamo cerrado **manualmente** lo deja en `manual`, no lo convierte en `paid` (RN-L13 se respeta), y sigue siendo reabrible a mano.
- Tras reabrir a mano un préstamo `manual`, la política automática vuelve a aplicar.
- Un ajuste reabre un préstamo `paid` **aunque `reopen()` manual lo prohíba** con `cannot_reopen_paid`. Asimetría deliberada: el ajuste refleja un hecho externo (el banco dice que aún debes), no una decisión discrecional del usuario.

## Validación contra datos reales

Se importó el respaldo real de Diego (v3, 213 entries, 1 préstamo) en el pipeline nuevo:

```
IMPORT v3      -> entries=213  loans=1   suma=23 070 306 centavos
SALDO préstamo -> 3 489 668 (antes)  →  3 499 668 (tras ajuste +10 000)
EXPORT         -> version 4
ROUND-TRIP v4  -> entries=213  suma=23 070 306  ajustes=1  saldo=3 499 668
```

El test es temporal y **no se versionó** (decisión P-006 del sprint anterior: el respaldo real contiene datos financieros y no entra al repo).

## Kit de rollback

Preparado en `~/fincore-respaldos/` **antes** de entregar el APK (R-01):

| Archivo | versionCode |
|---|---|
| `fincore-0.34.0+122-arm64.apk` | 2122 |
| `fincore-0.33.0+121-arm64.apk` | 2121 |
| `fincore-rollback-0.32.1+120-arm64.apk` | 2120 |
| `fincore-backup-2026-08-05-v3.json` | formato v3 |
| `fincore-backup-2026-08-05.json` | formato v2 |

Un export v4 no lo lee la 0.33.0. Bajar de versión obliga a `adb uninstall`, que borra la BD, así que el respaldo v3 es el único punto de retorno.

## Correcciones de la revisión de rama (2026-08-05 16:09)

`engineering/quality-review/flutter-loans-flexible-payments-v1/2026-08-05-1609-branch-quality-review.md` reportó un bloqueante y cinco hallazgos menores. Aplicados todos salvo M5, que es preexistente y fuera de alcance:

- **B1 (bloqueante)** — `deleteLoan` no cascadeaba a `loan_adjustments`. El export emitía el ajuste huérfano pero omitía su préstamo, y el respaldo resultante fallaba al importar con `invalid_reference`; el usuario se enteraba al restaurar, no al exportar. Corregida la cascada **y** añadido un guardrail en el export que filtra ajustes cuyo préstamo no se exporta — necesario para que una instalación que ya generó huérfanos vuelva a producir respaldos válidos. Dos tests de DAO y tres de backup, incluido uno que reproduce el estado previo al fix.
- **M1** — `reason` tenía tres límites distintos (UI 200, import 1000, DAO ninguno). Unificados a 200 vía `LoansDao.kMaxAdjustmentReasonLength`, que el import ahora referencia.
- **M2** — el `DestructiveDialog` de eliminar préstamo no anunciaba los ajustes que se lleva. Añadido `countActiveAdjustments` y la línea de impacto (se omite cuando no hay ajustes).
- **M3** — implementado WT-LF-09, la regresión del chip naranja de próximo pago.
- **M4** — `applyPaymentSideEffects` renombrado a `recalculateLoanState`.
- **M5** — corregido a petición de Diego tras cerrar el sprint. El `KindPicker` desbordaba 4px en anchos de 360dp cuando una etiqueta larga se partía en dos líneas. Dos cambios: `childAspectRatio` de 1.6 a 1.5 (holgura para el caso de dos líneas) y `Flexible` alrededor del `Text` del tile, que es la defensa estructural — evita el desborde a cualquier alto de celda y con cualquier escala de fuente del sistema, cosa que un ratio fijo no garantiza. `WT-LF-10` volvió al viewport de teléfono y actúa como regresión: un `RenderFlex` desbordado lanza excepción y hace fallar el test.

  Nota sobre el síntoma real: las franjas amarillas y negras de desborde **sólo se pintan en builds de debug**. En el release que usa Diego el efecto era un recorte silencioso del borde inferior de la etiqueta, razón por la que nunca lo reportó.

## Pendientes

1. **Smoke en el teléfono** (SM-01 a SM-08 de `test-plan.md`). El único que la suite no puede cubrir es CM-05: que el saldo de la app cuadre con el de la app del banco tras registrar el ajuste real.
2. **`kind_picker.dart:159`** — desborde de 4px en anchos de 360dp (D-04).
4. **`applyPaymentSideEffects`** conserva un nombre que ya no describe todos sus disparadores. Deuda menor asumida.
5. **R-07 de la spec sigue vigente**: el préstamo continúa modelado como mensual (`payment_day` único, `initial_duration_months`). Este sprint quitó los bloqueos, no corrigió el modelo. El chip naranja seguirá mostrando una fecha mensual aunque el préstamo sea quincenal.
