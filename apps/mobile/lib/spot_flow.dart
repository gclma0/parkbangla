import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'i18n.dart';
import 'session.dart';
import 'theme.dart';
import 'widgets.dart';

class SpotDetailPage extends StatefulWidget {
  const SpotDetailPage({super.key, required this.spotId});
  final String spotId;
  @override
  State<SpotDetailPage> createState() => _SpotDetailPageState();
}

class _SpotDetailPageState extends State<SpotDetailPage> {
  Map<String, dynamic>? spot;
  String? err;
  int _activePage = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await session.api.get('/spots/${widget.spotId}');
      setState(() => spot = Map<String, dynamic>.from(data as Map));
    } catch (e) {
      setState(() => err = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final i = I18n(session.bn);
    if (spot == null) {
      return Scaffold(body: Center(child: err == null ? const CircularProgressIndicator(color: Pb.yellow) : Text(err!)));
    }
    final host = Map<String, dynamic>.from(spot!['host'] as Map? ?? {});
    
    final List<String> photos = spot!['photos'] != null
        ? List<String>.from(spot!['photos'])
        : ['https://images.unsplash.com/photo-1590674899484-d5640e854abe?w=1200'];
    if (photos.isEmpty) {
      photos.add('https://images.unsplash.com/photo-1590674899484-d5640e854abe?w=1200');
    }

    final reviews = List<Map<String, dynamic>>.from(
      (spot!['reviews'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)),
    );

    return Scaffold(
      backgroundColor: Pb.cream,
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Image PageView Header
                  Stack(
                    children: [
                      SizedBox(
                        height: 300,
                        width: MediaQuery.of(context).size.width,
                        child: PageView.builder(
                          itemCount: photos.length,
                          onPageChanged: (page) {
                            setState(() {
                              _activePage = page;
                            });
                          },
                          itemBuilder: (ctx, index) {
                            return Image.network(photos[index], fit: BoxFit.cover);
                          },
                        ),
                      ),
                      // Dark gradient overlay
                      const Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Color(0x55000000), Colors.transparent, Color(0x33000000)],
                            ),
                          ),
                        ),
                      ),
                      // Dot indicators overlay
                      if (photos.length > 1)
                        Positioned(
                          bottom: 16,
                          left: 0,
                          right: 0,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(
                              photos.length,
                              (index) => AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                margin: const EdgeInsets.symmetric(horizontal: 4),
                                width: _activePage == index ? 20 : 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(4),
                                  color: _activePage == index ? Pb.yellow : Colors.white70,
                                ),
                              ),
                            ),
                          ),
                        ),
                      // Close button overlay
                      Positioned(
                        left: 12,
                        top: 12,
                        child: SafeArea(
                          child: CircleAvatar(
                            backgroundColor: Colors.black45,
                            radius: 20,
                            child: IconButton(
                              iconSize: 20,
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.close, color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  // Main Details
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Spot Verified Badge, Area and Address
                        Row(
                          children: [
                            if (spot!['verified'] == true)
                              Container(
                                margin: const EdgeInsets.only(right: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Pb.yellow,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Text('Verified', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11)),
                              ),
                            Text(
                              '${spot!['area']}',
                              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${spot!['address']}',
                          style: const TextStyle(color: Pb.muted, fontSize: 14),
                        ),
                        const SizedBox(height: 10),
                        _verificationNotice(spot!),
                        const SizedBox(height: 16),
                        
                        // Pricing Grid
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Pb.ink.withOpacity(0.06)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _priceItem(i.t('Hourly', 'ঘণ্টা'), '৳${spot!['hourlyPrice']}'),
                              Container(width: 1, height: 40, color: Pb.ink.withOpacity(0.08)),
                              _priceItem(i.t('Daily', 'দিন'), '৳${spot!['dailyPrice']}'),
                              Container(width: 1, height: 40, color: Pb.ink.withOpacity(0.08)),
                              _priceItem(i.t('Monthly', 'মাসিক'), '৳${spot!['monthlyPrice']}'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Specifications Grid
                        const Text(
                          'Specifications',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(child: _specCard('📏 Size', '${spot!['widthM'] ?? 2.5}m × ${spot!['lengthM'] ?? 5.2}m')),
                            const SizedBox(width: 12),
                            Expanded(child: _specCard('🔑 Access', '${spot!['accessType']}')),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(child: _specCard('🚗 Space', spot!['covered'] == true ? i.covered : i.openAir)),
                            const SizedBox(width: 12),
                            Expanded(child: _specCard('🚙 Fits', '${spot!['vehicleSizes'] ?? 'sedan,suv'}')),
                          ],
                        ),
                        const SizedBox(height: 16),
                        
                        if (spot!['accessNotes'] != null && spot!['accessNotes'].toString().trim().isNotEmpty) ...[
                          const Text(
                            'Access Instructions',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            spot!['accessNotes'].toString(),
                            style: TextStyle(color: Pb.ink.withOpacity(0.85), height: 1.3, fontSize: 13),
                          ),
                          const SizedBox(height: 20),
                        ],

                        // Host info
                        const Divider(height: 32),
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: Pb.yellow.withOpacity(0.3),
                              child: Text(
                                (host['name'] ?? 'U').toString().substring(0, 1).toUpperCase(),
                                style: const TextStyle(fontWeight: FontWeight.w900, color: Pb.ink),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Hosted by ${host['name'] ?? ''}',
                                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      const Icon(Icons.star, color: Pb.yellowDeep, size: 14),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${(host['ratingAvg'] as num?)?.toStringAsFixed(1) ?? '—'} (${host['ratingCount'] ?? 0} reviews)',
                                        style: const TextStyle(color: Pb.muted, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        
                        // Reviews Section
                        const Divider(height: 32),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              i.t('Reviews (${reviews.length})', 'রিভিউ (${reviews.length})'),
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                            ),
                            if (reviews.isNotEmpty)
                              Row(
                                children: [
                                  const Icon(Icons.star, color: Pb.yellowDeep, size: 18),
                                  const SizedBox(width: 4),
                                  Text(
                                    (reviews.map((r) => r['rating'] as int).reduce((a, b) => a + b) / reviews.length).toStringAsFixed(1),
                                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                                  ),
                                ],
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        
                        if (reviews.isEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            alignment: Alignment.center,
                            child: Text(
                              i.t('No reviews for this spot yet.', 'এই স্পটের জন্য এখনো কোনো রিভিউ নেই।'),
                              style: const TextStyle(color: Pb.muted, fontSize: 13, fontStyle: FontStyle.italic),
                            ),
                          )
                        else
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: reviews.length,
                            itemBuilder: (ctx, index) {
                              final review = reviews[index];
                              final reviewer = Map<String, dynamic>.from(review['fromUser'] as Map? ?? {});
                              final reviewerName = reviewer['name'] ?? 'Anonymous';
                              final tags = List.from(review['tags'] as List? ?? const []);
                              final dateStr = review['createdAt'] != null
                                  ? DateTime.parse(review['createdAt'] as String).toLocal().toString().split(' ').first
                                  : '';
                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Pb.ink.withOpacity(0.06)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          reviewerName,
                                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                                        ),
                                        Row(
                                          children: [
                                            const Icon(Icons.star, color: Pb.yellowDeep, size: 14),
                                            const SizedBox(width: 4),
                                            Text(
                                              '${review['rating']}',
                                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    if (review['comment'] != null && review['comment'].toString().trim().isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Text(
                                        review['comment'].toString(),
                                        style: TextStyle(color: Pb.ink.withOpacity(0.8), fontSize: 13, height: 1.3),
                                      ),
                                    ],
                                    if (tags.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 6,
                                        children: tags
                                            .map((tag) => Chip(
                                                  visualDensity: VisualDensity.compact,
                                                  label: Text(tag.toString().replaceAll('_', ' ')),
                                                ))
                                            .toList(),
                                      ),
                                    ],
                                    const SizedBox(height: 8),
                                    Text(
                                      dateStr,
                                      style: const TextStyle(color: Pb.muted, fontSize: 11),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Checkout Actions
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => InstantCheckoutPage(spot: spot!))),
                    child: Text(i.t('Instant Book', 'ইনস্ট্যান্ট বুক')),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: YellowCta(
                    label: i.getPass,
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CheckoutPage(spot: spot!))),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _priceItem(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Pb.muted, fontSize: 11, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Pb.ink)),
      ],
    );
  }

  Widget _verificationNotice(Map<String, dynamic> spot) {
    final status = spot['verifiedStatus']?.toString() ?? 'UNVERIFIED';
    final verified = spot['verified'] == true;
    final text = verified
        ? 'Verified spot: identity, photos, proof, and entrance location reviewed.'
        : status == 'PENDING'
            ? 'Verification pending: check photos, access notes, and host rating before booking.'
            : status == 'REJECTED'
                ? 'Verification rejected: this listing needs correction before it should be trusted.'
                : 'Unverified spot: review details carefully before booking.';
    final color = verified ? const Color(0xFFE8F5E9) : const Color(0xFFFFF8E1);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Pb.ink.withOpacity(0.08)),
      ),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Pb.ink)),
    );
  }

  Widget _specCard(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Pb.ink.withOpacity(0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Pb.muted, fontSize: 11, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Pb.ink)),
        ],
      ),
    );
  }
}

