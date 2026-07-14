# Resumen ejecutivo — flutter-weekly-budgets-v1

## Qué se implementó

Nuevo módulo standalone "Presupuestos semanales" en FinCore:

- **Planeador semanal anticipado**: armar antes de recibir dinero
  qué se va a hacer con él, viendo cuánto sobra/falta al final de
  la semana.
- **Multi-plan por semana**: podés armar "Conservador", "Optimista",
  etc. para comparar escenarios de la misma semana.
- **Plantillas de presupuesto**: crear una plantilla derivada de
  un presupuesto existente y reutilizarla al armar semanas nuevas.
  Snapshot copiado (no comparten referencia — editar plantilla no
  toca presupuestos derivados y viceversa).
- **Renglones drag & drop**: nombre libre + monto + categoría
  opcional + ordenados con handle visual (⋮⋮). Solo el handle
  inicia el reorder; el resto del row abre edit.
- **Configuración global**: día de inicio de la semana (viernes por
  defecto) desde Settings. No fuerza; solo sugiere el picker.
- **Entrada desde Dashboard**: nuevo IconButton en el AppBar. El
  ícono "Categorías" se movió al PopupMenu `⋮` para no partir el
  wordmark en cel angosto.

## Impacto esperado

- Diego reemplaza el paso mental / papel de planificar la semana
  con un flujo dentro de la app.
- Base para features futuros: comparativa "planeado vs ejecutado"
  contra movimientos reales, notificaciones semanales, dashboard
  con card "balance de esta semana", recurrencia automática.
- Cero regresión en el ledger existente ni en los reportes.

## Riesgos o pendientes relevantes

- **Los presupuestos y plantillas NO se guardan en el respaldo**
  (decisión de diseño P-001). Aviso agregado como banner permanente
  en la pantalla de listado + FAQ. En restore Diego los pierde;
  aceptado como trade-off.
- **Smokes SM-01..SM-16 pendientes** — Diego los correrá en cel
  real. Especialmente SM-04 (drag handle), SM-06 (multi-plan),
  SM-09/10 (snapshot semantics), SM-14 (backup pierde budgets) y
  SM-16 (cel angosto 360dp).
- **Commit final pendiente** — Diego revisa el reporte antes del
  push.

## Estado de pruebas

- **678/678 tests verdes** (1 skip preexistente en WT-TS04
  documentado por hang de stream subscription en `close()`).
- `flutter analyze` limpio (4 hints info preexistentes tolerables).
- APK release compilado y verificado con
  `versionCode 2094 / versionName 0.20.0`.
- **Branch quality-review ejecutado** con 21 hallazgos:
  - 5 altas + 5 medias resueltas antes del cierre.
  - 1 media diferida con justificación.
  - 10 bajas documentadas para sprints futuros.
  - 0 bloqueantes.

## Iteración post-review de Diego (2026-07-14)

Ronda adicional tras primera revisión visual:

- **Limpieza de UX**: quitado banner backup permanente,
  simplificado empty state, ícono en empty templates.
- **Acciones rápidas**: edit/comparar/eliminar desde el card
  del listado vía `PopupMenuButton`.
- **Español neutral** (rioplatense purgado — regla vinculante en
  memoria).
- **Feature nueva**: vista calendario del mes con marks por día
  con presupuesto (reutiliza `table_calendar`).
- **Feature nueva**: comparación side-by-side de 2 presupuestos
  de la misma semana con matching por nombre + deltas.
- **Refactor BalanceFooter** (Opción C del UI/UX experto): barra
  de progreso + label + monto grande. Fixeó 2 bugs preexistentes
  de layout que rompían hit-testing.
- **7 quick wins UI/UX** aplicados (pasados atenuados, botón
  Agregar tintado, borde lateral por kind, tipografía del rango,
  etc.).

Sprint apto para smoke con Diego + commit final tras revisión.
