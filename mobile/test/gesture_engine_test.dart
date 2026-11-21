
import 'package:flutter_test/flutter_test.dart';
import 'package:mactouch_mobile/core/touchpad/gesture_engine.dart';
import 'package:mactouch_mobile/core/touchpad/touchpad_settings.dart';

/// Raw settings: no acceleration or smoothing, so expected distances are exact.
const _plain = TouchpadSettings(accelEnabled: false, smoothing: 0, sensitivity: 1, scrollSensitivity: 1);

class Rig {
  Rig([TouchpadSettings settings = _plain]) {
    holds = ButtonHolds(actions.add);
    engine = GestureEngine(settings: settings, holds: holds, emit: actions.add);
  }
  final actions = <TouchpadAction>[];
  late final ButtonHolds holds;
  late final GestureEngine engine;

  Iterable<ButtonAction> get buttons => actions.whereType<ButtonAction>();
  int get movedX => actions.whereType<MoveAction>().fold(0, (a, m) => a + m.dx);
  int get movedY => actions.whereType<MoveAction>().fold(0, (a, m) => a + m.dy);
  int get scrolledX => actions.whereType<ScrollAction>().fold(0, (a, m) => a + m.dx);
  int get scrolledY => actions.whereType<ScrollAction>().fold(0, (a, m) => a + m.dy);
  List<String> get log => buttons.map((b) => '${b.button.name} ${b.down ? 'down' : 'up'} n=${b.clickCount}').toList();

  void tap(int id, Offset at, int t, {int holdMs = 60}) {
    engine.pointerDown(id, at, t);
    engine.pointerUp(id, at, t + holdMs);
  }

  /// Moves a finger in 10 px steps every 16 ms.
  void drag(int id, Offset from, Offset to, int t0, {int stepMs = 16}) {
    final steps = ((to - from).distance / 10).ceil();
    for (var i = 1; i <= steps; i++) {
      engine.pointerMove(id, Offset.lerp(from, to, i / steps)!, t0 + i * stepMs);
    }
  }
}

