# Sprint flutter-onboarding-for-testers-v1 — Preparar la app para beta testers

## Resumen

Sprint para reducir fricción de primer arranque y proteger los datos de los amigos de Diego que van a recibir el APK como beta testers. Incluye 3 features:

1. **Onboarding rápido** — 3 slides previos al first-run actual para explicar qué es FinCore.
2. **Sección Ayuda en Settings** — FAQ corto en una pantalla con `ExpansionTile`.
3. **Recordatorio de backup** — chip visual en Settings con "Último respaldo: hace X días" y warning si >14 días.

Schema bump aditivo (v3 → v4) para una tabla `app_preferences` simple key/value que persista el flag de onboarding visto y el timestamp del último export.

## Problema a resolver

La app está optimizada para Diego, que conoce el dominio, los kinds, las cuentas, el modelo de balance derivado y los reportes. Un tester nuevo:

- Abre el APK y ve la pantalla First-run con cards "Importar respaldo" / "Arrancar limpio". No sabe qué eligen ni qué viene después.
- No encuentra explicación de los 5 kinds (income / expense / credit_expense / debt_payment / transfer). Es probable que mezcle `transfer` con `debt_payment` o use `credit_expense` con cuenta debit.
- No entiende qué son BO, DE, CR del dashboard.
- No sabe cómo ni cuándo hacer backup. Si pierde el cel o desinstala la app por error, pierde todo el historial de testing.

Sin estos arreglos, el grupo de testers va a dar feedback dominado por confusión ("¿qué es esto?") en lugar de feedback útil sobre features y bugs reales.

## Objetivo

- Que un tester nuevo entienda el propósito de la app en menos de 30 segundos.
- Que pueda consultar referencias de los conceptos del dominio sin tener que preguntarle a Diego.
- Que minimice el riesgo de perder datos del testing por olvido de backup.
- Mantener cero impacto para Diego (que ya conoce todo): el onboarding no se le muestra porque su BD ya tiene Bolsa.

## Alcance

### 1. Onboarding

- Nueva pantalla `/onboarding` con 3 slides en formato `PageView` horizontal.
- Slide 1: wordmark "FinCore" + subtítulo "Tu libreta digital de cuentas".
- Slide 2: "Registrá cada movimiento" + lista breve de los 5 kinds con iconos del catálogo.
- Slide 3: "Mirá tus reportes y patrones" + lista breve de los 5 tabs de /reports con iconos.
- Indicador de slide actual (dots) en la parte inferior.
- Botón "Saltar" en la esquina superior derecha, visible en los 3 slides.
- Botón principal: "Siguiente" en slides 1-2, "Empezar" en slide 3.
- Navegación bidireccional permitida (swipe + dots tappeables).
- Al completar o saltar: persistir `onboarding_seen = true` en `app_preferences` y redirigir a la pantalla original (`/first-run` o `/dashboard` según `hasBolsa`).

### 2. Sección Ayuda

- Nueva pantalla `/help` accesible desde Settings → nueva sección "Ayuda" (justo encima de "Acerca de").
- Contenido: lista de 6 `ExpansionTile` en una sola pantalla scrolleable.
- Temas (orden propuesto):
  1. "¿Qué tipos de movimientos hay?" — los 5 kinds con descripción + ejemplo.
  2. "¿Qué significan BO, DE, CR?" — Bolsa, Deuda, Crédito disponible.
  3. "¿Cómo se calculan los reportes?" — breve párrafo por cada tab de /reports.
  4. "¿Cómo funciona la sugerencia de categoría?" — explica el match por substring de descripción.
  5. "¿Qué son las vistas guardadas?" — explica el flujo de `/entries` con filtros.
  6. "¿Cómo hacer backup y por qué importa?" — explica export / import desde Settings.
- Textos en español, tono didáctico breve (1-3 párrafos por sección).

### 3. Recordatorio de backup

- En Settings → sección "Respaldo", debajo del botón "Exportar respaldo" agregar línea:
  - Si nunca exportó: "Aún no exportaste un respaldo." en `textSubtle`.
  - Si exportó hace <14 días: "Último respaldo: hace X días" en `textSubtle`.
  - Si exportó hace ≥14 días: badge `warning` con icono `Icons.warning_amber_rounded` + texto "Último respaldo: hace X días — te recomendamos exportar pronto".
- Persistir timestamp del último export exitoso (`last_export_at`) en `app_preferences` cuando el flujo `_exportInternal` retorna `success`.
- NO usar dialogs ni snackbars intrusivos: solo señal visual estática.

