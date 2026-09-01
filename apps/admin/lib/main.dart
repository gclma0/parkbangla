import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:parkbangla_client/parkbangla_client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

String _resolveApiUrl() {
  const envUrl = String.fromEnvironment('API_URL');
  if (envUrl.isNotEmpty) return envUrl;
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    return 'http://10.0.2.2:3001';
  }
  return 'http://localhost:3001';
}

final kApiUrl = _resolveApiUrl();
const yellow = Color(0xFFFFC629);
const ink = Color(0xFF1A1A1A);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AdminApp());
}

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ParkBangla Ops',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: const ColorScheme.light(primary: yellow, onPrimary: ink, secondary: ink),
        textTheme: GoogleFonts.plusJakartaSansTextTheme(),
        scaffoldBackgroundColor: const Color(0xFFF7F4EE),
      ),
      home: const Gate(),
    );
  }
}

class Gate extends StatefulWidget {
  const Gate({super.key});
  @override
  State<Gate> createState() => _GateState();
}

class _GateState extends State<Gate> {
  final api = PbApi(baseUrl: kApiUrl);
  final phone = TextEditingController(text: '01710000009');
  final otp = TextEditingController(text: '123456');
  String? token;
  String? err;
  bool ready = false;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    final p = await SharedPreferences.getInstance();
    token = p.getString('admin_token');
    api.token = token;
    setState(() => ready = true);
  }

  Future<void> _login() async {
    setState(() => err = null);
    try {
      await api.post('/auth/otp/request', {'phone': phone.text.trim()});
      final res = Map<String, dynamic>.from(
        await api.post('/auth/otp/verify', {'phone': phone.text.trim(), 'code': otp.text.trim()}) as Map,
      );
      final user = Map<String, dynamic>.from(res['user'] as Map);
      if (user['isAdmin'] != true) {
        setState(() => err = 'Not an admin account');
        return;
      }
      token = res['token'] as String;
      api.token = token;
      final p = await SharedPreferences.getInstance();
      await p.setString('admin_token', token!);
      setState(() {});
    } catch (e) {
      setState(() => err = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!ready) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (token == null) {
      return Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('ParkBangla Ops', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  const Text('Demo admin 01710000009 · OTP 123456'),
                  const SizedBox(height: 16),
                  TextField(controller: phone, decoration: const InputDecoration(labelText: 'Phone')),
                  TextField(controller: otp, decoration: const InputDecoration(labelText: 'OTP')),
                  if (err != null) Text(err!, style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 16),
                  FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: yellow, foregroundColor: ink),
                    onPressed: _login,
                    child: const Text('Enter dashboard'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return Dashboard(api: api, onLogout: () async {
      final p = await SharedPreferences.getInstance();
      await p.remove('admin_token');
      setState(() => token = null);
    });
  }
}

class Dashboard extends StatefulWidget {
  const Dashboard({super.key, required this.api, required this.onLogout});
  final PbApi api;
  final VoidCallback onLogout;
  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  int tab = 0;
  Map stats = {};
  List users = [];
  List spots = [];
  List disputes = [];
  List reports = [];
  String? err;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      stats = await widget.api.get('/admin/stats') as Map;
      users = await widget.api.get('/admin/users') as List;
      spots = await widget.api.get('/admin/spots') as List;
      disputes = await widget.api.get('/admin/disputes') as List;
      reports = await widget.api.get('/admin/reports') as List;
      err = null;
    } catch (e) {
      err = e.toString();
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final pages = [_stats(), _users(), _spots(), _disputes(), _reports()];
    return Scaffold(
      appBar: AppBar(
        title: const Text('ParkBangla Ops'),
        backgroundColor: yellow,
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
          TextButton(onPressed: widget.onLogout, child: const Text('Log out', style: TextStyle(color: ink))),
        ],
      ),
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: tab,
            onDestinationSelected: (v) => setState(() => tab = v),
            labelType: NavigationRailLabelType.all,
            destinations: const [
              NavigationRailDestination(icon: Icon(Icons.insights), label: Text('Stats')),
              NavigationRailDestination(icon: Icon(Icons.people), label: Text('Users')),
              NavigationRailDestination(icon: Icon(Icons.local_parking), label: Text('Spots')),
              NavigationRailDestination(icon: Icon(Icons.gavel), label: Text('Disputes')),
              NavigationRailDestination(icon: Icon(Icons.flag), label: Text('Reports')),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: err != null ? Center(child: Text(err!)) : pages[tab],
          ),
        ],
      ),
    );
  }

  Widget _stats() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          _tile('Users', '${stats['users'] ?? '—'}'),
          _tile('Active spots', '${stats['activeSpots'] ?? '—'}'),
          _tile('Bookings', '${stats['bookings'] ?? '—'}'),
          _tile('Commission ৳', '${stats['commissionRevenue'] ?? '—'}'),
        ],
      ),
    );
  }

  Widget _tile(String k, String v) {
    return Container(
      width: 200,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(k, style: const TextStyle(color: Colors.black54)),
        Text(v, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
      ]),
    );
  }

  Widget _users() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: users.map((raw) {
        final u = Map<String, dynamic>.from(raw as Map);
        return Card(
          child: ListTile(
            title: Text('${u['name']}  ·  ${u['phone']}'),
            subtitle: Text('verified=${u['idVerified']} admin=${u['isAdmin']} wallet=${u['walletBalance']}'),
            trailing: TextButton(
              onPressed: () async {
                await widget.api.patch('/admin/users/${u['id']}/verify-id', {'verified': !(u['idVerified'] == true)});
                _load();
              },
              child: const Text('Toggle ID'),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _spots() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: spots.map((raw) {
        final s = Map<String, dynamic>.from(raw as Map);
        return Card(
          child: ListTile(
            title: Text('${s['area']} · ${s['address']}'),
            subtitle: Text('${s['verifiedStatus']} · ৳${s['monthlyPrice']}'),
            trailing: Wrap(children: [
              TextButton(
                onPressed: () async {
                  await widget.api.patch('/admin/spots/${s['id']}/verify', {'status': 'VERIFIED'});
                  _load();
                },
                child: const Text('Verify'),
              ),
              TextButton(
                onPressed: () async {
                  await widget.api.patch('/admin/spots/${s['id']}/verify', {'status': 'REJECTED'});
                  _load();
                },
                child: const Text('Reject'),
              ),
            ]),
          ),
        );
      }).toList(),
    );
  }

  Widget _disputes() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: disputes.map((raw) {
        final d = Map<String, dynamic>.from(raw as Map);
        return Card(
          child: ListTile(
            title: Text('${d['status']} · ${d['notes']}'),
            trailing: TextButton(
              onPressed: () async {
                await widget.api.patch('/admin/disputes/${d['id']}', {
                  'status': 'RESOLVED',
                  'resolution': 'Refunded by ops',
                  'refund': true,
                });
                _load();
              },
              child: const Text('Resolve+refund'),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _reports() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: reports.map((raw) {
        final r = Map<String, dynamic>.from(raw as Map);
        return ListTile(title: Text('${r['targetType']} ${r['targetId']}'), subtitle: Text('${r['reason']}'));
      }).toList(),
    );
  }
}
