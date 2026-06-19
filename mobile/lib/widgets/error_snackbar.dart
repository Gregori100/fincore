import 'package:fincore/data/backup.dart';
import 'package:fincore/models/domain_error.dart';
import 'package:fincore/theme/fincore_colors.dart';
import 'package:flutter/material.dart';

/// Mapeo de códigos de `BackupError` (validaciones del import de respaldos) a
/// mensajes amigables en español. RF-007 + RN-H01: el switch de
/// `showErrorSnackbar` rutea `BackupError` acá ANTES del branch `Exception()`
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

/// Mapeo de códigos del backend a mensajes amigables en español.
/// Si no hay match, devolvemos `error.message` directo (que ya es texto humano
/// del backend en la mayoría de los casos).
String domainErrorToMessage(DomainError error) {
  switch (error.code) {
    case 'overpay_debt':
      return 'No podés pagar más de lo que debés a la tarjeta.';
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
      return 'Ya tenés una cuenta con ese nombre.';
    case 'account_not_empty':
      return 'No podés archivar una cuenta con saldo distinto de cero.';
    case 'protected_account':
      return 'La Bolsa no se puede modificar ni eliminar.';
    case 'duplicate_category_name':
      return 'Ya tenés una categoría con ese nombre.';
    case 'invalid_category_applies_to':
      return 'La categoría no aplica a este tipo de movimiento.';
    case 'invalid_color_slug':
      return 'El color seleccionado no está disponible.';
    case 'invalid_icon_slug':
      return 'El ícono seleccionado no está disponible.';
    case 'immutable_journal_field':
      return 'Ese campo no es editable.';
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
  required String message,
  required Duration duration,
}) {
  // RF-019: el fondo `warning` (#EBBD52) con texto blanco daba contraste
  // ~3.8:1 (debajo del umbral WCAG AA de 4.5:1). Con texto sobre canvas
  // oscuro queda en ~10:1. Para success/error mantenemos texto blanco
  // porque sus contrastes con blanco ya son aceptables.
  final foreground =
      background == FincoreColors.warning ? FincoreColors.canvas : Colors.white;
  return SnackBar(
    content: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: messenger.hideCurrentSnackBar,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Icon(icon, color: foreground, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
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
    margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    elevation: 6,
    duration: duration,
  );
}

void showErrorSnackbar(BuildContext context, Object error) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;

  final message = switch (error) {
    BackupError() => backupErrorToMessage(error),
    DomainError() => domainErrorToMessage(error),
    Exception() => error.toString().replaceFirst('Exception: ', ''),
    _ => 'Error inesperado.',
  };

  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(_buildFincoreSnackBar(
    messenger: messenger,
    icon: Icons.error_outline,
    background: FincoreColors.negative,
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
    message: message,
    duration: const Duration(seconds: 3),
  ));
}
