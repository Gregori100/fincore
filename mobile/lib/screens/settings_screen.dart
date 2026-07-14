import 'dart:io';

import 'package:fincore/app_dependencies.dart';
import 'package:fincore/data/app_preferences_keys.dart';
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

  /// Día de inicio de la semana (ISO 8601, 1..7) para el planeador de
  /// presupuestos. `null` mientras se carga desde `AppPreferencesDao`.
  /// Sprint `flutter-weekly-budgets-v1` (T024).
  int? _weekStartDow;

  static const Map<int, String> _weekStartDowLabels = {
    1: 'Lunes',
    2: 'Martes',
    3: 'Miércoles',
    4: 'Jueves',
    5: 'Viernes',
    6: 'Sábado',
    7: 'Domingo',
  };

  // Guardrail una-vez: `didChangeDependencies` corre más de una vez si el
  // árbol de InheritedWidgets se reconstruye. `AppDependencies` no cambia
  // en runtime, así que solo nos interesa la primera pasada (justo después
  // de `initState`). Evita re-disparar la carga async en cada rebuild.
  bool _weekStartDowLoadStarted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_weekStartDowLoadStarted) {
      _weekStartDowLoadStarted = true;
      _loadWeekStartDow();
    }
  }

  Future<void> _loadWeekStartDow() async {
    final deps = AppDependencies.of(context);
    final dow = await deps.appPreferencesDao.weekStartDow();
    if (mounted) setState(() => _weekStartDow = dow);
  }

  Future<void> _onWeekStartDowChanged(int? value) async {
    if (value == null || value == _weekStartDow) return;
    final deps = AppDependencies.of(context);
    await deps.appPreferencesDao.setWeekStartDow(value);
    if (!mounted) return;
    setState(() => _weekStartDow = value);
    showSuccessSnackbar(
      context,
      'Día de inicio actualizado a ${_weekStartDowLabels[value]}.',
    );
  }

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
      text: 'Guardar este archivo en un lugar seguro.',
    ).timeout(
      const Duration(minutes: 2),
      onTimeout: () => const ShareResult('timeout', ShareResultStatus.unavailable),
    );
    final ok = result.status == ShareResultStatus.success;
    // Sprint `flutter-onboarding-for-testers-v1` (RN-O08): persistimos
    // el timestamp solo si el share completó con éxito. Cancelaciones o
    // unavailable NO cuentan como respaldo realizado.
    if (ok) {
      await deps.appPreferencesDao
          .set(kPrefLastExportAt, DateTime.now().toIso8601String());
      // Forzar rebuild para que `_LastExportInfo` reflejé el nuevo valor.
      if (mounted) setState(() {});
    }
    return ok;
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
    // Notificá al router que la BD está vacía → redirect a `/onboarding`.
    // S1 quality review v1: `wipeAll` borra la fila de `onboarding_seen`
    // en BD, pero el state EN MEMORIA sigue siendo `true`. Sin resetear
    // ambos, el router ve `hasBolsa=false && onboardingSeen=true` y va
    // a `/first-run` (no a `/onboarding` como dice el comentario en
    // `backup.dart`). Resetear los dos flags aquí mantiene la promesa
    // de RN-O04 ("el usuario queda como recién instalado").
    firstRunState.setInitial(hasBolsa: false, onboardingSeen: false);
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
          'No hay vuelta atrás (a menos que exista otro respaldo guardado).',
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
        // Sprint flutter-reports-credit-cards-v1: si el JSON legacy traía
        // cuentas credit con `credit_limit=null`, el import las ajustó a 0.
        // Reportar el conteo para que Diego lo sepa y pueda editar límites.
        final adjustedNote = report.adjustedAccountsCount > 0
            ? ' (${report.adjustedAccountsCount} '
                '${report.adjustedAccountsCount == 1 ? "cuenta ajustada" : "cuentas ajustadas"} '
                'a límite 0)'
            : '';
        showSuccessSnackbar(
          context,
          'Respaldo importado: ${report.accountsCount} cuentas$adjustedNote, '
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
                  'La BD es local. Exportar el respaldo con regularidad y '
                  'guardarlo en un lugar seguro (Drive, correo, etc.) para '
                  'no perder datos.',
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
                // Sprint `flutter-onboarding-for-testers-v1`: indicador
                // del último respaldo. Sin botón ni acción — solo señal.
                // NOTA (F1 quality review v1): SIN `const`. Si fuera
                // `const _LastExportInfo()`, el setState del padre tras
                // export exitoso NO reconstruiría este widget (Flutter
                // short-circuit por identidad de objeto canonizado), y
                // el FutureBuilder interno no se re-ejecutaría hasta
                // salir y volver a Settings.
                const SizedBox(height: 12),
                // ignore: prefer_const_constructors
                _LastExportInfo(),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const SectionTitle('Preferencias'),
          const SizedBox(height: 8),
          BaseCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Configuración del planeador semanal de presupuestos.',
                  style: TextStyle(color: FincoreColors.textMuted, fontSize: 13),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Text(
                        'Día de inicio de la semana',
                        style: TextStyle(
                            color: FincoreColors.textPrimary,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                    _weekStartDow == null
                        ? const Skeleton(width: 90, height: 32)
                        : DropdownButton<int>(
                            value: _weekStartDow,
                            dropdownColor: FincoreColors.surfaceElevated,
                            onChanged: _onWeekStartDowChanged,
                            items: _weekStartDowLabels.entries
                                .map((entry) => DropdownMenuItem<int>(
                                      value: entry.key,
                                      child: Text(
                                        entry.value,
                                        style: const TextStyle(
                                            color: FincoreColors.textPrimary),
                                      ),
                                    ))
                                .toList(),
                          ),
                  ],
                ),
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
          // Sprint `flutter-onboarding-for-testers-v1`: entrada Ayuda
          // entre "Zona peligrosa" y "Acerca de". Accesible siempre,
          // sin condiciones (RN-O05).
          const SectionTitle('Ayuda'),
          const SizedBox(height: 8),
          BaseCard(
            onTap: () => context.push('/help'),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: FincoreColors.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.help_outline,
                      color: FincoreColors.accent),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Ayuda',
                          style: TextStyle(
                              color: FincoreColors.textPrimary,
                              fontWeight: FontWeight.w600)),
                      SizedBox(height: 2),
                      Text('FAQ sobre tipos de movimientos, reportes, presupuestos y respaldo.',
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
              'legacy/web-and-online-flutter del repo. Para recuperar datos '
              'del backend antiguo, hacer checkout de esa rama.',
              style: TextStyle(color: FincoreColors.textMuted, fontSize: 13),
            ),
          ),
        ],
      ),
      ),
    );
  }
}

