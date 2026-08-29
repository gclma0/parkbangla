import 'package:flutter/material.dart';
import 'i18n.dart';
import 'session.dart';
import 'spot_flow.dart';
import 'theme.dart';

class BookingsPage extends StatefulWidget {
  const BookingsPage({super.key});
  @override
  State<BookingsPage> createState() => _BookingsPageState();
}

class _BookingsPageState extends State<BookingsPage> {
  List<Map<String, dynamic>> items = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    session.addListener(_reload);
    _load();
  }

  @override
  void dispose() {
    session.removeListener(_reload);
    super.dispose();
  }

  void _reload() => _load();

  Future<void> _load() async {
    try {
      final data = await session.api.get('/bookings', session.isHost ? {'role': 'host'} : null);
      items = (data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {}
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final i = I18n(session.bn);
    if (loading) return const Center(child: CircularProgressIndicator(color: Pb.yellow));
    if (items.isEmpty) return Center(child: Text(i.t('No passes yet. Swipe a driveway.', 'এখনো কোনো পাস নেই।')));
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: items.length + 1,
      itemBuilder: (ctx, n) {
        if (n == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(i.bookings, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
          );
        }
        final b = items[n - 1];
        final spot = Map<String, dynamic>.from(b['spot'] as Map? ?? {});
        final photos = spot['photos'];
        final img = photos is List && photos.isNotEmpty ? photos.first.toString() : null;
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: ScaleTap(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CheckInPage(bookingId: b['id'] as String))),
            child: Container(
              height: 148,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
              clipBehavior: Clip.antiAlias,
              child: Row(
                children: [
                  SizedBox(
                    width: 120,
                    child: img == null ? Container(color: Pb.yellow) : Image.network(img, fit: BoxFit.cover),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${spot['area'] ?? ''} · ${b['status']}', style: const TextStyle(fontWeight: FontWeight.w800)),
                          Text('${spot['address'] ?? ''}', maxLines: 2, overflow: TextOverflow.ellipsis),
                          const Spacer(),
                          Text('৳${b['amount']}  ·  PIN ${b['pin']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                          if (session.isHost && b['status'] == 'PENDING')
                            Row(
                              children: [
                                TextButton(
                                  onPressed: () async {
                                    await session.api.post('/bookings/${b['id']}/decide', {'approve': true});
                                    _load();
                                  },
                                  child: const Text('Approve'),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
