# Auditoría de diseño FinCore — Consolidado global

**Fecha**: 2026-07-14
**Alcance**: toda la app (8 auditorías paralelas, un módulo cada una + capa transversal).
**Auditor**: agente `mobile-designer` (rol lead designer mobile) sobre `general-purpose` (los 8 en paralelo, ~35 min total).
**Método**: cada agente auditó su módulo con el mismo marco (12 dimensiones + priorización P1/P2/P3/P4 + formato Markdown obligatorio).

---

## TL;DR global

FinCore ya tiene **fundamentos correctos** (paleta oklch documentada, semánticos con nombres, `DestructiveDialog` premium, `AmountFormatter` bien tokenizado, streams cacheados reactivos, guardrails de migración). Lo que impide que se sienta como producto de tier-1 son **tres deudas atravesando toda la app**:

1. **Falta de sistema de tokens ejercitado** — `textTheme` está definido pero nadie lo consume (95% `TextStyle` inline), 14 `fontSize` únicos, 13 `SizedBox` únicos, 9 radios, 13 alphas. Cada widget reinventa jerarquía. El synchronic effect es que la app se lee como "hecha por 5 personas" aunque técnicamente esté prolija.
2. **Español mixto** — hay voseo rioplatense (`pagás`, `configurá`, `probá`, `acotá`, `necesitás`) en al menos 4 módulos (Entries, Filters, Empty States, Monthly Average). Contradice frontalmente la regla de memoria del 2026-07-14 (`feedback_spanish_neutral.md`).
3. **Cada módulo reinventa loading/error/empty/período** — 5 variantes de skeleton, 3 de error, 3 de empty, 4 de header/período. La app "cambia de personalidad" al cambiar de tab. Un `ReportShell` + `EmptyState` + `LoadingState` compartidos resolverían ~500 líneas duplicadas y darían una lectura uniforme.

Además hay **oportunidades altas de percepción de valor** por módulo — la más urgente: **el monto en el entry form no es hero** (el flujo más frecuente de toda la app tiene el input más importante enterrado tras 2 pickers full-width, sin formato de miles, sin prominencia visual, con formatter que acepta `1.2.3`).

**Volumen total**: 25 P1 (críticos) · 44 P2 (alto impacto) · 46 P3 (refinamiento) · 30 P4 (ideas).

---

## Hallazgos sistémicos (patrones que se repiten en varios módulos)

Estos son los **verdaderos temas transversales** — cada uno aparece en ≥3 auditorías. Atacarlos rinde beneficio multiplicado.

### S1 — Ausencia de sistema de tokens tipográficos
**Aparece en**: Sistémico (P1), Dashboard (Ideas transversales), Categorías (contra P2), Entries (implícito en P3.5).
**Diagnóstico**: `textTheme` bien definido pero 226 `TextStyle` inline con 14 `fontSize` distintos. La escala 10/11/12/13/14/15/16/18/20/22/26/56/72 no comunica jerarquía — comunica azar.
**Acción**: crear `mobile/lib/theme/fincore_typography.dart` con 7 tokens semánticos (`displayXL / headingL / headingM / bodyM / bodyS / label / overline`), cablearlos al `textTheme`, y migrar por oleadas (widgets compartidos primero).

### S2 — Ausencia de sistema de tokens de spacing
**Aparece en**: Sistémico (P1), Weekly Budgets (varios), Settings (P2.6).
**Diagnóstico**: 16 valores de `EdgeInsets` únicos, 12 de `SizedBox`. `EdgeInsets.fromLTRB(16, 16, 16, 96)` copiado en 16 archivos.
**Acción**: `mobile/lib/theme/fincore_spacing.dart` con 6 tokens (`2xs/xs/sm/md/lg/xl/2xl`) + semánticos derivados (`kEdgeCard`, `kEdgeScreen`, `kEdgeDialog`).

### S3 — Español neutral roto
**Aparece en**: Entries (P1.1, catalogado), Reports (P2.7), Weekly Budgets (implícito).
**Diagnóstico**: `pagás`, `configurá`, `probá`, `acotá`, `necesitás`, `registrá`, `pediste` — todos voseo rioplatense. Contradicen `feedback_spanish_neutral.md`.
**Acción**: `grep -rE '\b(pagás|configurá|probá|acotá|poné|tocá|ingresá|guardá|elegí|hacé|deslizá|necesitás|registrá)\b' mobile/lib/` y arreglar. Agregar test que falle si aparecen.

