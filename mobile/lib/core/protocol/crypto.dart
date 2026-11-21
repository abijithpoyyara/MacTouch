import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

String b64uEncode(List<int> bytes) => base64Url.encode(bytes).replaceAll('=', '');

/// Throws [FormatException] on invalid input.
Uint8List b64uDecode(String text) {
  final padded = text + '=' * ((4 - text.length % 4) % 4);
  return Uint8List.fromList(base64Url.decode(padded));
}

Uint8List randomBytes(int count) {
  final rng = Random.secure();
  return Uint8List.fromList(List<int>.generate(count, (_) => rng.nextInt(256)));
}

bool constantTimeEquals(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a[i] ^ b[i];
  }
  return diff == 0;
}

List<int> _hmac(List<int> key, String message) =>
    Hmac(sha256, key).convert(utf8.encode(message)).bytes;

/// Domain-separated HMAC-SHA256 derivations. See protocol/PROTOCOL.md.
abstract final class Handshake {
  static List<int> pairProof({required List<int> token, required String deviceId, required String clientNonce, required String serverNonce}) =>
      _hmac(token, 'pair|$deviceId|$clientNonce|$serverNonce');

  static List<int> deriveSecret({required List<int> token, required String deviceId, required String clientNonce, required String serverNonce}) =>
      _hmac(token, 'secret|$deviceId|$clientNonce|$serverNonce');

  static List<int> authProof({required List<int> secret, required String deviceId, required String clientNonce, required String serverNonce}) =>
      _hmac(secret, 'auth|$deviceId|$clientNonce|$serverNonce');

  static List<int> serverProof({required List<int> secret, required String clientNonce, required String serverNonce}) =>
      _hmac(secret, 'server|$serverNonce|$clientNonce');
}