class CheckoutPage extends StatefulWidget {
  const CheckoutPage({super.key, required this.spot});
  final Map<String, dynamic> spot;
  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  bool loading = false;
  String? err;

  Future<void> _buy() async {
    setState(() {
      loading = true;
      err = null;
    });
    try {
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, now.day);
      final end = start.add(const Duration(days: 30));
      final booking = Map<String, dynamic>.from(
        await session.api.post('/bookings/commuter-pass', {
          'spotId': widget.spot['id'],
          'startDate': start.toIso8601String().split('T').first,
          'endDate': end.toIso8601String().split('T').first,
          'weekdays': [1, 2, 3, 4, 5],
          'startTime': '09:00',
          'endTime': '19:00',
        }) as Map,
      );
      await session.refreshMe();
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => MatchPage(booking: booking)));
    } catch (e) {
      setState(() => err = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final i = I18n(session.bn);
    final monthly = (widget.spot['monthlyPrice'] as num?)?.toDouble() ?? 0;
    final wallet = (session.user?['walletBalance'] as num?)?.toDouble() ?? 0;
    return Scaffold(
      appBar: AppBar(title: Text(i.getPass)),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.spot['address']?.toString() ?? '', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            Text(i.t('Weekdays 09:00–19:00 · 30 days', 'সপ্তাহের দিন ০৯:০০–১৯:০০ · ৩০ দিন')),
            const SizedBox(height: 12),
            Text('৳${widget.spot['monthlyPrice']}', style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text(i.t('Paid from wallet. 15% platform fee is taken from the host, not added on top.',
                'ওয়ালেট থেকে কাটা হবে। হোস্টের পেআউট থেকে ১৫% কমিশন কাটা হয়।')),
            const SizedBox(height: 16),
            _costBreakdown([
              _CostLine('Monthly pass', monthly),
              const _CostLine('Renter platform fee', 0.0),
              _CostLine('Wallet after hold', wallet - monthly),
            ], note: 'Cancellation before check-in refunds 80% to wallet. Host commission is not added to your fare.'),
            if (err != null) Padding(padding: const EdgeInsets.only(top: 16), child: Text(err!, style: const TextStyle(color: Colors.red))),
            const Spacer(),
            YellowCta(label: loading ? '…' : i.t('Confirm pass', 'পাস নিশ্চিত করুন'), onPressed: loading ? null : _buy),
          ],
        ),
      ),
    );
  }
}

