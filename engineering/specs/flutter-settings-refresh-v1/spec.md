# Settings refresh (Sprint 9 acotado)

## Resumen

Sprint 9 del roadmap 2026-07-14 con scope acotado a 2 hallazgos de mayor impacto:

- **Import con DestructiveDialog** (audit P1.1): la acción con mayor blast radius de la app (reemplaza toda la BD) usaba `showConfirmDialog` M2 genérico. Migrada al `showDestructiveDialog` premium con hero icon + chips de impacto + copy específico.
- **Zona peligrosa visualmente destacada** (audit P1.2): `BaseCard` con border rojo tinted (alpha 0.4, width 1.5). El SectionTitle sigue igual — el border es suficiente para telegrafiar "esto es distinto".

**Scope reducido**: reorden completo de secciones (Ayuda antes que Zona peligrosa), Ayuda con search + agrupación + deep-links, Acerca de con diagnóstico, Legacy como ExpansionTile — todos diferidos.

Bump `0.25.2+104` → `0.25.3+105` (patch, último sprint del roadmap 2026-07-14).

## Alcance

- `settings_screen.dart` `_import()`: reemplaza `showConfirmDialog` por `showDestructiveDialog` con impacts (4 chips: cuentas, categorías, movimientos, vistas guardadas). File picker se ejecuta ANTES del dialog para poder mostrar el nombre del archivo como `objectName`. `confirmLabel: 'Reemplazar mi BD'`.
- `settings_screen.dart` BaseCard de Zona peligrosa: `borderColor: FincoreColors.negative.withValues(alpha: 0.4)`, `borderWidth: 1.5`.
- Import `destructive_dialog.dart` agregado.

## Fuera de alcance

- Reorden de secciones (Ayuda ↑, Zona peligrosa ↓, Legacy como expansion).
- Ayuda con search + agrupación + deep-links.
- Acerca de con diagnóstico / bug report / changelog.
- Reset sin exportar migrado a DestructiveDialog (menos prioritario porque ya tiene 2 confirmaciones).
- Preferences con dropdown M3.

## Requisitos

- **RF-001**: `_import()` usa `showDestructiveDialog` con 4 impacts + objectName del archivo picked.
- **RF-002**: BaseCard de Zona peligrosa con `borderColor: negative.withValues(alpha: 0.4)` y `borderWidth: 1.5`.
- **RF-003**: bump `0.25.3+105`.
- **RF-004**: `flutter test` 707/707 verdes.

## Impacto

- El import destructivo ahora comunica gravedad con la misma UX que archivar cuenta con movimientos (patrón consistente).
- Zona peligrosa visualmente diferenciable a un vistazo.
