import 'package:fincore/app_dependencies.dart';
import 'package:fincore/router/app_router.dart';
import 'package:fincore/theme/fincore_colors.dart';
import 'package:fincore/widgets/base_card.dart';
import 'package:fincore/widgets/confirm_dialog.dart';
import 'package:fincore/widgets/error_snackbar.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Versión visible en Settings. Debe sincronizarse manualmente con `pubspec.yaml`
/// y `android/app/build.gradle.kts` en cada release. Mientras no incorporemos
/// `package_info_plus`, esta constante es la fuente de verdad en la UI.
const String kAppVersion = '0.1.0+1';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _loggingOut = false;

  Future<void> _logout() async {
    if (_loggingOut) return;
    final deps = AppDependencies.of(context);
    final confirmed = await showConfirmDialog(
      context,
      title: 'Cerrar sesión',
      message: 'Vas a salir de tu cuenta en este dispositivo. ¿Continuar?',
      confirmLabel: 'Cerrar sesión',
    );
    if (!confirmed) return;
    if (!mounted) return;

    setState(() => _loggingOut = true);
    try {
      // logout silencioso ante fallo de red — el clear local es lo importante.
      await deps.authApi.logout();
      await deps.tokenStorage.clear();
      deps.authState.value = const AuthSession(status: AuthStatus.anonymous);
      // El router redirige a /login automáticamente al cambiar el AuthSession.
    } catch (e) {
      if (mounted) showErrorSnackbar(context, e);
    } finally {
      if (mounted) setState(() => _loggingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final deps = AppDependencies.of(context);
    final user = deps.authState.user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/dashboard'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (user != null) ...[
            BaseCard(
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: FincoreColors.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Icon(Icons.person_outline, color: FincoreColors.accent),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.name,
                          style: const TextStyle(
                            color: FincoreColors.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user.email,
                          style: const TextStyle(
                            color: FincoreColors.textMuted,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          const SectionTitle('Servidor'),
          const SizedBox(height: 8),
          BaseCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'URL del API',
                  style: TextStyle(color: FincoreColors.textSubtle, fontSize: 12),
                ),
                const SizedBox(height: 4),
                SelectableText(
                  deps.apiUrl,
                  style: const TextStyle(
                    color: FincoreColors.textPrimary,
                    fontFamily: 'monospace',
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Para cambiarla, reconstruí la app con --dart-define=FINCORE_API_URL=...',
                  style: TextStyle(color: FincoreColors.textSubtle, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const SectionTitle('Acerca de'),
          const SizedBox(height: 8),
          const BaseCard(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('FinCore', style: TextStyle(color: FincoreColors.textPrimary, fontWeight: FontWeight.w600)),
                Text(kAppVersion,
                    style: TextStyle(
                      color: FincoreColors.textMuted,
                      fontFamily: 'monospace',
                      fontSize: 13,
                    )),
              ],
            ),
          ),
          const SizedBox(height: 32),
          OutlinedButton.icon(
            onPressed: _loggingOut ? null : _logout,
            icon: _loggingOut
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.logout),
            label: const Text('Cerrar sesión'),
            style: OutlinedButton.styleFrom(
              foregroundColor: FincoreColors.negative,
              side: const BorderSide(color: FincoreColors.negative),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }
}
