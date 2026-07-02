# Resumen ejecutivo — flutter-reports-credit-cards-v1

## Qué se implementó

- Sexto tab **"Tarjetas"** en `/reports`: estado por tarjeta activa con deuda actual, % usado del límite, disponible, próximo corte, próximo pago (con badge "Hoy" / "Mañana" / "en X días") y pago mínimo estimado si el usuario tiene setado el porcentaje.
- Empty state con CTA "Agregar tarjeta" para testers que aún no crearon ninguna.
- Reactivo: cargos, pagos y edición de tarjetas se reflejan sin refresh manual.
- **Inputs UI** para `Pago mínimo (% del saldo)` e `Interés anual` en el formulario de cuenta credit — dos campos que existían en la BD desde el pivote pero no tenían dónde escribirse.
- Schema **v4→v5**: `credit_limit` deja de ser nullable y pasa a `NOT NULL DEFAULT 0`. Ahora una tarjeta siempre tiene límite (aunque sea 0), consistente con la intención del dominio.
- Import de backup **legacy** con `credit_limit=null` sigue funcionando: se auto-ajusta a 0 y el snackbar reporta el número de cuentas ajustadas.
- Onboarding y FAQ actualizados: dicen "6 reportes" y mencionan "Estado de tarjetas".

## Impacto esperado

- Diego (usuario principal): en un solo vistazo del tab ve estado de todas sus tarjetas sin abrir cuenta por cuenta ni hacer mental math del disponible o del pago mínimo.
- Testers: si tienen tarjetas, ven el nuevo tab con datos reales; si no, ven un empty state claro con CTA para agregar. El backup viejo (Diego con tarjetas sin límite) sigue funcionando.
- Sistema: el schema queda más limpio, y los campos huérfanos post-pivote (`interestRate`, `minimumPaymentPct`) se pueden usar como base para features futuros (forecast, alertas de pago).

## Riesgos o pendientes relevantes

- **Migración destructiva de tabla `accounts`**: se probó in-memory con idempotencia + preservación de FKs. La primera corrida real en el cel de Diego es la única prueba definitiva. Recomendado exportar backup manual desde Settings antes de instalar el APK.
- **Cambio en CR total**: tarjetas legacy con `credit_limit=null` ahora suman `0 - deuda = -deuda` al CR. Diego verá su CR total bajar si tiene tarjetas sin límite configurado (esperado y deseado).
- **`interestRate` guardado pero no usado en el reporte**: el input persiste pero no se muestra aún. Helper text lo aclara.
- **Smokes SM-01..09** pendientes: Diego los ejecutará en su cel real.
- **branch-quality-review** pendiente antes del commit final.

## Estado de pruebas

- `flutter analyze`: 4 hints info pre-existentes tolerados (0 errores nuevos).
- `flutter test`: **406/406 verdes** (367 baseline + 39 nuevos del sprint).
- Build APK release + verify-apk.sh: OK, versionCode 2071 / versionName 0.13.0.
