# Migración a integer cents para precisión monetaria (flutter-integer-cents-v1)

## Resumen

Migra todos los montos monetarios de FinCore de `double` (SQLite `REAL`, IEEE 754) a `int` en centavos. Elimina de raíz los errores de precisión que hoy solo se mitigan con tolerancias parche (ej. `overpay_debt + 0.005` del hotfix 0.32.1+120). Los balances derivados vía `SUM(amount)` en SQLite pasan a ser matemáticamente exactos; las comparaciones directas `>` / `==` / `<` recuperan sentido semántico sin tolerancias artificiales.

El cambio es transversal: schema (v14), tipo Dart de dominio, todos los DAOs, todos los forms, todos los reportes agregados, backup JSON, y todos los tests. Los ratios `0-1` (`interest_rate`, `minimum_payment_pct`, `minimum_capital_pct`) NO son montos y quedan como `REAL` — la migración solo afecta valores en moneda.

Diego (único usuario) ya tiene 158 entries reales, 5 cuentas, 20 categorías, 1 préstamo. Suma agregada actual $207,916.25. El respaldo se hizo hoy 2026-07-24 en `~/Descargas/fincore-backup-2026-07-24.json`. El análisis del respaldo confirma que **cero valores actuales tienen más de 2 decimales** — la conversión `round(v * 100)` es matemáticamente limpia sobre el dataset real.

## Problema a resolver

FinCore guarda todos los montos como `REAL` en SQLite y los manipula como `double` en Dart. `double` es IEEE 754 de 64 bits y **no puede representar exactamente valores decimales comunes** como `0.1`, `0.2`, `173.77`. Las operaciones aritméticas acumulan error, especialmente en operaciones repetidas de suma/resta.

Consecuencias observadas y potenciales:

1. **Bug reportado (2026-07-24)**: Diego intentó pagar exactamente $173.77 de una tarjeta de crédito. La deuda derivada internamente estaba en `173.7699999...` por acumulación de floats sobre múltiples cargos. La validación `amount > deuda` sin tolerancia rechazó el pago con `overpay_debt`. Diego tuvo que pagar $172 + $1.77 en dos operaciones. Hotfix aplicado en 0.32.1+120 (agregó `+ 0.005`), pero es parche.
2. **`overpay_loan` tenía el mismo bug**: ya parcheado con `+ 0.005` en `registerLoanPayment` y `updateLoanPayment` desde `flutter-loans-v1`. Otro parche.
3. **Reportes agregados frágiles**: `spendingByCategory`, `incomeByCategory`, `cashflow`, `financial_state` hacen `COALESCE(SUM(amount), 0)`. En INTEGER estas sumas son exactas; en REAL acumulan error proporcional al número de entries sumadas.
4. **Backup round-trip lossy**: export a JSON serializa `double`, import parsea de vuelta a `double`. Cada round-trip puede introducir microerrores. Con integer cents el JSON emite números exactos.
5. **Riesgo latente en features futuras**: cada nueva comparación de montos que no aplique tolerancia hereda el bug. La única solución sostenible es eliminar la causa.

Adicionalmente, este cambio es un prerrequisito arquitectónico para features de precisión fina (moratorios de préstamos con cálculo diario, split de gastos entre cuentas, cash flow con precisión al centavo).

## Objetivo

Eliminar completamente los errores de precisión monetaria en FinCore, cumpliendo las siguientes capacidades verificables:

1. Todos los balances derivados (`accountBalanceNow`, `watchAccountBalance`, `LoansDao.balanceOf`, `FinancialStateService.watchBo/watchDe/watchCr`) son matemáticamente exactos: `Σ cargos − Σ pagos` en INTEGER da el centavo exacto sin residuo IEEE 754.
2. Todas las comparaciones de montos vuelven a ser semánticamente estrictas: `amount > deuda`, `amount == balance`, `amount < minimum` sin necesidad de tolerancias `+ 0.005`. Las tolerancias del código anterior se eliminan.
3. Los reportes agregados (`spendingByCategory`, `incomeByCategory`, `cashflow`, `monthly_average`, etc.) suman al centavo exacto con cualquier número de entries.
4. El backup JSON preserva y restaura montos sin pérdida de precisión (round-trip export → wipe → import es identidad matemática).
5. El backup real de Diego (`fincore-backup-2026-07-24.json`) importa post-migración sin errores y todas las agregaciones cuadran contra su suma pre-migración de $207,916.25 (→ `20,791,625` centavos).
6. La migración incluye backup automático pre-schema-change guardado en el filesystem del cel para rollback manual si algo falla.
7. Todos los tests existentes (867 al inicio del sprint) siguen pasando post-refactor.

