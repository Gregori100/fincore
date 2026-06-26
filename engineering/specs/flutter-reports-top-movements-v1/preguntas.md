# Preguntas abiertas

## Datos

- ID: P-001
  Estado: respondida
  Pregunta: ¿Qué `kind` entran en el top? Opciones:
    A) **Todos los 5 kinds** (income, expense, credit_expense,
       debt_payment, transfer). Muestra cualquier movimiento grande
       sea entrada, salida o interno. Top de "auditoría completa".
    B) **Solo gastos** (expense + credit_expense). El top responde
       específicamente "cuáles fueron mis gastos grandes". Coherente
       con la lectura más común de "top spending".
    C) **Income + gastos** (income + expense + credit_expense).
       Excluye movimientos internos (transfer, debt_payment) que no
       representan flujo "contra el afuera". Mismo criterio que el
       cashflow (RN-C03).
    D) **Configurable**: chips de kinds en el header del tab (como en
       el panel de filtros). Más flexibilidad pero más UI.
  Por que importa: cambia la utilidad del tab. Si Diego quiere
  auditoría amplia (incluye transfers grandes para revisar), opción A.
  Si quiere foco en gasto, opción B. Si quiere coherencia con el
  cashflow, opción C.
  Impacto si cambia: define el `WHERE kind IN (...)` del SQL.
  Cambiarlo después es trivial (1 línea), pero hay que decidir
  default ahora.
  Recomendación inicial: opción **C** (income + gastos, sin internos).
  Coherente con el cashflow tab. Para revisar transfers grandes, Diego
  va a `/entries` con filtro de kind. Pero confirmá vos.
  Respuesta o decision: **opción D — configurable con chips**.
  El header del tab muestra los 5 chips de kinds (multi-select).
  Default: **todos los 5 seleccionados** (auditoría completa al abrir).
  Diego destildea los que no le interesen. La query SQL filtra por
  `kind IN (...)` con la selección activa. Sin selección = empty
  state forzado (consistente con cualquier filtro a 0 matches).

## UX

- ID: P-002
  Estado: respondida
  Pregunta: ¿Cuántos rows muestra el top por default? Opciones:
    A) **10**. Cabe en 1 scroll en cel chico. Conciso, fuerza a Diego
       a acotar el rango si quiere ver más.
    B) **20**. Cabe en ~1.5 scrolls. Más cobertura sin abrumar.
    C) **50**. Más datos pero requiere scroll considerable. Más útil
       en rangos amplios (Año).
  Por que importa: balance UX entre "rápido de leer" y "suficiente
  para auditar".
  Impacto si cambia: solo el `limit` del SQL. Cambiar después es
  trivial.
  Recomendación inicial: opción **B** (20 rows). Balance entre
  legibilidad y cobertura — cubre bien los outliers del mes promedio
  sin abrumar.
  Respuesta o decision: **opción B — 20 rows**. Confirmado.
