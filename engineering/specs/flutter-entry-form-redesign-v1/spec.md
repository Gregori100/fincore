# Rediseño del entry form (Sprint 3 — Entry form redesign)

## Resumen

Sprint 3 del roadmap de la auditoría de diseño 2026-07-14. Rediseña el flujo más frecuente de la app (el registro de movimientos) atacando 4 fricciones diarias: amount input sin hero, fecha sin quick-chips, KindPicker excesivamente vertical, y CategoryPicker con patrón desktop. Bump esperado `0.21.1+98` → `0.22.0+99` (minor por feature de UX visible).

## Problema a resolver

El entry form (`mobile/lib/screens/entry_form_screen.dart` + `mobile/lib/widgets/kind_picker.dart` + `mobile/lib/widgets/category_picker.dart` + su llamador `mobile/lib/widgets/date_field_outlined.dart`) tiene 4 problemas de UX documentados en la auditoría (Entries P1.2/P1.3/P1.4/P2.7):

1. **Amount enterrado**: el `TextFormField` de monto es visualmente idéntico al de "Descripción", ubicado tras 1-2 `AccountPicker` full-width. Sin formato de miles, sin prominencia, sin autofoco, y `FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))` acepta múltiples puntos (`1.2.3` pasa el formatter y `double.tryParse` devuelve `null`, con submit silencioso en línea 324).
2. **Fecha sin acceso rápido**: el patrón actual es `InkWell → InputDecorator → showDatePicker`; para cambiar a "ayer" son 4 taps + modal grande. En un flujo diario donde el 90% de los movimientos son de hoy o ayer, es fricción real.
3. **KindPicker consume la pantalla**: 5 kinds apilados como cards full-width (~66dp cada uno), total ~330dp + paddings — casi toda la pantalla útil de un Pixel 6a. En pantallas ≤5" hay scroll. Diego elige `expense` ~80% del tiempo.
4. **CategoryPicker anti-patrón mobile**: `DropdownMenu` M3 con altura máx 320dp, sin search, sin agrupación, con `leadingIcon` coloreado + texto plano (rompe el `CategoryBadge` chip que usa el resto de la app). No escala a 20-50 categorías.

Además (audit P2.6): el `TextButton.icon "Cambiar tipo (Gasto)"` en el header del form es affordance secundaria escondida; y (audit P3.6) `lastDate: DateTime.now().add(365d)` permite fechas futuras arbitrarias sin caso funcional real.

## Objetivo

Rediseñar el entry form para que la captura diaria sea más rápida, expresiva y visualmente coherente con la percepción de calidad esperada de una libreta financiera personal:

1. Amount como hero visual (32-40sp, color por kind, formato de miles en vivo, autofoco).
2. Quick-chips de fecha (Hoy/Ayer/Anteayer/Otro) que reducen 4 taps a 1.
3. Botón "Guardar" también en AppBar (además del footer) para evitar scroll con teclado abierto.
4. KindPicker en grid compacto 2×3 (~160dp de altura vs 330dp).
5. CategoryPicker como bottom sheet con search-first + `CategoryBadge` completo + agrupación por `appliesTo` cuando corresponde.
6. Chip prominente "Cambiar tipo" al top con confirm dialog si hay datos ingresados.

Cero cambios de dominio, cero schema, cero regresión funcional.

## Alcance

### Amount hero (`entry_form_screen.dart`)

- Ubicación: al top del form (tras el chip "Cambiar tipo"), antes de los `AccountPicker`.
- Widget nuevo `_AmountHero` (privado del screen o extraído si aplica) que envuelve el `TextField` con:
  - `TextStyle` inline con `fontSize: 36`, `fontWeight: w700`, `color: _amountColor(kind)`, `fontFeatures: [FontFeature.tabularFigures()]`. **Marcado con `// token-exception:` en el archivo con justificación (`fontSize: 36` fuera de escala tipográfica; hero único de la app)**. NO agregar token global en este sprint.
  - Prefix `$` inline con opacidad reducida (`textMuted` o `alphaTint`).
  - `autofocus: true` cuando `_isEdit == false`.
  - `keyboardType: TextInputType.numberWithOptions(decimal: true)`.
