import 'package:flutter/material.dart';
import 'auth.dart';
import 'bookings.dart';
import 'fcm_service.dart';
import 'discover.dart';
import 'spot_flow.dart';
import 'i18n.dart';
import 'profile.dart';
import 'session.dart';
import 'theme.dart';
import 'wallet.dart';
import 'widgets.dart';

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int tab = 0;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: session,
      builder: (_, __) {
        final i = I18n(session.bn);
        final pages = session.isHost
            ? const [HostHome(), BookingsPage(), WalletPage(), ProfilePage()]
            : const [DiscoverPage(), BookingsPage(), WalletPage(), ProfilePage()];
        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: Row(
                    children: [
                      Text(i.app, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                      const Spacer(),
                      AnimatedBuilder(
                        animation: session,
                        builder: (context, _) {
                          final count = session.unreadNotificationsCount;
                          return Badge(
                            isLabelVisible: count > 0,
                            label: Text('$count'),
                            child: IconButton(
                              icon: const Icon(Icons.notifications_none_outlined),
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const NotificationsPage()),
                              ).then((_) => session.fetchUnreadCount()),
                            ),
                          );
                        },
                      ),
                      if (session.user?['phone']?.toString() != '01710000001' &&
                          session.user?['phone']?.toString() != '01710000002' &&
                          session.user?['phone']?.toString() != '01710000003') ...[
                        const SizedBox(width: 8),
                        RolePill(
                          host: session.isHost,
                          renterLabel: i.renter,
                          hostLabel: i.host,
                          onChanged: (h) => session.setRole(h ? 'host' : 'renter'),
                        ),
                      ],
                    ],
                  ),
                ),
                Expanded(child: pages[tab.clamp(0, pages.length - 1)]),
              ],
            ),
          ),
          bottomNavigationBar: NavigationBar(
            height: 68,
            backgroundColor: Colors.white,
            indicatorColor: Pb.yellow,
            selectedIndex: tab,
            onDestinationSelected: (v) => setState(() => tab = v),
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.local_fire_department_outlined),
                selectedIcon: const Icon(Icons.local_fire_department),
                label: session.isHost ? i.host : i.discover,
              ),
              NavigationDestination(
                icon: Badge(
                  isLabelVisible: session.unreadMessagesCount > 0,
                  label: Text('${session.unreadMessagesCount}'),
                  child: const Icon(Icons.style_outlined),
                ),
                selectedIcon: Badge(
                  isLabelVisible: session.unreadMessagesCount > 0,
                  label: Text('${session.unreadMessagesCount}'),
                  child: const Icon(Icons.style),
                ),
                label: i.bookings,
              ),
              NavigationDestination(
                icon: const Icon(Icons.account_balance_wallet_outlined),
                selectedIcon: const Icon(Icons.account_balance_wallet),
                label: i.wallet,
              ),
              NavigationDestination(icon: const Icon(Icons.person_outline), selectedIcon: const Icon(Icons.person), label: i.profile),
            ],
          ),
        );
      },
    );
  }
}

