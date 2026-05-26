# Respaldos — Export / Import de datos financieros

## Resumen

Permite al usuario generar un archivo JSON con su información financiera (cuentas, categorías y movimientos) y volver a aplicarlo más tarde. El import tiene un único modo: **reemplazo total**, que vacía la cuenta reusando el hard reset y luego restaura el respaldo, regenerando identidades para que el archivo sea aplicable en cualquier cuenta del mismo usuario o de otra. El plan (eventos planeados) queda fuera del respaldo. Todo es manual: el usuario descarga y sube el archivo.

## Problema a resolver

Hoy no hay forma de sacar los datos de FinCore ni de recuperarlos. El hard reset es irreversible y no tiene red de seguridad. Tampoco se puede mover la información entre cuentas o dispositivos. El usuario necesita: (a) respaldar antes de un reset, (b) restaurar si se equivocó o cambió de cuenta, (c) llevar sus cuentas y movimientos de un lado a otro.

## Objetivo

1. Exportar a un archivo JSON portable y legible el estado financiero del usuario (cuentas + categorías + movimientos), excluyendo registros archivados (soft-deleted) y el plan.
2. Importar ese archivo en modo reemplazo total, regenerando identidades para que el respaldo sea aplicable en cualquier cuenta.
3. Integrar ambos en la vista `/settings`, junto a la zona de resets, sin tocar el resto de la app.

## Alcance

- **Export**: endpoint que arma y devuelve un JSON descargable con `version`, `exported_at` y los arreglos `accounts`, `categories`, `entries`. Solo registros activos (no soft-deleted). Excluye `planned_events` y `planned_event_overrides`.
- **Import — reemplazo total**: valida el archivo, ejecuta `HardResetUserData::execute(userId, 'full')` y luego inserta el contenido del respaldo (cuentas, categorías por reconciliación, movimientos), regenerando UUIDs y remapeando FKs. Requiere confirmación por contraseña (acción destructiva).
- **UI** en `/settings`: sección "Respaldos" con botón "Descargar respaldo" y un flujo "Aplicar respaldo" (subir archivo → confirmar con contraseña).
- **Validación del archivo**: estructura y `version` compatibles; rechazo claro de archivos corruptos, vacíos o de versión incompatible.

## Fuera de alcance

- **Modo merge aditivo** (agregar solo cuentas inexistentes con sus movimientos, dedup por nombre). Se descartó de v1 por su complejidad (regla de elegibilidad de movimientos que cruzan cuentas existentes vs nuevas). Queda como v2.
- Respaldos automáticos, programados o almacenados en el servidor. Todo es manual y client-initiated.
- Incluir el plan (`planned_events`/overrides) en el respaldo. Versión posterior.
- Incluir datos de cuenta de usuario (email, password, tokens, verificación). El respaldo es solo del dominio financiero.
- Cifrado del archivo. El JSON es texto plano; el usuario resguarda.
- Versionado/migración entre múltiples esquemas. Esta versión define `version: 1`.
- Restaurar registros archivados (soft-deleted). El export los ignora.

## Reglas de negocio

- El export incluye, por cada entidad activa del usuario:
  - **Account**: `name`, `type`, `is_protected`, `credit_limit`, `closing_day`, `payment_day`, `interest_rate`, `minimum_payment_pct`, `description` + un identificador local del archivo.
  - **Category**: `name`, `applies_to`, `color_slug`, `icon_slug`, `monthly_limit` + identificador local.
  - **JournalEntry**: `kind`, `amount`, `description`, `occurred_at` + referencias por identificador local a cuenta origen, cuenta destino y categoría.
