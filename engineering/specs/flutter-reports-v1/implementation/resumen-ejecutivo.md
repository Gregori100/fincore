# Resumen ejecutivo — flutter-reports-v1

## Qué se implementó

Primer feature visible al usuario después del ciclo de hardening + testing: **pantalla de reportes en la app**.

- Nueva ruta `/reports` con `TabBar` (preparada para crecer).
- Primera tab activa: **"Gasto por categoría"** con rango libre, total acumulado, barras horizontales por categoría + tabla con monto y %.
- Default al abrir: primer día del mes corriente → hoy.
- Acceso: icono `bar_chart` nuevo en el AppBar del Dashboard.
- Reactivo: si Diego registra un movimiento desde otra pantalla, el reporte se actualiza solo al volver.

## Impacto esperado

- Diego puede responder "¿en qué se me fue la plata este mes?" en ≤ 5 segundos desde abrir la app, sin necesidad de exportar el JSON.
- La promesa local-first ("el archivo es el producto") se completa: lo registrado se lee directo desde la app.
- Sienta las bases (`ReportsService` + shell de tabs) para próximos sprints de cashflow, saldo a fecha o top movimientos.

## Riesgos o pendientes relevantes

- **Performance no validada con journal grande**: la query es rápida con BD in-memory, sin observación en cel con 1000+ entries. Si degrada, sprint siguiente agregaría índice nuevo.
- **Widget tests del DatePicker diferidos** (T027/T028): la animación interna del DatePicker cuelga `pumpAndSettle`. La lógica está cubierta por 22 tests data + smoke manual del usuario.
- **Smoke manual SM-01 a SM-08** pendiente del usuario tras instalar.

## Estado de pruebas

- **153 / 153 tests verdes** (de 126 previos + 27 nuevos), 0 regresiones.
- **`flutter analyze`**: 0 errores, 0 warnings.
- **APK release `0.4.0+43`** validado por `scripts/verify-apk.sh`.
- **Smoke manual** pendiente del usuario.

## Cómo instalar

```bash
~/Android/Sdk/platform-tools/adb install -r mobile/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

## Recomendación antes del commit

Invocar `/branch-quality-review flutter-reports-v1` para revisión exhaustiva de la rama. Hallazgos críticos resolverlos antes del commit.