### S4 — Cada módulo reinventa loading/error/empty
**Aparece en**: Reports (P1.2, el más severo), Entries (P2.2 empty), Weekly Budgets (H6), Dashboard (P2 streams sin error).
**Diagnóstico**: 5 variantes de "Cargando", 3 de "Error", 3 de "Empty" con paletas y componentes distintos.
**Acción**: extraer `LoadingState`, `ErrorState`, `EmptyState({icon, title, body, cta?})` compartidos. `Reports` merece además un `ReportShell` que combine header + período + estados.

### S5 — Pickers sin base compartida
**Aparece en**: Sistémico (P1-3), Categorías (P1-1 CategoryPicker), Entries (P2.7).
**Diagnóstico**: 8 pickers con 3 paradigmas visuales distintos (DropdownMenu / SegmentedButton / Cards con border). `AccountTypePicker` y `KindPicker` son gemelos visuales sin código compartido. `ColorPicker` usa border blanco 3px; `IconPicker` usa border accent 2px — misma pantalla.
**Acción**: `SelectableCard` compartido para pickers con descripción (Kind, AccountType). Convención documentada: `SegmentedButton` (≤3 opciones binarias) · `DropdownMenu` (opciones con search) · `SelectableCard` (opciones con metadata) · **bottom sheet con search-first** para category/account picker en flujos frecuentes.

### S6 — Convención destructiva incoherente
**Aparece en**: Sistémico (P3-1), Settings (P1.1, P1.2, P3.3), Accounts (P4).
**Diagnóstico**: `ConfirmDialog` y `DestructiveDialog` coexisten. El `DestructiveDialog` premium se usa en solo 3 lugares; el `ConfirmDialog` M2 se usa para las acciones **más destructivas** (import que reemplaza todo, reset de BD sin export). "Zona peligrosa" en Settings no se ve peligrosa.
**Acción**: (1) documentar en `CLAUDE.md`: reversible/bajo-impacto → `ConfirmDialog`; irreversible/alto-impacto → `DestructiveDialog`. (2) Migrar `_import` y `_resetWithoutExport` a `DestructiveDialog`. (3) `AlertCard` con `tone: warning|negative` para "Zona peligrosa" (border tinted, no card neutra).

### S7 — Iconografía mixta sin criterio
**Aparece en**: Sistémico (P2-2), Categorías (P4.6 flechas invertidas), Settings (P2.1), Dashboard (P3 credit=warning).
**Diagnóstico**: outlined/filled/rounded mezclados. `check_circle` vs `check_circle_outline`. Ingreso `arrow_downward` invertido para es_MX. Credit type pintado como `warning` (amarillo = "cuidado").
**Acción**: convención "outlined por default, filled solo para current/selected". Helper `AppIcons` con los 20 iconos canónicos. Invertir flechas en `AppliesToPicker`. Credit type = neutral (`textMuted` o color propio) — liberar `warning` para alertas operativas reales.

### S8 — Colisión `accent cyan` vs `categoryBlue` vs `positive/negative`
**Aparece en**: Sistémico (P2-1 alphas), Categorías (P1-2), Weekly Budgets (H3 en compare).
**Diagnóstico**: `positive #50CC8E == categoryGreen` (mismo hex). `negative #E05959 == categoryRed`. `accent #4CABDB` cerca de `categoryBlue #5A9AE0`. Compare de weekly budgets usa `accent` para delta positivo y `warning` para negativo — rompe la memoria muscular verde/rojo del resto.
**Acción**: (1) desaturar `categoryX` ~10-15% para separar del semántico. (2) Reservar `accent` para acciones/affordance; `positive/negative` para dinero; `categoryX` para taxonomía. (3) Escribir la regla en `CLAUDE.md`.