### Persistencia

- Nueva tabla SQLite `app_preferences` con esquema simple: `key TEXT PRIMARY KEY`, `value TEXT`. Schema bump v3 → v4 aditivo, no destructivo.
- Decisión (S-01): se descarta `shared_preferences` (nueva dep) y JSON local (menos robusto). Drift + SQLite ya está en el stack y es consistente con el resto del data layer.
- Las preferencias NO se incluyen en el backup JSON v1 (son estado de UI, no datos del usuario — misma decisión que `saved_views`).
- `wipeAll()` del backup DEBE limpiar la tabla `app_preferences` para que un reset deje al usuario en estado "como recién instalado".

## Fuera de alcance

- **Reportar bugs por email/teléfono**: Diego no quiere exponer contactos personales. Iteración futura.
- **Datos de demo / sample seed**: queda para iteración futura.
- **Light mode**: queda para iteración futura.
- **Crash reporting / telemetría**: contradice la filosofía local-first del repo.
- **Tour interactivo (highlights animados sobre la UI real)**: queda para iteración futura. v1 son slides estáticos.
- **Internacionalización**: app sigue siendo solo español.
- **Onboarding más detallado por feature** (e.g. tutorial específico para reportes): los slides son intro general; la sección Ayuda es la referencia profunda.
- **Restaurar el onboarding manualmente** desde Settings (e.g. "Volver a ver el tutorial"). Iteración futura si los testers lo piden.
- **Notificaciones push de recordatorio de backup**: solo señal visual estática en Settings.

## Reglas de negocio

- **RN-O01 (visibilidad del onboarding)**: el onboarding se muestra exactamente una vez por instalación, y solo si:
  - `app_preferences.onboarding_seen` es `false` o no existe **Y**
  - `hasBolsa()` retorna `false` (la BD está realmente vacía).
  - Esto garantiza que Diego (con Bolsa ya sembrada) NUNCA ve el onboarding al actualizar la app. Si el tester importa un respaldo en el first-run, tampoco vuelve a verlo porque el flag se marca al completar el onboarding (antes del first-run).
- **RN-O02 (orden de pantallas en arranque)**: `splash` → (si `!onboarding_seen && !hasBolsa`) `onboarding` → `first-run` → `dashboard`. Si `onboarding_seen` está en true o `hasBolsa` retorna true, se salta directo a `first-run` o `dashboard` según corresponda.
- **RN-O03 (saltar onboarding)**: al tappear "Saltar" o "Empezar", se marca `onboarding_seen = true` aunque no haya visto los 3 slides. La decisión del usuario es respetada.
- **RN-O04 (no reaparece tras wipe)**: tras `wipeAll()` (que limpia `app_preferences`), el flag de onboarding vuelve a `false` y el usuario lo verá de nuevo. Coherente con "reset deja la app como nueva".
- **RN-O05 (Ayuda accesible siempre)**: la pantalla `/help` está disponible desde Settings sin condición, no depende de flags ni de estado de la BD.
- **RN-O06 (semáforo de backup)**: la sección "Respaldo" en Settings calcula la antigüedad del último export en tiempo real al construir la pantalla. No requiere stream reactivo — basta con `FutureBuilder` o cálculo en `didChangeDependencies`.
- **RN-O07 (timestamp inicial de backup)**: si `app_preferences.last_export_at` no existe, mostrar "Aún no exportaste un respaldo." (no calcular como "hace ∞ días"). Si existe pero el parse falla, tratar como nunca exportado.
- **RN-O08 (qué cuenta como export exitoso)**: solo se actualiza `last_export_at` cuando `Share.shareXFiles` retorna `ShareResultStatus.success` (mismo criterio que `_exportThenReset` ya usa). Una cancelación del share NO actualiza.
- **RN-O09 (no romper el flujo de Diego)**: Diego (que ya tiene Bolsa) actualiza el APK a esta versión. NO debe ver el onboarding ni cambios disruptivos en el dashboard. La sección Ayuda y la línea de backup aparecen pero no son intrusivas.

## Requisitos funcionales

