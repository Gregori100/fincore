# Preguntas abiertas

## Alcance

- ID: P-001
  Estado: respondida
  Pregunta: ¿La migración inicial del JSON del backend se hace en el primer arranque vía una pantalla de "Importar respaldo" antes de Dashboard, o como un parámetro de build que precarga el JSON empaquetado en el APK?
  Por que importa: define cómo el usuario hace la transición de su BD real (Postgres) a la BD local (SQLite) al instalar la app nueva por primera vez. Opción A (pantalla) es más portable y reutilizable después como flujo de restore. Opción B (empaquetar) evita un paso manual la primera vez pero requiere reconstruir el APK por cada cambio del JSON.
  Impacto si cambia: A → pantalla "Primer arranque" con file picker + 2 botones. B → asset compilado en la app + sin pantalla. La spec asume A por defecto. Cambiar a B reduce el sprint en ~medio día pero acopla el APK al backup.
  Respuesta o decision: Opción A — pantalla "Primer arranque" obligatoria cuando la BD está vacía, con dos botones grandes: "Importar respaldo" (file picker → JSON v1 desde el celular) o "Arrancar limpio" (crea Bolsa singleton + 10 categorías default). Mismo flujo de import sirve después como "restaurar respaldo" desde Settings. Integrado en RF-006 y casos principales de spec.md.

## Restricciones

- ID: P-002
  Estado: respondida
  Pregunta: ¿Versión inicial = `0.2.0+2` (post-pivote, siguiendo la cuenta del 0.1.0+1 del cliente online actual) o `0.1.0+1` (reset porque es producto distinto)?
  Por que importa: como el `applicationId` es el mismo, Android trata la nueva app como upgrade de la vieja. El versionCode DEBE ser estrictamente mayor al ya instalado (1) — un `0.1.0+1` falla la instalación con `INSTALL_FAILED_VERSION_DOWNGRADE`. La opción A (0.2.0+2) respeta eso. La opción B sólo serviría si se desinstala manualmente la vieja primero (lo cual se va a hacer en el smoke igual).
  Impacto si cambia: cosmético, pero A tiene continuidad técnica que evita una traba en la primera instalación.
  Respuesta o decision: `versionName = 0.2.0`, `versionCode = 2`. Permite upgrade limpio sobre el `versionCode = 1` actual del APK del cliente online sin desinstalar previamente. Integrado en S-009.

- ID: P-003
  Estado: respondida
  Pregunta: ¿Drift con codegen (`build_runner`) o solo SQL manual?
  Por que importa: codegen genera las clases de tabla + queries tipadas; sin codegen el setup es más simple pero requiere escribir SQL crudo y mapear filas a mano. dogear usó codegen.
  Impacto si cambia: con codegen, el flujo de cambios de schema es: editar `database.dart` → `dart run build_runner build` → ya hay tipos. Sin codegen, requiere mantener manualmente clases por cada tabla. Para un schema de 3 tablas con relaciones, codegen es claramente mejor.
  Respuesta o decision: drift **con codegen** (`build_runner`). Tipos generados automáticamente, companions tipados, streams reactivos `watch()` para listas que se autoactualizan al cambiar la BD. Mismo patrón que dogear ya validó. Integrado en S-005.

## Datos

- ID: P-004
  Estado: respondida
  Pregunta: ¿Soft delete vs hard delete para cancelar movimientos y archivar cuentas/categorías?
  Por que importa: el backend usaba soft delete (`deleted_at`). Para sync futuro y para mantener histórico que aparezca en reportes (cuando se recuperen), soft delete es necesario. Pero en local single-user, hard delete es más simple y el "histórico" se conserva en backups.
  Impacto si cambia: A (soft delete, recomendado) — todos los DAOs filtran por `deleted_at IS NULL`. Cancelar un entry agrega `deleted_at = now()`. Archivar una cuenta idem. Los entries históricos siguen ahí. Compatible con sync futuro. B (hard delete) — sólo lo activo en la BD. Para histórico hay que mirar backups. Más simple pero rompe la compatibilidad sync futura.
  Respuesta o decision: **soft delete** (`deleted_at TEXT ISO-8601 NULL`) en accounts, categories y journal_entries. Todos los DAOs filtran `deleted_at IS NULL` por defecto. Cancelar/archivar setea `deleted_at = ISO8601(now)`. Sin UI para reactivar (decisión terminal, alineada con backend RN-006 y RN-007). Integrado en S-006.

- ID: P-005
  Estado: respondida
  Pregunta: ¿Saldos derivados sobre la marcha (calcular cada vez vía SQL agregado) o materializar en columna `accounts.balance` actualizada por trigger/Action?
  Por que importa: backend los derivaba siempre. Para SQLite local con miles de entries, derivar puede degradar performance del dashboard (suma cada vez que abro). Materializar es más rápido pero más estado a mantener (cada INSERT/UPDATE/DELETE de entries actualiza balances de las cuentas afectadas).
  Impacto si cambia: A (derivar siempre, recomendado) — SUM agregado en cada render del dashboard. Simple, sin estado. Si en el futuro hay slowdown, sprint aparte introduce materializado. B (materializar) — columna `accounts.balance` + trigger SQLite (o lógica en DAO). Más rápido pero introduce riesgo de inconsistencia.
  Respuesta o decision: **derivar sobre la marcha + aprovechar drift streams para cache automático + índices en `journal_entries`**. El `FinancialStateService` expone `Stream<num>` para BO/DE/CR y `Stream<num>` por cuenta usando `watch()` de drift. Como drift solo re-emite cuando cambia el contenido de las tablas observadas, el StreamBuilder reusa el último valor entre renders no-relacionados. Cero materialización, cero estado adicional. Índices sobre `journal_entries(account_origin_id)`, `journal_entries(account_destination_id)` y `journal_entries(deleted_at)` para que las queries `SUM ... WHERE ...` corran en < 5ms incluso con 50k+ entries. Integrado en S-007 y RF-004.
