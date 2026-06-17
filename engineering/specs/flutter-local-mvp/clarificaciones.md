# Clarificaciones

## 2026-06-17

- Pregunta: P-001
  Decision: pantalla "Importar respaldo" en primer arranque (no embeber el JSON como asset). El usuario es quien envía su archivo de backup al celular y lo selecciona desde la app la primera vez. Mismo componente sirve para restaurar respaldos posteriores desde Settings.
  Impacto en spec: actualizado RF-006 con confirmación explícita del flujo y referencia a P-001 cerrada. Casos principales ya lo incluyen.

- Pregunta: P-002
  Decision: `versionName = 0.2.0`, `versionCode = 2`. Permite upgrade limpio sobre el APK actual del cliente online (versionCode = 1) sin requerir desinstalación manual.
  Impacto en spec: actualizado S-009 (sin "supuesto" — ahora es decisión cerrada con justificación técnica del Android upgrade flow).

- Pregunta: P-003
  Decision: drift **con codegen** (`build_runner`). Tipos generados, streams reactivos, mismo patrón que dogear.
  Impacto en spec: actualizado S-005 con detalles del flujo de codegen y los beneficios (companions tipados, streams). RF-004 referencia el codegen.

- Pregunta: P-004
  Decision: **soft delete** (`deleted_at`) en accounts, categories y journal_entries. Sin UI para reactivar (terminal). Compatible con sync futuro.
  Impacto en spec: actualizado S-006 con detalles de implementación. RN-006/RN-007 ya alineadas. RF-008/RF-009/RF-010 ya describen el comportamiento esperado.

- Pregunta: P-005
  Decision: saldos **derivados** sobre la marcha + cache automático vía drift streams + índices en `journal_entries`. Sin materializar.
  Impacto en spec: actualizado S-007 con criterio de performance < 10 ms total. Actualizado RF-004 para incluir explícitamente la creación de los 3 índices en la migración inicial.

## 2026-06-17 — Decisión post-clarificaciones

- Tema: migración de datos del backend legacy
  Decision: Diego prefiere arrancar de cero sin importar el JSON del backend. Confirmó textualmente "no tengo tema en exportar mi backend. Puedo probar todo desde cero".
  Impacto en spec: Resumen, Objetivo, Casos principales, Riesgos, Supuestos S-001 y S-002, Criterios de aceptación actualizados. La pantalla "Primer arranque" mantiene los dos botones (Importar respaldo / Arrancar limpio) por resiliencia futura (Diego va a usar import después para restaurar respaldos propios), pero el flujo de lanzamiento es "Arrancar limpio".
  Impacto en plan: T001 (exportar JSON del backend) queda descartada. T004 (borrar legacy de main) deja de depender de T001. T050 (smoke en celular) se hace con BD seedeada (Arrancar limpio) en lugar de con JSON real importado. Fase 0 del plan se elimina como bloqueante.
