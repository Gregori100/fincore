# Preguntas abiertas

## UX

- ID: P-001
  Estado: respondida
  Pregunta: ¿Cuál es el preset de fecha default del tab "Cashflow
  mensual"?
  Por que importa: el default de hoy en `SpendingByCategoryTab` es
  `thisMonth` (un mes). Para Cashflow mensual, un solo mes muestra 1
  columna pareada → poca utilidad para tendencias. Necesitamos un
  rango más amplio por default.
  Opciones:
    A) Reusar `DateRangePreset.thisYear` (entre 1 y 12 meses según el
       momento del año). No requiere tocar el enum. Default conservador.
    B) Agregar un preset nuevo `last6Months` (rolling: últimos 6
       meses completos + el actual). Requiere bumpear el enum + la
       función `dateRangeForPreset` + actualizar tests del enum. Más
       trabajo, pero más útil siempre.
    C) Agregar `last12Months` rolling. Más datos visibles; barras
       comprimidas si el cel es chico.
    D) Misma opción default que `SpendingByCategory` (`thisMonth`) y
       que Diego cambie a Año / Custom según necesidad.
  Por que importa: cambia tanto el código (B y C requieren toque al
  enum) como la primera impresión de Diego al abrir el tab.
  Impacto si cambia: si se decide B o C, agregamos 1 RF más
  (DateRangePreset extendido), bumpeamos los tests del preset, y
  posiblemente reaprovechamos el preset nuevo también en el otro tab.
  Recomendación inicial: opción **B** (`last6Months` rolling), porque
  es el balance entre "ves tendencia útil" y "barras legibles en un
  cel". Pero confirmá vos.
  Respuesta o decision: **opción D — `thisMonth`** (igual que el tab
  existente). Razón: coherencia entre los 2 tabs. Si Diego quiere
  tendencia, tappea "Año" o "Custom". Evita bumpear el enum y mantiene
  patrón mental "default = mes corriente" entre tabs.

- ID: P-002
  Estado: respondida
  Pregunta: ¿Bar chart pareado (verde y rojo lado a lado por mes) o
  stacked (gasto debajo, ingreso encima) con una línea de neto encima?
  Por que importa: cambia la complejidad del render y la lectura del
  reporte.
  Opciones:
    A) **Pareado** (paired bars side-by-side). Cada mes tiene 2 barras
       verticales: verde a la izquierda (ingresos), rojo a la derecha
       (gastos). Lectura inmediata: cuál es más alta. Render simple
       (~30 líneas Dart nativo). Convención de apps financieras
       populares (Mint, YNAB).
    B) **Stacked + línea de neto**. Una barra por mes con ingreso
       arriba y gasto abajo (o invertido). Una línea continua
       superpuesta dibuja el neto del mes. Más denso de información,
       pero requiere más cuidado en render (eje doble, escala
       compartida). Probablemente requiere `fl_chart` o
       similar (dep nueva +500kb APK).
    C) **Solo neto** (1 barra por mes: alta verde si positivo, alta
       roja si negativo). Mínima información, máxima simplicidad. Si
       el objetivo es "ver tendencia", esto puede ser suficiente — pero
       perdés la composición (ingresos vs gastos).
  Impacto si cambia: si A → render nativo (~30 líneas) + sin deps.
  Si B → dep nueva `fl_chart` (~500kb) + más complejidad. Si C → 50%
  menos info pero 50% menos código.
  Recomendación inicial: opción **A** (pareado nativo). Es el balance
  entre información y simplicidad, y mantiene el patrón nativo del bar
  chart horizontal del spending tab.
  Respuesta o decision: **opción A — pareado nativo**. Sin dep nueva,
  patrón consistente con el spending tab, render simple.
