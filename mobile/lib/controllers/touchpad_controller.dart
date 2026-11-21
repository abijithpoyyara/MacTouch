import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:get/get.dart';

import '../core/haptics.dart';
import '../core/protocol/input_protocol.dart';
import '../core/shortcuts/shortcut_model.dart';
import '../core/touchpad/gesture_config.dart';
import '../core/touchpad/gesture_engine.dart';
import '../core/touchpad/input_batcher.dart';
import '../core/touchpad/touchpad_settings.dart';
import '../data/repositories/connection_repository.dart';
import '../data/services/settings_service.dart';
import 'connection_controller.dart';
import 'gesture_config_controller.dart';
import 'shortcut_controller.dart';

/// Result of sending a shortcut or system action.
enum ShortcutRunResult { sent, notConnected, invalid }

/// Glue between raw Flutter pointer events, the gesture engine, the frame batcher and the signed
/// WebSocket session. Everything that decides *what* a gesture means lives in [GestureEngine].
class TouchpadController extends GetxController {
  TouchpadController(this._repo, this._link, this._store);

  final ConnectionRepository _repo;
  final ConnectionController _link;
  final SettingsService _store;

  static const _settingsKey = 'touchpad.settings.v1';
  static const _srcLeftButton = #uiLeftButton;
  static const _srcRightButton = #uiRightButton;

  final settings = const TouchpadSettings().obs;
  final dragMode = false.obs;
  final dragLock = false.obs;
  final leftPressed = false.obs;
  final rightPressed = false.obs;

  /// Active fingers, for the touch indicators. Repainted without rebuilding widgets.
  final touches = ValueNotifier<Map<int, Offset>>(const {});
  final Map<int, Offset> _touchMap = {};

  /// Round-trip time in ms and whether the Mac has granted Accessibility (null = unknown).
  ValueListenable<int?> get rtt => _repo.rtt;
  ValueListenable<bool?> get macAccessibility => _repo.macAccessibility;

  late final ButtonHolds holds;
  late final GestureEngine engine;
  late final InputBatcher batcher;
  Worker? _linkWorker;
  Worker? _cfgWorker;
  Timer? _pump;
  final Stopwatch _sw = Stopwatch()..start();
  int _lastEventMs = 0;
  int _lastEventSw = 0;

  @override
  void onInit() {
    super.onInit();
    settings.value = _loadSettings();
    batcher = InputBatcher(onFrame: _send);
    holds = ButtonHolds(_onAction);
    engine = GestureEngine(settings: settings.value, holds: holds, emit: _onAction);
    final gestures = Get.find<GestureConfigController>();
    engine.config = gestures.config.value;
    _cfgWorker = ever<GestureConfig>(gestures.config, (c) => engine.config = c);
    _pump = Timer.periodic(const Duration(milliseconds: 30), (_) => _tick());
    _linkWorker = ever<LinkState>(_link.state, (s) {
      if (s != LinkState.connected) resetAll();
    });
  }

  @override
  void onClose() {
    _linkWorker?.dispose();
    _cfgWorker?.dispose();
    _pump?.cancel();
    touches.dispose();
    super.onClose();
  }

  bool get connected => _link.state.value == LinkState.connected;

  // MARK: Pointer events (called from a Listener, so every finger is tracked simultaneously)

  void onPointerDown(PointerDownEvent e) {
    if (!connected) return;
    _touchMap[e.pointer] = e.localPosition;
    _stamp(e.timeStamp.inMilliseconds);
    engine.pointerDown(e.pointer, e.localPosition, e.timeStamp.inMilliseconds);
    _publishTouches();
  }

  void onPointerMove(PointerMoveEvent e) {
    if (!connected || !_touchMap.containsKey(e.pointer)) return;
    _touchMap[e.pointer] = e.localPosition;
    _stamp(e.timeStamp.inMilliseconds);
    engine.pointerMove(e.pointer, e.localPosition, e.timeStamp.inMilliseconds);
    _publishTouches();
  }

  void onPointerUp(PointerUpEvent e) {
    if (_touchMap.remove(e.pointer) == null) return;
    _stamp(e.timeStamp.inMilliseconds);
    engine.pointerUp(e.pointer, e.localPosition, e.timeStamp.inMilliseconds);
    batcher.flush();
    _publishTouches();
  }

  void onPointerCancel(PointerCancelEvent e) {
    if (_touchMap.remove(e.pointer) == null) return;
    engine.pointerCancel(e.pointer);
    batcher.flush();
    _publishTouches();
  }

  void _publishTouches() => touches.value = Map<int, Offset>.of(_touchMap);

