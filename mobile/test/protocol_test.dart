import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mactouch_mobile/core/protocol/crypto.dart';
import 'package:mactouch_mobile/core/protocol/qr_payload.dart';

Map<String, dynamic> _validQr({Map<String, Object?> override = const {}, DateTime? now}) {
  final base = <String, Object?>{
    'app': 'mactouch',
    'v': 1,
    'host': '192.168.1.20',
    'port': 48500,
    'token': b64uEncode(List<int>.generate(32, (i) => i)),
    'exp': ((now ?? DateTime.now()).millisecondsSinceEpoch ~/ 1000) + 120,
    'name': 'Mac mini',
    'id': 'server-0123456789',
  };
  return {...base, ...override}..removeWhere((_, v) => v == #remove);
}

void main() {
  test('handshake matches the shared test vectors (same file Swift and Node check)', () {
    final v = jsonDecode(File('../protocol/test-vectors.json').readAsStringSync()) as Map<String, dynamic>;
    final token = b64uDecode(v['token'] as String);
    final id = v['deviceId'] as String, cn = v['clientNonce'] as String, sn = v['serverNonce'] as String;

    expect(b64uEncode(Handshake.pairProof(token: token, deviceId: id, clientNonce: cn, serverNonce: sn)), v['pairProof']);
    final secret = Handshake.deriveSecret(token: token, deviceId: id, clientNonce: cn, serverNonce: sn);
    expect(b64uEncode(secret), v['secret']);
    expect(b64uEncode(Handshake.authProof(secret: secret, deviceId: id, clientNonce: cn, serverNonce: sn)), v['authProof']);
    expect(b64uEncode(Handshake.serverProof(secret: secret, clientNonce: cn, serverNonce: sn)), v['serverProof']);
  });

  test('base64url round trip without padding', () {
    for (var n = 0; n < 40; n++) {
      final bytes = randomBytes(n);
      final text = b64uEncode(bytes);
      expect(text.contains(RegExp(r'[=+/]')), isFalse);
      expect(b64uDecode(text), bytes);
    }
    expect(() => b64uDecode('!!!'), throwsFormatException);
  });

  test('constantTimeEquals', () {
    expect(constantTimeEquals([1, 2, 3], [1, 2, 3]), isTrue);
    expect(constantTimeEquals([1, 2, 3], [1, 2, 4]), isFalse);
    expect(constantTimeEquals([1, 2], [1, 2, 3]), isFalse);
  });

  group('QR payload validation', () {
    test('accepts a valid payload', () {
      final p = QrPayload.parse(jsonEncode(_validQr()));
      expect(p.host, '192.168.1.20');
      expect(p.port, 48500);
      expect(p.token.length, 32);
      expect(p.serverName, 'Mac mini');
    });

    void rejects(String why, String raw, QrError error) {
      test('rejects $why', () {
        expect(() => QrPayload.parse(raw), throwsA(isA<QrException>().having((e) => e.error, 'error', error)));
      });
    }

    rejects('plain text', 'hello', QrError.notJson);
    rejects('a URL', 'https://example.com', QrError.notJson);
    rejects('JSON for another app', jsonEncode({'app': 'other'}), QrError.notMacTouch);
    rejects('a JSON array', '[1,2]', QrError.notMacTouch);
    rejects('a newer protocol version', jsonEncode(_validQr(override: {'v': 2})), QrError.unsupportedVersion);
    rejects('a missing version', jsonEncode(_validQr(override: {'v': #remove})), QrError.invalidField);
    rejects('a public IP address', jsonEncode(_validQr(override: {'host': '8.8.8.8'})), QrError.invalidField);
    rejects('a hostname', jsonEncode(_validQr(override: {'host': 'example.com'})), QrError.invalidField);
    rejects('a privileged port', jsonEncode(_validQr(override: {'port': 80})), QrError.invalidField);
    rejects('a short token', jsonEncode(_validQr(override: {'token': 'AAAA'})), QrError.invalidField);
    rejects('a non-base64 token', jsonEncode(_validQr(override: {'token': '!!!!'})), QrError.invalidField);
    rejects('an empty name', jsonEncode(_validQr(override: {'name': ' '})), QrError.invalidField);
    rejects('a malformed server id', jsonEncode(_validQr(override: {'id': 'x y'})), QrError.invalidField);
    rejects('an expired code',
        jsonEncode(_validQr(override: {'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 - 600})), QrError.expired);
    rejects('an oversized payload', 'x' * 3000, QrError.notMacTouch);
  });

  test('isPrivateIPv4', () {
    for (final ip in ['10.0.0.5', '172.16.1.1', '172.31.255.1', '192.168.1.20', '169.254.3.4']) {
      expect(isPrivateIPv4(ip), isTrue, reason: ip);
    }
    for (final ip in ['8.8.8.8', '172.32.0.1', '192.169.0.1', '256.1.1.1', '01.2.3.4', 'abc', '1.2.3']) {
      expect(isPrivateIPv4(ip), isFalse, reason: ip);
    }
  });
}