class _CostLine {
  const _CostLine(this.label, this.amount);
  final String label;
  final double amount;
}

Widget _costBreakdown(List<_CostLine> lines, {required String note}) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Pb.ink.withOpacity(0.06)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Cost breakdown', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
        const SizedBox(height: 10),
        ...lines.map(
          (line) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Expanded(child: Text(line.label, style: const TextStyle(color: Pb.muted, fontSize: 12))),
                Text('৳${line.amount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
              ],
            ),
          ),
        ),
        const Divider(height: 16),
        Text(note, style: const TextStyle(color: Pb.muted, fontSize: 12, height: 1.35)),
      ],
    ),
  );
}

class MatchPage extends StatelessWidget {
  const MatchPage({super.key, required this.booking});
  final Map<String, dynamic> booking;

  @override
  Widget build(BuildContext context) {
    final i = I18n(session.bn);
    return Scaffold(
      backgroundColor: Pb.yellow,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            children: [
              const Spacer(),
              const Icon(Icons.local_parking_rounded, size: 88)
                  .animate()
                  .scale(duration: 500.ms, curve: Curves.elasticOut),
              const SizedBox(height: 16),
              Text(i.itsAPark, style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w900), textAlign: TextAlign.center)
                  .animate()
                  .fadeIn(delay: 120.ms),
              const SizedBox(height: 12),
              Text(
                i.t('Your weekday driveway is locked in. Show the QR at the gate.', 'আপনার পাস লক হয়েছে। গেটে কিউআর দেখাবেন।'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, height: 1.4),
              ),
              const Spacer(),
              YellowCta(
                label: i.checkIn,
                onPressed: () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => CheckInPage(bookingId: booking['id'] as String)),
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
                style: OutlinedButton.styleFrom(backgroundColor: Colors.white),
                child: Text(i.t('Done', 'ঠিক আছে')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CheckInPage extends StatefulWidget {
  const CheckInPage({super.key, required this.bookingId});
  final String bookingId;
  @override
  State<CheckInPage> createState() => _CheckInPageState();
}

class _CheckInPageState extends State<CheckInPage> {
  Map<String, dynamic>? b;
  String? msg;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await session.api.get('/bookings/${widget.bookingId}');
    setState(() => b = Map<String, dynamic>.from(data as Map));
  }

  Future<void> _check(String kind) async {
    try {
      await session.api.post('/bookings/${widget.bookingId}/check', {'kind': kind, 'pin': b?['pin']});
      setState(() => msg = kind == 'in' ? 'Checked in' : 'Checked out');
      await _load();
    } catch (e) {
      setState(() => msg = e.toString());
    }
  }

  Future<void> _cancel() async {
    final i = I18n(session.bn);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(i.t('Cancel Booking', 'বুকিং বাতিল')),
        content: Text(i.t('Cancellation Policy: 80% of the fare will be refunded to your wallet. Do you want to proceed?', 'নীতিমালা: আপনার ওয়ালেটে ৮০% টাকা রিফান্ড করা হবে। বাতিল করতে চান?')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(i.t('No', 'না'))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(i.t('Yes, Cancel', 'হ্যাঁ, বাতিল'))),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      final res = await session.api.post('/bookings/${widget.bookingId}/cancel');
      final refund = res['refund'];
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Cancelled! ৳$refund refunded to wallet.')));
        _load();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _dispute() async {
    final i = I18n(session.bn);
    final notesController = TextEditingController();
    final evidenceController = TextEditingController();
    String category = 'ACCESS_PROBLEM';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(i.t('Raise Dispute / Flag Spot', 'অভিযোগ দায়ের')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: category,
                decoration: const InputDecoration(labelText: 'Category'),
                items: const [
                  DropdownMenuItem(value: 'SAFETY', child: Text('Safety')),
                  DropdownMenuItem(value: 'HARASSMENT', child: Text('Harassment')),
                  DropdownMenuItem(value: 'MISLEADING_LISTING', child: Text('Misleading listing')),
                  DropdownMenuItem(value: 'NO_SHOW', child: Text('No-show')),
                  DropdownMenuItem(value: 'ACCESS_PROBLEM', child: Text('Access problem')),
                  DropdownMenuItem(value: 'PAYMENT', child: Text('Payment')),
                ],
                onChanged: (v) => setDialogState(() => category = v ?? category),
              ),
              TextField(
                controller: notesController,
                maxLines: 3,
                decoration: InputDecoration(hintText: i.t('Write issue details...', 'অভিযোগের বিবরণ লিখুন...')),
              ),
              TextField(
                controller: evidenceController,
                decoration: const InputDecoration(labelText: 'Evidence URL'),
                keyboardType: TextInputType.url,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(i.t('Cancel', 'বাতিল'))),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(i.t('Submit', 'জমা দিন'))),
          ],
        ),
      ),
    );
    if (confirm != true || notesController.text.trim().isEmpty) return;
    try {
      await session.api.post('/bookings/${widget.bookingId}/disputes', {'notes': notesController.text.trim()});
      final spotId = b?['spotId'] ?? b?['spot']?['id'];
      if (spotId != null) {
        await session.api.post('/reports', {
          'targetType': 'SPOT',
          'targetId': spotId,
          'category': category,
          'reason': notesController.text.trim(),
          'evidenceUrls': [if (evidenceController.text.trim().isNotEmpty) evidenceController.text.trim()],
        });
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Dispute raised. Admin will review.')));
        _load();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _leaveReview() async {
    final i = I18n(session.bn);
    int selectedRating = 5;
    int spotRating = 5;
    int hostRating = 5;
    int renterRating = 5;
    final tags = <String>{};
    final commentController = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(i.t('Rate & Review', 'রেটিং ও রিভিউ')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  final starVal = index + 1;
                  return IconButton(
                    icon: Icon(
                      starVal <= selectedRating ? Icons.star_rounded : Icons.star_border_rounded,
                      color: Pb.yellowDeep,
                      size: 36,
                    ),
                    onPressed: () => setDialogState(() => selectedRating = starVal),
                  );
                }),
              ),
              _ratingPicker('Spot', spotRating, (v) => setDialogState(() => spotRating = v)),
              _ratingPicker('Host', hostRating, (v) => setDialogState(() => hostRating = v)),
              _ratingPicker('Renter', renterRating, (v) => setDialogState(() => renterRating = v)),
              Wrap(
                spacing: 8,
                children: ['easy_access', 'accurate_location', 'safe', 'clean', 'responsive_host'].map((tag) {
                  return FilterChip(
                    label: Text(tag.replaceAll('_', ' ')),
                    selected: tags.contains(tag),
                    onSelected: (selected) => setDialogState(() => selected ? tags.add(tag) : tags.remove(tag)),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: commentController,
                maxLines: 2,
                decoration: InputDecoration(hintText: i.t('Write your review...', 'মন্তব্য লিখুন...')),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(i.t('Cancel', 'বাতিল'))),
            TextButton(
              onPressed: () async {
                try {
                  final targetUser = session.isHost ? b!['renterId'] : b!['spot']['hostId'];
                  await session.api.post('/bookings/${widget.bookingId}/reviews', {
                    'toUserId': targetUser,
                    'rating': selectedRating,
                    'spotRating': spotRating,
                    'hostRating': hostRating,
                    'renterRating': renterRating,
                    'tags': tags.toList(),
                    'comment': commentController.text.trim(),
                  });
                  if (ctx.mounted) Navigator.pop(ctx);
                  _load();
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                  }
                }
              },
              child: Text(i.t('Submit', 'জমা দিন')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ratingPicker(String label, int value, ValueChanged<int> onChanged) {
    return Row(
      children: [
        SizedBox(width: 58, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700))),
        ...List.generate(5, (index) {
          final starVal = index + 1;
          return IconButton(
            visualDensity: VisualDensity.compact,
            icon: Icon(starVal <= value ? Icons.star_rounded : Icons.star_border_rounded, color: Pb.yellowDeep),
            onPressed: () => onChanged(starVal),
          );
        }),
      ],
    );
  }

  Future<void> _blockOtherUser() async {
    final spot = b?['spot'] is Map ? Map<String, dynamic>.from(b!['spot'] as Map) : null;
    final renterId = b == null ? null : b!['renterId'];
    final hostId = spot == null ? null : spot['hostId'];
    final otherId = session.isHost ? renterId : hostId;
    if (otherId == null) return;
    final reason = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Block user'),
        content: TextField(controller: reason, decoration: const InputDecoration(labelText: 'Reason'), maxLines: 2),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Block')),
        ],
      ),
    );
    if (confirm != true) return;
    await session.api.post('/blocked-users/$otherId', {'reason': reason.text.trim()});
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User blocked.')));
  }

