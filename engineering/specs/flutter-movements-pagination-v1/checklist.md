# Checklist de calidad de spec

- [x] Alcance claro
- [x] Fuera de alcance claro
- [x] Requisitos funcionales foliados
- [x] Reglas de negocio explícitas
- [x] Criterios de aceptación verificables
- [x] Criterios medibles de éxito definidos
- [x] Casos borde principales identificados
- [x] Datos, entidades o estados relevantes identificados
- [ ] Permisos, seguridad o auditoría considerados si aplica — N/A (single-user local-first)
- [x] Integraciones consideradas si aplica (drift `customSelect.watch()` reactivo + ScrollController)
- [x] Compatibilidad o impacto en procesos existentes considerado (Dashboard sigue con limit:10; deprecated eliminados no afectan callers vivos)
- [x] Preguntas bloqueantes registradas o resueltas (2 decisiones cerradas pre-spec: scroll infinito + limit default 100)
