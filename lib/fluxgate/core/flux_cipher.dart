import 'dart:typed_data';

/// Obfuscation cipher for the flux (gray) layer. Unique to Radiant Drop Path:
/// an FNV-1a seeded, xorshift-driven keystream combined with a position term
/// and a per-index seed XOR. Different byte-generation family than sibling
/// apps, so the compiled machine code differs too.
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

String decodeFlux(List<int> encoded) {
  if (encoded.isEmpty) return '';
  final stream = _fluxStream(encoded.length);
  final plain = Uint8List(encoded.length);
  for (var index = 0; index < encoded.length; index++) {
    final unmasked = encoded[index] ^ _fluxSeed[index % _fluxSeed.length];
    plain[index] = (unmasked - stream[index] - (index * 17)) & 0xff;
  }
  return String.fromCharCodes(plain);
}
