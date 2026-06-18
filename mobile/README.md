# FinCore mobile

App Flutter Android **local-first single-user** para llevar una libreta digital de cuentas. SQLite con drift es la única fuente de verdad: sin red en runtime, sin login, sin servidor. Compatible con Android 7.0 (API 24) en adelante.

## Stack

- **Flutter 3.29.3** (Dart SDK ≥ 3.7.2). Targets activos: Android + Linux desktop (este último solo para correr tests).
- **drift ^2.20.0** + codegen (`drift_dev` + `build_runner`).
- **sqlite3_flutter_libs ^0.5.0** (runtime SQLite en Android). En Linux desktop los tests usan `libsqlite3.so.0` del sistema vía `open.overrideFor` en `test/helpers/sqlite_override.dart`.
- **go_router ^14.6.2** con `refreshListenable: FirstRunState` para redirect a `/first-run` cuando la BD está vacía.
- **intl ^0.19.0** con `initializeDateFormatting('es_MX', null)` en `main()` (sin esto el `entry_form_screen` crashea silenciosamente en release).
- **file_picker ^8.1.0** + **share_plus ^10.0.0** para Importar / Exportar JSON.
- **flutter_launcher_icons ^0.14.1** dev dependency para generar iconos adaptive + monochrome.

## Estructura

```
mobile/
├── lib/
│   ├── main.dart                   # DI + SystemChrome + initializeDateFormatting + runApp
│   ├── app_dependencies.dart       # AppDependencies + AppDependenciesProvider (InheritedWidget)
│   ├── router/
│   │   └── app_router.dart         # go_router + FirstRunState + redirect
│   ├── data/
│   │   ├── database.dart           # Tablas drift (Accounts, Categories, JournalEntries) + índices
│   │   ├── database.g.dart         # Generado por build_runner
│   │   ├── uuid.dart               # UUID v7 compatible con Laravel HasUuids
│   │   ├── daos/                   # accounts_dao, categories_dao, entries_dao
│   │   ├── financial_state.dart    # BO/DE/CR + balance por cuenta con customSelect + readsFrom
│   │   ├── seed.dart               # Bolsa + 10 categorías default
│   │   ├── bootstrap.dart          # hasBolsa(db)
│   │   └── backup.dart             # Export + Import + wipeAll (JSON v1)
│   ├── screens/                    # splash, first_run, dashboard, accounts_*, categories_*, entries_*, settings
│   ├── widgets/                    # fincore_logo, account_picker, category_picker, account_balance_hint, skeleton, error_snackbar, kind_picker, base_card, ...
│   ├── models/                     # Modelos del legacy (User, Account, Category, ...) que conviven con drift
│   ├── theme/                      # fincore_colors + fincore_theme (dark)
│   └── constants/                  # kinds, account_types, category_catalog
├── test/
│   ├── helpers/sqlite_override.dart
│   └── data/                       # database_test, financial_state_test, backup_test, invariants_test
├── android/                        # Manifest + build.gradle.kts + iconos
├── assets/icon/                    # icon_full, foreground_1024, monochrome_1024, symbol_only, lockup_horizontal
├── pubspec.yaml                    # Deps + flutter_launcher_icons config + version
├── build.yaml                      # store_date_time_values_as_text: true
└── analysis_options.yaml
```

## Setup desde cero

```bash
# 1. Verificar Flutter
flutter doctor
# Necesitás Flutter 3.29.3 instalado. En este repo, Diego lo tiene en ~/development/flutter/bin

# 2. Instalar deps
cd mobile
flutter pub get

# 3. Generar código de drift
dart run build_runner build --delete-conflicting-outputs
# Outputs: lib/data/database.g.dart

# 4. Correr tests
flutter test
# Debe dar "All tests passed!" con 56 tests verdes.

# 5. Analyze
flutter analyze
# Debe dar "No issues found!" (1 hint cosmético tolerable en skeleton.dart).
```