- **RF-001**: Nueva tabla SQLite `app_preferences` con columnas `key TEXT PRIMARY KEY NOT NULL` y `value TEXT NOT NULL`. Schema bump v3 → v4 en `database.dart`. Migración aditiva en `onUpgrade` con guardarail (RN-H02 del repo).
- **RF-002**: Nuevo DAO `AppPreferencesDao` con métodos `Future<String?> get(String key)` y `Future<void> set(String key, String value)`. Usar `INSERT OR REPLACE` para idempotencia.
- **RF-003**: Constantes para las claves: `kPrefOnboardingSeen = 'onboarding_seen'`, `kPrefLastExportAt = 'last_export_at'`. Centralizadas en un archivo `lib/data/app_preferences_keys.dart` o similar.
- **RF-004**: Nueva pantalla `OnboardingScreen` en `lib/screens/onboarding_screen.dart` con 3 slides en `PageView`. Estado del slide actual + controlador del `PageView`. Botones "Saltar" (top-right) y "Siguiente"/"Empezar" (bottom).
- **RF-005**: Cada slide es un widget privado (`_Slide1`, `_Slide2`, `_Slide3`) reutilizable que renderea ícono/wordmark + título + descripción + (slide 2 y 3) lista breve con iconos del catálogo de categorías o `Icons` del Material.
- **RF-006**: Indicador de slide actual (dots) con highlight del slide activo, tappeables para navegación directa.
- **RF-007**: Al completar el último slide o tappear "Saltar", el screen llama a `appPreferencesDao.set(kPrefOnboardingSeen, 'true')` y luego navega con `context.go(...)`. Destino: si `hasBolsa()` es `false` → `/first-run`; si es `true` → `/dashboard` (improbable pero defensivo).
- **RF-008**: Nueva ruta `/onboarding` en `app_router.dart`. La lógica de redirect del splash se extiende: si la BD se ha chequeado y `hasBolsa` es `false` Y `onboarding_seen` es `false`, redirigir a `/onboarding` (en lugar de `/first-run`).
- **RF-009**: `FirstRunState` se extiende con un campo opcional `bool? onboardingSeen` (nullable hasta chequear) que el splash carga en paralelo con `hasBolsa`. El router consume ambos.
- **RF-010**: Nueva pantalla `HelpScreen` en `lib/screens/help_screen.dart` con scrollable `ListView` de 6 `ExpansionTile`. Textos hardcoded en español, sin i18n.
- **RF-011**: Nueva ruta `/help` en `app_router.dart`. Accesible vía `context.push('/help')`.
- **RF-012**: Nueva entrada en `settings_screen.dart` justo antes de la sección "Acerca de": `BaseCard` con icono `Icons.help_outline`, label "Ayuda", subtítulo "FAQ sobre kinds, reportes y backup", `onTap: () => context.push('/help')`.
- **RF-013**: En `settings_screen.dart`, sección "Respaldo", debajo del botón "Exportar respaldo": widget `_LastExportInfo` que lee `app_preferences.last_export_at` y muestra la antigüedad. 3 estados de render:
  - Nunca exportado: texto subtle "Aún no exportaste un respaldo."
  - Exportado hace <14 días: texto subtle "Último respaldo: hace X días."
  - Exportado hace ≥14 días: chip con icono warning y texto "Último respaldo: hace X días — te recomendamos exportar pronto."
- **RF-014**: `_exportInternal` de `settings_screen.dart` actualiza `app_preferences.last_export_at` con `DateTime.now().toIso8601String()` solo cuando `result.status == ShareResultStatus.success` (RN-O08).
- **RF-015**: `BackupService.wipeAll()` extiende su transacción para borrar también la tabla `app_preferences`. Mismo patrón usado para `saved_views`.
- **RF-016**: Tests del data layer: round-trip de `AppPreferencesDao` (set/get/overwrite, null cuando falta clave).
- **RF-017**: Tests de migración v3 → v4: tabla `app_preferences` queda lista para CRUD tras el upgrade. Rama defensiva v1→v4 y v2→v4 también cubiertas (replica las migraciones intermedias).
- **RF-018**: Tests widget: `OnboardingScreen` renderiza 3 slides, "Saltar" llama al DAO + navega, "Siguiente"/"Empezar" hace lo mismo. `HelpScreen` renderiza 6 ExpansionTile.
- **RF-019**: Tests widget de `SettingsScreen`: con `last_export_at` nunca, <14 días, ≥14 días → cada caso renderiza el texto correcto.

## Casos principales