## Alcance

### Schema (v14)

Columnas monetarias que migran `REAL → INTEGER` (centavos, `NOT NULL DEFAULT 0` donde ya lo eran, o `NULLABLE` donde ya lo eran):

- **`journal_entries`**:
  - `amount INTEGER NOT NULL` (era `REAL NOT NULL`).
  - `principal_amount INTEGER` (nullable, era `REAL`).
  - `interest_amount INTEGER` (nullable, era `REAL`).
- **`accounts`**:
  - `credit_limit INTEGER NOT NULL DEFAULT 0` (era `REAL NOT NULL DEFAULT 0`).
  - `minimum_floor INTEGER NOT NULL DEFAULT 15000` (era `REAL NOT NULL DEFAULT 150`; el default preserva $150 = 15000 centavos).
- **`loans`**:
  - `principal_amount INTEGER NOT NULL` (era `REAL NOT NULL`).
  - `monthly_payment INTEGER NOT NULL` (era `REAL NOT NULL`).
- **`weekly_budget_items`**:
  - `amount INTEGER NOT NULL` (era `REAL NOT NULL`).
- **`categories`**:
  - `monthly_limit INTEGER` (nullable, era `REAL`).

Columnas que **NO migran** (son ratios `0-1` o factores decimales, no montos):

- `accounts.interest_rate REAL` — tasa anual como decimal 0-1.
- `accounts.minimum_payment_pct REAL` — porcentaje del pago mínimo.
- `accounts.minimum_capital_pct REAL` — porcentaje del capital mínimo.

### Migración

- `schemaVersion` bumpa `13 → 14`.
- Rama principal `if (from == 13 && to == 14)` en `MigrationStrategy.onUpgrade`. Ejecuta en orden:
  1. **Backup automático pre-migración**: exporta el estado actual (v2 con doubles) a `<app_documents_dir>/fincore-pre-v14-YYYYMMDD-HHmmss.json`. Si el export falla, aborta la migración. El path del backup queda accesible desde Settings para que Diego lo pueda compartir/mover.
  2. Recrear cada tabla con nuevo schema `INTEGER`, migrando datos con `CAST(ROUND(<col> * 100) AS INTEGER)`. SQLite no soporta `ALTER COLUMN TYPE`, así que la conversión es por `CREATE TABLE new + INSERT ... SELECT + DROP old + ALTER RENAME`.
  3. Re-crear todos los índices no-declarados en Dart (mismos que `onCreate` originalmente crea vía `customStatement`).
- Ramas defensivas para saltos multi-versión desde `from ∈ {5, 6, 7, 8, 9, 10, 11, 12} && to == 14` — reutilizan los helpers existentes (`_createLoansSchema`, `_createWeeklyBudgetTablesRefactored`, etc.) + añaden el paso de conversión a integer al final. Guardrail `UnimplementedError` se conserva.
- La migración es **idempotente** por probe: si detecta que las columnas ya son INTEGER (via `pragma_table_info` con `type = 'INTEGER'`), el paso se omite. Bloquea la doble ejecución en caso de crash mid-migration.

### Tipo Dart de dominio

- Se define `int` como el tipo canónico de moneda en centavos. **Sin wrapper `Money`** — el overhead de creación de objetos + tuple unwrap por operación no compensa en aritmética tan simple, y drift acepta `int` directamente. Decidido en P-001.
- Convención de nombres: variables monetarias mantienen sus nombres actuales (`amount`, `principalAmount`, `creditLimit`, etc.) pero cambian de tipo `double → int`. El compilador Dart ayuda a encontrar cada uso.
- **Sin alias tipográfico** (`typedef Cents = int`): Dart no lo enforza en firmas y no ayuda al compilador. La documentación en `CLAUDE.md` deja explícita la convención.

### Helpers de conversión I/O

