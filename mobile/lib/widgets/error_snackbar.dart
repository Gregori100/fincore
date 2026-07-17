import 'package:fincore/data/backup.dart';
import 'package:fincore/data/daos/accounts_dao.dart';
import 'package:fincore/data/daos/categories_dao.dart';
import 'package:fincore/data/daos/entries_dao.dart';
import 'package:fincore/data/daos/loans_dao.dart';
import 'package:fincore/data/daos/saved_views_dao.dart';
import 'package:fincore/models/domain_error.dart';
import 'package:fincore/theme/fincore_colors.dart';
import 'package:fincore/theme/fincore_radii.dart';
import 'package:fincore/theme/fincore_spacing.dart';
import 'package:fincore/theme/fincore_typography.dart';
import 'package:flutter/material.dart';

/// Mapeo de códigos de `BackupError` (validaciones del import de respaldos) a
/// mensajes amigables en español. RF-007 + RN-H01: el switch de
/// `showErrorSnackbar` rutea `BackupError` aquí ANTES del branch `Exception()`
/// para que el usuario no vea texto crudo del estilo `"BackupError(invalid_kind)…"`.
String backupErrorToMessage(BackupError error) {
  switch (error.code) {
    case 'invalid_json':
      return 'El archivo no es un JSON válido.';
    case 'unsupported_version':
      return 'El respaldo es de una versión no soportada por esta app.';
    case 'missing_bolsa':
      return 'El respaldo no incluye la Bolsa (cuenta singleton requerida).';
    case 'invalid_reference':
      return 'El respaldo referencia cuentas o categorías que no existen.';
    case 'invalid_kind':
      return error.message;
    case 'invalid_account_type':
      return error.message;
    case 'invalid_applies_to':
      return error.message;
    case 'invalid_amount':
      return error.message;
    case 'string_too_long':
      return error.message;
    case 'invalid_uuid_format':
      return error.message;
    case 'invalid_date_format':
      return error.message;
    case 'invalid_credit_limit':
      return error.message;
    case 'invalid_credit_metadata':
      return error.message;
    case 'invalid_color_slug':
      return error.message;
    case 'invalid_icon_slug':
      return error.message;
    case 'protected_account':
      return 'Solo una Bolsa puede estar protegida.';
    default:
      return error.message;
  }
}

/// Sprint flutter-loans-v1 (hotfix): switch por código extraído del helper
/// `domainErrorToMessage` para reusarlo desde los cases de `*DaoError` que
/// no son `DomainError`. Toma `fallback` (el `.message` del error) cuando
/// no hay match — así el DAO puede emitir texto humano en el mensaje sin
/// necesidad de re-mapear cada nuevo código aquí.
String _daoCodeToMessage(String code, String fallback) {
  switch (code) {
    case 'overpay_debt':
      return 'El pago no puede ser mayor a la deuda de la tarjeta.';
    case 'invalid_account_type':
      return fallback;
    case 'invalid_credit_limit':
      return fallback;
    case 'invalid_credit_metadata':
      return fallback;
    case 'duplicate_account_name':
      return 'Ya existe una cuenta con ese nombre.';
    case 'account_not_empty':
      return 'No se puede eliminar una cuenta con movimientos activos.';
    case 'protected_account':
      return fallback; // El DAO ya explicita "Bolsa no se puede X".
    case 'invalid_category_applies_to':
      return 'La categoría no aplica a este tipo de movimiento.';
    case 'invalid_amount':
      return 'El monto debe ser mayor a 0.';
    case 'invalid_kind':
      return fallback;
    case 'immutable_journal_field':
      return 'Ese campo no es editable.';
    case 'not_found':
      return fallback;
    case 'account_in_use_by_loan':
      return fallback;
    case 'immutable_loan_field':
      return 'Ese campo del préstamo no es editable. Sólo puedes editar nombre, pago, plazo, día y fecha.';
    case 'immutable_loan_payment':
      return 'Este movimiento pertenece a un préstamo. Se administra desde /loans.';
    case 'invalid_loan_split':
      return 'La suma de capital + intereses debe ser igual al monto total.';
    case 'invalid_loan_data':
      return fallback;
    case 'invalid_payment_day':
      return 'El día de pago debe estar entre 1 y 28.';
    case 'loan_closed':
      return 'No se pueden registrar pagos sobre un préstamo cerrado.';
    case 'cannot_reopen_paid':
      return 'Un préstamo pagado no puede reabrirse. Elimina un pago para reactivarlo o elimina el préstamo.';
    // Hotfix smoke Diego: unicidad de pago del mes + fecha < contrato.
    case 'payment_before_contract':
      return 'El pago no puede ser anterior a la fecha del contrato del préstamo.';
    case 'duplicate_monthly_payment':
      return fallback; // Mensaje del DAO ya sugiere "usa Abono a capital".
    case 'capital_before_monthly':
      return fallback; // Mensaje del DAO explica la regla de orden.
    case 'not_loan_payment':
      return 'Este movimiento no es un pago de préstamo.';
    case 'overpay_loan':
      return fallback; // El DAO ya explica el monto que excede el saldo.
    default:
      return fallback;
  }
}