  Future<void> _simulateGeofencing() async {
    final i = I18n(session.bn);
    final spot = b!['spot'];
    final spotLat = (spot['lat'] as num).toDouble();
    final spotLng = (spot['lng'] as num).toDouble();
    
    final renterLat = spotLat + 0.001;
    final renterLng = spotLng - 0.001;

    final double distKm = const Distance().as(LengthUnit.Kilometer, LatLng(renterLat, renterLng), LatLng(spotLat, spotLng));
    
    if (distKm <= 0.5) {
      final isCheckingOut = b!['status'] == 'ACTIVE';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          i.t('Geofence Detected Proximity! Distance: ${(distKm * 1000).toStringAsFixed(0)} meters. Auto checking ${isCheckingOut ? "out" : "in"}...',
              'জিওফেন্স প্রক্সিমিটি শনাক্ত হয়েছে! দূরত্ব: ${(distKm * 1000).toStringAsFixed(0)} মিটার। স্বয়ংক্রিয় চেক-${isCheckingOut ? "আউট" : "ইন"} হচ্ছে...'),
        ),
      ));
      await _check(isCheckingOut ? 'out' : 'in');
    }
  }

  @override
  Widget build(BuildContext context) {
    final i = I18n(session.bn);
    if (b == null) return const Scaffold(body: Center(child: CircularProgressIndicator(color: Pb.yellow)));

    final isCompleted = b!['status'] == 'COMPLETED';
    final isCancelled = b!['status'] == 'CANCELLED';
    final isActive = b!['status'] == 'ACTIVE';

    return Scaffold(
      appBar: AppBar(title: Text(isCompleted ? i.t('Checkout Complete', 'চেক-আউট সম্পন্ন') : (isCancelled ? i.t('Cancelled', 'বাতিল করা হয়েছে') : i.checkIn))),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          if (isCompleted) ...[
            Center(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
                child: Column(
                  children: [
                    const Icon(Icons.check_circle_rounded, size: 68, color: Colors.green),
                    const SizedBox(height: 12),
                    Text(i.t('Parking Session Completed', 'পার্কিং সেশন সম্পন্ন'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    const Divider(),
                    const SizedBox(height: 12),
                    Text(
                      i.t('Final Fare Charged:', 'চূড়ান্ত ভাড়া কর্তন:'),
                      style: const TextStyle(color: Pb.muted),
                    ),
                    Text(
                      '৳${b!['amount']}',
                      style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      i.t('Your wallet ledger has been updated dynamically.', 'প্রকৃত সময়ের সাথে সমন্বয় করে আপনার ওয়ালেট ব্যালেন্স হিসাব করা হয়েছে।'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 13, color: Pb.muted),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            if ((b!['reviews'] as List?)?.isEmpty ?? true) ...[
              YellowCta(
                label: i.t('Leave a Review', 'রিভিউ দিন'),
                onPressed: _leaveReview,
              ),
              const SizedBox(height: 12),
            ],
            OutlinedButton(
              onPressed: _dispute,
              child: Text(i.t('Raise Dispute', 'অভিযোগ দায়ের')),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _blockOtherUser,
              icon: const Icon(Icons.block),
              label: const Text('Block user'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
              style: OutlinedButton.styleFrom(backgroundColor: Colors.white),
              child: Text(i.t('Back to Home', 'হোম পেজে ফিরে যান')),
            ),
          ] else if (isCancelled) ...[
            Center(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
                child: Column(
                  children: [
                    const Icon(Icons.cancel_rounded, size: 68, color: Colors.red),
                    const SizedBox(height: 12),
                    Text(i.t('Booking Cancelled', 'বুকিং বাতিল করা হয়েছে'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(i.t('Refund has been processed per our cancellation policy.', 'নীতিমালা অনুযায়ী রিফান্ড প্রসেস করা হয়েছে।'), textAlign: TextAlign.center, style: const TextStyle(color: Pb.muted)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            YellowCta(
              label: i.t('Back to Home', 'হোম পেজে ফিরে যান'),
              onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
            ),
          ] else ...[
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
                child: QrImageView(data: b!['qrToken']?.toString() ?? widget.bookingId, size: 220),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text('PIN  ${b!['pin']}', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: 4)),
            ),
            const SizedBox(height: 8),
            Text(i.t('Show this to the guard or host. They can also enter the PIN.', 'গার্ড বা হোস্টকে দেখান।'), textAlign: TextAlign.center),
            if (msg != null) Padding(padding: const EdgeInsets.all(12), child: Text(msg!, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700))),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: Text(i.t('Chat', 'চ্যাট')),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatPage(bookingId: widget.bookingId))),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.navigation_outlined),
                    label: Text(i.t('Navigate', 'ন্যাভিগেট')),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => NavigationPage(booking: b!))),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.gps_fixed_rounded),
              label: Text(i.t('Simulate Proximity / Geofencing', 'জিওফেন্স প্রক্সিমিটি সিমুলেশন')),
              onPressed: _simulateGeofencing,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _dispute,
                    child: Text(i.t('Raise Dispute', 'অভিযোগ দায়ের')),
                  ),
                ),
                if (b!['status'] == 'PENDING' || b!['status'] == 'CONFIRMED') ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _cancel,
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                      child: Text(i.t('Cancel Booking', 'বুকিং বাতিল')),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _blockOtherUser,
              icon: const Icon(Icons.block),
              label: const Text('Block user'),
            ),
            const SizedBox(height: 24),
            if (!isActive)
              YellowCta(label: i.t('I arrived — check in', 'চেক-ইন'), onPressed: () => _check('in')),
            if (isActive)
              YellowCta(label: i.t('I am leaving — check out', 'চেক-আউট'), onPressed: () => _check('out')),
          ],
        ],
      ),
    );
  }
}

