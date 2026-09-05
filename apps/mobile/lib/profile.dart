import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'i18n.dart';
import 'location_tools.dart';
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
                            session.user?['idVerified'] == true ? i.t('âœ“ ID Verified', 'âœ“ à¦†à¦‡à¦¡à¦¿ à¦­à§‡à¦°à¦¿à¦«à¦¾à¦‡à¦¡') : i.t('Unverified', 'à¦†à¦¨à¦­à§‡à¦°à¦¿à¦«à¦¾à¦‡à¦¡'),
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
            i.t('Preferences', 'à¦ªà¦›à¦¨à§à¦¦à¦¸à¦®à§‚à¦¹'),
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
                      i.t('App Language', 'à¦…à§à¦¯à¦¾à¦ªà§‡à¦° à¦­à¦¾à¦·à¦¾'),
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                    ),
                    Text(
                      session.bn ? 'à¦¬à¦¾à¦‚à¦²à¦¾' : 'English',
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
                    'à¦¬à¦¾à¦‚à¦²à¦¾',
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
                    i.t('Quick emergency assistance', 'à¦œà¦°à§à¦°à¦¿ à¦¦à§à¦°à§à¦¤ à¦¸à¦¹à¦¾à§Ÿà¦¤à¦¾'),
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
    final kycStatus = session.user?['kycStatus']?.toString() ?? 'NOT_SUBMITTED';
    final hasUploadedDoc = session.user?['nidDocUrl'] != null || session.user?['dlDocUrl'] != null;
    final isPending = !isVerified && (kycStatus == 'PENDING' || hasUploadedDoc);
    final isRejected = !isVerified && kycStatus == 'REJECTED';
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
            i.t('Identity Verification', 'à¦ªà¦°à¦¿à¦šà§Ÿ à¦¯à¦¾à¦šà¦¾à¦‡à¦•à¦°à¦£'),
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Pb.ink),
          ),
          const SizedBox(height: 12),
          if (isVerified || isPending || isRejected) ...[
            Row(
              children: [
                Icon(
                  isVerified ? Icons.verified : (isRejected ? Icons.error_outline : Icons.hourglass_top),
                  color: isVerified ? Colors.green[700] : (isRejected ? Colors.red[700] : Pb.yellowDeep),
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isVerified ? 'Status: Verified' : (isRejected ? 'Status: Rejected' : 'Status: Pending review'),
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: isVerified ? Colors.green[800] : (isRejected ? Colors.red[800] : Pb.ink),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isVerified
                            ? 'Identity has been successfully verified.'
                            : (isRejected
                                ? (session.user?['kycRejectionReason']?.toString() ?? 'Identity verification was rejected.')
                                : 'Document uploaded. Admin will review it.'),
                        style: const TextStyle(color: Pb.muted, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ] else ...[
            Text(
              i.t('Verify identity for listing spots or booking.', 'à¦¬à§à¦•à¦¿à¦‚ à¦“ à¦¸à§à¦ªà¦Ÿ à¦²à¦¿à¦¸à§à¦Ÿà¦¿à¦‚ à¦à¦° à¦œà¦¨à§à¦¯ à¦ªà¦°à¦¿à¦šà§Ÿ à¦¯à¦¾à¦šà¦¾à¦‡ à¦•à¦°à§à¦¨à¥¤'),
              style: const TextStyle(color: Pb.muted, fontSize: 12, height: 1.3),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () async {
                await _verifyIdentity();
              },
              style: FilledButton.styleFrom(
                backgroundColor: Pb.yellow,
                foregroundColor: Pb.ink,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              icon: const Icon(Icons.upload_file, size: 18),
              label: Text(i.t('Verify Identity', 'à¦ªà¦°à¦¿à¦šà§Ÿ à¦¯à¦¾à¦šà¦¾à¦‡ à¦•à¦°à§à¦¨')),
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
                i.t('My Vehicles', 'à¦†à¦®à¦¾à¦° à¦—à¦¾à§œà¦¿ à¦¸à¦®à§‚à¦¹'),
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Pb.ink),
              ),
              const Spacer(),
              if (isDesktop && !_showAddVehicleForm)
                TextButton.icon(
                  onPressed: () => setState(() => _showAddVehicleForm = true),
                  icon: const Icon(Icons.add, size: 18, color: Pb.yellowDeep),
                  label: Text(
                    i.t('Add Vehicle', 'à¦—à¦¾à§œà¦¿ à¦¯à§‹à¦—'),
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
                i.t('No vehicles added yet.', 'à¦à¦–à¦¨à§‹ à¦•à§‹à¦¨à§‹ à¦—à¦¾à§œà¦¿ à¦¯à§‹à¦— à¦•à¦°à¦¾ à¦¹à§Ÿà¦¨à¦¿à¥¤'),
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
                label: Text(i.t('Add Vehicle', 'à¦—à¦¾à§œà¦¿ à¦¯à§‹à¦—')),
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
                  '${m['type']?.toString().toUpperCase()} Â· ${m['sizeClass']?.toString().toUpperCase()}',
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
                    i.t('Add New Vehicle', 'à¦¨à¦¤à§à¦¨ à¦—à¦¾à§œà¦¿ à¦¯à§‹à¦— à¦•à¦°à§à¦¨'),
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: plate,
                    textInputAction: TextInputAction.done,
                    textCapitalization: TextCapitalization.characters,
                    onSubmitted: (_) => _addVehicle(),
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
                  FilledButton.icon(
                    onPressed: _addVehicle,
                    icon: const Icon(Icons.add),
                    label: Text(i.t('Add Vehicle', 'Add Vehicle')),
                    style: FilledButton.styleFrom(
                      backgroundColor: Pb.yellow,
                      foregroundColor: Pb.ink,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => setState(() => _showAddVehicleForm = false),
                        child: Text(i.t('Cancel', 'à¦¬à¦¾à¦¤à¦¿à¦²'), style: const TextStyle(color: Pb.muted, fontSize: 13)),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: _addVehicle,
                        style: FilledButton.styleFrom(
                          backgroundColor: Pb.yellow,
                          foregroundColor: Pb.ink,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                        child: Text(i.t('Add', 'à¦¯à§‹à¦— à¦•à¦°à§à¦¨')),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  Future<void> _verifyIdentity() async {
    try {
      await session.api.patch('/me', {'nidDocUrl': '/uploads/nid-demo.jpg'});
      await session.refreshMe();
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Identity document uploaded for review.')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _addVehicle() async {
    if (plate.text.trim().isEmpty) return;
    try {
      await session.api.post('/me/vehicles', {
        'plate': plate.text.trim().toUpperCase(),
        'type': 'car',
        'sizeClass': 'sedan',
      });
      plate.clear();
      await session.refreshMe();
      if (mounted) {
        setState(() {
          _showAddVehicleForm = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vehicle added.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
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
          i.t('Log out', 'à¦²à¦— à¦†à¦‰à¦Ÿ'),
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
  Map<String, dynamic>? summary;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await session.api.get('/host/summary');
      final mapped = Map<String, dynamic>.from(data as Map);
      if (!mounted) return;
      setState(() {
        summary = mapped;
        spots = mapped['spots'] as List? ?? [];
        loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => loading = false);
    }
  }

  void _add() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const ListSpotPage())).then((_) => _load());
  }

  void _edit(Map<String, dynamic> spot) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => ListSpotPage(initialSpot: spot))).then((_) => _load());
  }

  Future<void> _editPayout() async {
    final method = TextEditingController(text: session.user?['payoutMethod']?.toString() ?? 'bKash');
    final destination = TextEditingController(text: session.user?['payoutDestination']?.toString() ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Payout account'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: method, decoration: const InputDecoration(labelText: 'Method')),
            const SizedBox(height: 12),
            TextField(controller: destination, decoration: const InputDecoration(labelText: 'Account number or destination')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok == true) {
      await session.api.patch('/me', {
        'payoutMethod': method.text.trim(),
        'payoutDestination': destination.text.trim(),
      });
      await session.refreshMe();
      if (mounted) setState(() {});
    }
    method.dispose();
    destination.dispose();
  }

  Future<void> _blockSpot(Map<String, dynamic> spot) async {
    final reason = TextEditingController(text: 'Temporarily unavailable');
    DateTime start = DateTime.now();
    DateTime end = start.add(const Duration(hours: 4));
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Block spot'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: reason, decoration: const InputDecoration(labelText: 'Reason')),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Start date'),
                subtitle: Text(start.toLocal().toString().substring(0, 16)),
                onTap: () async {
                  final picked = await showDatePicker(context: context, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 180)), initialDate: start);
                  if (picked != null) setDialogState(() => start = DateTime(picked.year, picked.month, picked.day, start.hour, start.minute));
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('End date'),
                subtitle: Text(end.toLocal().toString().substring(0, 16)),
                onTap: () async {
                  final picked = await showDatePicker(context: context, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 180)), initialDate: end);
                  if (picked != null) setDialogState(() => end = DateTime(picked.year, picked.month, picked.day, end.hour, end.minute));
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Block')),
          ],
        ),
      ),
    );
    if (ok != true) {
      reason.dispose();
      return;
    }
    try {
      await session.api.post('/spots/${spot['id']}/blocks', {
        'startAt': start.toIso8601String(),
        'endAt': end.toIso8601String(),
        'reason': reason.text.trim(),
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Spot blocked.')));
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      reason.dispose();
    }
  }

  void _showSpotCalendar(Map<String, dynamic> spot) {
    final availability = List.from(spot['availability'] as List? ?? const []);
    final blocks = List.from(spot['blocks'] as List? ?? const []);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => ListView(
        padding: const EdgeInsets.all(20),
        shrinkWrap: true,
        children: [
          Text('${spot['area']} schedule', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          const Text('Availability', style: TextStyle(fontWeight: FontWeight.w800)),
          if (availability.isEmpty) const ListTile(contentPadding: EdgeInsets.zero, title: Text('No availability rules')),
          ...availability.map((raw) {
            final a = Map<String, dynamic>.from(raw as Map);
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_available),
              title: Text('${a['startTime']} - ${a['endTime']}'),
              subtitle: Text('Weekdays: ${(a['weekdays'] as List? ?? const []).join(', ')}'),
            );
          }),
          const Divider(),
          const Text('Temporary blocks', style: TextStyle(fontWeight: FontWeight.w800)),
          if (blocks.isEmpty) const ListTile(contentPadding: EdgeInsets.zero, title: Text('No active blocks')),
          ...blocks.map((raw) {
            final b = Map<String, dynamic>.from(raw as Map);
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_busy),
              title: Text('${b['startAt']}'),
              subtitle: Text('${b['endAt']}\n${b['reason'] ?? ''}'),
            );
          }),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final i = I18n(session.bn);
    if (loading) return const Center(child: CircularProgressIndicator(color: Pb.yellow));
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(i.t('Your spots', 'Your spots'), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _hostMetric('Earnings', 'Tk ${summary?['earnings'] ?? 0}'),
            _hostMetric('Pending', '${summary?['pendingRequests'] ?? 0}'),
            _hostMetric('Upcoming', '${summary?['upcomingBookings'] ?? 0}'),
            _hostMetric('Completed', '${summary?['completedBookings'] ?? 0}'),
          ],
        ),
        const SizedBox(height: 12),
        _payoutCard(),
        const SizedBox(height: 12),
        YellowCta(label: i.t('List a new spot', 'List a new spot'), onPressed: _add),
        const SizedBox(height: 16),
        ...spots.map((raw) {
          final s = Map<String, dynamic>.from(raw as Map);
          final blocks = List.from(s['blocks'] as List? ?? const []);
          final availability = List.from(s['availability'] as List? ?? const []);
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('${s['area']} · Tk ${s['monthlyPrice']}'),
                    subtitle: Text(
                      '${s['address']}\n${s['verifiedStatus']} · autoApprove ${s['autoApprove']}\n'
                      'Availability rules: ${availability.length} · active blocks: ${blocks.length}',
                    ),
                    isThreeLine: true,
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(icon: const Icon(Icons.edit, size: 16), label: const Text('Edit'), onPressed: () => _edit(s)),
                      OutlinedButton.icon(icon: const Icon(Icons.event_busy, size: 16), label: const Text('Block'), onPressed: () => _blockSpot(s)),
                      OutlinedButton.icon(icon: const Icon(Icons.calendar_month, size: 16), label: const Text('Calendar'), onPressed: () => _showSpotCalendar(s)),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _hostMetric(String label, String value) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: Pb.ink.withOpacity(0.06))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: Pb.muted, fontSize: 12, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Pb.ink, fontSize: 20, fontWeight: FontWeight.w900)),
      ]),
    );
  }

  Widget _payoutCard() {
    final method = session.user?['payoutMethod']?.toString();
    final destination = session.user?['payoutDestination']?.toString();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: Pb.ink.withOpacity(0.06))),
      child: Row(
        children: [
          const Icon(Icons.account_balance_wallet_outlined, color: Pb.yellowDeep),
          const SizedBox(width: 10),
          Expanded(child: Text(method == null || method.isEmpty ? 'Payout account not set' : '$method · ${destination ?? ''}', style: const TextStyle(fontWeight: FontWeight.w800))),
          TextButton(onPressed: _editPayout, child: const Text('Set')),
        ],
      ),
    );
  }
}