- Nuevo módulo `mobile/lib/utils/money.dart` con:
  - `int parseCents(String input)` — parsea un string ingresado por el usuario ("173.77", "173,77", "1500", "1,500.50") a centavos. Rechaza inputs con más de 2 decimales.
  - `String formatCents(int cents, {bool showSign = false, bool omitZeroDecimals = false})` — reemplaza al actual `formatAmount(double)` con firma equivalente pero tipo int. Devuelve "$173.77" o "-$173.77" según flags.
  - `int centsFromDouble(double dollars)` — SOLO para migración schema y para import de backup legacy (v1/v2 con doubles). Usa `(dollars * 100).round()` — nunca `.toInt()` (que truncaría).
  - `double centsToDouble(int cents)` — SOLO para export de backup legacy (mantener compat con formato v1/v2 Laravel). Devuelve `cents / 100.0`.

### Backup JSON

- Bumpa formato a **v3**: emite montos como `int` centavos directamente. Ejemplo: `{"amount": 17377}` en vez de `{"amount": 173.77}`.
- Import acepta v1, v2 y v3. Al importar v1/v2 (con `double`), convierte cada monto a cents vía `centsFromDouble` en la validación. Al importar v3, usa el valor int directamente (rechaza si no es int con error tipado `invalid_amount_format`).
- Export siempre emite v3. El backup automático pre-migración es el ÚLTIMO export en formato v2 que la app emite.
- Decidido en P-002 (backup v3 con integer cents).

### Refactor de DAOs

- **EntriesDao**: `registerIncome`, `registerExpense`, `registerCreditExpense`, `registerDebtPayment`, `registerTransfer`, `registerLoanPayment`, `updateEntry`, `updateLoanPayment`, `bulkUpdateCategory` (este último no toca amounts, no cambia). Signatures cambian `double amount → int amount`. Validaciones internas actualizan tolerancias — todas las comparaciones vuelven a ser estrictas sin `+ 0.005`.
- **AccountsDao**: `create`, `updateAccount` — `double creditLimit → int creditLimit`.
- **LoansDao**: `create`, `updateLoan`, `balanceOf`, `applyPaymentSideEffects` — `double → int` en `principalAmount`, `monthlyPayment`. `balanceOf` devuelve `int` (centavos).
- **WeeklyBudgetsDao**: `addItem`, `updateItem`, `watchBudgetBalance` — `double → int`.
- **CategoriesDao**: `create`, `updateCategory` — `Value<double> monthlyLimit → Value<int> monthlyLimit`.
- **FinancialStateService**: `accountBalanceNow`, `watchAccountBalance`, `watchBo`, `watchDe`, `watchCr` devuelven `int`. Las queries `customSelect` sobre `SUM(...)` leen `int` directamente de SQLite (ya devuelve INTEGER post-migración).
- **ReportsService** (`incomeByCategory`, `spendingByCategory`, `cashflow`, `monthlyAverage`, `topMovements`, `balanceAtDate`, `heatmaps`): todas las agregaciones cambian `double → int`. Las divisiones para promedios/porcentajes se calculan como `int` en el numerador y devuelven `double` solo si la UI necesita mostrar decimales (ej. porcentaje del total).

### Refactor de UI

Cada form que hoy parsea/muestra montos:

- `entry_form_screen.dart` — parse via `parseCents`, display via `formatCents`.
- `account_form_screen.dart` — `credit_limit` field.
- `loan_form_screen.dart` — `principal_amount`, `monthly_payment`.
- `loan_monthly_payment_form.dart` + `loan_capital_payment_form.dart` — split principal+interest.
- `weekly_budgets/widgets/budget_item_form_sheet.dart` — `amount`.
- `categories/category_form_screen.dart` — `monthly_limit`.

Widgets de display (leen/muestran, no parsean):

- `movement_row.dart`, `dashboard_screen.dart`, `entries_paginated_list.dart`, `loan_detail_screen.dart`, `spending_by_category_tab.dart`, `cashflow_tab.dart`, `top_movements_tab.dart`, `credit_cards_tab.dart`, `income_by_category_tab.dart`, `budgets_tab.dart`, `budgets/detail_screen.dart` (subtotal cascada), `budgets/list_screen.dart` (balance inline).

`AccountBalanceHint` y `BalanceFooter` reciben `int` desde el stream y muestran via `formatCents`.

### Tests

