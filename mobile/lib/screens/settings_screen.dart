import 'dart:io';

import 'package:fincore/app_dependencies.dart';
import 'package:fincore/data/backup.dart';
import 'package:fincore/router/app_router.dart';
import 'package:fincore/theme/fincore_colors.dart';
import 'package:fincore/widgets/base_card.dart';
import 'package:fincore/widgets/confirm_dialog.dart';
import 'package:fincore/widgets/error_snackbar.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:fincore/widgets/skeleton.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _working = false;

  Future<void> _export() async {
    if (_working) return;
    setState(() => _working = true);
    try {
      await _exportInternal();
    } catch (e) {
      if (mounted) showErrorSnackbar(context, e);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  /// Exporta el respaldo y dispara el share sheet. Retorna `true` si el
  /// usuario completó el share (`status: success`), `false` si lo canceló
  /// o si el dispositivo no tiene app destino disponible.
  ///
  /// Asume que el caller ya activó `_working = true` y lo desactivará al final.
  Future<bool> _exportInternal() async {
    final deps = AppDependencies.of(context);
    final json = await deps.backupService.exportToJson();
    final tempDir = await getTemporaryDirectory();
    final stamp = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final file = File('${tempDir.path}/fincore-backup-$stamp.json');
    await file.writeAsString(json);
    // RF-010 del sprint flutter-local-hardening-v2: timeout defensivo para
    // que `_working = true` no quede colgado si el share sheet del sistema
    // se cuelga (Android puede no resolver el Future si el usuario cierra
    // la app destino bruscamente). 2 minutos es holgado para cualquier
    // selección humana; al disparar, tratamos como cancelado.
    final result = await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'Respaldo FinCore $stamp',
      text: 'Guardá este archivo en lugar seguro.',
    ).timeout(
      const Duration(minutes: 2),
      onTimeout: () => const ShareResult('timeout', ShareResultStatus.unavailable),
    );
    return result.status == ShareResultStatus.success;
  }

  /// Flujo "Exportar respaldo y luego reiniciar" (RF-013).
  /// Dispara share; si el usuario completó, pide segunda confirmación y
  /// resetea. Si el share fue cancelado/unavailable, no procede.
  Future<void> _exportThenReset() async {
    if (_working) return;
    setState(() => _working = true);
    try {
      final exported = await _exportInternal();
      if (!mounted) return;
      if (!exported) {
        showWarningSnackbar(
          context,
          'Exportación cancelada. No se reinició la BD.',
        );
        return;
      }
      final confirmed = await showConfirmDialog(
        context,
        title: 'Reiniciar cuenta',
        message: 'El respaldo se compartió correctamente. '
            '¿Continuar con el reseteo de tu BD local? '
            'Esta acción es definitiva.',
        confirmLabel: 'Sí, borrar todo',
        destructive: true,
      );
      if (!confirmed) {
        // M3 (quality review 2026-06-19): si el usuario completó el share pero
        // canceló el segundo diálogo, dejarlo claro. El respaldo se exportó
        // pero la BD sigue intacta.
        if (mounted) {
          showSuccessSnackbar(
              context, 'Respaldo exportado. Reseteo cancelado.');
        }
        return;
      }
      if (!mounted) return;
      await _wipeAndRedirect();
    } catch (e) {
      if (mounted) showErrorSnackbar(context, e);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  /// Flujo "Reiniciar sin exportar" (RF-013).
  /// Confirmación destructiva enfática única + wipe.
  Future<void> _resetWithoutExport() async {
    if (_working) return;
    final confirmed = await showConfirmDialog(
      context,
      title: 'Reiniciar cuenta sin respaldo',
      message: 'Esto BORRA toda tu BD: cuentas, categorías, movimientos. '
          'NO se va a exportar respaldo. '
          'No hay vuelta atrás (excepto si ya guardaste otro respaldo manualmente).',
      confirmLabel: 'Borrar todo igual',
      destructive: true,
    );
    if (!confirmed) return;
    if (!mounted) return;
    setState(() => _working = true);
    try {
      await _wipeAndRedirect();
    } catch (e) {
      if (mounted) showErrorSnackbar(context, e);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _wipeAndRedirect() async {
    final deps = AppDependencies.of(context);
    final firstRunState = FirstRunStateProvider.of(context);
    await deps.backupService.wipeAll();
    if (!mounted) return;
    // Notificá al router que la BD está vacía → redirect a /first-run.
    firstRunState.value = false;
    // Salimos de Settings para que el redirect se vea.
    if (context.canPop()) {
      Navigator.of(context).maybePop();
    }
  }

  Future<void> _import() async {
    if (_working) return;
    final deps = AppDependencies.of(context);

    final confirmed = await showConfirmDialog(
      context,
      title: 'Importar respaldo',
      // H3 quality review v1: el JSON v1 no serializa saved_views (son
      // preferencias de UI, no datos críticos). Avisarle al usuario para
      // que no sea sorpresa silenciosa post-import.
      message: 'Esto REEMPLAZA toda la BD actual con el contenido del archivo. '
          'Tus vistas guardadas se perderán. '
          'No hay vuelta atrás (excepto si tenés otro respaldo guardado).',
      confirmLabel: 'Continuar',
    );
    if (!confirmed) return;
    if (!mounted) return;

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
      }
    } on BackupError catch (e) {
      if (mounted) showErrorSnackbar(context, e);
    } catch (e) {
      if (mounted) showErrorSnackbar(context, e);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SafeArea(
        child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          const SectionTitle('Organización'),
          const SizedBox(height: 8),
          BaseCard(
            onTap: () => context.push('/categories'),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: FincoreColors.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.label_outline,
                      color: FincoreColors.accent),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Categorías',
                          style: TextStyle(
                              color: FincoreColors.textPrimary,
                              fontWeight: FontWeight.w600)),
                      SizedBox(height: 2),
                      Text('Crear, editar y archivar.',
                          style: TextStyle(
                              color: FincoreColors.textSubtle, fontSize: 12)),
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
          const SizedBox(height: 16),
          const SectionTitle('Respaldo'),
          const SizedBox(height: 8),
          BaseCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Tu BD local. Exportá regularmente y guardalo en lugar seguro '
                  '(Drive, email a vos mismo, etc.) para no perder datos.',
                  style: TextStyle(color: FincoreColors.textMuted, fontSize: 13),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _working ? null : _export,
                  icon: const Icon(Icons.upload_outlined),
                  label: const Text('Exportar respaldo'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _working ? null : _import,
                  icon: const Icon(Icons.download_outlined),
                  label: const Text('Importar respaldo'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: FincoreColors.accent,
                    side: const BorderSide(color: FincoreColors.border),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                if (_working) ...[
                  const SizedBox(height: 12),
                  const Center(child: CircularProgressIndicator()),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          const SectionTitle('Zona peligrosa'),
          const SizedBox(height: 8),
          BaseCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Borra todas tus cuentas, categorías y movimientos. La app '
                  'vuelve a la pantalla de primer arranque para que importes '
                  'un respaldo o arranques limpio.',
                  style: TextStyle(color: FincoreColors.textMuted, fontSize: 13),
                ),
                const SizedBox(height: 16),
                // Botón primario (RF-013): forzar export antes del reset.
                FilledButton.icon(
                  onPressed: _working ? null : _exportThenReset,
                  icon: const Icon(Icons.save_alt_outlined),
                  label: const Text('Exportar respaldo y luego reiniciar'),
                  style: FilledButton.styleFrom(
                    backgroundColor: FincoreColors.accent,
                    foregroundColor: FincoreColors.canvas,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 8),
                // Botón secundario (RF-013): reset sin exportar, escape hatch
                // para usuarios que ya tienen respaldo guardado manualmente.
                OutlinedButton.icon(
                  onPressed: _working ? null : _resetWithoutExport,
                  icon: const Icon(Icons.delete_forever_outlined),
                  label: const Text('Reiniciar sin exportar'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: FincoreColors.negative,
                    side: const BorderSide(color: FincoreColors.negative),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const SectionTitle('Acerca de'),
          const SizedBox(height: 8),
          BaseCard(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('FinCore',
                    style: TextStyle(
                        color: FincoreColors.textPrimary,
                        fontWeight: FontWeight.w600)),
                // RF-016: la versión se lee de PackageInfo (manifest) en
                // runtime; el fallback en tests/error es cadena vacía.
                FutureBuilder<PackageInfo>(
                  future: PackageInfo.fromPlatform(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Skeleton(width: 60, height: 13);
                    }
                    if (snapshot.hasError || snapshot.data == null) {
                      return const Text('dev',
                          style: TextStyle(
                              color: FincoreColors.textMuted,
                              fontFamily: 'monospace',
                              fontSize: 13));
                    }
                    final info = snapshot.data!;
                    return Text(
                      '${info.version}+${info.buildNumber}',
                      style: const TextStyle(
                          color: FincoreColors.textMuted,
                          fontFamily: 'monospace',
                          fontSize: 13),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const SectionTitle('Legacy'),
          const SizedBox(height: 8),
          const BaseCard(
            child: Text(
              'El backend Laravel y la Vue web están en la rama '
              'legacy/web-and-online-flutter del repo. Si necesitás recuperar '
              'datos del backend antiguo, hacé checkout de esa rama.',
              style: TextStyle(color: FincoreColors.textMuted, fontSize: 13),
            ),
          ),
        ],
      ),
      ),
    );
  }
}
