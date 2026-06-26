# Resumen extenso — flutter-integration-tests-v1

## Contexto

Sprint 1 del ciclo de **deuda técnica** post-pivote-local. Apunta a uno de los
tres frentes priorizados:

1. **Migrar widget tests diferidos a integration tests** ← este sprint.
2. Refactor `EntriesListScreen` (siguiente).
3. Diagnóstico profundo del cuelgue de `pumpAndSettle` (último, incierto).

Disparador concreto: en `flutter-movements-pagination-v1` (patch v1) se
descubrió que el package `integration_test` corriendo en runtime real
(Linux desktop / Android device) evita el cuelgue sistémico de
`pumpAndSettle` con `pumpFincoreApp` + filtros drift. Con el patrón
probado en 3 tests del scroll infinito, este sprint extiende el approach a
los widget tests diferidos acumulados en sprints anteriores.

## Tests migrados

**14 tests nuevos** distribuidos en 4 archivos nuevos en `mobile/integration_test/`:

### `account_form_test.dart` (5 tests)

Cubre el scope `DV-2/RF-020` del `flutter-local-hardening-v4` (CRUD de
cuentas). Quedó diferido por cuelgue con 10-12 min de timeout por test.

- **AF-01**: alta debit "Banco BBVA" → cuenta en BD con `type=debit`.
- **AF-02**: nombre vacío → validator inline "Ingresá un nombre.".
- **AF-03**: nombre duplicado → snackbar `duplicate_account_name`.
- **AF-04**: edición de Bolsa → `_ProtectedView` read-only.
- **AF-05**: alta credit con metadata válida (límite, día de corte, día de
  pago) persiste todo.

### `category_form_test.dart` (5 tests)

Cubre el scope `DV-2/RF-022` (CRUD de categorías).

- **CF-01**: alta con nombre + defaults → categoría persistida.
- **CF-02**: nombre vacío → validator inline.
- **CF-03**: nombre duplicado → snackbar `duplicate_category_name`.
- **CF-04**: edición cambia el nombre y persiste.
- **CF-05**: archive desde edit → `deletedAt` seteado, `findActiveById`
  retorna null.

### `entries_filters_panel_test.dart` (2 tests)

Cubre el scope `M10` del MVP + `DV-2/RF-021`. Panel de filtros con cuentas
y categorías sembradas + multi-select funcional.

- **FP-01**: panel rinde 2 cuentas (Bolsa + debit "BBVA") + categoría
  custom como chips.
- **FP-02**: aplicar filtro por cuenta refresca la lista (entries de otra
  cuenta quedan fuera).

### `settings_destructive_test.dart` (2 tests)

Cubre el scope `DV-2/RF-023` (confirmaciones destructivas).

- **SD-01**: cancelar el ConfirmDialog destructivo NO ejecuta wipe (BD
  intacta).
- **SD-02**: confirmar con "Borrar todo igual" SÍ ejecuta wipe (BD vacía).

## Patrón usado

Replica el setup ya validado en `mobile/integration_test/movements_pagination_test.dart`:

```dart
late FincoreDatabase database;
late AppDependencies deps;
late FirstRunState firstRunState;
late GoRouter router;

setUp(() async {
  database = FincoreDatabase(NativeDatabase.memory());
  deps = AppDependencies.fromDatabase(database);
  await initializeDateFormatting('es_MX', null);
  await seedDefaults(...);
  firstRunState = FirstRunState();
  firstRunState.value = true;
  router = buildAppRouter(deps: deps, firstRunState: firstRunState);
});

tearDown(() => database.close());

Widget buildApp() => AppDependenciesProvider(
  deps: deps,
  child: FirstRunStateProvider(
    state: firstRunState,
    child: MaterialApp.router(theme: fincoreDarkTheme(), routerConfig: router),
  ),
);
```

Cada test seedea datos via DAOs, pumpea la app, navega con
`GoRouter.of(ctx).push('/X')`, interactúa con widgets reales y verifica
ambas: UI (`find.text(...)`) y BD (`deps.<dao>.<query>`). La verificación
en BD es **más robusta** que en UI tras un pop de navegación, así que se
usa siempre que el outcome del flujo persista en SQLite.

## Tests diferidos NO migrados

Documentados para futuros sprints:

- **M3 (deep link via URL manual)**: cubierto indirectamente por
  `reports_deeplink_test.dart`. URL manual no es flujo productivo
  (Diego no escribe URLs). Skippeado intencionalmente.
- **T027/T028 (DatePicker)**: nativo difícil de automatizar incluso en
  runtime real. Pendiente con incierto.
- **RF-019 / DV-1 (dropdown content per kind)**: la verificación del
  contenido del DropdownMenu por kind. ROI medio (la validación RN-011
  ya está cubierta en data layer). Pendiente.

## Cambios productivos

**Cero**. Sólo agregan tests + bump de versión.

## Validación

- `flutter test`: **217/217 unit/widget verdes** (sin regresión).
- `flutter test integration_test/ -d linux`: **17 integration verdes**
  (3 de paginación previos + 14 nuevos).
- `flutter analyze`: 0 errores, 4 hints `info` pre-existentes (cosméticos).
- APK `0.6.3+55` construido + `verify-apk.sh` OK
  (versionCode 2055 / versionName 0.6.3 consistentes).

## Riesgos residuales

- **RR-01** (bajo): los integration tests son ~3x más lentos que widget
  tests (build inicial de ~12s + runtime per archivo ~15-30s). Si la suite
  crece mucho, podría requerir paralelización o split entre CI/local.
- **RR-02** (bajo): Linux desktop como runtime de tests no es 100%
  equivalente a Android (sin SQLite version mismatch hasta hoy, sin
  diferencias de comportamiento detectadas). Para máxima fidelidad,
  correr periódicamente con `-d android` en cel conectado.

## Comandos

```bash
cd mobile

# Suite unit + widget tests.
flutter test

# Integration tests en Linux desktop.
flutter test integration_test/ -d linux

# Un archivo específico.
flutter test integration_test/account_form_test.dart -d linux

# En Android conectado (~3x más lento por build).
flutter test integration_test/ -d <android-device-id>
```
