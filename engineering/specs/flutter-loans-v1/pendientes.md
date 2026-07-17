# Pendientes flutter-loans-v1 (post-cierre 2026-07-17)

Backlog de lo que quedó abierto tras cerrar el sprint, el quality-review
2026-07-17 y el design audit del mismo día. Ordenado por categoría, no
por prioridad — cada ítem tiene su propia justificación de por qué se
dejó fuera y qué desbloquearía.

Estado del sprint al cerrar:
- APK `0.29.0+115` shipped, 842 tests verdes, 3 hints preexistentes.
- 4 commits del sprint base + 6 commits del ciclo quality-review + 10
  commits del design audit = 20 commits en `main`.
- Documentación: `spec.md`, `plan/`, `implementation/`, dos
  `quality-review/` (baseline + post-hotfix + 2026-07-17), este archivo.

## Deuda técnica del propio sprint (hicimos "suficiente", no completo)

### P-1. Sweep de tipografía completo

- **Estado**: parcial. En el commit `cd6cd7b` (F-DES-5) migré
  spacing/radii/alpha, pero los `fontSize: 10/11/15/18` en los 5
  archivos `loan_*.dart`, `dashboard_screen.dart`,
  `spending_by_category_tab.dart` y `movement_row.dart` siguen literales.
- **Por qué se dejó**: la escala tipográfica actual (7 tokens entre
  `displayXL` 56sp y `overline` 11sp) no cubre 10/15/18 sin inventar
  4-5 tokens intermedios con 1-2 usos cada uno — sería sobre-modelado.
- **Qué desbloquearía**: cerrar la deuda de "boy scout" que
  `CLAUDE.md` reclama para cada PR sobre esos archivos.
- **Cómo atacarlo**: sprint dedicado `flutter-typography-audit-v1` que
  (a) enumere fontSize literales en toda la app (no solo loans), (b)
  agrupe los tamaños en clusters y (c) decida token nuevo vs.
  `token-exception` justificada. `displayL` (36sp) que creamos en F-DES-4
  es la referencia del proceso.

### P-2. Semantics parcial

- **Estado**: F-DES-13 solo cubrió `_LoanTotalCard` y `_ChipShell` del
  dashboard. Faltan: `_StatusBadge` de `/loans`, `_AcumMetric` del
  detalle, pills capital/interés (`_SplitPill`), `_TypeBadge`,
  `_LoanChip` de `movement_row`.
- **Por qué se dejó**: el resto de la app tampoco tiene Semantics
  agrupado consistente. Cerrar solo el módulo loans crea inconsistencia
  con el resto.
- **Cómo atacarlo**: sprint `flutter-a11y-v1` que audite Semantics
  cross-app y establezca patrones (ídem `_TotalCard` del dashboard
  que ya funciona).

### P-3. Test de migración con BD real "vieja"

- **Estado**: `MG-QR-M4` (`test/data/database_migration_test.dart`)
  valida las ramas defensivas 5→11, 6→11, 7→11 en BD `NativeDatabase.memory()`
  recién creada. Nunca se probó contra una BD real de v5/6/7.
- **Por qué se dejó**: no hay tester previo con BD histórica accesible.
  Diego arrancó desde cero en el pivote local-first (2026-06-12).
- **Riesgo real**: bajo — la lógica es idempotente. Alto solo si aparece
  un tester futuro con BD antigua.
- **Cómo atacarlo**: cuando aparezca un tester con BD v5/6/7, capturar
  su archivo `.db` y añadirlo como fixture al test.

### P-4. Smoke manual del round-trip de backup v2

- **Estado**: tests unitarios (`backup_test.dart` en el commit `c243677`)
  cubren que `is_monthly_payment` sobrevive el round-trip. Diego nunca
  ejecutó el smoke item 30 del `test-plan.md`.
- **Por qué se dejó**: el test unitario es suficiente para regresión.
  El smoke manual es "belt-and-suspenders".
- **Cómo atacarlo**: cuando toque smoke completo pre-release, ejecutar
  item 30 (crear 1 monthly + 1 capital, export → wipe → import,
  verificar badges en `/loans/:id`).

### P-5. Política del flujo "editar fecha del contrato con pago existente"

- **Estado**: acordado como "queda para después" durante el ciclo
  hotfix v5 con Diego. Escenario: `contract_date = 17/jul`, pago del mes
  registrado el `17/jul`. Diego edita `contract_date` a `18/jul`. El
  pago queda "antes del contrato".
- **Comportamiento actual**: la BD acepta el update del contrato
  (`updateLoan` no valida contra pagos). El siguiente edit del pago
  lanza `payment_before_contract`. Ningún error inmediato.
- **Por qué se dejó**: es un edge case raro y hay 4 políticas posibles
  (a) rechazar el update, (b) mover el pago automáticamente, (c) alertar
  no bloqueante, (d) ignorar (comportamiento actual). No hay consenso.
- **Cómo atacarlo**: 5 min de discusión con Diego + 30 min de
  implementación de la política elegida + 1 test.

## Features de dominio nunca consideradas en el sprint

### P-6. Notificaciones locales de próximo pago

- **Uso real**: Diego olvidaría menos pagos si el cel le avisa 1 día
  antes del `payment_day`.
- **Requisitos técnicos**: `flutter_local_notifications`, permisos
  Android 13+ (`POST_NOTIFICATIONS`), scheduler que respete cambio de
  `payment_day` en `updateLoan` y cierre `paid`/`manual`.
