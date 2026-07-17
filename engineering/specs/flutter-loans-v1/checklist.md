# Checklist de calidad de spec

- [x] Alcance claro
- [x] Fuera de alcance claro
- [x] Requisitos funcionales foliados
- [x] Reglas de negocio explicitas
- [x] Criterios de aceptacion verificables
- [x] Criterios medibles de exito definidos
- [x] Casos borde principales identificados
- [x] Datos, entidades o estados relevantes identificados (tabla `loans`, columnas nuevas en `journal_entries`, estados Activo/Paid/Manual/Eliminado)
- [x] Permisos, seguridad o auditoria considerados si aplica (single-user, sin roles — documentado; historial de estados fuera de alcance)
- [x] Integraciones consideradas si aplica (Backup JSON v2 con compat v1, entry_form_screen modo read-only para movimientos ligados)
- [x] Compatibilidad o impacto en procesos existentes considerado (schema aditivo, reportes ganan renglón sintético sin romper existentes, AccountsDao.deleteAccount gana pre-check)
- [x] Preguntas bloqueantes registradas o resueltas (discovery completo — 4 tandas de AskUserQuestion + 1 aclaración final sobre pagos atrasados y cierre manual, todas integradas en spec)
