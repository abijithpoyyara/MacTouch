
import 'package:flutter_test/flutter_test.dart';
import 'package:mactouch_mobile/core/shortcuts/system_actions.dart';
import 'package:mactouch_mobile/core/touchpad/gesture_config.dart';
import 'package:mactouch_mobile/core/touchpad/gesture_engine.dart';
import 'package:mactouch_mobile/core/touchpad/touchpad_settings.dart';

const _plain = TouchpadSettings(accelEnabled: false, smoothing: 0, sensitivity: 1, scrollSensitivity: 1);

class R {
  R([TouchpadSettings s = _plain, GestureConfig? config]) {
    holds = ButtonHolds(actions.add);
    engine = GestureEngine(settings: s, holds: holds, emit: actions.add, config: config);
  }
  final actions = <TouchpadAction>[];
  late final ButtonHolds holds;
  late final GestureEngine engine;

  List<String> get swipes => actions.whereType<SwipeAction>().map((s) => '${s.fingers}-${s.direction.name}').toList();
  int get moves => actions.whereType<MoveAction>().length;
  int get scrollEvents => actions.whereType<ScrollAction>().length;
  int get scrollY => actions.whereType<ScrollAction>().fold(0, (a, s) => a + s.dy);
  int get scrollX => actions.whereType<ScrollAction>().fold(0, (a, s) => a + s.dx);
  int get movedX => actions.whereType<MoveAction>().fold(0, (a, s) => a + s.dx);
  List<String> get log =>
      actions.whereType<ButtonAction>().map((b) => '${b.button.name} ${b.down ? 'down' : 'up'} n=${b.clickCount}').toList();

  void tap(int id, Offset p, int t, {int hold = 60}) {
    engine.pointerDown(id, p, t);
    engine.pointerUp(id, p, t + hold);
  }

  /// [n] fingers side by side moving together by [delta] in [steps] steps. Returns the time of the last move.
  int fingers(int n, Offset delta, {int t0 = 0, double spacing = 40, Offset base = const Offset(100, 300), int stagger = 5,
      int steps = 10, int stepMs = 16, List<int>? ids, List<int>? only}) {
    int id(int i) => ids != null ? ids[i] : i + 1;
    for (var i = 0; i < n; i++) {
      engine.pointerDown(id(i), Offset(base.dx + i * spacing, base.dy), t0 + i * stagger);
    }
    final ts = t0 + (n - 1) * stagger;
    for (var s = 1; s <= steps; s++) {
      for (var i = 0; i < n; i++) {
        if (only != null && !only.contains(i)) continue;
        engine.pointerMove(id(i), Offset(base.dx + i * spacing + delta.dx * s / steps, base.dy + delta.dy * s / steps), ts + s * stepMs);
      }
    }
    return ts + steps * stepMs;
  }

  void lift(int n, Offset delta, int t, {double spacing = 40, Offset base = const Offset(100, 300), List<int>? ids}) {
    for (var i = 0; i < n; i++) {
      engine.pointerUp(ids != null ? ids[i] : i + 1, Offset(base.dx + i * spacing + delta.dx, base.dy + delta.dy), t + i);
    }
  }
}

GestureConfig _with(GestureConfig c, GestureId id, GestureSetting Function(GestureSetting) f) => c.with_(id, f(c[id]));

