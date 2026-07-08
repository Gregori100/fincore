# Branch quality review — flutter-reports-income-heatmap-v1

**Fecha:** 2026-07-09
**Slug del sprint:** `flutter-reports-income-heatmap-v1`
**Rama:** `main` (cambios sin commit sobre HEAD `c29fd82`)

## Alcance

Sprint aditivo puro. 11º tab "Heatmap ingresos" simétrico al 10º tab "Heatmap" (gastos) pero para `kind='income'` con paleta verde. Copia idiomática del `SpendingHeatmapTab` con reemplazos.

3 agentes en paralelo (2 Haiku + 1 Sonnet).

## Hallazgos por severidad

### Media — Comentario "sin gastos" quedó sin traducir en el income

**Archivo:** `mobile/lib/screens/reports/income_heatmap_tab.dart:150-152`

**Descripción:** El bloque de consolidación año vacío arrastra el comentario del spending: "el empty banner ya comunica 'sin gastos'" y "0 días con gasto". El código sí se refactorizó (`daysWithIncome`, banner con "Sin ingresos registrados"), pero el comentario contradice la semántica.

**Estado: RESUELTO (A2)** — traducido a "sin ingresos" y "0 días con ingreso".

---

### Media — Asimetría "Heatmap" vs "Heatmap ingresos"

**Archivo:** `mobile/lib/screens/reports_screen.dart:52-53`

**Descripción:** Los 2 tabs quedan adyacentes con labels `Heatmap` (gastos) y `Heatmap ingresos`. Al leerlos juntos el usuario infiere que el primero es "genérico" y el segundo es "solo ingresos", cuando en realidad ambos son específicos. Antes del sprint la etiqueta corta era razonable (era el único heatmap); ahora la simetría requiere nombrarlo explícitamente.

**Estado: RESUELTO (H3)** — renombrado el 10º tab a "Heatmap gastos". Actualizado en 4 lugares:
- `reports_screen.dart`: `Tab(text: 'Heatmap')` → `Tab(text: 'Heatmap gastos')`.
- `onboarding_screen.dart`: label `'Heatmap anual'` → `'Heatmap gastos'`.
- `help_screen.dart`: bullet `'• Heatmap anual: ...'` → `'• Heatmap gastos: ...'`.
- `spending_heatmap_tab_test.dart`: `find.widgetWithText(Tab, 'Heatmap')` → `'Heatmap gastos'`.

---

### Media — Gap CB-14 (cancelación reactiva del income)

**Archivo:** `mobile/test/data/reports_test.dart` (grupo `incomeHeatmap`)

**Descripción:** UT-IHM12 solo cubre **registrar** income con re-emit. **Cancelar** no está cubierto. Mismo gap que UT-HM11 del spending tampoco cubría.

**Estado: NO ACCIONAR** — cubierto lógicamente por el mismo `readsFrom: {journalEntries}` que dispara el registrar. TD arrastrado del sprint gastos que se aplica simétricamente. Riesgo bajo por la infraestructura común.

---

### Baja — Docstring de `ReportsScreen` desactualizado

**Archivo:** `mobile/lib/screens/reports_screen.dart:15-23`

**Descripción:** El docstring enumeraba solo 1-8. Faltan Calendario (9), Heatmap (10), Heatmap ingresos (11). TD arrastrado desde el sprint calendar.

**Estado: RESUELTO (A3)** — extendido con los 3 tabs faltantes. TD saldado.

---

### Baja — Typo `RN-IHM04/HM05` en docstring

**Archivo:** `mobile/lib/data/reports.dart:1500`

**Descripción:** Docstring de `incomeHeatmap` menciona `(RN-IHM04/HM05)` cuando debería ser `(RN-IHM04/IHM05)`. El prefijo del sprint es "IHM".

**Estado: RESUELTO (A1)** — fix 1 char.

---

### Baja — Mismo ícono `grid_view` para ambos heatmaps

**Archivo:** `mobile/lib/screens/onboarding_screen.dart:483-491`

**Descripción:** Los 2 rows del slide 3 usan `Icons.grid_view` diferenciados solo por color (negative/positive). Riesgo A11Y con daltonismo rojo-verde.

**Estado: NO ACCIONAR** — cosmético, Diego es single-user y no usa TalkBack. Registrable como TD si aparecen usuarios con esa necesidad en el futuro.

---

### Baja — Gap CB-21 (income con amount=0)

**Estado: NO ACCIONAR** — edge legacy muy raro. Cubierto lógicamente por `if (dayTotal <= 0) continue`. El equivalente en spending tampoco tenía test explícito.

---

### Baja — Gap CB-03 (2-3 incomes fallback)

**Estado: NO ACCIONAR** — redundante con UT-IHM02 (fallback con n=1). El path de código es idéntico para 1, 2 y 3 items.

---

### Baja — WT-IHM04 usa `.first` en `find.text('15')`

**Estado: NO ACCIONAR** — en el sheet expandido "15" aparece una sola vez. El `.first` es defensivo pero funciona correctamente.

---

### Notas positivas verificadas

- **Import cruzado `income → spending`** para `heatmapDayForMonthPosition`: sin ciclo (verificado). Acoplamiento aceptable como TD.
- **Reemplazo global `negative → positive`**: sin regresiones semánticas. El `_ErrorState.Icon` sigue en `negative` (correcto). Único uso de `negative` en el archivo del income.
- **Paridad SQL con spending**: verificada. Ambos usan `strftime('%Y-%m-%d', 'localtime')`, `readsFrom: {journalEntries}`, `_computeQuartiles`, mismo shape del helper.
- **21 tests nuevos**: 12 UT servicio + 5 UT modelo + 4 widget. Cobertura de 19/22 casos borde explícitos.

## Fixes aplicados antes del commit

| ID | Sev | Fix | Costo |
|---|---|---|---|
| A1 | Baja | Typo `RN-IHM04/HM05` → `RN-IHM04/IHM05` | 1 min |
| A2 | Media | Comentario `"sin gastos"` → `"sin ingresos"` | 1 min |
| A3 | Baja | Docstring ReportsScreen extendido con 3 tabs faltantes | 3 min |
| H3 | Media | Rename `"Heatmap"` → `"Heatmap gastos"` en 4 archivos | 5 min |

Total: ~10 min. Todos con impacto real de coherencia UX.

## Pruebas ejecutadas post-fix

- `flutter analyze` limpio (4 hints info pre-existentes tolerados).
- `flutter test` → **540/540 verdes** (519 baseline + 21 nuevos).
- Build APK release `--split-per-abi` OK.

## Recomendación de merge

**APTO PARA COMMIT** tras aplicar A1-A3 + H3. Los diferidos son cosméticos, TDs razonables o cubiertos lógicamente.

## Pendientes sugeridos para sprints futuros

- **Extraer `_heatmap_common.dart`** con `heatmapDayForMonthPosition`, `IntensityLevel` y `_colorForIntensity` compartido si aparece un 3er heatmap o se toca alguno.
- **Diferenciación de íconos A11Y** entre los 2 heatmaps si aparece usuario con daltonismo.
- **Sprint de tests defensivos** para cubrir CB-14/CB-21/CB-03 explícitamente si en un futuro se detecta regresión ahí.
