import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/trading_api.dart';
import '../theme.dart';

/// The core auto-pilot experience: see today's scanned picks, flip the run,
/// and read the P&L report. Paper mode on real market data.
class AutoPilotScreen extends StatefulWidget {
  const AutoPilotScreen({super.key, required this.account});
  final Account account;
  @override
  State<AutoPilotScreen> createState() => _AutoPilotScreenState();
}

class _AutoPilotScreenState extends State<AutoPilotScreen> {
  final _api = TradingApi();
  List<Candidate> _candidates = [];
  Map<String, dynamic>? _summary;
  bool _loading = true;
  bool _running = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([_api.scan(limit: 20), _api.report(widget.account.id)]);
      setState(() {
        _candidates = results[0] as List<Candidate>;
        _summary = results[1] as Map<String, dynamic>;
      });
    } catch (e) {
      setState(() => _message = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _run() async {
    setState(() {
      _running = true;
      _message = null;
    });
    try {
      final res = await _api.autopilotRun(widget.account.id, topK: 10, lookbackDays: 180);
      final s = res['summary'] as Map<String, dynamic>;
      setState(() => _message = 'Auto-pilot ran: ${s['total_trades']} trades, net ₹${s['net_pnl']}');
      await _load();
    } catch (e) {
      setState(() => _message = '$e');
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Auto-Pilot')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Paper Auto-Pilot', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 4),
                    const Text('Scans the market, trades the top momentum picks, and reports P&L. No real money.'),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _running ? null : _run,
                      icon: _running
                          ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.play_arrow),
                      label: const Text('Run Auto-Pilot'),
                    ),
                  ],
                ),
              ),
            ),
            if (_message != null) Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(_message!)),
            if (_summary != null) _reportCard(_summary!),
            const SizedBox(height: 16),
            Text("Today's picks (scanner)", style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (_loading) const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
            ..._candidates.map(_candidateTile),
            if (!_loading && _candidates.isEmpty)
              const Padding(padding: EdgeInsets.all(16), child: Text('No candidates right now.')),
          ],
        ),
      ),
    );
  }

  Widget _reportCard(Map<String, dynamic> s) {
    final net = double.tryParse('${s['net_pnl']}') ?? 0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Account report', style: Theme.of(context).textTheme.titleMedium),
            const Divider(),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Net P&L'),
              Text('₹${s['net_pnl']}', style: TextStyle(fontWeight: FontWeight.w700, color: pnlColor(context, net))),
            ]),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Trades'), Text('${s['total_trades']}')]),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Win rate'),
              Text('${(((s['win_rate'] ?? 0) as num) * 100).toStringAsFixed(1)}%'),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _candidateTile(Candidate c) {
    return Card(
      child: ListTile(
        dense: true,
        leading: CircleAvatar(child: Text(c.confidence.toStringAsFixed(0))),
        title: Text('${c.symbol}  ·  ${c.signal}'),
        subtitle: Text(c.name),
        trailing: c.target == null
            ? null
            : Text('T ₹${c.target!.toStringAsFixed(0)}\nSL ₹${c.stopLoss?.toStringAsFixed(0) ?? "-"}', textAlign: TextAlign.right, style: const TextStyle(fontSize: 12)),
      ),
    );
  }
}
