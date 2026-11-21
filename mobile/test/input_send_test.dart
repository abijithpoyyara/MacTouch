import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mactouch_mobile/core/protocol/crypto.dart';
import 'package:mactouch_mobile/core/protocol/input_protocol.dart';
import 'package:mactouch_mobile/core/protocol/qr_payload.dart';
import 'package:mactouch_mobile/data/repositories/connection_repository.dart';
import 'package:mactouch_mobile/data/repositories/identity_repository.dart';
import 'package:mactouch_mobile/data/repositories/paired_mac_repository.dart';
import 'package:mactouch_mobile/data/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:typed_data';

import 'connection_repository_test.dart' show FakeMac, MemorySecureStore, TestIdentity;

class RecordingMac extends FakeMac {
  RecordingMac({required super.token});
  final sent = <Map<String, dynamic>>[];
  @override
  void send(Map<String, dynamic> m) {
    sent.add(m);
    super.send(m);
  }
}

void main() {
  final token = List<int>.generate(32, (i) => i);
  late RecordingMac mac;
  late ConnectionRepository repo;
  late IdentityRepository identity;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService(await SharedPreferences.getInstance());
    identity = TestIdentity(settings);
    mac = RecordingMac(token: token);
    repo = ConnectionRepository(mac, PairedMacRepository(settings, MemorySecureStore()), identity);
  });

  QrPayload qr() => QrPayload(
        host: '192.168.1.20', port: 48500, token: Uint8List.fromList(token),
        expiresAt: DateTime.now().add(const Duration(minutes: 2)), serverName: 'Mac mini', serverId: 'server-0123456789',
      );

  test('input is refused before a session exists', () {
    expect(repo.sendInput([InputEvents.move(1, 1)]), isFalse);
    expect(mac.sent, isEmpty);
  });

  test('frames are signed with the session key, sequenced, timestamped and verifiable', () async {
    await repo.pair(qr());
    final deviceId = (mac.sent.firstWhere((m) => m['type'] == 'pair_request'))['deviceId'] as String;
    final cn = (mac.sent.firstWhere((m) => m['type'] == 'pair_request'))['clientNonce'] as String;
    final secret = mac.secret!;
    final key = InputCrypto.sessionKey(secret: secret, clientNonce: cn, serverNonce: FakeMac.serverNonce);
    expect(deviceId, isNotEmpty);

    expect(repo.sendInput([InputEvents.move(5, -3), InputEvents.button('left', true)]), isTrue);
    expect(repo.sendInput([InputEvents.scroll(0, 4)]), isTrue);

    final frames = mac.sent.where((m) => m['type'] == 'input').toList();
    expect(frames.length, 2);
    expect(frames.map((f) => f['seq']), [1, 2]);
    for (final f in frames) {
      final body = f['body'] as String;
      expect(b64uEncode(InputCrypto.inputMac(key, f['seq'] as int, body)), f['mac'], reason: 'MAC covers seq and the exact body');
      expect(f['t'], isA<int>());
      expect(f['v'], 1);
    }
    expect(jsonDecode(frames.first['body'] as String), {
      'ev': [
        {'e': 'move', 'dx': 5, 'dy': -3},
        {'e': 'btn', 'b': 'left', 's': 'down'},
      ]
    });
    expect((frames.last['t'] as int) >= (frames.first['t'] as int), isTrue, reason: 'timestamps never go backwards');
    await repo.disconnect(notifyPeer: false);
  });

  test('empty frames are never sent, and nothing can be sent after disconnect', () async {
    await repo.pair(qr());
    expect(repo.sendInput([]), isFalse);
    await repo.disconnect(notifyPeer: false);
    expect(repo.sendInput([InputEvents.move(1, 1)]), isFalse);
    expect(mac.sent.where((m) => m['type'] == 'input'), isEmpty);
  });

  test('sequence numbers restart for each new session', () async {
    final paired = await repo.pair(qr());
    repo.sendInput([InputEvents.move(1, 1)]);
    await repo.disconnect(notifyPeer: false);
    await repo.reconnect(paired);
    repo.sendInput([InputEvents.move(1, 1)]);
    final seqs = mac.sent.where((m) => m['type'] == 'input').map((m) => m['seq']).toList();
    expect(seqs, [1, 1]);
    await repo.disconnect(notifyPeer: false);
  });
}
