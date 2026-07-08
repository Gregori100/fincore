# Resumen ejecutivo — flutter-reports-income-heatmap-v1

## Qué se implementó

- **Nuevo 11º tab "Heatmap ingresos"** en `/reports`. Simétrico al 10º tab "Heatmap" (gastos) pero para ingresos con paleta verde.
- Grid 3×4 de mini-heatmaps mensuales del año en foco; cada mini con celdas coloreadas según intensidad de ingreso relativa al año.
- Tap en un mini abre el mismo bottom sheet expandido; tap en un día abre `/entries` filtrado a ese día + solo ingresos (los gastos del mismo día NO aparecen).
- Selector de año con chevrons prev/next.
- Reactivo: registrar/cancelar/editar un ingreso actualiza el heatmap sin refresh.
- Empty banner cuando el año no tiene ingresos.
- Documentación en app: onboarding slide 3 pasa a "11 reportes"; FAQ del Help lista los 11 tabs con simetría explícita entre los 2 heatmaps.

## Impacto esperado

- Cierre de la simetría analítica en `/reports`: gastos y ingresos con la misma vista año → mes → día.
- Diego responde "¿cuándo cobré?" a nivel anual con un tab dedicado.
- Feedback visual sobre regularidad de ingresos (sueldo mensual → 12 celdas verdes constantes; freelance irregular → celdas dispersas).
- Cero fricción con el resto del app: aditivo puro.
- Sin aumento medible del APK (~0.5 MB por código nuevo).

## Riesgos o pendientes relevantes

- **Label "Heatmap ingresos"** (16 chars) es más largo que "Heatmap" (7 chars). Validar overflow del TabBar en cel chico (SM-01).
- **Duplicación intencional con heatmap gastos**: TD conocido, mismo patrón que spending/income by category.
- **Smokes SM-01..08** pendientes en cel real.
- **branch-quality-review** pendiente antes del commit final.

## Estado de pruebas

- `flutter analyze`: 4 hints info pre-existentes tolerados (0 errores nuevos).
- `flutter test`: **540/540 verdes** (519 baseline + 21 nuevos: 12 UT servicio + 5 UT modelo + 4 widget).
- Build APK release + `verify-apk.sh`: OK, versionCode 2086 / versionName 0.16.4.
