# Test plan — flutter-weekly-budgets-v1

## Casos borde detectados

Además de los CB-01..CB-20 de la spec y CB-P01..CB-P07 del plan, se
agregan:

- **CB-T01 — Renglón con `name` de exactamente 60 chars**: aceptado.
  61 chars → rechazado con `invalid_item_name`.
- **CB-T02 — Renglón con `amount` de subcentavo (ej: 0.001)**:
  aceptado si > 0. La UI redondea a 2 decimales al mostrar; el
  DAO guarda el valor real.
- **CB-T03 — Renglón con `amount` gigante (ej: 1e12)**: aceptado
  (no hay validación de tope superior). Documentar como aceptado.
- **CB-T04 — Presupuesto con `label` en unicode / emojis**:
  aceptado (BD text, contador de chars usa `runes.length`).
- **CB-T05 — Presupuesto en fecha futura extrema (año 3000)**:
  aceptado por el DAO. Aparece bajo "Próximas". Sin bloqueo.
- **CB-T06 — Presupuesto en fecha pasada extrema (año 1900)**:
  aceptado. Bajo "Pasadas".
- **CB-T07 — Race: dos taps simultáneos en "Eliminar"**: el
  dialog bloquea múltiples taps por su naturaleza modal. Sin race
  real en single-user.
- **CB-T08 — Crear plantilla desde un presupuesto vacío**: se
  crea plantilla con 0 items. Aplicarla al crear otro presupuesto
  → presupuesto vacío. Aceptado.
- **CB-T09 — Aplicar plantilla mientras la BD está en estado
  parcial de import**: dentro del contrato "reemplazo total" no
  aplica — el usuario está bloqueado durante el import.
- **CB-T10 — Editar `weekStartDate` vía `updateBudget(id,
  weekStartDate: X)`**: DAO lanza `immutable_field`. Test explícito.
- **CB-T11 — Crear 2 items con mismo `sort_order` inicial**: el
  helper del DAO asigna en bloques de 100. Race no aplica en
  single-user. Test cubre asignación inicial correcta.
- **CB-T12 — Reorder que no cambia el orden (mover a la misma
  posición)**: `onReorder` de `ReorderableListView` no dispara si
  index viejo == nuevo. Sin efecto en BD. Aceptado.
- **CB-T13 — Presupuesto con 0 income y 5 expense** (CB-03): balance
  = −Σ, footer rojo "Faltan $X".
- **CB-T14 — Presupuesto con income y expense iguales**: balance
  = 0, footer gris "En equilibrio".
- **CB-T15 — Category picker con 0 categorías activas**: dropdown
  muestra "Sin categorías" — item sin badge, guardado con
  `category_id = null`.
- **CB-T16 — Preferencia `week_start_dow` no seteada (nunca se
  cambió)**: helper retorna default `5`. `get('week_start_dow')` =
  `null` → parsed como `null` → fallback a 5.
- **CB-T17 — Preferencia `week_start_dow` seteada a `'abc'` (BD
  corrupta)**: helper detecta `int.tryParse` = `null` → fallback
  a 5. Sin crash.
- **CB-T18 — Preferencia `week_start_dow` seteada a `'0'` o `'8'`
  (fuera de rango ISO)**: helper detecta fuera de rango → fallback
  a 5.
- **CB-T19 — Cambio de TZ del dispositivo entre create y read del
  budget**: el DATE guardado se lee con la nueva TZ. Aceptado —
  el rango calendario local puede desplazarse una hora en el
  borde de medianoche pero el día calendario se preserva por
  normalización.
- **CB-T20 — Backup exportado sin arrays de budgets + import**:
  la BD queda con presupuestos borrados (wipeAll), 0 budgets, 0
  templates. Data del ledger preservada.
- **CB-T21 — Backup importado que trae arrays inesperados
  `weekly_budgets` (backup de un fork o futuro)**: el import los
  ignora sin lanzar error. Robustez defensiva.

## Pruebas unitarias necesarias

**Helpers puros (`weekly_budgets.dart`)**:

