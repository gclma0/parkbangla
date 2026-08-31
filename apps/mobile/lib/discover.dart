import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'i18n.dart';
import 'session.dart';
import 'spot_flow.dart';
import 'theme.dart';
import 'widgets.dart';

class DiscoverPage extends StatefulWidget {
  const DiscoverPage({super.key});
  @override
  State<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends State<DiscoverPage> {
  bool mapMode = false;
  bool loading = true;
  String? err;
  List<Map<String, dynamic>> spots = [];
  double maxKm = 12;
  bool? covered;
  double maxMonthly = 15000;
  final searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      err = null;
    });
    try {
      final q = <String, String>{
        'lat': '23.7806',
        'lng': '90.4193',
        'maxKm': maxKm.toStringAsFixed(0),
      };
      if (covered == true) q['covered'] = 'true';
      if (covered == false) q['covered'] = 'false';
      if (maxMonthly < 15000) q['maxMonthly'] = maxMonthly.toStringAsFixed(0);
      if (searchController.text.trim().isNotEmpty) {
        q['q'] = searchController.text.trim();
      }
      final data = await session.api.get('/spots', q);
      spots = (data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (e) {
      err = e.toString();
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _open(Map<String, dynamic> spot) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => SpotDetailPage(spotId: spot['id'] as String)));
  }

  void _showFilters() {
    final i = I18n(session.bn);
    showModalBottomSheet(
      context: context,
      backgroundColor: Pb.cream,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    i.t('Filter Parking Spots', 'ফিল্টার করুন'),
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 20),
                  Text(i.t('Covered / Open-air', 'ছাউনি / খোলা'), style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: Center(child: Text(i.t('All', 'সব'))),
                          selected: covered == null,
                          onSelected: (_) => setSheetState(() => setState(() => covered = null)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ChoiceChip(
                          label: Center(child: Text(i.covered)),
                          selected: covered == true,
                          onSelected: (_) => setSheetState(() => setState(() => covered = true)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ChoiceChip(
                          label: Center(child: Text(i.openAir)),
                          selected: covered == false,
                          onSelected: (_) => setSheetState(() => setState(() => covered = false)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    i.t('Distance Radius: ${maxKm.toStringAsFixed(0)} km', 'দূরত্ব: ${maxKm.toStringAsFixed(0)} কিমি'),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Slider(
                    value: maxKm,
                    min: 1,
                    max: 30,
                    divisions: 29,
                    activeColor: Pb.yellowDeep,
                    onChanged: (v) => setSheetState(() => setState(() => maxKm = v)),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    i.t(
                      'Max Monthly Price: ৳${maxMonthly >= 15000 ? 'Any' : maxMonthly.toStringAsFixed(0)}',
                      'সর্বোচ্চ মাসিক ভাড়া: ৳${maxMonthly >= 15000 ? 'সব' : maxMonthly.toStringAsFixed(0)}',
                    ),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Slider(
                    value: maxMonthly,
                    min: 2000,
                    max: 15000,
                    divisions: 13,
                    activeColor: Pb.yellowDeep,
                    onChanged: (v) => setSheetState(() => setState(() => maxMonthly = v)),
                  ),
                  const SizedBox(height: 24),
                  YellowCta(
                    label: i.t('Apply Filters', 'ফিল্টার প্রয়োগ'),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _load();
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final i = I18n(session.bn);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              Text(i.discover, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
              const Spacer(),
              TextButton.icon(
                onPressed: () => setState(() => mapMode = !mapMode),
                style: TextButton.styleFrom(
                  backgroundColor: Pb.yellow,
                  foregroundColor: Pb.ink,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                icon: Icon(mapMode ? Icons.view_carousel : Icons.map, size: 18),
                label: Text(
                  mapMode ? i.cards : i.map,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: searchController,
                    onSubmitted: (_) => _load(),
                    decoration: InputDecoration(
                      hintText: i.t('Search Gulshan, Banani...', 'গুলশান, বনানী খুঁজুন...'),
                      hintStyle: const TextStyle(color: Pb.muted, fontSize: 14),
                      prefixIcon: const Icon(Icons.search, color: Pb.muted),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _showFilters,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.tune, color: Pb.ink),
                ),
              ),
            ],
          ),
        ),
        if (err != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('$err\nStart the API on :3001', textAlign: TextAlign.center),
          ),
        if (loading) const Expanded(child: Center(child: CircularProgressIndicator(color: Pb.yellow))),
        if (!loading && err == null)
          Expanded(
            child: mapMode ? _map() : Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: SpotDeck(
                spots: spots,
                onTap: _open,
              ),
            ),
          ),
      ],
    );
  }

  Widget _map() {
    return FlutterMap(
      options: const MapOptions(
        initialCenter: LatLng(23.7806, 90.4143),
        initialZoom: 13,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.parkbangla.mobile',
        ),
        MarkerLayer(
          markers: spots.map((s) {
            final lat = (s['lat'] as num).toDouble();
            final lng = (s['lng'] as num).toDouble();
            return Marker(
              point: LatLng(lat, lng),
              width: 44,
              height: 44,
              child: GestureDetector(
                onTap: () => _open(s),
                child: const Icon(Icons.location_on, color: Pb.yellowDeep, size: 40),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
