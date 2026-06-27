# Preguntas abiertas

## UX

- ID: P-001
  Estado: respondida
  Pregunta: ¿Cuál es la fecha default al abrir el tab "Saldo a
  fecha"?
  Por que importa: define la primera vista cuando Diego entra al tab.
  Si es "hoy", redundante con el dashboard. Si es "fin del mes
  anterior", apuntando al uso típico de reconciliación bancaria.
  Opciones:
    A) **Hoy**. Coherente con cómo abrieron otros tabs. Diego cambia
       inmediatamente si quiere ver el pasado. Redundante con
       dashboard, pero claro.
    B) **Ayer**. Pequeña diferencia con el dashboard pero útil para
       "cómo terminé el día de ayer".
    C) **Fin del mes anterior** (último día del mes calendario
       previo). Apuntando al uso típico de reconciliación con
       estados de cuenta que llegan al inicio del mes siguiente.
    D) **Fin de mes corriente** (hoy si estamos a fin de mes, sino
       último día del mes pasado completado).
  Impacto si cambia: 1 línea en `initState`. Cambiar después es
  trivial, pero define la primera impresión.
  Recomendación inicial: opción **C** (fin del mes anterior). El uso
  productivo del tab es reconciliación contra papel del banco.
  Default que apunta a ese uso es más útil que "hoy" redundante.
  Respuesta o decision: **opción C — fin del mes anterior**.
  Confirmado. `initState` calcula `_asOf = DateTime(now.year,
  now.month, 0)` (día 0 del mes corriente = último día del mes
  anterior).

- ID: P-002
  Estado: respondida
  Pregunta: ¿El tab muestra solo los 3 totales (BO/DE/CR) o también
  desglosa por cuenta?
  Por que importa: cambia el alcance UX y el tiempo de implementación.
  Opciones:
    A) **Solo totales** (3 cards). Resumen ejecutivo. Mismo formato
       que dashboard. Implementación más simple. Si Diego necesita
       saber qué cuenta tiene qué saldo, va a `/accounts`. PERO en
       `/accounts` no hay saldo histórico — solo el actual.
    B) **Totales + lista de cuentas** (3 cards + lista). Cada cuenta
       con su saldo individual a la fecha. Más útil para reconciliar
       cuenta por cuenta. Más código (~80 líneas extra) + 1 test
       data más + 1 widget test más.
    C) **Solo lista de cuentas** (sin cards). La suma agregada es
       trivial sumarla mentalmente del listado. Pero pierde el
       "resumen ejecutivo" del dashboard.
  Impacto si cambia: si A → ~250 líneas tab + 8 tests data + 3 widget.
  Si B → ~330 líneas tab + 9 tests data + 4 widget.
  Recomendación inicial: opción **B** (totales + lista). La lista es
  el valor diferencial del tab — sin ella, redundante con `/accounts`.
  La inversión en código es razonable.
  Respuesta o decision: **opción B — totales + lista de cuentas**.
  Confirmado. El tab incluye los 3 cards arriba y la lista de
  cuentas debajo con su saldo individual a la fecha.
