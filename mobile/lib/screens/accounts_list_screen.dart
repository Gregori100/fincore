import 'package:fincore/app_dependencies.dart';
import 'package:fincore/data/daos/accounts_dao.dart';
import 'package:fincore/data/database.dart';
import 'package:fincore/theme/fincore_colors.dart';
import 'package:fincore/theme/fincore_spacing.dart';
import 'package:fincore/widgets/amount_formatter.dart';
import 'package:fincore/widgets/base_card.dart';
import 'package:fincore/widgets/confirm_dialog.dart';
import 'package:fincore/widgets/destructive_dialog.dart';
import 'package:fincore/widgets/error_snackbar.dart';
import 'package:fincore/widgets/skeleton.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Segmentos del listado de cuentas. Sprint flutter-accounts-archive-v1:
/// separa las cuentas Activas (por default) de las Archivadas (reversibles).
/// Las eliminadas (`deleted_at != null`) nunca aparecen en ningún segmento.
enum AccountsSegment { active, archived }

class AccountsListScreen extends StatefulWidget {
  const AccountsListScreen({super.key});

  @override
  State<AccountsListScreen> createState() => _AccountsListScreenState();
}

class _AccountsListScreenState extends State<AccountsListScreen> {
  AccountsSegment _segment = AccountsSegment.active;
  Stream<List<Account>>? _activeStream;
  Stream<List<Account>>? _archivedStream;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final dao = AppDependencies.of(context).accountsDao;
    _activeStream ??= dao.watchActive();
    _archivedStream ??= dao.watchArchived();
  }

  @override
  Widget build(BuildContext context) {
    final stream =
        _segment == AccountsSegment.active ? _activeStream : _archivedStream;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cuentas'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      floatingActionButton: _segment == AccountsSegment.active
          ? FloatingActionButton(
              onPressed: () => context.push('/accounts/new'),
              backgroundColor: FincoreColors.accent,
              foregroundColor: FincoreColors.canvas,
              child: const Icon(Icons.add),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                kSpaceLg, kSpaceMd, kSpaceLg, kSpaceSm),
            child: SegmentedButton<AccountsSegment>(
              segments: const [
                ButtonSegment(
                  value: AccountsSegment.active,
                  label: Text('Activas'),
                  icon: Icon(Icons.folder_outlined),
                ),
                ButtonSegment(
                  value: AccountsSegment.archived,
                  label: Text('Archivadas'),
                  icon: Icon(Icons.inventory_2_outlined),
                ),
              ],
              selected: {_segment},
              onSelectionChanged: (selection) {
                setState(() => _segment = selection.first);
              },
              showSelectedIcon: false,
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Account>>(
              stream: stream,
              builder: (context, snap) {
                if (!snap.hasData) {
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                        kSpaceLg, kSpaceLg, kSpaceLg, kFabClearance),
                    itemCount: 4,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: kSpaceSm),
                    itemBuilder: (_, __) => const SkeletonCard(),
                  );
                }
                final accounts = snap.data!;
                if (accounts.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(kSpaceXl),
                      child: Text(
                        _segment == AccountsSegment.active
                            ? 'Aún no hay cuentas.'
                            : 'No tienes cuentas archivadas.',
                        style: const TextStyle(
                            color: FincoreColors.textMuted),
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                      kSpaceLg, kSpaceLg, kSpaceLg, kFabClearance),
                  itemCount: accounts.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: kSpaceSm),
                  itemBuilder: (_, i) => _AccountRow(
                    account: accounts[i],
                    isArchived: _segment == AccountsSegment.archived,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountRow extends StatelessWidget {
  final Account account;
  final bool isArchived;
  const _AccountRow({required this.account, required this.isArchived});

  @override
  Widget build(BuildContext context) {
    final deps = AppDependencies.of(context);
    return BaseCard(
      onTap: account.isProtected
          ? null
          : () => context.push('/accounts/${account.id}/edit'),
      padding: const EdgeInsets.symmetric(
          horizontal: kSpaceLg - kSpace2xs, vertical: kSpaceMd),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _typeColor(account.type).withValues(
                alpha: isArchived
                    ? FincoreColors.alphaHover
                    : FincoreColors.alphaTint,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _typeIcon(account.type),
              color: isArchived
                  ? FincoreColors.textSubtle
                  : _typeColor(account.type),
            ),
          ),
          const SizedBox(width: kSpaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        account.name,
                        style: TextStyle(
                          color: isArchived
                              ? FincoreColors.textSubtle
                              : FincoreColors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontStyle: isArchived
                              ? FontStyle.italic
                              : FontStyle.normal,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (account.isProtected) ...[
                      const SizedBox(width: kSpaceXs + kSpace2xs),
                      const Icon(Icons.lock_outline,
                          size: 14, color: FincoreColors.textSubtle),
                    ],
                  ],
                ),
                const SizedBox(height: kSpace2xs),
                Text(
                  _subtitle(account, isArchived),
                  style: const TextStyle(
                      color: FincoreColors.textSubtle, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: kSpaceSm),
          StreamBuilder<double>(
            stream: deps.stateService
                .watchAccountBalance(account.id, account.type),
            builder: (context, snap) {
              if (!snap.hasData) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Skeleton(width: 70, height: 16),
                    if (account.type == 'credit') ...[
                      const SizedBox(height: kSpaceXs),
                      const Skeleton(width: 50, height: 11),
                    ],
                  ],
                );
              }
              final balance = snap.data!;
              final color = account.type == 'credit'
                  ? (balance > 0
                      ? FincoreColors.negative
                      : FincoreColors.textPrimary)
                  : (balance < 0
                      ? FincoreColors.negative
                      : FincoreColors.textPrimary);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatAmount(balance),
                    style: TextStyle(
                      color: isArchived ? FincoreColors.textSubtle : color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (account.type == 'credit')
                    Text(
                      'de ${formatAmount(account.creditLimit)}',
                      style: const TextStyle(
                          color: FincoreColors.textSubtle, fontSize: 11),
                    ),
                ],
              );
            },
          ),
          if (!account.isProtected)
            _AccountRowMenu(account: account, isArchived: isArchived),
        ],
      ),
    );
  }

  String _subtitle(Account account, bool isArchived) {
    final typeLabel = _typeLabel(account.type);
    final description = account.description?.isNotEmpty == true
        ? ' · ${account.description}'
        : '';
    if (isArchived) return '$typeLabel$description · archivada';
    return '$typeLabel$description';
  }

  Color _typeColor(String t) => switch (t) {
        'cash' => FincoreColors.positive,
        'debit' => FincoreColors.accent,
        // Hotfix 2026-07-15: warning (amarillo) libera su semántico para
        // alertas operativas reales. categoryPurple para tipo credit.
        'credit' => FincoreColors.categoryPurple,
        _ => FincoreColors.textMuted,
      };
  IconData _typeIcon(String t) => switch (t) {
        'cash' => Icons.account_balance_wallet_outlined,
        'debit' => Icons.account_balance_outlined,
        'credit' => Icons.credit_card_outlined,
        _ => Icons.help_outline,
      };
  String _typeLabel(String t) => switch (t) {
        'cash' => 'Bolsa',
        'debit' => 'Débito',
        'credit' => 'Crédito',
        _ => t,
      };
}

