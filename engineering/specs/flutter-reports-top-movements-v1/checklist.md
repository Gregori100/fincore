# Checklist de calidad de spec

- [x] Alcance claro
- [x] Fuera de alcance claro
- [x] Requisitos funcionales foliados (RF-001 a RF-011)
- [x] Reglas de negocio explícitas (RN-T01 a RN-T08)
- [x] Criterios de aceptación verificables
- [x] Criterios medibles de éxito definidos (CM-01 a CM-04)
- [x] Casos borde principales identificados (CB-1 a CB-10)
- [x] Datos, entidades o estados relevantes identificados
- [ ] Permisos, seguridad o auditoría considerados — N/A (single-user
      local, sin permisos)
- [x] Integraciones consideradas — TabBar de `ReportsScreen`,
      `customSelect.watch()` del reports DAO, navegación a
      `/entries/:id/edit`
- [x] Compatibilidad o impacto en procesos existentes considerado
      (R-01: bump de TabBar a 3 podría romper tests)
- [x] Preguntas bloqueantes registradas o resueltas — P-001
      respondida (kinds configurable con chips, default 5
      seleccionados), P-002 respondida (N = 20)
