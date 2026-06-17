import 'package:fincore/models/domain_error.dart';
import 'package:fincore/theme/fincore_colors.dart';
import 'package:flutter/material.dart';

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

void showErrorSnackbar(BuildContext context, Object error) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;

  final message = switch (error) {
    DomainError() => domainErrorToMessage(error),
    Exception() => error.toString().replaceFirst('Exception: ', ''),
    _ => 'Error inesperado.',
  };

  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: FincoreColors.negative,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 4),
    ),
  );
}

void showSuccessSnackbar(BuildContext context, String message) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;

  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: FincoreColors.positive,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 3),
    ),
  );
}