### S9 — Sin comparación temporal (MoM/YoY)
**Aparece en**: Reports (P2.5, dedicado), Dashboard (implícito), Accounts (P1 credit utilization con umbral).
**Diagnóstico**: la mayoría de reportes son fotos, no historia. La pregunta que trae al usuario a Reports casi nunca es "cuánto gasté" — es "¿estoy peor que antes?".
**Acción**: extraer `DeltaChip` (ya existe en cashflow breakdown) a widget compartido y usar en cada fila ranked, en credit_cards, en balance-at-date.

### S10 — Amount input débil (formato, jerarquía, quick-adds)
**Aparece en**: Entries (P1.2), Weekly Budgets (H8), Accounts (P2.5).
**Diagnóstico**: `TextField` estándar 56dp con `prefixText: '$ '`, sin separador de miles, sin quick-chips. Formatter `[0-9.]` acepta múltiples puntos. En edit, `double.toString()` da `1000.0`.
**Acción**: (1) `AmountInput` widget compartido con formato tabular en vivo, regex `^\d*\.?\d{0,2}$`, quick-add chips opcionales. (2) En entry form: promover a hero visual (32-40pt, color por kind, prominente al top).

---

## Top-15 hallazgos priorizados (backlog global)

Priorizados por impacto en el usuario × frecuencia de uso × facilidad de fix. Cada línea remite al reporte-fuente.

### P1 — Bloqueantes / críticos

1. **Amount input no es hero en entry form** — el input más importante de la app está enterrado, sin formato, sin prominencia. → Entries P1.2. **Impacto: máximo, es el flujo diario.**
2. **Español neutral roto** — `pagás/configurá/probá/…` en varios sitios. Contradice regla de memoria. → Entries P1.1 + Reports P2.7. **Impacto: alto, viola política vinculante.**
3. **KPIs BO/DE/CR en criptograma** — el dashboard grita códigos internos como label principal, el descriptor real está minimizado en 10px. → Dashboard P1. **Impacto: rompe primer contacto.**
4. **Import destructivo usa `ConfirmDialog` débil** — la acción con mayor blast radius parece "¿Guardar cambios?". → Settings P1.1. **Impacto: riesgo real de pérdida de datos.**
5. **11 tabs planos en Reports** — anti-patrón de descubrimiento; el usuario no aprende el mapa mental. → Reports P1.1. **Impacto: los reportes existen pero no se descubren.**
6. **Sistema de tokens tipográficos ausente** — 14 `fontSize`, 226 inline `TextStyle`, `textTheme` sin consumo. → Sistémico P1-1. **Impacto: multiplicador de todo lo demás.**
7. **Sistema de tokens de spacing ausente** — 12+ `SizedBox` únicos, 16+ `EdgeInsets`. → Sistémico P1-2. **Impacto: idem.**
8. **`CategoryPicker` inutilizable a escala** — DropdownMenu con 20+ opciones sin search, patrón desktop. → Categorías P1-1. **Impacto: fricción diaria en entry form.**
9. **BalanceFooter obliga aritmética mental** — muestra solo el neto, no ingresos+gastos. → Weekly Budgets H2. **Impacto: rompe la esencia del planeador.**
10. **Fecha sin quick-chips Hoy/Ayer** — el segundo campo más modificado del entry form exige DatePicker completo. → Entries P1.3. **Impacto: fricción diaria.**
11. **Lista de cuentas sin agrupación por tipo** — 3 tipos apilados sin section headers ni subtotales. → Accounts P1. **Impacto: pierde contexto y jerarquía.**
12. **"Esta semana" en Weekly Budgets sin tratamiento hero** — la sección crítica se ve igual que las demás. → Weekly Budgets H1. **Impacto: no comunica lo importante.**
13. **`_ProtectedView` de Bolsa es dead-end** — bloquear + no explicar + no ofrecer siguiente acción. → Accounts P2. **Impacto: fricción conceptual con la piedra fundacional del modelo.**
14. **First-run con dos opciones equivalentes en jerga** — "BD vacía con Bolsa singleton" filtra vocabulario de dev. → Dashboard P1 (first-run). **Impacto: primer contacto con jerga técnica.**
15. **Utilización de crédito sin visualización** — cards de credit muestran saldo/límite pero no % ni barra. → Accounts P1 (credit cards). **Impacto: métrica de riesgo #1 invisible.**

### P2 — Alto impacto