  // MARK: On-screen buttons (can be held while another finger moves on the pad)

  void pressLeft() {
    if (!connected) return;
    leftPressed.value = true;
    holds.press(Btn.left, _srcLeftButton);
  }

  void releaseLeft() {
    leftPressed.value = false;
    holds.release(Btn.left, _srcLeftButton);
    batcher.flush();
  }

  void pressRight() {
    if (!connected) return;
    rightPressed.value = true;
    holds.press(Btn.right, _srcRightButton);
  }

  void releaseRight() {
    rightPressed.value = false;
    holds.release(Btn.right, _srcRightButton);
    batcher.flush();
  }

  // MARK: Modes and settings

  void setDragMode(bool on) {
    dragMode.value = on;
    engine.setDragMode(on);
    batcher.flush();
  }

  void setDragLock(bool on) {
    dragLock.value = on;
    engine.setDragLock(on);
    batcher.flush();
  }

  void updateSettings(TouchpadSettings s, {bool persist = true}) {
    settings.value = s;
    engine.settings = s;
    if (persist) persistSettings();
  }

  void persistSettings() => _store.setString(_settingsKey, jsonEncode(settings.value.toJson()));

  TouchpadSettings _loadSettings() {
    final raw = _store.getString(_settingsKey);
    if (raw == null) return const TouchpadSettings();
    try {
      return TouchpadSettings.fromJson(jsonDecode(raw));
    } on FormatException {
      return const TouchpadSettings();
    }
  }

  // MARK: Lifecycle

  /// Leaving the screen, app paused, or connection lost: nothing may stay pressed on the Mac.
  void resetAll({bool tellMac = false}) {
    engine.reset();                        // releases every held button into the batcher
    batcher.flush();
    if (tellMac) _repo.sendInput([InputEvents.release()]);
    batcher.clear();
    _touchMap.clear();
    _publishTouches();
    leftPressed.value = false;
    rightPressed.value = false;
    dragMode.value = false;
    dragLock.value = false;
  }

  void onLeave() => resetAll(tellMac: true);

  // MARK: Output

  void _onAction(TouchpadAction action) {
    switch (action) {
      case MoveAction(:final dx, :final dy):
        batcher.addMove(dx, dy);
      case ScrollAction(:final dx, :final dy):
        batcher.addScroll(dx, dy);
      case ButtonAction(:final button, :final down, :final clickCount):
        batcher.addButton(button.name, down, clickCount);
        if (down) Haptics.click();
      case SwipeAction(:final fingers, :final direction):
        _runSwipe(fingers, direction);
    }
  }

  void _send(List<Map<String, dynamic>> events) => _repo.sendInput(events);

  // MARK: Gestures and shortcuts (Part 3)

  void _stamp(int eventMs) {
    _lastEventMs = eventMs;
    _lastEventSw = _sw.elapsedMilliseconds;
  }

  /// Drives time-based gestures (long press, scroll held back for a possible third finger). The engine's clock is the
  /// pointer-event clock, so "now" is the last event time plus the wall time that has passed since it.
  void _tick() {
    if (engine.activeTouches == 0 || !connected) return;
    engine.tick(_lastEventMs + (_sw.elapsedMilliseconds - _lastEventSw));
    batcher.flush();
  }

  void _runSwipe(int fingers, SwipeDirection direction) {
    final id = GestureId.swipe(fingers, direction);
    if (id == null) return;
    final action = Get.find<GestureConfigController>().config.value[id].action;
    if (action == null) return;
    Haptics.heavy();
    performAction(action);
  }

  /// Runs what a gesture is mapped to: a macOS system action or one of the user's shortcuts.
  ShortcutRunResult performAction(GestureAction action) {
    if (action is SystemGestureAction) return _sendEvent(InputEvents.system(action.action));
    if (action is ShortcutGestureAction) {
      final item = Get.find<ShortcutController>().byId(action.shortcutId);
      return item == null ? ShortcutRunResult.invalid : runShortcut(item);
    }
    return ShortcutRunResult.invalid;
  }

  /// Sends a shortcut from the Shortcut Center, with the user's key mapping applied.
  ShortcutRunResult runShortcut(ShortcutItem item) {
    final event = Get.find<ShortcutController>().eventFor(item);
    return event == null ? ShortcutRunResult.invalid : _sendEvent(event);
  }

  ShortcutRunResult _sendEvent(Map<String, dynamic> event) {
    if (!connected) return ShortcutRunResult.notConnected;
    batcher.addEvent(event);          // pending motion goes out first, then this, in one frame
    return ShortcutRunResult.sent;
  }
}
