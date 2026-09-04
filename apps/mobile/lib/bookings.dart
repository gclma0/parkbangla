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

    final width = MediaQuery.of(context).size.width;
    final isDesktop = width > 768;

    if (items.isEmpty) {
      return Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.directions_car_outlined, size: 64, color: Pb.ink.withOpacity(0.2)),
              const SizedBox(height: 16),
              Text(
                i.t('No passes yet.', 'এখনো কোনো পাস নেই।'),
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Pb.ink),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                i.t('Swipe a driveway on the cards to book parking spots.', 'পার্কিং বুক করতে ড্রাইভওয়ে কার্ডগুলো সোয়াইপ করুন।'),
                style: const TextStyle(color: Pb.muted, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 800),
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          itemCount: items.length + 1,
          itemBuilder: (ctx, n) {
            if (n == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Text(
                  i.bookings,
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Pb.ink),
                ),
              );
            }
            final b = items[n - 1];
            final spot = Map<String, dynamic>.from(b['spot'] as Map? ?? {});
            final photos = spot['photos'];
            final img = photos is List && photos.isNotEmpty ? photos.first.toString() : null;
            final status = b['status']?.toString().toUpperCase() ?? '';

            Color statusColor;
            Color statusBg;
            switch (status) {
              case 'CONFIRMED':
                statusColor = Colors.green[800]!;
                statusBg = const Color(0xFFE8F5E9);
                break;
              case 'PENDING':
                statusColor = const Color(0xFFB78103);
                statusBg = const Color(0xFFFFF9C4);
                break;
              case 'ACTIVE':
                statusColor = Colors.blue[800]!;
                statusBg = const Color(0xFFE3F2FD);
                break;
              case 'COMPLETED':
                statusColor = Pb.muted;
                statusBg = const Color(0xFFECEFF1);
                break;
              default:
                statusColor = Colors.red[800]!;
                statusBg = const Color(0xFFFFEBEE);
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: ScaleTap(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => CheckInPage(bookingId: b['id'] as String)),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Pb.ink.withOpacity(0.06)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          width: isDesktop ? 160 : 110,
                          child: img == null
                              ? Container(
                                  color: Pb.yellow.withOpacity(0.2),
                                  child: const Icon(Icons.local_parking, size: 40, color: Pb.yellowDeep),
                                )
                              : Image.network(img, fit: BoxFit.cover),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        spot['area'] ?? '',
                                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Pb.ink),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: statusBg,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        status,
                                        style: TextStyle(
                                          color: statusColor,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Icon(Icons.location_on_outlined, size: 14, color: Pb.ink.withOpacity(0.4)),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        spot['address'] ?? '',
                                        style: const TextStyle(color: Pb.muted, fontSize: 12),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const Spacer(),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      '৳${b['amount']}',
                                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Pb.yellowDeep),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Pb.cream,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Pb.ink.withOpacity(0.04)),
                                      ),
                                      child: Text(
                                        'PIN ${b['pin']}',
                                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Pb.ink),
                                      ),
                                    ),
                                  ],
                                ),
                                if (session.isHost && b['status'] == 'PENDING') ...[
                                  const SizedBox(height: 12),
                                  FilledButton.icon(
                                    onPressed: () async {
                                      try {
                                        await session.api.post('/bookings/${b['id']}/decide', {'approve': true});
                                        _load();
                                      } catch (e) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                                        }
                                      }
                                    },
                                    icon: const Icon(Icons.check, size: 16),
                                    label: const Text('Approve Pass'),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: Pb.yellow,
                                      foregroundColor: Pb.ink,
                                      minimumSize: const Size.fromHeight(36),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      padding: const EdgeInsets.symmetric(vertical: 0),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
