# Resumen ejecutivo — Plan

## Qué se implementó

Una nueva sección `/plan` dentro de FinCore que permite a la persona declarar **eventos financieros futuros** (ingresos recurrentes, gastos fijos, pagos a tarjeta y gastos puntuales) y ver, de manera visual, **cómo evolucionan sus saldos a 6 meses**. El usuario puede planear "voy a recibir $5,700 cada viernes y abonar $3,000 a la tarjeta", ver con una gráfica cuándo termina cada deuda, y ajustar pagos específicos sin alterar la regla general.

La proyección vive en paralelo a los movimientos reales: nada de lo que se planea altera los saldos actuales ni se mezcla con el histórico real. Cuando llega el día, el usuario sigue registrando movimientos como hasta ahora.

## Impacto esperado

- **Visibilidad financiera real**: la app deja de ser solo retrospectiva. Por primera vez responde a "¿cómo me va a ir los próximos 6 meses si sigo este plan?".
- **Decisiones informadas de pago**: el usuario puede comparar visualmente "si pago $3k o $5k al viernes" editando una ocurrencia y viendo el impacto en la curva de deuda.
- **Sin riesgo en datos existentes**: el feature es totalmente aditivo. Cero cambios en `journal_entries`, cuentas, balances o reportes actuales.
- **Base para futuras capas**: el motor está listo para que se le sume, en una v2, el cálculo de intereses por no pagar el mínimo de la tarjeta (Fase 2 documentada).

## Riesgos o pendientes relevantes

- **Recorrido manual de la UI**: pendiente que el usuario lo haga en localhost antes de pushear (10 pasos documentados en `test-plan.md`). Especial foco en: archivar cuenta usada por un evento, sobrepago en simulación, cambio de día de recurrencia con overrides existentes.
- **Build de producción Vite**: el comando `npm run build` falla en el ambiente local por permisos en `dist/`, ajeno al feature. Conviene resolverlo o validarlo en imagen Docker limpia antes del deploy.
- **Zona horaria**: la proyección usa `Carbon::today()` del server. Para el deploy a Fly.io conviene fijar `APP_TIMEZONE=America/Mexico_City` para evitar off-by-one en la fecha "hoy".
- **`branch-quality-review`** sugerido como gate antes del merge.

## Estado de pruebas

- **Backend**: 265/265 (subió +59 nuevos del Plan; sin regresiones).
- **Frontend**: 49/49 (subió +8 nuevos del store).
- **Manual**: pendiente que el usuario lo recorra.
- **E2E**: no se agregaron tests en esta v1 (justificado por costo vs valor de Chart.js + modales encadenados; cubierto por backend + store).
