import 'dart:io';

import 'package:fincore/app_dependencies.dart';
import 'package:fincore/data/app_preferences_keys.dart';
import 'package:fincore/data/backup.dart';
import 'package:fincore/data/seed.dart';
import 'package:fincore/router/app_router.dart';
import 'package:fincore/theme/fincore_colors.dart';
import 'package:fincore/widgets/confirm_dialog.dart';
import 'package:fincore/widgets/error_snackbar.dart';
import 'package:fincore/widgets/fincore_logo.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class FirstRunScreen extends StatefulWidget {
  const FirstRunScreen({super.key});

  @override
  State<FirstRunScreen> createState() => _FirstRunScreenState();
}

class _FirstRunScreenState extends State<FirstRunScreen> {
  bool _working = false;

  Future<void> _importBackup() async {
    if (_working) return;
    final deps = AppDependencies.of(context);

    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );
    if (picked == null || picked.files.isEmpty) return;
    if (!mounted) return;

    setState(() => _working = true);
    try {
      final file = picked.files.single;
      String json;
      if (file.bytes != null) {
        json = String.fromCharCodes(file.bytes!);
      } else if (file.path != null) {
        json = await File(file.path!).readAsString();
      } else {
        throw const BackupError('invalid_json', 'No se pudo leer el archivo.');
      }
      final report = await deps.backupService.importFromJson(json);
      if (mounted) {
        showSuccessSnackbar(
          context,
          'Respaldo importado: ${report.accountsCount} cuentas, '
          '${report.categoriesCount} categorías, ${report.entriesCount} movimientos.',
        );
        // F-NAV quality review v1: await para que el `finally` no
        // desactive `_working` antes de que termine el set del flag.
        await _completeAndGo();
      }
    } on BackupError catch (e) {
      if (mounted) showErrorSnackbar(context, e);
    } catch (e) {
      if (mounted) showErrorSnackbar(context, e);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _startFresh() async {
    if (_working) return;
    final deps = AppDependencies.of(context);

    final confirmed = await showConfirmDialog(
      context,
      title: 'Arrancar limpio',
      message: 'Se va a crear una BD vacía con la Bolsa y las 10 categorías por defecto. '
          '¿Continuar?',
      confirmLabel: 'Crear',
      destructive: false,
    );
    if (!confirmed) return;
    if (!mounted) return;

    setState(() => _working = true);
    try {
      await seedDefaults(
        db: deps.database,
        accountsDao: deps.accountsDao,
        categoriesDao: deps.categoriesDao,
      );
      // F-NAV quality review v1: await (ver `_importBackup`).
      if (mounted) await _completeAndGo();
    } catch (e) {
      if (mounted) showErrorSnackbar(context, e);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _completeAndGo() async {
    // Sprint `flutter-onboarding-for-testers-v1` (SP-06 del plan): si el
    // usuario llegó hasta aquí por "Importar respaldo" o "Arrancar limpio",
    // ya está en uso real. Marcamos `onboarding_seen = true` para que un
    // wipe + re-instalación futura no lo fuerce a ver el tour si el flag
    // sigue en false por alguna razón.
    final deps = AppDependencies.of(context);
    final state = FirstRunStateProvider.of(context);
    await deps.appPreferencesDao.set(kPrefOnboardingSeen, 'true');
    state.setOnboardingSeen(true);
    // Notifica al router que ya hay Bolsa; el redirect va al dashboard.
    markFirstRunComplete(state);
    if (!mounted) return;
    GoRouter.of(context).go('/dashboard');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const FincoreLogo(fontSize: 72),
                  const SizedBox(height: 32),
                  const Text(
                    'Para comenzar, elegir una opción:',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: FincoreColors.textMuted, fontSize: 14),
                  ),
                  const SizedBox(height: 24),
                  _OptionCard(
                    icon: Icons.cloud_download_outlined,
                    title: 'Importar respaldo',
                    description:
                        'Restaurar un archivo JSON exportado previamente desde Configuración.',
                    enabled: !_working,
                    onTap: _importBackup,
                  ),
                  const SizedBox(height: 12),
                  _OptionCard(
                    icon: Icons.fiber_new_outlined,
                    title: 'Arrancar limpio',
                    description:
                        'Crea una BD vacía con la Bolsa singleton y 10 categorías por defecto.',
                    enabled: !_working,
                    onTap: _startFresh,
                  ),
                  if (_working) ...[
                    const SizedBox(height: 24),
                    const Center(child: CircularProgressIndicator()),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final bool enabled;
  final VoidCallback onTap;

  const _OptionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: FincoreColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: enabled ? onTap : null,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: FincoreColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: FincoreColors.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: FincoreColors.accent),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: FincoreColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: const TextStyle(
                        color: FincoreColors.textMuted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Semantics(
                excludeSemantics: true,
                child: const Icon(Icons.chevron_right,
                    color: FincoreColors.textSubtle),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
