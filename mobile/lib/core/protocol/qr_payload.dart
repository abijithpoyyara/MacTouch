import 'dart:convert';
import 'dart:typed_data';

import 'crypto.dart';
import 'protocol.dart';

enum QrError { notJson, notMacTouch, unsupportedVersion, invalidField, expired }

class QrException implements Exception {
  QrException(this.error, this.message);
  final QrError error;
  /// Safe to show to the user.
  final String message;
  @override
  String toString() => 'QrException($error)';
}

bool isPrivateIPv4(String ip) {
  final parts = ip.split('.');
  if (parts.length != 4) return false;
  final n = <int>[];
  for (final p in parts) {
    final v = int.tryParse(p);
    if (v == null || v < 0 || v > 255 || p != v.toString()) return false;
    n.add(v);
  }
  return n[0] == 10 ||
      (n[0] == 172 && n[1] >= 16 && n[1] <= 31) ||
      (n[0] == 192 && n[1] == 168) ||
      (n[0] == 169 && n[1] == 254);
}

/// What the Mac puts in its QR code. [parse] validates every field.
class QrPayload {
  QrPayload({
    required this.host,
    required this.port,
    required this.token,
    required this.expiresAt,
    required this.serverName,
    required this.serverId,
  });

  final String host;
  final int port;
  final Uint8List token;
  final DateTime expiresAt;
  final String serverName;
  final String serverId;

  static const _clockSkew = Duration(seconds: 30);
  static final _idPattern = RegExp(r'^[A-Za-z0-9_-]{8,64}$');

  /// The Mac is the authority on expiry; this only avoids a pointless round trip for stale codes.
  bool isExpired([DateTime? now]) => (now ?? DateTime.now()).isAfter(expiresAt.add(_clockSkew));

  static QrPayload parse(String raw, {DateTime? now}) {
    if (raw.length > 2048) {
      throw QrException(QrError.notMacTouch, 'This isn\u2019t a MacTouch code.');
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      throw QrException(QrError.notJson, 'This isn\u2019t a MacTouch code.');
    }
    if (decoded is! Map<String, dynamic> || decoded['app'] != Proto.appId) {
      throw QrException(QrError.notMacTouch, 'This isn\u2019t a MacTouch code.');
    }

    final v = decoded['v'];
    if (v is! int || v < 1) throw _invalid();
    if (v > Proto.version) {
      throw QrException(QrError.unsupportedVersion, 'This code is from a newer MacTouch. Update MacTouch Mobile and try again.');
    }
    if (v < Proto.version) {
      throw QrException(QrError.unsupportedVersion, 'This code is from an older MacTouch. Update MacTouch on your Mac.');
    }

    final host = decoded['host'];
    if (host is! String || !isPrivateIPv4(host)) {
      throw QrException(QrError.invalidField, 'This code points to an address outside your local network.');
    }
    final port = decoded['port'];
    if (port is! int || port < 1024 || port > 65535) throw _invalid();

    final tokenText = decoded['token'];
    final Uint8List token;
    try {
      if (tokenText is! String || tokenText.length > 64) throw const FormatException();
      token = b64uDecode(tokenText);
    } on FormatException {
      throw _invalid();
    }
    if (token.length != 32) throw _invalid();

    final exp = decoded['exp'];
    if (exp is! num) throw _invalid();
    final expiresAt = DateTime.fromMillisecondsSinceEpoch((exp * 1000).round());

    final name = decoded['name'];
    if (name is! String || name.trim().isEmpty || name.length > 64) throw _invalid();
    final id = decoded['id'];
    if (id is! String || !_idPattern.hasMatch(id)) throw _invalid();

    final payload = QrPayload(
      host: host, port: port, token: token, expiresAt: expiresAt,
      serverName: name.trim(), serverId: id,
    );
    if (payload.isExpired(now)) {
      throw QrException(QrError.expired, 'This code has expired. Look at your Mac for a fresh one.');
    }
    return payload;
  }

  static QrException _invalid() =>
      QrException(QrError.invalidField, 'This MacTouch code is damaged. Ask your Mac for a new one.');
}