- Refactor de todos los tests que usan literales `double` para amounts (`amount: 100.50` → `amount: 10050`). Estimo ~300 líneas de test tocadas distribuidas en 15+ archivos.
- Nuevos tests específicos del sprint:
  - **UT-IC-01**: `parseCents` — inputs válidos ("100", "100.5", "100.50", "1,500.75") y rechazos (">2 decimales", "abc", negativos, vacío).
  - **UT-IC-02**: `formatCents` — cobertura de `showSign`, `omitZeroDecimals`, ceros, negativos, millones.
  - **UT-IC-03**: `centsFromDouble` — round-trip contra `centsToDouble` para grid de valores incluyendo `173.77`, `0.1 + 0.2`, negativos, cero.
  - **MG-IC-01**: migración 13 → 14 sobre BD con 158 entries generadas por seeds → 158 entries INTEGER, `SUM(amount)` cuadra contra el valor original × 100.
  - **MG-IC-02**: migración crea backup automático en el filesystem antes de tocar el schema. Fallo simulado del export aborta la migración sin cambiar nada.
  - **BK-IC-01**: import del fixture sintético `test/fixtures/synthetic-backup-v2.json` (158 entries, montos con residuos IEEE 754 intencionales) → todas las entries importadas, `SUM(amount)` cuadra contra el oracle del fixture.
  - **BK-IC-02**: round-trip v3 export → wipe → v3 import es identidad matemática (todos los amounts idénticos byte a byte).
  - **BK-IC-03**: import de backup v1/v2 legacy (con doubles) convierte correctamente vía `centsFromDouble`.
  - **BK-IC-04**: import de backup v3 con `amount` no-integer (ej. float en JSON) lanza `invalid_amount_format`.
- Eliminar los tests que validan tolerancias `+ 0.005`: `overpay_debt` y `overpay_loan` vuelven a comparaciones estrictas.

### Ordenamiento del refactor

Debido al tamaño (10-15h + planning), la implementación se hace en **fases con commits granulares**, pero como **un solo sprint monolítico** — no partido en 2. Decidido en P-005.

Orden sugerido:

1. Helpers `money.dart` + tests (no toca nada más).
2. Schema v14 + migración + tests de migración.
3. DAOs (bottom-up: `AccountsDao`, `CategoriesDao`, `LoansDao`, `WeeklyBudgetsDao`, `EntriesDao`, `FinancialStateService`, `ReportsService`).
4. UI (bottom-up: widgets de display primero, forms después).
5. Backup v3 export + import backward-compat + tests round-trip.
6. Suite completa verde + fixture del respaldo de Diego.
7. Bump a `0.33.0+121` + build APK.

## Fuera de alcance

- Ratios `0-1` (`interest_rate`, `minimum_payment_pct`, `minimum_capital_pct`) siguen como `REAL`. Migrarlos a basis points (integer × 10000) es un sprint separado si algún día se necesita precisión también ahí. Hoy no hay uso operativo de esos campos en UI (RF-018 del sprint `flutter-reports-credit-cards-v1` los dejó en schema sin exposición).
- Formatos de moneda distintos a MXN. Hoy `formatAmount` hardcodea `$` y separador de miles con coma. No cambia.
- Locales distintos a `es_MX` para parsing/formatting. Sigue como hoy.
- Multi-currency. Fuera del scope actual y del roadmap.
- Import de backups de otros formatos (CSV, OFX, QIF, Excel). Sigue siendo solo JSON.
- Precisión sub-centavo (milésimas, décimas de centavo). El único uso posible sería en cálculos de interés diario proporcional; no aplica al modelo actual de FinCore.
- Migración de datos externos al backup JSON. Diego hace backup previo y la migración corre solo sobre su BD local.

## Reglas de negocio

