# Checklist de calidad de spec

- [x] Alcance claro
- [x] Fuera de alcance claro
- [x] Requisitos funcionales foliados (RF-001 a RF-014)
- [x] Reglas de negocio explícitas (RN-A01 a RN-A08)
- [x] Criterios de aceptación verificables
- [x] Criterios medibles de éxito definidos (CM-01 a CM-04)
- [x] Casos borde principales identificados (CB-1 a CB-12)
- [x] Datos, entidades o estados relevantes identificados
- [ ] Permisos, seguridad o auditoría considerados — N/A (single-user
      local, sin permisos)
- [x] Integraciones consideradas — extensión de `EntriesFilters`,
      `EntriesDao.watchPage`, `EntriesFiltersScreen`,
      `EntriesActiveFiltersBar`, `EntriesPaginatedList`
- [x] Compatibilidad o impacto en procesos existentes considerado
      (R-04: campos opcionales con default null preservan callers)
- [x] Preguntas bloqueantes registradas o resueltas — sin
      preguntas; supuestos documentados en spec.md
