# Preguntas abiertas

Preguntas bloqueantes o de alto impacto para la implementación de `flutter-integer-cents-v1`. Todas resueltas por decisión del asistente el 2026-07-24 (Diego autorizó proceder sin discusión detallada previa). Integrar respuestas con `spec-clarificar` o dejar consolidado en `spec.md`.

## Datos

- **ID: P-001**
  **Estado**: respondida
  **Pregunta**: ¿`int` desnudo vs. wrapper `Money`?
  **Respuesta**: **`int` desnudo**. Convención documentada en `CLAUDE.md`. Sin overhead, drift nativo, SQL directo. La documentación es la única garantía semántica.

- **ID: P-002**
  **Estado**: respondida
  **Pregunta**: ¿Backup v3 con integer cents, o v2 preservado con doubles?
  **Respuesta**: **v3 con integer cents**. App local-first sin backend activo; v3 es autodocumentado; revival de Laravel legacy tendría su propio converter dedicado.

- **ID: P-003**
  **Estado**: respondida
  **Pregunta**: ¿Ratios (`interest_rate`, `minimum_payment_pct`, `minimum_capital_pct`) migran o quedan REAL?
  **Respuesta**: **No migran en este sprint**. Sin uso operativo actual en UI (RF-018 de sprint anterior). Se documenta en `pendientes.md` post-sprint para futuro sprint si se agregan cálculos que los consuman.

## UX

- **ID: P-004**
  **Estado**: respondida
  **Pregunta**: ¿Migración automática o con dialog de confirmación?
  **Respuesta**: **Automática**. Patrón que Diego ya conoce y espera. Backup automático pre-migración (RF-004) da respaldo sin fricción. Banner post-migración de 5s comunica.

- **ID: P-005**
  **Estado**: respondida
  **Pregunta**: ¿1 sprint monolítico o 2 sprints (v1a schema+DAO, v1b UI+backup)?
  **Respuesta**: **Monolítico**. Single-user single-dev; sideload manual; commits granulares dan trazabilidad sin dividir en subsprints.

## Casos borde

- **ID: P-006**
  **Estado**: respondida
  **Pregunta**: ¿Fixture del respaldo real de Diego versionado (anonimizado) o solo local?
  **Respuesta**: **No versionar el respaldo real ni anonimizarlo — usar fixture sintético**. Crear `test/fixtures/synthetic-backup-v2.json` con 158 entries generadas programáticamente, distribución similar (income/expense/credit_expense/debt_payment/transfer/loan_payment), montos con residuos IEEE 754 intencionales (ej. Σ de `0.1 + 0.2 + 0.3` que dan `0.6000000000000001`) para probar la conversión `centsFromDouble`. Suma total conocida, verificable por el test. **Ventajas**: sin data personal en el repo, determinístico, fácil de mantener. **Trade-off**: el dev (yo) valida contra el respaldo real de Diego una vez durante desarrollo (leído desde `~/Descargas/`), pero no queda en el repo.

## Restricciones

- **ID: P-007**
  **Estado**: respondida
  **Pregunta**: ¿Bump minor (`0.33.0+121`) o major (`1.0.0+121`)?
  **Respuesta**: **Minor `0.33.0+121`**. Consistente con el patrón previo. `1.0.0` se reserva para cuando FinCore se considere "production-ready" para múltiples usuarios.