- Formatter robusto `_AmountInputFormatter extends TextInputFormatter`:
  - Reemplaza el `FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))` actual.
  - Acepta dígitos, un solo separador decimal (`.` o `,`), máx 2 decimales.
  - Regex de validación del nuevo valor: `^\d*[.,]?\d{0,2}$`.
  - Formato en vivo: para la parte entera, insertar separadores de miles (`,`) — output visual `1,234.56` o `1,234` sin decimales.
  - Internamente el `_amountCtrl.text` almacena el valor formateado; al submit se limpia con regex `str.replaceAll(',', '')` y luego `double.parse` sobre string canónico con `.` como decimal.
- `_amountColor(JournalKind kind)`:
  - `income` → `positive`.
  - `expense` → `negative`.
  - `creditExpense` → `warning`.
  - `debtPayment` → `accent`.
  - `transfer` → `accent`.
- Fix del edit hydration: `_amountCtrl.text = _formatInitialAmount(item.entry.amount)` (helper que devuelve `"1,234"` o `"1,234.56"` sin `.0` colgando).
- Submit: si el parse falla (edge extremo), mostrar `showWarningSnackbar(context, 'El monto no es válido.')` en vez de silenciar (línea 324 actual).

### Quick-chips de fecha (`entry_form_screen.dart` + posiblemente helper nuevo)

- Nuevo widget `_DateQuickPicker` privado del screen que renderiza 4 chips M3 (`ChoiceChip` o `FilterChip` single-select):
  - `Hoy` (default en modo alta), `Ayer`, `Anteayer`, `Otro…`.
  - `_occurredAt` para cada uno: hora normalizada a **`12:00:00` (mediodía)** para orden estable.
  - Chip seleccionado con `selectedColor: accent.withValues(alpha: alphaSelected)`.
  - "Otro…" al tap abre `showDatePicker` (existing) con `lastDate: DateTime.now()` (elimina el año en el futuro).
  - Debajo del row de chips, línea sutil (`overline` con `textMuted`): `"Sábado, 12 jul 2026"` mostrando la fecha efectiva actual del form.
- El `_DateFieldOutlined` widget compartido queda intacto (puede seguirse usando en otros sitios).
- En modo edición, el `_occurredAt` inicial se compara con hoy/ayer/anteayer:
  - Si matchea uno, se selecciona ese chip.
  - Si no matchea, se selecciona `Otro…` implícitamente y el label bajo el row muestra la fecha original.

### Botón "Guardar" en AppBar (`entry_form_screen.dart`)

- `AppBar.actions: [TextButton('Guardar', onPressed: _saving ? null : _submit)]`.
- Style: `foregroundColor: accent`, `textStyle: bodyM.copyWith(fontWeight: w700)`.
- Mantiene el `FilledButton` al pie (redundancia esperada; algunos usuarios lo esperan al final del scroll).
- El label del AppBar action es "Guardar" en alta y "Guardar cambios" en edit (opcional, alinear con el FilledButton del pie o simplificar a "Guardar" siempre — decidir en implementación).

### KindPicker grid compacto 2×3 (`mobile/lib/widgets/kind_picker.dart`)

- Refactor total del widget:
  - `GridView.count(crossAxisCount: 2, mainAxisSpacing: kSpaceSm, crossAxisSpacing: kSpaceSm, childAspectRatio: 1)` — 2 columnas, tiles cuadrados ~160×160dp en 360dp (o similar).
  - **5 tiles** distribuidos en 3 filas: fila 1 (Gasto | Ingreso), fila 2 (Cargo a tarjeta | Pago de tarjeta), fila 3 (Transferencia centrado en col 1 con `crossAxisCount: 2` puede requerir `Row` extra o `GridView` con 6 tiles usando el 6to como espacio vacío o card explicativo).
  - Cada tile: `_KindTile` (privado o extraído):
    - `AnimatedContainer` con `duration: kMotionFast`, `curve: kCurveEmphasized`.
    - Ícono grande centrado (32dp `Icon`) en `_kindColor`.
    - Label debajo (`bodyS.copyWith(fontWeight: w600)`).
    - Cuando seleccionado: fill `_kindColor.withValues(alpha: alphaTint)`, border 2px `_kindColor`, ícono con color al 100%.
    - Cuando no seleccionado: fill `surface`, border 1px `border`, ícono con color al 70% (o `textMuted`).
    - `InkWell` con `borderRadius: kRadiusMd`.
