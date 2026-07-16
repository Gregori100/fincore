# Resumen ejecutivo — flutter-accounts-archive-v1

## Qué se implementó

Se separó la acción "Archivar cuenta" en tres opciones distintas y honestas:

- **Archivar** (nuevo, reversible): la cuenta desaparece del picker de nuevos movimientos, pero sigue en `/entries`, en filtros, en KPIs y en todos los reportes. Preserva el histórico contable.
- **Desarchivar** (nuevo): devuelve la cuenta al estado activo. No tiene efectos secundarios.
- **Eliminar** (comportamiento anterior renombrado, destructivo): cancela en cascada todos los movimientos donde la cuenta figura como origen o destino. Requiere confirmación con `DestructiveDialog` que muestra cuántos movimientos se van a cancelar.

La Bolsa sigue protegida: no puede archivarse ni eliminarse. El módulo de categorías queda igual (fuera de alcance).

## Impacto esperado

- Diego puede archivar cuentas que ya no usa (tarjetas cerradas, cuentas viejas) sin perder el histórico de gastos que generaron. La libreta se vuelve utilizable a largo plazo.
- Los reportes históricos ganan integridad: ya no se pierden movimientos por accidente al "archivar" una cuenta.
- Queda desbloqueado el próximo sprint de préstamos (`flutter-loans-v1`), que necesita cerrar préstamos saldados sin borrar sus 36 pagos históricos.
- La UI de gestión de cuentas se vuelve honesta: cada acción hace exactamente lo que dice.

## Riesgos o pendientes relevantes

- Smoke manual Android pendiente. APK arm64 listo para instalar (`build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`, 21.5MB, versionCode 109).
- Cuentas que Diego "archivó" con el método antiguo (que en realidad eliminó) no se recuperan; el sprint no restaura datos históricos, sólo corrige la semántica hacia adelante.
- Widget tests para el segmented control y el banner read-only quedan como follow-up opcional. La cobertura DAO + `flutter test` completo (735/735 verde) dan suficiente confianza para el release.

## Estado de pruebas

- `flutter analyze`: cero errores nuevos (5 hints preexistentes de `prefer_const_constructors` en `entry_form_screen.dart`).
- `flutter test`: **735/735 verde** (base 711 + 24 nuevos).
- APK release arm64 build exitoso, `versionCode = 109`, `versionName = "0.26.0"`.
- Smoke manual Android: pendiente.

## Bump de versión

`0.25.6+108` → `0.26.0+109` (minor por feature de dominio nueva + schema bump 8 → 9).