/// Mapeo de códigos del backend a mensajes amigables en español.
/// Si no hay match, devolvemos `error.message` directo (que ya es texto humano
/// del backend en la mayoría de los casos).
String domainErrorToMessage(DomainError error) {
  switch (error.code) {
    case 'overpay_debt':
      return 'El pago no puede ser mayor a la deuda de la tarjeta.';
    case 'insufficient_funds':
      return 'No hay fondos suficientes.';
    case 'credit_limit_exceeded':
      return 'Excede el límite de la tarjeta.';
    case 'invalid_account_type':
      return 'El tipo de cuenta no es válido para esta operación.';
    case 'invalid_credit_limit':
      return 'El nuevo límite es menor a la deuda actual.';
    case 'invalid_credit_metadata':
      return 'El día de corte y el día de pago no pueden ser el mismo.';
    case 'duplicate_account_name':
      return 'Ya existe una cuenta con ese nombre.';
    case 'account_not_empty':
      return 'No se puede archivar una cuenta con saldo distinto de cero.';
    case 'protected_account':
      return 'La Bolsa no se puede modificar ni eliminar.';
    case 'duplicate_category_name':
      return 'Ya existe una categoría con ese nombre.';
    case 'invalid_category_applies_to':
      return 'La categoría no aplica a este tipo de movimiento.';
    case 'invalid_color_slug':
      return 'El color seleccionado no está disponible.';
    case 'invalid_icon_slug':
      return 'El ícono seleccionado no está disponible.';
    case 'immutable_journal_field':
      return 'Ese campo no es editable.';
    // Sprint flutter-loans-v1: errores nuevos del dominio de préstamos.
    case 'immutable_loan_field':
      return 'Ese campo del préstamo no es editable. Sólo puedes editar nombre, pago, plazo, día y fecha.';
    case 'immutable_loan_payment':
      return 'Este movimiento pertenece a un préstamo. Se administra desde /loans.';
    case 'invalid_loan_split':
      return 'La suma de capital + intereses debe ser igual al monto total.';
    case 'invalid_loan_data':
      return 'Datos del préstamo inválidos: revisa monto, pago mensual y plazo.';
    case 'invalid_payment_day':
      return 'El día de pago debe estar entre 1 y 28.';
    case 'account_in_use_by_loan':
      return error.message; // El DAO ya incluye el nombre del préstamo.
    case 'loan_closed':
      return 'No se pueden registrar pagos sobre un préstamo cerrado.';
    case 'cannot_reopen_paid':
      return 'Un préstamo pagado no puede reabrirse. Elimina un pago para reactivarlo o elimina el préstamo.';
    case 'network_error':
      return error.message;
    default:
      if (error.statusCode == 429) {
        return 'Demasiados intentos. Esperá 1 minuto.';
      }
      return error.message;
  }
}