- **Descripción** del kind seleccionado: no dentro del tile, sino en una línea `bodyS` textMuted debajo del grid (dinámica; cambia al tocar otro tile). Ejemplo: `"Cargo a tarjeta desde otra cuenta"`.
- Preservar API pública del widget (`value`, `onChanged`, `enabled`). Los call sites (`entry_form_screen.dart`) no deben cambiar.
- Reemplazar la lista de 5 opciones con orden semántico: `[expense, income, creditExpense, debtPayment, transfer]` — gasto e ingreso primeros porque son los más comunes.

### CategoryPicker como bottom sheet (`mobile/lib/widgets/category_picker.dart`)

- Refactor total del widget. Nuevo API:
  - Widget compacto tipo `CategoryPickerField` que renderiza un `InkWell + Container` con:
    - Si `selectedId != null`: `CategoryBadge` completo (mismo componente del resto de la app) + `chevron_right`.
    - Si `selectedId == null`: label `"Sin categoría"` en `textMuted` + `chevron_right`.
    - Al tap: `showModalBottomSheet` con el sheet nuevo.
  - El `label` del field (título arriba tipo `overline`) sigue siendo `"Categoría (opcional)"`.
- Nuevo `_CategoryPickerSheet`:
  - `showModalBottomSheet<String?>` con `isScrollControlled: true`, `useSafeArea: true`, `showDragHandle: true`, `backgroundColor: FincoreColors.surface`, `shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(kRadiusXl)))`.
  - Padding: `EdgeInsets.only(left: kSpaceLg, right: kSpaceLg, top: kSpaceXs, bottom: media.viewInsets.bottom + media.viewPadding.bottom + kSpaceXl)`.
  - Estructura:
    1. Search `TextField` (autofocus solo si `_categories.length > 12`).
    2. Row: `"Sin categoría"` como opción con `Icons.block_outlined` + tap devuelve `null`.
    3. Divisor.
    4. Si `validAppliesTo` incluye `income` + `expense` (kind `both` o mixto): headers `overline` con `"Ingreso"`, `"Gasto"`, `"Ambos"`. Si `validAppliesTo` es un subset (kind puro income o puro expense): sin headers.
    5. MRU en memoria (`static final List<String> _sessionMRU = []`): las últimas 3-5 categorías tocadas van al tope de la lista visible con label `"Recientes"` (`overline`), solo si hay ≥2 elementos.
    6. `ListView` con `ListTile` por categoría filtrada:
       - `leading: CategoryBadge(compact: true, category: c)`.
       - `title: Text(c.name, style: bodyM)`.
       - Tap: devuelve `c.id` al `Navigator.pop(ctx, c.id)`.
- El caller (`entry_form_screen.dart:_CategoryPicker`) usa `await showModalBottomSheet(...)` y al recibir el valor actualiza `_categoryId`. Compatible con el `_categoryTouched` flag existente (sugerencia de categoría no se pisa hasta que el usuario elige manualmente).

### Chip "Cambiar tipo" al top (`entry_form_screen.dart:_buildForm`)

- Reemplaza el `TextButton.icon "Cambiar tipo (Gasto)"` (~línea 586-597) por un `_KindChipHeader`:
  - Container con `padding: kEdgeListItem`, `decoration: BoxDecoration(color: _kindColor.withValues(alpha: alphaTint), borderRadius: BorderRadius.circular(kRadiusMd))`.
  - `Row`: `Icon(_kindIcon, color: _kindColor)` + `Text('Gasto', style: bodyM.copyWith(fontWeight: w700, color: _kindColor))` + `Spacer` + `TextButton('Cambiar', onPressed: _promptChangeKind)`.
  - Solo en modo alta (no en edit — el kind es inmutable en edit por RN-011, ya está bloqueado).
- `_promptChangeKind()`:
  - Si el form tiene datos (`_amountCtrl.text.isNotEmpty || _originId != null || _destinationId != null || _descriptionCtrl.text.isNotEmpty`), mostrar `showConfirmDialog(context, title: 'Cambiar tipo?', message: 'Los datos ingresados se perderán.', confirmLabel: 'Cambiar', destructive: false)`.
  - Si confirma o el form está vacío, `Navigator.pop(context)` para volver al `KindPicker` inicial (o setear estado interno según cómo esté hoy la navegación entre KindPicker y form).

## Fuera de alcance

