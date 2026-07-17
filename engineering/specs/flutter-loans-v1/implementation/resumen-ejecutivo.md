# Resumen ejecutivo — flutter-loans-v1

## Qué se implementó

Módulo completo de préstamos personales en FinCore. Diego ahora puede:

- **Registrar préstamos** (bancarios, hipoteca, auto, amigos) con capital original, pago mensual referencial, duración en meses, día de pago y cuenta destino. Al crearlo la app registra automáticamente el ingreso inicial en la cuenta seleccionada.
- **Ver el saldo pendiente** de cada préstamo en tiempo real, calculado como `principal − Σ capital pagado`. Nuevo KPI naranja "PRÉSTAMO" en el Dashboard con la suma de todos los saldos activos (condicional: sólo aparece si hay ≥1 préstamo con saldo).
- **Registrar dos tipos de pago**: "Pago del mes" con split editable (capital + intereses debe sumar el total) y "Abono a capital" (100% al saldo, monto libre). La parte de intereses aparece en `spending_by_category` bajo un renglón sintético "Intereses de préstamos".
- **Recibir recordatorios**: chip "PRÓXIMO PAGO" en el Dashboard cuando falta ≤5 días al día de pago de un préstamo.
- **Cerrar préstamos** en dos sabores: automático cuando el saldo llega a 0 (`paid`, terminal), o manualmente por condonación/error (`manual`, reversible con acción "Reabrir").
- **Eliminar préstamos** con confirmación destructiva premium que muestra el conteo real de pagos afectados + el ingreso inicial que se cancela.

Los movimientos ligados a préstamo (ingreso inicial + pagos) son **inmutables** desde `/entries`: aparecen con chip pequeño "· préstamo" y al abrirlos el form está bloqueado con banner naranja + enlace "Ver préstamo".

## Impacto esperado

- **Spending reportado más honesto**: Diego deja de contar $1,758 mensuales como gasto cuando en realidad sólo $558 son intereses reales. Los reportes por categoría ganan claridad.
- **Visibilidad del saldo pendiente**: consultable en el Dashboard sin abrir la app del banco.
- **Recordatorios de pago**: reduce el olvido y los cargos moratorios reales del banco.
- **Base para futuras features**: préstamos de casa/carro, financiamientos y adelantos operan bajo la misma mecánica sin cambios estructurales.
- **Libreta pasiva**: la app no persigue al usuario, no calcula intereses, no maneja moratorios ni tabla de amortización dinámica. Diego declara cada pago con el split que el banco le mostró en su estado de cuenta.

## Riesgos o pendientes relevantes

- Smoke manual Android pendiente. APK arm64 en `mobile/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` (21.6MB, versionCode 110).
- Overpay accidental de un préstamo (pagar más del saldo pendiente) cierra el préstamo `paid` silenciosamente. Snackbar informa. Eliminar el pago con overpay lo reabre automáticamente.
- Backup v2 no se puede importar en versiones anteriores de la app (rollback pierde préstamos).
- Widget tests puntuales para las nuevas pantallas quedan como follow-up opcional; la cobertura DAO (44 tests nuevos) es sólida y `flutter test` completo pasa 780/780.

## Estado de pruebas

- `flutter analyze`: cero errores nuevos (5 hints preexistentes de `prefer_const_constructors` en `entry_form_screen.dart`).
- `flutter test`: **780/780 verde** (base 735 + 44 nuevos + 1 backup v1 legacy).
- APK release arm64 build exitoso, `versionCode = 110`, `versionName = "0.27.0"`.
- Smoke manual Android: pendiente.

## Bump de versión

`0.26.0+109` → `0.27.0+110` (minor por feature de dominio grande + schema bump 9→10 + backup v1→v2).

## Addenda de cierre (2026-07-17)

El sprint terminó shipped en `0.27.3+113` con schemaVersion 11 tras 5 ciclos de hotfixes iterativos con Diego:

- **v2 (0.27.1+111)**: agregó columna persistida `is_monthly_payment` (schema 10→11) reemplazando el proxy legacy `interest > 0`. Sin esto los pagos del mes con interés=0 quedaban clasificados como capital.
- **v3 (0.27.2+112)**: bloqueo estricto de overpay (`overpay_loan`), cascade delete de capitales del mismo mes al eliminar monthly, botón "Saldar" en ambos formularios, read-only condicional en préstamos cerrados, renglón sintético "Pago a capital de préstamos" en reportes.
- **v4 (0.27.3+113)**: fix del bug real del cascade (`customStatement` no acepta `Variable<DateTime>`), chip inteligente del dashboard con `contract_day <= paymentDay` (edge del 1 del mes), read-only solo si `closeReason == 'manual'`.
- **Quality review 2026-07-17** (`engineering/quality-review/flutter-loans-v1/2026-07-17-2200-branch-quality-review.md`): 3 bloqueantes (backup no preservaba `is_monthly_payment`, `updateLoanPayment` sin tests, brecha del round-trip) + 11 medias + 17 bajas. Corregidos en un solo lote post-review con schema bump 11→12 (índices en `loans`) y `LoanActionsMenu` extraído.
- Total tests al cierre: **≥ 842 verdes**, 0 errores de analyze.
- Los cambios finales del ciclo shipped en una versión posterior a `0.27.3`.
