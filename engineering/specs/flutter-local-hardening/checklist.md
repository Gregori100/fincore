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
- [ ] Integraciones consideradas si aplica
- [x] Compatibilidad o impacto en procesos existentes considerado
- [x] Preguntas bloqueantes registradas o resueltas

## Notas

- **Integraciones**: NO aplica. Sprint de cleanup técnico sobre app local-first sin integraciones externas. El único "límite externo" es el flujo de share sheet de Android para exportar respaldo (RF-013), pero es API estándar de la plataforma, no integración con terceros.
- **Preguntas bloqueantes**: NO se generó `preguntas.md`. Diego cubrió en la solicitud todos los supuestos razonables (errores tipados snake_case, invalidación del cache de streams, fallback de `package_info_plus` en tests, alcance de la migración `schemaVersion` 1→2 limitado al índice parcial nuevo). Los riesgos restantes están documentados en la sección "Riesgos" de la spec; ninguno bloquea la planeación.
