import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/flux_models.dart';

/// Persists the flux routing decision, cached WebView URL, pending push URL
/// and the push-invite state. Content URLs live in the Keychain (secure),
/// flags/timestamps in SharedPreferences.
class DropVault {
  static const String _routeKey = 'rdp.vault.route';
  static const String _expiryKey = 'rdp.vault.expiry';
  static const String _inviteKey = 'rdp.vault.invite.after';
  static const String _permissionKey = 'rdp.vault.push.allowed';
  static const String _osDeniedKey = 'rdp.vault.push.os_denied';
  static const String _savedUrlKey = 'rdp.vault.secure.destination';
  static const String _pendingUrlKey = 'rdp.vault.secure.pending';

  final FlutterSecureStorage _secure = const FlutterSecureStorage();
  late SharedPreferences _preferences;

  Future<void> initialize() async {
    _preferences = await SharedPreferences.getInstance();
  }

  FlowRoute get route => FlowRoute.parse(_preferences.getString(_routeKey));

  Future<void> saveRoute(FlowRoute route) =>
      _preferences.setString(_routeKey, route.storageValue);

  Future<String?> savedUrl() async {
    try {
      return await _secure.read(key: _savedUrlKey);
    } catch (_) {
      return null;
    }
  }

  Future<void> cacheUrl(String url, int? expiresAt) async {
    try {
      await _secure.write(key: _savedUrlKey, value: url);
      if (expiresAt != null) {
        await _preferences.setInt(_expiryKey, expiresAt);
      }
    } catch (_) {}
  }

  bool get cachedUrlExpired {
    final expiry = _preferences.getInt(_expiryKey);
    return expiry == null ||
        DateTime.now().millisecondsSinceEpoch ~/ 1000 >= expiry;
  }

  Future<void> stashPushUrl(String url) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return;
    // Guard against stashing non-URL tokens (`deep_link_test`, campaign
    // labels, etc.) so a poorly-formed payload can never end up steering the
    // portal to a garbage / stale destination on the next launch.
    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
      return;
    }
    try {
      await _secure.write(key: _pendingUrlKey, value: trimmed);
    } catch (_) {}
  }

  Future<String?> consumePushUrl() async {
    try {
      final value = await _secure.read(key: _pendingUrlKey);
      if (value != null) await _secure.delete(key: _pendingUrlKey);
      if (value == null) return null;
      final trimmed = value.trim();
      if (trimmed.isEmpty) return null;
      // A stale non-URL from an earlier build (before validation existed)
      // must never make it to the WebView.
      if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
        return null;
      }
      return trimmed;
    } catch (_) {
      return null;
    }
  }

  bool get pushAllowed => _preferences.getBool(_permissionKey) ?? false;
  bool get pushDeniedByOs => _preferences.getBool(_osDeniedKey) ?? false;

  Future<void> setPushAllowed(bool value) =>
      _preferences.setBool(_permissionKey, value);

  Future<void> markPushDeniedByOs() => _preferences.setBool(_osDeniedKey, true);

  bool get shouldShowPushInvite {
    if (pushAllowed || pushDeniedByOs) return false;
    final after = _preferences.getInt(_inviteKey);
    return after == null ||
        DateTime.now().millisecondsSinceEpoch ~/ 1000 >= after;
  }

  Future<void> snoozePushInvite(int epochSeconds) =>
      _preferences.setInt(_inviteKey, epochSeconds);
}