class ParkBanglaApp extends StatelessWidget {
  const ParkBanglaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'ParkBangla',
      debugShowCheckedModeBanner: false,
      theme: Pb.theme(),
      home: const SplashGate(home: Shell()),
    );
  }
}

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});
  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  List items = [];
  bool loading = true;
  Map<String, dynamic> prefs = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await session.api.get('/notifications');
      final rawPrefs = await session.api.get('/me/notification-preferences');
      setState(() => items = data as List);
      if (rawPrefs is Map) prefs = Map<String, dynamic>.from(rawPrefs);
    } catch (_) {}
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final i = I18n(session.bn);
    return Scaffold(
      backgroundColor: Pb.cream,
      appBar: AppBar(
        title: Text(i.t('Notifications', 'বিজ্ঞপ্তি')),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _preferences,
            icon: const Icon(Icons.tune),
            tooltip: i.t('Notification preferences', 'বিজ্ঞপ্তির সেটিংস'),
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: Pb.yellow))
          : items.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.notifications_off_outlined, size: 64, color: Pb.ink.withOpacity(0.2)),
                      const SizedBox(height: 16),
                      Text(
                        i.t('No notifications yet.', 'কোনো বিজ্ঞপ্তি নেই।'),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Pb.ink),
                      ),
                    ],
                  ),
                )
              : Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 800),
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                      itemCount: items.length,
                      itemBuilder: (ctx, idx) {
                        final n = Map<String, dynamic>.from(items[idx] as Map);
                        final read = n['read'] == true;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          color: read ? Colors.white : Pb.yellow.withOpacity(0.08),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                              color: read ? Pb.ink.withOpacity(0.06) : Pb.yellowDeep.withOpacity(0.3),
                              width: read ? 1 : 1.5,
                            ),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            leading: CircleAvatar(
                              backgroundColor: read ? Pb.cream : Pb.yellow,
                              child: Icon(
                                read ? Icons.notifications_none_outlined : Icons.notifications_active,
                                color: Pb.ink,
                              ),
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${n['title']}',
                                    style: TextStyle(
                                      fontWeight: read ? FontWeight.bold : FontWeight.w900,
                                      color: Pb.ink,
                                    ),
                                  ),
                                ),
                                if (!read)
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: Pb.yellowDeep,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                              ],
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                '${n['body']}',
                                style: TextStyle(color: read ? Pb.muted : Pb.ink),
                              ),
                            ),
                            onTap: () async {
                              // Mark as read
                              if (!read) {
                                try {
                                  await session.api.post('/notifications/${n['id']}/read');
                                  session.fetchUnreadCount();
                                  _load();
                                } catch (_) {}
                              }
                              // Deep-link to booking
                              final bookingId = n['bookingId'];
                              if (bookingId != null && context.mounted) {
                                final route = n['route']?.toString();
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => route?.endsWith('/chat') == true
                                        ? ChatPage(bookingId: bookingId.toString())
                                        : CheckInPage(bookingId: bookingId.toString()),
                                  ),
                                );
                              }
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ),
    );
  }

  Future<void> _preferences() async {
    bool pushEnabled = prefs['pushEnabled'] != false;
    bool inAppEnabled = prefs['inAppEnabled'] != false;
    final disabled = Set<String>.from((prefs['disabledTypes'] as List?)?.map((v) => v.toString()) ?? const []);
    const types = [
      'BOOKING_REQUESTED',
      'BOOKING_ACCEPTED',
      'BOOKING_REJECTED',
      'BOOKING_CANCELLED',
      'MESSAGE_RECEIVED',
      'UPCOMING_BOOKING_REMINDER',
      'CHECKOUT_REMINDER',
      'PENDING_APPROVAL_REMINDER',
    ];
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Notification preferences'),
            content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SwitchListTile(
                      value: pushEnabled,
                      onChanged: (v) => setDialogState(() => pushEnabled = v),
                      title: const Text('Push notifications'),
                    ),
                    SwitchListTile(
                      value: inAppEnabled,
                      onChanged: (v) => setDialogState(() => inAppEnabled = v),
                      title: const Text('In-app notifications'),
                    ),
                    const Divider(),
                    ...types.map(
                      (type) => CheckboxListTile(
                        value: !disabled.contains(type),
                        onChanged: (v) => setDialogState(() => v == true ? disabled.remove(type) : disabled.add(type)),
                        title: Text(type.replaceAll('_', ' ')),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
            ],
          ),
        );
      },
    );
    if (saved != true) return;
    await session.api.patch('/me/notification-preferences', {
      'pushEnabled': pushEnabled,
      'inAppEnabled': inAppEnabled,
      'disabledTypes': disabled.toList(),
    });
    await _load();
  }
}
