import 'dart:convert';

import 'package:get/get.dart';

import '../core/history/connection_history.dart';
import '../data/models/paired_mac.dart';
import '../data/services/settings_service.dart';
import 'connection_controller.dart';

/// Records connection events for the Devices screen by watching [ConnectionController]. It never changes connection behaviour.
class ConnectionHistoryController extends GetxController {
  ConnectionHistoryController(this._link, this._store);
  final ConnectionController _link;
  final SettingsService _store;

  static const _key = 'history.v1';

  final history = const ConnectionHistory().obs;

  Worker? _stateWorker;
  Worker? _macWorker;
  late LinkState _lastState;
  PairedMac? _lastMac;

  @override
  void onInit() {
    super.onInit();
    final raw = _store.getString(_key);
    if (raw != null) {
      try {
        history.value = ConnectionHistory.fromJson(jsonDecode(raw));
      } on FormatException {
        history.value = const ConnectionHistory();
      }
    }
    _lastState = _link.state.value;
    _lastMac = _link.mac.value;
    _stateWorker = ever<LinkState>(_link.state, _onState);
    _macWorker = ever<PairedMac?>(_link.mac, _onMac);
  }

  @override
  void onClose() {
    _stateWorker?.dispose();
    _macWorker?.dispose();
    super.onClose();
  }

  void _onState(LinkState state) {
    final prev = _lastState;
    if (state == prev) return;
    _lastState = state;
    final name = _link.mac.value?.name ?? _lastMac?.name ?? 'Mac';
    if (state == LinkState.connected) {
      _record(HistoryKind.connected, name);
    } else if (prev == LinkState.connected && state == LinkState.idle) {
      _record(HistoryKind.disconnected, name);
    } else if (prev == LinkState.connected) {
      _record(HistoryKind.lost, name, _link.message.value);
    } else if (state == LinkState.failed) {
      _record(HistoryKind.failed, name, _link.message.value);
    }
  }

  void _onMac(PairedMac? mac) {
    final prev = _lastMac;
    _lastMac = mac;
    if (prev == null && mac != null) {
      _record(HistoryKind.paired, mac.name);
    } else if (prev != null && mac == null) {
      _record(HistoryKind.forgotten, prev.name);
    }
  }

  void _record(HistoryKind kind, String device, [String? detail]) {
    history.value = history.value.add(HistoryEntry(
      atMs: DateTime.now().millisecondsSinceEpoch,
      kind: kind,
      device: device,
      detail: detail,
    ));
    _save();
  }

  void clear() {
    history.value = const ConnectionHistory();
    _save();
  }

  void _save() => _store.setString(_key, jsonEncode(history.value.toJson()));
}
