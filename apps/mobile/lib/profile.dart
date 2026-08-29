import 'package:flutter/material.dart';
import 'i18n.dart';
import 'session.dart';
import 'spot_flow.dart';
import 'theme.dart';
import 'widgets.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final plate = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final i = I18n(session.bn);
    final vehicles = (session.user?['vehicles'] as List?) ?? [];
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(i.profile, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
        const SizedBox(height: 16),
        CircleAvatar(
          radius: 44,
          backgroundColor: Pb.yellow,
          child: Text(session.name.characters.first, style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: Pb.ink)),
        ),
        const SizedBox(height: 12),
        Text(session.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
        Text(session.user?['phone']?.toString() ?? '', style: const TextStyle(color: Pb.muted)),
        if (session.user?['idVerified'] == true)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Chip(label: Text('ID verified'), backgroundColor: Pb.yellow),
          ),
        const SizedBox(height: 20),
        SwitchListTile(
          title: Text(i.t('Bangla', 'বাংলা')),
          value: session.bn,
          activeColor: Pb.ink,
          activeTrackColor: Pb.yellow,
          onChanged: (v) => session.setBn(v),
        ),
        ListTile(
          title: Text(i.sos),
          leading: const Icon(Icons.emergency, color: Colors.red),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SosPage())),
        ),
        const Divider(),
        Text(i.t('Vehicles', 'গাড়ি'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        ...vehicles.map((v) {
          final m = Map<String, dynamic>.from(v as Map);
          return ListTile(title: Text('${m['plate']}'), subtitle: Text('${m['type']} · ${m['sizeClass']}'));
        }),
        TextField(controller: plate, decoration: const InputDecoration(hintText: 'DHAKA-GA-00-0000')),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () async {
            if (plate.text.trim().isEmpty) return;
            await session.api.post('/me/vehicles', {
              'plate': plate.text.trim(),
              'type': 'car',
              'sizeClass': 'sedan',
            });
            plate.clear();
            await session.refreshMe();
            setState(() {});
          },
          child: Text(i.t('Add vehicle', 'গাড়ি যোগ')),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: () async {
            await session.api.patch('/me', {'nidDocUrl': '/uploads/nid-demo.jpg'});
            await session.refreshMe();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('NID marked uploaded (demo)')));
            }
          },
          child: Text(i.t('Upload NID / DL (demo)', 'এনআইডি আপলোড (ডেমো)')),
        ),
        const SizedBox(height: 24),
        TextButton(onPressed: session.logout, child: Text(i.t('Log out', 'লগ আউট'), style: const TextStyle(color: Colors.red))),
      ],
    );
  }
}

class HostHome extends StatefulWidget {
  const HostHome({super.key});
  @override
  State<HostHome> createState() => _HostHomeState();
}

class _HostHomeState extends State<HostHome> {
  List spots = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await session.api.get('/me/spots');
    setState(() => spots = data as List);
  }

  void _add() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ListSpotPage()),
    ).then((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    final i = I18n(session.bn);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(i.t('Your spots', 'আপনার স্পট'), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
        const SizedBox(height: 12),
        YellowCta(label: i.t('List a new spot', 'নতুন স্পট যোগ'), onPressed: _add),
        const SizedBox(height: 16),
        ...spots.map((raw) {
          final s = Map<String, dynamic>.from(raw as Map);
          return Card(
            child: ListTile(
              title: Text('${s['area']} · ৳${s['monthlyPrice']}'),
              subtitle: Text('${s['address']}\n${s['verifiedStatus']} · autoApprove ${s['autoApprove']}'),
              isThreeLine: true,
              trailing: IconButton(
                icon: const Icon(Icons.block),
                onPressed: () async {
                  final now = DateTime.now();
                  await session.api.post('/spots/${s['id']}/blocks', {
                    'startAt': now.toIso8601String(),
                    'endAt': now.add(const Duration(days: 1)).toIso8601String(),
                    'reason': 'Coming home early',
                  });
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Blocked 24h')));
                  }
                },
              ),
            ),
          );
        }),
      ],
    );
  }
}

class ListSpotPage extends StatefulWidget {
  const ListSpotPage({super.key});
  @override
  State<ListSpotPage> createState() => _ListSpotPageState();
}

class _ListSpotPageState extends State<ListSpotPage> {
  final address = TextEditingController(text: 'House 24, Road 12, Banani');
  final area = TextEditingController(text: 'Banani');
  final lat = TextEditingController(text: '23.7940');
  final lng = TextEditingController(text: '90.4048');
  final photo = TextEditingController(text: 'https://images.unsplash.com/photo-1506521781263-d8422e82f27a?w=1200');
  final accessNotes = TextEditingController(text: 'Tell the guard "ParkBangla - Sadia". Gate code: 1234');
  
  final hourly = TextEditingController();
  final daily = TextEditingController();
  final monthly = TextEditingController();

  final widthM = TextEditingController(text: '2.5');
  final lengthM = TextEditingController(text: '5.2');
  final vehicleSizes = TextEditingController(text: 'sedan,suv');

  bool covered = true;
  bool autoApprove = true;
  String accessType = 'GUARD';
  Map<String, dynamic>? suggestions;
  bool loading = false;

  @override
  void initState() {
    super.initState();
    _fetchSuggestions(area.text);
    area.addListener(() {
      _fetchSuggestions(area.text);
    });
  }

  @override
  void dispose() {
    address.dispose();
    area.dispose();
    lat.dispose();
    lng.dispose();
    photo.dispose();
    accessNotes.dispose();
    hourly.dispose();
    daily.dispose();
    monthly.dispose();
    widthM.dispose();
    lengthM.dispose();
    vehicleSizes.dispose();
    super.dispose();
  }