- UT-H01 `suggestedWeekStartDate(now: 2026-07-14 martes, dow=5
  viernes)` → `2026-07-10` (viernes previo).
- UT-H02 `suggestedWeekStartDate` con `now` cayendo exactamente en
  el `dow` → mismo día.
- UT-H03 `suggestedWeekStartDate` con `dow=1 lunes` y `now`
  domingo → lunes previo (6 días atrás).
- UT-H04 `groupBudgetsByRange(budgets, now)` separa
  correctamente "Esta semana", "Próximas", "Pasadas" según el
  rango calculado desde `week_start_date`.
- UT-H05 `groupBudgetsByRange` con presupuestos multi-plan misma
  fecha bajo la misma sección.
- UT-H06 `calculateBalance(items)` con 0 items → 0.
- UT-H07 `calculateBalance` con solo income → +Σ.
- UT-H08 `calculateBalance` con solo expense → −Σ.
- UT-H09 `calculateBalance` mixto → Σincome − Σexpense.

**WeeklyBudgetsDao**:

- UT-WB01 schema: las 4 tablas nuevas existen tras open de BD
  con schema v7.
- UT-WB02 `createBudget` con label válido persiste 1 fila con
  `created_at` seteado.
- UT-WB03 `createBudget` con label vacío / whitespace →
  `invalid_budget_label`.
- UT-WB04 `createBudget` con label > 60 chars →
  `invalid_budget_label`.
- UT-WB05 `updateBudget(id, label: 'nuevo')` persiste; retorna
  `1` (rows updated).
- UT-WB06 `updateBudget(id, weekStartDate: DateTime(...))` →
  `immutable_field`. (CB-T10)
- UT-WB07 `deleteBudget(id)` remueve la fila; los items caen por
  cascade. Verificar row count post.
- UT-WB08 `addItem` con `name` vacío → `invalid_item_name`.
- UT-WB09 `addItem` con `amount = 0` → `invalid_item_amount`.
- UT-WB10 `addItem` con `amount < 0` → `invalid_item_amount`.
- UT-WB11 `addItem` con `kind` inválido → `invalid_kind`.
- UT-WB12 `addItem` con `categoryId` de categoría archivada →
  `invalid_category_reference` (o `not_found`).
- UT-WB13 `addItem` sin categoría persiste con `categoryId = null`.
- UT-WB14 `addItem` asigna `sort_order` incremental en bloques de
  100 (10, 110, 210, ...).
- UT-WB15 `updateItem(id, amount: nuevo)` persiste; balance re-emite.
- UT-WB16 `deleteItem(id)` remueve fila; balance re-emite.
- UT-WB17 `reorderItems(budgetId, [id2, id1, id3])` renumera
  `sort_order` en transacción.
- UT-WB18 `watchBudgetBalance` retorna 0 para presupuesto vacío.
- UT-WB19 `watchBudgetBalance` retorna Σincome − Σexpense al
  agregar items.
- UT-WB20 `watchBudgetBalance` re-emite al agregar item con
  `emitsThrough`.
- UT-WB21 Multi-plan: 2 budgets con misma `week_start_date` y
  labels distintos coexisten sin error.
- UT-WB22 Categoría archivada tras crearse el item → el join deja
  category_id apuntando a la row archivada pero UI la ignora
  (verificar en widget test).
- UT-WB23 `createBudgetFromTemplate` copia snapshot: los items
  generados tienen nuevos `id` distintos a los del template.
- UT-WB24 `createBudgetFromTemplate` con template inexistente →
  `not_found`.
- UT-WB25 Editar template DESPUÉS de crear budget derivado NO
  cambia el budget derivado. (RN-B16 crítica)

**BudgetTemplatesDao**:

- UT-BT01 `createTemplateFromBudget` copia snapshot: items nuevos
  `id`.
- UT-BT02 `createTemplateFromBudget` con budget inexistente →
  `not_found`.
- UT-BT03 `createTemplate` con `name` duplicado →
  `duplicate_template_name`.
