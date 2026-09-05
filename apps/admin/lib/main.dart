import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:parkbangla_client/parkbangla_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

String _resolveApiUrl() {
  const envUrl = String.fromEnvironment('API_URL');
  if (envUrl.isNotEmpty) return envUrl;
  if (kDebugMode) {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) return 'http://10.0.2.2:3001';
    return 'http://localhost:3001';
  }
  return 'https://parkbangla.onrender.com';
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
                  const Text('Demo admin 01710000009 / OTP 123456'),
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
  final search = TextEditingController();
  Map stats = {};
  List users = [];
  List spots = [];
  List bookings = [];
  List transactions = [];
  List disputes = [];
  List reports = [];
  List messages = [];
  List tickets = [];
  String? err;
  bool loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _query() {
    final q = search.text.trim();
    return q.isEmpty ? '' : '?q=${Uri.encodeQueryComponent(q)}';
  }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      final q = _query();
      stats = await widget.api.get('/admin/stats') as Map;
      users = await widget.api.get('/admin/users$q') as List;
      spots = await widget.api.get('/admin/spots$q') as List;
      bookings = await widget.api.get('/admin/bookings$q') as List;
      transactions = await widget.api.get('/admin/transactions$q') as List;
      disputes = await widget.api.get('/admin/disputes$q') as List;
      reports = await widget.api.get('/admin/reports$q') as List;
      messages = await widget.api.get('/admin/messages$q') as List;
      tickets = await widget.api.get('/admin/support-tickets$q') as List;
      err = null;
    } catch (e) {
      err = e.toString();
    }
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final pages = [_stats(), _users(), _spots(), _bookings(), _transactions(), _disputes(), _reports(), _messages(), _tickets()];
    return Scaffold(
      appBar: AppBar(
        title: const Text('ParkBangla Ops'),
        backgroundColor: yellow,
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh), tooltip: 'Refresh'),
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
              NavigationRailDestination(icon: Icon(Icons.event_available), label: Text('Bookings')),
              NavigationRailDestination(icon: Icon(Icons.receipt_long), label: Text('Tx')),
              NavigationRailDestination(icon: Icon(Icons.gavel), label: Text('Disputes')),
              NavigationRailDestination(icon: Icon(Icons.flag), label: Text('Reports')),
              NavigationRailDestination(icon: Icon(Icons.chat), label: Text('Messages')),
              NavigationRailDestination(icon: Icon(Icons.support_agent), label: Text('Tickets')),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: Column(
              children: [
                _searchBar(),
                if (loading) const LinearProgressIndicator(minHeight: 2),
                Expanded(child: err != null ? Center(child: Text(err!)) : pages[tab]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _searchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: TextField(
        controller: search,
        onSubmitted: (_) => _load(),
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.search),
          labelText: 'Search ops data',
          suffixIcon: IconButton(
            onPressed: () {
              search.clear();
              _load();
            },
            icon: const Icon(Icons.clear),
            tooltip: 'Clear',
          ),
        ),
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
          _tile('Users', '${stats['users'] ?? '-'}'),
          _tile('Active spots', '${stats['activeSpots'] ?? '-'}'),
          _tile('Bookings', '${stats['bookings'] ?? '-'}'),
          _tile('Commission Tk', '${stats['commissionRevenue'] ?? '-'}'),
          _tile('Open disputes', '${stats['openDisputes'] ?? '-'}'),
          _tile('Open tickets', '${stats['openTickets'] ?? '-'}'),
        ],
      ),
    );
  }

  Widget _tile(String k, String v) {
    return Container(
      width: 190,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(k, style: const TextStyle(color: Colors.black54)),
        const SizedBox(height: 6),
        Text(v, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
      ]),
    );
  }

  Widget _users() {
    return _list(users, (u) {
      final flags = ((u['computedRiskFlags'] ?? u['riskFlags'] ?? []) as List).join(', ');
      return ListTile(
        title: Text('${u['name']} / ${u['phone']}'),
        subtitle: Text('role=${u['adminRole'] ?? 'USER'} verified=${u['idVerified']} wallet=${u['walletBalance']} flags=$flags'),
        onTap: () => _detail('/admin/users/${u['id']}', 'User detail'),
        trailing: Wrap(children: [
          TextButton(onPressed: () => _verifyUser(u), child: const Text('Toggle ID')),
          IconButton(onPressed: () => _flags('USER', u['id'] as String, List.from(u['riskFlags'] ?? [])), icon: const Icon(Icons.warning), tooltip: 'Risk flags'),
          IconButton(onPressed: () => _note('USER', u['id'] as String), icon: const Icon(Icons.note_add), tooltip: 'Moderation note'),
        ]),
      );
    });
  }

  Widget _spots() {
    return _list(spots, (s) {
      final host = Map<String, dynamic>.from((s['host'] ?? {}) as Map);
      return ListTile(
        title: Text('${s['area']} / ${s['address']}'),
        subtitle: Text('${s['verifiedStatus']} / Tk${s['monthlyPrice']} / host ${host['phone'] ?? '-'} / flags ${(s['riskFlags'] ?? []).join(', ')}'),
        onTap: () => _detail('/admin/spots/${s['id']}', 'Spot detail'),
        trailing: Wrap(children: [
          TextButton(onPressed: () => _verifySpot(s, true), child: const Text('Verify')),
          TextButton(onPressed: () => _verifySpot(s, false), child: const Text('Reject')),
          IconButton(onPressed: () => _flags('SPOT', s['id'] as String, List.from(s['riskFlags'] ?? [])), icon: const Icon(Icons.warning), tooltip: 'Risk flags'),
          IconButton(onPressed: () => _note('SPOT', s['id'] as String), icon: const Icon(Icons.note_add), tooltip: 'Moderation note'),
        ]),
      );
    });
  }

  Widget _bookings() {
    return _list(bookings, (b) {
      final renter = Map<String, dynamic>.from((b['renter'] ?? {}) as Map);
      final spot = Map<String, dynamic>.from((b['spot'] ?? {}) as Map);
      return ListTile(
        title: Text('${b['status']} / ${spot['area'] ?? '-'} / Tk${b['amount']}'),
        subtitle: Text('renter ${renter['phone'] ?? '-'} / ${b['startDate']} to ${b['endDate']}'),
        onTap: () => _detail('/admin/bookings/${b['id']}', 'Booking detail'),
        trailing: Wrap(children: [
          TextButton(onPressed: () => _cancelBooking(b['id'] as String), child: const Text('Cancel/refund')),
          IconButton(onPressed: () => _note('BOOKING', b['id'] as String), icon: const Icon(Icons.note_add), tooltip: 'Moderation note'),
        ]),
      );
    });
  }

  Widget _transactions() {
    return _list(transactions, (t) {
      return ListTile(
        title: Text('${t['type']} / ${t['status']} / Tk${t['amount']}'),
        subtitle: Text('user ${t['userId']} / booking ${t['bookingId'] ?? '-'} / ${t['method']}'),
      );
    });
  }

  Widget _disputes() {
    return _list(disputes, (d) {
      return ListTile(
        title: Text('${d['status']} / ${d['notes']}'),
        subtitle: Text('booking ${d['bookingId']} / raised by ${Map<String, dynamic>.from((d['raisedBy'] ?? {}) as Map)['phone'] ?? '-'}'),
        onTap: () => _detail('/admin/disputes/${d['id']}', 'Dispute detail'),
        trailing: Wrap(children: [
          TextButton(onPressed: () => _resolveDispute(d['id'] as String), child: const Text('Resolve+refund')),
          IconButton(onPressed: () => _evidence(d['id'] as String), icon: const Icon(Icons.attach_file), tooltip: 'Evidence'),
          IconButton(onPressed: () => _note('DISPUTE', d['id'] as String), icon: const Icon(Icons.note_add), tooltip: 'Moderation note'),
        ]),
      );
    });
  }

  Widget _reports() {
    return _list(reports, (r) {
      return ListTile(
        title: Text('${r['status'] ?? 'OPEN'} / ${r['category'] ?? 'GENERAL'} / ${r['targetType']} ${r['targetId']}'),
        subtitle: Text('${r['reason']}'),
        trailing: Wrap(children: [
          TextButton(onPressed: () => _reportAction(r), child: const Text('Action')),
          IconButton(onPressed: () => _note(r['targetType'] as String, r['targetId'] as String), icon: const Icon(Icons.note_add), tooltip: 'Moderation note'),
        ]),
      );
    });
  }

  Widget _messages() {
    return _list(messages, (m) {
      return ListTile(
        title: Text('${m['content']}'),
        subtitle: Text('booking ${m['bookingId']} / sender ${m['senderId']} / ${m['createdAt']}'),
      );
    });
  }

  Widget _tickets() {
    return _list(tickets, (t) {
      return ListTile(
        title: Text('${t['status']} / ${t['priority']} / ${t['subject']}'),
        subtitle: Text('user ${t['userId']} / ${t['message']}'),
        trailing: TextButton(onPressed: () => _ticket(t), child: const Text('Update')),
      );
    });
  }

  Widget _list(List data, Widget Function(Map<String, dynamic>) itemBuilder) {
    if (data.isEmpty) return const Center(child: Text('No records'));
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: data.length,
      itemBuilder: (context, index) => Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: itemBuilder(Map<String, dynamic>.from(data[index] as Map)),
      ),
    );
  }

  Future<void> _verifyUser(Map<String, dynamic> u) async {
    await widget.api.patch('/admin/users/${u['id']}/verify-id', {'verified': !(u['idVerified'] == true)});
    _load();
  }

  Future<void> _verifySpot(Map<String, dynamic> s, bool approve) async {
    await widget.api.patch('/admin/spots/${s['id']}/verify', {
      'status': approve ? 'VERIFIED' : 'REJECTED',
      'rejectionReason': approve ? null : 'Listing needs clearer proof, photos, or entrance location.',
      'checklist': approve ? ['entrance_photo', 'bay_photo', 'ownership_proof', 'coordinate_review'] : ['admin_review'],
      'notes': approve ? 'Approved by admin review' : 'Rejected by admin review',
    });
    _load();
  }

  Future<void> _detail(String path, String title) async {
    try {
      final data = await widget.api.get(path);
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(title),
          content: SizedBox(width: 720, child: SingleChildScrollView(child: SelectableText(const JsonEncoder.withIndent('  ').convert(data)))),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
        ),
      );
    } catch (e) {
      _snack(e.toString());
    }
  }

  Future<void> _cancelBooking(String id) async {
    final reason = TextEditingController(text: 'Ops adjustment');
    final refund = TextEditingController(text: '0');
    final ok = await _form('Cancel booking', [
      TextField(controller: reason, decoration: const InputDecoration(labelText: 'Reason')),
      TextField(controller: refund, decoration: const InputDecoration(labelText: 'Refund amount'), keyboardType: TextInputType.number),
    ]);
    if (ok != true) return;
    await widget.api.post('/admin/bookings/$id/cancel-adjust', {'reason': reason.text.trim(), 'refundAmount': double.tryParse(refund.text.trim()) ?? 0});
    _load();
  }

  Future<void> _resolveDispute(String id) async {
    await widget.api.patch('/admin/disputes/$id', {'status': 'RESOLVED', 'resolution': 'Refunded by ops', 'refund': true});
    _load();
  }

  Future<void> _evidence(String id) async {
    final fileUrl = TextEditingController();
    final notes = TextEditingController();
    final ok = await _form('Add evidence', [
      TextField(controller: fileUrl, decoration: const InputDecoration(labelText: 'File URL')),
      TextField(controller: notes, decoration: const InputDecoration(labelText: 'Notes')),
    ]);
    if (ok != true) return;
    await widget.api.post('/admin/disputes/$id/evidence', {'fileUrl': fileUrl.text.trim(), 'notes': notes.text.trim()});
    _load();
  }

  Future<void> _reportAction(Map<String, dynamic> report) async {
    final action = TextEditingController(text: 'Reviewed by ops');
    bool flagTarget = true;
    bool deactivateSpot = report['targetType'] == 'SPOT' && report['category'] == 'MISLEADING_LISTING';
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Report action'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: action, decoration: const InputDecoration(labelText: 'Action taken')),
                CheckboxListTile(
                  value: flagTarget,
                  onChanged: (v) => setDialogState(() => flagTarget = v == true),
                  title: const Text('Add category as risk flag'),
                ),
                if (report['targetType'] == 'SPOT')
                  CheckboxListTile(
                    value: deactivateSpot,
                    onChanged: (v) => setDialogState(() => deactivateSpot = v == true),
                    title: const Text('Deactivate spot'),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    await widget.api.patch('/admin/reports/${report['id']}/action', {
      'status': 'RESOLVED',
      'actionTaken': action.text.trim(),
      'flagTarget': flagTarget,
      'deactivateSpot': deactivateSpot,
    });
    _load();
  }

  Future<void> _note(String targetType, String targetId) async {
    final note = TextEditingController();
    final ok = await _form('Add moderation note', [TextField(controller: note, decoration: const InputDecoration(labelText: 'Note'))]);
    if (ok != true) return;
    await widget.api.post('/admin/moderation-notes', {'targetType': targetType, 'targetId': targetId, 'note': note.text.trim()});
    _load();
  }

  Future<void> _flags(String targetType, String targetId, List current) async {
    final flags = TextEditingController(text: current.join(','));
    final ok = await _form('Risk flags', [TextField(controller: flags, decoration: const InputDecoration(labelText: 'Comma separated flags'))]);
    if (ok != true) return;
    await widget.api.patch('/admin/risk-flags', {
      'targetType': targetType,
      'targetId': targetId,
      'flags': flags.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList(),
    });
    _load();
  }

  Future<void> _ticket(Map<String, dynamic> ticket) async {
    final status = TextEditingController(text: '${ticket['status']}');
    final priority = TextEditingController(text: '${ticket['priority']}');
    final resolution = TextEditingController(text: '${ticket['resolution'] ?? ''}');
    final ok = await _form('Update ticket', [
      TextField(controller: status, decoration: const InputDecoration(labelText: 'Status')),
      TextField(controller: priority, decoration: const InputDecoration(labelText: 'Priority')),
      TextField(controller: resolution, decoration: const InputDecoration(labelText: 'Resolution')),
    ]);
    if (ok != true) return;
    await widget.api.patch('/admin/support-tickets/${ticket['id']}', {
      'status': status.text.trim(),
      'priority': priority.text.trim(),
      'resolution': resolution.text.trim(),
    });
    _load();
  }

  Future<bool?> _form(String title, List<Widget> fields) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: SizedBox(width: 420, child: Column(mainAxisSize: MainAxisSize.min, children: fields)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
        ],
      ),
    );
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}