## Correr en Linux desktop (para iterar UI sin cel)

```bash
flutter run -d linux
```

La BD se guarda en `~/.local/share/fincore/` (path resuelto por `drift_flutter` + `path_provider`).

## Correr en Android (con cel conectado por USB)

```bash
# Asegurate de tener adb instalado
~/Android/Sdk/platform-tools/adb devices
# Debería listar tu cel con estado "device" (no "unauthorized").

# Si dice "unauthorized": en el cel, aceptá el diálogo "Permitir depuración USB" y marcá "Permitir siempre desde este equipo".

# Si dice "no permissions": agregá udev rules para tu vendor ID. Para Xiaomi (2717):
sudo bash -c 'printf "SUBSYSTEM==\"usb\", ATTR{idVendor}==\"2717\", MODE=\"0666\", GROUP=\"plugdev\"\n" > /etc/udev/rules.d/51-android.rules && udevadm control --reload-rules && udevadm trigger'
~/Android/Sdk/platform-tools/adb kill-server
# Desconectá y reconectá el cable USB.

# Correr la app en debug
flutter run -d android

# O build APK release + sideload
flutter build apk --release --split-per-abi
~/Android/Sdk/platform-tools/adb install -r build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

## Generar iconos de launcher

```bash
dart run flutter_launcher_icons
# Lee la config de pubspec.yaml (sección `flutter_launcher_icons:`) y regenera todos los mipmaps + drawables adaptive + monochrome.
```

Si cambiás los PNG en `assets/icon/`, volvé a correr este comando.

## Build release

```bash
flutter build apk --release --split-per-abi
```

Output: `build/app/outputs/flutter-apk/`:

- `app-armeabi-v7a-release.apk` (16-17 MB) — celulares ARM 32-bit antiguos.
- `app-arm64-v8a-release.apk` (~19.5 MB) — **el que se instala en cels modernos**.
- `app-x86_64-release.apk` (~20 MB) — emuladores.

**Importante sobre el versionCode con `--split-per-abi`**: Flutter prepende un código de arquitectura al `versionCode`. Para arm64 → `2000 + versionCode`. Si el cel ya tiene una versión instalada con un código más alto, el install falla con `INSTALL_FAILED_VERSION_DOWNGRADE`. Solución: bumpear `versionCode` en `android/app/build.gradle.kts` y en `pubspec.yaml` antes del build. La constante `kAppVersion` en `lib/screens/settings_screen.dart` se actualiza a mano también para que la pantalla "Acerca de" muestre la versión real.

## Filosofía

- **Libreta libre**: gastos, transfers y cargos a tarjeta se permiten siempre, incluso con saldo negativo. Único bloqueo: `OverpayDebt` (no podés pagar más de lo que debés a una tarjeta).
- **Soft delete terminal**: cuentas, categorías y movimientos archivados/cancelados no se reactivan. Para recuperar algo, importar respaldo previo.
- **Sin reactivación, sin tombstones**: import de respaldo es reemplazo total (`wipeAll()` + insertar todo). Single-user lo permite.
- **Schema compatible con sync futuro**: UUIDs v7 + `created_at`/`updated_at`/`deleted_at` en todas las tablas. No se usa nada SQLite-only.

## Cosas que NO están en este MVP

Ver `engineering/specs/flutter-local-mvp/implementation/pendientes.md`:

- Reportes (`/reports/by-category`, `/reports/cashflow-monthly`, etc.).
- Plan engine con eventos recurrentes.
- Login + sync con backend.
- Multi-usuario.
- Widget tests (T043-T045 aplazados).
- Reactivación de archivados.
- Edición del `kind` de un movimiento.

Estos se atacan cuando aparezca la necesidad real.

## Cómo recuperar el cliente web legacy

```bash
git checkout legacy/web-and-online-flutter
# Ahí están: backend/, frontend/, docker compose stack, cliente Flutter online.
```
