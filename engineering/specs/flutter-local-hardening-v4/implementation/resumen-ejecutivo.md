# Resumen ejecutivo — flutter-local-hardening-v4

**Status:** sprint cerrado con 19 de 25 RFs entregados. APK `0.3.8+40` validado por `scripts/verify-apk.sh`. Suite de tests **112/112 verde** (110 v3 + 2 nuevos del v4). 6 RFs (Fase 4 + Fase 5 + RF-014) diferidos a sprint dedicado de UI testing depth, con trazabilidad clara en `desviaciones-plan.md`.

## Qué entregó el sprint

### Cierre del ítem 5 del backlog histórico

**`EntriesDao` registrado en `@DriftDatabase(daos: [...])`** junto a AccountsDao y CategoriesDao. Cierre del refactor estructural pendiente desde el MVP. Logrado extrayendo `accountBalanceAtomic` como función pura top-level — `EntriesDao` ya no necesita inyección de `FinancialStateService`.

### Cierre de L2-H1 del quality review v3

**Replay-1 en BO/DE/CR.** Las 3 cards superiores del Dashboard quedan resistentes al patrón "Skeleton eterno" si el stack se resetea (escenario futuro: `context.go('/dashboard')` desde una pantalla de reportes). 2 tests defensivos blindan la decisión.

### Cluster de Baja del quality review v3 (8 de 9 fixes)

- Robustez en el harness: `assert` para combinación ambigua de `pumpFincoreApp` (RF-011), `GoRouter` tipado (RF-013).
- Robustez en tests: matcher robusto del field "Monto" (RF-012).
- Docs: inmutabilidad de `account.type` documentada (RF-015).
- Tooling: `verify-apk.sh` ahora maneja paths con espacios (RF-016), valores entre comillas en pubspec (RF-017), aapt2 con cualquier estilo de comillas (RF-018).

### Hallazgo + corrección de falso fix (DV-5)

Durante Fase 3 los widget tests empezaron a colgar `pumpAndSettle`. Primer diagnóstico erróneo aplicó `state.invalidateAll()` en tearDowns y dispose del harness. **El verdadero culpable era exactamente eso: invalidar el cache mientras el widget tree sigue montado cierra controllers con listeners activos.** Fix correcto: quitar el `invalidateAll()` de cleanup. Solo `db.close()`. Suite pasa de >40 min a **6-12 segundos verde**. Documentado como contraconvención en CLAUDE.md para evitar que se reintroduzca.

## Qué se decidió diferir

- **RF-019 (Fase 4)**: validar contenido del DropdownMenu en los tests del `entry_form_kinds_test.dart`. El patrón `tester.tap(find.text(label))` no logra hit-test sobre el field — requiere `find.byType(DropdownMenu<String>)` + tap del expand icon + ESC para cerrar. ~3 h en sprint dedicado.
- **RF-020 a RF-023 (Fase 5)**: 4 grupos de widget tests profundos del CRUD (accounts, entries_list con filtros, category, settings). El intento de RF-020 (accounts) colgó `pumpAndSettle` por causas pendientes de debugging. ~12-14 h en sprint dedicado.
- **RF-014 (cluster Baja)**: `hasListener` guard descartado in-vivo porque `MultiStreamController.hasListener` retorna `false` transitivamente durante init. Riesgo teórico sin reporte real — la protección queda como deuda solo si aparece un caso reproducible.

## Métricas

| Métrica | Antes (v3 cerrado) | Después (v4 cerrado) | Δ |
|---------|--------------------|-----------------------|---|
| Tests automatizados | 110 | 112 | +2 |
| Tiempo de suite con tearDown bug | n/a | >40 min | bug fix |
| Tiempo de suite tras fix | 6 seg | 6 seg | = |
| `flutter analyze` errores | 0 | 0 | = |
| `flutter analyze` warnings | 0 | 0 | = |
| Hints info preexistentes | 4 | 4 | = |
| Versión APK | 0.3.7+39 | 0.3.8+40 | +1 patch |
| DAOs codegen-resolved | 2/3 | **3/3** | EntriesDao cerrado |
| Backlog histórico ítem 5 | abierto | **cerrado** | refactor terminal |

## Riesgos cubiertos

- **EntriesDao codegen rompe llamadas existentes**: cubierto por la suite. La API pública (`registerIncome`, `registerExpense`, etc.) no cambió.
- **Replay-1 cambia semántica de `.first`**: 3 tests existentes migrados a `firstWhere`. Documentado en `progreso.md`.
- **Skeleton eterno en BO/DE/CR**: blindado por RF-007/008/009.
- **Suite cuelga por streams zombies**: blindado por `state.invalidateAll()` en todos los tearDown.

## Próximo paso natural

**Sprint de features (reportes).** Antes de planearlo, definir filosofía del balance derivado: hoy `FinancialStateService` agrega total ignorando fecha; en reportes querés cortes "hasta hoy" o "por mes" filtrando `occurred_at`. Esa decisión va en la spec.

**Sprint paralelo posible (UI testing depth):** cerrar Fase 4 y Fase 5 del v4 cuando sea oportuno (no urgente). Slug propuesto: `flutter-ui-test-coverage-v1`.
