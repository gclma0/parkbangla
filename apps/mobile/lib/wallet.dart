import 'package:flutter/material.dart';
import 'i18n.dart';
import 'session.dart';
import 'theme.dart';

class WalletPage extends StatefulWidget {
  const WalletPage({super.key});

  @override
  State<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage> {
  final amount = TextEditingController(text: '2000');
  final destination = TextEditingController();
  Map<String, dynamic>? wallet;
  String method = 'bKash';
  bool loading = true;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    amount.dispose();
    destination.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await session.api.get('/wallet');
      if (mounted) setState(() => wallet = Map<String, dynamic>.from(data as Map));
    } catch (e) {
      _snack('Wallet failed to load: $e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _topUp() async {
    final value = double.tryParse(amount.text.trim());
    if (value == null || value <= 0) {
      _snack('Enter a valid amount.');
      return;
    }
    setState(() => busy = true);
    try {
      await session.api.post('/wallet/topup', {'amount': value, 'method': method});
      await session.refreshMe();
      await _load();
      _snack('Top up successful.');
    } catch (e) {
      _snack('Top up failed: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _withdraw() async {
    final value = double.tryParse(amount.text.trim());
    final dest = destination.text.trim().isEmpty ? method : destination.text.trim();
    if (value == null || value <= 0) {
      _snack('Enter a valid amount.');
      return;
    }
    setState(() => busy = true);
    try {
      await session.api.post('/wallet/withdraw', {'amount': value, 'destination': dest});
      await session.refreshMe();
      await _load();
      _snack('Withdraw request completed.');
    } catch (e) {
      _snack('Withdraw failed: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final i = I18n(session.bn);
    final ledger = List<Map<String, dynamic>>.from(
      (wallet?['ledger'] as List? ?? const []).map((e) => Map<String, dynamic>.from(e as Map)),
    );
    final balance = (wallet?['balance'] as num?)?.toDouble() ?? (session.user?['walletBalance'] as num?)?.toDouble() ?? 0;

    if (loading) return const Center(child: CircularProgressIndicator(color: Pb.yellow));

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 820),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          children: [
            Row(
              children: [
                Text(i.wallet, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Pb.ink)),
                const Spacer(),
                IconButton(onPressed: _load, icon: const Icon(Icons.refresh), tooltip: 'Refresh'),
              ],
            ),
            const SizedBox(height: 16),
            _balanceCard(balance),
            const SizedBox(height: 16),
            _actionPanel(),
            const SizedBox(height: 16),
            _ledger(ledger),
          ],
        ),
      ),
    );
  }

  Widget _balanceCard(double balance) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Pb.ink,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 14, offset: const Offset(0, 8))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Pb.yellow, borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.account_balance_wallet, color: Pb.ink),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Available balance', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('Tk ${balance.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w900)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionPanel() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Pb.ink.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Add or withdraw money', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Pb.ink)),
          const SizedBox(height: 12),
          TextField(
            controller: amount,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              labelText: 'Amount',
              prefixText: 'Tk ',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ['bKash', 'Nagad', 'Rocket', 'Card', 'Cash'].map((m) {
              final selected = method == m;
              return ChoiceChip(
                label: Text(m),
                selected: selected,
                selectedColor: Pb.yellow,
                backgroundColor: Pb.cream,
                labelStyle: TextStyle(color: Pb.ink, fontWeight: selected ? FontWeight.w900 : FontWeight.w600),
                side: BorderSide(color: selected ? Pb.yellowDeep : Pb.ink.withOpacity(0.12)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onSelected: (_) => setState(() => method = m),
              );
            }).toList(),
          ),
          if (session.isHost) ...[
            const SizedBox(height: 12),
            TextField(
              controller: destination,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Withdraw destination',
                hintText: 'MFS number or bank note',
                border: OutlineInputBorder(),
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: busy ? null : _topUp,
                  icon: const Icon(Icons.add),
                  label: const Text('Top up'),
                  style: FilledButton.styleFrom(backgroundColor: Pb.yellow, foregroundColor: Pb.ink, minimumSize: const Size.fromHeight(48)),
                ),
              ),
              if (session.isHost) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: busy ? null : _withdraw,
                    icon: const Icon(Icons.outbox),
                    label: const Text('Withdraw'),
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Demo wallet only. Real payment provider settlement will be integrated in the final stage.',
            style: TextStyle(color: Pb.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _ledger(List<Map<String, dynamic>> ledger) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Pb.ink.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Recent activity', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Pb.ink)),
          const SizedBox(height: 10),
          if (ledger.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 26),
              child: Center(child: Text('No wallet activity yet.', style: TextStyle(color: Pb.muted))),
            )
          else
            ...ledger.take(30).map(_ledgerRow),
        ],
      ),
    );
  }

  Widget _ledgerRow(Map<String, dynamic> row) {
    final amountValue = (row['amount'] as num?)?.toDouble() ?? 0;
    final credit = amountValue >= 0;
    final createdAt = row['createdAt']?.toString();
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Pb.ink.withOpacity(0.06)))),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: credit ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
            child: Icon(credit ? Icons.arrow_downward : Icons.arrow_upward, size: 18, color: credit ? Colors.green[800] : Colors.red[700]),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(row['reason']?.toString() ?? 'Wallet activity', style: const TextStyle(fontWeight: FontWeight.w800, color: Pb.ink)),
                if (createdAt != null) Text(createdAt.split('T').first, style: const TextStyle(color: Pb.muted, fontSize: 12)),
              ],
            ),
          ),
          Text(
            '${credit ? '+' : '-'}Tk ${amountValue.abs().toStringAsFixed(0)}',
            style: TextStyle(fontWeight: FontWeight.w900, color: credit ? Colors.green[800] : Colors.red[700]),
          ),
        ],
      ),
    );
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}
