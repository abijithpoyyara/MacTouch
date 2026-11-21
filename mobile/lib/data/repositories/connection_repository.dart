import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../core/errors.dart';
import '../../core/logging/app_log.dart';
import '../../core/protocol/crypto.dart';
import '../../core/protocol/input_protocol.dart';
import '../../core/protocol/protocol.dart';
import '../../core/protocol/qr_payload.dart';
import '../models/paired_mac.dart';
import '../services/transport.dart';
import 'identity_repository.dart';
import 'paired_mac_repository.dart';

enum PairingStep { connecting, verifying, awaitingApproval }

enum SessionEvent { lost }

/// Runs the pairing and reconnect handshakes and keeps the authenticated session alive.
class ConnectionRepository {
  ConnectionRepository(this._transport, this._macs, this._identity);

  static const _tag = 'conn';
  final Transport _transport;
  final PairedMacRepository _macs;
  final IdentityRepository _identity;

  final _events = StreamController<SessionEvent>.broadcast();
  Stream<SessionEvent> get events => _events.stream;

  Timer? _heartbeat;
  DateTime _lastInbound = DateTime.now();
  bool _sessionActive = false;
  bool get hasSession => _sessionActive;

  // Part 2: signed input session state
  List<int>? _sessionKey;
  int _seq = 0;
  final Stopwatch _clock = Stopwatch();

  /// Round-trip time to the Mac in ms (null when unknown) and whether the Mac has granted Accessibility.
  final ValueNotifier<int?> rtt = ValueNotifier<int?>(null);
  final ValueNotifier<bool?> macAccessibility = ValueNotifier<bool?>(null);

  /// First-time pairing from a scanned QR code.
  Future<PairedMac> pair(QrPayload qr, {void Function(PairingStep step)? onStep}) async {
    await disconnect(notifyPeer: false);
    onStep?.call(PairingStep.connecting);
    await _transport.connect(_uri(qr.host, qr.port));
    try {
      final serverNonce = await _readChallenge(expectedServerId: qr.serverId);
      onStep?.call(PairingStep.verifying);

      final deviceId = await _identity.deviceId();
      final clientNonce = b64uEncode(randomBytes(16));
      _transport.send({
        'type': MsgType.pairRequest,
        'deviceId': deviceId,
        'deviceName': await _identity.deviceName(),
        'clientNonce': clientNonce,
        'proof': b64uEncode(Handshake.pairProof(
            token: qr.token, deviceId: deviceId, clientNonce: clientNonce, serverNonce: serverNonce)),
      });

      var wait = Proto.challengeTimeout;   // the Mac answers "pending" quickly; approval can take a while
      for (;;) {
        final m = await _transport.receive(timeout: wait);
        switch (m['type']) {
          case MsgType.pairPending:
            onStep?.call(PairingStep.awaitingApproval);
            wait = Proto.approvalTimeout;
          case MsgType.pairAccepted:
            final secret = Handshake.deriveSecret(
                token: qr.token, deviceId: deviceId, clientNonce: clientNonce, serverNonce: serverNonce);
            _verifyServerProof(m, secret, clientNonce, serverNonce);
            final now = DateTime.now();
            final mac = PairedMac(
                serverId: qr.serverId, name: qr.serverName, host: qr.host, port: qr.port,
                pairedAt: now, lastConnectedAt: now);
            await _macs.save(mac, secret);
            _startSession(secret: secret, clientNonce: clientNonce, serverNonce: serverNonce, accessibility: m['accessibility']);
            AppLog.i(_tag, 'paired with ${AppLog.shortId(mac.serverId)}');
            return mac;
          case MsgType.pairRejected:
            throw _fromReason(m['reason']);
          default:
            throw ConnectionException(ConnectionFailure.protocol);
        }
      }
    } catch (_) {
      await _transport.close();
      rethrow;
    }
  }

  /// Reconnects to a previously paired Mac using the stored secret.
  Future<PairedMac> reconnect(PairedMac mac) async {
    final secret = await _macs.loadSecret(mac.serverId);
    if (secret == null) throw ConnectionException(ConnectionFailure.unknownDevice);
    await disconnect(notifyPeer: false);
    await _transport.connect(_uri(mac.host, mac.port));
    try {
      final serverNonce = await _readChallenge(expectedServerId: mac.serverId);
      final deviceId = await _identity.deviceId();
      final clientNonce = b64uEncode(randomBytes(16));
      _transport.send({
        'type': MsgType.auth,
        'deviceId': deviceId,
        'clientNonce': clientNonce,
        'proof': b64uEncode(Handshake.authProof(
            secret: secret, deviceId: deviceId, clientNonce: clientNonce, serverNonce: serverNonce)),
      });
      final m = await _transport.receive(timeout: Proto.challengeTimeout);
      switch (m['type']) {
        case MsgType.authOk:
          _verifyServerProof(m, secret, clientNonce, serverNonce);
          final updated = mac.copyWith(lastConnectedAt: DateTime.now());
          await _macs.update(updated);
          _startSession(secret: secret, clientNonce: clientNonce, serverNonce: serverNonce, accessibility: m['accessibility']);
          AppLog.i(_tag, 'reconnected to ${AppLog.shortId(mac.serverId)}');
          return updated;
        case MsgType.authFailed:
          throw _fromReason(m['reason'], duringAuth: true);
        default:
          throw ConnectionException(ConnectionFailure.protocol);
      }
    } catch (_) {
      await _transport.close();
      rethrow;
    }
  }