SnackBar _buildFincoreSnackBar({
  required ScaffoldMessengerState messenger,
  required IconData icon,
  required Color background,
  required Color foreground,
  required String message,
  required Duration duration,
}) {
  // RF-009 del sprint flutter-local-hardening-v2: el foreground se inyecta
  // explícitamente desde el helper público (show*Snackbar) que conoce la
  // intención del mensaje. Antes se inferia con `background == warning`,
  // lo que rompe si algún caller pasa una variante con
  // `withValues(alpha: ...)` u otra modificación del color base.
  return SnackBar(
    content: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: messenger.hideCurrentSnackBar,
        borderRadius: BorderRadius.circular(kRadiusLg),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: kSpaceXs),
          child: Row(
            children: [
              Icon(icon, color: foreground, size: 20),
              const SizedBox(width: kSpaceSm),
              Expanded(
                child: Text(
                  message,
                  style: bodyM.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    backgroundColor: background,
    behavior: SnackBarBehavior.floating,
    margin: const EdgeInsets.fromLTRB(kSpaceLg, 0, kSpaceLg, kSpaceMd),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadiusLg)),
    elevation: 6,
    duration: duration,
  );
}

/// Mapeo de códigos del `CategoriesDao` a mensajes amigables. Sprint
/// `flutter-budgets-v1` agregó `invalid_monthly_limit` e
/// `invalid_monthly_limit_for_income`; el resto son pre-existentes.
String categoriesDaoErrorToMessage(CategoriesDaoError error) {
  switch (error.code) {
    case 'invalid_monthly_limit':
      return 'El presupuesto mensual no puede ser negativo.';
    case 'invalid_monthly_limit_for_income':
      return 'Las categorías de tipo ingreso no llevan presupuesto.';
    case 'duplicate_category_name':
      return 'Ya existe una categoría con ese nombre.';
    case 'invalid_category_applies_to':
      return 'El tipo de categoría no es válido.';
    case 'invalid_color_slug':
      return 'El color seleccionado no está disponible.';
    case 'invalid_icon_slug':
      return 'El ícono seleccionado no está disponible.';
    case 'not_found':
      return 'Esa categoría ya no existe.';
    default:
      return error.message;
  }
}

/// Mapeo de códigos del `SavedViewsDao` a mensajes amigables (sprint
/// `flutter-entries-saved-views-v1`, RF-011).
String savedViewsDaoErrorToMessage(SavedViewsDaoError error) {
  switch (error.code) {
    case 'invalid_name':
      return 'El nombre no es válido. Debe tener entre 1 y 50 caracteres.';
    case 'duplicate_name':
      return 'Ya existe una vista con ese nombre.';
    case 'not_found':
      return 'Esa vista ya no existe.';
    default:
      return error.message;
  }
}

void showErrorSnackbar(BuildContext context, Object error) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;

  final message = switch (error) {
    BackupError() => backupErrorToMessage(error),
    DomainError() => domainErrorToMessage(error),
    CategoriesDaoError() => categoriesDaoErrorToMessage(error),
    SavedViewsDaoError() => savedViewsDaoErrorToMessage(error),
    // Sprint flutter-loans-v1 (hotfix): faltaban cases explícitos para las
    // 3 clases *DaoError. Sin esto caían al `Exception()` genérico y el
    // usuario veía "EntriesDaoError(invalid_loan_split): La suma..." con
    // prefijo feo, o al `_` (default) si el pattern no matcheaba. Los 3
    // comparten el mapping de códigos con `domainErrorToMessage` porque
    // muchos usan códigos comunes (`invalid_account_type`, etc.).
    EntriesDaoError() => _daoCodeToMessage(error.code, error.message),
    AccountsDaoError() => _daoCodeToMessage(error.code, error.message),
    LoansDaoError() => _daoCodeToMessage(error.code, error.message),
    String() => error,
    Exception() => error.toString().replaceFirst('Exception: ', ''),
    _ => 'Error inesperado.',
  };

  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(_buildFincoreSnackBar(
    messenger: messenger,
    icon: Icons.error_outline,
    background: FincoreColors.negative,
    foreground: Colors.white,
    message: message,
    duration: const Duration(seconds: 4),
  ));
}

void showSuccessSnackbar(BuildContext context, String message) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;

  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(_buildFincoreSnackBar(
    messenger: messenger,
    icon: Icons.check_circle_outline,
    background: FincoreColors.positive,
    foreground: Colors.white,
    message: message,
    duration: const Duration(seconds: 3),
  ));
}

void showWarningSnackbar(BuildContext context, String message) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;

  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(_buildFincoreSnackBar(
    messenger: messenger,
    icon: Icons.warning_amber_outlined,
    background: FincoreColors.warning,
    // RF-019 del sprint anterior: fondo warning (#EBBD52) requiere texto
    // sobre canvas oscuro (~10:1 contraste) en vez de blanco (~3.8:1 < AA).
    foreground: FincoreColors.canvas,
    message: message,
    duration: const Duration(seconds: 3),
  ));
}
