import 'dart:async';

import 'package:fincore/app_dependencies.dart';
import 'package:fincore/models/domain_error.dart';
import 'package:fincore/router/app_router.dart';
import 'package:fincore/theme/fincore_colors.dart';
import 'package:fincore/widgets/error_snackbar.dart';
import 'package:flutter/material.dart';

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  bool _resending = false;
  bool _checking = false;
  int _cooldownSecondsLeft = 0;
  Timer? _cooldownTimer;

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    setState(() => _cooldownSecondsLeft = 10);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _cooldownSecondsLeft = _cooldownSecondsLeft - 1;
        if (_cooldownSecondsLeft <= 0) timer.cancel();
      });
    });
  }

  Future<void> _resend() async {
    if (_resending || _cooldownSecondsLeft > 0) return;
    final deps = AppDependencies.of(context);
    setState(() => _resending = true);
    try {
      await deps.authApi.resendVerification();
      if (mounted) {
        showSuccessSnackbar(context, 'Correo enviado. Revisá tu bandeja.');
        _startCooldown();
      }
    } on DomainError catch (e) {
      if (mounted) showErrorSnackbar(context, e);
    } catch (e) {
      if (mounted) showErrorSnackbar(context, e);
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  Future<void> _checkVerified() async {
    if (_checking) return;
    final deps = AppDependencies.of(context);
    setState(() => _checking = true);
    try {
      final user = await deps.authApi.me();
      if (user.isVerified) {
        deps.authState.value = AuthSession(
          status: AuthStatus.authenticated,
          user: user,
        );
      } else {
        if (mounted) {
          showErrorSnackbar(
            context,
            const DomainError(
              message: 'Tu cuenta aún no está verificada. Esperá unos segundos y reintentá.',
              code: null,
              fieldErrors: <String, List<String>>{},
              statusCode: 0,
            ),
          );
        }
      }
    } on DomainError catch (e) {
      if (mounted) showErrorSnackbar(context, e);
    } catch (e) {
      if (mounted) showErrorSnackbar(context, e);
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _logout() async {
    final deps = AppDependencies.of(context);
    await deps.authApi.logout();
    await deps.tokenStorage.clear();
    deps.authState.value = const AuthSession(status: AuthStatus.anonymous);
  }

  @override
  Widget build(BuildContext context) {
    final deps = AppDependencies.of(context);
    final email = deps.authState.user?.email ?? 'tu correo';
    final canResend = !_resending && _cooldownSecondsLeft == 0;
    final resendLabel = _cooldownSecondsLeft > 0
        ? 'Reenviar en $_cooldownSecondsLeft s'
        : 'Reenviar correo';

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.mark_email_unread_outlined,
                    size: 64,
                    color: FincoreColors.accent,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Verificá tu email',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: FincoreColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Te mandamos un correo a $email para confirmar tu cuenta. '
                    'Hacé click en el enlace y volvé acá para continuar.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: FincoreColors.textMuted, fontSize: 14),
                  ),
                  const SizedBox(height: 32),
                  FilledButton(
                    onPressed: _checking ? null : _checkVerified,
                    child: _checking
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: FincoreColors.canvas,
                            ),
                          )
                        : const Text('Ya verifiqué'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: canResend ? _resend : null,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: FincoreColors.accent,
                      side: const BorderSide(color: FincoreColors.border),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: _resending
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(resendLabel),
                  ),
                  const SizedBox(height: 24),
                  TextButton(
                    onPressed: _logout,
                    child: const Text('Cerrar sesión'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
