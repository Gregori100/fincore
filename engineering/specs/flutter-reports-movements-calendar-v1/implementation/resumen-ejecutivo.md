# Resumen ejecutivo — flutter-reports-movements-calendar-v1

## Qué se implementó

- **Nuevo 9no tab "Calendario"** en `/reports` con vista mensual del proyecto.
- **Marcadores por día** (hasta 3): verde ingreso, rojo gasto, azul movimiento interno. Reflejan qué tipos de movimiento hubo cada día — no el monto.
- **Drill-down por tap**: tocar un día abre `/entries` filtrado exactamente a ese día. Reusa el mismo mecanismo de los otros drill-downs por bucket.
- **Navegación mes anterior / siguiente** con las flechas del header nativo del calendario.
- **Reactividad**: registrar/cancelar un movimiento actualiza los marcadores sin refresh manual.
- Documentación en app: onboarding slide 3 pasa a "9 reportes"; FAQ menciona el nuevo tab.

## Impacto esperado

- Usuario responde rápido "¿qué gasté el día X?" con contexto visual del mes, sin abrir sheet de filtros.
- Ver la distribución de actividad del mes de un vistazo (días densos vs vacíos).
- Prepara la infraestructura de agregación diaria para el próximo sprint de heatmap.
- Cero fricción con el resto del app: aditivo puro.

## Riesgos o pendientes relevantes

- **Dependencia externa nueva**: `table_calendar 3.1.2` (pinned). ~120 KB agregados al APK. Sin conflicto con drift/go_router en el análisis; validar en cel real.
- **Timezone-safe grouping**: la query usa `strftime('%Y-%m-%d', 'localtime')` porque drift almacena UTC. Blindado por tests UT-CAL07 y UT-CAL11.
- **Legibilidad de los 3 puntos** en cel chico con día denso: validar en smoke. Si se ve saturado, patch cosmético sencillo.
- **Smokes SM-01..07** pendientes de ejecución con Diego.
- **branch-quality-review** pendiente antes del commit final.

## Estado de pruebas

- `flutter analyze`: 4 hints info pre-existentes tolerados (0 errores nuevos).
- `flutter test`: **492/492 verdes** (474 baseline + 18 nuevos: 12 UT servicio + 2 UT factory + 4 widget).
- Build APK release + `verify-apk.sh`: OK, versionCode 2082 / versionName 0.16.0.