void main() {
  group('cursor movement', () {
    test('one finger moves the cursor by the finger distance', () {
      final r = Rig();
      r.engine.pointerDown(1, const Offset(100, 100), 0);
      r.drag(1, const Offset(100, 100), const Offset(200, 160), 0);
      r.engine.pointerUp(1, const Offset(200, 160), 400);
      expect(r.movedX, closeTo(100, 1));
      expect(r.movedY, closeTo(60, 1));
      expect(r.buttons, isEmpty, reason: 'a drag is not a tap');
    });

    test('tiny jitter inside the deadzone does not move the cursor', () {
      final r = Rig();
      r.engine.pointerDown(1, const Offset(50, 50), 0);
      r.engine.pointerMove(1, const Offset(51, 50), 10);
      r.engine.pointerMove(1, const Offset(51, 51), 20);
      expect(r.actions.whereType<MoveAction>(), isEmpty);
    });

    test('sensitivity scales movement and subpixel remainders are carried, not lost', () {
      final r = Rig(_plain.copyWith(sensitivity: 0.3));
      r.engine.pointerDown(1, Offset.zero, 0);
      for (var i = 1; i <= 50; i++) {
        r.engine.pointerMove(1, Offset(4.0 * i, 0), i * 16);
      }
      expect(r.movedX, closeTo(200 * 0.3, 1));
    });

    test('smoothing lowers the reaction to a sudden change', () {
      final raw = Rig();
      final smooth = Rig(_plain.copyWith(smoothing: 0.7));
      for (final r in [raw, smooth]) {
        r.engine.pointerDown(1, Offset.zero, 0);
        r.engine.pointerMove(1, const Offset(5, 0), 16);
        r.engine.pointerMove(1, const Offset(5, 0), 32);
        r.engine.pointerMove(1, const Offset(45, 0), 48);   // sudden 40 px jump
      }
      final lastRaw = raw.actions.whereType<MoveAction>().last.dx;
      final lastSmooth = smooth.actions.whereType<MoveAction>().last.dx;
      expect(lastSmooth, lessThan(lastRaw));
    });

    test('acceleration makes fast swipes travel further than slow ones', () {
      final accel = _plain.copyWith(accelEnabled: true, accelStrength: 1);
      int travel(int stepMs) {
        final r = Rig(accel);
        r.engine.pointerDown(1, Offset.zero, 0);
        for (var i = 1; i <= 10; i++) {
          r.engine.pointerMove(1, Offset(30.0 * i, 0), i * stepMs);
        }
        return r.movedX;
      }

      final slow = travel(100);   // 0.3 px/ms
      final fast = travel(4);     // 7.5 px/ms
      expect(fast, greaterThan(slow * 2));
      expect(slow, greaterThanOrEqualTo(300));
    });

    test('accelFactor: 1 when off or slow, monotonic, capped at 1 + 3 * strength', () {
      expect(accelFactor(5, enabled: false, strength: 1), 1);
      expect(accelFactor(5, enabled: true, strength: 0), 1);
      expect(accelFactor(0.05, enabled: true, strength: 1), 1);
      var prev = 1.0;
      for (var v = 0.0; v <= 5; v += 0.1) {
        final f = accelFactor(v, enabled: true, strength: 0.6);
        expect(f, greaterThanOrEqualTo(prev));
        prev = f;
      }
      expect(accelFactor(10, enabled: true, strength: 0.6), closeTo(1 + 3 * 0.6, 1e-9));
    });
  });

  group('clicks', () {
    test('tap = left click', () {
      final r = Rig()..tap(1, const Offset(10, 10), 0);
      expect(r.log, ['left down n=1', 'left up n=1']);
    });

    test('tap-to-click can be disabled', () {
      final r = Rig(_plain.copyWith(tapToClick: false))..tap(1, const Offset(10, 10), 0);
      expect(r.log, isEmpty);
    });

    test('a long press is not a click', () {
      final r = Rig()..tap(1, const Offset(10, 10), 0, holdMs: 600);
      expect(r.log, isEmpty);
    });

    test('a touch that wanders too far is not a click', () {
      final r = Rig();
      r.engine.pointerDown(1, Offset.zero, 0);
      r.engine.pointerMove(1, const Offset(30, 0), 30);
      r.engine.pointerUp(1, const Offset(30, 0), 60);
      expect(r.log, isEmpty);
    });

    test('two quick taps = click then double click (click count 2)', () {
      final r = Rig()
        ..tap(1, const Offset(100, 100), 0)
        ..tap(2, const Offset(104, 102), 200);
      expect(r.log, ['left down n=1', 'left up n=1', 'left down n=2', 'left up n=2']);
    });

    test('the second tap too late, or too far away, is a fresh single click', () {
      final late = Rig()
        ..tap(1, const Offset(100, 100), 0)
        ..tap(2, const Offset(100, 100), 600);
      expect(late.log.where((l) => l.contains('n=2')), isEmpty);
      final far = Rig()
        ..tap(1, const Offset(100, 100), 0)
        ..tap(2, const Offset(300, 100), 150);
      expect(far.log.where((l) => l.contains('n=2')), isEmpty);
    });

    test('a third tap starts over with a single click', () {
      final r = Rig()
        ..tap(1, const Offset(100, 100), 0)
        ..tap(2, const Offset(100, 100), 150)
        ..tap(3, const Offset(100, 100), 300);
      expect(r.log.sublist(4), ['left down n=1', 'left up n=1']);
    });

    test('two-finger tap = right click', () {
      final r = Rig();
      r.engine.pointerDown(1, const Offset(100, 100), 0);
      r.engine.pointerDown(2, const Offset(160, 100), 10);
      r.engine.pointerUp(1, const Offset(100, 100), 90);
      r.engine.pointerUp(2, const Offset(160, 100), 95);
      expect(r.log, ['right down n=1', 'right up n=1']);
      expect(r.actions.whereType<MoveAction>(), isEmpty);
    });

    test('two-finger right click can be disabled', () {
      final r = Rig(_plain.copyWith(twoFingerRightClick: false));
      r.engine.pointerDown(1, const Offset(100, 100), 0);
      r.engine.pointerDown(2, const Offset(160, 100), 10);
      r.engine.pointerUp(1, const Offset(100, 100), 90);
      r.engine.pointerUp(2, const Offset(160, 100), 95);
      expect(r.log, isEmpty);
    });
  });

  group('scrolling', () {
    Rig twoFingerSwipe(TouchpadSettings s, Offset delta) {
      final r = Rig(s);
      r.engine.pointerDown(1, const Offset(100, 200), 0);
      r.engine.pointerDown(2, const Offset(180, 200), 5);
      for (var i = 1; i <= 10; i++) {
        final d = delta * (i / 10);
        r.engine.pointerMove(1, const Offset(100, 200) + d, 5 + i * 16);
        r.engine.pointerMove(2, const Offset(180, 200) + d, 5 + i * 16);
      }
      r.engine.pointerUp(1, const Offset(100, 200) + delta, 400);
      r.engine.pointerUp(2, const Offset(180, 200) + delta, 405);
      return r;
    }

    test('two fingers moving down scroll down (natural) and do not right-click or move the cursor', () {
      final r = twoFingerSwipe(_plain, const Offset(0, 100));
      expect(r.scrolledY, greaterThan(80));
      expect(r.scrolledX, 0);
      expect(r.buttons, isEmpty);
      expect(r.actions.whereType<MoveAction>(), isEmpty);
    });

    test('traditional scrolling inverts the direction', () {
      final r = twoFingerSwipe(_plain.copyWith(naturalScroll: false), const Offset(0, 100));
      expect(r.scrolledY, lessThan(-80));
    });

    test('scroll sensitivity scales the distance', () {
      final one = twoFingerSwipe(_plain, const Offset(0, 100)).scrolledY;
      final two = twoFingerSwipe(_plain.copyWith(scrollSensitivity: 2), const Offset(0, 100)).scrolledY;
      expect(two, closeTo(one * 2, 3));
    });

    test('horizontal scrolling follows the fingers, can be reversed, and can be turned off', () {
      expect(twoFingerSwipe(_plain, const Offset(100, 0)).scrolledX, greaterThan(80));
      expect(twoFingerSwipe(_plain.copyWith(invertHorizontal: true), const Offset(100, 0)).scrolledX, lessThan(-80));
      final off = twoFingerSwipe(_plain.copyWith(horizontalScroll: false), const Offset(100, 0));
      expect(off.scrolledX, 0);
      expect(off.scrolledY, 0);
    });

    test('a mostly vertical swipe does not leak sideways scroll (axis lock)', () {
      final r = twoFingerSwipe(_plain, const Offset(12, 100));
      expect(r.scrolledX, 0);
      expect(r.scrolledY, greaterThan(80));
    });

    test('the finger left over after one lifts does not move the cursor', () {
      final r = Rig();
      r.engine.pointerDown(1, const Offset(100, 100), 0);
      r.engine.pointerDown(2, const Offset(160, 100), 5);
      r.engine.pointerMove(1, const Offset(100, 160), 400);   // wandered, so this is not a right-click tap
      r.engine.pointerMove(2, const Offset(160, 160), 400);
      r.engine.pointerUp(1, const Offset(100, 160), 450);
      final before = r.actions.length;
      r.engine.pointerMove(2, const Offset(300, 300), 500);
      expect(r.actions.length, before);
      r.engine.pointerUp(2, const Offset(300, 300), 520);
    });

    test('a fifth finger is ignored (three and four fingers are recognised since Part 3)', () {
      final r = Rig();
      for (var i = 0; i < 5; i++) {
        r.engine.pointerDown(i + 1, Offset(100.0 + i * 30, 100), i);
      }
      expect(r.engine.activeTouches, 4);
      r.engine.pointerUp(5, const Offset(220, 100), 50);
      expect(r.engine.activeTouches, 4);
    });
  });

  group('drag', () {
    test('tap, then touch and drag = left button held while moving', () {
      final r = Rig()..tap(1, const Offset(100, 100), 0);
      r.engine.pointerDown(2, const Offset(100, 100), 150);
      r.drag(2, const Offset(100, 100), const Offset(180, 100), 150);
      expect(r.holds.isDown(Btn.left), isTrue);
      r.engine.pointerUp(2, const Offset(180, 100), 500);
      expect(r.holds.isDown(Btn.left), isFalse);
      expect(r.log, ['left down n=1', 'left up n=1', 'left down n=1', 'left up n=1']);
      expect(r.movedX, closeTo(80, 2));
    });

    test('drag mode: the left button is held for as long as the finger is down', () {
      final r = Rig();
      r.engine.setDragMode(true);
      r.engine.pointerDown(1, const Offset(50, 50), 0);
      expect(r.holds.isDown(Btn.left), isTrue);
      r.drag(1, const Offset(50, 50), const Offset(150, 50), 0);
      r.engine.pointerUp(1, const Offset(150, 50), 500);
      expect(r.holds.isDown(Btn.left), isFalse);
      expect(r.log, ['left down n=1', 'left up n=1']);
    });

    test('drag lock: the button stays held after lifting, and a tap lets go', () {
      final r = Rig();
      r.engine.setDragMode(true);
      r.engine.setDragLock(true);
      r.engine.pointerDown(1, const Offset(50, 50), 0);
      r.drag(1, const Offset(50, 50), const Offset(150, 50), 0);
      r.engine.pointerUp(1, const Offset(150, 50), 500);
      expect(r.holds.isDown(Btn.left), isTrue, reason: 'locked');
      expect(r.engine.isLocked, isTrue);

      r.engine.pointerDown(2, const Offset(60, 60), 1000);     // reposition while still holding
      r.drag(2, const Offset(60, 60), const Offset(100, 60), 1000);
      r.engine.pointerUp(2, const Offset(100, 60), 1400);
      expect(r.holds.isDown(Btn.left), isTrue);

      r.tap(3, const Offset(100, 60), 2000);                   // tap = release
      expect(r.holds.isDown(Btn.left), isFalse);
      expect(r.log, ['left down n=1', 'left up n=1'], reason: 'exactly one down and one up overall');
    });

    test('drag lock: a plain tap in drag mode is just a click, not a lock', () {
      final r = Rig();
      r.engine.setDragMode(true);
      r.engine.setDragLock(true);
      r.tap(1, const Offset(50, 50), 0);
      expect(r.holds.isDown(Btn.left), isFalse);
      expect(r.log, ['left down n=1', 'left up n=1']);
    });

    test('turning drag mode off releases a locked button', () {
      final r = Rig();
      r.engine.setDragMode(true);
      r.engine.setDragLock(true);
      r.engine.pointerDown(1, const Offset(50, 50), 0);
      r.drag(1, const Offset(50, 50), const Offset(150, 50), 0);
      r.engine.pointerUp(1, const Offset(150, 50), 500);
      r.engine.setDragMode(false);
      expect(r.holds.isDown(Btn.left), isFalse);
    });

    test('an on-screen button held together with a finger drag: the button only goes up when both let go', () {
      final r = Rig();
      r.engine.setDragMode(true);
      r.holds.press(Btn.left, #ui);
      r.engine.pointerDown(1, const Offset(50, 50), 0);
      r.engine.pointerUp(1, const Offset(50, 50), 300);
      expect(r.holds.isDown(Btn.left), isTrue);
      r.holds.release(Btn.left, #ui);
      expect(r.log, ['left down n=1', 'left up n=1']);
    });
  });

  group('safety', () {
    test('reset releases every held button', () {
      final r = Rig();
      r.holds.press(Btn.left, #a);
      r.holds.press(Btn.right, #b);
      r.engine.reset();
      expect(r.holds.isDown(Btn.left) || r.holds.isDown(Btn.right), isFalse);
      expect(r.log, containsAll(['left down n=1', 'right down n=1', 'left up n=1', 'right up n=1']));
    });

    test('a cancelled touch during a tap-drag releases the button', () {
      final r = Rig()..tap(1, const Offset(100, 100), 0);
      r.engine.pointerDown(2, const Offset(100, 100), 150);
      r.drag(2, const Offset(100, 100), const Offset(180, 100), 150);
      r.engine.pointerCancel(2);
      expect(r.holds.isDown(Btn.left), isFalse);
    });

    test('ButtonHolds: only transitions are emitted', () {
      final actions = <TouchpadAction>[];
      final h = ButtonHolds(actions.add);
      h.press(Btn.left, #a);
      h.press(Btn.left, #b);
      h.release(Btn.left, #a);
      expect(actions.length, 1);
      h.release(Btn.left, #b);
      h.release(Btn.left, #b);
      expect(actions.length, 2);
    });
  });
}