- **Impacto**: alto (uso diario). Esfuerzo: medio (permisos + política
  de reprogramación).
- **Nota**: el más rentable si sobra energía para el próximo ciclo.

### P-7. Simulador "¿cuánto ahorro si abono X a capital?"

- **Uso real**: botón en el detalle del préstamo que muestre "Si aplicás
  $5,000 extra hoy, terminás 3 meses antes y ahorrás $1,200 en
  intereses proyectados."
- **Requiere**: modelo de amortización con tasa implícita (derivada de
  `principal / monthly_payment / initial_duration_months`).
- **Utilidad**: alta para decisiones ("¿pago el aguinaldo o lo ahorro?").
- **Escollo**: si el interés es variable (P-10), el modelo se
  complica.

### P-8. Historial de cambios del contrato

- **Estado hoy**: `updateLoan` cambia `monthly_payment`,
  `current_duration_months`, `payment_day`, `contract_date` in-place.
  No queda rastro (auditoría inexistente).
- **Uso real**: cuando el banco reestructura el préstamo (baja mensual,
  extiende plazo), Diego pierde la foto del contrato original.
- **Requiere**: tabla `loan_history` (o `loan_events`) con snapshot al
  cambiar campos clave + UI en el detalle para ver la línea de tiempo.

### P-9. Múltiples préstamos con misma cuenta destino

- **Estado hoy**: técnicamente permitido; ninguna validación bloquea
  crear 2 préstamos apuntando a la misma cuenta. El `AccountsDao.archive`
  usa `findByDestinationAccount` que devuelve el PRIMERO — puede fallar
  silenciosamente si hay 2.
- **Uso real**: bajo. Un tester real casi nunca deposita 2 préstamos en
  la misma cuenta.
- **Riesgo**: potencial bug en la cascada de `deleteAccount` si hay 2.

### P-10. Interés variable / tasa mes a mes

- **Uso real**: préstamos hipotecarios / créditos con tasa SOFR + spread.
  Diego probablemente no tiene, pero es un límite del modelo.
- **Modelo actual**: implícito, fijo, derivado de la relación
  `principal ↔ monthly_payment ↔ duration`.
- **Extensión requerida**: tabla `loan_rate_history` con
  `effective_from` + tasa % — o campo `interest_amount` que ya soporta
  variación mes a mes (ya se guarda; falta UI para verlo agregado).

### P-11. Comisiones/seguros embedded en la mensualidad

- **Estado hoy**: `principal + interest = amount` es hard rule (RN-L07).
- **Uso real**: mensualidades reales de banco incluyen "seguro de vida"
  + "comisión de administración" + capital + intereses. Hoy Diego los
  suma a `interest` o los pierde.
- **Extensión**: `other_fees` como cuarta columna del split, con
  `principal + interest + other_fees = amount`.

### P-12. Exportar un préstamo aislado

- **Uso real**: cuando el banco / contratista te pide "detalle de tu
  préstamo" o cuando el contador te pide comprobantes. Compartir por
  chat un JSON o PDF con contrato + historial de pagos.
- **Requiere**: función de export selectiva (variante de
  `BackupService.exportToJson` con filtro por `loan_id`) + template
  visual (Markdown/PDF).
- **Fuera del alcance local-first "puro"** pero es útil aislado.

## Mejoras UX incrementales (no propuestas por el design audit)

### P-13. Reportes filtrados por préstamos

- Ver evolución del saldo total de deuda en el tiempo (línea temporal).
- Hoy solo hay renglones sintéticos en `spendingByCategory` (capital +
  intereses del mes). Falta una gráfica "deuda desde que arrancaste
  FinCore" y "proyección de cierre si mantengo el ritmo".

### P-14. Widget "Patrimonio neto" en dashboard

- BO + DE − CR usados − Σ saldo préstamos.
- En 1 mirada Diego vería su patrimonio real, que es más útil que BO/DE
  separados cuando hay deuda considerable.

### P-15. Búsqueda de préstamo por nombre

- Con 5+ préstamos, `/loans` se vuelve poco práctica sin buscar.
- Hoy es scroll manual. En cel con la pantalla llena de préstamos
  cerrados, encontrar uno activo es fricción.
- Solución simple: `TextField` de filtro arriba de la lista, filtro
  in-memory.

### P-16. Modo "solo lectura" del detalle más notorio

- Cuando el préstamo está `paid`/`manual`, hoy solo los rows tienen
  candado + colores muted (F-DES-9). El shift visual del detalle
  completo es sutil.
- Alternativa: fondo del Scaffold ligeramente distinto + banner más
  presente + FAB oculto (ya está) + header con badge grande.

## Sugerencia de orden para el próximo ciclo

Si el objetivo es **valor inmediato para Diego**:
1. P-6 (notificaciones) — pega a diario, cerrado técnicamente.
2. P-14 (patrimonio neto) — 1 KPI nuevo, minutos de código, alto valor.
3. P-15 (búsqueda) — mínimo esfuerzo, resuelve fricción real.

Si el objetivo es **hardening técnico**:
1. P-1 (sprint tipografía) — cierra deuda documentada.
2. P-8 (historial contrato) — evita pérdida silenciosa de auditoría.
3. P-2 (Semantics cross-app) — cierra a11y en toda la app.

Si el objetivo es **extender modelo de dominio**:
1. P-10 (interés variable) — habilita hipotecarios.
2. P-11 (comisiones) — habilita mensualidades reales de banco.
3. P-7 (simulador) — subproducto de tener el modelo de amortización.
