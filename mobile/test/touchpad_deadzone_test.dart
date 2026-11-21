import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mactouch_mobile/core/touchpad/gesture_engine.dart';
import 'package:mactouch_mobile/core/touchpad/touchpad_settings.dart';

int _moved(TouchpadSettings s, List<double> steps) {
  final actions = <TouchpadAction>[];
  final engine = GestureEngine(settings: s, holds: ButtonHolds(actions.add), emit: actions.add);
  engine.pointerDown(1, Offset.zero, 0);
  var x = 0.0, t = 0;
  for (final d in steps) {
    x += d;
    t += 16;
    engine.pointerMove(1, Offset(x, 0), t);
  }
  return actions.whereType<MoveAction>().fold(0, (a, m) => a + m.dx);
}

void main() {
  const plain = TouchpadSettings(accelEnabled: false, smoothing: 0, sensitivity: 1);

  test('touch sensitivity (dead zone) defaults to 3 px and is persisted and clamped', () {
    expect(const TouchpadSettings().deadzone, 3.0);
    final back = TouchpadSettings.fromJson(jsonDecode(jsonEncode(const TouchpadSettings(deadzone: 5.5).toJson())));
    expect(back.deadzone, 5.5);
    expect(TouchpadSettings.fromJson({'deadzone': 99}).deadzone, TouchpadSettings.deadzoneRange.max);
    expect(TouchpadSettings.fromJson({'deadzone': -4}).deadzone, TouchpadSettings.deadzoneRange.min);
    expect(TouchpadSettings.fromJson({'deadzone': 'wide'}).deadzone, 3.0);
    expect(TouchpadSettings.fromJson(null).deadzone, 3.0);
  });

  test('a small movement is ignored with a wide dead zone and followed with none', () {
    final small = [1.0, 1.0, 1.0];                       // 3 px in total
    expect(_moved(plain.copyWith(deadzone: 8), small), 0);
    expect(_moved(plain.copyWith(deadzone: 0), small), 3);
  });

  test('the default keeps the old behaviour', () {
    expect(_moved(plain, [1.0, 1.0]), 0, reason: '2 px is inside the default 3 px dead zone');
    expect(_moved(plain, [4.0, 4.0]), 8);
  });

  test('a wider dead zone needs more movement before the pointer starts', () {
    final steps = [2.0, 2.0, 2.0, 2.0];                  // 8 px in 2 px steps
    expect(_moved(plain.copyWith(deadzone: 4), steps), greaterThan(0));
    expect(_moved(plain.copyWith(deadzone: 8), steps), 2, reason: 'only the move that crosses 8 px is applied');
  });
}