- Long-press en `MovementRow` → sheet contextual (duplicar/eliminar/cambiar categoría).
- Sticky day headers en la lista `/entries`.
- Autocomplete de descripciones previas basado en histórico.
- Header con totales del rango en la lista de movimientos.
- Migración masiva de todas las screens a los tokens de diseño del Sprint 1. Solo se migran los archivos que este sprint toca: `entry_form_screen.dart`, `kind_picker.dart`, `category_picker.dart`. Los demás screens quedan para sprints por módulo.
- CategoryPicker con acción "Crear categoría inline". Diferido a Sprint 6 (Component library) donde puede resolverse con un patrón compartido.
- Rediseño del snackbar (audit P3.3 con `surfaceElevated` + borde lateral). Sprint 6.
- Refactor del `_typeColor` en `dashboard_screen.dart` para liberar `warning` del tipo `credit` (regla de CLAUDE.md). Queda para Sprint 4 (Dashboard clarity).

## Reglas de negocio

Sprint sin cambios de dominio. Reglas de UX:

- **Amount hero color por kind**: `income → positive`, `expense → negative`, `creditExpense → warning`, `debtPayment/transfer → accent`. Justificación: los últimos 2 son movimientos "internos" (no cambian BO), color neutral. El `creditExpense` es cargo a tarjeta (aumenta deuda) — mantener `warning` es aceptable aunque la regla de CLAUDE.md diga que warning no debe usarse para tipos de cuenta; aquí es para tipo de kind, no tipo de cuenta. Documentar la distinción en el diff.
- **Amount formato en vivo**: durante el tipeo, el valor se muestra con separadores de miles. Al leer del controller para submit, se normaliza a `double` sin comas.
- **Fecha default en alta**: `DateTime.now()` normalizado a mediodía (12:00). Los quick-chips setean con la misma normalización.
- **Fecha en edit**: `_occurredAt` inicial se preserva; los chips reflejan la fecha original (matchea Hoy/Ayer/Anteayer si aplica, o "Otro" si es anterior).
- **KindPicker orden**: expense, income, credit_expense, debt_payment, transfer — de más común a menos común según uso real.
- **CategoryPicker MRU**: solo en memoria durante la sesión, no persiste entre restart de la app. Se pierde al cerrar. Aceptado en este sprint; persistencia se evalúa después.
- **CategoryPicker "Sin categoría" siempre al top**: no participa en la filtración del search, siempre visible en su sección propia.
- **Guardar en AppBar**: siempre visible (no scrollea), da acceso al submit sin cerrar teclado.

## Requisitos funcionales

- **RF-001**: el amount se renderiza como widget hero al top del form (tras el chip "Cambiar tipo") con `fontSize: 36`, `fontFeatures: tabularFigures()`, color según `_amountColor(kind)`, prefix `$` inline.
- **RF-002**: `_AmountInputFormatter` acepta solo strings que matcheen `^\d*[.,]?\d{0,2}$` post-transformación de comas de miles. `1.2.3` es rechazado en tiempo real (no llega al controller).
- **RF-003**: en modo alta, el amount tiene `autofocus: true`. En modo edit, foco al primer campo diferente al amount (respeta el patrón de focus preservation ya implementado).
- **RF-004**: al abrir edit, `_amountCtrl.text` muestra el amount formateado con miles y sin `.0` colgando (`1000` → `"1,000"`, `1500.5` → `"1,500.50"`).
- **RF-005**: si el submit falla por amount inválido (`double.tryParse` devuelve `null` sobre el valor normalizado), se muestra `showWarningSnackbar(context, 'El monto no es válido.')`.
- **RF-006**: nuevo widget `_DateQuickPicker` con 4 chips `[Hoy] [Ayer] [Anteayer] [Otro…]`. Setean `_occurredAt` normalizado a 12:00. "Otro…" abre `showDatePicker` con `lastDate: DateTime.now()`.
- **RF-007**: bajo el row de chips, línea `overline` con `textMuted` muestra la fecha efectiva formateada en `es_MX`. Ejemplo: `"Sábado, 12 jul 2026"`.
- **RF-008**: `AppBar.actions` incluye `TextButton('Guardar')` (o "Guardar cambios" en edit) que dispara `_submit`. Se deshabilita mientras `_saving == true`.
- **RF-009**: `KindPicker` refactorizado a `GridView.count(crossAxisCount: 2)` con tiles cuadrados. 5 kinds en orden `[expense, income, creditExpense, debtPayment, transfer]`. Tile seleccionado con fill `_kindColor.withValues(alpha: alphaTint)` + border 2px `_kindColor`. Debajo del grid, línea `bodyS textMuted` con descripción del kind seleccionado.
- **RF-010**: `CategoryPicker` refactorizado. El caller ve un `CategoryPickerField` compacto (chip actual + chevron); al tap se abre `showModalBottomSheet` con search + "Sin categoría" fija + MRU en memoria + agrupación por `appliesTo` (si `validAppliesTo` es mixto) + lista de `ListTile` con `CategoryBadge` completo.
- **RF-011**: chip "Cambiar tipo" al top del form en modo alta. `showConfirmDialog` si el form tiene datos antes de disparar el cambio.
- **RF-012**: `pubspec.yaml` bumpea a `0.22.0+99`. `build.gradle.kts` `versionCode = 99`, `versionName = "0.22.0"`.
- **RF-013**: `flutter analyze` en 0 errores. `flutter test` en 681+ verdes (los previos se adaptan al nuevo layout donde corresponda).

