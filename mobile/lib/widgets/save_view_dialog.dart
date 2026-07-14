import 'package:fincore/theme/fincore_colors.dart';
import 'package:fincore/theme/fincore_radii.dart';
import 'package:fincore/theme/fincore_spacing.dart';
import 'package:fincore/theme/fincore_typography.dart' as t;
import 'package:flutter/material.dart';

/// Modal Bottom Sheet para ingresar el nombre de una vista guardada.
/// Sprint `flutter-entries-saved-views-v1` (RF-008, RF-009).
///
/// Patch UX v2 post-research: reemplaza el `AlertDialog` por un
/// `showModalBottomSheet` con `TextField`. Patrón validado por research
/// agent contra Material 3 + apps modernas (Things, Todoist, Notion,
/// Files Android). Razones:
/// - M3 lo legitima textual: *"an alternative to inline menus or simple
///   dialogs on mobile"*.
/// - Sube con el teclado (`isScrollControlled + viewInsets.bottom`).
/// - Alcance del pulgar, espacio cómodo, mismo patrón reusable.
/// - Consistencia visual con el otro modal sheet de la app ("Mis vistas").
///
/// Nombre del archivo se mantiene `save_view_dialog.dart` por
/// compatibilidad de imports. La API también: `showSaveViewDialog`.
Future<String?> showSaveViewDialog(
  BuildContext context, {
  required String title,
  String? initialName,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: FincoreColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(kRadiusXl)),
    ),
    builder: (ctx) => _SaveViewSheet(
      title: title,
      initialName: initialName ?? '',
    ),
  );
}

class _SaveViewSheet extends StatefulWidget {
  final String title;
  final String initialName;

  const _SaveViewSheet({
    required this.title,
    required this.initialName,
  });

  @override
  State<_SaveViewSheet> createState() => _SaveViewSheetState();
}

class _SaveViewSheetState extends State<_SaveViewSheet> {
  late final TextEditingController _ctrl;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    final trimmed = _ctrl.text.trim();
    if (trimmed.isEmpty) {
      setState(() => _errorText = 'Ingresar un nombre.');
      return;
    }
    if (trimmed.length > 50) {
      setState(() => _errorText = 'Máx 50 caracteres.');
      return;
    }
    Navigator.of(context).pop(trimmed);
  }

  @override
  Widget build(BuildContext context) {
    // Sumar viewPadding.bottom (nav bar gestual Android) además de
    // viewInsets.bottom (teclado). `useSafeArea: true` en
    // showModalBottomSheet no cubre la nav bar inferior.
    final media = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: kSpaceXl,
        right: kSpaceXl,
        top: kSpaceXs,
        bottom: media.viewInsets.bottom + media.viewPadding.bottom + kSpaceXl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.bookmark_outline,
                color: FincoreColors.accent,
                size: 22,
              ),
              const SizedBox(width: kSpaceMd),
              Expanded(
                child: Text(
                  widget.title,
                  style: t.headingL,
                ),
              ),
            ],
          ),
          const SizedBox(height: kSpaceLg),
          TextField(
            controller: _ctrl,
            autofocus: true,
            maxLength: 50,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.done,
            style: t.bodyM,
            decoration: InputDecoration(
              hintText: 'Ej: Gastos comida del mes',
              border: const OutlineInputBorder(),
              errorText: _errorText,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: kSpaceLg,
                vertical: kSpaceLg,
              ),
            ),
            onChanged: (_) {
              if (_errorText != null) {
                setState(() => _errorText = null);
              }
            },
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: kSpaceMd),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: FincoreColors.textSubtle,
                    padding: const EdgeInsets.symmetric(vertical: kSpaceMd),
                    side: const BorderSide(color: FincoreColors.border),
                  ),
                  child: const Text('Cancelar'),
                ),
              ),
              const SizedBox(width: kSpaceMd),
              Expanded(
                child: FilledButton(
                  onPressed: _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: FincoreColors.accent,
                    foregroundColor: FincoreColors.canvas,
                    padding: const EdgeInsets.symmetric(vertical: kSpaceMd),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: const Text('Guardar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
