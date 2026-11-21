import 'dart:async';

import 'package:get/get.dart';

import '../app/routes.dart';
import '../core/errors.dart';
import '../core/logging/app_log.dart';
import '../core/protocol/qr_payload.dart';
import '../data/repositories/connection_repository.dart';
import 'connection_controller.dart';

enum PairingPhase { idle, connecting, verifying, awaitingApproval, success, failed }

class PairingController extends GetxController {
  PairingController(this._repo, this._connection);

  final ConnectionRepository _repo;
  final ConnectionController _connection;

  final phase = PairingPhase.idle.obs;
  final failure = Rxn<ConnectionException>();
  /// Shown on the scanner screen while scanning continues (wrong code, expired code, ...).
  final scanError = RxnString();

  QrPayload? _payload;
  bool _busy = false;
  Timer? _scanErrorTimer;

  String get serverName => _payload?.serverName ?? 'your Mac';

  /// Called by the scanner for every detected barcode.
  Future<void> onScan(String? raw) async {
    if (_busy || raw == null) return;
    final QrPayload payload;
    try {
      payload = QrPayload.parse(raw);
    } on QrException catch (e) {
      _showScanError(e.message);
      return;
    }
    _busy = true;
    _payload = payload;
    scanError.value = null;
    Get.offNamed(Routes.pairing);
    await _run();
  }

  void _showScanError(String text) {
    scanError.value = text;
    _scanErrorTimer?.cancel();
    _scanErrorTimer = Timer(const Duration(seconds: 3), () => scanError.value = null);
  }

  Future<void> _run() async {
    final payload = _payload;
    if (payload == null) return;
    failure.value = null;
    phase.value = PairingPhase.connecting;
    try {
      final paired = await _repo.pair(payload, onStep: (step) {
        phase.value = switch (step) {
          PairingStep.connecting => PairingPhase.connecting,
          PairingStep.verifying => PairingPhase.verifying,
          PairingStep.awaitingApproval => PairingPhase.awaitingApproval,
        };
      });
      _connection.adoptPairing(paired);
      phase.value = PairingPhase.success;
      await Future<void>.delayed(const Duration(milliseconds: 900));
      Get.offAllNamed(Routes.connected);
    } on ConnectionException catch (e) {
      AppLog.w('pairing', 'failed: ${e.failure.name}');
      failure.value = e;
      phase.value = PairingPhase.failed;
    } catch (e) {
      AppLog.e('pairing', 'unexpected: ${e.runtimeType}');
      failure.value = ConnectionException(ConnectionFailure.protocol);
      phase.value = PairingPhase.failed;
    } finally {
      _busy = false;
    }
  }

  /// Only offered when the Mac never saw the token (network failure before the handshake).
  void retrySameCode() {
    final payload = _payload;
    if (payload == null || _busy || payload.isExpired()) {
      scanAgain();
      return;
    }
    _busy = true;
    unawaited(_run());
  }

  /// Opens the scanner from the welcome screen.
  void startScan() {
    _busy = false;
    _payload = null;
    failure.value = null;
    phase.value = PairingPhase.idle;
    scanError.value = null;
    Get.toNamed(Routes.scan);
  }

  /// Replaces the current screen with the scanner (used after a failed pairing).
  void scanAgain() {
    _busy = false;
    _payload = null;
    failure.value = null;
    phase.value = PairingPhase.idle;
    Get.offNamed(Routes.scan);
  }

  void cancel() {
    unawaited(_repo.disconnect(notifyPeer: false));
    _busy = false;
    _payload = null;
    phase.value = PairingPhase.idle;
    Get.offAllNamed(Routes.welcome);
  }

  @override
  void onClose() {
    _scanErrorTimer?.cancel();
    super.onClose();
  }
}