- El identificador local (puede ser el UUID original) sirve **solo para resolver referencias dentro del archivo**; al importar se descarta y se generan UUID nuevos.
- **Regeneración de identidad**: al importar, toda entidad creada recibe UUID v7 nuevo (`HasUuids`) y `user_id` = usuario autenticado. Las referencias de los movimientos se remapean con una tabla local archivo→nuevo-id.
- **Reconciliación de la Bolsa**: la Bolsa es `is_protected` y singleton; nunca se crea una segunda. La cuenta cash del archivo se mapea a la Bolsa existente del destino (que el reset conserva), y sus movimientos se remapean a ella.
- **Reconciliación de categorías por nombre** (case-insensitive, trim): si existe una categoría con ese nombre en el destino, se reusa; si no, se crea. Así los movimientos importados conservan su categoría.
- **Cuentas no-cash**: se crean siempre nuevas (el reset borró las del destino), con UUID nuevo.
- El reemplazo total es destructivo: requiere confirmación por contraseña, igual que el hard reset.
- Validación del archivo antes de tocar la BD: JSON válido, `version` soportada (`1`), estructura esperada. Si falla, se rechaza con error claro y no se modifica nada.
- Toda la operación corre en una transacción: el hard reset y la restauración son atómicos; si algo falla a mitad, rollback total (la cuenta queda como estaba antes del import).
- Filas de movimiento inválidas (monto ≤ 0, fecha no parseable, referencia que no resuelve) se omiten e informan en el resumen; estructura/versión inválida aborta todo el import.
- La filosofía libreta libre se respeta: los movimientos importados pueden dejar saldos negativos sin bloqueo.

## Requisitos funcionales

- RF-001: El sistema debe exponer un endpoint autenticado que devuelva un JSON con `version`, `exported_at`, y los arreglos `accounts`, `categories`, `entries` del usuario actual, solo registros activos y sin el plan.
- RF-002: El JSON de export debe incluir, por cada movimiento, referencias resolubles a su cuenta origen, cuenta destino y categoría mediante identificadores locales presentes en el archivo.
- RF-003: El sistema debe exponer un endpoint autenticado de import que reciba el contenido del archivo, validando estructura y versión antes de modificar datos.
- RF-004: El import debe ejecutar el hard reset (`full`) y luego restaurar el respaldo completo, requiriendo confirmación por contraseña.
- RF-005: El import debe regenerar todos los UUID y remapear las FKs de los movimientos (origin, destination, category) a las entidades resultantes (creadas o reconciliadas).
- RF-006: El import debe reconciliar la Bolsa contra la existente (nunca duplicarla) y las categorías por nombre (case-insensitive, trim), creando las que no existan.
- RF-007: El import debe ejecutarse dentro de una transacción y revertir todo ante cualquier error no recuperable.
- RF-008: El import debe devolver un resumen de lo aplicado: cuentas creadas, categorías creadas/reconciliadas, movimientos importados, movimientos omitidos.
- RF-009: La UI `/settings` debe ofrecer "Descargar respaldo" (descarga el JSON) y "Aplicar respaldo" (subir archivo, confirmar con contraseña).
- RF-010: El sistema debe rechazar archivos no-JSON, sin `version`, con `version` no soportada, o sin la estructura mínima, con un mensaje accionable y sin alterar datos.
- RF-011: Tras un import exitoso, la UI debe refrescar el estado (`finance.fetchState`) y reflejar los datos nuevos sin recarga manual.

## Casos principales

- Respaldo y restauración tras reset: el usuario descarga su respaldo, hace hard reset, luego "Aplicar respaldo" → su cuenta vuelve al estado del archivo, con la Bolsa reconciliada.
- Migración a otra cuenta: exporta desde la cuenta A, inicia sesión en la cuenta B (recién creada), aplica el respaldo → la cuenta B queda con los datos de A, asignados al user de B con UUIDs nuevos.
- Descarga simple: el usuario quiere un backup periódico manual; descarga el JSON y lo guarda.

## Casos borde

- Archivo corrupto o no-JSON: rechazo en validación; no se modifica nada.
- Archivo con `version` desconocida: rechazo con mensaje de incompatibilidad.
- Respaldo vacío (sin cuentas ni movimientos): import válido que solo deja la Bolsa vacía; resumen en cero.
- Respaldo sin la Bolsa (archivo manipulado): la Bolsa destino se conserva igualmente (el reset no la borra) y queda sin movimientos del archivo.
- Movimiento con categoría que no existe en el destino: la categoría se crea por reconciliación y el movimiento la conserva.
- Movimiento con referencia a cuenta que no resuelve (archivo manipulado): el movimiento se omite y se reporta en el resumen.
- Monto ≤ 0 o fecha inválida en un movimiento: se omite e informa, sin abortar todo el import.
- Contraseña incorrecta: se rechaza, no se ejecuta el reset ni la restauración.
- Falla a mitad de la restauración: rollback total; la cuenta queda como estaba antes del import (ni reseteada a medias ni a medio restaurar).

## Criterios de aceptacion

