import 'dart:async';

import '../protocol/input_protocol.dart';

typedef FrameSink = void Function(List<Map<String, dynamic>> events);

/// Coalesces movement and scroll into at most one frame per [interval] (default 8 ms, about 125 Hz) and
/// sends button / key events immediately, preserving order (pending motion always goes out first).
/// Zero-length deltas are never sent.
class InputBatcher {
  InputBatcher({
    required this.onFrame,
    this.interval = const Duration(milliseconds: 8),
    void Function(Duration, void Function())? schedule,
  }) : _schedule = schedule ?? ((d, f) => Timer(d, f));

  final FrameSink onFrame;
  final Duration interval;
  final void Function(Duration, void Function()) _schedule;

  static const _maxChunk = 1800;      // stays under the Mac's per-event limit of 2000
  int _mx = 0, _my = 0, _sx = 0, _sy = 0;
  bool _scheduled = false;
  int framesSent = 0;

  bool get hasPending => _mx != 0 || _my != 0 || _sx != 0 || _sy != 0;

  void addMove(int dx, int dy) {
    _mx += dx;
    _my += dy;
    _arm();
  }

  void addScroll(int dx, int dy) {
    _sx += dx;
    _sy += dy;
    _arm();
  }

  void addButton(String button, bool down, [int clickCount = 1]) =>
      addEvent(InputEvents.button(button, down, clickCount));

  /// Any non-motion event: flushes pending motion first and sends everything now.
  void addEvent(Map<String, dynamic> event) => flush(trailing: event);

  void flush({Map<String, dynamic>? trailing}) {
    final events = <Map<String, dynamic>>[];
    _drain(events, _mx, _my, InputEvents.move);
    _drain(events, _sx, _sy, InputEvents.scroll);
    _mx = _my = _sx = _sy = 0;
    if (trailing != null) events.add(trailing);
    if (events.isEmpty) return;
    framesSent++;
    onFrame(events);
  }

  /// Drops pending motion (connection lost); nothing is sent.
  void clear() => _mx = _my = _sx = _sy = 0;

  static void _drain(List<Map<String, dynamic>> out, int x, int y, Map<String, dynamic> Function(int, int) make) {
    while (x != 0 || y != 0) {
      final int cx = x.clamp(-_maxChunk, _maxChunk).toInt(), cy = y.clamp(-_maxChunk, _maxChunk).toInt();
      out.add(make(cx, cy));
      x -= cx;
      y -= cy;
    }
  }

  void _arm() {
    if (_scheduled) return;
    _scheduled = true;
    _schedule(interval, () {
      _scheduled = false;
      flush();
    });
  }
}
