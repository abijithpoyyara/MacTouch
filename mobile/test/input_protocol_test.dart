import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mactouch_mobile/core/protocol/crypto.dart';
import 'package:mactouch_mobile/core/protocol/input_protocol.dart';
import 'package:mactouch_mobile/core/touchpad/touchpad_settings.dart';

void main() {
  test('session key and input MAC match the shared test vectors (same file Swift and Node check)', () {
    final v = jsonDecode(File('../protocol/test-vectors.json').readAsStringSync()) as Map<String, dynamic>;
    final key = InputCrypto.sessionKey(
      secret: b64uDecode(v['secret'] as String),
      clientNonce: v['clientNonce'] as String,
      serverNonce: v['serverNonce'] as String,
    );
    expect(b64uEncode(key), v['sessionKey']);
    expect(b64uEncode(InputCrypto.inputMac(key, v['inputSeq'] as int, v['inputBody'] as String)), v['inputMac']);
  });

  test('event builders produce the compact wire format', () {
    expect(InputEvents.move(5, -3), {'e': 'move', 'dx': 5, 'dy': -3});
    expect(InputEvents.scroll(0, 12), {'e': 'scroll', 'dx': 0, 'dy': 12});
    expect(InputEvents.button('right', false), {'e': 'btn', 'b': 'right', 's': 'up'});
    expect(InputEvents.key(36, true, 8), {'e': 'key', 'c': 36, 's': 'down', 'm': 8});
    expect(InputEvents.release(), {'e': 'release'});
  });

  test('the MAC changes when the sequence number or the body changes', () {
    final key = List<int>.filled(32, 7);
    final base = b64uEncode(InputCrypto.inputMac(key, 1, '{"ev":[]}'));
    expect(b64uEncode(InputCrypto.inputMac(key, 2, '{"ev":[]}')), isNot(base));
    expect(b64uEncode(InputCrypto.inputMac(key, 1, '{"ev":[ ]}')), isNot(base));
  });

  group('TouchpadSettings', () {
    test('survive a JSON round trip', () {
      const s = TouchpadSettings(sensitivity: 2.1, accelEnabled: false, smoothing: 0.5, naturalScroll: false, invertHorizontal: true);
      final back = TouchpadSettings.fromJson(jsonDecode(jsonEncode(s.toJson())));
      expect(back.sensitivity, 2.1);
      expect(back.accelEnabled, isFalse);
      expect(back.smoothing, 0.5);
      expect(back.naturalScroll, isFalse);
      expect(back.invertHorizontal, isTrue);
    });

    test('out-of-range and wrongly typed values are clamped or replaced by defaults', () {
      final s = TouchpadSettings.fromJson({'sensitivity': 99, 'smoothing': -5, 'scrollSensitivity': 'fast', 'tapToClick': 'yes'});
      expect(s.sensitivity, TouchpadSettings.sensitivityRange.max);
      expect(s.smoothing, TouchpadSettings.smoothingRange.min);
      expect(s.scrollSensitivity, const TouchpadSettings().scrollSensitivity);
      expect(s.tapToClick, const TouchpadSettings().tapToClick);
      expect(TouchpadSettings.fromJson('garbage').sensitivity, const TouchpadSettings().sensitivity);
      expect(TouchpadSettings.fromJson(null).sensitivity, const TouchpadSettings().sensitivity);
    });
  });
}
