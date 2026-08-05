# Checklist de calidad de spec

- [x] Alcance claro
- [x] Fuera de alcance claro
- [x] Requisitos funcionales foliados (RF-001 a RF-014)
- [x] Reglas de negocio explicitas (RN-LF-01 a RN-LF-14)
- [x] Criterios de aceptacion verificables (CA-01 a CA-16)
- [x] Criterios medibles de exito definidos (CM-01 a CM-06)
- [x] Casos borde principales identificados (15)
- [x] Datos, entidades o estados relevantes identificados (tabla `loan_adjustments`, schema v15, fórmula de saldo RN-LF-05)
- [x] Permisos, seguridad o auditoria considerados si aplica — app single-user sin permisos; la auditoría del ajuste se cubre con `reason` + historial + soft delete
- [x] Integraciones consideradas si aplica — backup JSON v4 (export e import), única superficie externa del proyecto
- [x] Compatibilidad o impacto en procesos existentes considerado — migración aditiva v14 → v15, import v1-v4, ruptura hacia atrás documentada en R-01
- [x] Preguntas bloqueantes registradas o resueltas — P-001, P-002 y P-003 respondidas por Diego el 2026-08-05

## Puntos de atención para `spec-planear`

- El orden de implementación importa: schema y `balanceOf` antes que la UI de ajustes, porque `overpay_loan` y el auto-cierre dependen de la fórmula nueva.
- La inversión de los 20 puntos de test existentes (CM-02) debe hacerse en el mismo commit que quita cada candado, no al final.
- R-01 obliga a preparar el kit de rollback (APK 0.33.0+121 + respaldo v3) **antes** de que Diego instale la versión nueva.
- RF-012 (higiene de tolerancias) es independiente del resto; puede ir en su propio commit para no contaminar el diff funcional.
