# Checklist de calidad de spec

- [x] Alcance claro
- [x] Fuera de alcance claro
- [x] Requisitos funcionales foliados (RF-001..RF-020)
- [x] Reglas de negocio explicitas (RN-001..RN-016)
- [x] Criterios de aceptacion verificables
- [x] Criterios medibles de exito definidos
- [x] Casos borde principales identificados
- [x] Datos, entidades o estados relevantes identificados (schema drift v1 con accounts, categories, journal_entries + sus columnas)
- [x] Permisos, seguridad o auditoria considerados (single-user sin auth; INTERNET único permiso Android; no se conecta a red en runtime; backups son archivos JSON que el usuario controla)
- [x] Integraciones consideradas (no aplica — única "integración" es el formato JSON v1 compartido con el backend legacy para migración inicial)
- [x] Compatibilidad o impacto en procesos existentes considerado (`legacy/web-and-online-flutter` rama nueva preserva todo; `main` cambia identidad; datos del usuario migran vía JSON)
- [x] Preguntas bloqueantes registradas o resueltas (P-001..P-005 cerradas el 2026-06-17; ver clarificaciones.md)
