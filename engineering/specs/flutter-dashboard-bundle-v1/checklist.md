# Checklist de calidad de spec

- [x] Alcance claro
- [x] Fuera de alcance claro
- [x] Requisitos funcionales foliados
- [x] Reglas de negocio explicitas
- [x] Criterios de aceptacion verificables
- [x] Criterios medibles de exito definidos
- [x] Casos borde principales identificados (18 CB: sparkline con pocos datos, filtro con cuenta archivada, cruzar medianoche, transfer/debt_payment excluidos, timezone borderline)
- [x] Datos, entidades o estados relevantes identificados (modelos `TodaySummary` + `DailyBalance` nuevos; sin schema bump)
- [x] Permisos, seguridad o auditoria considerados si aplica (N/A — single-user)
- [x] Integraciones consideradas si aplica (N/A — sin red)
- [x] Compatibilidad o impacto en procesos existentes considerado (dashboard aditivo; `_TotalCard` extendido; lista de mov con filtro reactivo; `FinancialStateService` intacto)
- [x] Preguntas bloqueantes registradas o resueltas (ninguna — 3 decisiones críticas cerradas con Diego antes de spec + 1 tomada por el skill: filtro NO persiste entre sesiones)