- **RN-IC-01**: `int` es el tipo canónico de moneda en centavos. Cero uso de `double` para valores monetarios en el modelo de dominio, DAOs, ReportsService o UI.
- **RN-IC-02**: `double` sigue siendo válido SOLO para ratios `0-1` (`interest_rate`, `minimum_payment_pct`, `minimum_capital_pct`) y para métricas derivadas de UI que no son montos (ej. porcentaje de un total como número entre 0 y 100).
- **RN-IC-03**: Toda entrada de usuario en un form monetario se parsea via `parseCents`. Rechaza inputs con más de 2 decimales (evita ambigüedad sobre truncar vs. redondear silencioso).
- **RN-IC-04**: Todo display monetario en UI se hace via `formatCents`. Sin excepciones — no `.toString()` directo sobre un int de centavos, no cálculos ad-hoc con `/ 100`.
- **RN-IC-05**: Toda comparación de montos vuelve a ser estricta (`>`, `<`, `==`, `!=`). Se eliminan todas las tolerancias `+ 0.005` del código actual. Cualquier tolerancia que quede es bug documentado.
- **RN-IC-06**: La migración schema `13 → 14` es one-shot y no reversible desde la app. El backup automático pre-migración es el único mecanismo de rollback (importar con app previa 0.32.1+120).
- **RN-IC-07**: El import de backup v3 rechaza montos que no sean `int` con `invalid_amount_format`. El import de v1/v2 convierte a `int` via `round(v * 100)`.
- **RN-IC-08**: Todos los saltos multi-versión defensivos (`from ∈ {5..12} && to == 14`) preservan la garantía de idempotencia por probe. El guardrail `UnimplementedError` se conserva.
- **RN-IC-09**: La migración exporta backup automático ANTES de tocar el schema. Si el export falla (permisos, disco lleno, path inválido), la migración aborta y la app queda en v13 funcional.

## Requisitos funcionales

- **RF-001**: Nuevo módulo `mobile/lib/utils/money.dart` con `parseCents`, `formatCents`, `centsFromDouble`, `centsToDouble`. `formatCents` reemplaza a `formatAmount` con firma equivalente pero tipo `int`.
- **RF-002**: Schema v14 con todas las columnas monetarias como `INTEGER` según sección "Schema" del alcance. Ratios quedan como `REAL`.
- **RF-003**: `MigrationStrategy.onUpgrade` con rama `13 → 14` idempotente por probe de tipo (`pragma_table_info` con chequeo de `type`). Ramas defensivas `X → 14` para X ∈ {5..12}. Guardrail preservado.
- **RF-004**: La migración `13 → 14` ejecuta backup automático a `<app_documents_dir>/fincore-pre-v14-YYYYMMDD-HHmmss.json` como primer paso. Si el export falla, aborta.
- **RF-005**: Todos los DAOs (`EntriesDao`, `AccountsDao`, `LoansDao`, `WeeklyBudgetsDao`, `CategoriesDao`, `FinancialStateService`, `ReportsService`) cambian signatures monetarias `double → int`.
- **RF-006**: Todos los forms de UI parsean con `parseCents` y muestran con `formatCents`. Widgets de display consumen `int` desde streams del DAO.
- **RF-007**: Backup JSON bumpa a v3 con montos como `int` centavos. Import acepta v1, v2 y v3 con conversión automática para las dos primeras.
- **RF-008**: Fixture sintético `test/fixtures/synthetic-backup-v2.json` generado programáticamente por un test helper. Contiene 158 entries con distribución similar al respaldo real, incluye montos con residuos IEEE 754 intencionales (para probar `centsFromDouble`). Test `BK-IC-01` importa el fixture y valida la suma total conocida. El respaldo real de Diego se usa solo en desarrollo local, sin versionar. Decidido en P-006.
- **RF-009**: Path del backup automático pre-migración queda accesible desde Settings ("Ver backup pre-migración v14") con acción "Compartir" (via `share_plus`).
- **RF-010**: Todas las tolerancias `+ 0.005` en `overpay_debt` (línea 302 hoy) y `overpay_loan` (líneas 453, 609 hoy) se eliminan. Los tests que validaban esas tolerancias se eliminan o se refactoran para validar la comparación estricta post-migración.

## Casos principales