16. **`ReportShell` inexistente** — 5 variantes de loading, 3 de error, 3 de empty. → Reports P1.2 + Sistémico S4.
17. **`AccountBalanceHint` demasiado discreto** — su rol es prevenir errores, es visualmente insignificante. → Accounts P2.5.
18. **Copy "Metadata de la tarjeta"** — jerga de dev en form del usuario. → Accounts P2.
19. **Weekly Budgets compare rompe convención cromática** — accent/warning para deltas en vez de verde/rojo. → Weekly Budgets H3.
20. **Data-viz cashflow sin ejes/tooltips/línea net** — chart decorativo, no explorable. → Reports P2.3.
21. **`BaseCard` sin variantes semánticas** — 63 usos con overrides caso por caso, sin `InfoCard`/`ActionCard`/`AlertCard`. → Sistémico P1-4.
22. **Sparklines dashboard con escala independiente** — comparación imposible, transmite info falsa. → Dashboard P2.
23. **Ayuda es muro de 8 `ExpansionTile` sin índice/search** — no escala. → Settings P2.4.
24. **`CategoryBadge` amarillo con contraste borderline** — texto sólido yellow sobre fill 0.15 falla AA. → Categorías P3, Sistémico P3-2.
25. **Multi-select weekly budgets con doble descubribilidad frágil** — long-press oculto + menu overflow redundante. → Weekly Budgets H5.
26. **AppBar del dashboard denso, semánticas mezcladas** — 3 IconButtons + PopupMenu, iconos ambiguos. → Dashboard P2.
27. **`_TotalRow` de compare denso e inescaneable** — Text.rich con 3 números concatenados. → Weekly Budgets H4.
28. **CategoryPicker sin "crear inline"** — interrumpe flow del entry form. → Entries P2.7.
29. **Empty states sin diseño** — texto centrado en textMuted en varios lados. → Entries P2.2, Accounts P3, Dashboard P4.
30. **Botón guardar del entry form al fondo del ListView** — fuera de viewport con teclado abierto. → Entries P2.3.

### P3 — Refinamientos de sistema

31. **Motion sin filosofía** — solo skeleton y onboarding usan `Curves`; no hay `fincore_motion.dart`. → Sistémico P3-3.
32. **Snackbar sin swipe-to-dismiss + solapamiento con FAB** → Sistémico P2-3.
33. **Skeleton pulse casi imperceptible + 3 controllers por SkeletonCard** → Sistémico P2-4.
34. **`FontFeature.tabularFigures()` ausente fuera de credit_cards** — dígitos jittean en listas ranked. → Reports P2.6.
35. **`ColorPicker` viola touch target 44dp** (40dp). → Categorías P1-3.
36. **Iconografía cash/debit/credit con `warning` para credit** → Dashboard P3.
37. **Radios y alphas sin tokens** — 9 radios, 5 variaciones del mismo alpha "seleccionado". → Sistémico P2-1.
38. **Preferences dropdown crudo, no M3** — inconsistente con otros pickers de la app. → Settings P2.3.
39. **Descripción del entry form como campo residual** → Entries.
40. **AccountBalanceHint como texto plano, no chip visual** → Entries P3.4.

---

## Sugerencia de orden de sprints (roadmap)

Cada sprint es autocontenido y toma 2-4 días. Priorizados para maximizar ROI y desbloquear sprints siguientes.

### Sprint 1 — **Foundations** (habilitador de todo lo demás)
- Extraer `fincore_typography.dart` (7 tokens) + cablear `textTheme`.
- Extraer `fincore_spacing.dart` (6 tokens + semánticos derivados).
- Extraer `fincore_radii.dart` y `fincore_alphas.dart`.
- Extraer `fincore_motion.dart` (5 durations + 4 curves).
- Documentar convenciones en `CLAUDE.md` (outlined default, accent reservado, verde=positivo).
- Migrar `widgets/` compartidos como primer piloto (deja las screens para sprints siguientes).
- **Ganancia**: base para todo lo demás.

### Sprint 2 — **Language cleanup** (política + polish rápido)
- Audit `grep -rE '\b(pagás|configurá|probá|…)\b'` y purga total.
- Reemplazar copy "Metadata", "Zona peligrosa" (con tratamiento visual), "kinds", etc.
- Test que falle en CI si aparece voseo.
- **Ganancia**: coherencia + política respetada.

