import 'package:fincore/theme/fincore_colors.dart';
import 'package:flutter/material.dart';

/// Bottom sheet compartido para editar el nombre/label de un presupuesto
/// semanal o de una plantilla (sprint `flutter-weekly-budgets-v1`, fixes
/// UX/UI).
///
/// Extraído de `WeeklyBudgetScreen._editLabel` (`detail_screen.dart`) para
/// reutilizarlo también desde la acción rápida "Editar label" del
/// `PopupMenuButton` de cada `_BudgetCard` en `list_screen.dart` — mismo
/// sheet, dos puntos de entrada (detalle y listado).
///
/// Rediseño (sprint `flutter-weekly-budgets-v1`, propuesta 1 del review
/// UI/UX): antes era un `AlertDialog` centrado; ahora es un
/// `showModalBottomSheet` consistente con `BudgetItemFormSheet`.
///
/// Retorna el nuevo valor recortado, o `null` si el usuario cancela, deja el
/// campo vacío o no cambia el valor.
Future<String?> showEditLabelDialog(
  BuildContext context, {
  required String currentLabel,
  String title = 'Editar nombre',
}) async {
  final controller = TextEditingController(text: currentLabel);
  final result = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: FincoreColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      // `useSafeArea: true` en showModalBottomSheet NO cubre la nav bar
      // gestual de Android (solo el status bar). Sumamos viewPadding (nav
      // bar) + viewInsets (teclado) al padding inferior — mismo fix que
      // `BudgetItemFormSheet` y `_TemplatePickerSheet`.
      final media = MediaQuery.of(ctx);
      return Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 4,
          bottom: media.viewInsets.bottom + media.viewPadding.bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: FincoreColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                maxLength: 60,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(color: FincoreColors.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Nombre',
                  // Oculta el contador "0/60": el límite se sigue validando
                  // (maxLength recorta el input), solo no se renderiza.
                  counterText: '',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: FincoreColors.textSubtle,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: FincoreColors.border),
                      ),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed:
                          () => Navigator.of(ctx).pop(controller.text.trim()),
                      style: FilledButton.styleFrom(
                        backgroundColor: FincoreColors.accent,
                        foregroundColor: FincoreColors.canvas,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Guardar'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
  // No se dispone el controller aquí: el `TextField` sigue montado durante
  // la animación de cierre del bottom sheet (Navigator.pop resuelve el
  // Future antes de que termine esa transición), y disponer el controller
  // de inmediato dispara "TextEditingController used after being disposed"
  // mientras esa transición todavía reconstruye el árbol.
  if (result == null || result.isEmpty || result == currentLabel) return null;
  return result;
}
