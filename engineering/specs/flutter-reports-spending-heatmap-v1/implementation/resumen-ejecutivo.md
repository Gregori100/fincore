# Resumen ejecutivo — flutter-reports-spending-heatmap-v1

## Qué se implementó

- **Nuevo 10mo tab "Heatmap"** en `/reports` con vista año completo estilo GitHub contributions.
- **Grid de ~365 celdas** (7 filas × 53 columnas) con 5 niveles de intensidad de color por día:
  - Sin gasto: fondo neutro.
  - Bajo / Medio / Alto / Muy alto: rojo con opacidad creciente.
- **Escala relativa por cuartiles**: se recalcula automáticamente para cada año en foco. Con menos de 4 días de datos, todos se ven uniformemente "muy altos" (fallback visual).
- **Kinds contados**: solo `expense` + `credit_expense` (definición operativa de "gasto" consistente con el resto del app).
- **Selector de año** con chevrons prev/next.
- **Drill-down** tap → `/entries` con filtro custom del día + solo gastos.
- **Reactividad**: registrar/cancelar/editar un gasto actualiza el heatmap sin refresh manual.
- **Empty banner** cuando el año no tiene ningún gasto registrado.
- Documentación en app: onboarding slide 3 pasa a "10 reportes"; FAQ del Help aclara la diferencia con el calendario ("el calendario detalla el mes por tipo de movimiento; el heatmap muestra el año por intensidad de gasto").

## Impacto esperado

- Responde "¿cuándo gasto más?" a nivel anual: patrones estacionales, semanas altas/bajas, bursts inesperados.
- Complementa el calendario (mes detallado) con perspectiva macro (año completo).
- Sin dependencia externa nueva; APK sin aumento medible.
- Cero fricción con el resto del app: aditivo puro.

## Riesgos o pendientes relevantes

- **Rendering en cel chico (360 px)**: celdas quedan de ~5-6 px, legibles para vista de patrón. Validar SM-02 en cel real.
- **Hit-testing manual**: la conversión coordenadas → día en el `CustomPaint` es la parte más frágil. Validar SM-03 (tap en día → drill-down navega al día correcto).
- **Smokes SM-01..07** pendientes de ejecución con Diego.
- **branch-quality-review** pendiente antes del commit final.

## Estado de pruebas

- `flutter analyze`: 4 hints info pre-existentes tolerados (0 errores nuevos).
- `flutter test`: **512/512 verdes** (492 baseline + 20 nuevos: 11 UT servicio + 5 UT modelo + 4 widget).
- Build APK release + `verify-apk.sh`: OK, versionCode 2083 / versionName 0.16.1.
