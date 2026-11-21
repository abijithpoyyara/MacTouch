import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mactouch_mobile/core/shortcuts/system_actions.dart';
import 'package:mactouch_mobile/core/touchpad/gesture_config.dart';

void main() {
  test('every gesture has a finger count; swipes have a direction', () {
    for (final g in GestureId.values) {
      expect(g.fingers, inInclusiveRange(1, 4));
      expect(g.isSwipe, g.fingers >= 3);
      expect(g.direction != null, g.isSwipe);
    }
    expect(GestureId.swipe(3, SwipeDirection.up), GestureId.threeUp);
    expect(GestureId.swipe(4, SwipeDirection.right), GestureId.fourRight);
    expect(GestureId.swipe(2, SwipeDirection.up), isNull);
    expect(GestureId.values.length, 15);
  });

  test('serialization round trip keeps every field, including actions', () {
    var c = GestureConfig.defaults();
    c = c.with_(GestureId.fourRight, const GestureSetting(enabled: false, distance: 123, action: ShortcutGestureAction('custom.42')));
    c = c.with_(GestureId.longPress, const GestureSetting(holdMs: 700));
    c = c.with_(GestureId.doubleTap, const GestureSetting(sensitivity: 1.5));
    final back = GestureConfig.fromJson(jsonDecode(jsonEncode(c.toJson())));
    expect(back[GestureId.fourRight].enabled, isFalse);
    expect(back[GestureId.fourRight].distance, 123);
    expect(back[GestureId.fourRight].action, const ShortcutGestureAction('custom.42'));
    expect(back[GestureId.longPress].holdMs, 700);
    expect(back[GestureId.doubleTap].sensitivity, 1.5);
    expect(back[GestureId.threeUp].action, const SystemGestureAction(SystemActionIds.missionControl));
  });

  test('a cleared action stays cleared after a round trip (it does not snap back to the default)', () {
    final c = GestureConfig.defaults().with_(GestureId.threeUp, GestureConfig.defaults()[GestureId.threeUp].copyWith(clearAction: true));
    expect(c[GestureId.threeUp].action, isNull);
    final back = GestureConfig.fromJson(jsonDecode(jsonEncode(c.toJson())));
    expect(back[GestureId.threeUp].action, isNull);
  });

  test('loading never throws: garbage, missing gestures and unknown ids give defaults; numbers are clamped', () {
    expect(GestureConfig.fromJson(null)[GestureId.threeUp].distance, 80);
    expect(GestureConfig.fromJson('nope')[GestureId.threeUp].distance, 80);
    final c = GestureConfig.fromJson({
      'threeUp': {'on': 'yes', 'sens': 99, 'dist': 5, 'hold': 99999, 'action': {'t': 'sys', 'id': 'reboot'}},
      'bogus': {'on': false},
    });
    final s = c[GestureId.threeUp];
    expect(s.enabled, isTrue, reason: 'wrong type -> default');
    expect(s.sensitivity, GestureSetting.sensitivityRange.max);
    expect(s.distance, GestureSetting.distanceRange.min);
    expect(s.holdMs, GestureSetting.holdRange.max);
    expect(s.action, isNull, reason: 'unknown system action is rejected');
    expect(c[GestureId.threeDown].action, const SystemGestureAction(SystemActionIds.appExpose));
  });

  test('actions: serialization and validation', () {
    expect(GestureAction.fromJson({'t': 'sys', 'id': 'mission_control'}), const SystemGestureAction('mission_control'));
    expect(GestureAction.fromJson({'t': 'shortcut', 'id': 'preset.find'}), const ShortcutGestureAction('preset.find'));
    expect(GestureAction.fromJson({'t': 'sys', 'id': 'format_disk'}), isNull);
    expect(GestureAction.fromJson({'t': 'other', 'id': 'x'}), isNull);
    expect(GestureAction.fromJson({'t': 'sys'}), isNull);
    expect(GestureAction.fromJson(5), isNull);
    expect(const SystemGestureAction('app_expose').toJson(), {'t': 'sys', 'id': 'app_expose'});
  });

  test('anyEnabledFor', () {
    var c = GestureConfig.defaults();
    expect(c.anyEnabledFor(3), isTrue);
    for (final g in [GestureId.threeUp, GestureId.threeDown, GestureId.threeLeft, GestureId.threeRight]) {
      c = c.with_(g, c[g].copyWith(enabled: false));
    }
    expect(c.anyEnabledFor(3), isFalse);
    expect(c.anyEnabledFor(4), isTrue);
  });

  test('restoring defaults is just a fresh config', () {
    final changed = GestureConfig.defaults().with_(GestureId.threeUp, const GestureSetting(enabled: false));
    final restored = GestureConfig.defaults();
    expect(restored[GestureId.threeUp].enabled, isTrue);
    expect(changed[GestureId.threeUp].enabled, isFalse, reason: 'configs are immutable');
  });
}
