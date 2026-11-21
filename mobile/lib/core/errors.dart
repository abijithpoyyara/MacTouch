enum ConnectionFailure {
  noNetwork,
  unreachable,
  timeout,
  closed,
  protocol,
  tokenExpired,
  rejected,
  declined,
  busy,
  authFailed,
  unknownDevice,
  serverMismatch,
  unsupportedVersion,
}

class ConnectionException implements Exception {
  ConnectionException(this.failure, [String? message]) : message = message ?? _defaults[failure]!;

  final ConnectionFailure failure;
  /// Safe to show to the user: says what happened and what to do.
  final String message;

  /// True when the same QR code can still be used (the Mac never saw the token).
  bool get canRetrySameCode =>
      failure == ConnectionFailure.unreachable || failure == ConnectionFailure.noNetwork;

  /// True when automatic reconnection is worth attempting.
  bool get isTransient =>
      failure == ConnectionFailure.unreachable ||
      failure == ConnectionFailure.timeout ||
      failure == ConnectionFailure.closed;

  static const _defaults = <ConnectionFailure, String>{
    ConnectionFailure.noNetwork: 'Wi-Fi is off. Connect to the same network as your Mac.',
    ConnectionFailure.unreachable: 'Couldn\u2019t reach your Mac. Check that both devices are on the same Wi-Fi and MacTouch is running.',
    ConnectionFailure.timeout: 'Your Mac didn\u2019t respond in time.',
    ConnectionFailure.closed: 'The connection to your Mac was closed.',
    ConnectionFailure.protocol: 'Your Mac sent something unexpected. Update both apps and try again.',
    ConnectionFailure.tokenExpired: 'The code expired. Scan the new code on your Mac.',
    ConnectionFailure.rejected: 'Your Mac refused the request. Scan the code again.',
    ConnectionFailure.declined: 'Pairing was declined on your Mac.',
    ConnectionFailure.busy: 'Your Mac is already connected to a phone or pairing with one.',
    ConnectionFailure.authFailed: 'Your Mac no longer trusts this phone. Pair again.',
    ConnectionFailure.unknownDevice: 'This phone isn\u2019t paired with that Mac anymore. Pair again.',
    ConnectionFailure.serverMismatch: 'That isn\u2019t the Mac you paired with. Check the QR code.',
    ConnectionFailure.unsupportedVersion: 'Your Mac uses a different MacTouch version. Update both apps.',
  };

  @override
  String toString() => 'ConnectionException($failure)';
}