class SosPage extends StatefulWidget {
  const SosPage({super.key});

  @override
  State<SosPage> createState() => _SosPageState();
}

class _SosPageState extends State<SosPage> {
  Map<String, dynamic>? safety;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await session.api.get('/safety-center');
      if (mounted) setState(() => safety = Map<String, dynamic>.from(res as Map));
    } catch (_) {}
  }

  Future<void> _support() async {
    final subject = TextEditingController(text: 'Safety support request');
    final message = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Contact support'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: subject, decoration: const InputDecoration(labelText: 'Subject')),
            TextField(controller: message, decoration: const InputDecoration(labelText: 'What happened?'), maxLines: 3),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Send')),
        ],
      ),
    );
    if (ok != true || message.text.trim().isEmpty) return;
    await session.api.post('/support-tickets', {
      'subject': subject.text.trim(),
      'message': message.text.trim(),
      'priority': 'HIGH',
    });
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Support ticket created.')));
  }

  Future<void> _call(String number) async {
    final uri = Uri(scheme: 'tel', path: number);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not open dialer for $number')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final i = I18n(session.bn);
    final contacts = List<Map<String, dynamic>>.from(
      (safety?['emergencyContacts'] as List? ?? const []).map((e) => Map<String, dynamic>.from(e as Map)),
    );
    return Scaffold(
      backgroundColor: const Color(0xFFB71C1C),
      appBar: AppBar(backgroundColor: Colors.transparent, foregroundColor: Colors.white, title: Text(i.sos)),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text(i.t('Emergency', 'জরুরি'), style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            if (contacts.isEmpty)
              Column(
                children: [
                  const Text('Bangladesh emergency service 999\nParkBangla safety: flag the booking in-app.',
                      style: TextStyle(color: Colors.white, height: 1.5, fontSize: 16), textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => _call('999'),
                    icon: const Icon(Icons.call),
                    label: const Text('Call 999'),
                    style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: const Color(0xFFB71C1C)),
                  ),
                ],
              )
            else
              ...contacts.map(
                (contact) => ListTile(
                  textColor: Colors.white,
                  iconColor: Colors.white,
                  leading: const Icon(Icons.local_phone),
                  title: Text('${contact['label']}'),
                  subtitle: Text('${contact['value']}', style: const TextStyle(color: Colors.white70)),
                  trailing: FilledButton.icon(
                    onPressed: () => _call('${contact['value']}'),
                    icon: const Icon(Icons.call, size: 16),
                    label: const Text('Call'),
                    style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: const Color(0xFFB71C1C)),
                  ),
                ),
              ),
            const Spacer(),
            OutlinedButton.icon(
              onPressed: _support,
              icon: const Icon(Icons.support_agent),
              label: const Text('Contact ParkBangla support'),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white)),
            ),
            const SizedBox(height: 12),
            YellowCta(label: i.t('Close', 'বন্ধ'), onPressed: () => Navigator.pop(context)),
          ],
        ),
      ),
    );
  }
}

