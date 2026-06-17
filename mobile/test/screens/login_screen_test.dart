import 'package:fincore/models/domain_error.dart';
import 'package:fincore/screens/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/test_app.dart';

void main() {
  setUpAll(() {
    registerFallbackValue('');
  });

  testWidgets('Login renderiza email + password + botón "Iniciar sesión"',
      (tester) async {
    await tester.pumpWidget(testApp(child: const LoginScreen()));

    expect(find.text('FinCore'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.text('Iniciar sesión'), findsOneWidget);
  });

  testWidgets('submit con email vacío muestra error de validación',
      (tester) async {
    await tester.pumpWidget(testApp(child: const LoginScreen()));

    await tester.tap(find.text('Iniciar sesión'));
    await tester.pump();

    expect(find.text('Ingresá tu email.'), findsOneWidget);
    expect(find.text('Ingresá tu contraseña.'), findsOneWidget);
  });

  testWidgets('submit válido llama authApi.login y muestra error de backend si 422',
      (tester) async {
    final mockAuth = MockAuthApi();
    when(() => mockAuth.login(email: any(named: 'email'), password: any(named: 'password')))
        .thenThrow(const DomainError(
      message: 'Credenciales incorrectas.',
      code: 'invalid_credentials',
      fieldErrors: <String, List<String>>{},
      statusCode: 422,
    ));

    await tester.pumpWidget(testApp(authApi: mockAuth, child: const LoginScreen()));

    await tester.enterText(find.byType(TextFormField).at(0), 'a@b.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'badpass');
    await tester.tap(find.text('Iniciar sesión'));
    await tester.pump(); // procesa submit
    await tester.pump(const Duration(milliseconds: 100)); // permite que snackbar aparezca

    expect(find.text('Credenciales incorrectas.'), findsOneWidget);
    verify(() => mockAuth.login(email: 'a@b.com', password: 'badpass')).called(1);
  });
}