### Sprint 3 — **Entry form redesign** (el flujo diario)
- Amount como hero (formato tabular en vivo, regex estricto, color por kind, 32-40pt).
- Quick-chips fecha (Hoy/Ayer/Anteayer/Otro).
- Guardar en AppBar (además del footer).
- KindPicker grid compacto 2×3.
- `CategoryPicker` como bottom sheet con search-first + agrupación.
- Chip "Cambiar tipo" al top con feedback visual.
- **Ganancia**: mejor el flujo más frecuente. Impacto directo en uso diario de Diego.

### Sprint 4 — **Dashboard clarity** (primer contacto)
- Invertir jerarquía KPIs (descriptivo arriba, código como caption).
- First-run reescrito (arrancar limpio recomendado, copy sin jerga).
- Chips filtro dentro del grupo Movimientos (no entre secciones).
- Sparklines: escala compartida o quitarlos.
- Card de credit con barra de utilización.
- **Ganancia**: percepción de calidad al abrir la app.

### Sprint 5 — **Reports hub** (rediseño de arquitectura)
- Hub visual grid en `/reports` con preview micro por reporte.
- `ReportShell` compartido (header + período + estados).
- 3 componentes de período canónicos (`PeriodPresetBar`, `PeriodStepper`, `PeriodSheet`).
- Fusionar spending/income por categoría en tab único con toggle.
- DeltaChip global + tabular figures en todos los amounts.
- **Ganancia**: los reportes se descubren y comparan.

### Sprint 6 — **Component library** (unificación)
- `SelectableCard` compartido, refactor `AccountTypePicker` + `KindPicker`.
- `BaseCard` → `InfoCard` / `ActionCard` / `AlertCard`.
- `EmptyState` / `ErrorState` / `LoadingState` compartidos.
- `DeltaChip` extraído.
- `AmountInput` extraído para reusar en entry + weekly budgets.
- `showFincoreBottomSheet<T>` con safe area calculada.
- **Ganancia**: cierra el ciclo del sistema de diseño.

### Sprint 7 — **Weekly budgets polish** (elevar el módulo nuevo)
- Card "Esta semana" hero.
- BalanceFooter con Ingresos+Gastos visibles + copy humano.
- Compare con matriz alineada y semántica de dirección.
- Item form con Kind al top, monto con quick-adds.
- Calendar con leyenda + dot semántico.
- **Ganancia**: el módulo nuevo entra en producción con la percepción correcta.

### Sprint 8 — **Accounts + Categories polish**
- Lista de cuentas agrupada por tipo con subtotales.
- Bolsa detail screen (no dead-end).
- Utilización de crédito con barra.
- `CategoryPicker` (ya hecho en Sprint 3, aquí extender al catálogo mismo).
- Live preview del category form con contextos reales.
- IconPicker agrupado + search.
- **Ganancia**: los módulos CRUD suben a nivel producto.

### Sprint 9 — **Settings + Help refresh**
- Zona peligrosa con tratamiento visual (AlertCard).
- Reorden secciones (Ayuda antes de peligrosa).
- Import con `DestructiveDialog` + preview del payload.
- Ayuda con search + agrupación + deep-links.
- Estado último respaldo al inicio del card.
- **Ganancia**: settings deja de ser "config anexo" y pasa a ser parte del producto.

---

## Métricas antes/después esperadas

Sin datos duros, pero como norte para saber si los sprints logran el objetivo:

- **Antes**: 14 `fontSize` únicos → **Después**: 7 tokens tipográficos.
- **Antes**: 5 variantes loading + 3 error + 3 empty → **Después**: 3 componentes canónicos.
- **Antes**: 8 pickers con 3 paradigmas → **Después**: 3 paradigmas documentados + `SelectableCard` compartido.
- **Antes**: 11 tabs planos en reports → **Después**: hub agrupado semánticamente.
- **Antes**: `pagás/configurá/…` en 4 módulos → **Después**: 0 (test bloqueante en CI).
- **Antes**: import destructivo con `ConfirmDialog` → **Después**: todos los destructivos con `DestructiveDialog`.
- **Antes**: entry form con amount enterrado → **Después**: amount hero visible sin scroll.

