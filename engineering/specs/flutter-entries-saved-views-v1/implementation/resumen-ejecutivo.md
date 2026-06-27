# Resumen ejecutivo — flutter-entries-saved-views-v1

## Qué se implementó

Vistas guardadas en `/entries`. Diego ahora puede:

- Configurar filtros (fecha + tipo + cuenta + categoría + monto) y
  tappear "Guardar como vista" → ingresar un nombre → persistido.
- Tappear el icono bookmark del AppBar → sheet con todas las vistas
  guardadas.
- Tap en una vista → filtros aplicados con un solo toque.
- Menú ⋮ por vista para renombrar o eliminar (con confirmación
  destructiva).

Convierte combinaciones frecuentes en un tap.

**Primer schema bump del MVP local** (versión 2 → 3): tabla
`saved_views` agregada con migración aditiva no destructiva.

## Impacto esperado

- **Producto**: reduce la fricción de reconfigurar filtros
  recurrentes.
- **Performance**: cero impacto. Lista esperada <100 vistas
  (single-user).
- **APK size**: cero impacto. Sin deps externas.
- **Schema**: primer bump del MVP. Establece patrón para futuros
  bumps.
- **wipeAll() extendido**: "Reiniciar cuenta" en Settings ahora
  también borra vistas (coherencia con "arrancar limpio").

## Riesgos o pendientes relevantes

- **Smoke SM-01 crítico**: instalar APK sobre versión 0.9.0+61 con
  datos existentes para verificar que la migración real (no
  in-memory) no rompe nada. Es el primer schema bump real.
- Sin riesgos productivos detectados en automatizado.

## Estado de pruebas

- `flutter test` → **299/299 verdes** (279 previos + 20 nuevos).
- `flutter analyze` → 0 errores.
- APK `0.10.0+62` construido + verify-apk OK.
- Test de migración (UT-17) valida CREATE TABLE + datos preservados.
  Validación end-to-end "abrir BD v2 → onUpgrade dispara" requiere
  cel real (cobertura por SM-01).
