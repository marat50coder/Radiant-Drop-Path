import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Background message handler entry point. Must be a top-level function so it
/// can be resolved from the isolate that Firebase spawns when the app is
/// backgrounded / terminated. Kept intentionally minimal — the white build
/// does not act on push payloads, it just logs delivery.
@pragma('vm:entry-point')
Future<void> radiantBackgroundHandler(RemoteMessage message) async {
  assert(() {
    debugPrint(
      '[RDP.PUSH] background message id=${message.messageId} '
      'data=${message.data}',
    );
    return true;
  }());
}

/// Thin wrapper around Firebase Messaging used by the white build to receive
/// remote notifications. Does not drive any in-app navigation on tap — a push
/// just opens the app to the main menu. Safe to call `initialize()` multiple
/// times; it will short-circuit after the first successful call.
class NotificationsService {
  NotificationsService._();
  static final NotificationsService instance = NotificationsService._();

  bool _initialized = false;
  String? _fcmToken;

  String? get fcmToken => _fcmToken;

  /// Initializes Firebase Core + Messaging, requests user permission, wires
  /// foreground / background / open-from-tap handlers and caches the FCM
  /// token. Any error is swallowed so a broken/absent Firebase config never
  /// breaks the game — the app just proceeds without push.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    try {
      await Firebase.initializeApp();
    } catch (error) {
      _log('Firebase.initializeApp failed: $error');
      return;
    }

    try {
      FirebaseMessaging.onBackgroundMessage(radiantBackgroundHandler);

      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      _log('permission status: ${settings.authorizationStatus}');

      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      try {
        _fcmToken = await messaging.getToken();
        _log('FCM token: ${_fcmToken?.substring(0, 12) ?? "null"}…');
      } catch (error) {
        _log('getToken failed: $error');
      }

      FirebaseMessaging.instance.onTokenRefresh.listen((token) {
        _fcmToken = token;
        _log('token refreshed: ${token.substring(0, 12)}…');
      });

      FirebaseMessaging.onMessage.listen((message) {
        _log(
          'foreground push id=${message.messageId} '
          'title=${message.notification?.title} data=${message.data}',
        );
      });

      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        _log(
          'push tap (background) id=${message.messageId} data=${message.data}',
        );
      });

      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) {
        _log('push tap (cold start) data=${initial.data}');
      }
    } catch (error) {
      _log('messaging init failed: $error');
    }
  }

  void _log(String message) {
    assert(() {
      debugPrint('[RDP.PUSH] $message');
      return true;
    }());
  }
}