  Future<void> disconnect({bool notifyPeer = true}) async {
    final wasActive = _sessionActive;
    _sessionActive = false;
    _heartbeat?.cancel();
    _heartbeat = null;
    if (wasActive && notifyPeer) _transport.send({'type': MsgType.disconnect});
    _resetSession();
    await _transport.close();
  }

  // MARK: Internals

  Uri _uri(String host, int port) => Uri(scheme: 'ws', host: host, port: port, path: '/');

  Future<String> _readChallenge({required String expectedServerId}) async {
    final m = await _transport.receive(timeout: Proto.challengeTimeout);
    if (m['type'] != MsgType.challenge) throw ConnectionException(ConnectionFailure.protocol);
    final version = m['v'];
    if (version is int && version != Proto.version) throw ConnectionException(ConnectionFailure.unsupportedVersion);
    final serverId = m['serverId'], nonce = m['serverNonce'];
    if (serverId is! String || nonce is! String || nonce.length < 16 || nonce.length > 64) {
      throw ConnectionException(ConnectionFailure.protocol);
    }
    if (serverId != expectedServerId) throw ConnectionException(ConnectionFailure.serverMismatch);
    return nonce;
  }

  void _verifyServerProof(Map<String, dynamic> m, List<int> secret, String clientNonce, String serverNonce) {
    final text = m['serverProof'];
    Uint8List? got;
    if (text is String) {
      try {
        got = b64uDecode(text);
      } on FormatException {
        got = null;
      }
    }
    final expected = Handshake.serverProof(secret: secret, clientNonce: clientNonce, serverNonce: serverNonce);
    if (got == null || !constantTimeEquals(expected, got)) {
      throw ConnectionException(ConnectionFailure.protocol, 'Your Mac couldn\u2019t prove its identity. Don\u2019t continue; check the QR code.');
    }
  }

  ConnectionException _fromReason(Object? reason, {bool duringAuth = false}) {
    switch (reason) {
      case Reason.tokenExpired:
        return ConnectionException(ConnectionFailure.tokenExpired);
      case Reason.declined:
        return ConnectionException(ConnectionFailure.declined);
      case Reason.busy:
        return ConnectionException(ConnectionFailure.busy);
      case Reason.timeout:
        return ConnectionException(ConnectionFailure.timeout, 'Your Mac didn\u2019t approve the pairing in time. Scan a new code.');
      case Reason.unknownDevice:
        return ConnectionException(ConnectionFailure.unknownDevice);
      case Reason.invalidProof:
        return ConnectionException(duringAuth ? ConnectionFailure.authFailed : ConnectionFailure.rejected);
      default:
        return ConnectionException(duringAuth ? ConnectionFailure.authFailed : ConnectionFailure.rejected);
    }
  }

  void _startSession({
    required List<int> secret,
    required String clientNonce,
    required String serverNonce,
    Object? accessibility,
  }) {
    _sessionActive = true;
    _lastInbound = DateTime.now();
    _sessionKey = InputCrypto.sessionKey(secret: secret, clientNonce: clientNonce, serverNonce: serverNonce);
    _seq = 0;
    _clock
      ..reset()
      ..start();
    macAccessibility.value = accessibility is bool ? accessibility : null;
    _transport.listen(_onMessage, () => _lost('socket closed'));
    _heartbeat?.cancel();
    _transport.send({'type': MsgType.ping, 't': _clock.elapsedMilliseconds});   // first latency sample right away
    _heartbeat = Timer.periodic(Proto.heartbeatInterval, (_) {
      if (DateTime.now().difference(_lastInbound) > Proto.heartbeatDeadline) {
        _lost('heartbeat timeout');
      } else {
        _transport.send({'type': MsgType.ping, 't': _clock.elapsedMilliseconds});
      }
    });
  }

  void _onMessage(Map<String, dynamic> m) {
    _lastInbound = DateTime.now();
    switch (m['type']) {
      case MsgType.pong:
        final t = m['t'];
        if (t is int) rtt.value = (_clock.elapsedMilliseconds - t).clamp(0, 60000).toInt();
      case InputMsg.status:
        final allowed = m['accessibility'];
        if (allowed is bool) macAccessibility.value = allowed;
      case MsgType.disconnect:
        _lost('Mac disconnected');
      case MsgType.error:
        AppLog.w(_tag, 'Mac reported error: ${m['code'] ?? m['reason']}');
      default:
        break;
    }
  }

  /// Sends one signed input frame (sequence number, timestamp, HMAC). False when there is no live session.
  bool sendInput(List<Map<String, dynamic>> events) {
    final key = _sessionKey;
    if (key == null || !_sessionActive || events.isEmpty) return false;
    final body = jsonEncode({'ev': events});
    final seq = ++_seq;
    _transport.send({
      'type': InputMsg.input,
      'seq': seq,
      't': _clock.elapsedMilliseconds,
      'body': body,
      'mac': b64uEncode(InputCrypto.inputMac(key, seq, body)),
    });
    return true;
  }

  void _resetSession() {
    _sessionKey = null;
    rtt.value = null;
    macAccessibility.value = null;
  }

  void _lost(String why) {
    if (!_sessionActive) return;
    AppLog.w(_tag, 'session lost: $why');
    _sessionActive = false;
    _resetSession();
    _heartbeat?.cancel();
    _heartbeat = null;
    unawaited(_transport.close());
    _events.add(SessionEvent.lost);
  }
}
