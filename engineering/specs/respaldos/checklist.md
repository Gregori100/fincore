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

- Scope simplificado por decisión del usuario (2026-05-21): se descartó el modo **merge aditivo** del import; queda solo **reemplazo total** (reusa `HardResetUserData` modo full). El merge pasa a "Fuera de alcance" como v2. Esto elimina el edge case más complejo (elegibilidad de movimientos que cruzan cuentas existentes vs nuevas).
- No se creó `preguntas.md`: las decisiones grandes se resolvieron antes/durante la definición. Puntos revisables (manejo de filas inválidas, acumulación de categorías en replace) quedaron como Riesgos/Supuestos, no bloquean.
- Si al planear surge ambigüedad sobre el formato de transporte del import (JSON en body vs multipart) se resuelve en `plan/`.
