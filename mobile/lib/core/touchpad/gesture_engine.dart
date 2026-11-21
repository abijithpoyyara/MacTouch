import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'gesture_config.dart';
import 'touchpad_settings.dart';

export 'gesture_config.dart' show SwipeDirection;

enum Btn { left, right }

/// What the engine asks the app to do. Integer pixels, subpixel remainders are carried.
sealed class TouchpadAction {
  const TouchpadAction();
}

class MoveAction extends TouchpadAction {
  const MoveAction(this.dx, this.dy);
  final int dx, dy;
}

/// Positive `dy` = content moves down (the "natural" direction when the fingers move down).
class ScrollAction extends TouchpadAction {
  const ScrollAction(this.dx, this.dy);
  final int dx, dy;
}

class ButtonAction extends TouchpadAction {
  const ButtonAction(this.button, this.down, this.clickCount);
  final Btn button;
  final bool down;
  final int clickCount;
}

/// A completed 3- or 4-finger swipe. What it does is decided by the app from the user's gesture mapping.
class SwipeAction extends TouchpadAction {
  const SwipeAction(this.fingers, this.direction);
  final int fingers;
  final SwipeDirection direction;
}

/// Thresholds, in logical pixels / milliseconds.
abstract final class Tuning {
  static const maxFingers = 4;
  static const tapSlopPx = 10.0;
  static const tapTimeoutMs = 250;
  static const doubleTapWindowMs = 320;
  static const doubleTapRadiusPx = 40.0;
  static const moveDeadzonePx = 3.0;
  static const scrollSlopPx = 6.0;
  static const twoFingerTapTimeoutMs = 300;
  static const twoFingerTapSlopPx = 14.0;

  /// Two-finger scrolling waits this long after the second finger lands, so a third finger that is
  /// about to land can claim the gesture as a swipe instead. Movement in the meantime is kept, not lost.
  static const scrollStartDelayMs = 60;

  /// A swipe's direction is not decided before the fingers have moved this far.
  static const swipeDecisionPx = 14.0;

  /// Movement along one axis must exceed the other axis by this factor, otherwise it is ambiguous (diagonal).
  static const swipeDominance = 1.5;

  /// Longest time from the first real movement to reaching the swipe distance. Slower = not a swipe.
  static const swipeMaxDurationMs = 900;

  /// Every finger must have moved at least this fraction of the distance in the swipe direction.
  static const swipeAgreeFraction = 0.4;
  static const swipeStartMovePx = 4.0;
}

/// Direction of a movement vector, or null while it is too short or too diagonal to call.
SwipeDirection? detectSwipe(Offset d, {double minDistance = Tuning.swipeDecisionPx, double dominance = Tuning.swipeDominance}) {
  if (d.distance < minDistance) return null;
  final ax = d.dx.abs(), ay = d.dy.abs();
  if (ay >= ax * dominance) return d.dy < 0 ? SwipeDirection.up : SwipeDirection.down;
  if (ax >= ay * dominance) return d.dx < 0 ? SwipeDirection.left : SwipeDirection.right;
  return null;
}

/// Pointer speed (px/ms) -> multiplier. 1.0 below ~150 px/s, smoothly rising to 1 + 3 * strength at ~2000 px/s.
double accelFactor(double speedPxPerMs, {required bool enabled, required double strength}) {
  if (!enabled || strength <= 0) return 1;
  final double t = ((speedPxPerMs - 0.15) / (2.0 - 0.15)).clamp(0.0, 1.0).toDouble();
  final s = t * t * (3 - 2 * t);
  return 1 + 3 * strength.clamp(0.0, 1.0) * s;
}

/// Several things can hold a button (a finger drag, drag lock, long press, the on-screen button). The button goes
/// down when the first holder arrives and up when the last one leaves, so sources never fight.
class ButtonHolds {
  ButtonHolds(this._emit);
  final void Function(TouchpadAction) _emit;
  final Map<Btn, Set<Object>> _holds = {Btn.left: {}, Btn.right: {}};
  final Map<Btn, int> _count = {Btn.left: 1, Btn.right: 1};

  bool isDown(Btn b) => _holds[b]!.isNotEmpty;

  void press(Btn b, Object source, {int clickCount = 1}) {
    final set = _holds[b]!;
    final wasDown = set.isNotEmpty;
    set.add(source);
    if (!wasDown) {
      _count[b] = clickCount;
      _emit(ButtonAction(b, true, clickCount));
    }
  }