- Exportar devuelve un JSON con `version: 1`, `accounts`, `categories`, `entries`, sin soft-deleted ni plan, descargable desde `/settings`.
- Un respaldo exportado y luego importado sobre la misma cuenta reproduce el estado original: mismo número de cuentas activas, categorías y movimientos, y los balances (BO/DE/CR) coinciden con los previos al ciclo export→reset→import (delta 0.00).
- Importar asigna todas las entidades al usuario autenticado y genera UUIDs nuevos (ningún id del archivo persiste como id real).
- Un archivo inválido o de versión incompatible se rechaza con HTTP 422 y mensaje claro, sin alterar la BD.
- El import corre en transacción: si se fuerza un error a mitad, la BD queda como antes del import.
- Import sin contraseña correcta retorna 422 y no ejecuta nada.
- Tras import exitoso, el dashboard refleja los datos sin recarga manual.
- La Bolsa nunca se duplica tras un import.

## Criterios medibles de exito

- Ciclo export → reset full → import deja BO, DE y CR idénticos (delta 0.00) a los previos, para un dataset de al menos 3 cuentas y 20 movimientos.
- El endpoint de export responde en menos de 500 ms para 5 cuentas y 200 movimientos.
- El import de 200 movimientos completa en menos de 2 s en localhost.
- Cobertura de tests ≥ 90% sobre las Actions de export e import, cubriendo los casos borde listados.
- Cero regresiones: la suite backend completa (actual 275) permanece verde tras integrar el feature.

## Riesgos

- **Manejo de filas inválidas**: la spec propone "omitir e informar" para movimientos inválidos, pero abortar ante estructura/versión inválida. Si se prefiere all-or-nothing estricto, ajustar (punto revisable, no bloqueante).
- **Categorías acumulándose**: como el hard reset full no borra categorías, el import reconcilia/crea las del respaldo pero conserva además las categorías actuales que no estén en el archivo (unión). Puede no ser fidelidad estricta al archivo. Documentado como supuesto; ajustable.
- **Archivo de texto plano sin cifrar**: contiene el detalle financiero. Riesgo si se comparte por error. Mitigación: documentar; cifrado fuera de alcance v1.
- **Tamaño del archivo**: para históricos muy grandes el JSON crece; para uso personal no es problema. Si creciera, comprimir/paginar en v2.

## Supuestos

- Formato JSON con `version: 1` y `exported_at` ISO 8601. Identificadores locales por entidad solo para resolver referencias internas del archivo.
- Al importar se regeneran todos los UUID (HasUuids) y se remapean FKs; `user_id` = usuario autenticado.
- Reconciliación de la Bolsa contra la existente (nunca se duplica) y de categorías por nombre (case-insensitive, trim).
- Se reusa `HardResetUserData::execute(userId, 'full')` (conserva Bolsa y categorías) y luego se restaura; los movimientos de la Bolsa del archivo se remapean a la Bolsa existente.
- Filas de movimiento inválidas se omiten e informan; estructura/versión inválida aborta el import completo.
- El import es transaccional (rollback total ante error no recuperable). El reset y la restauración ocurren dentro de la misma transacción.
- La UI vive en `/settings`, sección "Respaldos", separada de la "Zona de peligro" pero en la misma vista.
- Endpoints bajo `/api/finance/*` con middleware `auth:sanctum` + `verified`.
- El export se entrega como descarga JSON; el import recibe el contenido del archivo parseado en el cliente y enviado como JSON al backend (decisión de implementación afinable en el plan).

## Impacto esperado

- **Backend**: dos Actions nuevas (`ExportUserData`, `ImportUserData`) en `Domain/Finance/Actions/`, métodos en `SettingsController`, dos rutas nuevas. Reusa `HardResetUserData` para el reset previo. Sin cambios de schema.
- **Frontend**: sección "Respaldos" en `SettingsView.vue`, helpers en `api/settings.js`, manejo de descarga de archivo y de subida/parseo. Reusa `BaseModal`, `BaseButton`, `BaseInput`.
- **Datos**: ningún cambio de esquema; lectura (export) e inserción transaccional (import). El reset reusa el borrado físico existente.
- **Usuario**: gana red de seguridad para los resets y portabilidad entre cuentas/dispositivos. Cierra el riesgo de irreversibilidad del hard reset.
- **Seguridad**: el import exige contraseña; ambos endpoints scoped por usuario. El archivo es texto plano (resguardo del lado del usuario, documentado).
