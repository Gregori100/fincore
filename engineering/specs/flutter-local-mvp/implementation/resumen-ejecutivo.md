# Resumen ejecutivo — flutter-local-mvp

## Qué se implementó

FinCore pivotó de cliente Flutter online sobre backend Laravel (vía Tailscale) a **app Flutter Android local-first single-user** estilo Obsidian: SQLite con drift como única fuente de verdad, sin red, sin login, mismo modelo de dominio que el backend legacy (cuentas, categorías, journal entries con UUID v7, soft delete, libreta libre).

El sprint cubre:

- Preservación del legacy en la rama `legacy/web-and-online-flutter` (backend Laravel, frontend Vue, cliente Flutter online, stack Docker, scripts CLI). `main` queda con solo `mobile/`.
- Reconstrucción del cliente desde cero con Flutter 3.29.3 + drift 2.20 + go_router 14.6, replicando la identidad visual (tema oscuro, paleta accent #4CABDB) y el catálogo de 10 categorías default del backend.
- Soporte de respaldo JSON v1 compatible bit a bit con `/api/finance/backup/export` del backend legacy, así Diego puede importar respaldos antiguos sin perder datos.
- Pantalla "Primer arranque" con dos puertas: Importar respaldo o Arrancar limpio.
- APK release firmado de 19.5 MB instalado en Redmi de Diego y validado con smoke manual completo (los 5 kinds + edit + cancel + offline + export/import).

## Impacto esperado

- **Eliminación de fricción de red**: el principal motivo del pivote era que la app cliente online dependía de la laptop encendida + Tailscale + cert TLS válido en el momento de captura. La nueva app funciona sin red en runtime, lo que devuelve la usabilidad cotidiana.
- **Resiliencia ante migraciones futuras**: schema diseñado con UUIDs v7 + `created_at`/`updated_at`/`deleted_at` en todas las tablas, soft delete, sin features SQLite-only. Permite agregar sync con backend en un futuro sprint sin reescribir el modelo.
- **Recuperabilidad**: respaldo JSON manual (Settings → Exportar) + restauración desde primer arranque. El usuario es responsable de mantener un JSON al día en un lugar seguro (Drive, email).

## Riesgos o pendientes relevantes

- **Widget tests aplazados** (T043-T045): la capa de datos tiene 56 tests verdes, pero la UI no tiene cobertura automatizada. Varios bugs UI de release solo se detectaron en smoke real (DateFormat sin initializeDateFormatting, navegación con stack duplicado, snackbar dismiss). Para el próximo sprint conviene agregar widget tests para flujos críticos.
- **Sin sync con backend**: por diseño y por decisión del 2026-06-17, Diego arrancó la BD local desde cero, sin importar movimientos previos del backend Laravel.
- **APK release firmado con clave debug**: suficiente para sideload en el Redmi de Diego. Distribución por Play Store o uso público requiere clave de release real, que es scope aparte.
- **Sin reactivación de archivados**: cuentas y categorías archivadas son terminales por diseño (consistente con backend legacy). Si Diego archivó algo por error, debe importar un respaldo previo o crear una entidad nueva.

## Estado de pruebas

- **`flutter analyze`**: 0 errores, 0 warnings (1 hint cosmético `prefer_const_constructors` en `skeleton.dart:75` que no afecta).
- **`flutter test`**: **56 tests en verde** (29 schema + DAOs, 12 financial_state, 7 backup, 8 invariants).
- **Smoke manual**: Diego validó alta de los 5 kinds, edición, cancelación, modo avión, export + import round-trip, reset de cuenta. Reportó 17 polish/bugs UX durante el smoke, todos corregidos en iteraciones incrementales del APK (versiones 0.2.0+4 → +27).
- **Branch-quality-review**: ejecutado al cierre del sprint; ver `engineering/quality-review/flutter-local-mvp/` para el reporte completo.
