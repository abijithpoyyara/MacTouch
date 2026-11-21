import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mactouch_mobile/core/errors.dart';
import 'package:mactouch_mobile/core/protocol/crypto.dart';
import 'package:mactouch_mobile/core/protocol/qr_payload.dart';
import 'package:mactouch_mobile/data/repositories/connection_repository.dart';
import 'package:mactouch_mobile/data/repositories/identity_repository.dart';
import 'package:mactouch_mobile/data/repositories/paired_mac_repository.dart';
import 'package:mactouch_mobile/data/services/secure_store_service.dart';
import 'package:mactouch_mobile/data/services/settings_service.dart';
import 'package:mactouch_mobile/data/services/transport.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MemorySecureStore extends SecureStoreService {
  final items = <String, String>{};
  @override
  Future<void> write(String key, String value) async => items[key] = value;
  @override
  Future<String?> read(String key) async => items[key];
  @override
  Future<void> delete(String key) async => items.remove(key);
}

class TestIdentity extends IdentityRepository {
  TestIdentity(super.settings);
  @override
  Future<String> deviceName() async => 'Test phone';
}

/// A scripted Mac speaking protocol v1 (mirrors protocol/tools/reference.mjs).
class FakeMac implements Transport {
  FakeMac({required this.token, this.serverId = 'server-0123456789', this.rejectWith, this.corruptServerProof = false});
  final List<int> token;
  final String serverId;
  final String? rejectWith;
  final bool corruptServerProof;
  static const serverNonce = 'c2VydmVyLW5vbmNlLTAwMQ';
  List<int>? secret;
  final _inbox = <Map<String, dynamic>>[];
  bool closed = false;

  @override
  Future<void> connect(Uri uri, {Duration timeout = const Duration(seconds: 1)}) async {
    closed = false;
    _inbox
      ..clear()
      ..add({'type': 'challenge', 'v': 1, 'serverNonce': serverNonce, 'serverId': serverId, 'serverName': 'Mac mini'});
  }

  @override
  void send(Map<String, dynamic> m) {
    final id = m['deviceId'] as String?;
    final cn = m['clientNonce'] as String?;
    switch (m['type']) {
      case 'pair_request':
        if (rejectWith != null) {
          _inbox.add({'type': 'pair_rejected', 'reason': rejectWith});
          return;
        }
        final expected = b64uEncode(Handshake.pairProof(token: token, deviceId: id!, clientNonce: cn!, serverNonce: serverNonce));
        if (expected != m['proof']) {
          _inbox.add({'type': 'pair_rejected', 'reason': 'invalid_proof'});
          return;
        }
        secret = Handshake.deriveSecret(token: token, deviceId: id, clientNonce: cn, serverNonce: serverNonce);
        _inbox.add({'type': 'pair_pending'});
        _inbox.add({'type': 'pair_accepted', 'serverProof': _proof(cn)});
      case 'auth':
        final expected = b64uEncode(Handshake.authProof(secret: secret!, deviceId: id!, clientNonce: cn!, serverNonce: serverNonce));
        _inbox.add(expected == m['proof']
            ? {'type': 'auth_ok', 'serverProof': _proof(cn)}
            : {'type': 'auth_failed', 'reason': 'invalid_proof'});
      default:
        break;
    }
  }

  String _proof(String cn) {
    final p = Handshake.serverProof(secret: secret!, clientNonce: cn, serverNonce: serverNonce);
    return b64uEncode(corruptServerProof ? List<int>.filled(p.length, 0) : p);
  }

  @override
  Future<Map<String, dynamic>> receive({required Duration timeout}) async {
    if (_inbox.isEmpty) throw ConnectionException(ConnectionFailure.timeout);
    return _inbox.removeAt(0);
  }

  @override
  void listen(void Function(Map<String, dynamic>) onMessage, void Function() onClosed) {}

  @override
  Future<void> close() async => closed = true;
}

QrPayload _qr(List<int> token, {String id = 'server-0123456789'}) => QrPayload(
      host: '192.168.1.20', port: 48500, token: Uint8List.fromList(token),
      expiresAt: DateTime.now().add(const Duration(minutes: 2)), serverName: 'Mac mini', serverId: id,
    );

void main() {
  late PairedMacRepository macs;
  late MemorySecureStore secure;
  late IdentityRepository identity;
  final token = List<int>.generate(32, (i) => i);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService(await SharedPreferences.getInstance());
    secure = MemorySecureStore();
    macs = PairedMacRepository(settings, secure);
    identity = TestIdentity(settings);
  });

  test('pairs, stores the derived secret, then reconnects with it', () async {
    final mac = FakeMac(token: token);
    final repo = ConnectionRepository(mac, macs, identity);
    final steps = <PairingStep>[];

    final paired = await repo.pair(_qr(token), onStep: steps.add);

    expect(steps, [PairingStep.connecting, PairingStep.verifying, PairingStep.awaitingApproval]);
    expect(paired.name, 'Mac mini');
    expect(macs.load()?.serverId, 'server-0123456789');
    final stored = await macs.loadSecret(paired.serverId);
    expect(stored, mac.secret, reason: 'secret derived locally, never transmitted');
    expect(repo.hasSession, isTrue);

    await repo.disconnect(notifyPeer: false);
    expect(repo.hasSession, isFalse);

    final again = await repo.reconnect(paired);
    expect(again.serverId, paired.serverId);
    expect(repo.hasSession, isTrue);
    await repo.disconnect(notifyPeer: false);
  });

  test('refuses a Mac whose identity differs from the QR code', () async {
    final repo = ConnectionRepository(FakeMac(token: token, serverId: 'someone-else-1'), macs, identity);
    await expectLater(
      repo.pair(_qr(token)),
      throwsA(isA<ConnectionException>().having((e) => e.failure, 'failure', ConnectionFailure.serverMismatch)),
    );
    expect(macs.load(), isNull);
  });

  test('maps Mac rejections to user-facing failures', () async {
    for (final entry in {
      'token_expired': ConnectionFailure.tokenExpired,
      'declined': ConnectionFailure.declined,
      'busy': ConnectionFailure.busy,
    }.entries) {
      final repo = ConnectionRepository(FakeMac(token: token, rejectWith: entry.key), macs, identity);
      await expectLater(
        repo.pair(_qr(token)),
        throwsA(isA<ConnectionException>().having((e) => e.failure, 'failure', entry.value)),
      );
    }
    expect(macs.load(), isNull);
  });

  test('rejects a Mac that cannot prove it knows the token', () async {
    final repo = ConnectionRepository(FakeMac(token: token, corruptServerProof: true), macs, identity);
    await expectLater(
      repo.pair(_qr(token)),
      throwsA(isA<ConnectionException>().having((e) => e.failure, 'failure', ConnectionFailure.protocol)),
    );
    expect(macs.load(), isNull, reason: 'nothing may be stored after a failed identity check');
    expect(secure.items, isEmpty);
  });

  test('reconnect without a stored secret asks the user to pair again', () async {
    final repo = ConnectionRepository(FakeMac(token: token), macs, identity);
    final orphan = (await ConnectionRepository(FakeMac(token: token), macs, identity).pair(_qr(token)));
    await macs.clear(orphan.serverId);
    await expectLater(
      repo.reconnect(orphan),
      throwsA(isA<ConnectionException>().having((e) => e.failure, 'failure', ConnectionFailure.unknownDevice)),
    );
  });
}