class InstantCheckoutPage extends StatefulWidget {
  const InstantCheckoutPage({super.key, required this.spot});
  final Map<String, dynamic> spot;

  @override
  State<InstantCheckoutPage> createState() => _InstantCheckoutPageState();
}

class _InstantCheckoutPageState extends State<InstantCheckoutPage> {
  bool isHourly = true;
  double hours = 2;
  double days = 1;
  bool loading = false;
  String? err;

  Future<void> _book() async {
    setState(() {
      loading = true;
      err = null;
    });
    try {
      final now = DateTime.now();
      String startTime = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
      
      DateTime endDateTime;
      if (isHourly) {
        endDateTime = now.add(Duration(hours: hours.toInt()));
      } else {
        endDateTime = now.add(Duration(days: days.toInt()));
      }
      
      String endTime = "${endDateTime.hour.toString().padLeft(2, '0')}:${endDateTime.minute.toString().padLeft(2, '0')}";

      final booking = Map<String, dynamic>.from(
        await session.api.post('/bookings/instant', {
          'spotId': widget.spot['id'],
          'startDate': now.toIso8601String().split('T').first,
          'endDate': endDateTime.toIso8601String().split('T').first,
          'startTime': startTime,
          'endTime': endTime,
          'isHourly': isHourly,
          'hoursEstimated': isHourly ? hours.toInt() : 0,
          'daysEstimated': isHourly ? 0 : days.toInt(),
        }) as Map,
      );
      await session.refreshMe();
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => MatchPage(booking: booking)));
    } catch (e) {
      setState(() => err = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final i = I18n(session.bn);
    final rate = isHourly ? widget.spot['hourlyPrice'] : widget.spot['dailyPrice'];
    final count = isHourly ? hours.toInt() : days.toInt();
    final total = rate * count;
    final totalAmount = (total as num).toDouble();
    final wallet = (session.user?['walletBalance'] as num?)?.toDouble() ?? 0;

    return Scaffold(
      appBar: AppBar(title: Text(i.t('Instant Booking', 'ইনস্ট্যান্ট বুকিং'))),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.spot['address']?.toString() ?? '', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: Center(child: Text(i.t('Hourly', 'ঘণ্টা'))),
                    selected: isHourly,
                    selectedColor: Pb.yellow,
                    backgroundColor: Colors.white,
                    labelStyle: const TextStyle(color: Pb.ink, fontWeight: FontWeight.w800),
                    side: BorderSide(color: isHourly ? Pb.yellowDeep : Pb.ink.withOpacity(0.12)),
                    onSelected: (_) => setState(() => isHourly = true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ChoiceChip(
                    label: Center(child: Text(i.t('Daily', 'দিন'))),
                    selected: !isHourly,
                    selectedColor: Pb.yellow,
                    backgroundColor: Colors.white,
                    labelStyle: const TextStyle(color: Pb.ink, fontWeight: FontWeight.w800),
                    side: BorderSide(color: !isHourly ? Pb.yellowDeep : Pb.ink.withOpacity(0.12)),
                    onSelected: (_) => setState(() => isHourly = false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (isHourly) ...[
              Text(
                i.t('Estimated Hours: ${hours.toInt()}', 'আনুমানিক ঘণ্টা: ${hours.toInt()}'),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              Slider(
                value: hours,
                min: 1,
                max: 12,
                divisions: 11,
                activeColor: Pb.yellowDeep,
                onChanged: (v) => setState(() => hours = v),
              ),
            ] else ...[
              Text(
                i.t('Estimated Days: ${days.toInt()}', 'আনুমানিক দিন: ${days.toInt()}'),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              Slider(
                value: days,
                min: 1,
                max: 7,
                divisions: 6,
                activeColor: Pb.yellowDeep,
                onChanged: (v) => setState(() => days = v),
              ),
            ],
            const SizedBox(height: 24),
            Text(
              '৳$total',
              style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w900),
            ),
            Text(
              isHourly ? '৳${widget.spot['hourlyPrice']}/hr' : '৳${widget.spot['dailyPrice']}/day',
              style: const TextStyle(color: Pb.muted, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            _costBreakdown([
              _CostLine(isHourly ? 'Hourly parking' : 'Daily parking', totalAmount),
              const _CostLine('Renter platform fee', 0.0),
              _CostLine('Wallet after hold', wallet - totalAmount),
            ], note: 'This amount is held from wallet. Final hourly/daily cost is adjusted at checkout when you leave.'),
            const SizedBox(height: 12),
            Text(i.t(
              'Your wallet balance will be held. The final cost is calculated dynamically when you check out.',
              'আপনার ওয়ালেট থেকে সাময়িক কাটা হবে। চেক-আউটের সময় প্রকৃত সময় অনুযায়ী ভাড়া পুনঃনির্ধারণ হবে।',
            )),
            if (err != null) Padding(padding: const EdgeInsets.only(top: 16), child: Text(err!, style: const TextStyle(color: Colors.red))),
            const Spacer(),
            YellowCta(
              label: loading ? '…' : i.t('Confirm & Book', 'নিশ্চিত ও বুক করুন'),
              onPressed: loading ? null : _book,
            ),
          ],
        ),
      ),
    );
  }
}

class ChatPage extends StatefulWidget {
  const ChatPage({super.key, required this.bookingId});
  final String bookingId;
  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  List messages = [];
  final content = TextEditingController();
  final attachment = TextEditingController();
  Timer? _timer;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _loadSilent());
  }

  @override
  void dispose() {
    _timer?.cancel();
    content.dispose();
    attachment.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final res = await session.api.get('/bookings/${widget.bookingId}/messages');
      setState(() => messages = res as List);
      session.fetchUnreadCount();
    } catch (_) {}
    if (mounted) setState(() => loading = false);
  }

  Future<void> _loadSilent() async {
    try {
      final res = await session.api.get('/bookings/${widget.bookingId}/messages');
      if (mounted) setState(() => messages = res as List);
      session.fetchUnreadCount();
    } catch (_) {}
  }

  Future<void> _send() async {
    if (content.text.trim().isEmpty) return;
    final text = content.text.trim();
    final attachmentUrl = attachment.text.trim();
    content.clear();
    attachment.clear();
    try {
      await session.api.post('/bookings/${widget.bookingId}/messages', {
        'content': text,
        if (attachmentUrl.isNotEmpty) 'attachmentUrl': attachmentUrl,
        if (attachmentUrl.isNotEmpty) 'attachmentType': 'url',
      });
      _loadSilent();
      session.fetchUnreadCount();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final i = I18n(session.bn);
    return Scaffold(
      appBar: AppBar(title: Text(i.t('In-App Chat', 'ইন-অ্যাপ চ্যাট'))),
      body: Column(
        children: [
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator(color: Pb.yellow))
                : messages.isEmpty
                    ? Center(child: Text(i.t('No messages yet. Send a message to start.', 'কোনো বার্তা নেই।')))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: messages.length,
                        itemBuilder: (ctx, idx) {
                          final msg = Map<String, dynamic>.from(messages[idx] as Map);
                          final mine = msg['senderId'] == session.id;
                          final attachmentUrl = msg['attachmentUrl']?.toString();
                          return Align(
                            alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: mine ? Pb.yellow : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4)],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${msg['content']}',
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                  if (attachmentUrl != null && attachmentUrl.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    InkWell(
                                      onTap: () => launchUrl(Uri.parse(attachmentUrl)),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.attach_file, size: 16),
                                          const SizedBox(width: 4),
                                          Flexible(
                                            child: Text(
                                              attachmentUrl,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(decoration: TextDecoration.underline, fontWeight: FontWeight.w700),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
                  child: TextField(
                    controller: content,
                    onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: i.t('Type a message...', 'বার্তা লিখুন...'),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _attach,
                  icon: const Icon(Icons.attach_file),
                  tooltip: i.t('Attach link', 'লিংক যুক্ত করুন'),
                ),
                IconButton(
                  onPressed: _send,
                  icon: const Icon(Icons.send_rounded, color: Pb.yellowDeep),
                  style: IconButton.styleFrom(backgroundColor: Pb.ink, foregroundColor: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _attach() async {
    final draft = TextEditingController(text: attachment.text);
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Attachment link'),
        content: TextField(
          controller: draft,
          decoration: const InputDecoration(labelText: 'Photo or evidence URL'),
          keyboardType: TextInputType.url,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
        ],
      ),
    );
    if (saved == true) attachment.text = draft.text.trim();
  }
}

class NavigationPage extends StatefulWidget {
  const NavigationPage({super.key, required this.booking});
  final Map<String, dynamic> booking;

  @override
  State<NavigationPage> createState() => _NavigationPageState();
}

class _NavigationPageState extends State<NavigationPage> {
  Timer? _timer;
  int _step = 0;
  
  late final double _destLat;
  late final double _destLng;

  final List<LatLng> _routePoints = [];

  @override
  void initState() {
    super.initState();
    final spot = widget.booking['spot'];
    _destLat = (spot['lat'] as num).toDouble();
    _destLng = (spot['lng'] as num).toDouble();

    final startLat = _destLat - 0.005;
    final startLng = _destLng - 0.005;

    for (int idx = 0; idx <= 10; idx++) {
      double pct = idx / 10.0;
      _routePoints.add(LatLng(
        startLat + (_destLat - startLat) * pct,
        startLng + (_destLng - startLng) * pct,
      ));
    }

    _timer = Timer.periodic(const Duration(milliseconds: 1800), (timer) {
      if (_step < _routePoints.length - 1) {
        setState(() => _step++);
      } else {
        _timer?.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _getPrompt(int step, I18n i) {
    switch (step) {
      case 0:
      case 1:
        return i.t('Head north-east toward your destination.', 'আপনার গন্তব্যের দিকে এগিয়ে যান।');
      case 2:
      case 3:
        return i.t('In 300 meters, prepare to turn left.', '৩০০ মিটার পরে বামে মোড় নেওয়ার প্রস্তুতি নিন।');
      case 4:
      case 5:
        return i.t('Turn left onto Road 11.', 'রোড ১১ এর ওপর বামে মোড় নিন।');
      case 6:
      case 7:
        return i.t('In 100 meters, prepare to turn right.', '১০০ মিটার পরে ডানে মোড় নেওয়ার প্রস্তুতি নিন।');
      case 8:
      case 9:
        return i.t('Turn right into parking spot driveway.', 'ডানে প্রবেশদ্বারে ডুকে পার্ক করুন।');
      default:
        return i.t('Arrived at your destination! Tell the guard or enter PIN.', 'গন্তব্যে পৌঁছে গেছেন! গার্ডকে কিউআর বা পিন দেখান।');
    }
  }

  @override
  Widget build(BuildContext context) {
    final i = I18n(session.bn);
    final currentPos = _routePoints[_step];
    
    return Scaffold(
      appBar: AppBar(title: Text(i.t('Route Navigation', 'ন্যাভিগেশন'))),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: Pb.ink,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                const Icon(Icons.navigation_rounded, color: Pb.yellow, size: 36),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    _getPrompt(_step, i),
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: FlutterMap(
              options: MapOptions(
                initialCenter: LatLng((_destLat - 0.0025), (_destLng - 0.0025)),
                initialZoom: 15,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.parkbangla.mobile',
                ),
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _routePoints,
                      color: Colors.blue,
                      strokeWidth: 5,
                    ),
                  ],
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: LatLng(_destLat, _destLng),
                      width: 50,
                      height: 50,
                      child: const Icon(Icons.location_on, color: Colors.green, size: 44),
                    ),
                    Marker(
                      point: currentPos,
                      width: 44,
                      height: 44,
                      child: Transform.rotate(
                        angle: 0.785, // rotate icon arrow
                        child: const Icon(Icons.navigation, color: Colors.blueAccent, size: 36),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
