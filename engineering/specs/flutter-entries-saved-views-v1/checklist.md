# Checklist de calidad de spec

- [x] Alcance claro
- [x] Fuera de alcance claro
- [x] Requisitos funcionales foliados (RF-001 a RF-012)
- [x] Reglas de negocio explícitas (RN-V01 a RN-V10)
- [x] Criterios de aceptación verificables
- [x] Criterios medibles de éxito definidos (CM-01 a CM-06)
- [x] Casos borde principales identificados (CB-1 a CB-11)
- [x] Datos, entidades o estados relevantes identificados
- [ ] Permisos, seguridad o auditoría considerados — N/A (single-user
      local, sin permisos)
- [x] Integraciones consideradas — `EntriesFilters` serializer,
      panel de filtros, AppBar, backup JSON v1 (RN-V10)
- [x] Compatibilidad o impacto en procesos existentes considerado
      (R-01: schema bump 2→3 con migración aditiva; R-03: backup v1
      no incluye vistas)
- [x] Preguntas bloqueantes registradas o resueltas — P-001
      respondida (híbrido preset/custom), P-002 respondida (guardar
      en panel + aplicar desde AppBar)
