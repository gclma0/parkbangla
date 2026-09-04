import 'package:flutter/material.dart';
import 'i18n.dart';
import 'session.dart';
import 'theme.dart';
import 'widgets.dart';

class WalletPage extends StatefulWidget {
  const WalletPage({super.key});
  @override
  State<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage> {
  Map<String, dynamic>? w;
  String method = 'bKash';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await session.api.get('/wallet');
    setState(() => w = Map<String, dynamic>.from(data as Map));
  }

  @override
  Widget build(BuildContext context) {
    final i = I18n(session.bn);
    final ledger = (w?['ledger'] as List?) ?? [];
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width > 768;

    Widget balanceCard = Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Pb.yellow,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Pb.ink.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          )
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                i.t('Total Balance', 'মোট ব্যালেন্স'),
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Pb.ink),
              ),
              const SizedBox(height: 6),
              Text(
                '৳ ${(w?['balance'] as num?)?.toStringAsFixed(0) ?? '—'}',
                style: const TextStyle(fontSize: 38, fontWeight: FontWeight.w900, color: Pb.ink),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.account_balance_wallet, size: 32, color: Pb.ink),
          ),
        ],
      ),
    );

    Widget actionsCard = Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Pb.ink.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            i.t('Top up & Payment Methods', 'টপ আপ ও পেমেন্ট মাধ্যম'),
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Pb.ink),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ['bKash', 'Nagad', 'Rocket', 'card'].map((m) {
              final on = method == m;
              return ChoiceChip(
                selected: on,
                label: Text(m, style: TextStyle(fontWeight: on ? FontWeight.w800 : FontWeight.normal, fontSize: 13)),
                selectedColor: Pb.yellow,
                backgroundColor: Pb.cream,
                labelStyle: const TextStyle(color: Pb.ink),
                onSelected: (_) => setState(() => method = m),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                side: BorderSide(color: on ? Pb.yellowDeep : Pb.ink.withOpacity(0.06)),
              );
            }).toList(),
          ),
          const SizedBox(height: 18),
          YellowCta(
            label: i.t('Top up ৳2,000', '২,০০০ টাকা যোগ করুন'),
            onPressed: () async {
              await session.api.post('/wallet/topup', {'amount': 2000, 'method': method});
              await session.refreshMe();
              _load();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(i.t('Top up of ৳2,000 successful!', '২,০০০ টাকা টপ আপ সফল হয়েছে!'))),
                );
              }
            },
          ),
          if (session.isHost) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () async {
                try {
                  await session.api.post('/wallet/withdraw', {'amount': 500, 'destination': method});
                  await session.refreshMe();
                  _load();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(i.t('Withdraw of ৳500 successful!', '৫০০ টাকা প্রত্যাহার সফল হয়েছে!'))),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                }
              },
              icon: const Icon(Icons.outbox, size: 16),
              label: Text(i.t('Withdraw ৳500 to MFS', '৫০০ টাকা উত্তোলন করুন')),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ],
        ],
      ),
    );

    Widget ledgerCard = Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Pb.ink.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            i.t('Recent Activity', 'সাম্প্রতিক লেনদেন'),
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Pb.ink),
          ),
          const SizedBox(height: 12),
          if (ledger.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24),
              alignment: Alignment.center,
              child: Text(
                i.t('No transactions yet.', 'এখনো কোনো লেনদেন হয়নি।'),
                style: const TextStyle(color: Pb.muted, fontSize: 12, fontStyle: FontStyle.italic),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: ledger.take(20).length,
              separatorBuilder: (_, __) => Divider(color: Pb.ink.withOpacity(0.05), height: 20),
              itemBuilder: (context, idx) {
                final m = Map<String, dynamic>.from(ledger[idx] as Map);
                final amount = m['amount'] as num? ?? 0;
                final isCredit = amount > 0;
                return Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isCredit ? const Color(0xFFE8F5E9) : const Color(0xFFECEFF1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isCredit ? Icons.arrow_downward : Icons.arrow_upward,
                        color: isCredit ? Colors.green[800] : Pb.muted,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        m['reason']?.toString() ?? '',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Pb.ink),
                      ),
                    ),
                    Text(
                      '${isCredit ? '+' : ''}৳${amount.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        color: isCredit ? Colors.green[800] : Pb.ink,
                      ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 800),
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          children: [
            Text(
              i.wallet,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Pb.ink),
            ),
            const SizedBox(height: 20),
            if (isDesktop)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 11,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        balanceCard,
                        const SizedBox(height: 20),
                        actionsCard,
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    flex: 12,
                    child: ledgerCard,
                  ),
                ],
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  balanceCard,
                  const SizedBox(height: 16),
                  actionsCard,
                  const SizedBox(height: 16),
                  ledgerCard,
                ],
              ),
          ],
        ),
      ),
    );
  }
}