- **CP-01**: Tester instala el APK por primera vez. Splash → onboarding (3 slides) → first-run → arrancar limpio → dashboard con Bolsa.
- **CP-02**: Tester avanza con "Siguiente" hasta el último slide, tappea "Empezar" → flag se persiste → first-run.
- **CP-03**: Tester tappea "Saltar" en el slide 1 → flag se persiste → first-run sin haber visto los slides 2 y 3.
- **CP-04**: Tester abre Settings → tap "Ayuda" → expande "¿Qué tipos de movimientos hay?" → lee la explicación → vuelve a Settings.
- **CP-05**: Tester ya tiene 20 días sin exportar respaldo. Abre Settings → ve el badge warning amarillo + texto "te recomendamos exportar pronto". Exporta. La línea cambia a "Último respaldo: hace 0 días" sin badge.
- **CP-06**: Diego actualiza el APK de `0.11.4+67` a esta versión sobre su BD real (con Bolsa). Abre la app → splash → dashboard directo. NO ve onboarding. La sección Ayuda y la línea de backup están disponibles en Settings.
- **CP-07**: Tester hace "Reiniciar cuenta" desde Settings → wipe limpia BD + `app_preferences` → router redirige a /first-run → splash carga → `onboarding_seen` es false → redirect a `/onboarding`. Vuelve a verlo desde cero.

## Casos borde

- **CB-T01**: La tabla `app_preferences` no existe (migración interrumpida o fallida). `AppPreferencesDao.get` debe retornar `null` sin crashear. Cobertura por test de migración.
- **CB-T02**: `last_export_at` existe pero no parsea como ISO 8601 válido. Tratar como "nunca exportado" (RN-O07).
- **CB-T03**: Tester rota el teléfono durante el onboarding. El `PageView` mantiene el slide actual gracias al `PageController`.
- **CB-T04**: Tester sale del onboarding con back hardware del Android sin tappear nada. Decisión: el back vuelve a `/splash` o cierra la app. NO marca `onboarding_seen`. La próxima vez que entre, vuelve a ver el onboarding. Comportamiento aceptable.
- **CB-T05**: El reloj del cel cambia hacia el pasado (e.g. usuario juguetea con la fecha). `last_export_at` queda en el futuro respecto a `now`. Mostrar "hace 0 días" o "Último respaldo: en el futuro" sin crashear. Decisión: tratar deltas negativos como "hace 0 días".
- **CB-T06**: Tester abre la app con `hasBolsa = true` Y `onboarding_seen = false` (e.g. importó respaldo desde la pantalla de first-run de versión vieja sin pasar por onboarding). NO debe forzarse el onboarding: la condición `!hasBolsa` lo bloquea. Listo.
- **CB-T07**: Diego en el dashboard con Bolsa visible NO debe ver ningún elemento de onboarding ni cambio disruptivo en el dashboard. Ya cubierto por RN-O01.
- **CB-T08**: La sección Ayuda con texto largo en un `ExpansionTile` no debe romper el scroll. Validar con prueba manual.
- **CB-T09**: Backup automático futuro (no en este sprint) podría querer actualizar `last_export_at`. Documentar que la clave existe.

## Criterios de aceptación

- **AC-01**: Al instalar el APK sobre una BD vacía, el primer pantallazo después del splash es `OnboardingScreen` con el slide 1 visible.
- **AC-02**: Avanzando con "Siguiente" hasta el último slide y tappeando "Empezar", el siguiente pantallazo es `FirstRunScreen`.
- **AC-03**: Tappear "Saltar" en cualquier slide salta a `FirstRunScreen`.
- **AC-04**: Al volver a abrir la app después de haber visto el onboarding (sin importar el resultado del first-run), NUNCA vuelve a aparecer el onboarding.
- **AC-05**: Diego con BD que tiene Bolsa instalada NUNCA ve el onboarding al actualizar a esta versión.
- **AC-06**: Settings tiene una sección "Ayuda" con icono `Icons.help_outline` y texto "Ayuda" + subtítulo "FAQ sobre kinds, reportes y backup". Tap navega a `/help`.
- **AC-07**: `HelpScreen` renderiza 6 secciones expandibles con los temas listados en RF-010.
- **AC-08**: En Settings, debajo del botón "Exportar respaldo" siempre hay una línea sobre el último respaldo. Con BD nueva: "Aún no exportaste un respaldo.". Tras un export exitoso: "Último respaldo: hace 0 días.".
- **AC-09**: Con `last_export_at` de hace ≥14 días: aparece un badge `warning` con icono y texto "te recomendamos exportar pronto".
- **AC-10**: Tras `Reiniciar cuenta` desde Settings, el siguiente arranque vuelve a mostrar el onboarding desde el slide 1.
- **AC-11**: 0 errores en `flutter analyze`; suite verde en `flutter test`.