  void release(Btn b, Object source) {
    final set = _holds[b]!;
    if (!set.remove(source)) return;
    if (set.isEmpty) _emit(ButtonAction(b, false, _count[b]!));
  }

  /// Complete press + release (tap).
  void click(Btn b, {int clickCount = 1}) {
    if (isDown(b)) return;
    press(b, #click, clickCount: clickCount);
    release(b, #click);
  }

  void releaseAll() {
    for (final b in Btn.values) {
      if (_holds[b]!.isNotEmpty) {
        _holds[b]!.clear();
        _emit(ButtonAction(b, false, _count[b]!));
      }
    }
  }
}

class _Touch {
  _Touch(this.start, this.startMs)
      : last = start,
        lastMs = startMs,
        swipeStart = start;
  final Offset start;
  final int startMs;
  Offset last;
  int lastMs;
  Offset swipeStart;
  double moved = 0;
  bool engaged = false;
}

/// Turns raw multi-touch pointer data into trackpad actions. No Flutter widgets and no clocks: timestamps come
/// from the pointer events (and [tick] for things that happen without events), so behaviour is deterministic
/// and unit-testable.
///
/// One finger: move (deadzone, smoothing, acceleration), tap = click, second tap = double click, tap then
/// touch-and-drag = drag, long press = drag. Two fingers: scroll (vertical and horizontal), quick tap = right click.
/// Three or four fingers: swipes up / down / left / right, reported as [SwipeAction]. More than four fingers are
/// ignored. Drag mode: a finger holds the left button; drag lock keeps it held after the finger lifts until the next tap.
///
/// Conflict rules: the number of fingers decides the gesture family and never goes back (lifting a finger does not
/// turn a swipe into a scroll); a third finger cancels a scroll or right-click that has not been emitted yet;
/// a swipe fires at most once per touch session; 3+ fingers never move the cursor, click or scroll;
/// a cancelled pointer ends the whole session without any action.
class GestureEngine {
  GestureEngine({required this.settings, required this.holds, required this.emit, GestureConfig? config})
      : config = config ?? GestureConfig.defaults();

  TouchpadSettings settings;
  GestureConfig config;
  final ButtonHolds holds;
  final void Function(TouchpadAction) emit;

  static const _srcDrag = #gestureDrag;
  static const _srcLock = #gestureLock;
  static const _srcTapDrag = #gestureTapDrag;
  static const _srcLongPress = #gestureLongPress;

  bool _dragMode = false;
  bool _dragLock = false;
  bool _locked = false;
  bool _fingerDrag = false;
  bool _tapDragActive = false;
  bool _longPressArmed = false;
  bool _longPressActive = false;

  final Map<int, _Touch> _touches = {};
  final Set<int> _ignored = {};
  bool _cancelled = false;

  // two fingers
  bool _multi = false;
  bool _scrolling = false;
  bool _scrollPending = false;
  bool _rightDone = false;
  int _twoStartMs = 0;
  double _twoMoved = 0;
  Offset _centroid = Offset.zero;
  double _pendX = 0, _pendY = 0;

  // three / four fingers
  bool _swipeMode = false;
  bool _swipeFired = false;
  int _swipeFingers = 0;
  int _swipeMoveStartMs = -1;
  Offset _swipeRef = Offset.zero;

  // one finger
  bool _secondTap = false;
  int? _lastTapMs;
  Offset _lastTapPos = Offset.zero;
  Offset _smooth = Offset.zero;
  bool _hasSmooth = false;
  double _accX = 0, _accY = 0, _sAccX = 0, _sAccY = 0;

  bool get dragMode => _dragMode;
  bool get dragLock => _dragLock;
  bool get isLocked => _locked;
  int get activeTouches => _touches.length;

  double get _tapSlop => Tuning.tapSlopPx * config[GestureId.oneFingerTap].sensitivity;
  double get _twoTapSlop => Tuning.twoFingerTapSlopPx * config[GestureId.twoFingerTap].sensitivity;
  int get _doubleTapWindow => (Tuning.doubleTapWindowMs * config[GestureId.doubleTap].sensitivity).round();

  void setDragMode(bool on) {
    _dragMode = on;
    if (on) _longPressArmed = false;
    if (!on) _releaseDragHolds();
  }

  void setDragLock(bool on) {
    _dragLock = on;
    if (!on && _locked) {
      holds.release(Btn.left, _srcLock);
      _locked = false;
    }
  }

  // MARK: pointer events

  void pointerDown(int id, Offset pos, int tMs) {
    if (_cancelled) {
      _touches[id] = _Touch(pos, tMs);          // tracked only so we know when everything has lifted
      return;
    }
    if (_touches.length >= Tuning.maxFingers ||
        (_touches.isNotEmpty && (_tapDragActive || _fingerDrag || _longPressActive))) {
      _ignored.add(id);
      return;
    }
    _touches[id] = _Touch(pos, tMs);
    final n = _touches.length;
    if (n == 1) {
      _multi = false;
      _swipeMode = false;
      _swipeFired = false;
      _hasSmooth = false;
      _secondTap = false;
      final lastTap = _lastTapMs;
      if (!_dragMode && config[GestureId.doubleTap].enabled && lastTap != null &&
          tMs - lastTap <= _doubleTapWindow && (pos - _lastTapPos).distance <= Tuning.doubleTapRadiusPx) {
        _secondTap = true;
      }
      if (_dragMode) {
        if (!_locked) holds.press(Btn.left, _srcDrag);
        _fingerDrag = true;
      }
      _longPressArmed = !_dragMode && config[GestureId.longPress].enabled;
    } else if (n == 2) {
      _longPressArmed = false;
      _multi = true;
      _scrolling = false;
      _scrollPending = false;
      _rightDone = false;
      _secondTap = false;
      _twoMoved = 0;
      _pendX = _pendY = 0;
      _twoStartMs = tMs;
      _centroid = _centroidOf();
    } else {
      _longPressArmed = false;
      _enterSwipeMode(tMs);
    }
  }

  void pointerMove(int id, Offset pos, int tMs) {
    final t = _touches[id];
    if (t == null) return;
    final delta = pos - t.last;
    final dt = math.max(1, tMs - t.lastMs);
    t.last = pos;
    t.lastMs = tMs;
    t.moved += delta.distance;
    if (_cancelled) return;
    if (_swipeMode) {
      _swipeMove(tMs);
    } else if (_multi) {
      _twoFingerMove(tMs);
    } else {
      if (_longPressArmed && t.moved > _tapSlop) _longPressArmed = false;
      _singleMove(t, delta, dt);
    }
  }

  void pointerUp(int id, Offset pos, int tMs) {
    if (_ignored.remove(id)) return;
    final t = _touches.remove(id);
    if (t == null) return;

    if (_cancelled) {
      if (_touches.isEmpty) _endGesture();
      return;
    }

    if (_swipeMode) {                 // swipes act when the distance is reached, never on lift
      if (_touches.isEmpty) _endGesture();
      return;
    }

    if (_multi) {
      if (_scrolling && _scrollPending) _flushScroll();
      // Decided when the first of the two fingers lifts.
      if (!_rightDone && !_scrolling && _touches.length == 1 && settings.twoFingerRightClick &&
          _twoMoved <= _twoTapSlop && tMs - _twoStartMs <= Tuning.twoFingerTapTimeoutMs) {
        holds.click(Btn.right);
      }
      _rightDone = true;
      if (_touches.isEmpty) _endGesture();
      return;
    }

    final isTap = t.moved <= _tapSlop && tMs - t.startMs <= Tuning.tapTimeoutMs;
    if (_longPressActive) {
      holds.release(Btn.left, _srcLongPress);
      _longPressActive = false;
      _lastTapMs = null;
    } else if (_tapDragActive) {
      holds.release(Btn.left, _srcTapDrag);
      _tapDragActive = false;
      _lastTapMs = null;
    } else if (_dragMode) {
      _finishFingerDrag(isTap);
    } else if (isTap && settings.tapToClick) {
      holds.click(Btn.left, clickCount: _secondTap ? 2 : 1);
      _lastTapMs = _secondTap ? null : tMs;
      _lastTapPos = pos;
    } else {
      _lastTapMs = null;
    }
    _endGesture();
  }

  /// The system took the touch away (palm rejection, gesture navigation). The whole session is abandoned:
  /// no click, no swipe, nothing stays pressed.
  void pointerCancel(int id) {
    _ignored.remove(id);
    if (_touches.remove(id) == null) return;
    _cancelSession();
    if (_touches.isEmpty) _endGesture();
  }

  /// Call every ~30-50 ms while fingers are down, with a clock that matches the pointer timestamps. Handles things
  /// that happen without a pointer event: a finger resting for a long press, and scroll movement held back
  /// while waiting for a possible third finger.
  void tick(int nowMs) {
    if (_cancelled || _swipeMode) return;
    if (_longPressArmed && !_multi && _touches.length == 1) {
      final t = _touches.values.first;
      if (t.moved <= _tapSlop && nowMs - t.startMs >= config[GestureId.longPress].holdMs) {
        _longPressArmed = false;
        _longPressActive = true;
        _secondTap = false;
        holds.press(Btn.left, _srcLongPress);
      }
    }
    if (_scrollPending && _touches.length == 2 && nowMs - _twoStartMs >= Tuning.scrollStartDelayMs) _flushScroll();
  }

  /// Forget everything and release every button (disconnect, leaving the screen, app paused).
  void reset() {
    _touches.clear();
    _ignored.clear();
    holds.releaseAll();
    _tapDragActive = false;
    _fingerDrag = false;
    _longPressActive = false;
    _locked = false;
    _lastTapMs = null;
    _endGesture();
  }

  // MARK: single finger

  void _singleMove(_Touch t, Offset delta, int dtMs) {
    if (!config[GestureId.oneFingerMove].enabled) return;
    if (!t.engaged) {
      if (t.moved < settings.deadzone) return;     // keeps taps accurate; the user's "touch sensitivity"
      t.engaged = true;
    }
    if (_secondTap && !_tapDragActive && !_dragMode && t.moved > _tapSlop) {
      _tapDragActive = true;
      holds.press(Btn.left, _srcTapDrag);
    }
    final alpha = (1 - settings.smoothing).clamp(0.15, 1.0).toDouble();
    _smooth = _hasSmooth ? _smooth * (1 - alpha) + delta * alpha : delta;
    _hasSmooth = true;
    final factor = accelFactor(_smooth.distance / dtMs, enabled: settings.accelEnabled, strength: settings.accelStrength);
    final k = settings.sensitivity * factor;
    _accX += _smooth.dx * k;
    _accY += _smooth.dy * k;
    final ix = _accX.truncate(), iy = _accY.truncate();
    _accX -= ix;
    _accY -= iy;
    if (ix != 0 || iy != 0) emit(MoveAction(ix, iy));
  }

  void _finishFingerDrag(bool isTap) {
    _fingerDrag = false;
    if (_dragLock) {
      if (_locked) {
        if (isTap) {                              // a tap while locked lets go
          holds.release(Btn.left, _srcLock);
          _locked = false;
        }
      } else if (!isTap) {                        // a real drag stays held after lifting
        holds.press(Btn.left, _srcLock);
        holds.release(Btn.left, _srcDrag);
        _locked = true;
      } else {
        holds.release(Btn.left, _srcDrag);        // plain tap = just a click
      }
    } else {
      holds.release(Btn.left, _srcDrag);
    }
  }

  // MARK: two fingers

  void _twoFingerMove(int tMs) {
    if (_touches.length != 2) return;          // one finger left over: wait until all lift
    final c = _centroidOf();
    final d = c - _centroid;
    _centroid = c;
    _twoMoved += d.distance;
    if (!_scrolling) {
      if (_twoMoved < Tuning.scrollSlopPx) return;
      _scrolling = true;
    }
    _pendX += d.dx;
    _pendY += d.dy;
    if (config.anyEnabledFor(3) && tMs - _twoStartMs < Tuning.scrollStartDelayMs) {
      _scrollPending = true;                    // hold back briefly in case a third finger is on its way
      return;
    }
    _flushScroll();
  }

  void _flushScroll() {
    _scrollPending = false;
    var dx = _pendX, dy = _pendY;
    _pendX = _pendY = 0;
    if (dy.abs() > dx.abs() * 2) {
      dx = 0;                                    // axis lock: mostly vertical
    } else if (dx.abs() > dy.abs() * 2) {
      dy = 0;
    }
    if (!config[GestureId.scrollVertical].enabled) dy = 0;
    if (!settings.horizontalScroll) dx = 0;
    final dir = settings.naturalScroll ? 1.0 : -1.0;
    final hdir = dir * (settings.invertHorizontal ? -1.0 : 1.0);
    _sAccX += dx * settings.scrollSensitivity * config[GestureId.scrollHorizontal].sensitivity * hdir;
    _sAccY += dy * settings.scrollSensitivity * dir;
    final ix = _sAccX.truncate(), iy = _sAccY.truncate();
    _sAccX -= ix;
    _sAccY -= iy;
    if (ix != 0 || iy != 0) emit(ScrollAction(ix, iy));
  }

  // MARK: three and four fingers

  void _enterSwipeMode(int tMs) {
    final continuing = _swipeMode && _swipeFired;      // a swipe already fired this session: stay done
    _swipeMode = true;
    _multi = true;
    _scrolling = false;
    _scrollPending = false;
    _pendX = _pendY = 0;
    _rightDone = true;                                 // 3+ fingers can never be a right click
    _swipeFingers = _touches.length;
    _swipeFired = continuing;
    _swipeMoveStartMs = -1;
    for (final t in _touches.values) {
      t.swipeStart = t.last;
    }
    _swipeRef = _centroidOf();
  }

  void _swipeMove(int tMs) {
    if (_swipeFired || _touches.length != _swipeFingers) return;     // finger-count validation
    final d = _centroidOf() - _swipeRef;
    if (_swipeMoveStartMs < 0) {
      if (d.distance < Tuning.swipeStartMovePx) return;
      _swipeMoveStartMs = tMs;
    }
    if (tMs - _swipeMoveStartMs > Tuning.swipeMaxDurationMs) {       // too slow: not a swipe
      _swipeFired = true;
      return;
    }
    final dir = detectSwipe(d);
    if (dir == null) return;
    final id = GestureId.swipe(_swipeFingers, dir);
    if (id == null) return;
    final setting = config[id];
    final along = (dir == SwipeDirection.up || dir == SwipeDirection.down) ? d.dy.abs() : d.dx.abs();
    if (along < setting.distance) return;
    if (!_allFingersAgree(dir, setting.distance)) return;
    _swipeFired = true;                                              // once per session
    if (setting.enabled) emit(SwipeAction(_swipeFingers, dir));
  }

  bool _allFingersAgree(SwipeDirection dir, double need) {
    final unit = switch (dir) {
      SwipeDirection.up => const Offset(0, -1),
      SwipeDirection.down => const Offset(0, 1),
      SwipeDirection.left => const Offset(-1, 0),
      SwipeDirection.right => const Offset(1, 0),
    };
    for (final t in _touches.values) {
      final v = t.last - t.swipeStart;
      if (v.dx * unit.dx + v.dy * unit.dy < need * Tuning.swipeAgreeFraction) return false;
    }
    return true;
  }

  // MARK: housekeeping

  void _cancelSession() {
    _cancelled = true;
    _releaseFingerHolds();
    _lastTapMs = null;
    _scrolling = false;
    _scrollPending = false;
    _pendX = _pendY = 0;
    _swipeFired = true;
    _longPressArmed = false;
  }

  void _releaseFingerHolds() {
    if (_tapDragActive) {
      _tapDragActive = false;
      holds.release(Btn.left, _srcTapDrag);
    }
    if (_longPressActive) {
      _longPressActive = false;
      holds.release(Btn.left, _srcLongPress);
    }
    if (_fingerDrag) {
      _fingerDrag = false;
      holds.release(Btn.left, _srcDrag);
    }
  }

  void _releaseDragHolds() {
    _fingerDrag = false;
    _locked = false;
    _tapDragActive = false;
    holds.release(Btn.left, _srcDrag);
    holds.release(Btn.left, _srcLock);
    holds.release(Btn.left, _srcTapDrag);
  }

  void _endGesture() {
    if (_touches.isNotEmpty) return;
    _cancelled = false;
    _multi = false;
    _scrolling = false;
    _scrollPending = false;
    _pendX = _pendY = 0;
    _swipeMode = false;
    _swipeFired = false;
    _longPressArmed = false;
    _secondTap = false;
    _hasSmooth = false;
    _accX = _accY = _sAccX = _sAccY = 0;
  }

  Offset _centroidOf() {
    var sum = Offset.zero;
    for (final t in _touches.values) {
      sum += t.last;
    }
    return sum / _touches.length.toDouble();
  }
}
