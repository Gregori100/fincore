/// Representa un error del backend de forma homogénea para la UI.
///
/// El backend Laravel devuelve dos formatos:
///   1. DomainException → `{ "error": "Texto humano", "code": "snake_case" }` con 422 o 409.
///   2. Validación de Laravel → `{ "message": "...", "errors": { "field": ["msg"] } }` con 422.
///
/// Esta clase unifica ambos. `code` se preserva cuando viene; los `errors` por
/// campo se exponen como `fieldErrors`.
class DomainError implements Exception {
  /// Texto humano principal a mostrar en snackbar/diálogo.
  final String message;

  /// Código snake_case del backend si aplica (ej. `overpay_debt`, `protected_account`).
  /// Null si fue un error de validación de Laravel sin DomainException.
  final String? code;

  /// Errores por campo (cuando viene de validación Laravel).
  final Map<String, List<String>> fieldErrors;

  /// Status code HTTP original.
  final int statusCode;

  const DomainError({
    required this.message,
    required this.code,
    required this.fieldErrors,
    required this.statusCode,
  });

  factory DomainError.fromJson(Map<String, dynamic> json, {required int statusCode}) {
    // Formato DomainException.
    if (json.containsKey('error') && json.containsKey('code')) {
      return DomainError(
        message: json['error'] as String,
        code: json['code'] as String?,
        fieldErrors: const <String, List<String>>{},
        statusCode: statusCode,
      );
    }
    // Formato validación Laravel.
    final fieldErrors = <String, List<String>>{};
    final errors = json['errors'];
    if (errors is Map<String, dynamic>) {
      errors.forEach((k, v) {
        if (v is List) {
          fieldErrors[k] = v.cast<String>();
        }
      });
    }
    return DomainError(
      message: (json['message'] as String?) ?? 'Solicitud inválida.',
      code: null,
      fieldErrors: fieldErrors,
      statusCode: statusCode,
    );
  }

  /// Helper para construir error desconocido / red caída.
  factory DomainError.network(String message) {
    return DomainError(
      message: message,
      code: 'network_error',
      fieldErrors: const <String, List<String>>{},
      statusCode: 0,
    );
  }

  @override
  String toString() => 'DomainError($statusCode${code != null ? ', $code' : ''}): $message';
}
