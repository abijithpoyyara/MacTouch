import 'package:flutter_test/flutter_test.dart';
import 'package:mactouch_mobile/core/touchpad/input_batcher.dart';

void main() {
  late List<List<Map<String, dynamic>>> frames;
  late List<void Function()> timers;
  late InputBatcher b;

  setUp(() {
    frames = [];
    timers = [];
    b = InputBatcher(onFrame: frames.add, schedule: (_, f) => timers.add(f));
  });

  test('many moves in one interval become one frame with one summed move', () {
    for (var i = 0; i < 20; i++) {
      b.addMove(2, -1);
    }
    expect(timers.length, 1, reason: 'one timer, not one per event');
    expect(frames, isEmpty, reason: 'nothing is sent before the interval ends');
    timers.single();
    expect(frames, [
      [
        {'e': 'move', 'dx': 40, 'dy': -20}
      ]
    ]);
  });

  test('moves that cancel out, and empty flushes, send nothing', () {
    b.addMove(5, 5);
    b.addMove(-5, -5);
    timers.single();
    b.flush();
    expect(frames, isEmpty);
  });

  test('a button event flushes pending motion first, in order, in the same frame', () {
    b.addMove(3, 4);
    b.addScroll(0, 9);
    b.addButton('left', true);
    expect(frames.length, 1);
    expect(frames.single.map((e) => e['e']), ['move', 'scroll', 'btn']);
    expect(frames.single.last, {'e': 'btn', 'b': 'left', 's': 'down'});
    expect(b.hasPending, isFalse);
  });

  test('click count is only included when it is not 1', () {
    b.addButton('left', true, 2);
    expect(frames.single.single, {'e': 'btn', 'b': 'left', 's': 'down', 'n': 2});
  });

  test('a huge accumulated delta is split below the Mac limit of 2000 per event', () {
    b.addMove(5000, -4000);
    b.flush();
    final moves = frames.single;
    expect(moves.every((m) => (m['dx'] as int).abs() <= 1800 && (m['dy'] as int).abs() <= 1800), isTrue);
    expect(moves.fold<int>(0, (a, m) => a + (m['dx'] as int)), 5000);
    expect(moves.fold<int>(0, (a, m) => a + (m['dy'] as int)), -4000);
  });

  test('clear drops pending motion without sending', () {
    b.addMove(10, 10);
    b.clear();
    timers.single();
    expect(frames, isEmpty);
  });

  test('a new timer is armed again after each flush', () {
    b.addMove(1, 1);
    timers.removeLast()();
    b.addMove(1, 1);
    expect(timers.length, 1);
    timers.removeLast()();
    expect(frames.length, 2);
  });
}