  Future<void> _fetchSuggestions(String val) async {
    if (val.trim().isEmpty) return;
    try {
      final res = await session.api.get('/spots/suggest-price', {'area': val.trim()});
      if (mounted) {
        setState(() {
          suggestions = Map<String, dynamic>.from(res as Map);
          if (hourly.text.isEmpty && suggestions != null) {
            hourly.text = suggestions!['hourly']?.toString() ?? '';
          }
          if (daily.text.isEmpty && suggestions != null) {
            daily.text = suggestions!['daily']?.toString() ?? '';
          }
          if (monthly.text.isEmpty && suggestions != null) {
            monthly.text = suggestions!['monthly']?.toString() ?? '';
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _submit() async {
    if (address.text.trim().isEmpty || area.text.trim().isEmpty) return;
    setState(() => loading = true);
    try {
      final spot = Map<String, dynamic>.from(
        await session.api.post('/spots', {
          'lat': double.tryParse(lat.text) ?? 23.7808,
          'lng': double.tryParse(lng.text) ?? 90.4143,
          'address': address.text.trim(),
          'area': area.text.trim(),
          'covered': covered,
          'widthM': double.tryParse(widthM.text) ?? 2.5,
          'lengthM': double.tryParse(lengthM.text) ?? 5.2,
          'vehicleSizes': vehicleSizes.text.trim().isEmpty ? 'sedan,suv' : vehicleSizes.text.trim(),
          'hourlyPrice': double.tryParse(hourly.text) ?? 80.0,
          'dailyPrice': double.tryParse(daily.text) ?? 500.0,
          'monthlyPrice': double.tryParse(monthly.text) ?? 9000.0,
          'accessType': accessType,
          'accessNotes': accessNotes.text.trim(),
          'photos': [photo.text.trim()],
          'autoApprove': autoApprove,
        }) as Map,
      );
      await session.api.post('/spots/${spot['id']}/availability', {
        'weekdays': [1, 2, 3, 4, 5],
        'startTime': '09:00',
        'endTime': '19:00',
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Spot listed successfully!')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final i = I18n(session.bn);
    return Scaffold(
      appBar: AppBar(title: Text(i.t('List a new spot', 'নতুন স্পট যোগ করুন'))),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          TextField(controller: address, decoration: InputDecoration(labelText: i.t('Address', 'ঠিকানা'))),
          const SizedBox(height: 12),
          TextField(controller: area, decoration: InputDecoration(labelText: i.t('Area (e.g. Gulshan)', 'এলাকা (যেমন গুলশান)'))),
          if (suggestions != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Suggested prices for ${area.text}: ৳${suggestions!['hourly']}/hr · ৳${suggestions!['daily']}/day · ৳${suggestions!['monthly']}/mo',
                style: const TextStyle(color: Pb.muted, fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: TextField(controller: lat, decoration: const InputDecoration(labelText: 'Latitude'))),
              const SizedBox(width: 12),
              Expanded(child: TextField(controller: lng, decoration: const InputDecoration(labelText: 'Longitude'))),
            ],
          ),
          const SizedBox(height: 12),
          TextField(controller: photo, decoration: InputDecoration(labelText: i.t('Photo URL', 'ছবির ইউআরএল'))),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: accessType,
            decoration: InputDecoration(labelText: i.t('Access Type', 'প্রবেশদ্বার ধরন')),
            items: ['GUARD', 'GATE_CODE', 'REMOTE'].map((t) {
              return DropdownMenuItem(value: t, child: Text(t));
            }).toList(),
            onChanged: (val) {
              if (val != null) setState(() => accessType = val);
            },
          ),
          const SizedBox(height: 12),
          TextField(controller: accessNotes, decoration: InputDecoration(labelText: i.t('Access Notes', 'প্রবেশদ্বার নোট'))),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: TextField(controller: widthM, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: i.t('Width (meters)', 'প্রস্থ (মিটার)')))),
              const SizedBox(width: 12),
              Expanded(child: TextField(controller: lengthM, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: i.t('Length (meters)', 'দৈর্ঘ্য (মিটার)')))),
            ],
          ),
          const SizedBox(height: 12),
          TextField(controller: vehicleSizes, decoration: InputDecoration(labelText: i.t('Supported Vehicle Sizes (comma separated)', 'সমর্থিত গাড়ির সাইজ (কমা দ্বারা আলাদা করুন)'))),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: TextField(controller: hourly, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: i.t('Hourly Price (৳)', 'ঘণ্টাপ্রতি ভাড়া (৳)')))),
              const SizedBox(width: 12),
              Expanded(child: TextField(controller: daily, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: i.t('Daily Price (৳)', 'দৈনিক ভাড়া (৳)')))),
              const SizedBox(width: 12),
              Expanded(child: TextField(controller: monthly, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: i.t('Monthly Price (৳)', 'মাসিক ভাড়া (৳)')))),
            ],
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            title: Text(i.covered),
            value: covered,
            activeColor: Pb.ink,
            activeTrackColor: Pb.yellow,
            onChanged: (v) => setState(() => covered = v),
          ),
          SwitchListTile(
            title: Text(i.t('Auto-approve Bookings', 'স্বয়ংক্রিয় বুকিং অনুমোদন')),
            value: autoApprove,
            activeColor: Pb.ink,
            activeTrackColor: Pb.yellow,
            onChanged: (v) => setState(() => autoApprove = v),
          ),
          const SizedBox(height: 24),
          YellowCta(
            label: loading ? '…' : i.t('Submit Spot', 'স্পট জমা দিন'),
            onPressed: loading ? null : _submit,
          ),
        ],
      ),
    );
  }
}
