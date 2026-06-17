import 'package:fincore/models/domain_error.dart';
import 'package:fincore/widgets/error_snackbar.dart';
import 'package:flutter_test/flutter_test.dart';

DomainError _err(String code) => DomainError(
      message: 'Fallback msg',
      code: code,
      fieldErrors: const <String, List<String>>{},
      statusCode: 422,
    );

void main() {
  group('domainErrorToMessage', () {
    test('mapea overpay_debt a mensaje claro en español', () {
      expect(domainErrorToMessage(_err('overpay_debt')),
          'No podés pagar más de lo que debés a la tarjeta.');
    });

    test('mapea protected_account', () {
      expect(domainErrorToMessage(_err('protected_account')),
          'La Bolsa no se puede modificar ni eliminar.');
    });

    test('mapea invalid_credit_metadata', () {
      expect(domainErrorToMessage(_err('invalid_credit_metadata')),
          'El día de corte y el día de pago no pueden ser el mismo.');
    });

    test('mapea account_not_empty', () {
      expect(domainErrorToMessage(_err('account_not_empty')),
          'No podés archivar una cuenta con saldo distinto de cero.');
    });

    test('429 sin code retorna mensaje throttle', () {
      const e = DomainError(
        message: 'Too many.',
        code: null,
        fieldErrors: <String, List<String>>{},
        statusCode: 429,
      );
      expect(domainErrorToMessage(e), 'Demasiados intentos. Esperá 1 minuto.');
    });

    test('código desconocido retorna message del backend tal cual', () {
      const e = DomainError(
        message: 'Texto del backend',
        code: 'codigo_nuevo_que_no_mapeamos',
        fieldErrors: <String, List<String>>{},
        statusCode: 422,
      );
      expect(domainErrorToMessage(e), 'Texto del backend');
    });

    test('network_error retorna el message tal cual', () {
      final e = DomainError.network('No se pudo conectar.');
      expect(domainErrorToMessage(e), 'No se pudo conectar.');
    });
  });
}