void main() {
  group('direction detection', () {
    test('up, down, left, right', () {
      expect(detectSwipe(const Offset(0, -50)), SwipeDirection.up);
      expect(detectSwipe(const Offset(0, 50)), SwipeDirection.down);
      expect(detectSwipe(const Offset(-50, 0)), SwipeDirection.left);
      expect(detectSwipe(const Offset(50, 0)), SwipeDirection.right);
      expect(detectSwipe(const Offset(10, -50)), SwipeDirection.up, reason: 'mostly vertical');
    });

    test('diagonal and tiny movements are not a direction', () {
      expect(detectSwipe(const Offset(40, 40)), isNull);
      expect(detectSwipe(const Offset(5, 5)), isNull);
      expect(detectSwipe(Offset.zero), isNull);
    });
  });

  group('three-finger swipes', () {
    const cases = {
      'up': [Offset(0, -120), '3-up'],
      'down': [Offset(0, 120), '3-down'],
      'left': [Offset(-120, 0), '3-left'],
      'right': [Offset(120, 0), '3-right'],
    };
    for (final e in cases.entries) {
      test('swipe ${e.key} fires exactly once', () {
        final r = R();
        final d = e.value[0] as Offset;
        final t = r.fingers(3, d);
        r.lift(3, d, t + 10);
        expect(r.swipes, [e.value[1]]);
      });
    }

    test('three fingers never move the cursor, click, scroll or right-click', () {
      final r = R();
      final t = r.fingers(3, const Offset(0, -120));
      r.lift(3, const Offset(0, -120), t + 10);
      expect(r.moves + r.scrollEvents + r.log.length, 0);
    });

    test('a fifth finger is ignored', () {
      final r = R();
      for (var i = 0; i < 5; i++) {
        r.engine.pointerDown(i + 1, Offset(100.0 + i * 30, 300), i);
      }
      expect(r.engine.activeTouches, 4);
      r.engine.pointerUp(5, const Offset(220, 300), 50);
      expect(r.engine.activeTouches, 4);
    });
  });

  group('four-finger swipes', () {
    const cases = {
      'up': [Offset(0, -120), '4-up'],
      'down': [Offset(0, 120), '4-down'],
      'left': [Offset(-120, 0), '4-left'],
      'right': [Offset(120, 0), '4-right'],
    };
    for (final e in cases.entries) {
      test('swipe ${e.key} fires exactly once', () {
        final r = R();
        final d = e.value[0] as Offset;
        final t = r.fingers(4, d, spacing: 30);
        r.lift(4, d, t + 10, spacing: 30);
        expect(r.swipes, [e.value[1]]);
      });
    }

    test('a fourth finger after three: only the four-finger swipe fires', () {
      final r = R();
      for (var i = 0; i < 3; i++) {
        r.engine.pointerDown(i + 1, Offset(100.0 + i * 30, 300), i * 5);
      }
      r.engine.pointerMove(1, const Offset(100, 296), 20);
      r.engine.pointerDown(4, const Offset(190, 300), 25);
      for (var s = 1; s <= 10; s++) {
        for (var i = 0; i < 4; i++) {
          r.engine.pointerMove(i + 1, Offset(100.0 + i * 30, 300.0 - 10 * s), 25 + s * 16);
        }
      }
      expect(r.swipes, ['4-up']);
    });

    test('after a three-finger swipe has fired, a fourth finger does not fire a second swipe', () {
      final r = R();
      final t = r.fingers(3, const Offset(0, -120));
      r.engine.pointerDown(4, const Offset(220, 300), t + 5);
      for (var s = 1; s <= 10; s++) {
        for (var i = 0; i < 4; i++) {
          r.engine.pointerMove(i + 1, Offset(100.0 + i * 40, 180.0 - 15 * s), t + 5 + s * 16);
        }
      }
      expect(r.swipes, ['3-up']);
    });
  });

  group('thresholds, duration and validation', () {
    test('below the distance nothing fires; the distance is configurable per gesture', () {
      var r = R();
      var t = r.fingers(3, const Offset(0, -60));
      r.lift(3, const Offset(0, -60), t + 10);
      expect(r.swipes, isEmpty, reason: '60 px < default 80 px');

      r = R(_plain, _with(GestureConfig.defaults(), GestureId.threeUp, (s) => s.copyWith(distance: 40)));
      r.fingers(3, const Offset(0, -60));
      expect(r.swipes, ['3-up']);

      r = R(_plain, _with(GestureConfig.defaults(), GestureId.threeUp, (s) => s.copyWith(distance: 200)));
      r.fingers(3, const Offset(0, -150));
      expect(r.swipes, isEmpty);
    });

    test('distance is per direction', () {
      final cfg = _with(GestureConfig.defaults(), GestureId.threeLeft, (s) => s.copyWith(distance: 200));
      final r = R(_plain, cfg);
      r.fingers(3, const Offset(-120, 0));
      expect(r.swipes, isEmpty, reason: 'left needs 200');
      final r2 = R(_plain, cfg);
      r2.fingers(3, const Offset(120, 0));
      expect(r2.swipes, ['3-right'], reason: 'right still needs only 80');
    });

    test('a diagonal drag does not fire', () {
      final r = R();
      final t = r.fingers(3, const Offset(100, -100));
      r.lift(3, const Offset(100, -100), t + 10);
      expect(r.swipes, isEmpty);
    });

    test('a swipe slower than the duration limit does not fire', () {
      final r = R();
      final t = r.fingers(3, const Offset(0, -120), stepMs: 200);
      r.lift(3, const Offset(0, -120), t + 10);
      expect(r.swipes, isEmpty);
    });

    test('time spent resting before the swipe does not count against the limit', () {
      final r = R();
      for (var i = 0; i < 3; i++) {
        r.engine.pointerDown(i + 1, Offset(100.0 + i * 40, 300), i * 5);
      }
      for (var s = 1; s <= 10; s++) {
        for (var i = 0; i < 3; i++) {
          r.engine.pointerMove(i + 1, Offset(100.0 + i * 40, 300.0 - 12 * s), 2000 + s * 16);
        }
      }
      expect(r.swipes, ['3-up']);
    });

    test('finger-count validation: a finger that stays put blocks the swipe', () {
      final r = R();
      final t = r.fingers(3, const Offset(0, -120), only: [0, 1]);
      r.lift(3, Offset.zero, t + 10);
      expect(r.swipes, isEmpty);
    });

    test('finger-count validation: lifting a finger first cancels it, and the rest do not become a scroll', () {
      final r = R();
      for (var i = 0; i < 3; i++) {
        r.engine.pointerDown(i + 1, Offset(100.0 + i * 40, 300), i * 5);
      }
      for (var s = 1; s <= 3; s++) {
        for (var i = 0; i < 3; i++) {
          r.engine.pointerMove(i + 1, Offset(100.0 + i * 40, 300.0 - 10 * s), 20 + s * 16);
        }
      }
      r.engine.pointerUp(3, const Offset(180, 270), 100);
      for (var s = 4; s <= 12; s++) {
        for (var i = 0; i < 2; i++) {
          r.engine.pointerMove(i + 1, Offset(100.0 + i * 40, 300.0 - 10 * s), 100 + s * 16);
        }
      }
      expect(r.swipes, isEmpty);
      expect(r.scrollEvents, 0);
    });

    test('only one swipe fires per touch session; a new session can swipe again', () {
      var r = R();
      r.fingers(3, const Offset(0, -300), steps: 20, stepMs: 10);
      expect(r.swipes, ['3-up']);

      r = R();
      var t = r.fingers(3, const Offset(0, -120));
      r.lift(3, const Offset(0, -120), t + 10);
      t = r.fingers(3, const Offset(-120, 0), t0: 2000, ids: [4, 5, 6]);
      expect(r.swipes, ['3-up', '3-left']);
    });
  });

  group('enable / disable and conflict prevention', () {
    test('a disabled swipe does nothing and does not turn into another gesture', () {
      final r = R(_plain, _with(GestureConfig.defaults(), GestureId.threeUp, (s) => s.copyWith(enabled: false)));
      final t = r.fingers(3, const Offset(0, -120));
      r.lift(3, const Offset(0, -120), t + 10);
      expect(r.actions, isEmpty);
    });

    test('a third finger landing right after two cancels the scroll before any of it is sent', () {
      final r = R();
      r.engine.pointerDown(1, const Offset(100, 300), 0);
      r.engine.pointerDown(2, const Offset(140, 300), 5);
      r.engine.pointerMove(1, const Offset(100, 290), 20);
      r.engine.pointerMove(2, const Offset(140, 290), 22);
      r.engine.pointerDown(3, const Offset(180, 300), 30);
      expect(r.scrollEvents, 0);
      for (var s = 1; s <= 10; s++) {
        for (var i = 0; i < 3; i++) {
          r.engine.pointerMove(i + 1, Offset(100.0 + i * 40, 290.0 - 12 * s), 30 + s * 16);
        }
      }
      expect(r.swipes, ['3-up']);
      expect(r.scrollEvents, 0);
    });

    test('scroll movement held back for a possible third finger is not lost', () {
      final r = R();
      final t = r.fingers(2, const Offset(0, 100));
      r.lift(2, const Offset(0, 100), t + 10);
      expect(r.scrollY, inInclusiveRange(90, 100));
    });

    test('a quick flick shorter than the hold-back still scrolls (released when a finger lifts)', () {
      final r = R();
      r.engine.pointerDown(1, const Offset(100, 300), 0);
      r.engine.pointerDown(2, const Offset(140, 300), 2);
      r.engine.pointerMove(1, const Offset(100, 330), 10);
      r.engine.pointerMove(2, const Offset(140, 330), 12);
      r.engine.pointerUp(1, const Offset(100, 330), 20);
      r.engine.pointerUp(2, const Offset(140, 330), 22);
      expect(r.scrollY, greaterThanOrEqualTo(25));
    });

    test('held-back scroll is released by tick once the delay has passed', () {
      final r = R();
      r.engine.pointerDown(1, const Offset(100, 300), 0);
      r.engine.pointerDown(2, const Offset(140, 300), 2);
      r.engine.pointerMove(1, const Offset(100, 320), 10);
      r.engine.pointerMove(2, const Offset(140, 320), 12);
      expect(r.scrollEvents, 0);
      r.engine.tick(40);
      expect(r.scrollEvents, 0);
      r.engine.tick(70);
      expect(r.scrollY, greaterThanOrEqualTo(18));
    });

    test('with every three-finger swipe disabled, scrolling starts immediately', () {
      var cfg = GestureConfig.defaults();
      for (final g in [GestureId.threeUp, GestureId.threeDown, GestureId.threeLeft, GestureId.threeRight]) {
        cfg = cfg.with_(g, cfg[g].copyWith(enabled: false));
      }
      final r = R(_plain, cfg);
      r.engine.pointerDown(1, const Offset(100, 300), 0);
      r.engine.pointerDown(2, const Offset(140, 300), 2);
      r.engine.pointerMove(1, const Offset(100, 320), 10);
      r.engine.pointerMove(2, const Offset(140, 320), 12);
      expect(r.scrollY, greaterThanOrEqualTo(18));
    });

    test('cancelling one pointer abandons the whole session; the next session works', () {
      final r = R();
      for (var i = 0; i < 3; i++) {
        r.engine.pointerDown(i + 1, Offset(100.0 + i * 40, 300), i * 5);
      }
      for (var s = 1; s <= 3; s++) {
        for (var i = 0; i < 3; i++) {
          r.engine.pointerMove(i + 1, Offset(100.0 + i * 40, 300.0 - 10 * s), 20 + s * 16);
        }
      }
      r.engine.pointerCancel(2);
      for (var s = 4; s <= 14; s++) {
        for (final i in [0, 2]) {
          r.engine.pointerMove(i + 1, Offset(100.0 + i * 40, 300.0 - 10 * s), 20 + s * 16);
        }
      }
      expect(r.swipes, isEmpty);
      r.engine.pointerUp(1, const Offset(100, 160), 400);
      r.engine.pointerUp(3, const Offset(180, 160), 401);
      expect(r.engine.activeTouches, 0);
      r.fingers(3, const Offset(0, -120), t0: 1000, ids: [7, 8, 9]);
      expect(r.swipes, ['3-up']);
    });
  });

  group('long press = drag', () {
    test('holding still presses the left button; movement drags; lifting releases', () {
      final r = R();
      r.engine.pointerDown(1, const Offset(100, 100), 0);
      r.engine.tick(200);
      expect(r.log, isEmpty);
      r.engine.tick(450);
      expect(r.log, ['left down n=1']);
      for (var s = 1; s <= 8; s++) {
        r.engine.pointerMove(1, Offset(100.0 + 12 * s, 100), 450 + s * 16);
      }
      expect(r.movedX, greaterThanOrEqualTo(90));
      expect(r.holds.isDown(Btn.left), isTrue);
      r.engine.pointerUp(1, const Offset(196, 100), 700);
      expect(r.holds.isDown(Btn.left), isFalse);
      expect(r.log, ['left down n=1', 'left up n=1']);
    });

    test('it does not trigger if the finger moves, a second finger lands, or the finger lifts early', () {
      var r = R();
      r.engine.pointerDown(1, const Offset(100, 100), 0);
      r.engine.pointerMove(1, const Offset(130, 100), 100);
      r.engine.tick(600);
      expect(r.log, isEmpty, reason: 'moved');

      r = R();
      r.engine.pointerDown(1, const Offset(100, 100), 0);
      r.engine.pointerDown(2, const Offset(160, 100), 100);
      r.engine.tick(600);
      expect(r.log, isEmpty, reason: 'second finger');

      r = R();
      r.engine.pointerDown(1, const Offset(100, 100), 0);
      r.engine.tick(300);
      r.engine.pointerUp(1, const Offset(100, 100), 300);
      r.engine.tick(900);
      expect(r.holds.isDown(Btn.left), isFalse);
    });

    test('the hold time is configurable and the gesture can be disabled', () {
      var r = R(_plain, _with(GestureConfig.defaults(), GestureId.longPress, (s) => s.copyWith(holdMs: 800)));
      r.engine.pointerDown(1, const Offset(1, 1), 0);
      r.engine.tick(700);
      expect(r.log, isEmpty);
      r.engine.tick(800);
      expect(r.log, ['left down n=1']);

      r = R(_plain, _with(GestureConfig.defaults(), GestureId.longPress, (s) => s.copyWith(enabled: false)));
      r.engine.pointerDown(1, const Offset(1, 1), 0);
      r.engine.tick(5000);
      expect(r.log, isEmpty);
    });

    test('a cancelled touch releases the button; releasing never also clicks', () {
      var r = R();
      r.engine.pointerDown(1, const Offset(1, 1), 0);
      r.engine.tick(500);
      expect(r.holds.isDown(Btn.left), isTrue);
      r.engine.pointerCancel(1);
      expect(r.holds.isDown(Btn.left), isFalse);

      r = R();
      r.engine.pointerDown(1, const Offset(1, 1), 0);
      r.engine.tick(500);
      r.engine.pointerUp(1, const Offset(1, 1), 520);
      expect(r.log, ['left down n=1', 'left up n=1']);
    });

    test('with the drag-mode toggle on, nothing extra happens', () {
      final r = R();
      r.engine.setDragMode(true);
      r.engine.pointerDown(1, const Offset(1, 1), 0);
      r.engine.tick(1000);
      expect(r.log, ['left down n=1']);
    });
  });

  group('per-gesture settings on the basic gestures', () {
    test('double-tap disabled: two taps are two single clicks', () {
      final r = R(_plain, _with(GestureConfig.defaults(), GestureId.doubleTap, (s) => s.copyWith(enabled: false)));
      r.tap(1, const Offset(100, 100), 0);
      r.tap(2, const Offset(100, 100), 150);
      expect(r.log, ['left down n=1', 'left up n=1', 'left down n=1', 'left up n=1']);
    });

    test('one-finger movement disabled: the cursor stays, taps still click', () {
      final r = R(_plain, _with(GestureConfig.defaults(), GestureId.oneFingerMove, (s) => s.copyWith(enabled: false)));
      r.engine.pointerDown(1, Offset.zero, 0);
      r.engine.pointerMove(1, const Offset(50, 0), 20);
      expect(r.moves, 0);
      r.engine.pointerUp(1, const Offset(50, 0), 40);
      r.tap(2, const Offset(5, 5), 500);
      expect(r.log.length, 2);
    });

    test('vertical scroll disabled keeps horizontal working', () {
      final r = R(_plain, _with(GestureConfig.defaults(), GestureId.scrollVertical, (s) => s.copyWith(enabled: false)));
      r.fingers(2, const Offset(0, 100));
      expect(r.scrollY, 0);
      final r2 = R(_plain, _with(GestureConfig.defaults(), GestureId.scrollVertical, (s) => s.copyWith(enabled: false)));
      r2.fingers(2, const Offset(100, 0));
      expect(r2.scrollX, greaterThan(80));
    });

    test('horizontal scroll sensitivity multiplies the horizontal distance', () {
      final base = R()..fingers(2, const Offset(100, 0));
      final fast = R(_plain, _with(GestureConfig.defaults(), GestureId.scrollHorizontal, (s) => s.copyWith(sensitivity: 2)))
        ..fingers(2, const Offset(100, 0));
      expect(fast.scrollX, closeTo(base.scrollX * 2, 3));
    });

    test('tap tolerance and double-tap timing scale with their sensitivity', () {
      // a 14 px wobble is too much for a tap by default (10 px) but fine with tolerance x2
      final strict = R();
      strict.engine.pointerDown(1, const Offset(50, 50), 0);
      strict.engine.pointerMove(1, const Offset(64, 50), 20);
      strict.engine.pointerUp(1, const Offset(64, 50), 60);
      expect(strict.log, isEmpty);

      final loose = R(_plain, _with(GestureConfig.defaults(), GestureId.oneFingerTap, (s) => s.copyWith(sensitivity: 2)));
      loose.engine.pointerDown(1, const Offset(50, 50), 0);
      loose.engine.pointerMove(1, const Offset(64, 50), 20);
      loose.engine.pointerUp(1, const Offset(64, 50), 60);
      expect(loose.log, ['left down n=1', 'left up n=1']);

      // second tap 500 ms later: too late by default (320 ms), accepted with the window x2
      final slow = R();
      slow.tap(1, const Offset(100, 100), 0);
      slow.tap(2, const Offset(100, 100), 560);
      expect(slow.log.where((l) => l.contains('n=2')), isEmpty);
      final patient = R(_plain, _with(GestureConfig.defaults(), GestureId.doubleTap, (s) => s.copyWith(sensitivity: 2)));
      patient.tap(1, const Offset(100, 100), 0);
      patient.tap(2, const Offset(100, 100), 560);
      expect(patient.log.where((l) => l.contains('n=2')), isNotEmpty);
    });
  });

  test('default mapping: three fingers = Mission Control, App Expos\u00e9, previous and next desktop', () {
    final c = GestureConfig.defaults();
    expect(c[GestureId.threeUp].action, const SystemGestureAction(SystemActionIds.missionControl));
    expect(c[GestureId.threeDown].action, const SystemGestureAction(SystemActionIds.appExpose));
    expect(c[GestureId.threeLeft].action, const SystemGestureAction(SystemActionIds.desktopLeft));
    expect(c[GestureId.threeRight].action, const SystemGestureAction(SystemActionIds.desktopRight));
  });
}
