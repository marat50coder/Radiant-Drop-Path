import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

/// Reads the cold-start push destination written by SceneDelegate.swift.
/// The `flutter.` prefix on the native side bridges UserDefaults ↔
/// SharedPreferences, so the Dart key omits it.
class ColdTapReader {
  static const String _dartKey = 'rdp_tap_route';

  static Future<String?> consume() async {
    if (!Platform.isIOS) return null;
    try {
      final preferences = await SharedPreferences.getInstance();
      final value = preferences.getString(_dartKey)?.trim();
      // Always remove — a stale non-URL token from an earlier build must not
      // linger and get replayed on every cold start.
      await preferences.remove(_dartKey);
      if (value == null || value.isEmpty) return null;
      if (!value.startsWith('http://') && !value.startsWith('https://')) {
        return null;
      }
      return value;
    } catch (_) {
      return null;
    }
  }
}
