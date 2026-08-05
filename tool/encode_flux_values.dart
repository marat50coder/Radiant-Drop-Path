// ignore_for_file: avoid_print

import 'dart:typed_data';

// Keep this in sync with lib/fluxgate/core/flux_cipher.dart. Change `_fluxSeed`
// there AND here together, then re-run: dart run tool/encode_flux_values.dart
const List<int> _fluxSeed = <int>[
  0x52,
  0x64,
  0x70,
  0x2A,
  0x66,
  0x6C,
  0x75,
  0x78,
  0x34,
  0x51,
  0x37,
  0x5E,
];

int _xorshift(int state) {
  var h = state & 0xffffffff;
  h ^= (h << 13) & 0xffffffff;
  h ^= h >> 17;
  h ^= (h << 5) & 0xffffffff;
  return h & 0xffffffff;
}

Uint8List _fluxStream(int length) {
  var hash = 0x811c9dc5;
  for (final byte in _fluxSeed) {
    hash = ((hash ^ byte) * 0x01000193) & 0xffffffff;
  }
  final result = Uint8List(length);
  for (var index = 0; index < length; index++) {
    hash = _xorshift((hash + (index * 0x9e3779b1)) & 0xffffffff);
    result[index] = (hash ^ (hash >> 8) ^ (hash >> 16)) & 0xff;
  }
  return result;
}

List<int> fold(String value) {
  final bytes = Uint8List.fromList(value.codeUnits);
  final stream = _fluxStream(bytes.length);
  return List<int>.generate(bytes.length, (index) {
    final combined = (bytes[index] + stream[index] + (index * 17)) & 0xff;
    return combined ^ _fluxSeed[index % _fluxSeed.length];
  });
}

String unfold(List<int> encoded) {
  final stream = _fluxStream(encoded.length);
  return String.fromCharCodes(
    List<int>.generate(encoded.length, (index) {
      final unmasked = encoded[index] ^ _fluxSeed[index % _fluxSeed.length];
      return (unmasked - stream[index] - (index * 17)) & 0xff;
    }),
  );
}

void main() {
  const values = <String, String>{
    'config': 'https://radiantdroppath.com/config.php',
    'privacy': 'https://radiantdroppath.com/privacy-policy.html',
    'support': 'https://radiantdroppath.com/support.html',
    'gcd': 'https://gcdsdk.appsflyer.com/install_data/v5.0/',
    'webkit': '605.1.15',
    'safari': '18.7',
    'safariTail': '604.1',
    'appsFlyerDevKey': 'NUR4s2AGvF6bNrnjSs55xV',
    'firebaseProjectNumber': '151296230806',
    'oneLinkHost': 'radiantdrop.onelink.me',
  };

  for (final entry in values.entries) {
    final encoded = fold(entry.value);
    print('${entry.key}: <int>[${encoded.join(', ')}]');
    if (unfold(encoded) != entry.value) {
      throw StateError('Round-trip failed for ${entry.key}');
    }
  }
  print('VERIFY: all values round-tripped');
}
