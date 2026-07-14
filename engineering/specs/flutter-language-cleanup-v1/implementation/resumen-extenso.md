# Resumen extenso — flutter-language-cleanup-v1

## Contexto

Sprint 2 del roadmap definido en `engineering/design-audit-2026-07-14/consolidado.md`. Cierra la deuda **S3 (español neutral roto)** identificada en la auditoría global.

La regla `feedback_spanish_neutral.md` (2026-07-14 en memoria): "Usar 'tienes/puedes/aquí' en strings UI y comentarios; nunca 'tenés/podés/acá'". El sprint anterior (`flutter-design-tokens-v1`) documentó su falta de cumplimiento; este sprint la resuelve estructuralmente.

Cero preguntas bloqueantes. Un hallazgo colateral durante discovery: los matchers de `integration_test/` apuntan a strings ya inexistentes en `lib/` — heredado de un sprint pasado sin propagación a tests.

## Relación con `plan.md` y `tasks.md`

Ejecución alineada al plan. Total: 26 ediciones puntuales + 1 archivo nuevo + 2 archivos de bump. Ejecutado por Claude directo (sin subagentes) por ser sprint chico y mecánico.

Ninguna desviación del plan; una tweak técnica documentada:

- **DP-01** (guardrail): la regex inicial incluía `partí|salí|dormí|volvé|corré|escribí` como formas verbales voseantes. Falso positivo detectado en `dashboard_screen.dart:150` donde `"partía"` (pretérito imperfecto neutral) fue matcheado por `\bpartí\b` — bug de Dart RegExp con Unicode y word boundaries en caracteres acentuados. Solución: remover `partí/salí/dormí` del regex (son ambiguos: neutral vs voseo según contexto). Se mantiene `volvé/corré` porque son inequívocamente imperativo voseo. Documentado en el docstring del test.

## Cambios principales por módulo o capa

### Copy UI visible al usuario (`mobile/lib/screens/`, `mobile/lib/widgets/`, `mobile/lib/data/daos/`)

10 strings reescritos con criterio semántico:

- **Verbo tú directo** cuando el copy actual era imperativo directo: `Configurá → Configura`, `Ajusta`, `Ajusta los filtros`.
- **Infinitivo impersonal** cuando el copy era instrucción sistémica: `Pagás una tarjeta desde otra cuenta → Pagar una tarjeta desde otra cuenta`, `Acotá filtros → Reducir el rango de filtros`, `Configurá filtros y tap → Configura filtros y toca` (anglicismo "tap" también localizado).
- **Voz impersonal** cuando el original era condicional: `Necesitás al menos 1 mes → Se necesita al menos 1 mes`.
- **Sustantivo** cuando el verbo era ambiguo: `Pagás desde → Pago desde` (label del origen en `debtPayment`).
- **Reformulación** cuando el reemplazo mecánico quedaba torpe: `Probá con 1-50 caracteres → Debe tener entre 1 y 50 caracteres`.
- **Descontrafacción de "entries"** en el copy: `ver entries más viejos → ver movimientos más antiguos`.

### Comentarios de código

15 ocurrencias de `acá` → `aquí` en 11 archivos de `lib/` y 4 de `test/`. Reemplazo mecánico (cada archivo tenía 1 sola ocurrencia). También `querés → quieres` y `pasá → pasar` en `widget_test_harness.dart`.

### Jerga técnica

`settings_screen.dart:501` — `"FAQ sobre kinds, reportes y backup."` → `"FAQ sobre tipos de movimientos, reportes, presupuestos y respaldo."`. Elimina 2 tecnicismos (`kinds`, `backup`) y agrega `presupuestos` que ya estaban en el resto de la ayuda.

### Tests

- 5 matchers en `integration_test/` actualizados al copy neutral real (`'Ingresar un nombre.'`, `'Ya existe una cuenta con ese nombre'`, etc.).
- 3 matchers en widget tests (`entry_form_kinds`, `settings_screen`, `monthly_average_tab`) actualizados como consecuencia directa del cambio de copy en `lib/`.
- Nuevo `mobile/test/language/no_voseo_test.dart` — 76 líneas, escanea `lib/` con regex y falla con mensaje diagnóstico si detecta voseo.

### Documentación

- `CLAUDE.md` `Convenciones del repo` — 1 línea agregada: la regla + referencia al test.
- `pubspec.yaml` — bump `0.21.1+98` + comentario changelog.
- `build.gradle.kts` — bump `98 / 0.21.1`.

## Desviaciones respecto al plan

### DP-01 — regex del guardrail ajustada

Ya documentada arriba. El plan no anticipó el falso positivo por Unicode `\b`. Fix inline sin bloquear el sprint.

### DP-02 — matchers de widget tests fuera del plan explícito

El plan mencionaba solo los 5 matchers de `integration_test/` (T006). Al correr `flutter test`, 3 widget tests fallaron por matchear el copy voseado que se cambió. Se actualizaron dentro del sprint por RF-008 ("los tests existentes deben seguir pasando"). Cambios triviales: literal-por-literal replacement.

## Pruebas realizadas y recomendadas

### Realizadas

- `flutter analyze --no-fatal-infos`: **verde** (3 hints info pre-existentes de `entry_form_screen.dart`, no del sprint).
- `flutter test` (suite completa): **681/681 verdes**. Timing: ~1 min. 3 iteraciones:
  1. Post-migración de copy: 678/681 verdes (3 tests con matchers desactualizados).
  2. Post-actualización de matchers: 681/681 verdes.
  3. Confirmación tras ediciones adicionales: 681/681 verdes.
- `flutter test test/language/no_voseo_test.dart`: verde en 500ms tras el fix del regex.
- Guardrails con `grep`: cero violaciones.

### Recomendadas / pendientes

- **Smoke desktop** (`flutter run -d linux`): 5 pantallas con copy cambiado (Entries + Settings + Reports MonthlyAverage + KindPicker + saved_views).
- **Smoke Android SM-06**: layout en 360dp para las 2 strings alargadas.
- **Integration_test en emulador**: `flutter test integration_test/` con dispositivo Android o Linux desktop conectado — confirma que los 5 matchers actualizados pasan en runtime real.

## Riesgos residuales y posibles regresiones

- **RT-03** (strings alargadas): posible wrap raro en 360dp. Mitigación: smoke Android.
- **Falso positivo del guardrail resuelto**: regex sin verbos ambiguos, aceptado como trade-off.
- **Integration_test posiblemente descolgados de CI**: hallazgo colateral del sprint. No es del scope, pero se recomienda agregar `flutter test integration_test/` al pipeline en un follow-up separado.

## Trazabilidad final

- **8 RF** definidos en `spec.md` → **16 tasks** planificadas → **14 ejecutadas**, 2 pendientes de Diego (smoke + commit).
- **Cero preguntas bloqueantes**.
- **2 desviaciones documentadas** (DP-01 regex tweak + DP-02 widget test matchers).
- **681 tests** verdes; **3 tests actualizados** (consecuencia esperada del sprint).
- **1 hallazgo colateral** (integration_test descolgado de CI) — recomendación separada.

Sprint listo para commit cuando Diego apruebe.
