# Tareas — flutter-reports-credit-cards-v1

## Base de datos

- [ ] T001 BD: Cambiar declaración de `credit_limit` de `real().nullable()()` a `real().withDefault(const Constant(0))()` en `mobile/lib/data/database.dart`. Regenerar `database.g.dart` con build_runner.
  RF: RF-001
  Depende de: ninguna
  Paralelizable: no (bloquea T002-T005)
  Criterio de terminado: `flutter analyze` sin errores nuevos por cambio de tipo; código generado con `credit_limit: double NOT NULL DEFAULT 0`.

- [ ] T002 BD: Subir `schemaVersion` de 4 a 5 en `mobile/lib/data/database.dart`. Agregar comentario del sprint en la lista de comentarios sobre `schemaVersion`.
  RF: RF-001
  Depende de: T001
  Paralelizable: no
  Criterio de terminado: constante `int get schemaVersion => 5` visible.

- [ ] T003 BD: Agregar rama `if (from == 4 && to == 5)` en `MigrationStrategy.onUpgrade` que ejecuta backfill + recreación de tabla. Guardrail `UnimplementedError` intacto al final.
  RF: RF-001
  Depende de: T002
  Paralelizable: no
  Criterio de terminado: correr `onUpgrade(m, 4, 5)` sobre BD con `credit_limit=null` deja el valor en 0 y la columna con constraint NOT NULL.

- [ ] T004 BD: Agregar ramas defensivas `if (from == 3 && to == 5)`, `if (from == 2 && to == 5)`, `if (from == 1 && to == 5)` en `MigrationStrategy.onUpgrade` combinando las migraciones intermedias más el paso a v5.
  RF: RF-002
  Depende de: T003
  Paralelizable: no
  Criterio de terminado: correr `onUpgrade(m, X, 5)` para X en {1,2,3} deja BD funcional y equivalente al camino v4→v5.

- [ ] T005 BD: Reforzar validación en `AccountsDao.create` y `AccountsDao.updateAccount` para rechazar `creditLimit==null` explícito cuando `type=='credit'` con `AccountsDaoError('invalid_credit_limit', 'El límite de crédito es obligatorio.')`.
  RF: RF-003
  Depende de: T001
  Paralelizable: sí (con T006, T007)
  Criterio de terminado: tests UT-01 y UT-02 pasan.

## Backend

- [ ] T006 Backend: Definir clase inmutable `CreditCardStatus` en `mobile/lib/data/reports.dart` con los campos listados en RF-007.
  RF: RF-007
  Depende de: T001
  Paralelizable: sí (con T005, T007)
  Criterio de terminado: clase compila con const constructor y `equals`/`hashCode` implementados.

- [ ] T007 Backend: Crear helper `nextOccurrenceOfDay(DateTime today, int targetDay)` en nuevo archivo `mobile/lib/data/date_helpers.dart` con clamp al último día del mes destino.
  RF: RF-007
  Depende de: ninguna
  Paralelizable: sí (con T005, T006)
  Criterio de terminado: UT-13 (15 casos) pasa.

- [ ] T008 Backend: Agregar método `Stream<List<CreditCardStatus>> watchCreditCards()` a `ReportsService` en `mobile/lib/data/reports.dart`. Query SQL agrega deuda por credit account activa; el orden RN-CC09 y las fechas próximas se computan en Dart post-fetch usando `nextOccurrenceOfDay`.
  RF: RF-007
  Depende de: T001, T006, T007
  Paralelizable: no
  Criterio de terminado: UT-05..UT-12 pasan.

- [ ] T009 Backend: Relajar validación de `credit_limit` en `BackupService.importFromJson` en `mobile/lib/data/backup.dart`. `null` para `type=credit` se ajusta a 0 e incrementa contador `adjustedAccountsCount` en el `ImportReport`. `< 0` se sigue rechazando con `invalid_credit_limit`. `>= 0` acepta.
  RF: RF-011
  Depende de: T001
  Paralelizable: sí (con T005, T006, T007)
  Criterio de terminado: DT-01, DT-02, DT-03, DT-04 pasan.

- [ ] T010 Backend: Extender `ImportReport` con campo `int adjustedAccountsCount` (default 0) en `mobile/lib/data/backup.dart`.
  RF: RF-011
  Depende de: ninguna (previa a T009)
  Paralelizable: sí (independiente)
  Criterio de terminado: campo presente, tests existentes de backup no rompen.

## Frontend

- [ ] T011 Frontend: Conectar `_minPaymentPctCtrl` a un `TextField` en `AccountFormScreen` (`mobile/lib/screens/account_form_screen.dart`). Visible solo cuando `_type == AccountType.credit`. Label "Pago mínimo (% del saldo)", suffixText '%', keyboard numeric, validator 0-100 opcional.
  RF: RF-004
  Depende de: T005
  Paralelizable: sí (con T012, T013)
  Criterio de terminado: WT-08, WT-09, WT-11, WT-12, WT-25 pasan.

