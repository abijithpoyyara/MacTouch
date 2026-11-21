/// Wire-protocol constants. Keep in sync with protocol/PROTOCOL.md and desktop/Sources/MacTouchCore/Protocol.swift.
abstract final class Proto {
  static const int version = 1;
  static const String appId = 'mactouch';
  static const Duration connectTimeout = Duration(seconds: 6);
  static const Duration challengeTimeout = Duration(seconds: 8);
  static const Duration approvalTimeout = Duration(seconds: 75);
  static const Duration heartbeatInterval = Duration(seconds: 10);
  static const Duration heartbeatDeadline = Duration(seconds: 25);
}

abstract final class MsgType {
  static const challenge = 'challenge';
  static const pairRequest = 'pair_request';
  static const pairPending = 'pair_pending';
  static const pairAccepted = 'pair_accepted';
  static const pairRejected = 'pair_rejected';
  static const auth = 'auth';
  static const authOk = 'auth_ok';
  static const authFailed = 'auth_failed';
  static const ping = 'ping';
  static const pong = 'pong';
  static const disconnect = 'disconnect';
  static const error = 'error';
}

abstract final class Reason {
  static const tokenExpired = 'token_expired';
  static const invalidProof = 'invalid_proof';
  static const declined = 'declined';
  static const busy = 'busy';
  static const timeout = 'timeout';
  static const unknownDevice = 'unknown_device';
}
