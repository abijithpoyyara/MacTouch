import 'dart:async';

import 'package:get/get.dart';

import '../app/routes.dart';
import '../core/errors.dart';
import '../core/logging/app_log.dart';
import '../data/models/paired_mac.dart';
import '../data/repositories/connection_repository.dart';
import '../data/repositories/paired_mac_repository.dart';
import '../data/services/network_monitor_service.dart';

enum LinkState { idle, connecting, connected, reconnecting, offline, failed }

/// Owns the long-lived connection to the paired Mac: auto-reconnect, Wi-Fi changes, disconnect, forget.
class ConnectionController extends GetxController {
  ConnectionController(this._repo, this._macs, this._network);

  static const _tag = 'link';
  static const _backoff = [Duration(seconds: 1), Duration(seconds: 2), Duration(seconds: 4), Duration(seconds: 8), Duration(seconds: 15)];

  final ConnectionRepository _repo;
  final PairedMacRepository _macs;
  final NetworkMonitorService _network;

  final state = LinkState.idle.obs;
  final mac = Rxn<PairedMac>();
  final message = RxnString();

  StreamSubscription<SessionEvent>? _lostSub;
  StreamSubscription<NetworkStatus>? _netSub;
  Timer? _retryTimer;
  int _attempt = 0;
  bool _online = true;
  bool _busy = false;

  @override
  void onInit() {
    super.onInit();
    mac.value = _macs.load();
    _lostSub = _repo.events.listen((_) => _onSessionLost());
    _netSub = _network.changes.listen(_onNetworkChanged);
    unawaited(_startup());
  }

  Future<void> _startup() async {
    _online = (await _network.current()).online;
    if (mac.value != null) await connectSaved(userInitiated: false);
  }

  @override
  void onClose() {
    _retryTimer?.cancel();
    unawaited(_lostSub?.cancel());
    unawaited(_netSub?.cancel());
    super.onClose();
  }

  bool get isConnected => state.value == LinkState.connected;

  /// Called by the pairing flow once the Mac approved this phone.
  void adoptPairing(PairedMac paired) {
    _retryTimer?.cancel();
    _attempt = 0;
    mac.value = paired;
    message.value = null;
    state.value = LinkState.connected;
  }

  /// Connects to the saved Mac. [userInitiated] attempts surface errors and navigate on success.
  Future<void> connectSaved({bool userInitiated = true}) async {
    final target = mac.value;
    if (target == null || _busy) return;
    if (!_online) {
      state.value = LinkState.offline;
      message.value = ConnectionException(ConnectionFailure.noNetwork).message;
      return;
    }
    _busy = true;
    _retryTimer?.cancel();
    state.value = _attempt > 0 ? LinkState.reconnecting : LinkState.connecting;
    message.value = null;
    try {
      mac.value = await _repo.reconnect(target);
      _attempt = 0;
      state.value = LinkState.connected;
      if (Get.currentRoute == Routes.welcome) Get.offAllNamed(Routes.connected);
    } on ConnectionException catch (e) {
      AppLog.w(_tag, 'connect failed: ${e.failure.name}');
      _onConnectFailed(e, userInitiated: userInitiated);
    } finally {
      _busy = false;
    }
  }

  void _onConnectFailed(ConnectionException e, {required bool userInitiated}) {
    message.value = e.message;
    if (e.isTransient && _attempt < _backoff.length && !(userInitiated && _attempt == 0)) {
      state.value = LinkState.reconnecting;
      final delay = _backoff[_attempt++];
      _retryTimer = Timer(delay, () => unawaited(connectSaved(userInitiated: false)));
    } else {
      _attempt = 0;
      state.value = LinkState.failed;
    }
  }

  void _onSessionLost() {
    if (state.value != LinkState.connected) return;
    _attempt = 0;
    message.value = 'Connection lost. Reconnecting\u2026';
    state.value = _online ? LinkState.reconnecting : LinkState.offline;
    if (_online) unawaited(connectSaved(userInitiated: false));
  }

  void _onNetworkChanged(NetworkStatus status) {
    final wasOnline = _online;
    _online = status.online;
    AppLog.i(_tag, 'network ${status.signature} online=${status.online}');
    if (mac.value == null) return;

    if (!status.online) {
      if (state.value == LinkState.connected || state.value == LinkState.reconnecting || state.value == LinkState.connecting) {
        _retryTimer?.cancel();
        unawaited(_repo.disconnect(notifyPeer: false));
        message.value = ConnectionException(ConnectionFailure.noNetwork).message;
        state.value = LinkState.offline;
      }
      return;
    }
    // Back online, or moved to a different kind of network: the old socket is dead or about to be.
    final shouldReconnect = !wasOnline || state.value == LinkState.connected;
    if (shouldReconnect && state.value != LinkState.idle) {
      _retryTimer?.cancel();
      _attempt = 0;
      unawaited(_repo.disconnect(notifyPeer: false));
      state.value = LinkState.reconnecting;
      unawaited(connectSaved(userInitiated: false));
    }
  }

  /// Ends the session but keeps the pairing.
  Future<void> disconnect() async {
    _retryTimer?.cancel();
    _attempt = 0;
    await _repo.disconnect();
    message.value = null;
    state.value = LinkState.idle;
    Get.offAllNamed(Routes.welcome);
  }

  /// Removes the pairing and its stored secret.
  Future<void> forget() async {
    final current = mac.value;
    _retryTimer?.cancel();
    await _repo.disconnect();
    if (current != null) await _macs.clear(current.serverId);
    mac.value = null;
    message.value = null;
    state.value = LinkState.idle;
    Get.offAllNamed(Routes.welcome);
  }
}