/// Menú overflow por card. Muestra distintas opciones según si la cuenta
/// está activa o archivada. La Bolsa nunca lo muestra (protegida).
class _AccountRowMenu extends StatelessWidget {
  final Account account;
  final bool isArchived;
  const _AccountRowMenu({required this.account, required this.isArchived});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_AccountRowAction>(
      icon: const Icon(Icons.more_vert, color: FincoreColors.textSubtle),
      color: FincoreColors.surfaceElevated,
      onSelected: (action) => _handle(context, action),
      itemBuilder: (ctx) => isArchived
          ? const [
              PopupMenuItem(
                value: _AccountRowAction.unarchive,
                child: ListTile(
                  leading: Icon(Icons.unarchive_outlined,
                      color: FincoreColors.accent),
                  title: Text('Desarchivar'),
                  contentPadding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
              ),
              PopupMenuDivider(),
              PopupMenuItem(
                value: _AccountRowAction.delete,
                child: ListTile(
                  leading: Icon(Icons.delete_outline,
                      color: FincoreColors.negative),
                  title: Text('Eliminar',
                      style: TextStyle(color: FincoreColors.negative)),
                  contentPadding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ]
          : const [
              PopupMenuItem(
                value: _AccountRowAction.edit,
                child: ListTile(
                  leading: Icon(Icons.edit_outlined,
                      color: FincoreColors.textPrimary),
                  title: Text('Editar'),
                  contentPadding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
              ),
              PopupMenuItem(
                value: _AccountRowAction.archive,
                child: ListTile(
                  leading: Icon(Icons.archive_outlined,
                      color: FincoreColors.textPrimary),
                  title: Text('Archivar'),
                  contentPadding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
              ),
              PopupMenuDivider(),
              PopupMenuItem(
                value: _AccountRowAction.delete,
                child: ListTile(
                  leading: Icon(Icons.delete_outline,
                      color: FincoreColors.negative),
                  title: Text('Eliminar',
                      style: TextStyle(color: FincoreColors.negative)),
                  contentPadding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
    );
  }

  Future<void> _handle(
      BuildContext context, _AccountRowAction action) async {
    switch (action) {
      case _AccountRowAction.edit:
        context.push('/accounts/${account.id}/edit');
        return;
      case _AccountRowAction.archive:
        await _confirmArchive(context);
        return;
      case _AccountRowAction.unarchive:
        await _confirmUnarchive(context);
        return;
      case _AccountRowAction.delete:
        await _confirmDelete(context);
        return;
    }
  }

  Future<void> _confirmArchive(BuildContext context) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Archivar cuenta',
      message:
          '"${account.name}" ya no aparecerá al registrar movimientos, pero '
          'sigue en tu histórico y en reportes. Puedes desarchivarla cuando '
          'quieras.',
      confirmLabel: 'Archivar',
      destructive: false,
    );
    if (!ok || !context.mounted) return;
    try {
      await AppDependencies.of(context).accountsDao.archive(account.id);
      if (context.mounted) {
        showSuccessSnackbar(context, 'Cuenta archivada.');
      }
    } on AccountsDaoError catch (e) {
      if (context.mounted) showErrorSnackbar(context, e);
    }
  }

  Future<void> _confirmUnarchive(BuildContext context) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Desarchivar cuenta',
      message: '"${account.name}" vuelve a estar disponible para registrar '
          'movimientos.',
      confirmLabel: 'Desarchivar',
      destructive: false,
    );
    if (!ok || !context.mounted) return;
    try {
      await AppDependencies.of(context).accountsDao.unarchive(account.id);
      if (context.mounted) {
        showSuccessSnackbar(context, 'Cuenta desarchivada.');
      }
    } on AccountsDaoError catch (e) {
      if (context.mounted) showErrorSnackbar(context, e);
    }
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final deps = AppDependencies.of(context);
    final affected = await deps.accountsDao.countAssociatedEntries(account.id);
    if (!context.mounted) return;
    final impacts = [
      DestructiveImpact(
        icon: Icons.receipt_long,
        label: affected == 0
            ? 'Sin movimientos'
            : (affected == 1
                ? '1 movimiento se cancelará'
                : '$affected movimientos se cancelarán'),
      ),
      const DestructiveImpact(
        icon: Icons.history_toggle_off,
        label: 'No se puede deshacer',
      ),
    ];
    final description = affected == 0
        ? 'La cuenta no tiene movimientos activos. Se elimina permanentemente. '
            'Esta acción no se puede deshacer.'
        : 'Se cancelarán todos los movimientos donde esta cuenta figura como '
            'origen o destino. Esta acción no se puede deshacer.';
    final ok = await showDestructiveDialog(
      context,
      title: 'Eliminar cuenta',
      objectName: account.name,
      icon: Icons.delete_forever_outlined,
      impacts: impacts,
      description: description,
      confirmLabel:
          affected == 0 ? 'Eliminar' : 'Eliminar y cancelar movimientos',
    );
    if (!ok || !context.mounted) return;
    try {
      await deps.accountsDao.deleteAccount(account.id, deps.stateService);
      if (context.mounted) {
        showSuccessSnackbar(
          context,
          affected == 0
              ? 'Cuenta eliminada.'
              : 'Cuenta eliminada. $affected movimientos cancelados.',
        );
      }
    } on AccountsDaoError catch (e) {
      if (context.mounted) showErrorSnackbar(context, e);
    }
  }
}

enum _AccountRowAction { edit, archive, unarchive, delete }
