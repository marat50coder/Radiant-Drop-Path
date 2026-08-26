import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';

import 'drop_vault.dart';
import 'trace_signals.dart' show fluxTrace;

@pragma('vm:entry-point')
Future<void> rdpBackgroundMessage(RemoteMessage _) async {}

/// Firebase Messaging / APNs wrapper: token warmup, permission prompt,
/// foreground presentation and push-destination extraction.
class PulseBeacon {
  PulseBeacon(this._vault, {required this.enabled});

  final DropVault _vault;
  final bool enabled;
  FirebaseMessaging? _messaging;
  Future<void>? _bootFuture;
  Future<bool>? _permissionFuture;
  String? _token;

  void Function(String url)? onDestination;
  void Function(String token)? onTokenChanged;

  String? get token => _token;

  Future<void> boot() => _bootFuture ??= _boot();

  Future<void> _boot() async {
    if (!enabled) return;
    final messaging = FirebaseMessaging.instance;
    _messaging = messaging;
    // getInitialMessage() returns the RemoteMessage that launched the app
    // via a push tap (or null). On a cold-start with a slow / large Firebase
    // bootstrap it can take a few seconds to resolve, so we give it a
    // generous window before falling through — losing this call is the
    // single biggest source of "opened the wrong URL" reports because the
    // routing then leans on the cached URL from the previous session.
    final initial = await messaging.getInitialMessage().timeout(
      const Duration(seconds: 8),
      onTimeout: () {
        fluxTrace(
          () => '[RDX.PUSH] getInitialMessage timed out (8s) — likely no tap',
        );
        return null;
      },
    );
    final initialUrl = initial == null ? null : _extract(initial.data);
    if (initial != null) {
      fluxTrace(
        () => '[RDX.PUSH] initial data=${initial.data} url=$initialUrl',
      );
    }
    if (initialUrl != null) await _vault.stashPushUrl(initialUrl);

    FirebaseMessaging.onBackgroundMessage(rdpBackgroundMessage);
    await messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
    messaging.onTokenRefresh.listen((value) {
      _token = value;
      onTokenChanged?.call(value);
    });
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      final url = _extract(message.data);
      fluxTrace(
        () => '[RDX.PUSH] opened data=${message.data} url=$url',
      );
      if (url == null) return;
      final callback = onDestination;
      if (callback == null) {
        _vault.stashPushUrl(url);
      } else {
        callback(url);
      }
    });
    await _waitForApns();
    _token = await messaging.getToken();
  }

  /// Extracts the destination URL from a push payload. Checks a broad set of
  /// keys — the config backend and OneLink/AppsFlyer publish under different
  /// names depending on channel. First match wins. Only http(s) are accepted;
  /// non-URL strings (deep_link_value tokens, campaign labels) are skipped
  /// so we never navigate to a garbage URL.
  String? _extract(Map<String, dynamic> payload) {
    for (final key in const <String>[
      // config backend / partner
      'destination', 'target_url', 'target', 'deep_link', 'deeplink',
      'redirect_url', 'redirect', 'url', 'link', 'href',
      // AppsFlyer OneLink / Firebase
      'af_dp', 'af_web_dp', 'af_deep_link', 'af_web_deep_link',
      'gcm.notification.link', 'notification_link',
    ]) {
      final value = payload[key];
      if (value is String) {
        final trimmed = value.trim();
        if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
          return trimmed;
        }
      }
    }
    for (final container in const <String>[
      'payload', 'data', 'gcm.notification', 'aps',
    ]) {
      final nested = payload[container];
      if (nested is Map) {
        final found = _extract(Map<String, dynamic>.from(nested));
        if (found != null) return found;
      }
    }
    return null;
  }

  Future<void> _waitForApns({int attempts = 6}) async {
    final messaging = _messaging;
    if (messaging == null) return;
    for (var attempt = 0; attempt < attempts; attempt++) {
      try {
        if ((await messaging.getAPNSToken())?.isNotEmpty ?? false) return;
      } catch (_) {}
      await Future<void>.delayed(const Duration(milliseconds: 550));
    }
  }

  Future<bool> canOfferPermission() async {
    if (!enabled || _vault.pushDeniedByOs) return false;
    final messaging = _messaging;
    if (messaging == null) return false;
    final status =
        (await messaging.getNotificationSettings()).authorizationStatus;
    if (status == AuthorizationStatus.denied) {
      await _vault.markPushDeniedByOs();
      return false;
    }
    return status == AuthorizationStatus.notDetermined ||
        status == AuthorizationStatus.provisional;
  }

  Future<bool> askPermission() {
    return _permissionFuture ??= _performPermissionRequest().whenComplete(
      () => _permissionFuture = null,
    );
  }

  Future<bool> _performPermissionRequest() async {
    if (!enabled || _messaging == null) return false;
    final result = await _messaging!.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    final accepted =
        result.authorizationStatus == AuthorizationStatus.authorized ||
        result.authorizationStatus == AuthorizationStatus.provisional;
    await _vault.setPushAllowed(accepted);
    if (!accepted && result.authorizationStatus == AuthorizationStatus.denied) {
      await _vault.markPushDeniedByOs();
    }
    if (accepted) {
      await _waitForApns(attempts: 14);
      _token = await _messaging!.getToken();
      if (_token?.isNotEmpty ?? false) onTokenChanged?.call(_token!);
    }
    return accepted;
  }
}
