import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/models.dart';
import '../services/trading_api.dart';
import '../theme.dart';

/// Monthly Momentum Portfolio - the validated cross-sectional edge.
/// Rank the liquid universe by 30-day return, hold the top 10, rebalance monthly.
class MomentumScreen extends StatefulWidget {
  const MomentumScreen({super.key, required this.account});
  final Account account;
  @override
  State<MomentumScreen> createState() => _MomentumScreenState();
}

class _MomentumScreenState extends State<MomentumScreen> {
  final _api = TradingApi();
  final _money = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
  List<MomentumPick> _picks = [];
  Map<String, dynamic>? _portfolio;
  bool _loading = true;
  bool _rebalancing = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([_api.momentumRanking(top: 10), _api.momentumPortfolio(widget.account.id)]);
      setState(() {
        _picks = results[0] as List<MomentumPick>;
        _portfolio = results[1] as Map<String, dynamic>;
      });
    } catch (e) {
      setState(() => _message = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _rebalance() async {
    setState(() {
      _rebalancing = true;
      _message = null;
    });
    try {
      final res = await _api.momentumRebalance(widget.account.id, top: 10);
      setState(
        () => _message =
            'Rebalanced: sold ${(res['sold'] as List).length}, bought ${(res['bought'] as List).length}. '
            'Portfolio ₹${res['portfolio_value']}',
      );
      await _load();
    } catch (e) {
      setState(() => _message = '$e');
    } finally {
      if (mounted) setState(() => _rebalancing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final holdings = (_portfolio?['holdings'] as List?) ?? [];
    return Scaffold(
      appBar: AppBar(title: const Text('Momentum Portfolio')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _banner(context),
            const SizedBox(height: 12),
            if (_portfolio != null) _portfolioCard(_portfolio!),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _rebalancing ? null : _rebalance,
              icon: _rebalancing
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.sync),
              label: Text(
                holdings.isEmpty ? 'Build portfolio (buy this month\'s top 10)' : 'Rebalance into this month\'s picks',
              ),
            ),
            if (_message != null) Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(_message!)),
            const SizedBox(height: 8),
            if (holdings.isNotEmpty) ...[
              Text('Your holdings (${holdings.length})', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              ...holdings.map((h) => _holdingTile(h as Map<String, dynamic>)),
              const Divider(height: 32),
            ],
            Text("This month's top 10 (30-day momentum)", style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            if (_loading)
              const Center(
                child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()),
              ),
            ..._picks.asMap().entries.map((e) => _pickTile(e.key + 1, e.value)),
          ],
        ),
      ),
    );
  }

  Widget _banner(BuildContext context) => Card(
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: const Padding(
      padding: EdgeInsets.all(12),
      child: Text(
        'Paper money. Ranks the liquid market by 30-day return and holds the top 10, rebalanced monthly — '
        'a factor that beat the market across 6+ years of testing. But: bumpy month to month, and past '
        'results carry survivorship-bias caveats. Not investment advice.',
        style: TextStyle(fontSize: 12),
      ),
    ),
  );

  Widget _portfolioCard(Map<String, dynamic> p) {
    final total = (p['total_value'] as num?)?.toDouble() ?? 0;
    final start = widget.account.startingBalance ?? 10000;
    final pnl = total - start;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Portfolio value', style: Theme.of(context).textTheme.labelMedium),
            Text(_money.format(total), style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text(
              '${pnl >= 0 ? "▲" : "▼"} ${_money.format(pnl.abs())} since start',
              style: TextStyle(color: pnlColor(context, pnl), fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              'Cash ${_money.format((p['cash'] as num?)?.toDouble() ?? 0)} · '
              'Invested ${_money.format((p['holdings_value'] as num?)?.toDouble() ?? 0)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _holdingTile(Map<String, dynamic> h) {
    final pnl = (h['pnl'] as num?)?.toDouble() ?? 0;
    return ListTile(
      dense: true,
      title: Text(h['symbol'] as String),
      subtitle: Text(
        '${h['qty']} @ ₹${(h['avg_price'] as num).toStringAsFixed(1)} → ₹${(h['ltp'] as num).toStringAsFixed(1)}',
      ),
      trailing: Text(
        '${pnl >= 0 ? "+" : ""}${pnl.toStringAsFixed(0)}',
        style: TextStyle(color: pnlColor(context, pnl), fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _pickTile(int rank, MomentumPick p) {
    final conf = p.confidenceRaw ?? (68 - (rank - 1) * 2).clamp(50, 68);
    return ListTile(
      dense: true,
      leading: CircleAvatar(radius: 14, child: Text('$rank', style: const TextStyle(fontSize: 12))),
      title: Row(
        children: [
          Text(p.symbol),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(color: Colors.green.shade600, borderRadius: BorderRadius.circular(4)),
            child: Text(
              p.signal,
              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      subtitle: Text(
        '${p.name}  •  Hold ${p.holdPeriod}  •  Conf $conf%',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Text(
        '+${p.trailingReturnPct.toStringAsFixed(1)}%\n₹${p.lastClose.toStringAsFixed(0)}',
        textAlign: TextAlign.right,
        style: TextStyle(color: Colors.green.shade600, fontSize: 12),
      ),
    );
  }
}