- UT-BT04 `createTemplate` con `name` vacío → `invalid_template_name`.
- UT-BT05 `updateTemplate(id, name: 'X')` valida
  duplicate_template_name si X ya está en uso por otro template.
- UT-BT06 `deleteTemplate(id)` remueve fila; items cascade;
  budgets derivados intactos. (RN-B16)
- UT-BT07 `addTemplateItem`, `updateTemplateItem`,
  `deleteTemplateItem`, `reorderTemplateItems` — mismos casos
  que WB08..WB17 aplicados a template.
- UT-BT08 Editar BUDGET original tras crear template derivado NO
  cambia el template. (Dirección inversa de RN-B15)

**AppPreferencesDao helpers**:

- UT-AP01 `weekStartDow()` con clave ausente → default `5`.
  (CB-T16)
- UT-AP02 `weekStartDow()` con valor `'3'` → `3`.
- UT-AP03 `weekStartDow()` con valor `'abc'` → default `5`.
  (CB-T17)
- UT-AP04 `weekStartDow()` con valor `'0'` o `'8'` → default `5`.
  (CB-T18)
- UT-AP05 `setWeekStartDow(3)` persiste y `weekStartDow()` retorna
  `3` en la lectura siguiente.

## Pruebas de integracion o API necesarias

No aplica — sin API externa.

## Pruebas de UI o flujo necesarias

Widget tests con harness `pumpFincoreApp`:

- WT-LS01 `/budgets` con BD vacía muestra empty state.
- WT-LS02 `/budgets` con 3 budgets (uno esta semana, uno próximo,
  uno pasado) muestra 3 secciones + card por budget con label +
  balance.
- WT-LS03 Tap FAB abre bottom sheet con 2 opciones.
- WT-LS04 "En blanco" del bottom sheet navega a picker + form.
- WT-LS05 "Desde plantilla" está deshabilitada si no hay
  templates activos; habilitada si sí.

- WT-DS01 `/budgets/:id` muestra AppBar con label + rango; sección
  income vacía, sección expense vacía, footer "En equilibrio".
- WT-DS02 Tap "+ ingreso" abre `BudgetItemFormSheet`. Guardar con
  monto 6500 y name "Sueldo" agrega card en sección income; footer
  → "Sobra $6500".
- WT-DS03 Agregar 1 expense $2000 → footer "Sobra $4500".
- WT-DS04 Editar el expense a $8000 → footer "Faltan $1500" rojo.
- WT-DS05 Delete item vía swipe/long-press con confirmación
  destructiva → item desaparece + balance recalcula.
- WT-DS06 Menu → "Eliminar presupuesto" muestra dialog destructivo
  con texto exacto "Esto borrará el presupuesto y sus N renglones.
  Esta acción no se puede deshacer." (CB-RT07 confirma copy)
- WT-DS07 Menu → "Crear plantilla desde este presupuesto" muestra
  dialog para name → guarda → snackbar success.
- WT-DS08 Drag handle sí reordena. Reorder desde el row (sin
  handle) NO reordena — el tap inicia edit. (CB-20)
- WT-DS09 Tap label en AppBar abre dialog inline para editar
  label; guardar persiste.
- WT-DS10 Intentar guardar item con `name` vacío → validación en
  el form no permite submit; snackbar/error inline.
- WT-DS11 Intentar guardar item con `amount = 0` → validación en
  el form no permite submit.

- WT-TS01 `/budget-templates` con 0 templates muestra empty state.
- WT-TS02 Con 2 templates listados, tap uno → detalle editable.
- WT-TS03 Detalle plantilla: agregar item + editar item + delete
  item + reorder — mismos flows que budget detail sin fecha.
- WT-TS04 Menu → "Eliminar plantilla" → confirm → borrado.

- WT-SET01 Sección "Preferencias" en `/settings` muestra
  DropdownButton con 7 opciones + valor actual.
- WT-SET02 Cambiar de "Viernes" a "Domingo" persiste; volver a
  entrar a `/budgets` y verificar sugerencia inicial del picker
  = próximo domingo.

