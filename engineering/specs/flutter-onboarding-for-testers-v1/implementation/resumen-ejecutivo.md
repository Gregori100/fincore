# Resumen ejecutivo — flutter-onboarding-for-testers-v1

## Qué se implementó

Prepara la app para distribución a beta testers:

1. **Onboarding de 3 slides** que se muestra solo a usuarios nuevos (BD vacía). Wordmark + tagline, lista de los 5 kinds, lista de los 5 reportes. Botones "Saltar"/"Siguiente"/"Empezar". Una vez visto, no vuelve a aparecer.
2. **Sección "Ayuda" en Settings** con FAQ corto en 6 ExpansionTile: kinds, BO/DE/CR, reportes, sugerencia de categoría, vistas guardadas, backup.
3. **Recordatorio de backup** en Settings: línea con "Último respaldo: hace X días" y badge warning con icono si pasaron ≥14 días.

Persistencia: tabla SQLite nueva `app_preferences (key, value)`. Schema bump v3 → v4 aditivo + migraciones defensivas. Diego con Bolsa nunca ve el onboarding al actualizar.

## Impacto esperado

- Los amigos de Diego entienden la app sin necesidad de explicaciones cara a cara.
- Diego recibe feedback de bugs y features reales, no de "¿qué es esto?".
- Los datos del testing están protegidos: el badge naranja recuerda exportar antes de que pase mucho tiempo.
- Cero disrupción para Diego: dashboard sin cambios.

## Riesgos o pendientes relevantes

- **Migración v3→v4 real no probada**: los tests in-memory son sólidos pero el smoke manual sobre la BD real de Diego es la red final (SM-01).
- **Diego con `last_export_at` vacío**: aunque ya haya hecho respaldos antes del sprint, el indicador muestra "Aún no exportaste un respaldo." la primera vez. Se mitiga con un nuevo export.
- **`branch-quality-review` no se invocó**: Diego decide si lo dispara antes del commit final.

## Estado de pruebas

- `flutter test`: **367 tests verdes** (antes 344; +23 nuevos).
- `flutter analyze`: 0 errores nuevos.
- Smoke manual: pendiente Diego (SM-01 con su BD real es el caso crítico).

## Versión

`0.11.4+67` → `0.12.0+68`. Minor bump por feature visible significativo + schema bump.