class ListSpotPage extends StatefulWidget {
  const ListSpotPage({super.key, this.initialSpot});
  final Map<String, dynamic>? initialSpot;
  @override
  State<ListSpotPage> createState() => _ListSpotPageState();
}

class _ListSpotPageState extends State<ListSpotPage> {
  static const _dhakaCenter = LatLng(23.7806, 90.4143);

  final _mapController = MapController();
  final address = TextEditingController();
  final area = TextEditingController();
  final lat = TextEditingController();
  final lng = TextEditingController();
  final photo = TextEditingController(text: 'https://images.unsplash.com/photo-1506521781263-d8422e82f27a?w=1200');
  final entrancePhoto = TextEditingController(text: 'https://images.unsplash.com/photo-1506521781263-d8422e82f27a?w=1200');
  final bayPhoto = TextEditingController(text: 'https://images.unsplash.com/photo-1590674899484-d5640e854abe?w=1200');
  final ownershipProof = TextEditingController(text: 'demo-host-permission-proof');
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
  bool locating = false;
  LatLng? markerPoint;

  @override
  void initState() {
    super.initState();
    final spot = widget.initialSpot;
    if (spot != null) {
      address.text = spot['address']?.toString() ?? '';
      area.text = spot['area']?.toString() ?? '';
      lat.text = spot['lat']?.toString() ?? '';
      lng.text = spot['lng']?.toString() ?? '';
      hourly.text = spot['hourlyPrice']?.toString() ?? '';
      daily.text = spot['dailyPrice']?.toString() ?? '';
      monthly.text = spot['monthlyPrice']?.toString() ?? '';
      widthM.text = spot['widthM']?.toString() ?? widthM.text;
      lengthM.text = spot['lengthM']?.toString() ?? lengthM.text;
      vehicleSizes.text = spot['vehicleSizes']?.toString() ?? vehicleSizes.text;
      accessType = spot['accessType']?.toString() ?? accessType;
      accessNotes.text = spot['accessNotes']?.toString() ?? accessNotes.text;
      entrancePhoto.text = spot['entrancePhotoUrl']?.toString() ?? entrancePhoto.text;
      bayPhoto.text = spot['bayPhotoUrl']?.toString() ?? bayPhoto.text;
      ownershipProof.text = spot['ownershipProofUrl']?.toString() ?? ownershipProof.text;
      final photos = spot['photos'];
      if (photos is List && photos.isNotEmpty) photo.text = photos.first.toString();
      covered = spot['covered'] == true;
      autoApprove = spot['autoApprove'] != false;
      final parsedLat = double.tryParse(lat.text);
      final parsedLng = double.tryParse(lng.text);
      if (parsedLat != null && parsedLng != null) markerPoint = LatLng(parsedLat, parsedLng);
    }
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
    entrancePhoto.dispose();
    bayPhoto.dispose();
    ownershipProof.dispose();
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

  void _setMarker(LatLng point, {bool moveMap = true}) {
    setState(() {
      markerPoint = point;
      lat.text = point.latitude.toStringAsFixed(7);
      lng.text = point.longitude.toStringAsFixed(7);
    });
    if (moveMap) _mapController.move(point, 17);
  }

  Future<void> _setMarkerAndAddress(LatLng point, {bool moveMap = true}) async {
    _setMarker(point, moveMap: moveMap);
    final place = await reverseGeocodePoint(point);
    if (!mounted || place == null) return;
    setState(() {
      if (address.text.trim().isEmpty) address.text = place.address;
      if (area.text.trim().isEmpty && place.area.trim().isNotEmpty) area.text = place.area;
    });
  }

  Future<void> _searchAddress() async {
    final term = '${address.text} ${area.text}'.trim();
    if (term.length < 2) return;
    final places = await searchOsmPlaces(term);
    if (!mounted) return;
    if (places.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No matching location found. Try a fuller address.')));
      return;
    }
    final place = places.first;
    _setMarker(place.point);
    if (address.text.trim().isEmpty) address.text = place.subtitle.isNotEmpty ? place.subtitle : place.title;
  }

  Future<void> _useCurrentLocation() async {
    setState(() => locating = true);
    final result = await getCurrentLocation();
    if (!mounted) return;
    setState(() => locating = false);
    if (result.point == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message ?? 'Current location unavailable.')));
      return;
    }
    await _setMarkerAndAddress(result.point!);
  }

  Future<void> _submit() async {
    if (address.text.trim().isEmpty || area.text.trim().isEmpty) return;
    if (accessNotes.text.trim().length < 3 ||
        entrancePhoto.text.trim().length < 3 ||
        bayPhoto.text.trim().length < 3 ||
        ownershipProof.text.trim().length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Access notes, entrance photo, bay photo, and ownership proof are required.')),
      );
      return;
    }
    final parsedLat = double.tryParse(lat.text);
    final parsedLng = double.tryParse(lng.text);
    if (parsedLat == null || parsedLng == null || parsedLat < -90 || parsedLat > 90 || parsedLng < -180 || parsedLng > 180) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Set an exact valid parking location on the map.')));
      return;
    }
    setState(() => loading = true);
    try {
      final payload = {
        'lat': parsedLat,
        'lng': parsedLng,
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
        'photos': [photo.text.trim(), entrancePhoto.text.trim(), bayPhoto.text.trim()],
        'entrancePhotoUrl': entrancePhoto.text.trim(),
        'bayPhotoUrl': bayPhoto.text.trim(),
        'ownershipProofUrl': ownershipProof.text.trim(),
        'autoApprove': autoApprove,
      };
      if (widget.initialSpot != null) {
        await session.api.patch('/spots/${widget.initialSpot!['id']}', payload);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Spot updated and submitted for review.')));
          Navigator.pop(context);
        }
        return;
      }
      final spot = Map<String, dynamic>.from(
        await session.api.post('/spots', payload) as Map,
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
      appBar: AppBar(title: Text(i.t('List a new spot', 'à¦¨à¦¤à§à¦¨ à¦¸à§à¦ªà¦Ÿ à¦¯à§‹à¦— à¦•à¦°à§à¦¨'))),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          TextField(controller: address, decoration: InputDecoration(labelText: i.t('Address', 'à¦ à¦¿à¦•à¦¾à¦¨à¦¾'))),
          const SizedBox(height: 12),
          TextField(controller: area, decoration: InputDecoration(labelText: i.t('Area (e.g. Gulshan)', 'à¦à¦²à¦¾à¦•à¦¾ (à¦¯à§‡à¦®à¦¨ à¦—à§à¦²à¦¶à¦¾à¦¨)'))),
          if (suggestions != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Suggested prices for ${area.text}: à§³${suggestions!['hourly']}/hr Â· à§³${suggestions!['daily']}/day Â· à§³${suggestions!['monthly']}/mo',
                style: const TextStyle(color: Pb.muted, fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.search),
                  label: const Text('Find on map'),
                  onPressed: _searchAddress,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  icon: locating
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.my_location),
                  label: const Text('Use current'),
                  onPressed: locating ? null : _useCurrentLocation,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: SizedBox(
              height: 260,
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: markerPoint ?? _dhakaCenter,
                  initialZoom: 15,
                  maxZoom: 19,
                  minZoom: 5,
                  interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
                  onTap: (_, point) => _setMarkerAndAddress(point, moveMap: false),
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.parkbangla.mobile',
                    maxZoom: 19,
                  ),
                  MarkerLayer(markers: [
                    if (markerPoint != null)
                      Marker(
                        point: markerPoint!,
                        width: 48,
                        height: 48,
                        child: const Icon(Icons.location_on, color: Pb.yellowDeep, size: 44),
                      ),
                  ]),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text('Tap the map to fine-tune the exact parking entrance.', style: TextStyle(color: Pb.muted, fontSize: 12)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: TextField(controller: lat, decoration: const InputDecoration(labelText: 'Latitude'))),
              const SizedBox(width: 12),
              Expanded(child: TextField(controller: lng, decoration: const InputDecoration(labelText: 'Longitude'))),
            ],
          ),
          const SizedBox(height: 12),
          TextField(controller: photo, decoration: InputDecoration(labelText: i.t('Photo URL', 'à¦›à¦¬à¦¿à¦° à¦‡à¦‰à¦†à¦°à¦à¦²'))),
          const SizedBox(height: 12),
          TextField(controller: entrancePhoto, decoration: const InputDecoration(labelText: 'Entrance photo URL')),
          const SizedBox(height: 12),
          TextField(controller: bayPhoto, decoration: const InputDecoration(labelText: 'Parking bay photo URL')),
          const SizedBox(height: 12),
          TextField(controller: ownershipProof, decoration: const InputDecoration(labelText: 'Ownership/permission proof URL or note')),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: accessType,
            decoration: InputDecoration(labelText: i.t('Access Type', 'à¦ªà§à¦°à¦¬à§‡à¦¶à¦¦à§à¦¬à¦¾à¦° à¦§à¦°à¦¨')),
            items: ['GUARD', 'GATE_CODE', 'REMOTE'].map((t) {
              return DropdownMenuItem(value: t, child: Text(t));
            }).toList(),
            onChanged: (val) {
              if (val != null) setState(() => accessType = val);
            },
          ),
          const SizedBox(height: 12),
          TextField(controller: accessNotes, decoration: InputDecoration(labelText: i.t('Access Notes', 'à¦ªà§à¦°à¦¬à§‡à¦¶à¦¦à§à¦¬à¦¾à¦° à¦¨à§‹à¦Ÿ'))),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: TextField(controller: widthM, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: i.t('Width (meters)', 'à¦ªà§à¦°à¦¸à§à¦¥ (à¦®à¦¿à¦Ÿà¦¾à¦°)')))),
              const SizedBox(width: 12),
              Expanded(child: TextField(controller: lengthM, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: i.t('Length (meters)', 'à¦¦à§ˆà¦°à§à¦˜à§à¦¯ (à¦®à¦¿à¦Ÿà¦¾à¦°)')))),
            ],
          ),
          const SizedBox(height: 12),
          TextField(controller: vehicleSizes, decoration: InputDecoration(labelText: i.t('Supported Vehicle Sizes (comma separated)', 'à¦¸à¦®à¦°à§à¦¥à¦¿à¦¤ à¦—à¦¾à§œà¦¿à¦° à¦¸à¦¾à¦‡à¦œ (à¦•à¦®à¦¾ à¦¦à§à¦¬à¦¾à¦°à¦¾ à¦†à¦²à¦¾à¦¦à¦¾ à¦•à¦°à§à¦¨)'))),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: TextField(controller: hourly, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: i.t('Hourly Price (à§³)', 'à¦˜à¦£à§à¦Ÿà¦¾à¦ªà§à¦°à¦¤à¦¿ à¦­à¦¾à§œà¦¾ (à§³)')))),
              const SizedBox(width: 12),
              Expanded(child: TextField(controller: daily, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: i.t('Daily Price (à§³)', 'à¦¦à§ˆà¦¨à¦¿à¦• à¦­à¦¾à§œà¦¾ (à§³)')))),
              const SizedBox(width: 12),
              Expanded(child: TextField(controller: monthly, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: i.t('Monthly Price (à§³)', 'à¦®à¦¾à¦¸à¦¿à¦• à¦­à¦¾à§œà¦¾ (à§³)')))),
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
            title: Text(i.t('Auto-approve Bookings', 'à¦¸à§à¦¬à§Ÿà¦‚à¦•à§à¦°à¦¿à§Ÿ à¦¬à§à¦•à¦¿à¦‚ à¦…à¦¨à§à¦®à§‹à¦¦à¦¨')),
            value: autoApprove,
            activeColor: Pb.ink,
            activeTrackColor: Pb.yellow,
            onChanged: (v) => setState(() => autoApprove = v),
          ),
          const SizedBox(height: 24),
          YellowCta(
            label: loading ? 'â€¦' : i.t('Submit Spot', 'à¦¸à§à¦ªà¦Ÿ à¦œà¦®à¦¾ à¦¦à¦¿à¦¨'),
            onPressed: loading ? null : _submit,
          ),
        ],
      ),
    );
  }
}
