import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../core/errors.dart';
import '../../core/logging/app_log.dart';
import '../../core/protocol/protocol.dart';

/// Message transport to the Mac. Abstract so the handshake can be tested without a network.
abstract class Transport {
  Future<void> connect(Uri uri, {Duration timeout = Proto.connectTimeout});

  /// Adds the protocol version and sends a JSON text frame.
  void send(Map<String, dynamic> message);

  /// Next inbound message; throws [ConnectionException] on timeout or close.
  Future<Map<String, dynamic>> receive({required Duration timeout});

  /// Switches from request/response mode to push mode (after the handshake).
  void listen(void Function(Map<String, dynamic>) onMessage, void Function() onClosed);

  Future<void> close();
}

class WebSocketTransport implements Transport {
  static const _tag = 'ws';
  static const _maxFrameChars = 16 * 1024;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _sub;
  final List<Map<String, dynamic>> _buffer = [];
  Completer<Map<String, dynamic>>? _waiter;
  bool _closed = true;
  void Function(Map<String, dynamic>)? _onMessage;
  void Function()? _onClosed;

  @override
  Future<void> connect(Uri uri, {Duration timeout = Proto.connectTimeout}) async {
    await close();
    _closed = false;
    _buffer.clear();
    AppLog.i(_tag, 'connecting to ${uri.host}:${uri.port}');
    try {
      final channel = IOWebSocketChannel.connect(uri, connectTimeout: timeout);
      _channel = channel;
      _sub = channel.stream.listen(_onData, onDone: _onDone, onError: (_) => _onDone(), cancelOnError: true);
      await channel.ready.timeout(timeout + const Duration(seconds: 1));
    } on TimeoutException {
      await close();
      throw ConnectionException(ConnectionFailure.unreachable);
    } catch (_) {
      await close();
      throw ConnectionException(ConnectionFailure.unreachable);
    }
  }

  void _onData(dynamic data) {
    if (data is! String || data.length > _maxFrameChars) return;
    final Object? decoded;
    try {
      decoded = jsonDecode(data);
    } on FormatException {
      return;
    }
    if (decoded is! Map<String, dynamic>) return;
    final handler = _onMessage;
    if (handler != null) {
      handler(decoded);
    } else if (_waiter != null) {
      final w = _waiter!;
      _waiter = null;
      w.complete(decoded);
    } else {
      _buffer.add(decoded);
    }
  }

  void _onDone() {
    if (_closed) return;
    _closed = true;
    final w = _waiter;
    _waiter = null;
    if (w != null && !w.isCompleted) w.completeError(ConnectionException(ConnectionFailure.closed));
    _onClosed?.call();
  }

  @override
  void send(Map<String, dynamic> message) {
    if (_closed) return;
    _channel?.sink.add(jsonEncode({'v': Proto.version, ...message}));
  }

  @override
  Future<Map<String, dynamic>> receive({required Duration timeout}) async {
    if (_buffer.isNotEmpty) return _buffer.removeAt(0);
    if (_closed) throw ConnectionException(ConnectionFailure.closed);
    final waiter = Completer<Map<String, dynamic>>();
    _waiter = waiter;
    try {
      return await waiter.future.timeout(timeout);
    } on TimeoutException {
      if (identical(_waiter, waiter)) _waiter = null;
      throw ConnectionException(ConnectionFailure.timeout);
    }
  }

  @override
  void listen(void Function(Map<String, dynamic>) onMessage, void Function() onClosed) {
    _onMessage = onMessage;
    _onClosed = onClosed;
    final pending = List<Map<String, dynamic>>.of(_buffer);
    _buffer.clear();
    pending.forEach(onMessage);
    if (_closed) onClosed();
  }

  @override
  Future<void> close() async {
    _onMessage = null;
    _onClosed = null;
    _closed = true;
    final w = _waiter;
    _waiter = null;
    if (w != null && !w.isCompleted) w.completeError(ConnectionException(ConnectionFailure.closed));
    await _sub?.cancel();
    _sub = null;
    final channel = _channel;
    _channel = null;
    if (channel != null) {
      try {
        await channel.sink.close(1000).timeout(const Duration(seconds: 1));
      } catch (_) {/* peer already gone */}
    }
  }
}