---

## Preguntas abiertas para Diego (decisiones de producto)

Recopilo aquí las preguntas que quedaron abiertas en los 8 reportes, filtradas por las que **afectan alcance del roadmap**. Las cosméticas van al backlog.

### Alto impacto (definir antes de Sprint 5)

1. **Reports: tabs o hub?** — si aceptás romper el patrón actual y migrar a hub, Sprint 5 arranca; si no, hay que rediseñar la agrupación de tabs.
2. **Data-viz library** — ¿aceptás traer `fl_chart` para charts serios (ejes, tooltips, animación)? Alternativa: seguir con CustomPainter (más control, más código de mantenimiento).
3. **Roadmap de reportes** — ¿cuántos más vienen en los próximos 6 meses? Si son >15, urgencia del hub sube.
4. **AccountDetailScreen intermedia** — ¿va a existir "tap row → detalle" o el flujo se queda "row → edit form" para siempre? Impacta Sprint 8.
5. **CategoryPicker bottom sheet** — ¿va con "crear categoría inline" (P2.7) desde ya o queda para sprint separado?

### Filosóficos (afectan tono, no arquitectura)

6. **Densidad**: ¿la app va hacia "cómoda con hero grandes" (Cash App) o hacia "tablas densas eficientes" (YNAB/Monarch)? Es la decisión más importante para el próximo sprint de reportes.
7. **Light theme algún día?** — si es "nunca", varios trade-offs (contraste yellow, elevación tonal) se pueden endurecer.
8. **Long-press vs swipe** — para acciones contextuales en filas (multi-select, duplicar, eliminar). Android moderno tira a sheets, iOS a swipes.
9. **Modo denso opt-in en Settings** — ¿vale la pena diseñar los tokens de spacing con multiplicador desde ya?

### De data del usuario (para calibrar prioridad)

10. **Cuántas categorías tenés hoy?** Si son ≤12, varias P1/P2 de categorías bajan urgencia.
11. **Cuántas cuentas?** Si son 3-5, agrupación por tipo (P1 Accounts) baja urgencia.
12. **Con qué frecuencia usás Compare de weekly budgets?** — si es baja, H4 baja urgencia.
13. **`applies_to='both'` se usa?** — si en la práctica no, se puede eliminar del modelo.

---

## Cómo usar este documento

- **Como norte para próximos sprints**: cada Sprint 1-9 puede convertirse en spec con `spec-definir` reutilizando los hallazgos que le tocan.
- **Como criterio en code review**: cada PR nuevo puede validarse contra estos hallazgos ("¿estás introduciendo un `fontSize` inline nuevo?").
- **Como insumo de decisiones de producto**: las preguntas abiertas requieren respuestas antes de arrancar Sprint 5.
- **Vive**: cuando cada hallazgo se resuelva, tacharlo o mover a "done" al final. Cuando aparezca uno nuevo (auditoría futura, feedback de tester), agregarlo con el mismo formato.

---

## Reportes fuente (por módulo)

Los 8 reportes completos viven en las notificaciones de agentes de este turno. Si necesitás recuperarlos, cada uno vino con:

1. **Onboarding + Dashboard** — 2 P1, 7 P2, 6 P3, 4 P4
2. **Accounts** — 3 P1, 5 P2, 4 P3
3. **Categories** — 3 P1, 6 P2, 5 P3, 5 P4
4. **Entries** — 4 P1, 8 P2, 9 P3, 8 P4
5. **Weekly Budgets** — 5 P1, 7 P2, 6 P3, 3 P4
6. **Reports** — 4 P1, 8 P2, 8 P3, 6 P4
7. **Settings + Help** — 4 P1, 7 P2, 6 P3, 8 P4
8. **Sistémico (theme/tokens/widgets)** — 5 P1, 4 P2, 4 P3, 2 P4, **más "Diseño de tokens propuesto" completo**

Total: 30 P1, 52 P2, 48 P3, 36 P4 → **166 hallazgos**. Este consolidado extrae los ~40 con mayor ROI y agrupa el resto en el roadmap de sprints.
