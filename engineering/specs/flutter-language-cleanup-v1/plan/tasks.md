# Tasks — flutter-language-cleanup-v1

## Frontend

- [ ] T000 Pruebas: Investigar estado de los 5 matchers en `integration_test/`. Verificar (a) qué string real muestra la app hoy en cada punto, (b) si los tests están pasando actualmente. Grep en `lib/` de las strings `'Ingresá un nombre.'` y `'Ya tenés una cuenta/categoría con ese nombre'` para confirmar que están ausentes. Documentar hallazgo en `desviaciones-plan.md` si aplica.
  RF: RF-004
  Depende de: ninguna
  Paralelizable: no
  Criterio de terminado: documento con qué string mostrar en cada matcher y por qué.

- [ ] T001 Frontend: Migrar copy con voseo en widgets (`kind_picker.dart:122`, `entries_paginated_list.dart:226`, `entries_empty_state.dart:31`, `error_snackbar.dart:174`).
  RF: RF-001
  Depende de: ninguna
  Paralelizable: si
  Criterio de terminado: 4 archivos editados; grep del voseo en `lib/widgets/` = 0.

- [ ] T002 Frontend: Migrar copy con voseo en screens (`entry_form_screen.dart:712`, `entries_filters_screen.dart:490`, `saved_views_list_screen.dart:221`, `reports/monthly_average_tab.dart:441`, `onboarding_screen.dart:14` si aplica).
  RF: RF-001
  Depende de: ninguna
  Paralelizable: si
  Criterio de terminado: 5 archivos editados; grep del voseo en `lib/screens/` = 0.

- [ ] T003 Frontend: Migrar copy con voseo en data layer (`daos/saved_views_dao.dart:146`).
  RF: RF-001
  Depende de: ninguna
  Paralelizable: si
  Criterio de terminado: 1 archivo editado; grep = 0 en `lib/data/`.

- [ ] T004 Frontend: Reemplazo mecánico `\bacá\b` → `aquí` en 11 comentarios de `lib/` y 4 de `test/`. NO tocar `pubspec.yaml` (bitácora histórica).
  RF: RF-002
  Depende de: ninguna
  Paralelizable: si
  Criterio de terminado: grep `\bacá\b` en `lib/` y `test/` = 0.

- [ ] T005 Frontend: Reemplazar `'FAQ sobre kinds, reportes y backup.'` en `settings_screen.dart:501` por `'FAQ sobre tipos de movimientos, reportes, presupuestos y respaldo.'`.
  RF: RF-003
  Depende de: ninguna
  Paralelizable: si
  Criterio de terminado: grep `"kinds"` en `settings_screen.dart` no devuelve la línea de copy visible.

- [ ] T006 Frontend: Actualizar matchers de `integration_test/account_form_test.dart` (2 matchers + comentario) y `category_form_test.dart` (2 matchers) al copy neutral actual. Basado en hallazgo de T000.
  RF: RF-004
  Depende de: T000, T001, T002, T003
  Paralelizable: no
  Criterio de terminado: los 5 matchers reflejan el copy real que muestra la app.

## Pruebas

- [ ] T007 Pruebas: Crear `mobile/test/language/no_voseo_test.dart` con el test guardrail. Debe:
  - Escanear todos los `.dart` de `mobile/lib/` recursivamente.
  - Excluir archivos `.g.dart` y el propio archivo del test.
  - Aplicar la regex del voseo.
  - Fallar con `fail('Voseo detectado en <archivo>:<línea>: <match>')` si encuentra ocurrencias.
  - Ejecutarse en &lt;500ms.
  RF: RF-005
  Depende de: T001, T002, T003 (para que el test pase de una)
  Paralelizable: no
  Criterio de terminado: `flutter test test/language/no_voseo_test.dart` pasa en verde.

## Documentacion

- [ ] T008 Documentación: Extender `CLAUDE.md` en la sección "Convenciones del repo" con la regla: "Lenguaje UI y comentarios en español neutral. Nunca voseo rioplatense (`pagás/podés/tenés/acá`). El test `mobile/test/language/no_voseo_test.dart` blindea contra regresión.".
  RF: RF-006
  Depende de: T007
  Paralelizable: si
  Criterio de terminado: sección actualizada; `grep "voseo" CLAUDE.md` devuelve la nueva línea.

- [ ] T009 Frontend: Bump versión en `mobile/pubspec.yaml` (`0.21.1+98`) y `mobile/android/app/build.gradle.kts` (`versionCode = 98`, `versionName = "0.21.1"`). Agregar comentario changelog al pubspec.
  RF: RF-007
  Depende de: T001-T008
  Paralelizable: no
  Criterio de terminado: ambos archivos actualizados.

## Validacion de calidad

- [ ] T010 Pruebas: Correr `flutter analyze` — 0 errores.
  RF: RF-008
  Depende de: T001-T009
  Paralelizable: no
  Criterio de terminado: `No issues found!` o solo hints info pre-existentes tolerados.

- [ ] T011 Pruebas: Correr `flutter test` — 681+ verdes (680 previos + guardrail).
  RF: RF-008
  Depende de: T001-T009
  Paralelizable: no
  Criterio de terminado: suite completa verde. Registrar en `implementation/pruebas.md`.

- [ ] T012 Pruebas: Smoke desktop (`flutter run -d linux`) SM-01 a SM-05. Diego lo ejecuta (o Claude reporta y Diego valida).
  RF: RF-008
  Depende de: T010, T011
  Paralelizable: no
  Criterio de terminado: 5 flujos smoke ejecutados sin regresión visual.

- [ ] T013 Pruebas: Build APK release y smoke Android SM-06 (validar layout en 360dp de los 2 strings alargados). Diego lo ejecuta.
  RF: RF-008
  Depende de: T012
  Paralelizable: no
  Criterio de terminado: APK generado; smoke sin wrap/ellipsis inesperado.

- [ ] T014 Validación: Revisión equivalente a `branch-quality-review` (skill no expuesta en sesiones actuales). Manual checklist: guardrails grep, cero regresión de tests, correspondencia RF↔implementación, sin cambios fuera de scope, excepciones documentadas.
  RF: transversal
  Depende de: T013
  Paralelizable: no
  Criterio de terminado: reporte manual en `implementation-review.md` sección "Revisión equivalente".

## Documentacion (cierre)

- [ ] T015 Documentación: Crear `engineering/specs/flutter-language-cleanup-v1/implementation/` con `implementation-review.md`, `resumen-ejecutivo.md`, `resumen-extenso.md`, `progreso.md`, `pruebas.md`. Opcional `desviaciones-plan.md` si T000 detecta discrepancias.
  RF: transversal
  Depende de: T014
  Paralelizable: no
  Criterio de terminado: archivos de cierre completos.

- [ ] T016 Documentación: Reportar a Diego el estado final antes del commit. Diego decide si commit único o dos (uno por Sprint 1 pendiente de aprobación + uno por Sprint 2).
  RF: transversal
  Depende de: T015
  Paralelizable: no
  Criterio de terminado: reporte + espera de decisión de Diego (regla del proyecto: solo commitear con aprobación explícita).
