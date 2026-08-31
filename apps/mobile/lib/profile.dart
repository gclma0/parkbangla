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
  bool _showAddVehicleForm = false;

  @override
  void dispose() {
    plate.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final i = I18n(session.bn);
    final vehicles = (session.user?['vehicles'] as List?) ?? [];
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width > 768;

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 800),
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          children: [
            Text(
              i.profile,
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
                        _buildProfileCard(i),
                        const SizedBox(height: 20),
                        _buildVerificationCard(i),
                        const SizedBox(height: 20),
                        _buildSafetyCard(i),
                        const SizedBox(height: 20),
                        _buildAccountActions(i),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    flex: 12,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildPreferencesCard(i),
                        const SizedBox(height: 20),
                        _buildVehiclesSection(vehicles, i, isDesktop),
                      ],
                    ),
                  ),
                ],
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildProfileCard(i),
                  const SizedBox(height: 16),
                  _buildPreferencesCard(i),
                  const SizedBox(height: 16),
                  _buildVehiclesSection(vehicles, i, isDesktop),
                  const SizedBox(height: 16),
                  _buildVerificationCard(i),
                  const SizedBox(height: 16),
                  _buildSafetyCard(i),
                  const SizedBox(height: 16),
                  _buildAccountActions(i),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileCard(I18n i) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Pb.ink.withOpacity(0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.01),
            blurRadius: 8,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: Pb.yellow,
            child: Text(
              session.name.characters.first.toUpperCase(),
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Pb.ink),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.name,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Pb.ink),
                ),
                const SizedBox(height: 3),
                Text(
                  session.user?['phone']?.toString() ?? '',
                  style: const TextStyle(color: Pb.muted, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: session.user?['idVerified'] == true ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            session.user?['idVerified'] == true ? Icons.check_circle : Icons.error_outline,
                            color: session.user?['idVerified'] == true ? Colors.green[800] : Colors.red[800],
                            size: 13,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            session.user?['idVerified'] == true ? i.t('✓ ID Verified', '✓ আইডি ভেরিফাইড') : i.t('Unverified', 'আনভেরিফাইড'),
                            style: TextStyle(
                              color: session.user?['idVerified'] == true ? Colors.green[800] : Colors.red[800],
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Pb.yellow.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        session.isHost ? i.host : i.renter,
                        style: const TextStyle(
                          color: Pb.ink,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
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

  Widget _buildPreferencesCard(I18n i) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Pb.ink.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            i.t('Preferences', 'পছন্দসমূহ'),
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Pb.ink),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.language, color: Pb.muted, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      i.t('App Language', 'অ্যাপের ভাষা'),
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                    ),
                    Text(
                      session.bn ? 'বাংলা' : 'English',
                      style: const TextStyle(color: Pb.muted, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  Text(
                    'EN',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: !session.bn ? FontWeight.w900 : FontWeight.normal,
                      color: !session.bn ? Pb.ink : Pb.muted,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Switch(
                    value: session.bn,
                    activeColor: Pb.ink,
                    activeTrackColor: Pb.yellow,
                    inactiveThumbColor: Pb.ink,
                    inactiveTrackColor: Colors.grey[200],
                    onChanged: (v) => session.setBn(v),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'বাংলা',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: session.bn ? FontWeight.w900 : FontWeight.normal,
                      color: session.bn ? Pb.ink : Pb.muted,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSafetyCard(I18n i) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Pb.ink.withOpacity(0.06)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SosPage())),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red[50],
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.emergency_share_outlined, color: Colors.red[800], size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    i.sos,
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Pb.ink),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    i.t('Quick emergency assistance', 'জরুরি দ্রুত সহায়তা'),
                    style: const TextStyle(color: Pb.muted, fontSize: 11),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  Widget _buildVerificationCard(I18n i) {
    final isVerified = session.user?['idVerified'] == true;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Pb.ink.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            i.t('Identity Verification', 'পরিচয় যাচাইকরণ'),
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Pb.ink),
          ),
          const SizedBox(height: 12),
          if (isVerified) ...[
            Row(
              children: [
                Icon(Icons.verified, color: Colors.green[700], size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        i.t('Status: Verified', 'অবস্থা: যাচাইকৃত'),
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Colors.green[800]),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        i.t('Identity has been successfully verified.', 'পরিচয় সফলভাবে যাচাই করা হয়েছে।'),
                        style: const TextStyle(color: Pb.muted, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ] else ...[
            Text(
              i.t('Verify identity for listing spots or booking.', 'বুকিং ও স্পট লিস্টিং এর জন্য পরিচয় যাচাই করুন।'),
              style: const TextStyle(color: Pb.muted, fontSize: 12, height: 1.3),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () async {
                await session.api.patch('/me', {'nidDocUrl': '/uploads/nid-demo.jpg'});
                await session.refreshMe();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(i.t('NID marked uploaded', 'এনআইডি আপলোড সফল হয়েছে'))),
                  );
                }
              },
              style: FilledButton.styleFrom(
                backgroundColor: Pb.yellow,
                foregroundColor: Pb.ink,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              icon: const Icon(Icons.upload_file, size: 18),
              label: Text(i.t('Verify Identity', 'পরিচয় যাচাই করুন')),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVehiclesSection(List vehicles, I18n i, bool isDesktop) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Pb.ink.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                i.t('My Vehicles', 'আমার গাড়ি সমূহ'),
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Pb.ink),
              ),
              const Spacer(),
              if (isDesktop && !_showAddVehicleForm)
                TextButton.icon(
                  onPressed: () => setState(() => _showAddVehicleForm = true),
                  icon: const Icon(Icons.add, size: 18, color: Pb.yellowDeep),
                  label: Text(
                    i.t('Add Vehicle', 'গাড়ি যোগ'),
                    style: const TextStyle(color: Pb.yellowDeep, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _buildAddVehicleForm(i),
          if (vehicles.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24),
              alignment: Alignment.center,
              child: Text(
                i.t('No vehicles added yet.', 'এখনো কোনো গাড়ি যোগ করা হয়নি।'),
                style: const TextStyle(color: Pb.muted, fontSize: 12, fontStyle: FontStyle.italic),
              ),
            )
          else
            ...vehicles.map((v) => _buildVehicleItem(Map<String, dynamic>.from(v as Map), i)),
          if (!isDesktop && !_showAddVehicleForm)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: OutlinedButton.icon(
                onPressed: () => setState(() => _showAddVehicleForm = true),
                icon: const Icon(Icons.add, size: 16),
                label: Text(i.t('Add Vehicle', 'গাড়ি যোগ')),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildVehicleItem(Map<String, dynamic> m, I18n i) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Pb.cream,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Pb.ink.withOpacity(0.04)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Pb.yellow.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.directions_car, color: Pb.ink, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  m['plate']?.toString() ?? '',
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Pb.ink),
                ),
                const SizedBox(height: 2),
                Text(
                  '${m['type']?.toString().toUpperCase()} · ${m['sizeClass']?.toString().toUpperCase()}',
                  style: const TextStyle(color: Pb.muted, fontSize: 11),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
            onPressed: () async {
              try {
                await session.api.delete('/me/vehicles/${m['id']}');
                await session.refreshMe();
                setState(() {});
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAddVehicleForm(I18n i) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      child: !_showAddVehicleForm
          ? const SizedBox.shrink()
          : Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Pb.cream,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Pb.ink.withOpacity(0.08)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    i.t('Add New Vehicle', 'নতুন গাড়ি যোগ করুন'),
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: plate,
                    decoration: InputDecoration(
                      hintText: 'DHAKA-GA-00-0000',
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Pb.ink.withOpacity(0.1)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Pb.yellowDeep, width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => setState(() => _showAddVehicleForm = false),
                        child: Text(i.t('Cancel', 'বাতিল'), style: const TextStyle(color: Pb.muted, fontSize: 13)),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () async {
                          if (plate.text.trim().isEmpty) return;
                          try {
                            await session.api.post('/me/vehicles', {
                              'plate': plate.text.trim(),
                              'type': 'car',
                              'sizeClass': 'sedan',
                            });
                            plate.clear();
                            await session.refreshMe();
                            setState(() {
                              _showAddVehicleForm = false;
                            });
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                            }
                          }
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: Pb.yellow,
                          foregroundColor: Pb.ink,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                        child: Text(i.t('Add', 'যোগ করুন')),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildAccountActions(I18n i) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Pb.ink.withOpacity(0.06)),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        leading: const Icon(Icons.logout, color: Colors.red),
        title: Text(
          i.t('Log out', 'লগ আউট'),
          style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w800, fontSize: 14),
        ),
        onTap: session.logout,
      ),
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