1. **Diego actualiza la app de 0.32.1+120 a 0.33.0+121**. Al abrir por primera vez, la app corre la migración 13 → 14. Antes de tocar el schema, exporta el backup completo a un archivo con timestamp. Después convierte todas las columnas monetarias. La UI muestra un banner por 5 segundos: "Migración completada. Backup previo guardado en Configuración." Diego verifica en Dashboard que sus balances BO/DE/CR son idénticos a los de antes.
2. **Diego intenta pagar el saldo exacto de una tarjeta**. Ingresa "173.77" en el form. `parseCents` devuelve `17377`. El DAO compara `17377 > deudaEnCentavos` — que es exactamente `17377` — retorna `false` — pago aceptado. Sin tolerancias.
3. **Diego crea un movimiento nuevo con monto "1500.50"**. `parseCents("1500.50")` → `150050`. El DAO lo persiste como INTEGER. Los reportes agregados suman en INTEGER (exacto). Dashboard muestra "$1,500.50" via `formatCents(150050)`.
4. **Diego importa un backup v2 legacy** (por ejemplo, uno viejo de antes de la migración). El import detecta version `2`, itera los amounts como `double`, aplica `centsFromDouble` (round) a cada uno, y persiste como INTEGER. Diego recupera datos históricos sin errores de precisión introducidos por el import.
5. **Diego exporta su BD post-migración**. El backup emite JSON v3 con `"amount": 17377`. Cualquier consumidor externo (script, análisis en Excel/Python) sabe que son centavos y divide entre 100 al leer.

## Casos borde

1. **Migración crashea mid-conversion** (cel se apaga, out of memory). La migración es idempotente: al reabrir, el probe detecta si la columna ya es INTEGER y omite el paso. El backup automático ya se generó como primer paso, así que Diego puede restaurarlo con la app previa si el estado quedó inconsistente.
2. **`_maybeAddColumn` no aplica** — hay que agregar `_probeColumnType(table, column)` que retorna `'REAL'` o `'INTEGER'` según `pragma_table_info`. Si es INTEGER, se omite el CREATE TABLE new.
3. **Backup v3 con un monto `173.77`** (float) por bug de un consumidor externo. Import lanza `invalid_amount_format` con mensaje claro. No convierte silenciosamente para no romper la invariante "v3 = solo integers".
4. **Backup v1/v2 con un monto `173.7699999`** (residuo IEEE 754 heredado). Import aplica `round(v * 100) = 17377`. Zero data loss si el valor original era `173.77`. Si era realmente `173.769999999...` con intención, se pierde el sub-centavo — aceptado por diseño (no aplica al modelo actual).
5. **Overflow de `int`**: Dart `int` en Android VM = 64 bits signed = ±9.2 quintillones. Max monto histórico observado en la BD de Diego: $37,300 = 3,730,000 centavos. A años luz del límite. Sin protección adicional necesaria.
6. **Diego tiene una app 0.33.0+ e intenta importar un backup v3 emitido por una versión aún más nueva (v4 hipotética)**. Import rechaza con `unsupported_version` (comportamiento actual preservado).
7. **`parseCents` recibe "1,500.75" con separador de miles**. Debe aceptar y devolver `150075`. Con separadores decimales alternativos (`1500,75` estilo europeo), también acepta si el locale es `es_MX` (que usa `.` decimal pero muchos usuarios ingresan con `,`).
8. **`formatCents(0)`** → `"$0.00"` por default, o `"$0"` si `omitZeroDecimals: true`. Sin surprise NaN.
9. **`formatCents(-100)`** → `"-$1.00"` (signo antes del símbolo). Ver `formatAmount` actual para preservar convención.
10. **Migración desde v5** (hipotético tester con BD muy vieja). La rama defensiva `5 → 14` reutiliza `_maybeAddColumn`, `_createLoansSchema`, `_createWeeklyBudgetTablesRefactored`, y agrega al final el paso de conversión REAL → INTEGER.
11. **Test round-trip contra fixture real**: el fixture `test/fixtures/fincore-backup-2026-07-24.json` se versiona sin edición. El test `BK-IC-01` no debe romperse si Diego hace commits futuros que no toquen el modelo — solo si el modelo cambia genuinamente.
12. **`bulkUpdateCategory`** no toca amounts, pero sus tests pueden tener literales `double` en el seed. Refactor mecánico sin cambios semánticos.
13. **Backup Settings acción "Compartir backup pre-migración"** — si el archivo ya no existe (Diego lo movió), mostrar snackbar con path esperado y opción de re-generar (que corre un `exportToJson` fresco, no rehace la migración).

## Criterios de aceptacion