- [ ] T012 Frontend: Conectar `_interestRateCtrl` a un `TextField` en `AccountFormScreen`. Visible solo cuando `_type == AccountType.credit`. Label "Tasa de interés anual", suffixText '% anual', helperText "Se usará en futuros reportes", validator 0-200 opcional.
  RF: RF-005
  Depende de: T005
  Paralelizable: sí (con T011, T013)
  Criterio de terminado: WT-08, WT-09, WT-11, WT-26 pasan.

- [ ] T013 Frontend: Agrupar los 5 campos credit-only en `AccountFormScreen` bajo un `SectionTitle('Detalles de tarjeta')` interno para mejorar la legibilidad del form.
  RF: RF-004, RF-005
  Depende de: T011, T012
  Paralelizable: no
  Criterio de terminado: form renderea el título encima de los 5 inputs credit-only cuando `_type=credit`; no aparece cuando `_type=cash|debit`.

- [ ] T014 Frontend: Crear archivo nuevo `mobile/lib/screens/reports/credit_cards_tab.dart` con `CreditCardsTab` StatelessWidget, `StreamBuilder<List<CreditCardStatus>>`, loading (SkeletonCard x2), empty state (texto + FilledButton "Agregar tarjeta" que hace `context.push('/accounts/new')`), data (ListView.builder de `_CreditCardTile`).
  RF: RF-006, RF-008
  Depende de: T008
  Paralelizable: sí (con T011, T012)
  Criterio de terminado: WT-01, WT-02, WT-05 pasan.

- [ ] T015 Frontend: Implementar `_CreditCardTile` privado en `credit_cards_tab.dart`. Card con header (nombre + descripción), progress ring del % usado con colores por umbral, filas deuda/límite/disponible, fila próximo corte con badge, fila próximo pago con badge, fila pago mínimo si aplica, badge "Sin deuda" o "Excedido por $X" cuando corresponda.
  RF: RF-008
  Depende de: T014
  Paralelizable: no
  Criterio de terminado: WT-03, WT-04, WT-06 pasan.

- [ ] T016 Frontend: Integrar sexto tab en `mobile/lib/screens/reports_screen.dart` agregando `Tab(text: 'Tarjetas')` al `TabBar` y `CreditCardsTab()` al `TabBarView`. Verificar que `isScrollable: true` sigue permitiendo scroll de los 6 tabs.
  RF: RF-006
  Depende de: T014
  Paralelizable: no
  Criterio de terminado: WT-15 pasa; visualmente el tab aparece al final.

- [ ] T017 Frontend: Actualizar slide 3 del `OnboardingScreen` en `mobile/lib/screens/onboarding_screen.dart`: agregar `_KindRow(icon: Icons.credit_card_outlined, color: FincoreColors.warning, label: 'Estado de tarjetas')` como sexta fila. Actualizar el párrafo para decir "6 reportes" en lugar de "5 reportes".
  RF: RF-009
  Depende de: ninguna (independiente del resto)
  Paralelizable: sí (con T011, T012, T014, T018, T019)
  Criterio de terminado: WT-13 pasa.

- [ ] T018 Frontend: Actualizar `HelpScreen` en `mobile/lib/screens/help_screen.dart`: el FAQ "¿Cómo se calculan los reportes?" pasa a listar los 6 tabs con explicación del nuevo tab "Estado de tarjetas".
  RF: RF-010
  Depende de: ninguna
  Paralelizable: sí (con T011, T012, T014, T017, T019)
  Criterio de terminado: WT-14 pasa; visualmente el FAQ menciona los 6 tabs.

- [ ] T019 Frontend: Actualizar `SettingsScreen._import` en `mobile/lib/screens/settings_screen.dart` para mostrar en el snackbar de éxito el conteo `adjustedAccountsCount` si es > 0. Ej: "Respaldo importado: 5 cuentas (3 ajustadas a límite 0), 10 categorías, 100 movimientos."
  RF: RF-011
  Depende de: T009, T010
  Paralelizable: sí (con T017, T018)
  Criterio de terminado: snackbar visualmente incluye la línea de ajustados cuando aplica.

## Pruebas

- [ ] T020 Pruebas: Agregar tests UT-01..UT-04 al final de `mobile/test/data/database_test.dart` en el grupo AccountsDao para cubrir validación reforzada de `credit_limit`.
  RF: RF-003
  Depende de: T005
  Paralelizable: sí (con T021, T022, T023, T024)
  Criterio de terminado: 4 tests pasan.

- [ ] T021 Pruebas: Agregar tests UT-05..UT-12 en un archivo o grupo nuevo `mobile/test/data/reports_test.dart` (o `reports_credit_cards_test.dart` si crece) cubriendo `watchCreditCards()` con distintos escenarios (empty, sin metadata, archivadas, orden, %, overdue, reactividad).
  RF: RF-007
  Depende de: T008
  Paralelizable: sí (con T020, T022, T023, T024)
  Criterio de terminado: 8 tests pasan.

- [ ] T022 Pruebas: Agregar tests UT-13 (15 sub-casos) en archivo nuevo `mobile/test/data/date_helpers_test.dart` cubriendo `nextOccurrenceOfDay` en calendario edge cases.
  RF: RF-007
  Depende de: T007
  Paralelizable: sí (con T020, T021, T023, T024)
  Criterio de terminado: 15 sub-tests pasan.

