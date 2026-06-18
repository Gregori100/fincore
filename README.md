# FinCore

Libreta digital de cuentas. App Flutter Android **local-first single-user**: SQLite con drift como única fuente de verdad, sin red en runtime, sin login.

> _"Tu libreta digital de cuentas."_

## Estado actual

Sprint `flutter-local-mvp` cerrado. APK release **0.2.0+27** instalado y validado en Redmi. Toda la app vive en [`mobile/`](./mobile/README.md). Detalles del modelo, dominio y stack en [`CLAUDE.md`](./CLAUDE.md).

## Quick start

```bash
cd mobile
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter test                       # 56 tests verdes
flutter run -d linux               # iterar en desktop
# o:
flutter build apk --release --split-per-abi
~/Android/Sdk/platform-tools/adb install -r build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

Setup completo y troubleshooting en [`mobile/README.md`](./mobile/README.md).

## Estructura

```
fincore/
├── mobile/        # Único producto activo en main: app Flutter local
├── engineering/   # Specs, planes, implementación, quality reviews
├── CLAUDE.md      # Guía de dominio y stack para Claude Code
└── README.md      # Este archivo
```

## Filosofía

- **Libreta libre**: gastos, transfers y cargos a tarjeta se permiten siempre, incluso con saldo negativo. Único bloqueo: no pagar más de lo que se debe a una tarjeta.
- **Local-first**: el archivo SQLite es el producto. La app respalda a JSON y restaura desde JSON. No depende de un servidor.
- **Single user**: una BD por cel, sin login ni multi-tenancy.
- **Schema sync-ready**: UUIDs v7, soft delete, timestamps en todo. Cuando aparezca la necesidad de sync, será una spec aparte; el modelo ya está preparado.

## Cliente web legacy (Vue + Laravel)

El backend Laravel, frontend Vue, cliente Flutter online y stack Docker viven en la rama [`legacy/web-and-online-flutter`](../../tree/legacy/web-and-online-flutter). Conservados por si en algún momento se necesita consultar la arquitectura previa o exportar JSON de la BD productiva original.

```bash
git checkout legacy/web-and-online-flutter
```

## Specs y trazabilidad

- `engineering/specs/flutter-local-mvp/spec.md` — qué se construyó y por qué.
- `engineering/specs/flutter-local-mvp/plan/` — plan técnico + tasks + test-plan.
- `engineering/specs/flutter-local-mvp/implementation/` — progreso, desviaciones, resúmenes, review final.
- `engineering/quality-review/flutter-local-mvp/` — branch-quality-review al cierre.
