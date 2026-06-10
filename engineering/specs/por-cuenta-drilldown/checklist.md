# Checklist de calidad de spec

- [x] Alcance claro
- [x] Fuera de alcance claro
- [x] Requisitos funcionales foliados
- [x] Reglas de negocio explicitas
- [x] Criterios de aceptacion verificables
- [x] Criterios medibles de exito definidos
- [x] Casos borde principales identificados
- [x] Datos, entidades o estados relevantes identificados
- [x] Permisos, seguridad o auditoria considerados si aplica
- [x] Integraciones consideradas si aplica
- [x] Compatibilidad o impacto en procesos existentes considerado
- [x] Preguntas bloqueantes registradas o resueltas

Notas:

- Sin `preguntas.md`: las decisiones grandes (alcance del reporte, alcance del drill-down, UI del modal, endpoint genérico) se resolvieron en una ronda con el usuario antes de generar la spec. Las decisiones técnicas secundarias quedaron como Supuestos explícitos en `spec.md`.
- Puntos revisables documentados como Riesgos (no bloqueantes): claridad del copy en tarjetas de crédito, manejo de buckets vacíos clickeables, cap del modal, divergencia futura con `/entries`.
- Si al planear surgen ambigüedades nuevas, registrar `preguntas.md` y resolver con `spec-clarificar`.