- **CA-01**: Al actualizar de 0.32.1+120 a 0.33.0+121, la app corre la migración sin intervención del usuario. El backup automático se genera en `<app_documents_dir>/fincore-pre-v14-YYYYMMDD-HHmmss.json`.
- **CA-02**: Post-migración, `Dashboard` muestra `BO`, `DE`, `CR` idénticos (visualmente) a los pre-migración. Verificable comparando capturas de pantalla o exportando ambos backups y verificando manualmente.
- **CA-03**: Post-migración, importar el backup pre-migración (v2) reconstruye la BD idéntica. Round-trip export v3 → wipe → import v3 es identidad matemática.
- **CA-04**: El caso original del bug (pagar saldo exacto de tarjeta) funciona: Diego reproduce el escenario y el pago se acepta sin fragmentar.
- **CA-05**: Suite `flutter test` en verde con al menos los mismos tests que antes (867) + nuevos tests del sprint (~10 nuevos ≈ 877 target).
- **CA-06**: `flutter analyze` en 0 errores (los 3 hints preexistentes en `entry_form_screen.dart:510-513` se toleran).
- **CA-07**: Fixture sintético `test/fixtures/synthetic-backup-v2.json` importa post-migración sin errores y `Σ amount` cuadra contra el oracle del fixture. En desarrollo local, el respaldo real de Diego se prueba manualmente una vez antes del commit final del sprint.
- **CA-08**: Cero ocurrencias de `+ 0.005` o similares en `mobile/lib/` (validado con `grep -rn "+ 0.005\|+ 0.001" mobile/lib/`).
- **CA-09**: Todos los tests `overpay_debt` y `overpay_loan` usan comparaciones estrictas (sin tolerancia parche).
- **CA-10**: Settings expone "Backup pre-migración v14" con path visible y acción "Compartir".
- **CA-11**: Bump de versión a `0.33.0+121` en pubspec.yaml y build.gradle.kts, verificado por `scripts/verify-apk.sh`.

## Criterios medibles de exito

- **CM-01**: 0 tolerancias monetarias `+ 0.005` en el código de producción post-sprint (validado por grep).
- **CM-02**: Diferencia de balances pre/post migración = 0 centavos exactos (validado con test comparando `SUM(amount)` antes de la migración vs. después).
- **CM-03**: Tiempo de migración sobre la BD real de Diego (158 entries, 5 cuentas, 20 categorías, 1 préstamo) < 500 ms end-to-end (incluyendo backup automático). Medido con `Stopwatch` inline en la migración, log a `debugPrint`.
- **CM-04**: Tests del sprint (10+ nuevos) todos verdes en < 30 segundos en el runner de tests (subset de `flutter test test/data/ test/utils/`).
- **CM-05**: Zero regresiones en tests preexistentes (los 867 verdes siguen verdes).
- **CM-06**: Fixture del respaldo real está versionado y el test `BK-IC-01` lo importa exitosamente en cada CI run local.

## Riesgos

- **R-01 (Alto)**: **Corrupción de datos durante la migración**. Si la conversión REAL → INTEGER se corta mid-transaction, la BD queda inconsistente (algunas columnas migradas, otras no). Mitigación: la migración recrea cada tabla completa con `INSERT ... SELECT` dentro de la misma transacción de drift (autocommit al final). Si crashea, drift no persiste `schemaVersion = 14` → al reabrir vuelve a intentar 13 → 14 desde cero. El backup automático es el rollback definitivo.
- **R-02 (Alto)**: **Superficie enorme del refactor**. Cambiar `double → int` en decenas de archivos implica que cualquier lugar olvidado sigue compilando (Dart no distingue tipos numéricos en literales) pero produce resultados incorrectos. Mitigación: usar `flutter analyze` como red de seguridad + suite completa de tests + revisión manual con `grep` de patrones `\.toDouble()`, `double amount`, `Amount:.*double`.
- **R-03 (Medio)**: **Backup automático puede fallar por permisos**. Android 13+ requiere `POST_NOTIFICATIONS`, y el filesystem exposé al usuario varía. Mitigación: usar `path_provider.getApplicationDocumentsDirectory()` (siempre accesible, no requiere permisos extra). Path resultante: `/data/user/0/io.github.gregori100.fincore/app_flutter/`. Diego lo puede compartir desde Settings.
- **R-04 (Medio)**: **Round-trip con backup legacy v1/v2**. Los doubles se convierten con `round(v * 100)`. Si algún valor tenía intención decimal más allá de 2 posiciones (ej. `0.005` como interés diario proporcional), se pierde. Aceptado por diseño: el modelo actual de FinCore no usa sub-centavos.
- **R-05 (Bajo)**: **Ratios como REAL siguen siendo IEEE 754**. `interest_rate`, `minimum_payment_pct`, `minimum_capital_pct` mantienen imprecisión, pero: (a) hoy no se usan en UI ni en cálculos críticos, (b) su rango 0-1 con ~2 decimales significativos hace que el error sea despreciable. Si algún día se necesita precisión ahí, sprint separado con basis points.
- **R-06 (Bajo)**: **Compat con Laravel legacy backend**. El backup v3 con integer cents ya NO es directamente importable por el backend Laravel (que espera doubles). Pero el backend está fuera de scope activo (rama `legacy/web-and-online-flutter`). Si Diego alguna vez lo revive, hay que agregar un converter de v3 → v2 en el import de Laravel. Documentado en `pendientes.md` post-sprint.
- **R-07 (Bajo)**: **Formatters usados en tests con literales double**. Ejemplo: `expect(find.text(formatAmount(6500)), findsWidgets)` en tests de weekly_budgets. Refactor mecánico: `expect(find.text(formatCents(650000)), findsWidgets)`. Volumen: ~30 llamadas distribuidas en tests.

