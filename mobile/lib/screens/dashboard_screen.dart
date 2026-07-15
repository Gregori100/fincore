import 'dart:async';

import 'package:fincore/app_dependencies.dart';
import 'package:fincore/data/daos/entries_dao.dart';
import 'package:fincore/data/database.dart' as db;
import 'package:fincore/data/reports.dart';
import 'package:fincore/theme/fincore_colors.dart';
import 'package:fincore/widgets/amount_formatter.dart';
import 'package:fincore/widgets/base_card.dart';
import 'package:fincore/widgets/movement_row.dart';
import 'package:fincore/widgets/skeleton.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Stream<double>? _boStream;
  Stream<double>? _deStream;
  Stream<double>? _crStream;
  Stream<List<db.Account>>? _accountsStream;
  Stream<List<EntryWithRelations>>? _recentEntriesStream;
  // Sprint flutter-dashboard-bundle-v1.
  Stream<TodaySummary>? _todayStream;
  Stream<List<DailyBalance>>? _boSparkStream;
  Stream<List<DailyBalance>>? _deSparkStream;
  Stream<List<DailyBalance>>? _crSparkStream;
  String? _selectedAccountId;
  StreamSubscription<List<db.Account>>? _accountsListenerSub;
  // Sprint dashboard-bundle — actualización a RN-DB15: al cruzar
  // medianoche local con el dashboard abierto, la vista "Hoy" y los
  // sparklines 30d se recrean automáticamente sin necesidad de salir
  // de la pantalla. Se programa un Timer one-shot para la próxima
  // medianoche local; al dispararse recrea los streams del día y
  // reprograma el siguiente.
  Timer? _midnightTimer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_boStream != null) return;
    final deps = AppDependencies.of(context);
    _boStream = deps.stateService.watchBo();
    _deStream = deps.stateService.watchDe();
    _crStream = deps.stateService.watchCr();
    _accountsStream = deps.accountsDao.watchActive();
    _recentEntriesStream = deps.entriesDao.watchPage(limit: 10);
    _todayStream = deps.reportsService.watchTodaySummary();
    _boSparkStream = deps.reportsService.watchDailyBalance30d(kind: 'bo');
    _deSparkStream = deps.reportsService.watchDailyBalance30d(kind: 'de');
    _crSparkStream = deps.reportsService.watchDailyBalance30d(kind: 'cr');
    // Listener para resetear el filtro cuando se archiva la cuenta
    // seleccionada (RN-DB11).
    _accountsListenerSub = _accountsStream!.listen((accounts) {
      final selected = _selectedAccountId;
      if (selected == null) return;
      final stillActive = accounts.any((a) => a.id == selected);
      if (!stillActive && mounted) {
        setState(() {
          _selectedAccountId = null;
          _recentEntriesStream = deps.entriesDao.watchPage(limit: 10);
        });
      }
    });
    _scheduleMidnightRefresh();
  }

  void _scheduleMidnightRefresh() {
    _midnightTimer?.cancel();
    final now = DateTime.now();
    final nextMidnight = DateTime(now.year, now.month, now.day)
        .add(const Duration(days: 1));
    // +1s de margen para que `DateTime.now()` dentro de los servicios
    // ya vea el día nuevo cuando se recrean los streams.
    final delay = nextMidnight.difference(now) + const Duration(seconds: 1);
    _midnightTimer = Timer(delay, _onMidnightCrossed);
  }

  void _onMidnightCrossed() {
    if (!mounted) return;
    final deps = AppDependencies.of(context);
    setState(() {
      _todayStream = deps.reportsService.watchTodaySummary();
      _boSparkStream = deps.reportsService.watchDailyBalance30d(kind: 'bo');
      _deSparkStream = deps.reportsService.watchDailyBalance30d(kind: 'de');
      _crSparkStream = deps.reportsService.watchDailyBalance30d(kind: 'cr');
    });
    _scheduleMidnightRefresh();
  }

  @override
  void dispose() {
    _accountsListenerSub?.cancel();
    _midnightTimer?.cancel();
    super.dispose();
  }

  void _onFilterChanged(String? accountId) {
    final deps = AppDependencies.of(context);
    setState(() {
      _selectedAccountId = accountId;
      _recentEntriesStream = deps.entriesDao.watchPage(
        limit: 10,
        accountIds: accountId != null ? [accountId] : null,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: RichText(
          text: const TextSpan(
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
            children: [
              TextSpan(text: 'Fin', style: TextStyle(color: FincoreColors.accent)),
              TextSpan(text: 'Core', style: TextStyle(color: FincoreColors.textPrimary)),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart),
            tooltip: 'Reportes',
            onPressed: () => context.push('/reports'),
          ),
          IconButton(
            icon: const Icon(Icons.calendar_month_outlined),
            tooltip: 'Presupuestos semanales',
            onPressed: () => context.push('/budgets'),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Configuración',
            onPressed: () => context.push('/settings'),
          ),
          // Sprint quality-review (A5): con los 4 IconButtons directos
          // originales (Reportes, Presupuestos semanales, Categorías,
          // Configuración) el AppBar no cabía en un cel de 360dp y partía
          // el wordmark "FinCore". "Categorías" se mueve a este menú por
          // ser la acción menos frecuente de las 4 (se navega mucho más
          // seguido a Reportes/Presupuestos/Configuración).
          PopupMenuButton<String>(
            tooltip: 'Más opciones',
            onSelected: (value) {
              if (value == 'categories') context.push('/categories');
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'categories',
                child: Row(
                  children: [
                    Icon(Icons.label_outline),
                    SizedBox(width: 8),
                    Text('Categorías'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/entries/new'),
        tooltip: 'Nuevo movimiento',
        icon: const Icon(Icons.add),
        label: const Text('Movimiento'),
        backgroundColor: FincoreColors.accent,
        foregroundColor: FincoreColors.canvas,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          _TodayCard(stream: _todayStream!),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _TotalCard(
                  label: 'Bolsa + Débito',
                  code: 'BO',
                  stream: _boStream!,
                  color: FincoreColors.positive,
                  sparklineStream: _boSparkStream,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _TotalCard(
                  label: 'Deuda',
                  code: 'DE',
                  stream: _deStream!,
                  color: FincoreColors.negative,
                  sparklineStream: _deSparkStream,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _TotalCard(
                  label: 'Disponible',
                  code: 'CR',
                  stream: _crStream!,
                  color: FincoreColors.accent,
                  sparklineStream: _crSparkStream,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SectionTitle(
            'Mis cuentas',
            trailing: TextButton.icon(
              onPressed: () => context.push('/accounts'),
              icon: const Icon(Icons.arrow_forward, size: 16),
              label: const Text('Ver todas'),
            ),
          ),
          const SizedBox(height: 8),
          StreamBuilder<List<db.Account>>(
            stream: _accountsStream,
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Column(
                  children: [
                    SkeletonCard(),
                    SizedBox(height: 8),
                    SkeletonCard(),
                    SizedBox(height: 8),
                    SkeletonCard(),
                  ],
                );
              }
              final accounts = snap.data!;
              if (accounts.isEmpty) {
                return const BaseCard(
                  child: Text(
                    'No hay cuentas todavía. Crear una desde "Cuentas".',
                    style: TextStyle(color: FincoreColors.textMuted),
                  ),
                );
              }
              return Column(
                children: [
                  for (var i = 0; i < accounts.length; i++) ...[
                    if (i > 0) const SizedBox(height: 8),
                    _AccountTile(account: accounts[i]),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          SectionTitle(
            'Últimos movimientos',
            trailing: TextButton.icon(
              onPressed: () => context.push('/entries'),
              icon: const Icon(Icons.arrow_forward, size: 16),
              label: const Text('Ver todos'),
            ),
          ),
          const SizedBox(height: 8),
          _AccountFilterChips(
            stream: _accountsStream!,
            selectedId: _selectedAccountId,
            onChanged: _onFilterChanged,
          ),
          const SizedBox(height: 8),
          StreamBuilder<List<EntryWithRelations>>(
            stream: _recentEntriesStream,
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Column(
                  children: [
                    SkeletonCard(),
                    SizedBox(height: 8),
                    SkeletonCard(),
                    SizedBox(height: 8),
                    SkeletonCard(),
                  ],
                );
              }
              final entries = snap.data!;
              if (entries.isEmpty) {
                return const BaseCard(
                  child: Text(
                    'Aún no hay movimientos. Tocar "Movimiento" para registrar uno.',
                    style: TextStyle(color: FincoreColors.textMuted),
                  ),
                );
              }
              return Column(
                children: [
                  for (var i = 0; i < entries.length; i++) ...[
                    if (i > 0) const SizedBox(height: 8),
                    MovementRow(item: entries[i], dateFormatPattern: 'd MMM'),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _TotalCard extends StatelessWidget {
  /// Label descriptivo mostrado en el card (arriba, uppercase).
  final String label;

  /// Código corto (BO/DE/CR) usado solo en `Semantics.label` para
  /// accesibilidad. No se renderiza visualmente tras la audit 2026-07-14.
  final String code;
  final Stream<double> stream;
  final Color color;

  /// Sprint flutter-dashboard-bundle-v1: sparkline opcional del saldo
  /// diario en los últimos 30 días.
  final Stream<List<DailyBalance>>? sparklineStream;

  const _TotalCard({
    required this.label,
    required this.code,
    required this.stream,
    required this.color,
    this.sparklineStream,
  });

  @override
  Widget build(BuildContext context) {
    return BaseCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label descriptivo arriba (jerarquía invertida post-audit 2026-07-14).
          // El código BO/DE/CR queda como Semantics label para accesibilidad.
          Semantics(
            label: '$code — $label',
            child: Text(
              label.toUpperCase(),
              style: const TextStyle(
                color: FincoreColors.textMuted,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 6),
          StreamBuilder<double>(
            stream: stream,
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 2),
                  child: Skeleton(width: 80, height: 20),
                );
              }
              return Text(
                formatAmount(snap.data!),
                // token-exception: 18 hero del monto KPI, sin token intermedio
                // entre headingM (16) y headingL (20). Ligero bump vs 16 previo
                // para reforzar la lectura del número.
                style: TextStyle(
                  color: color,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              );
            },
          ),
          if (sparklineStream != null) ...[
            const SizedBox(height: 6),
            _Sparkline(stream: sparklineStream!, color: color),
          ],
        ],
      ),
    );
  }
}

/// Card "Hoy" del dashboard. Sprint `flutter-dashboard-bundle-v1`.
/// Muestra fecha del día + ingresos, gastos, neto del día calendario
/// local. Sin movimientos → `$0 · $0 · Neto $0` en textMuted.
class _TodayCard extends StatelessWidget {
  final Stream<TodaySummary> stream;
  const _TodayCard({required this.stream});

  @override
  Widget build(BuildContext context) {
    return BaseCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: StreamBuilder<TodaySummary>(
        stream: stream,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const SizedBox(
              height: 48,
              child: Center(child: Skeleton(width: 200, height: 14)),
            );
          }
          final data = snap.data!;
          final rawDate =
              DateFormat("EEE d MMM", 'es_MX').format(data.day);
          final dateLabel =
              '${rawDate[0].toUpperCase()}${rawDate.substring(1)}';
          final hasMovements =
              data.totalIncome > 0 || data.totalExpense > 0;
          final defaultColor = hasMovements
              ? FincoreColors.textPrimary
              : FincoreColors.textMuted;
          final incomeColor = data.totalIncome > 0
              ? FincoreColors.positive
              : FincoreColors.textMuted;
          final expenseColor = data.totalExpense > 0
              ? FincoreColors.negative
              : FincoreColors.textMuted;
          final netColor = !hasMovements
              ? FincoreColors.textMuted
              : (data.net >= 0
                  ? FincoreColors.positive
                  : FincoreColors.negative);
          // Sprint quality-review: sin movimientos → `$0` sin signo. `+`
          // sobre cero es ruido semántico (sugiere ingreso donde no lo
          // hubo).
          final String netLabel;
          if (!hasMovements) {
            netLabel = formatAmount(0);
          } else if (data.net >= 0) {
            netLabel = '+${formatAmount(data.net)}';
          } else {
            netLabel = '-${formatAmount(data.net.abs())}';
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hoy · $dateLabel',
                style: TextStyle(
                  color: defaultColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: _TodayMetric(
                      label: 'Ingresos',
                      value: formatAmount(data.totalIncome),
                      color: incomeColor,
                    ),
                  ),
                  Expanded(
                    child: _TodayMetric(
                      label: 'Gastos',
                      value: formatAmount(data.totalExpense),
                      color: expenseColor,
                    ),
                  ),
                  Expanded(
                    child: _TodayMetric(
                      label: 'Neto',
                      value: netLabel,
                      color: netColor,
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TodayMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _TodayMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: FincoreColors.textMuted,
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 1),
        // Sprint quality-review: `FittedBox(scaleDown)` en vez de
        // `ellipsis` para que montos largos (7+ dígitos) se lean
        // completos en cel angosto. `scaleDown` solo achica cuando no
        // cabe; con montos chicos se ve al tamaño natural.
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            maxLines: 1,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

/// Mini-gráfico horizontal de saldo diario. Sprint
/// `flutter-dashboard-bundle-v1`. Sin ejes ni labels — solo la línea.
class _Sparkline extends StatelessWidget {
  final Stream<List<DailyBalance>> stream;
  final Color color;
  const _Sparkline({required this.stream, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 24,
      child: StreamBuilder<List<DailyBalance>>(
        stream: stream,
        builder: (context, snap) {
          // Sprint quality-review: skeleton durante loading para evitar
          // el parpadeo de ~200ms entre balance visible y sparkline. En
          // empty (edge inesperado; el servicio garantiza 30 puntos
          // backfilled) también skeleton — degradación grácil.
          if (!snap.hasData || snap.data!.isEmpty) {
            return const Skeleton(width: double.infinity, height: 24);
          }
          return CustomPaint(
            painter: _SparklinePainter(data: snap.data!, color: color),
            size: Size.infinite,
          );
        },
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<DailyBalance> data;
  final Color color;
  const _SparklinePainter({required this.data, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;
    // Escala vertical al min-max local. Si min == max → línea centrada.
    var minY = data.first.balance;
    var maxY = data.first.balance;
    for (final p in data) {
      if (p.balance < minY) minY = p.balance;
      if (p.balance > maxY) maxY = p.balance;
    }
    final path = Path();
    final dx = data.length > 1 ? size.width / (data.length - 1) : size.width;
    for (var i = 0; i < data.length; i++) {
      final x = i * dx;
      final double y;
      if (maxY == minY) {
        y = size.height / 2;
      } else {
        // Invertir Y: valor alto arriba (y=0 arriba en Canvas).
        y = size.height -
            ((data[i].balance - minY) / (maxY - minY)) * size.height;
      }
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter old) =>
      old.data != data || old.color != color;
}

/// Chips scrollables horizontales para filtrar la lista de "Últimos
/// movimientos" del dashboard por una cuenta específica. Sprint
/// `flutter-dashboard-bundle-v1`.
///
/// `selectedId == null` → chip "Todas" seleccionado (RN-DB10). Al
/// tapear un chip de cuenta, se emite el `accountId`. El state vive en
/// el `_DashboardScreenState` (no persiste entre sesiones).
class _AccountFilterChips extends StatelessWidget {
  final Stream<List<db.Account>> stream;
  final String? selectedId;
  final ValueChanged<String?> onChanged;
  const _AccountFilterChips({
    required this.stream,
    required this.selectedId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<db.Account>>(
      stream: stream,
      builder: (context, snap) {
        final accounts = snap.data ?? const <db.Account>[];
        // Sprint quality-review: SizedBox 34→44 px para respetar el
        // mínimo WCAG 2.5.5 (44x44) y aproximar Material touch target
        // (48 dp). Combinado con padding vertical 8 del chip da un hit
        // area cómodo aunque el visual permanece compacto por
        // `visualDensity: compact`.
        return SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _buildChip(context, label: 'Todas', id: null),
              for (final a in accounts) ...[
                const SizedBox(width: 6),
                _buildChip(context, label: a.name, id: a.id),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildChip(BuildContext context,
      {required String label, required String? id}) {
    final selected = selectedId == id;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onChanged(id),
      showCheckmark: false,
      selectedColor: FincoreColors.accent.withValues(alpha: 0.18),
      backgroundColor: FincoreColors.surface,
      side: BorderSide(
        color: selected ? FincoreColors.accent : FincoreColors.border,
      ),
      labelStyle: TextStyle(
        color: selected ? FincoreColors.accent : FincoreColors.textPrimary,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        fontSize: 12,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      // Sprint quality-review: quitamos `MaterialTapTargetSize.shrinkWrap`
      // que colapsaba el hit area. Mantenemos `visualDensity: compact`
      // para preservar la densidad visual (labels apretados) sin sacrificar
      // el touch target.
      visualDensity: VisualDensity.compact,
    );
  }
}

class _AccountTile extends StatelessWidget {
  final db.Account account;
  const _AccountTile({required this.account});

  @override
  Widget build(BuildContext context) {
    return BaseCard(
      onTap: account.isProtected
          ? null
          : () => context.push('/accounts/${account.id}/edit'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _typeColor(account.type).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(_typeIcon(account.type), size: 18, color: _typeColor(account.type)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(account.name,
                    style: const TextStyle(
                        color: FincoreColors.textPrimary, fontWeight: FontWeight.w600)),
                Text(
                  _typeLabel(account.type),
                  style: const TextStyle(color: FincoreColors.textSubtle, fontSize: 12),
                ),
              ],
            ),
          ),
          _BalanceLabel(accountId: account.id, accountType: account.type),
        ],
      ),
    );
  }

  Color _typeColor(String t) => switch (t) {
        'cash' => FincoreColors.positive,
        'debit' => FincoreColors.accent,
        // Regla CLAUDE.md: `warning` reservado para alertas operativas, no
        // para tipos de cuenta. Sprint flutter-dashboard-clarity-v1 migró
        // a `textMuted` (gris) por conservación; hotfix 2026-07-15 elige
        // `categoryPurple` por feedback (gris se sentía "simple"). El monto
        // de la deuda sigue en `negative` (rojo) que es semántico correcto.
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

class _BalanceLabel extends StatelessWidget {
  final String accountId;
  final String accountType;
  const _BalanceLabel({required this.accountId, required this.accountType});

  @override
  Widget build(BuildContext context) {
    final deps = AppDependencies.of(context);
    return StreamBuilder<double>(
      stream: deps.stateService.watchAccountBalance(accountId, accountType),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Skeleton(width: 60, height: 14);
        }
        final balance = snap.data!;
        final isCredit = accountType == 'credit';
        final color = isCredit
            ? (balance > 0 ? FincoreColors.negative : FincoreColors.textPrimary)
            : (balance < 0 ? FincoreColors.negative : FincoreColors.textPrimary);
        return Text(
          formatAmount(balance),
          style: TextStyle(color: color, fontWeight: FontWeight.w700),
        );
      },
    );
  }
}