- [ ] T023 Pruebas: Agregar tests UT-14..UT-19 en el grupo de migraciones de `mobile/test/data/database_test.dart` cubriendo v4→v5 + defensivas + idempotencia + preservación de FKs.
  RF: RF-001, RF-002
  Depende de: T003, T004
  Paralelizable: sí (con T020, T021, T022, T024)
  Criterio de terminado: 6 tests pasan.

- [ ] T024 Pruebas: Agregar tests DT-01..DT-06 en `mobile/test/data/backup_test.dart` cubriendo import compat con `credit_limit=null`, `=0`, `<0` + round-trip + export siempre con campo presente.
  RF: RF-011
  Depende de: T009, T010
  Paralelizable: sí (con T020, T021, T022, T023)
  Criterio de terminado: 6 tests pasan.

- [ ] T025 Pruebas: Agregar tests WT-01..WT-07 en archivo nuevo `mobile/test/screens/reports/credit_cards_tab_test.dart` cubriendo empty, data, sin metadata, reactividad, orden, overdue, "Sin deuda".
  RF: RF-008
  Depende de: T014, T015
  Paralelizable: sí (con T026, T027)
  Criterio de terminado: 7 tests pasan.

- [ ] T026 Pruebas: Extender `mobile/test/screens/account_form_screen_test.dart` (o similar) con tests WT-08..WT-12 cubriendo visibilidad condicional de los 5 campos credit-only, validación de credit_limit obligatorio, save exitoso con nuevos campos.
  RF: RF-004, RF-005
  Depende de: T011, T012, T013
  Paralelizable: sí (con T025, T027)
  Criterio de terminado: 5 tests pasan.

- [ ] T027 Pruebas: Actualizar/extender tests existentes de `OnboardingScreen` y `HelpScreen` con WT-13, WT-14, WT-15 y RT-08, RT-09.
  RF: RF-006, RF-009, RF-010
  Depende de: T016, T017, T018
  Paralelizable: sí (con T025, T026)
  Criterio de terminado: 3 tests nuevos pasan + los previos no regresan.

- [ ] T028 Pruebas: Correr `flutter test` completo para validar 0 regresiones y ~385 tests verdes.
  RF: todos
  Depende de: T020..T027
  Paralelizable: no
  Criterio de terminado: exit code 0, contador de tests visible al final.

## Documentación

- [ ] T029 Documentación: Actualizar `mobile/pubspec.yaml` con `version: 0.13.0+71` y comentario del sprint arriba de la línea de version siguiendo el estilo de los sprints previos.
  RF: RF-012
  Depende de: T028
  Paralelizable: no
  Criterio de terminado: pubspec actualizado.

- [ ] T030 Documentación: Actualizar `mobile/android/app/build.gradle.kts` con `versionCode = 71` y `versionName = "0.13.0"`.
  RF: RF-012
  Depende de: T029
  Paralelizable: no
  Criterio de terminado: gradle actualizado.

- [ ] T031 Documentación: Actualizar `CLAUDE.md` en la raíz del repo: agregar el nuevo tab a la sección "Reports" (si existe) y el nuevo campo obligatorio `credit_limit NOT NULL` a la sección de "Capa de datos".
  RF: N/A (calidad de documentación interna)
  Depende de: T028
  Paralelizable: sí (con T029, T030)
  Criterio de terminado: sección "Capa de datos" refleja el schema v5.

## Validación de calidad

- [ ] T032 Validación: Correr `flutter analyze`. Debe quedar en 0 errores (los 4 hints info pre-existentes tolerados).
  RF: todos
  Depende de: T028
  Paralelizable: no
  Criterio de terminado: análisis limpio.

- [ ] T033 Validación: Build APK release con `flutter build apk --release --split-per-abi` + `bash scripts/verify-apk.sh`. Confirmar versionCode 2071 y versionName 0.13.0 consistentes.
  RF: RF-012
  Depende de: T029, T030
  Paralelizable: no
  Criterio de terminado: verify-apk OK.

- [ ] T034 Validación: Diego corre SM-01..SM-09 en su cel real con APK arm64-v8a. Reportar cualquier issue como blocker antes del commit final.
  RF: todos
  Depende de: T033
  Paralelizable: no
  Criterio de terminado: smokes confirmados por Diego (mínimo SM-01, SM-03, SM-08).

- [ ] T035 Validación: Invocar skill `branch-quality-review` con slug `flutter-reports-credit-cards-v1` para revisión exhaustiva de rama antes del commit final. Aplicar hallazgos verificados 1 por 1 (patrón usado en sprints previos).
  RF: todos
  Depende de: T034
  Paralelizable: no
  Criterio de terminado: reporte generado en `engineering/quality-review/flutter-reports-credit-cards-v1/` y hallazgos reales atendidos.

- [ ] T036 Validación: Commit final con mensaje HEREDOC describiendo el sprint. Incluir versión, cambios schema, cambios UI, tests nuevos, y Co-Authored-By.
  RF: todos
  Depende de: T035
  Paralelizable: no
  Criterio de terminado: commit visible con `git log`.
