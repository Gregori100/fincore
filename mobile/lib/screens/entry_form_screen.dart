import 'dart:async';

import 'package:fincore/app_dependencies.dart';
import 'package:fincore/constants/kinds.dart';
import 'package:fincore/data/daos/entries_dao.dart';
import 'package:fincore/data/database.dart';
import 'package:fincore/theme/fincore_colors.dart';
import 'package:fincore/theme/fincore_radii.dart';
import 'package:fincore/theme/fincore_spacing.dart';
import 'package:fincore/theme/fincore_typography.dart' as typo;
import 'package:fincore/widgets/account_balance_hint.dart';
import 'package:fincore/widgets/account_picker.dart';
import 'package:fincore/widgets/amount_input_formatter.dart';
import 'package:fincore/widgets/category_picker.dart';
import 'package:fincore/widgets/confirm_dialog.dart';
import 'package:fincore/widgets/error_snackbar.dart';
import 'package:fincore/widgets/kind_picker.dart';
import 'package:fincore/widgets/skeleton.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class EntryFormScreen extends StatefulWidget {
  final String? entryId;
  const EntryFormScreen({super.key, this.entryId});

  @override
  State<EntryFormScreen> createState() => _EntryFormScreenState();
}

class _EntryFormScreenState extends State<EntryFormScreen>
    with WidgetsBindingObserver {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  // Sprint UX de preservación de focus: cuando el usuario tabbea a otra
  // app (banco, calculadora) mientras escribe monto o descripción, al
  // volver debe reaparecer el focus + teclado en el mismo field. Sin
  // esto, Flutter default suelta el focus en `paused` y hay que volver a
  // tocar el field.
  final _amountFocus = FocusNode();
  final _descFocus = FocusNode();
  FocusNode? _lastFocusedField;

  JournalKind? _kind;
  String? _originId;
  String? _destId;
  String? _categoryId;
  DateTime _occurredAt = DateTime.now();

  List<Account> _accounts = const [];
  List<Category> _categories = const [];

  bool _loading = true;
  bool _saving = false;
  String? _bootstrapError;

  // Sprint flutter-entries-category-suggestion-v1:
  // - `_categoryTouched`: el usuario tocó manualmente el CategoryPicker
  //   (CUALQUIER selección lo marca — B1 quality review v1). Mientras
  //   sea true, `_recalcSuggestion` queda inhibido para no pisar su
  //   elección (RN-S07).
  // - `_categorySuggested`: la categoría actual fue propuesta por el
  //   servicio. Controla el render del chip "Sugerida" (RF-005).
  // - `_suggestionDebounce`: Timer para agrupar cambios rápidos en
  //   descripción/monto (RN-S08, debounce 300 ms).
  // - `_suggestionGeneration`: contador monotónico para descartar
  //   resultados de queries obsoletas tras race conditions (R-08 del plan).
  bool _categoryTouched = false;
  bool _categorySuggested = false;
  Timer? _suggestionDebounce;
  int _suggestionGeneration = 0;

  bool get _isEdit => widget.entryId != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
    // Listener para recalcular la sugerencia al tipear descripción. Se
    // agrega en `initState` porque el `TextEditingController` existe
    // desde aquí. El handler short-circuit en `_isEdit` y `_categoryTouched`.
    // (Tras refactor v2 ya NO escuchamos `_amountCtrl` — el monto no
    // influye en la sugerencia.)
    _descCtrl.addListener(_onSuggestionInputChanged);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _suggestionDebounce?.cancel();
    _descCtrl.removeListener(_onSuggestionInputChanged);
    _amountFocus.dispose();
    _descFocus.dispose();
    _amountCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  // Preservación de focus al volver de otra app (banco, calculadora).
  // - En `paused`/`inactive`: recordamos cuál field tenía focus.
  // - En `resumed`: si el recordado sigue existiendo (y el widget sigue
  //   montado), le devolvemos el focus. El teclado reaparece porque
  //   Flutter dispara `showKeyboard` al pedir focus sobre un TextField.
  // Solo aplica a los 2 fields del form (monto + descripción).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      if (_amountFocus.hasFocus) {
        _lastFocusedField = _amountFocus;
      } else if (_descFocus.hasFocus) {
        _lastFocusedField = _descFocus;
      }
    } else if (state == AppLifecycleState.resumed) {
      final target = _lastFocusedField;
      if (target != null && mounted) {
        // Post-frame porque el árbol puede estar aún reconstruyéndose
        // tras el resume; sin esto el requestFocus se pierde.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          target.requestFocus();
          // En Android, si el mismo FocusNode ya era el primary antes
          // del pause, Flutter puede decidir que "no cambió el focus"
          // y omitir la reapertura de la TextInputConnection. Forzamos
          // el show explícito para que el teclado reaparezca sin que
          // el usuario tenga que tocar el field.
          SystemChannels.textInput.invokeMethod('TextInput.show');
        });
      }
      _lastFocusedField = null;
    }
  }

  /// Listener del `_descCtrl`. Programa el `_recalcSuggestion` con
  /// debounce 300 ms.
  void _onSuggestionInputChanged() {
    if (_isEdit || _categoryTouched) return;
    _scheduleSuggestion();
  }

  /// Cancela el timer previo y programa uno nuevo con `Duration(ms: 300)`.
  /// Al disparar, llama a `_recalcSuggestion` que captura la generación
  /// actual y la valida antes de aplicar el resultado.
  void _scheduleSuggestion() {
    _suggestionDebounce?.cancel();
    _suggestionDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      _recalcSuggestion();
    });
  }

  /// Cancela cualquier timer pendiente y dispara la sugerencia
  /// inmediatamente (sin debounce). Usado tras eventos discretos como
  /// cambio de kind o cuenta — no hay tipeo continuo que agrupar.
  void _recalcSuggestionImmediate() {
    _suggestionDebounce?.cancel();
    _recalcSuggestion();
  }

  Future<void> _recalcSuggestion() async {
    if (!mounted) return;
    if (_isEdit) return; // RN-S02: solo en alta.
    if (_categoryTouched) return; // RN-S07: respeta elección manual.
    if (_kind == null || !_kind!.acceptsCategory) return;

    final generation = ++_suggestionGeneration;
    final deps = AppDependencies.of(context);
    final kindApi = _kind!.apiValue;
    final description = _descCtrl.text;

    String? result;
    try {
      result = await deps.categorySuggestionService.suggestForNewEntry(
        kind: kindApi,
        description: description,
      );
    } catch (_) {
      // RN-S09: degradación silenciosa. El picker queda como estaba.
      return;
    }

    // Si una generación más reciente disparó o el form se desmontó,
    // descartar este resultado (R-02 + R-08 del plan).
    if (!mounted || generation != _suggestionGeneration) return;
    // Si el usuario tocó el picker mientras la query estaba en flight,
    // tampoco aplicamos (race tardío).
    if (_categoryTouched) return;

    setState(() {
      if (result == null) {
        // Sin sugerencia: limpiar el sello y la sugerencia previa.
        // DV-02 del implementation-review: si la cascada deja de
        // matchear (e.g. el usuario borra la descripción que daba
        // match), invalidamos la sugerencia anterior. NO afecta
        // elecciones manuales porque este `setState` solo corre con
        // `_categoryTouched == false`.
        _categorySuggested = false;
        _categoryId = null;
      } else {
        _categoryId = result;
        _categorySuggested = true;
      }
    });
  }

  /// Wrapper del `onChanged` del `CategoryPicker`. CUALQUIER selección
  /// del usuario en el dropdown se considera interacción manual y marca
  /// `_categoryTouched = true`, incluso si Diego volvió a elegir la
  /// categoría que ya estaba pre-seleccionada por sugerencia.
  ///
  /// B1 quality review v1: confirmar explícitamente desde el dropdown
  /// debe blindar contra que un re-cálculo posterior la reemplace. Una
  /// elección manual que coincide con la sugerencia sigue siendo manual.
  ///
  /// `CategoryPicker.onChanged` solo se dispara por interacción del
  /// usuario en Material 3 — el setState que aplica la sugerencia
  /// programática NO la dispara. Por eso es seguro tratar cualquier
  /// invocación como manual.
  void _onCategoryPickerChanged(String? value) {
    setState(() {
      _categoryId = value;
      _categoryTouched = true;
      _categorySuggested = false;
    });
  }

  Future<void> _bootstrap() async {
    if (!mounted) return;
    final deps = AppDependencies.of(context);
    try {
      final accounts = await deps.accountsDao.listAll();
      final categories = await deps.categoriesDao.listAll();
      if (!mounted) return;
      _accounts = accounts;
      _categories = categories;

      if (_isEdit) {
        final item = await deps.entriesDao.findById(widget.entryId!);
        if (!mounted) return;
        if (item == null) {
          throw const EntriesDaoError('not_found', 'Movimiento no encontrado.');
        }
        _kind = parseJournalKind(item.entry.kind);
        _originId = item.entry.accountOriginId;
        _destId = item.entry.accountDestinationId;
        // B2 (quality review 2026-06-19): si la categoría heredada está
        // archivada, resetear _categoryId a null. Sin esto, el form pasaba
        // categoryId del entry como "explícito" al DAO y el updateEntry
        // lanzaba invalid_category_applies_to al guardar, rompiendo la
        // promesa de RN-H03 (limpieza silenciosa de categoría archivada).
        if (item.entry.categoryId != null) {
          final activeCat =
              await deps.categoriesDao.findActiveById(item.entry.categoryId!);
          _categoryId = activeCat == null ? null : item.entry.categoryId;
        } else {
          _categoryId = null;
        }
        _occurredAt = item.entry.occurredAt;
        _amountCtrl.text = formatAmountForInput(item.entry.amount);
        _descCtrl.text = item.entry.description ?? '';
      }
    } on EntriesDaoError catch (e) {
      if (mounted) setState(() => _bootstrapError = e.message);
      return;
    } catch (e) {
      if (mounted) setState(() => _bootstrapError = e.toString());
      return;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _selectKind(JournalKind k) {
    setState(() {
      _kind = k;
      _originId = null;
      _destId = null;
      _categoryId = null;
      _occurredAt = DateTime.now();
      _amountCtrl.clear();
      _descCtrl.clear();
      _formKey.currentState?.reset();
      // Reset del estado de sugerencia: cambiar kind es reset total del form.
      _categoryTouched = false;
      _categorySuggested = false;
    });
    // Con kind nuevo + form vacío, la cascada puede caer al paso 3 si
    // hay histórico para ese kind. Disparamos inmediato (no debounce
    // porque es evento discreto).
    _recalcSuggestionImmediate();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _occurredAt,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _occurredAt = DateTime(picked.year, picked.month, picked.day,
          _occurredAt.hour, _occurredAt.minute));
    }
  }

  Future<void> _submit() async {
    if (_saving || _kind == null) return;
    if (!_formKey.currentState!.validate()) return;
    final deps = AppDependencies.of(context);

    // Los pickers de cuenta usan DropdownMenu (M3) y no validan por Form.
    // Cubrimos a mano que origin/destination requeridos por el kind estén.
    final k = _kind!;
    if (_needsOrigin(k) && _originId == null) {
      _showFieldError('Seleccionar la cuenta origen.');
      return;
    }
    if (_needsDestination(k) && _destId == null) {
      _showFieldError('Seleccionar la cuenta destino.');
      return;
    }

    final amount = parseFormattedAmount(_amountCtrl.text);
    if (amount == null || amount <= 0) {
      _showFieldError('El monto no es válido.');
      return;
    }
    final description = _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim();

    setState(() => _saving = true);
    try {
      if (_isEdit) {
        await deps.entriesDao.updateEntry(
          id: widget.entryId!,
          amount: amount,
          description: _descCtrl.text.trim().isEmpty ? '' : _descCtrl.text.trim(),
          occurredAt: _occurredAt,
          accountOriginId: _originId,
          accountDestinationId: _destId,
          categoryId: _kind!.acceptsCategory ? _categoryId : null,
          clearCategory: _kind!.acceptsCategory && _categoryId == null,
        );
      } else {
        switch (_kind!) {
          case JournalKind.income:
            await deps.entriesDao.registerIncome(
              accountDestinationId: _destId!,
              amount: amount,
              occurredAt: _occurredAt,
              description: description,
              categoryId: _categoryId,
            );
            break;
          case JournalKind.expense:
            await deps.entriesDao.registerExpense(
              accountOriginId: _originId!,
              amount: amount,
              occurredAt: _occurredAt,
              description: description,
              categoryId: _categoryId,
            );
            break;
          case JournalKind.creditExpense:
            await deps.entriesDao.registerCreditExpense(
              accountOriginId: _originId!,
              amount: amount,
              occurredAt: _occurredAt,
              description: description,
              categoryId: _categoryId,
            );
            break;
          case JournalKind.debtPayment:
            await deps.entriesDao.registerDebtPayment(
              accountOriginId: _originId!,
              accountDestinationId: _destId!,
              amount: amount,
              occurredAt: _occurredAt,
              description: description,
            );
            break;
          case JournalKind.transfer:
            await deps.entriesDao.registerTransfer(
              accountOriginId: _originId!,
              accountDestinationId: _destId!,
              amount: amount,
              occurredAt: _occurredAt,
              description: description,
            );
            break;
        }
      }
      if (mounted) {
        showSuccessSnackbar(
            context, _isEdit ? 'Movimiento actualizado.' : 'Movimiento creado.');
        // Resetear _saving ANTES del pop para que PopScope.canPop pase a
        // true. `setState` marca el state dirty pero el rebuild ocurre en
        // el próximo frame; por eso el `maybePop` se agenda con
        // `addPostFrameCallback` para que el PopScope ya esté con
        // `canPop=true` cuando el pop se intente. El `finally` re-pone
        // `_saving=false` de forma idempotente si seguimos montados.
        setState(() => _saving = false);
        if (_isEdit) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) Navigator.of(context).maybePop();
          });
        } else {
          // Alta: resetea el stack al Dashboard. Predecible y simple.
          context.go('/dashboard');
        }
      }
    } on EntriesDaoError catch (e) {
      if (mounted) showErrorSnackbar(context, e);
    } catch (e) {
      if (mounted) showErrorSnackbar(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showFieldError(String msg) {
    showWarningSnackbar(context, msg);
  }

  Future<void> _cancel() async {
    final deps = AppDependencies.of(context);
    final confirmed = await showConfirmDialog(
      context,
      title: 'Eliminar movimiento',
      message: '¿Eliminar este movimiento? Esta acción es definitiva.',
      confirmLabel: 'Eliminar movimiento',
    );
    if (!confirmed) return;
    if (!mounted) return;
    setState(() => _saving = true);
    try {
      await deps.entriesDao.cancel(widget.entryId!);
      if (mounted) {
        showSuccessSnackbar(context, 'Movimiento cancelado.');
        // Resetear _saving ANTES del pop (ver comentario en `build()`).
        // El `maybePop` se agenda con `addPostFrameCallback` para que el
        // PopScope ya esté reconstruido con `canPop=true`.
        setState(() => _saving = false);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Navigator.of(context).maybePop();
        });
      }
    } on EntriesDaoError catch (e) {
      if (mounted) showErrorSnackbar(context, e);
    } catch (e) {
      if (mounted) showErrorSnackbar(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(_isEdit ? 'Editar movimiento' : 'Nuevo movimiento'),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: const [
                Skeleton(width: double.infinity, height: 56, radius: 8),
                SizedBox(height: 16),
                Skeleton(width: double.infinity, height: 56, radius: 8),
                SizedBox(height: 16),
                Skeleton(width: double.infinity, height: 56, radius: 8),
                SizedBox(height: 16),
                Skeleton(width: double.infinity, height: 56, radius: 8),
                SizedBox(height: 16),
                Skeleton(width: double.infinity, height: 56, radius: 8),
              ],
            ),
          ),
        ),
      );
    }

    if (_bootstrapError != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: FincoreColors.negative),
                const SizedBox(height: 16),
                Text(_bootstrapError!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: FincoreColors.textPrimary)),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: const Text('Volver'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return PopScope(
      // Mientras hay save en curso, NO permitir back: evita race entre el
      // DAO escribiendo y el reset del form (o el pop desde otro lugar).
      //
      // Hotfix post-smoke 2026-06-19 (bug "pantalla gris muerto"): cuando
      // el back lo dispara `_cancel`/`_submit` programáticamente vía
      // `Navigator.maybePop()`, el flujo previo cancelaba el pop (canPop
      // false por `_saving=true`) y `onPopInvokedWithResult` reseteaba
      // `_kind = null` en plena edición. En el siguiente rebuild,
      // `_buildForm()` crasheaba en `final k = _kind!;` y Flutter
      // renderizaba `ErrorWidget` gris pleno sin AppBar. Solución:
      //   1) `_cancel`/`_submit` ahora hacen `setState(_saving = false)`
      //      antes del `maybePop`, así canPop pasa a true y el pop ocurre.
      //   2) El callback de PopScope solo resetea el form en alta con kind
      //      ya elegido (caso "back desde KindPicker → todo limpio").
      //      Nunca toca `_kind` cuando `_isEdit`.
      canPop: (_isEdit || _kind == null) && !_saving,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_isEdit) return; // no resetear nada en edit
        if (_kind == null) return; // ya estamos en KindPicker
        // Back desde el form alta: vuelve al KindPicker con todo limpio.
        setState(() {
          _kind = null;
          _originId = null;
          _destId = null;
          _categoryId = null;
          _occurredAt = DateTime.now();
          _amountCtrl.clear();
          _descCtrl.clear();
          _formKey.currentState?.reset();
        });
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isEdit ? 'Editar movimiento' : 'Nuevo movimiento'),
          actions: [
            if (_kind != null)
              TextButton(
                onPressed: _saving ? null : _submit,
                style: TextButton.styleFrom(
                  foregroundColor: FincoreColors.accent,
                  padding: const EdgeInsets.symmetric(horizontal: kSpaceLg),
                ),
                child: Text(
                  _isEdit ? 'Guardar' : 'Guardar',
                  style: typo.bodyM.copyWith(
                    color: FincoreColors.accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
        body: SafeArea(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: kEdgeCard,
              children: [
                if (!_isEdit && _kind == null)
                  KindPicker(value: _kind, onChanged: _selectKind)
                else
                  _buildForm(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForm() {
    final k = _kind!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Header con chip del kind + acción "Cambiar" (alta) o pill informativo (edit).
        _KindChipHeader(
          kind: k,
          isEdit: _isEdit,
          saving: _saving,
          onChangePressed: _promptChangeKind,
        ),
        const SizedBox(height: kSpaceLg),

        // 2. Amount hero.
        _AmountHero(
          controller: _amountCtrl,
          focusNode: _amountFocus,
          color: _amountColor(k),
          autofocus: !_isEdit,
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Ingresar el monto.';
            final n = parseFormattedAmount(v);
            if (n == null || n <= 0) return 'Debe ser mayor a 0.';
            return null;
          },
        ),
        const SizedBox(height: kSpaceLg),

        // 3. Fecha con quick chips.
        _DateQuickPicker(
          occurredAt: _occurredAt,
          enabled: !_saving,
          onChanged: (dt) => setState(() => _occurredAt = dt),
          openCustomPicker: _pickDate,
        ),
        const SizedBox(height: kSpaceXl),

        // 4. Account pickers según kind.
        if (_needsOrigin(k)) ...[
          AccountPicker(
            label: _originLabel(k),
            accounts: _accounts,
            allowedTypes: _originTypes(k),
            selectedId: _originId,
            onChanged: (v) => setState(() => _originId = v),
            excludeId: k == JournalKind.transfer ? _destId : null,
          ),
          AccountBalanceHint(accountId: _originId, accounts: _accounts),
          const SizedBox(height: kSpaceXl),
        ],
        if (_needsDestination(k)) ...[
          AccountPicker(
            label: _destLabel(k),
            accounts: _accounts,
            allowedTypes: _destTypes(k),
            selectedId: _destId,
            onChanged: (v) => setState(() => _destId = v),
            excludeId: k == JournalKind.transfer ? _originId : null,
          ),
          AccountBalanceHint(accountId: _destId, accounts: _accounts),
          const SizedBox(height: kSpaceXl),
        ],

        // 5. Descripción.
        TextFormField(
          controller: _descCtrl,
          focusNode: _descFocus,
          decoration: const InputDecoration(labelText: 'Descripción (opcional)'),
          textCapitalization: TextCapitalization.sentences,
          maxLines: 2,
          maxLength: 200,
        ),

        // 6. Category picker.
        if (k.acceptsCategory) ...[
          const SizedBox(height: kSpaceSm),
          CategoryPicker(
            categories: _categories,
            validAppliesTo: k.validCategoryAppliesTo,
            selectedId: _categoryId,
            onChanged: _onCategoryPickerChanged,
          ),
          if (_categorySuggested && _categoryId != null) ...[
            const SizedBox(height: kSpaceXs),
            const _SuggestionChip(),
          ],
        ],

        // 7. Footer con Guardar (redundante con el del AppBar) + Cancelar en edit.
        const SizedBox(height: kSpace2xl),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: FincoreColors.canvas,
                  ),
                )
              : Text(_isEdit ? 'Guardar cambios' : 'Registrar movimiento'),
        ),
        if (_isEdit) ...[
          const SizedBox(height: kSpaceMd),
          OutlinedButton.icon(
            onPressed: _saving ? null : _cancel,
            icon: const Icon(Icons.cancel_outlined),
            label: const Text('Eliminar movimiento'),
            style: OutlinedButton.styleFrom(
              foregroundColor: FincoreColors.negative,
              side: const BorderSide(color: FincoreColors.negative),
              padding: const EdgeInsets.symmetric(vertical: kSpaceMd),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(kRadiusMd),
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// Color emocional del amount hero según el kind.
  /// - income → positive (verde).
  /// - expense → negative (rojo).
  /// - creditExpense → warning (aumenta deuda).
  /// - debtPayment/transfer → accent (movimientos internos, neutrales).
  Color _amountColor(JournalKind k) => switch (k) {
        JournalKind.income => FincoreColors.positive,
        JournalKind.expense => FincoreColors.negative,
        JournalKind.creditExpense => FincoreColors.warning,
        JournalKind.debtPayment => FincoreColors.accent,
        JournalKind.transfer => FincoreColors.accent,
      };

  /// Handler del botón "Cambiar" del chip del kind. Solo en modo alta.
  /// Si el form tiene datos, pide confirmación antes de resetear al KindPicker.
  Future<void> _promptChangeKind() async {
    if (_saving || _isEdit) return;
    final hasData = _amountCtrl.text.trim().isNotEmpty ||
        _originId != null ||
        _destId != null ||
        _descCtrl.text.trim().isNotEmpty ||
        _categoryId != null;

    if (hasData) {
      final confirmed = await showConfirmDialog(
        context,
        title: '¿Cambiar tipo de movimiento?',
        message: 'Los datos ingresados se perderán.',
        confirmLabel: 'Cambiar',
      );
      if (!confirmed) return;
    }
    if (!mounted) return;
    setState(() {
      _kind = null;
      _originId = null;
      _destId = null;
      _categoryId = null;
      _occurredAt = DateTime.now();
      _amountCtrl.clear();
      _descCtrl.clear();
      _formKey.currentState?.reset();
      _categoryTouched = false;
      _categorySuggested = false;
    });
  }

  bool _needsOrigin(JournalKind k) => k != JournalKind.income;
  bool _needsDestination(JournalKind k) =>
      k == JournalKind.income || k == JournalKind.debtPayment || k == JournalKind.transfer;

  String _originLabel(JournalKind k) => switch (k) {
        JournalKind.expense => 'Cuenta origen',
        JournalKind.creditExpense => 'Tarjeta',
        JournalKind.debtPayment => 'Pago desde',
        JournalKind.transfer => 'Cuenta origen',
        JournalKind.income => '',
      };
  String _destLabel(JournalKind k) => switch (k) {
        JournalKind.income => 'Cuenta destino',
        JournalKind.debtPayment => 'Tarjeta a pagar',
        JournalKind.transfer => 'Cuenta destino',
        JournalKind.expense || JournalKind.creditExpense => '',
      };
  List<String> _originTypes(JournalKind k) => switch (k) {
        JournalKind.expense || JournalKind.debtPayment || JournalKind.transfer =>
          const ['cash', 'debit'],
        JournalKind.creditExpense => const ['credit'],
        JournalKind.income => const [],
      };
  List<String> _destTypes(JournalKind k) => switch (k) {
        JournalKind.income || JournalKind.transfer => const ['cash', 'debit'],
        JournalKind.debtPayment => const ['credit'],
        JournalKind.expense || JournalKind.creditExpense => const [],
      };
}

/// Chip pequeño que comunica al usuario que la categoría actual del
/// picker fue propuesta por el `CategorySuggestionService`. Sprint
/// `flutter-entries-category-suggestion-v1` (RF-005).
///
/// Color accent suave para no robar protagonismo al picker. Icono
/// sparkle al inicio + texto "Sugerida". Informativo, no interactivo.
class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: FincoreColors.accent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: FincoreColors.accent.withValues(alpha: 0.5)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.auto_awesome,
              size: 14,
              color: FincoreColors.accent,
            ),
            SizedBox(width: 6),
            Text(
              'Sugerida',
              style: TextStyle(
                color: FincoreColors.accent,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Chip prominente al top del form con el kind seleccionado + acción "Cambiar".
/// En modo edit, renderiza un pill informativo (kind es inmutable por RN-011).
class _KindChipHeader extends StatelessWidget {
  final JournalKind kind;
  final bool isEdit;
  final bool saving;
  final Future<void> Function() onChangePressed;

  const _KindChipHeader({
    required this.kind,
    required this.isEdit,
    required this.saving,
    required this.onChangePressed,
  });

  @override
  Widget build(BuildContext context) {
    final color = KindPicker.kindColor(kind);
    final icon = KindPicker.kindIcon(kind);

    // Hotfix 2026-07-15: chip más compacto por feedback (padding
    // reducido, icon 16, label bodyS, "Cambiar" solo texto sin ícono).
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: kSpaceMd,
        vertical: kSpaceSm,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: FincoreColors.alphaTint),
        borderRadius: BorderRadius.circular(kRadiusMd),
        border: Border.all(
          color: color.withValues(alpha: FincoreColors.alphaHairline),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: kSpaceXs),
          Expanded(
            child: Text(
              kind.label,
              style: typo.bodyS.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (isEdit)
            Text(
              '(no editable)',
              style: typo.label.copyWith(color: FincoreColors.textMuted),
            )
          else
            InkWell(
              onTap: saving ? null : onChangePressed,
              borderRadius: BorderRadius.circular(kRadiusSm),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: kSpaceSm,
                  vertical: kSpace2xs,
                ),
                child: Text(
                  'Cambiar',
                  style: typo.label.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Amount input tratado como hero visual del form.
/// - fontSize: 36 (token-exception documentada; sin token entre headingL=20
///   y displayXL=56 que aplique al hero de un solo input).
/// - Color emocional según kind, con tabular figures para alineación consistente.
/// - Prefix "$" inline en textMuted.
/// - autofocus en modo alta para captura rápida.
class _AmountHero extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final Color color;
  final bool autofocus;
  final String? Function(String?) validator;

  const _AmountHero({
    required this.controller,
    required this.focusNode,
    required this.color,
    required this.autofocus,
    required this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      key: const ValueKey('amount_hero_field'),
      controller: controller,
      focusNode: focusNode,
      autofocus: autofocus,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [AmountInputFormatter()],
      textAlign: TextAlign.center,
      // token-exception: 36 es fontSize hero del amount, sin token entre headingL (20) y displayXL (56).
      style: TextStyle(
        color: color,
        fontSize: 36,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
      decoration: InputDecoration(
        prefixText: r'$ ',
        prefixStyle: TextStyle(
          color: FincoreColors.textMuted,
          // token-exception: matchea el fontSize del hero del amount.
          fontSize: 28,
          fontWeight: FontWeight.w500,
        ),
        hintText: '0',
        hintStyle: TextStyle(
          color: FincoreColors.textSubtle,
          // token-exception: matchea el fontSize del hero del amount.
          fontSize: 36,
          fontWeight: FontWeight.w700,
        ),
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        errorBorder: InputBorder.none,
        focusedErrorBorder: InputBorder.none,
        filled: false,
        contentPadding: const EdgeInsets.symmetric(vertical: kSpaceMd),
        errorStyle: typo.label.copyWith(color: FincoreColors.negative),
      ),
      validator: validator,
    );
  }
}

/// Row de 4 quick chips [Hoy] [Ayer] [Anteayer] [Otro…] + label con la fecha
/// efectiva formateada en es_MX.
class _DateQuickPicker extends StatelessWidget {
  final DateTime occurredAt;
  final bool enabled;
  final ValueChanged<DateTime> onChanged;
  final Future<void> Function() openCustomPicker;

  const _DateQuickPicker({
    required this.occurredAt,
    required this.enabled,
    required this.onChanged,
    required this.openCustomPicker,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day, 12);
    final yesterday = today.subtract(const Duration(days: 1));
    final dayBefore = today.subtract(const Duration(days: 2));
    final normalized = DateTime(
      occurredAt.year,
      occurredAt.month,
      occurredAt.day,
      12,
    );

    final isToday = normalized == today;
    final isYesterday = normalized == yesterday;
    final isDayBefore = normalized == dayBefore;
    final isCustom = !isToday && !isYesterday && !isDayBefore;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Fecha',
          style: typo.label.copyWith(color: FincoreColors.textMuted),
        ),
        const SizedBox(height: kSpaceSm),
        // Hotfix 2026-07-15 (audit del `mobile-designer` sobre feedback de
        // Diego): 4 chips en `Row` con `Expanded` para que ocupen todo el
        // ancho por igual. El `Wrap` previo dejaba un vacío a la derecha
        // que descuadraba el form contra el `_AmountHero` centrado y los
        // `AccountPicker` full-width.
        Row(
          children: [
            Expanded(
              child: _DateChip(
                label: 'Hoy',
                selected: isToday,
                onTap: enabled ? () => onChanged(today) : null,
              ),
            ),
            const SizedBox(width: kSpaceSm),
            Expanded(
              child: _DateChip(
                label: 'Ayer',
                selected: isYesterday,
                onTap: enabled ? () => onChanged(yesterday) : null,
              ),
            ),
            const SizedBox(width: kSpaceSm),
            Expanded(
              child: _DateChip(
                label: 'Anteayer',
                selected: isDayBefore,
                onTap: enabled ? () => onChanged(dayBefore) : null,
              ),
            ),
            const SizedBox(width: kSpaceSm),
            Expanded(
              child: _DateChip(
                label: 'Otro…',
                selected: isCustom,
                onTap: enabled ? openCustomPicker : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: kSpaceSm),
        Text(
          _formatDate(normalized),
          style: typo.bodyS.copyWith(color: FincoreColors.textMuted),
        ),
      ],
    );
  }

  String _formatDate(DateTime dt) {
    return DateFormat("EEEE d 'de' MMMM y", 'es_MX').format(dt);
  }
}

class _DateChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  const _DateChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? FincoreColors.accent.withValues(alpha: FincoreColors.alphaSelected)
          : FincoreColors.surfaceElevated,
      borderRadius: BorderRadius.circular(kRadiusLg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(kRadiusLg),
        child: Container(
          // Padding vertical subido de kSpaceSm (8) a kSpaceMd (12) para
          // llevar el touch target de ~30dp a ~44dp — chip más tapeado del
          // form (audit 2026-07-15). Horizontal se mantiene en kSpaceLg
          // pero el `Expanded` externo estira igual a los 4 chips.
          padding: const EdgeInsets.symmetric(
            horizontal: kSpaceSm,
            vertical: kSpaceMd,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(kRadiusLg),
            border: Border.all(
              color: selected ? FincoreColors.accent : FincoreColors.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: typo.bodyS.copyWith(
              color: selected
                  ? FincoreColors.accent
                  : FincoreColors.textPrimary,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