- WT-DASH01 IconButton nuevo en Dashboard AppBar navega a
  `/budgets`.

- WT-HELP01 FAQ del `HelpScreen` tiene bloque explicando la
  diferencia entre mensual y semanal.

## Pruebas de permisos y seguridad

No aplica (single-user).

## Pruebas de datos, migracion o compatibilidad

- MG-01 Open de BD virgen (schemaVersion 7 desde 0) crea las 4
  tablas nuevas.
- MG-02 Open de BD existente v6 corre `onUpgrade` v6→v7; las 4
  tablas se crean; no se pierden datos de tablas previas.
- MG-03 Sin datos previos a migrar (aditivo puro).
- MG-04 Guardrail `UnimplementedError` sigue activo para cualquier
  `from`/`to` no manejado (test explícito con un `from = 99, to =
  100`).

## Pruebas de regresion sobre flujos existentes

- RG-01 Backup export sin budgets ni templates activos → JSON
  idéntico al del sprint previo (accounts + categories +
  journal_entries).
- RG-02 Backup export CON budgets/templates activos → JSON NO los
  incluye (RN-B13). Verificar keys en el objeto raíz.
- RG-03 Backup import de un JSON v1 legacy en BD con budgets
  activos → BD queda sin budgets/templates (wipeAll los borra) +
  data legacy poblada. (CB-09 spec)
- RG-04 Backup import de un JSON con array `weekly_budgets`
  spurio → el import no crashea; ignora el array; produce mismo
  resultado que RG-03.
- RG-05 `EntriesDao.watchPage` + `registerIncome/Expense/*` no
  alterados.
- RG-06 `FinancialStateService.watchBo/De/Cr` no alterados.
- RG-07 `ReportsService.*` métodos no alterados.
- RG-08 Dashboard: la agregación de la card "Hoy" + sparklines +
  chips filtro siguen funcionando.
- RG-09 SavedViews, onboarding, help screen tests preexistentes
  siguen verdes.
- RG-10 `flutter analyze` sin nuevos issues.

## Pruebas manuales o smoke tests necesarios

- **SM-01 Setting inicial**: primer install del APK, ir a
  `/settings` → "Preferencias" → verificar que muestra "Viernes"
  como default. Cambiar a "Sábado" → persiste.
- **SM-02 Crear budget en blanco**: FAB en `/budgets` → "En
  blanco" → picker sugiere próximo sábado (por SM-01) → label
  "Sueldo 25" → guardar → aparece card en "Próximas".
- **SM-03 Agregar renglones + ver balance**: en el detalle,
  agregar 1 income $6500 + 4 expense (1000, 2000, 500, 800) →
  footer muestra "Sobra $2200" en verde reactivo.
- **SM-04 Drag handle reordena**: mantener presionado el handle
  ⋮⋮ de un renglón → arrastrarlo → nuevo orden persiste al salir
  y reentrar.
- **SM-05 Tap en row (no en handle) NO reordena, abre edit**:
  confirmar que solo el handle inicia el gesto.
- **SM-06 Multi-plan por semana**: crear un segundo presupuesto
  "Sueldo 25 · Optimista" con los mismos $6500 pero $6000 en
  gastos → footer "Sobra $500". Ambos aparecen en el listado
  bajo la misma sección.
- **SM-07 Crear plantilla desde presupuesto**: menú → "Crear
  plantilla" → nombre "Sueldo base" → snackbar success → verificar
  en `/budget-templates` que aparece.
- **SM-08 Aplicar plantilla al crear budget nuevo**: FAB → "Desde
  plantilla" → seleccionar "Sueldo base" → preview correcto →
  guardar → budget nuevo con los mismos renglones.
- **SM-09 Editar plantilla no afecta budget derivado**: editar
  "Sueldo base" agregando "Ahorro $500" → verificar que el budget
  derivado (SM-08) sigue sin ese renglón.
- **SM-10 Editar budget no afecta plantilla**: editar el budget
  derivado (SM-08) cambiando "Sueldo" a $7000 → verificar que la
  plantilla "Sueldo base" sigue con $6500.
