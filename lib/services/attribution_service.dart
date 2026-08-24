import 'dart:async';

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:appsflyer_sdk/appsflyer_sdk.dart';
import 'package:flutter/foundation.dart';

/// Thin wrapper around the AppsFlyer SDK used by the white build for install
/// attribution. Does not drive any in-app routing — decoupled from the gray
/// flow — it just registers the install with AppsFlyer so that acquisition
/// campaigns and reengagement can be measured.
class AttributionService {
  AttributionService._();
  static final AttributionService instance = AttributionService._();

  static const String _appsFlyerDevKey = 'NUR4s2AGvF6bNrnjSs55xV';
  static const String _iosAppStoreId = '6792810383';

  AppsflyerSdk? _sdk;
  bool _started = false;

  /// Fires ATT (iOS 14+ tracking prompt), then initializes and starts the
  /// AppsFlyer SDK. Safe to call multiple times — subsequent calls are no-ops.
  /// Any error is swallowed so a missing/blocked SDK never breaks the game.
  Future<void> start() async {
    if (_started) return;
    _started = true;

    try {
      await _requestTrackingIfNeeded();
    } catch (error) {
      _log('ATT request failed: $error');
    }

    try {
      final options = AppsFlyerOptions(
        afDevKey: _appsFlyerDevKey,
        appId: _iosAppStoreId,
        showDebug: kDebugMode,
        timeToWaitForATTUserAuthorization: 15,
      );
      final sdk = AppsflyerSdk(options);
      _sdk = sdk;
      await sdk.initSdk(
        registerConversionDataCallback: true,
        registerOnAppOpenAttributionCallback: false,
        registerOnDeepLinkingCallback: false,
      );
      _log('AppsFlyer SDK started.');
    } catch (error) {
      _log('AppsFlyer init failed: $error');
    }
  }

  /// Best-effort accessor to the resolved AppsFlyer UID (null before init).
  Future<String?> get appsFlyerId async {
    final sdk = _sdk;
    if (sdk == null) return null;
    try {
      return await sdk.getAppsFlyerUID();
    } catch (error) {
      _log('getAppsFlyerUID failed: $error');
      return null;
    }
  }

  Future<void> _requestTrackingIfNeeded() async {
    final status =
        await AppTrackingTransparency.trackingAuthorizationStatus;
    if (status == TrackingStatus.notDetermined) {
      // Small pre-warm so the system prompt shows reliably right after
      // ATT.trackingAuthorizationStatus finishes settling.
      await Future<void>.delayed(const Duration(milliseconds: 200));
      await AppTrackingTransparency.requestTrackingAuthorization();
    }
  }

  void _log(String message) {
    assert(() {
      debugPrint('[RDP.ATTR] $message');
      return true;
    }());
  }
}
