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
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(i.wallet, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: Pb.yellow, borderRadius: BorderRadius.circular(28)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(i.t('Balance', 'ব্যালেন্স'), style: const TextStyle(fontWeight: FontWeight.w700)),
              Text('৳${(w?['balance'] as num?)?.toStringAsFixed(0) ?? '—'}',
                  style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w900)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          children: ['bKash', 'Nagad', 'Rocket', 'card'].map((m) {
            final on = method == m;
            return ChoiceChip(
              selected: on,
              label: Text(m),
              selectedColor: Pb.yellow,
              onSelected: (_) => setState(() => method = m),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        YellowCta(
          label: i.t('Top up ৳2,000 (demo)', '২,০০০ টাকা যোগ (ডেমো)'),
          onPressed: () async {
            await session.api.post('/wallet/topup', {'amount': 2000, 'method': method});
            await session.refreshMe();
            _load();
          },
        ),
        if (session.isHost) ...[
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: () async {
              await session.api.post('/wallet/withdraw', {'amount': 500, 'destination': method});
              await session.refreshMe();
              _load();
            },
            child: Text(i.t('Withdraw ৳500 to MFS', '৫০০ টাকা এমএফএস-এ তুলুন')),
          ),
        ],
        const SizedBox(height: 24),
        Text(i.t('Activity', 'লেনদেন'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        ...ledger.take(20).map((row) {
          final m = Map<String, dynamic>.from(row as Map);
          return ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('${m['reason']}'),
            trailing: Text('৳${m['amount']}', style: const TextStyle(fontWeight: FontWeight.w800)),
          );
        }),
      ],
    );
  }
}
