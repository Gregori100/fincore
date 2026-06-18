# Pendientes — flutter-local-mvp

Detalles que Diego anotó durante el smoke y que conviene retomar en sprints futuros. No son blockers del MVP, son polish y mejoras incrementales.

## UI/UX

- **Widget tests para flujos críticos**: el smoke iterativo detectó 3 bugs UI (form blanco, navegación con stack duplicado, snackbar dismiss) que no estaban cubiertos por los tests de datos. Para próximos sprints, agregar widget tests al menos para:
  - `entry_form_screen` bootstrap (verifica que renderiza los pickers con `es_MX` locale activo).
  - `accounts_list_screen` y `entries_list_screen` con stream loading → skeletons → data.
  - `first_run_screen` flujos de Importar y Arrancar limpio.
- **Confirmación visual del snackbar**: si Diego nota que el snackbar verde de éxito tras `go('/dashboard')` aparece desfasado, una alternativa robusta es no mostrar snackbar antes del navigate, sino pasar un `?flash=ok` query param a la siguiente ruta y leerlo allí.

## Funcionalidad

- **Reactivación de archivados**: hoy el archive es terminal. Si Diego archivó por error una cuenta o categoría, la única recuperación es importar un respaldo previo. Evaluar agregar pantalla "Archivados" con botón "Reactivar" si crece la demanda.
- **Edición de `kind` en movimiento**: hoy bloqueado por contrato del DAO porque cambiar el kind requiere revalidar origen/destino/categoría. Para habilitarlo: refactor de `UpdateJournalEntry` que reciba un nuevo objeto completo en lugar de patches, y revalide todo el bloque.
- **Multi usuario / multi cuenta**: la app es single-user por diseño. Si Diego presta el cel, ambos comparten BD. Evaluar partición lógica con `userId` en cada tabla cuando aparezca el caso real.
- **Sync con backend (spec futura)**: Diego mencionó que en el futuro querrá login + sync de respaldos. Es una spec separada cuando llegue el momento. El schema actual ya está preparado (UUIDs v7, soft delete, timestamps).
- **Reportes y exportes a Excel**: el cliente Vue legacy tenía `/reports/by-category`, `/reports/cashflow-monthly`, `/reports/credit-cards`, `/reports/budgets`, `/reports/forecast`, `/reports/by-account`, `/reports/month-comparison` + exports XLSX. Ninguno está en este MVP. Cuando se vuelvan a necesitar, replicarlos como pantallas locales que lean los streams de drift.
- **Plan engine** (proyección a 6 meses con eventos recurrentes + overrides): tampoco está en este MVP. Era una feature del backend legacy.

## Refactors menores

- **Modelos duplicados** entre `lib/models/` (clases del legacy con `fromJson`) y drift (clases generadas). Hoy conviven porque widgets reutilizables tipan contra los del legacy. Refactor: pasar todos los widgets a usar drift directamente y borrar `lib/models/`.
- **`flutter_launcher_icons.yaml` duplica config con pubspec.yaml**: ambos archivos tienen los paths del icon. Borrar el yaml externo (`assets/icon/flutter_launcher_icons.yaml` si existe) y dejar solo el bloque dentro de `pubspec.yaml` para no desincronizar.
- **`kAppVersion` constante en `settings_screen.dart`**: hoy se actualiza a mano cada release. Refactor: leer desde `package_info_plus` para que siempre matchee con `pubspec.yaml`.

## Tooling

- **Pipeline CI**: hoy todo se buildea localmente. Para distribución a otros (familia, amigos) conviene agregar un workflow de GitHub Actions que builde APKs en cada tag.
- **Firma de release**: el APK actual está firmado con la clave debug de Sail. Si Diego decide publicar en Play Store o distribuir vía F-Droid, generar una clave de release real y agregar `signingConfigs.release` en `android/app/build.gradle.kts`.

## Documentación

- **`mobile/README.md`**: creado en T052 con setup, build, tests. Si Diego cambia de máquina, revisar que los pasos sigan funcionando con Flutter SDK más reciente.
- **CHANGELOG**: hoy las versiones 0.2.0+1 → +27 están en el git log y en los comentarios de pubspec.yaml, pero no hay un changelog formal. Si la cadencia de releases crece, agregarlo.
