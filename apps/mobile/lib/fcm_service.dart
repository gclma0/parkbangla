import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'firebase_options.dart';
import 'session.dart';
import 'spot_flow.dart';

import 'package:flutter/foundation.dart' show kIsWeb;

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class FcmHandler {
  static Future<void> init() async {
    if (kIsWeb) {
      debugPrint('FCM is not supported on Web. Skipping init.');
      return;
    }
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      final messaging = FirebaseMessaging.instance;
      
      // Request notification permissions
      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        _handleForegroundMessage(message);
      });

      // Handle background/tapped message (when app is in background but not terminated)
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        _handleNotificationTap(message);
      });

      // Handle terminated app launch via notification
      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) {
        // Wait a short duration for the navigator tree to build
        Future.delayed(const Duration(milliseconds: 800), () {
          _handleNotificationTap(initialMessage);
        });
      }

      // Token refresh listener
      messaging.onTokenRefresh.listen((newToken) {
        _sendTokenToBackend(newToken);
      });
    } catch (e) {
      debugPrint('FCM Init Error: $e');
    }
  }

  static Future<void> updateToken() async {
    if (kIsWeb) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await _sendTokenToBackend(token);
      }
    } catch (e) {
      debugPrint('Error getting FCM token: $e');
    }
  }

  static Future<void> _sendTokenToBackend(String token) async {
    if (session.api.token != null) {
      try {
        await session.api.patch('/me', {'fcmToken': token});
        debugPrint('FCM token sent to backend: $token');
      } catch (e) {
        debugPrint('Error sending FCM token to backend: $e');
      }
    }
  }

  static void _handleForegroundMessage(RemoteMessage message) {
    final title = message.notification?.title ?? 'Notification';
    final body = message.notification?.body ?? '';
    final bookingId = message.data['bookingId'];

    final context = navigatorKey.currentContext;
    if (context != null) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
            if (bookingId != null)
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  navigatorKey.currentState?.push(
                    MaterialPageRoute(
                      builder: (_) => CheckInPage(bookingId: bookingId.toString()),
                    ),
                  );
                },
                child: const Text('View'),
              ),
          ],
        ),
      );
    }
  }

  static void _handleNotificationTap(RemoteMessage message) {
    final bookingId = message.data['bookingId'];
    if (bookingId != null) {
      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => CheckInPage(bookingId: bookingId.toString()),
        ),
      );
    }
  }
}