- **SM-11 Eliminar budget con dialog destructivo**: menú →
  "Eliminar" → dialog muestra texto correcto → confirmar → back al
  listado, card desaparece.
- **SM-12 Eliminar plantilla no toca budgets derivados**: eliminar
  "Sueldo base" → confirmar → los presupuestos creados desde ella
  siguen intactos.
- **SM-13 Cambio de day-of-week no afecta existentes**: cambiar
  setting a "Lunes" → volver a `/budgets` → los presupuestos
  previos conservan su fecha y rango.
- **SM-14 Backup + wipeAll pierde budgets**: exportar backup → ir
  a "Zona peligrosa" → "Reiniciar cuenta" con backup → confirmar
  → los presupuestos y plantillas desaparecen. Data del ledger
  restaurada.
- **SM-15 IconButton del Dashboard abre `/budgets`**: tap en el
  ícono nuevo del AppBar → navegación correcta.
- **SM-16 Cel angosto**: el drag handle sigue siendo tapable en
  viewport ≤ 400 px. Confirmar hit area.

## Datos de prueba recomendados

Setup UT (in-memory BD):

- Bolsa (seed default) + categorías básicas del seed.
- Categoría extra "Ahorro" (`applies_to = income`) para testear
  categoría income en item expense (CB-12 spec).
- Categoría archivada "Vieja" para CB-04 y CB-16 spec.
- Presupuesto A: `week_start_date = 2026-07-17 (vie)`, label
  "Sueldo 17", 3 items income (6500, 200, 500) + 4 items expense
  (1000, 2000, 500, 800).
- Presupuesto B: mismo `week_start_date`, label "Sueldo 17
  Optimista", 2 items.
- Plantilla T: creada desde A.

Setup widget tests (harness):

- BD sembrada con seedDefaults + Bolsa (por default de
  pumpFincoreApp).
- Opcional: seed extra de 1 budget para tests que requieren datos.

## Comandos o validaciones locales sugeridas

```bash
cd mobile
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter analyze
flutter test
flutter build apk --release --split-per-abi
bash ../scripts/verify-apk.sh
```

## Criterios minimos para aprobar la implementacion

- Los 22 RF de la spec implementados.
- Todos los UT y WT del test-plan verdes.
- `flutter analyze` limpio (0 errores; hints info preexistentes
  aceptables).
- `flutter test` full suite verde (591 previos + los nuevos).
- APK release build OK, `verify-apk.sh` OK con versionCode 2094 /
  versionName 0.20.0.
- Sin regresión en `EntriesDao`, `AccountsDao`,
  `FinancialStateService`, `ReportsService`, dashboard, reportes,
  backup roundtrip.
- Copy destructivo en los dialogs de eliminación verificado
  literal.
- Snapshot semántico en plantillas verificado por dirección (edit
  template no cambia budget derivado; edit budget no cambia
  template origen).
- FAQ del `HelpScreen` incluye advertencia sobre backup.

## Validacion final recomendada

Ejecutar `branch-quality-review` con slug
`flutter-weekly-budgets-v1` antes del commit final. El reporte
queda en `engineering/quality-review/flutter-weekly-budgets-v1/`.

Si `branch-quality-review` no está disponible, checklist manual
equivalente:

- Verificar `store_date_time_values_as_text` respetado.
- Verificar `PRAGMA foreign_keys = ON` activo.
- Verificar cascade FK en `weekly_budget_items.budget_id` y
  `budget_template_items.template_id`.
- Verificar `ON DELETE SET NULL` en `category_id` de items
  (S-01) — consistente con `journal_entries.category_id`.
- Verificar `readsFrom` en todos los streams reactivos.
- Verificar transacciones en `reorderItems` y snapshot copies.
- Verificar tests de snapshot cover ambas direcciones.
- Verificar copy exacto de los dialogs destructivos.
- Verificar A11Y del drag handle (touch target ≥ 44 px).
- Verificar wipeAll extendida y test de regression.
- Verificar bump de schemaVersion + guardrail
  `UnimplementedError`.