## Casos principales

**Caso 1** (alta rápida): tap FAB → KindPicker grid (default `expense` puede sugerirse o requerir tap) → tap "Gasto" → form abre con chip "Gasto" arriba, amount hero con foco, chip "Hoy" seleccionado. Usuario tipea `500`, tap AccountPicker → Bolsa, tap "Guardar" en AppBar. 4 taps + tipeo del monto.

**Caso 2** (registro atrasado): mismo flujo, pero al llegar al form usuario tap "Ayer" → fecha se setea a ayer 12:00. Sin abrir modal.

**Caso 3** (edición): navegación a `/entries/:id/edit`. Amount muestra `"1,234.50"` (no `"1234.5"`). Chip fecha refleja la original. Kind es visible pero bloqueado (edit no permite cambiar kind por RN-011).

**Caso 4** (cambio de kind con datos): en alta, usuario elige "Gasto" y tipea monto. Cambia de opinión, tap "Cambiar" → confirm dialog "Los datos se perderán" → confirma → vuelve al KindPicker.

**Caso 5** (búsqueda de categoría): con 30 categorías, usuario tap CategoryPicker → sheet abre → tipea "Com" → lista filtra a "Comida", "Comida rápida", "Combustible" → tap "Comida" → sheet cierra → chip actualizado en el field.

## Casos borde

**Borde 1**: usuario tipea `1,` (con coma) — el formatter debe aceptarlo como estado intermedio (parte entera `1`, decimal en progreso) y no borrar la coma. Similar con `1.`.

**Borde 2**: usuario tipea `1,000,000` — separadores múltiples aceptados. Al submit se normaliza a `1000000.00`.

**Borde 3**: usuario tipea `1.234.56` (error tipográfico: `.` en vez de `,` para miles) — el regex `^\d*[.,]?\d{0,2}$` NO permite dos separadores. El formatter rechaza el input y el controller queda en el último estado válido (`1.234.5` no aceptado; `1.23` sí).

**Borde 4**: paste desde clipboard con string inválido (`"$1,234.56 pesos"`) — el formatter debe filtrar y quedar con `"1,234.56"`. Si es complicado, aceptar solo el subset limpio o mostrar warning.

**Borde 5**: amount hero con overflow visual (`"999,999,999.99"` en 36sp en 360dp) — el `TextField` debe permitir horizontal scroll interno (por default lo hace). No cortar.

**Borde 6**: fecha "Anteayer" hoy es 2026-07-12 → chip setea 2026-07-10 12:00. Si el usuario navega la app cuando cambia el día (edge del auto-refresh de medianoche), los chips no se recalculan hasta que el widget rebuild. Aceptable.

**Borde 7**: edit de un movimiento de hace 6 meses — ningún chip Hoy/Ayer/Anteayer matchea. Chip "Otro…" queda seleccionado con label mostrando la fecha original.

**Borde 8**: `Guardar` en AppBar mientras el formulario tiene validation error (nombre vacío, monto 0) — igual dispara `_submit`, que corre los validators. `showWarningSnackbar` con el primer error.

**Borde 9**: `KindPicker` con 5 kinds en 3 filas (2+2+1) — el 5to tile queda solo en la fila 3. Alternativas: centrar el tile 5 en la fila (con `Row` extra fuera del grid), o `GridView` con 6 elementos donde el 6to es un `SizedBox.shrink()` decorativo. **Elección**: fila 3 con 2 tiles (Transferencia + tile vacío/informativo). Documentar en implementación.