## Supuestos

- **S-01**: Diego solo tiene 1 dispositivo Android con FinCore instalado. No hay multi-device sync a preservar.
- **S-02**: Diego no ha hecho commits al backend Laravel legacy (rama `legacy/web-and-online-flutter`) recientemente y no planea revivir el sync en el corto plazo. Si lo hiciera, el converter v3 → v2 se agregaría en su propio sprint.
- **S-03**: Diego usa `es_MX` como locale (confirmado en el código: `initializeDateFormatting('es_MX')`). `parseCents` acepta ambos separadores decimales (`.` y `,`) para tolerar hábitos de tipeo, pero canoniza a `.` internamente antes del parse.
- **S-04**: El respaldo `fincore-backup-2026-07-24.json` es representativo del uso real (variedad de kinds, cuentas, préstamos con pagos). Alcanza como fixture de test.
- **S-05**: La BD in-memory de test (`NativeDatabase.memory()`) soporta las migraciones idénticamente a la BD real. Verificado indirectamente por el patrón previo (todos los sprints usan la misma).
- **S-06**: `path_provider.getApplicationDocumentsDirectory()` está siempre disponible en Android y no requiere permisos runtime. Verificado por su uso previo en `BackupService`.
- **S-07**: `int` en Dart en Android runtime es de 64 bits (no 32). Documentado por Dart oficial: `int` en la VM Dart mobile es siempre 64-bit signed. Confirma que no hay riesgo de overflow con montos realistas.
- **S-08**: Los tests widget del harness `pumpFincoreApp` no requieren cambios al patrón — solo actualización de literales monetarios en los seeds.

## Impacto esperado

**Positivo**:

- Elimina de raíz la clase de bugs "precisión monetaria" — futuras features heredan la precisión sin necesidad de recordar tolerancias.
- Balances y agregados de reportes son matemáticamente exactos. Diego confía en los números sin necesidad de reconciliar manualmente.
- El backup JSON deja de ser lossy en round-trip.
- Habilita features futuras que dependen de precisión al centavo (moratorios diarios, split fino de gastos, cash flow proyectado con precisión).
- El código queda más simple: comparaciones estrictas sin `+ 0.005` son más legibles y fáciles de razonar.

**Negativo / disruptivo temporal**:

- Sprint largo (10-15 h) con superficie enorme. Muchos commits granulares esperados.
- Riesgo real de bug de conversión olvidado si el compilador no detecta un uso legacy. Mitigación: red de tests + grep exhaustivo.
- El backup v3 rompe compat directa con el backend Laravel legacy (documentado en R-06 y a resolver en su propio sprint si aplica).
- Duración de la migración one-shot al abrir por primera vez la nueva versión. Estimado < 500 ms para la BD real de Diego, pero podría tomar más en BDs futuras muy grandes.

**Neutral**:

- La UI no cambia visualmente. Diego no debería notar diferencia salvo que específicamente reproduzca el bug de overpay_debt.
- El schema v14 mantiene todas las semánticas de nullability y defaults (solo cambia el tipo).
