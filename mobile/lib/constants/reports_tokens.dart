/// Tokens especiales usados por `ReportsService` para representar renglones
/// sintéticos que NO viven en la tabla `categories`. Los widgets que renderizan
/// reportes deben tratar estas ids como "no navegar a drill-down por
/// category_id" o navegar a una pantalla contextual (`/loans` para el token
/// de préstamos).
library;

/// Sprint flutter-loans-v1 (RN-L17): renglón sintético "Intereses de
/// préstamos" en `spendingByCategory`. Suma todos los `interest_amount` de
/// los `loan_payment` del periodo. No hay categoría real detrás. El
/// drill-down por defecto es no-op; opcionalmente se puede rutear a `/loans`.
const String kLoanInterestSyntheticId = '__synthetic_loan_interest__';

/// Hotfix smoke Diego v4: renglón sintético "Pago a capital de préstamos" en
/// `spendingByCategory`. Suma todos los `principal_amount` de los
/// `loan_payment` del periodo. No es "gasto" contable (es reducción de
/// pasivo) pero Diego lo pidió como renglón informativo para ver cuánto
/// dinero de la Bolsa salió a préstamos en el mes. Drill-down: `/loans`.
const String kLoanCapitalSyntheticId = '__synthetic_loan_capital__';