**Borde 10**: `CategoryPicker` sheet con teclado abierto (por el search) — el padding bottom incluye `viewInsets.bottom` para no quedar tapado. Aprendizaje del sprint weekly-budgets.

**Borde 11**: `CategoryPicker` con 0 categorías activas — el sheet muestra "Sin categoría" y un mensaje `bodyM` `"No hay categorías activas. Crea una desde Settings → Categorías."` con CTA opcional para navegar. En este sprint solo el mensaje sin CTA (crear inline es Sprint 6).

**Borde 12**: MRU en el CategoryPicker — si el usuario elige la misma categoría 5 veces consecutivas, aparece 1 vez en MRU (no duplicada). El array se mantiene con `Set` internamente + orden LRU.

**Borde 13**: chip "Cambiar tipo" en edit — no se renderiza (kind inmutable en edit). Reemplazado por un pill informativo `"Gasto (no editable)"` con `textMuted`.

**Borde 14**: tests widget existentes del entry form matchean el layout viejo (KindPicker vertical, TextField de amount plano, DropdownMenu de categoría). Se actualizan al nuevo layout. Documentar en `decisiones-implementacion.md` cada test tocado.

**Borde 15**: `AmountFormatter` string helper existente en `mobile/lib/widgets/amount_formatter.dart` es puro string (`formatAmount`, `formatAmountCompact`). El nuevo `_AmountInputFormatter` es un `TextInputFormatter`. Distintos artefactos, no colisión. El formatter helper string sigue usándose en el resto de la app.

## Criterios de aceptacion

- `entry_form_screen.dart` renderiza al top el `_KindChipHeader` (alta) + `_AmountHero` (36sp) + `_DateQuickPicker`. El orden visual es: chip kind → amount → date chips → AccountPicker(s) → descripción → CategoryPicker.
- `kind_picker.dart` renderiza un `GridView.count(crossAxisCount: 2)` con 5 tiles (última fila con 1-2 tiles según decisión de borde-9).
- `category_picker.dart` expone un `CategoryPickerField` compacto que abre un `showModalBottomSheet` con search + "Sin categoría" fija + MRU + agrupación cuando aplica.
- Amount input:
  - Rechaza `1.2.3` en tiempo real (no llega al controller).
  - Formatea con miles en vivo (`1000` → `"1,000"`).
  - En edit hydration: `1500.5` → `"1,500.50"`.
  - Al submit con amount inválido: `showWarningSnackbar`.
- Fecha:
  - 4 chips visibles.
  - Tap "Hoy" setea `_occurredAt` = `DateTime(now.year, now.month, now.day, 12)`.
  - "Otro…" abre picker con `lastDate: DateTime.now()`.
- AppBar tiene `TextButton('Guardar')` en actions (o "Guardar cambios" en edit).
- Chip "Cambiar tipo" al tap con datos en el form: `showConfirmDialog` antes de cambiar.
- `flutter analyze`: verde (0 errores nuevos, 3 hints info pre-existentes tolerados).
- `flutter test`: 681+ verdes. Los tests que matcheaban el layout viejo se actualizan y documenan.
- `pubspec.yaml`: `0.22.0+99`. `build.gradle.kts`: `versionCode = 99, versionName = "0.22.0"`.

## Criterios medibles de exito

- **Taps para captura estándar** (alta expense de $500 con cuenta Bolsa y fecha hoy): de ~7-8 actuales a **≤5** (kind → tap tile → amount tipea → account tap → Guardar).
- **Tiempo estimado** para captura estándar: subjetivo, mejora percibida en smoke.
- **Amount input formato**: el 100% de los inputs válidos se muestran con separadores de miles.
- **Inputs inválidos silenciosos** (`1.2.3`, string vacío): **0** — todos generan feedback visible (snackbar o rechazo del formatter).
- **KindPicker altura visual**: de ~330dp actual a **≤180dp** (grid 2×3 con 80×80).
- **CategoryPicker escalabilidad**: con 20+ categorías, el usuario debe poder encontrar cualquiera en ≤2 taps + tipeo. Hoy es scroll manual sin search.
- `flutter analyze` en 0 errores.
- `flutter test` en 681+ verdes con matchers actualizados.

## Riesgos

