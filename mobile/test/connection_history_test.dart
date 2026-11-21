import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mactouch_mobile/core/format.dart';
import 'package:mactouch_mobile/core/history/connection_history.dart';

HistoryEntry _e(int ms, [HistoryKind k = HistoryKind.connected, String d = 'Mac mini']) => HistoryEntry(atMs: ms, kind: k, device: d);

void main() {
  test('adding puts the newest first', () {
    var h = const ConnectionHistory();
    h = h.add(_e(1)).add(_e(2, HistoryKind.lost)).add(_e(3, HistoryKind.disconnected));
    expect(h.entries.map((e) => e.atMs), [3, 2, 1]);
    expect(h.entries.first.kind, HistoryKind.disconnected);
  });

  test('the log is capped, keeping the newest', () {
    var h = const ConnectionHistory();
    for (var i = 0; i < ConnectionHistory.limit + 25; i++) {
      h = h.add(_e(i));
    }
    expect(h.entries.length, ConnectionHistory.limit);
    expect(h.entries.first.atMs, ConnectionHistory.limit + 24);
    expect(h.entries.last.atMs, 25);
  });

  test('JSON round trip keeps kind, device, detail and time', () {
    final h = const ConnectionHistory().add(const HistoryEntry(atMs: 1700000000000, kind: HistoryKind.failed, device: 'Studio Mac', detail: 'Couldn\u2019t reach your Mac.'));
    final back = ConnectionHistory.fromJson(jsonDecode(jsonEncode(h.toJson())));
    expect(back.entries.single.kind, HistoryKind.failed);
    expect(back.entries.single.device, 'Studio Mac');
    expect(back.entries.single.detail, 'Couldn\u2019t reach your Mac.');
    expect(back.entries.single.at, DateTime.fromMillisecondsSinceEpoch(1700000000000));
  });

  test('loading skips bad entries, sorts newest first, and never throws', () {
    final h = ConnectionHistory.fromJson([
      {'t': 5, 'k': 'connected', 'd': 'A'},
      {'t': 9, 'k': 'lost', 'd': 'A'},
      {'t': 'x', 'k': 'connected', 'd': 'A'},
      {'t': 1, 'k': 'exploded', 'd': 'A'},
      {'t': 2, 'k': 'paired'},
      7,
      null,
    ]);
    expect(h.entries.map((e) => e.atMs), [9, 5]);
    expect(ConnectionHistory.fromJson(null).entries, isEmpty);
    expect(ConnectionHistory.fromJson({'a': 1}).entries, isEmpty);
  });

  test('every kind has a label', () {
    for (final k in HistoryKind.values) {
      expect(k.label, isNotEmpty);
    }
  });

  group('formatWhen', () {
    final now = DateTime(2026, 11, 8, 15, 30);
    test('today, yesterday, older', () {
      expect(formatWhen(DateTime(2026, 11, 8, 9, 5), now: now), 'Today 09:05');
      expect(formatWhen(DateTime(2026, 11, 7, 23, 59), now: now), 'Yesterday 23:59');
      expect(formatWhen(DateTime(2026, 11, 3, 14, 0), now: now), 'Nov 3, 14:00');
      expect(formatWhen(DateTime(2025, 1, 2, 0, 0), now: now), 'Jan 2, 00:00');
    });

    test('around midnight it compares calendar days, not 24-hour spans', () {
      final lateNow = DateTime(2026, 11, 8, 0, 10);
      expect(formatWhen(DateTime(2026, 11, 7, 23, 50), now: lateNow), 'Yesterday 23:50');
    });
  });
}