/// Indicador del estado del último respaldo. Sprint
/// `flutter-onboarding-for-testers-v1` (RF-013).
///
/// 3 estados de render según `last_export_at`:
/// - clave inexistente o parse falla → "Aún no exportaste un respaldo."
/// - hace <14 días → "Último respaldo: hace X días."
/// - hace ≥14 días → badge warning + texto sugiriendo exportar.
///
/// Sin reactividad (no es stream). El valor se recarga al construir
/// SettingsScreen, lo cual es suficiente para uso real. El export
/// exitoso fuerza un `setState` arriba para refrescar el indicador.
class _LastExportInfo extends StatelessWidget {
  const _LastExportInfo();

  @override
  Widget build(BuildContext context) {
    final deps = AppDependencies.of(context);
    return FutureBuilder<String?>(
      future: deps.appPreferencesDao.get(kPrefLastExportAt),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const SizedBox(height: 20);
        }
        final raw = snap.data;
        if (raw == null || raw.isEmpty) {
          return const _ExportInfoText(
            text: 'Aún no exportaste un respaldo.',
            warning: false,
          );
        }
        final parsed = DateTime.tryParse(raw);
        if (parsed == null) {
          // CB-D04: tratar valores corruptos como "nunca exportado".
          return const _ExportInfoText(
            text: 'Aún no exportaste un respaldo.',
            warning: false,
          );
        }
        // CB-D05: clock futuro → tratar deltas negativos como 0.
        var days = DateTime.now().difference(parsed).inDays;
        if (days < 0) days = 0;
        if (days >= 14) {
          return _ExportInfoText(
            text:
                'Último respaldo: hace $days días — te recomendamos exportar pronto.',
            warning: true,
          );
        }
        return _ExportInfoText(
          text: 'Último respaldo: hace $days días.',
          warning: false,
        );
      },
    );
  }
}

class _ExportInfoText extends StatelessWidget {
  final String text;
  final bool warning;

  const _ExportInfoText({required this.text, required this.warning});

  @override
  Widget build(BuildContext context) {
    if (!warning) {
      return Text(
        text,
        style: const TextStyle(
          color: FincoreColors.textSubtle,
          fontSize: 12,
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: FincoreColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: FincoreColors.warning.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: FincoreColors.warning,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: FincoreColors.warning,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
