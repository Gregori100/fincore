# Resumen ejecutivo — flutter-local-hardening

## Qué se implementó

Sprint técnico de cleanup y hardening sobre la app FinCore Flutter Android local-first del MVP anterior (`flutter-local-mvp`, commit `44c3614`). 22 RFs en 8 familias, sin features visibles para el usuario. Atacó 20 de los 25 hallazgos no bloqueantes del `branch-quality-review` previo.

Cambios principales:

- **Endurecimiento del import de respaldos**: 6 nuevos códigos de error tipados que validan enums (`kind`, `type`, `applies_to`), montos positivos, longitudes máximas y formato UUID v4/v7 antes de tocar la BD. Mensajes amigables al usuario vía nuevo `backupErrorToMessage`.
- **Privacidad de datos local**: `adb backup` queda bloqueado vía `android:allowBackup="false"` + `dataExtractionRules`. El flujo oficial de respaldo sigue siendo Settings → Exportar JSON.
- **Robustez de migraciones**: bumpeo de `schemaVersion` 1→2 con índice parcial `idx_entries_occurred_active` para mantener `watchPage` rápido con histórico grande; guardrail `UnimplementedError` para que futuros bumps accidentales fallen visibles en QA.
- **Performance**: cache de streams `Map<String, Stream<double>>` en `FinancialStateService` reduce de 15 a 5 los listeners activos del Dashboard con 10 cuentas.
- **UX**: reset destructivo en Settings ahora ofrece "Exportar respaldo y luego reiniciar" como botón primario, con confirmación adicional tras share sheet exitoso. Snackbar warning con texto oscuro sobre amarillo cumple WCAG AA. Iconos críticos con `tooltip` para TalkBack.
- **Mantenibilidad**: `kAppVersion` eliminado; la versión se lee de `PackageInfo` en runtime. CLAUDE.md documenta 4 convenciones nuevas (migraciones, joins con categorías archivadas, `ndkVersion`, deps `^`).

Versión final: `0.3.0+30`. APK arm64: 19.5 MB.

## Impacto esperado

- **Menor superficie de ataque del import**: respaldos malintencionados o corruptos no pueden insertar valores fuera del catálogo. Las validaciones existentes en los DAOs ahora también cierran el bypass del `BackupService.importFromJson`.
- **Privacidad mejorada**: alguien con USB debugging activado sobre el cel desbloqueado ya no puede extraer la BD vía `adb backup`. La superficie real de extracción se reduce al export JSON intencional desde Settings.
- **Performance sostenida en el mediano plazo**: el índice parcial garantiza que la lista de movimientos se mantenga rápida hasta 50k+ entries. El cache de streams baja la presión sobre Drift cuando hay muchas cuentas activas.
- **Mantenimiento más simple**: el bump de versión pasa de 3 lugares a 2; cualquier futuro PR que toque schema sin migrar fallará visiblemente.
- **Cero impacto visible para el usuario** salvo dos micro-cambios validados en smoke: dos botones en el reset destructivo y texto oscuro en el snackbar warning.

## Riesgos o pendientes relevantes

- **T023 (smoke manual) queda pendiente de Diego**: instalar APK arm64 sobre `0.2.0+29` y validar 7 puntos. Bloqueante para cerrar el sprint con commit a `main`.
- **Downgrade `0.3.0+30` → `0.2.0+29` no soportado**: BD migrada a `schemaVersion = 2` no se puede abrir con código que espera 1.
- **5 hallazgos fuera de alcance explícitos**: M6 (firma release Play Store), M11 (export streaming), M17 (filtro por categoría = feature), M19 (hints cosméticos), M24 (typing fantasma DropdownMenu), M25 (loader progreso import).
- **Widget tests siguen aplazados** desde el MVP. Conviene atacarlos en sprint específico de coverage UI.

## Estado de pruebas

- **`flutter test`**: **81 tests verdes** (de 59 → 81, **+22 tests nuevos**: 1 cancel idempotente con balance + 6 transiciones updateEntry + 10 validaciones import + 5 cache de streams).
- **`flutter analyze`**: 0 errores, 0 warnings (4 hints info cosméticos no bloqueantes).
- **`flutter build apk --release --split-per-abi`**: 3 APKs generados sin errores.
- **Verificación con aapt**: `versionCode='2030'`, `versionName='0.3.0'`, `allowBackup=0x0` (false), `dataExtractionRules` apunta correctamente al recurso.
- **Smoke manual T023**: pendiente de Diego.
- **`branch-quality-review` T025**: se invoca al cierre.
