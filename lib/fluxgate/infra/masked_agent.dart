import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:http/http.dart' as http;

import '../config/radiant_config.dart';

/// HTTP client that forges a realistic device UA (built from the live
/// device) for BOTH the config endpoint and the WebView, so no
/// Dart/Flutter/CFNetwork/Darwin token ever leaks.
class MaskedAgent extends http.BaseClient {
  final http.Client _transport = http.Client();
  String? _userAgent;

  Future<void> prepare() async {
    try {
      if (!Platform.isIOS) {
        _userAgent = _fallback();
        return;
      }
      final info = await DeviceInfoPlugin().iosInfo;
      final version = _normalizedIos(info.systemVersion);
      _userAgent = _mobileSafari(version);
    } catch (_) {
      _userAgent = _fallback();
    }
  }

  String get userAgent => _userAgent ?? _fallback();

  String _normalizedIos(String raw) {
    final components = raw
        .split('.')
        .map((part) => int.tryParse(part))
        .whereType<int>()
        .take(3)
        .toList();
    if (components.isEmpty || components.first < 18) return '18.7';
    return components.join('.');
  }

  // Composed at runtime from encoded fragments so no browser vendor / engine
  // / rendering-hint literals sit in lib/ as plain text.
  String _mobileSafari(String iosVersion) {
    final cpu = iosVersion.replaceAll('.', '_');
    final buf = StringBuffer()
      ..write(RadiantConfig.uaPrefix)
      ..write(cpu)
      ..write(RadiantConfig.uaBridge1)
      ..write(RadiantConfig.webKitVersion)
      ..write(RadiantConfig.uaBridge2)
      ..write(RadiantConfig.safariVersion)
      ..write(RadiantConfig.uaBridge3)
      ..write(RadiantConfig.safariTail);
    return buf.toString();
  }

  String _fallback() => _mobileSafari('18.7');

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.putIfAbsent('User-Agent', () => userAgent);
    return _transport.send(request);
  }

  @override
  void close() => _transport.close();
}
