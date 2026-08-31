import 'package:flutter/foundation.dart';
import 'package:parkbangla_client/parkbangla_client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'fcm_service.dart';

const kApiUrl = String.fromEnvironment('API_URL', defaultValue: 'http://localhost:3001');

class Session extends ChangeNotifier {
  Session() {
    api = PbApi(baseUrl: kApiUrl);
  }

  late PbApi api;
  Map<String, dynamic>? user;
  String role = 'renter';
  bool bn = false;
  bool ready = false;

  Future<void> boot() async {
    final p = await SharedPreferences.getInstance();
    final token = p.getString('token');
    role = p.getString('role') ?? 'renter';
    api.activeRole = role;
    bn = p.getBool('bn') ?? false;
    if (token != null) {
      api.token = token;
      try {
        user = Map<String, dynamic>.from(await api.get('/me') as Map);
        FcmHandler.updateToken();
        fetchUnreadCount();
      } catch (_) {
        api.token = null;
        await p.remove('token');
      }
    }
    ready = true;
    notifyListeners();
  }

  Future<void> _persist() async {
    final p = await SharedPreferences.getInstance();
    if (api.token != null) {
      await p.setString('token', api.token!);
    } else {
      await p.remove('token');
    }
    await p.setString('role', role);
    await p.setBool('bn', bn);
  }

  Future<Map<String, dynamic>> requestOtp(String phone) async {
    return Map<String, dynamic>.from(await api.post('/auth/otp/request', {'phone': phone}) as Map);
  }

  Future<void> verifyOtp(String phone, String code, {String? name}) async {
    final res = Map<String, dynamic>.from(
      await api.post('/auth/otp/verify', {'phone': phone, 'code': code, if (name != null) 'name': name}) as Map,
    );
    api.token = res['token'] as String;
    user = Map<String, dynamic>.from(res['user'] as Map);
    if (phone == '01710000002' || phone == '01710000003') {
      role = 'host';
    } else {
      role = 'renter';
    }
    api.activeRole = role;
    await _persist();
    FcmHandler.updateToken();
    fetchUnreadCount();
    notifyListeners();
  }

  Future<void> refreshMe() async {
    user = Map<String, dynamic>.from(await api.get('/me') as Map);
    notifyListeners();
  }

  Future<void> setRole(String r) async {
    if (user?['phone']?.toString() == '01710000001' && r != 'renter') return;
    if ((user?['phone']?.toString() == '01710000002' || user?['phone']?.toString() == '01710000003') && r != 'host') return;
    role = r;
    api.activeRole = r;
    await _persist();
    notifyListeners();
  }

  Future<void> setBn(bool v) async {
    bn = v;
    await _persist();
    try {
      await api.patch('/me', {'locale': v ? 'bn' : 'en'});
    } catch (_) {}
    notifyListeners();
  }

  Future<void> logout() async {
    try {
      await api.patch('/me', {'fcmToken': null});
    } catch (_) {}
    api.token = null;
    api.activeRole = null;
    user = null;
    await _persist();
    notifyListeners();
  }

  int unreadNotificationsCount = 0;

  Future<void> fetchUnreadCount() async {
    if (api.token == null) return;
    try {
      final data = await api.get('/notifications');
      if (data is List) {
        unreadNotificationsCount = data.where((n) => Map<String, dynamic>.from(n as Map)['read'] != true).length;
        notifyListeners();
      }
    } catch (_) {}
  }

  String get name => user?['name'] as String? ?? 'ParkBangla';
  String get id => user?['id'] as String? ?? '';
  bool get isHost => role == 'host';
}

final session = Session();