## Criterios medibles de éxito

- **CME-01**: `flutter test` pasa con al menos +14 tests nuevos (DAO + widget tests del onboarding + widget tests del recordatorio + 1 test de migración).
- **CME-02**: `flutter analyze` no introduce warnings o errores nuevos (los 4 hints `info` preexistentes siguen tolerados).
- **CME-03**: Diego puede actualizar el APK con su BD real sin que aparezca el onboarding ni se rompa ningún flujo existente.
- **CME-04**: Los testers que reciban el APK pueden navegar sin asistencia el flujo: onboarding → first-run → registrar primer movimiento → ver reportes → abrir Ayuda → exportar respaldo. Validable por smoke manual con un tester.

## Riesgos

- **R-01** (schema bump): es el segundo schema bump del MVP (el primero fue `saved_views` v2→v3). Riesgo bajo si seguimos la convención RN-H02 (rama explícita + guardrail + tests de migración). Migrar v3 → v4 con `CREATE TABLE app_preferences` aditivo.
- **R-02** (no romper Diego): la lógica del onboarding está condicionada a `!hasBolsa`. Pero hay que asegurar que el splash carga correctamente `onboarding_seen` en paralelo con `hasBolsa` y NO meta delays adicionales para Diego (su redirect debe ser instantáneo como hoy). Mitigar con un Future.wait en paralelo o lazy.
- **R-03** (back hardware en onboarding): si el tester presiona back, ¿qué pasa? Decisión: vuelve al splash o cierra la app (comportamiento default de Android). NO marca `onboarding_seen`. Documentado en CB-T04.
- **R-04** (textos del Ayuda quedan desactualizados): si en el futuro cambia un kind o un reporte, los textos del Ayuda van a tener que actualizarse. Sin i18n, la actualización es directa.
- **R-05** (tester con cel viejo): el `PageView` y `ExpansionTile` son Material widgets estándar. Sin riesgo.
- **R-06** (último respaldo en el futuro): si el clock del cel se desfasa, `now - last_export_at` puede ser negativo. CB-T05 lo aborda mostrando "hace 0 días".

## Supuestos

- **S-01** (persistencia): se opta por tabla `app_preferences` en SQLite (drift). Razones: consistencia con el resto del data layer, sin dep nueva, sin manejo paralelo de `shared_preferences`. Schema bump aditivo v3 → v4.
- **S-02** (NO se incluye en backup JSON v1): `app_preferences` son estado de UI, no datos del usuario. Misma decisión que `saved_views` (v1 sprint).
- **S-03** (wipe limpia preferencias): `BackupService.wipeAll()` extiende su transacción para borrar `app_preferences`. Coherente con "reset deja como recién instalado".
- **S-04** (cantidad de slides): 3 slides. Bajo costo cognitivo, suficiente para dar contexto.
- **S-05** (navegación de slides): bidireccional (swipe + tap en dots). Estándar UX.
- **S-06** (ayuda en una sola pantalla): 6 `ExpansionTile` en un `ListView`. Sin sub-rutas ni navegación profunda. Simple.
- **S-07** (umbral de backup): 14 días. Razonable para un tester casual.
- **S-08** (tono de los textos): español neutro / mexicano coloquial, mismo tono que el resto de la UI. No "Estimado usuario, le informamos que..." — es Diego hablando con sus amigos.
- **S-09** (sin restaurar manualmente el onboarding): si un tester quiere volver a ver el tutorial, no hay opción explícita en v1. Iteración futura si lo piden.

## Impacto esperado

- **Funcional**: el grupo de testers entiende la app sin intervención de Diego. Diego puede compartir el APK con instrucciones mínimas. Los testers no pierden datos por olvido de backup.
- **Operativo**: Diego recibe feedback sobre features y bugs reales, no sobre fricción de onboarding. El backup recordatorio reduce el riesgo de pérdida de datos del testing.
- **Técnico**: introduce el patrón de `app_preferences` (tabla key/value para estado de UI) que puede reutilizarse en sprints futuros (e.g. preferencias del usuario, configuración avanzada, recordar último filtro). Es el segundo schema bump del MVP, valida que el patrón RN-H02 escala.
- **Para Diego**: cero disrupción. Su flujo de arranque sigue idéntico. Gana la sección Ayuda y la línea del último respaldo como features útiles para él también.