- **R-01**: el formato en vivo con separadores de miles puede introducir bugs sutiles (cursor position, undo/redo, IME behavior). Mitigación: usar un helper testeado (`intl` NumberFormat + manejo de cursor). Si aparecen bugs raros, versión conservadora sin separador de miles en vivo (solo al submit).
- **R-02**: `fontSize: 36` es una excepción documentada al sistema de tokens del Sprint 1. Si aparecen más hero grandes en sprints siguientes (Dashboard, Reports), evaluar crear `displayS` o `displayM` en `fincore_typography.dart`.
- **R-03**: `KindPicker` con 5 tiles en 3 filas (2+2+1) puede verse asimétrico. Mitigación: probar 2+2+1 vs 3+2 (crossAxisCount=3) y elegir el que se vea mejor. Si 3+2 gana, ajustar la spec.
- **R-04**: `CategoryPicker` bottom sheet con muchas categorías (50+) puede ser lento si el filter recorre la lista completa por cada keystroke. Optimización trivial: filtrar sobre una lista pre-computada de tuplas `(id, lowerName)`. Sin index externo.
- **R-05**: MRU en memoria se pierde al cerrar la app. Si el usuario espera persistencia, decepciona. Aceptado; documentado en `pendientes.md` para evaluar persistencia después.
- **R-06**: chip "Cambiar tipo" con confirm dialog puede ser fricción si el usuario cambió por error de kind muy temprano (sin datos). Mitigación: dialog solo si hay datos.
- **R-07**: tests widget del entry form son varios (entry_form_screen_test, entry_form_kinds_test, entry_form_suggestion_test). Cambio grande de layout requiere actualizar todos. Riesgo de regresión por matcher desactualizado. Mitigación: correr suite completa post-implementación; ajustar cada matcher documentado.
- **R-08**: cambio del `TextField` a un `TextField` con estilo hero puede afectar el `focus preservation` implementado en el sprint anterior (WidgetsBindingObserver + SystemChannels.textInput). Mitigación: verificar que el patrón sigue funcionando.

## Supuestos

- El sistema de tokens del Sprint 1 (`fincore_typography.dart`, `fincore_spacing.dart`, `fincore_radii.dart`, `fincore_motion.dart`, `fincore_colors` extendido) es la única fuente de estilos para los widgets nuevos, excepto la excepción documentada del `fontSize: 36` del hero.
- El copy nuevo (labels de chips, mensajes de snackbar, tooltip del kind) es español neutral. El guardrail del Sprint 2 lo blindea.
- No hay nuevas dependencias externas. Todo se logra con `intl` (ya en el proyecto) y widgets estándar de Flutter.
- El `NumberFormat.decimalPattern('es_MX')` de `intl` produce `"1,234.56"` (coma miles, punto decimal). Verificar en implementación; si el patrón MX usa `"1.234,56"` (punto miles, coma decimal), ajustar la lógica del formatter.
- El `AmountFormatter` existente (`mobile/lib/widgets/amount_formatter.dart`) es puro string y no colisiona con el nuevo `_AmountInputFormatter`.
- Los 3 widgets a refactorizar (`kind_picker`, `category_picker`, `entry_form_screen`) tienen consumidores conocidos: entry form (principal), edit (mismo screen), y CategoryPicker se usa también en `mobile/lib/screens/weekly_budgets/widgets/budget_item_form_sheet.dart`. Verificar en implementación que el nuevo API es retrocompatible con weekly budgets (que sigue usando el widget).
- La MRU en memoria vive en `static final List<String> _sessionMRU = []` dentro del `_CategoryPickerSheet` — se comparte entre invocaciones porque es static. Sin isolate issues (single-user app single-process).
- El bump patch (0.22.0) es apropiado. Si Diego prefiere `0.21.2+99` (patch), se ajusta al cierre.

## Impacto esperado

**Positivo**:
- El flujo más frecuente de la app se siente más rápido y elegante.
- Fricción diaria (fecha, monto) baja significativamente.
- KindPicker deja de ser un obstáculo visual.
- CategoryPicker escala a 30-50 categorías sin degradación de UX.
- Los tokens del Sprint 1 tienen su primer piloto en screens (no solo widgets).

**Negativo** (aceptado):
- Sprint grande con diff moderado en un archivo crítico (`entry_form_screen.dart`).
- Riesgo de regresión en tests que hay que actualizar.
- Cambios visuales perceptibles (amount hero, KindPicker grid, CategoryPicker sheet) — smoke visual necesario.

**Neutral**:
- `weekly_budgets/widgets/budget_item_form_sheet.dart` consume `CategoryPicker` — el refactor debe preservar el API público o ajustar el caller.
- Sin schema bump, sin migración de datos.
